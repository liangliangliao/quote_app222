import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'xiangji_dao.dart';
import 'xiangji_models.dart';

class XiangjiBookIndexResult {
  const XiangjiBookIndexResult({
    required this.chunks,
    required this.parsedCharacters,
    required this.partial,
  });

  final List<XiangjiBookChunk> chunks;
  final int parsedCharacters;
  final bool partial;
}

class XiangjiBookIndexService {
  XiangjiBookIndexService({XiangjiGoalMentorDao? dao})
      : _dao = dao ?? XiangjiGoalMentorDao();

  static const int maxFileBytes = 64 * 1024 * 1024;
  static const int maxParsedCharacters = 4 * 1000 * 1000;
  static const int maxChunkCharacters = 1100;
  static const int chunkOverlapCharacters = 120;

  final XiangjiGoalMentorDao _dao;

  Future<XiangjiBookIndexResult> indexFile({
    required File file,
    required String filename,
    required int bookId,
    required String bookTitle,
  }) async {
    if (!await file.exists()) throw StateError('本地书籍文件不存在。');
    final length = await file.length();
    if (length == 0) throw StateError('书籍文件为空。');
    if (length > maxFileBytes) {
      throw StateError('单本书暂不支持超过 64 MB；请先压缩或拆分文件。');
    }
    final bytes = await file.readAsBytes();
    final parsed = _parse(bytes, filename);
    if (parsed.sections.isEmpty || parsed.characterCount < 20) {
      throw StateError('没有提取到足够的可检索文字；扫描版 PDF 需要先完成 OCR。');
    }
    final chunks = _chunk(
      parsed.sections,
      bookId: bookId,
      bookTitle: bookTitle,
    );
    if (chunks.isEmpty) throw StateError('书籍文字无法建立有效索引。');
    return XiangjiBookIndexResult(
      chunks: chunks,
      parsedCharacters: parsed.characterCount,
      partial: parsed.partial,
    );
  }

  Future<List<XiangjiBookChunk>> retrieve({
    required String query,
    required List<String> allowedBookIds,
    int limit = 6,
  }) async {
    if (query.trim().isEmpty || allowedBookIds.isEmpty || limit <= 0) {
      return const <XiangjiBookChunk>[];
    }
    final terms = _queryTerms(query);
    if (terms.isEmpty) return const <XiangjiBookChunk>[];
    final chunks = await _dao.chunksForBooks(allowedBookIds);
    final scored = <XiangjiBookChunk>[];
    final exact = _normalizeForSearch(query);
    for (final chunk in chunks) {
      final body = _normalizeForSearch(chunk.text);
      final heading = _normalizeForSearch(
        '${chunk.bookTitle} ${chunk.sectionTitle}',
      );
      var score = 0.0;
      if (exact.length >= 4 && body.contains(exact)) score += 12;
      for (final term in terms) {
        final bodyMatches = term.allMatches(body).length;
        final headingMatches = term.allMatches(heading).length;
        score += bodyMatches.clamp(0, 4).toDouble();
        score += headingMatches.clamp(0, 2).toDouble() * 3.0;
      }
      if (score > 0) scored.add(chunk.copyWith(relevanceScore: score));
    }
    scored.sort((left, right) {
      final score = right.relevanceScore.compareTo(left.relevanceScore);
      return score == 0 ? left.chunkIndex.compareTo(right.chunkIndex) : score;
    });
    return scored.take(limit).toList(growable: false);
  }

  _ParsedBook _parse(Uint8List bytes, String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.txt') || lower.endsWith('.md')) {
      return _parsePlainText(utf8.decode(bytes, allowMalformed: true));
    }
    if (lower.endsWith('.docx')) return _parseDocx(bytes);
    if (lower.endsWith('.epub')) return _parseEpub(bytes);
    if (lower.endsWith('.pdf')) return _parsePdf(bytes);
    if (lower.endsWith('.azw3')) return _parseBinaryEbook(bytes);
    throw StateError('暂不支持 ${p.extension(filename)} 格式。');
  }

  _ParsedBook _parsePlainText(String raw) {
    final sections = <_ParsedSection>[];
    var title = '正文';
    var buffer = StringBuffer();

    void flush() {
      final text = _cleanText(buffer.toString());
      if (text.isNotEmpty) {
        sections.add(_ParsedSection(title: title, text: text));
      }
      buffer = StringBuffer();
    }

    for (final rawLine in raw.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      final markdownHeading = RegExp(r'^#{1,6}\s+(.+)$').firstMatch(line);
      final chapterHeading = RegExp(
        r'^(第.{1,20}[章节篇部卷]|chapter\s+\d+\b).{0,80}$',
        caseSensitive: false,
      ).hasMatch(line);
      if (markdownHeading != null || chapterHeading) {
        flush();
        title = (markdownHeading?.group(1) ?? line).trim();
      } else if (line.isEmpty) {
        buffer.writeln();
      } else {
        buffer.writeln(line);
      }
    }
    flush();
    return _limited(sections);
  }

  _ParsedBook _parseDocx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    final document = archive.findFile('word/document.xml');
    if (document == null) throw StateError('DOCX 中缺少正文 document.xml。');
    final xml = utf8.decode(_archiveBytes(document), allowMalformed: true);
    final parsed = XmlDocument.parse(xml);
    final sections = <_ParsedSection>[];
    var title = '正文';
    var buffer = StringBuffer();

    void flush() {
      final text = _cleanText(buffer.toString());
      if (text.isNotEmpty) sections.add(_ParsedSection(title: title, text: text));
      buffer = StringBuffer();
    }

    for (final paragraph in parsed.findAllElements('w:p')) {
      final text = paragraph
          .findAllElements('w:t')
          .map((element) => element.innerText)
          .join('')
          .trim();
      if (text.isEmpty) continue;
      final style = paragraph
          .findAllElements('w:pStyle')
          .map((element) =>
              element.getAttribute('w:val') ?? element.getAttribute('val') ?? '')
          .join()
          .toLowerCase();
      final heading = style.contains('heading') ||
          RegExp(r'^第.{1,20}[章节篇部卷]').hasMatch(text);
      if (heading && text.length <= 100) {
        flush();
        title = text;
      } else {
        buffer.writeln(text);
      }
    }
    flush();
    return _limited(sections);
  }

  _ParsedBook _parseEpub(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    final contentFiles = archive.files
        .where((file) {
          final name = file.name.toLowerCase();
          return file.isFile &&
              (name.endsWith('.xhtml') ||
                  name.endsWith('.html') ||
                  name.endsWith('.htm'));
        })
        .toList()
      ..sort((left, right) => left.name.compareTo(right.name));
    if (contentFiles.isEmpty) throw StateError('EPUB 中没有可读取的正文文件。');
    final sections = <_ParsedSection>[];
    for (final file in contentFiles) {
      final raw = utf8.decode(_archiveBytes(file), allowMalformed: true);
      final titleMatch = RegExp(
        r'<(?:title|h1|h2)[^>]*>([\s\S]*?)</(?:title|h1|h2)>',
        caseSensitive: false,
      ).firstMatch(raw);
      final title = _cleanText(
        _stripMarkup(titleMatch?.group(1) ?? p.posix.basename(file.name)),
      );
      final text = _cleanText(_stripMarkup(raw));
      if (text.length >= 10) {
        sections.add(
          _ParsedSection(
            title: title.isEmpty ? p.posix.basename(file.name) : title,
            text: text,
            locatorPrefix: file.name,
          ),
        );
      }
    }
    return _limited(sections);
  }

  _ParsedBook _parsePdf(Uint8List bytes) {
    final raw = latin1.decode(bytes, allowInvalid: true);
    final buffer = StringBuffer();
    void addPdfText(String stream) {
      final paren = RegExp(r'\((?:\\.|[^\\)]){2,1600}\)');
      for (final match in paren.allMatches(stream)) {
        var text = match.group(0) ?? '';
        if (text.length <= 2) continue;
        text = text.substring(1, text.length - 1);
        text = text
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\r', '\n')
            .replaceAll(r'\t', '\t')
            .replaceAll(r'\(', '(')
            .replaceAll(r'\)', ')')
            .replaceAll(r'\\', r'\');
        if (_looksReadable(text)) buffer.write('$text ');
        if (buffer.length >= maxParsedCharacters) break;
      }
    }

    addPdfText(raw);
    final streams = RegExp(r'stream\r?\n([\s\S]*?)\r?\nendstream');
    for (final match in streams.allMatches(raw)) {
      if (buffer.length >= maxParsedCharacters) break;
      final headerStart = raw.lastIndexOf('<<', match.start);
      final header = headerStart < 0
          ? ''
          : raw.substring(
              headerStart,
              match.start > raw.length ? raw.length : match.start,
            );
      if (!header.contains('/FlateDecode')) continue;
      try {
        final compressed = latin1.encode(match.group(1) ?? '');
        final inflated = ZLibDecoder().decodeBytes(compressed, verify: false);
        addPdfText(latin1.decode(inflated, allowInvalid: true));
      } catch (_) {}
    }
    final text = _cleanText(buffer.toString());
    return _limited(
      <_ParsedSection>[
        _ParsedSection(title: 'PDF 可提取文本', text: text),
      ],
      forcePartial: true,
    );
  }

  _ParsedBook _parseBinaryEbook(Uint8List bytes) {
    final runs = <String>[];
    final ascii = StringBuffer();
    var extractedCharacters = 0;
    void flushAscii() {
      final value = ascii.toString().trim();
      if (value.length >= 12 && _looksReadable(value)) {
        runs.add(value);
        extractedCharacters += value.length;
      }
      ascii.clear();
    }

    for (final byte in bytes) {
      if (byte == 9 || byte == 10 || byte == 13 || (byte >= 32 && byte <= 126)) {
        ascii.writeCharCode(byte);
      } else {
        flushAscii();
      }
      if (extractedCharacters >= maxParsedCharacters) {
        break;
      }
    }
    flushAscii();
    final text = _cleanText(runs.toSet().join('\n'));
    return _limited(
      <_ParsedSection>[
        _ParsedSection(title: 'AZW3 可提取文本', text: text),
      ],
      forcePartial: true,
    );
  }

  _ParsedBook _limited(
    List<_ParsedSection> sections, {
    bool forcePartial = false,
  }) {
    final limited = <_ParsedSection>[];
    var remaining = maxParsedCharacters;
    var partial = forcePartial;
    for (final section in sections) {
      if (remaining <= 0) {
        partial = true;
        break;
      }
      final text = section.text.trim();
      if (text.isEmpty) continue;
      if (text.length > remaining) {
        limited.add(
          _ParsedSection(
            title: section.title,
            text: text.substring(0, remaining),
            locatorPrefix: section.locatorPrefix,
          ),
        );
        remaining = 0;
        partial = true;
      } else {
        limited.add(section);
        remaining -= text.length;
      }
    }
    return _ParsedBook(sections: limited, partial: partial);
  }

  List<XiangjiBookChunk> _chunk(
    List<_ParsedSection> sections, {
    required int bookId,
    required String bookTitle,
  }) {
    final chunks = <XiangjiBookChunk>[];
    var index = 0;
    for (final section in sections) {
      final text = section.text.trim();
      var start = 0;
      while (start < text.length) {
        final proposedEnd = start + maxChunkCharacters;
        var end = proposedEnd < text.length ? proposedEnd : text.length;
        if (end < text.length) {
          final minimum = start + (maxChunkCharacters * 0.62).round();
          final candidate = text.substring(minimum, end);
          final boundary = candidate.lastIndexOf(RegExp(r'[。！？.!?；;\n]'));
          if (boundary >= 0) end = minimum + boundary + 1;
        }
        final content = text.substring(start, end).trim();
        if (content.isNotEmpty) {
          final uid = 'xj_${bookId}_${index.toString().padLeft(5, '0')}';
          final prefix = section.locatorPrefix.isEmpty
              ? section.title
              : '${section.locatorPrefix} · ${section.title}';
          chunks.add(
            XiangjiBookChunk(
              id: uid,
              bookId: 'local_$bookId',
              bookTitle: bookTitle,
              chunkIndex: index,
              sectionTitle: section.title,
              locator: '$prefix · 字符 ${start + 1}–$end',
              text: content,
              contentHash: sha256.convert(utf8.encode(content)).toString(),
            ),
          );
          index += 1;
        }
        if (end >= text.length) break;
        final next = end - chunkOverlapCharacters;
        start = next > start ? next : end;
      }
    }
    return chunks;
  }

  static List<RegExp> _queryTerms(String query) {
    final normalized = _normalizeForSearch(query);
    final values = <String>{};
    for (final match in RegExp(r'[a-z0-9_]{2,}|[\u4e00-\u9fff]+')
        .allMatches(normalized)) {
      final value = match.group(0) ?? '';
      if (RegExp(r'^[\u4e00-\u9fff]+$').hasMatch(value) && value.length > 2) {
        for (var index = 0; index < value.length - 1; index++) {
          values.add(value.substring(index, index + 2));
        }
      } else if (value.length >= 2) {
        values.add(value);
      }
    }
    return values.map((value) => RegExp(RegExp.escape(value))).toList();
  }

  static String _normalizeForSearch(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(RegExp(r'[^a-z0-9_\u4e00-\u9fff]'), '');

  static String _stripMarkup(String raw) => raw
      .replaceAll(
        RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
        ' ',
      )
      .replaceAll(
        RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false),
        ' ',
      )
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</(?:p|div|h[1-6]|li)>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAllMapped(
        RegExp(r'&#(\d+);'),
        (match) => String.fromCharCode(int.tryParse(match.group(1) ?? '') ?? 32),
      );

  static String _cleanText(String value) => value
      .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\uFFFD]'), ' ')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r' *\n *'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  static bool _looksReadable(String value) {
    final text = value.trim();
    if (text.length < 2) return false;
    final readable = RegExp(r'[A-Za-z0-9\u4e00-\u9fff]')
        .allMatches(text)
        .length;
    return readable >= (text.length * 0.3).ceil();
  }

  static Uint8List _archiveBytes(ArchiveFile file) {
    final content = file.content;
    if (content is Uint8List) return content;
    if (content is List<int>) return Uint8List.fromList(content);
    return Uint8List(0);
  }
}

class _ParsedBook {
  const _ParsedBook({required this.sections, required this.partial});

  final List<_ParsedSection> sections;
  final bool partial;

  int get characterCount =>
      sections.fold<int>(0, (total, section) => total + section.text.length);
}

class _ParsedSection {
  const _ParsedSection({
    required this.title,
    required this.text,
    this.locatorPrefix = '',
  });

  final String title;
  final String text;
  final String locatorPrefix;
}
