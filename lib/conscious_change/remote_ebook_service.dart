import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class RemoteEbookCandidate {
  final String sourceName;
  final String sourceBookId;
  final String title;
  final String author;
  final String language;
  final String fileName;
  final String fileExt;
  final String mimeType;
  final String downloadUrl;
  final String sourcePageUrl;
  final String licenseStatus;
  final String rightsNote;

  const RemoteEbookCandidate({
    required this.sourceName,
    required this.sourceBookId,
    required this.title,
    required this.author,
    required this.language,
    required this.fileName,
    required this.fileExt,
    required this.mimeType,
    required this.downloadUrl,
    required this.sourcePageUrl,
    required this.licenseStatus,
    required this.rightsNote,
  });

  String get sourceLabel {
    return switch (sourceName) {
      'gutendex' => 'Project Gutenberg',
      'internet_archive' => 'Internet Archive',
      _ => sourceName,
    };
  }

  String get formatLabel => fileExt.toUpperCase();

  bool get canImportIntoReader {
    return const <String>{
      'epub',
      'txt',
      'md',
      'markdown',
      'html',
      'htm',
      'xhtml',
      'rtf',
      'fb2',
      'docx',
      'pdf',
    }.contains(fileExt.toLowerCase());
  }

  String get normalizedKey => '$sourceName::$sourceBookId::$fileExt::$downloadUrl';
}

class RemoteEbookDownloadResult {
  final Uint8List bytes;
  final String supportPath;
  final String downloadsPath;
  final String sha256;

  const RemoteEbookDownloadResult({
    required this.bytes,
    required this.supportPath,
    required this.downloadsPath,
    required this.sha256,
  });
}

abstract class RemoteEbookSource {
  String get name;
  Future<List<RemoteEbookCandidate>> search(String query);
}

class RemoteEbookRepository {
  RemoteEbookRepository({http.Client? client}) : _client = client ?? http.Client() {
    _sources = <RemoteEbookSource>[
      GutendexEbookSource(_client),
      InternetArchiveEbookSource(_client),
    ];
  }

  final http.Client _client;
  late final List<RemoteEbookSource> _sources;

  Future<List<RemoteEbookCandidate>> searchAll(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const <RemoteEbookCandidate>[];
    final results = <RemoteEbookCandidate>[];
    for (final source in _sources) {
      try {
        results.addAll(await source.search(trimmed));
      } catch (_) {
        // 单个数据源失败不影响其它来源，页面会展示已有可用结果。
      }
    }
    final byKey = <String, RemoteEbookCandidate>{};
    for (final item in results) {
      if (item.downloadUrl.trim().isEmpty || !item.canImportIntoReader) continue;
      byKey.putIfAbsent(item.normalizedKey, () => item);
    }
    final list = byKey.values.toList();
    list.sort((a, b) {
      final titleCompare = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      if (titleCompare != 0) return titleCompare;
      final sourceCompare = a.sourceLabel.compareTo(b.sourceLabel);
      if (sourceCompare != 0) return sourceCompare;
      return _formatRank(a.fileExt).compareTo(_formatRank(b.fileExt));
    });
    return list.take(80).toList();
  }

  Future<RemoteEbookDownloadResult> downloadToLocalCopies(RemoteEbookCandidate candidate) async {
    final response = await _client.get(
      Uri.parse(candidate.downloadUrl),
      headers: <String, String>{
        'User-Agent': 'quote_app ebook downloader (public-domain/open-access ebooks only)',
        'Accept': '${candidate.mimeType},application/octet-stream,*/*',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('下载失败：HTTP ${response.statusCode}');
    }
    final bytes = response.bodyBytes;
    if (bytes.isEmpty) throw const FormatException('下载文件为空。');
    if (bytes.length > 220 * 1024 * 1024) {
      throw const FormatException('文件过大，已停止导入。');
    }

    final digest = sha256.convert(bytes).toString();
    final fileName = _safeFileName(candidate.fileName, extension: candidate.fileExt);
    final supportPath = await _writeSupportCopy(
      fileName: fileName,
      extension: candidate.fileExt,
      bytes: bytes,
      sha256Value: digest,
    );
    final downloadsPath = await _writeDownloadsCopy(
      fileName: fileName,
      mimeType: candidate.mimeType,
      bytes: bytes,
      sha256Value: digest,
      supportPath: supportPath,
    );

    return RemoteEbookDownloadResult(
      bytes: bytes,
      supportPath: supportPath,
      downloadsPath: downloadsPath,
      sha256: digest,
    );
  }

  Future<String> _writeSupportCopy({
    required String fileName,
    required String extension,
    required Uint8List bytes,
    required String sha256Value,
  }) async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory('${root.path}/conscious_change_books');
    if (!await dir.exists()) await dir.create(recursive: true);
    final baseName = _withoutExtension(fileName);
    final ext = extension.toLowerCase().replaceFirst('.', '').trim();
    final safeExt = ext.isEmpty ? 'bin' : ext;
    final path = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${sha256Value.substring(0, 10)}_$baseName.$safeExt';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<String> _writeDownloadsCopy({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
    required String sha256Value,
    required String supportPath,
  }) async {
    try {
      const channel = MethodChannel('native.scheduler');
      final saved = await channel.invokeMethod<String>('saveFileToDownloads', <String, Object?>{
        'path': supportPath,
        'name': fileName,
        'mime': mimeType,
        'subDir': 'Ebooks',
      });
      if (saved != null && saved.trim().isNotEmpty) return saved.trim();
    } catch (_) {
      // Fall back to plain file APIs below on platforms without the native Android channel.
    }

    final candidates = <Directory>[];
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) candidates.add(Directory('${downloads.path}/Ebooks'));
    } catch (_) {
      // Some Android/iOS builds do not expose a writable Downloads directory through path_provider.
    }
    if (Platform.isAndroid) {
      candidates.add(Directory('/storage/emulated/0/Download/Ebooks'));
    }

    for (final dir in candidates) {
      try {
        if (!await dir.exists()) await dir.create(recursive: true);
        final baseName = _withoutExtension(fileName);
        final ext = _extensionFromFileName(fileName);
        final file = File('${dir.path}/${sha256Value.substring(0, 10)}_$baseName.$ext');
        await file.writeAsBytes(bytes, flush: true);
        return file.path;
      } catch (_) {
        // Best effort: if public Downloads is blocked by scoped storage, the support copy still works.
      }
    }
    return '';
  }

  void close() => _client.close();
}

class GutendexEbookSource implements RemoteEbookSource {
  GutendexEbookSource(this._client);

  final http.Client _client;

  @override
  String get name => 'gutendex';

  @override
  Future<List<RemoteEbookCandidate>> search(String query) async {
    final uri = Uri.https('gutendex.com', '/books', <String, String>{
      'search': query,
    });
    final response = await _client.get(uri, headers: _jsonHeaders);
    if (response.statusCode != 200) return const <RemoteEbookCandidate>[];
    final root = jsonDecode(utf8.decode(response.bodyBytes));
    if (root is! Map<String, Object?>) return const <RemoteEbookCandidate>[];
    final results = root['results'];
    if (results is! List) return const <RemoteEbookCandidate>[];

    return results.whereType<Map<String, Object?>>().expand((book) {
      final id = (book['id'] ?? '').toString();
      final title = _cleanText((book['title'] ?? '').toString());
      final authors = book['authors'];
      final author = authors is List && authors.isNotEmpty && authors.first is Map
          ? _cleanText(((authors.first as Map)['name'] ?? '').toString())
          : '';
      final languages = book['languages'];
      final language = languages is List && languages.isNotEmpty ? languages.first.toString() : '';
      final formats = book['formats'];
      if (formats is! Map) return const <RemoteEbookCandidate>[];

      final byExt = <String, RemoteEbookCandidate>{};
      for (final entry in formats.entries) {
        final rawMime = entry.key.toString();
        final url = entry.value.toString();
        if (url.trim().isEmpty) continue;
        final fileType = _candidateFileTypeFromMimeAndName(rawMime, url);
        if (fileType == null) continue;
        final ext = fileType.extension;
        // Gutendex may return many encodings for the same format; keep one compact candidate per extension.
        byExt.putIfAbsent(
          ext,
          () => RemoteEbookCandidate(
            sourceName: name,
            sourceBookId: id,
            title: title.isEmpty ? 'Untitled' : title,
            author: author,
            language: language,
            fileName: _safeFileName(title.isEmpty ? 'book_$id.$ext' : '$title.$ext', extension: ext),
            fileExt: ext,
            mimeType: fileType.mimeType,
            downloadUrl: url,
            sourcePageUrl: 'https://www.gutenberg.org/ebooks/$id',
            licenseStatus: 'public_domain',
            rightsNote: 'Project Gutenberg 公版电子书',
          ),
        );
      }
      final values = byExt.values.toList()..sort((a, b) => _formatRank(a.fileExt).compareTo(_formatRank(b.fileExt)));
      return values;
    }).take(60).toList();
  }
}

class InternetArchiveEbookSource implements RemoteEbookSource {
  InternetArchiveEbookSource(this._client);

  final http.Client _client;

  @override
  String get name => 'internet_archive';

  @override
  Future<List<RemoteEbookCandidate>> search(String query) async {
    final advanced = Uri.https('archive.org', '/advancedsearch.php', <String, dynamic>{
      'q': 'mediatype:texts AND (${_iaQuery(query)})',
      'fl[]': <String>['identifier', 'title', 'creator', 'language', 'licenseurl', 'rights'],
      'rows': '10',
      'page': '1',
      'output': 'json',
    });
    final response = await _client.get(advanced, headers: _jsonHeaders);
    if (response.statusCode != 200) return const <RemoteEbookCandidate>[];
    final root = jsonDecode(utf8.decode(response.bodyBytes));
    if (root is! Map<String, Object?>) return const <RemoteEbookCandidate>[];
    final docs = ((root['response'] as Map?)?['docs']);
    if (docs is! List) return const <RemoteEbookCandidate>[];

    final results = <RemoteEbookCandidate>[];
    for (final doc in docs.whereType<Map>()) {
      final identifier = (doc['identifier'] ?? '').toString();
      if (identifier.isEmpty) continue;
      final title = _cleanText((doc['title'] ?? '').toString());
      final author = _creatorToText(doc['creator']);
      final metadata = await _fetchMetadata(identifier);
      if (metadata == null) continue;
      final rights = _metadataRights(metadata, doc);
      final licenseStatus = _classifyInternetArchiveRights(rights);
      if (licenseStatus == null) continue;
      final files = metadata['files'];
      if (files is! List) continue;

      final byExt = <String, RemoteEbookCandidate>{};
      for (final file in files.whereType<Map>()) {
        final name = (file['name'] ?? '').toString();
        final format = (file['format'] ?? '').toString();
        if (name.trim().isEmpty || _isArchiveDerivedNoise(name)) continue;
        final fileType = _candidateFileTypeFromArchiveFile(name, format);
        if (fileType == null) continue;
        final ext = fileType.extension;
        final downloadUrl = Uri.https('archive.org', '/download/$identifier/$name').toString();
        final originalFileName = _safeFileName(name, extension: ext);
        byExt.putIfAbsent(
          ext,
          () => RemoteEbookCandidate(
            sourceName: this.name,
            sourceBookId: identifier,
            title: title.isEmpty ? identifier : title,
            author: author,
            language: _firstValueAsText(doc['language']),
            fileName: originalFileName,
            fileExt: ext,
            mimeType: fileType.mimeType,
            downloadUrl: downloadUrl,
            sourcePageUrl: 'https://archive.org/details/$identifier',
            licenseStatus: licenseStatus,
            rightsNote: rights.isEmpty ? 'Internet Archive 公开可下载电子书' : rights,
          ),
        );
      }
      final values = byExt.values.toList()..sort((a, b) => _formatRank(a.fileExt).compareTo(_formatRank(b.fileExt)));
      results.addAll(values);
    }
    return results.take(60).toList();
  }

  Future<Map<String, Object?>?> _fetchMetadata(String identifier) async {
    final response = await _client.get(Uri.https('archive.org', '/metadata/$identifier'), headers: _jsonHeaders);
    if (response.statusCode != 200) return null;
    final root = jsonDecode(utf8.decode(response.bodyBytes));
    return root is Map<String, Object?> ? root : null;
  }
}

class _RemoteFileType {
  final String extension;
  final String mimeType;

  const _RemoteFileType(this.extension, this.mimeType);
}

const Map<String, String> _jsonHeaders = <String, String>{
  'User-Agent': 'quote_app ebook search (public-domain/open-access ebooks only)',
  'Accept': 'application/json,text/plain,*/*',
};

String _iaQuery(String query) {
  final tokens = query
      .split(RegExp(r'\s+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .take(6)
      .map((e) => e.replaceAll('"', ''))
      .where((e) => e.isNotEmpty)
      .join(' AND ');
  return tokens.isEmpty ? query : tokens;
}

String _metadataRights(Map<String, Object?> metadata, Map<dynamic, dynamic> doc) {
  final meta = metadata['metadata'];
  final parts = <String>[
    _firstValueAsText(doc['rights']),
    _firstValueAsText(doc['licenseurl']),
  ];
  if (meta is Map) {
    parts.add(_firstValueAsText(meta['rights']));
    parts.add(_firstValueAsText(meta['licenseurl']));
    parts.add(_firstValueAsText(meta['license']));
    parts.add(_firstValueAsText(meta['access-restricted-item']));
  }
  return parts.where((e) => e.trim().isNotEmpty).join(' · ');
}

String? _classifyInternetArchiveRights(String rights) {
  final text = rights.toLowerCase();
  if (text.contains('access-restricted') && text.contains('true')) return null;
  if (text.contains('public domain') || text.contains('pd-old') || text.contains('mark/1.0')) {
    return 'public_domain';
  }
  if (text.contains('creativecommons') || text.contains('creative commons') || text.contains('/licenses/by') || text.contains('cc0')) {
    return 'cc_license';
  }
  if (text.contains('open access') || text.contains('open-access')) return 'open_access';
  return null;
}

_RemoteFileType? _candidateFileTypeFromMimeAndName(String mime, String nameOrUrl) {
  final m = mime.toLowerCase();
  final n = nameOrUrl.toLowerCase().split('?').first;
  if (m.contains('epub') || n.endsWith('.epub')) return const _RemoteFileType('epub', 'application/epub+zip');
  if (m.contains('pdf') || n.endsWith('.pdf')) return const _RemoteFileType('pdf', 'application/pdf');
  if (m.contains('html') || n.endsWith('.html') || n.endsWith('.htm')) return const _RemoteFileType('html', 'text/html; charset=utf-8');
  if (m.contains('plain') || n.endsWith('.txt') || n.endsWith('_djvu.txt')) return const _RemoteFileType('txt', 'text/plain; charset=utf-8');
  if (m.contains('rtf') || n.endsWith('.rtf')) return const _RemoteFileType('rtf', 'application/rtf');
  if (m.contains('fictionbook') || n.endsWith('.fb2')) return const _RemoteFileType('fb2', 'application/x-fictionbook+xml');
  if (m.contains('wordprocessingml') || n.endsWith('.docx')) return const _RemoteFileType('docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
  return null;
}

_RemoteFileType? _candidateFileTypeFromArchiveFile(String name, String format) {
  final n = name.toLowerCase();
  final f = format.toLowerCase();
  if (n.endsWith('.epub') || f.contains('epub')) return const _RemoteFileType('epub', 'application/epub+zip');
  if (n.endsWith('.pdf') || f == 'text pdf' || f == 'pdf' || f.contains('portable document')) return const _RemoteFileType('pdf', 'application/pdf');
  if (n.endsWith('.html') || n.endsWith('.htm') || f.contains('html')) return const _RemoteFileType('html', 'text/html; charset=utf-8');
  if (n.endsWith('.txt') || n.endsWith('_djvu.txt') || f == 'djvu txt' || f.contains('plain text')) return const _RemoteFileType('txt', 'text/plain; charset=utf-8');
  if (n.endsWith('.rtf') || f.contains('rtf')) return const _RemoteFileType('rtf', 'application/rtf');
  if (n.endsWith('.fb2') || f.contains('fictionbook')) return const _RemoteFileType('fb2', 'application/x-fictionbook+xml');
  if (n.endsWith('.docx') || f.contains('word')) return const _RemoteFileType('docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
  return null;
}

bool _isArchiveDerivedNoise(String name) {
  final n = name.toLowerCase();
  if (n.contains('_meta') || n.contains('_files') || n.contains('_scandata')) return true;
  if (n.endsWith('.torrent') || n.endsWith('_itemimage.jpg')) return true;
  if (n.endsWith('_abbyy.gz') || n.endsWith('_djvu.xml')) return true;
  if (n.endsWith('_jp2.zip') || n.endsWith('_images.zip')) return true;
  return false;
}

int _formatRank(String ext) {
  return switch (ext.toLowerCase()) {
    'epub' => 0,
    'fb2' => 1,
    'html' || 'htm' || 'xhtml' => 2,
    'txt' || 'md' || 'markdown' => 3,
    'docx' => 4,
    'rtf' => 5,
    'pdf' => 6,
    _ => 99,
  };
}

String _creatorToText(Object? value) {
  if (value is List) return value.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).join('、');
  return (value ?? '').toString();
}

String _firstValueAsText(Object? value) {
  if (value is List) return value.isEmpty ? '' : value.first.toString();
  return (value ?? '').toString();
}

String _cleanText(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _safeFileName(String input, {required String extension}) {
  final ext = extension.toLowerCase().replaceFirst('.', '').trim();
  final safeExt = ext.isEmpty ? 'bin' : ext;
  var normalized = input
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (normalized.isEmpty) normalized = 'ebook.$safeExt';
  normalized = _withoutExtension(normalized);
  final limited = normalized.length > 110 ? normalized.substring(0, 110).trim() : normalized;
  return '${limited.isEmpty ? 'ebook' : limited}.$safeExt';
}

String _extensionFromFileName(String input) {
  final match = RegExp(r'\.([A-Za-z0-9]+)$').firstMatch(input.trim());
  return match == null ? 'bin' : match.group(1)!.toLowerCase();
}

String _withoutExtension(String input) {
  return input.replaceFirst(RegExp(r'\.[A-Za-z0-9]+$', caseSensitive: false), '');
}
