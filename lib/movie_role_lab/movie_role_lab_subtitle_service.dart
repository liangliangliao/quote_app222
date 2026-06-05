import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'movie_role_lab_config.dart';
import 'movie_role_lab_models.dart';

class OpenSubtitleCandidate {
  final int fileId;
  final String subtitleId;
  final String language;
  final String fileName;
  final double rating;
  final int downloads;

  const OpenSubtitleCandidate({
    required this.fileId,
    required this.subtitleId,
    required this.language,
    required this.fileName,
    required this.rating,
    required this.downloads,
  });
}

class MovieRoleLabSubtitleService {
  static const String _baseUrl = 'https://api.opensubtitles.com/api/v1';

  Future<MovieRoleLabSubtitleEvidence> loadEvidenceForMovie({
    required MovieRoleLabConfig config,
    required int tmdbMovieId,
    required String imdbId,
    required MovieRoleLabCharacter character,
    required List<MovieRoleLabCharacter> ensemble,
  }) async {
    if (!config.hasOpenSubtitlesSearchAuth) {
      return const MovieRoleLabSubtitleEvidence(
        available: false,
        status: '未配置 OpenSubtitles API Key 或 User-Agent，暂不能拉取真实字幕。',
      );
    }
    if (!config.hasOpenSubtitlesDownloadAuth) {
      return const MovieRoleLabSubtitleEvidence(
        available: false,
        status: '已配置 OpenSubtitles API Key，但未配置用户名/密码；可以搜索字幕，但无法下载真实字幕。',
      );
    }

    final normalizedImdb = _normalizeImdbId(imdbId);
    if (normalizedImdb.isEmpty && tmdbMovieId <= 0) {
      return const MovieRoleLabSubtitleEvidence(
        available: false,
        status: 'TMDb 未返回有效 IMDb ID，无法精确匹配字幕。',
      );
    }

    try {
      final candidates = await searchSubtitles(
        config: config,
        imdbId: normalizedImdb,
        tmdbMovieId: tmdbMovieId,
      );
      if (candidates.isEmpty) {
        return MovieRoleLabSubtitleEvidence(
          available: false,
          status: 'OpenSubtitles 没有找到匹配字幕。IMDb: ${imdbId.isEmpty ? '无' : imdbId}，TMDb: $tmdbMovieId。',
        );
      }
      final selected = candidates.first;
      final token = await login(config);
      final download = await createDownloadLink(config: config, token: token, fileId: selected.fileId);
      final content = await downloadSubtitleText(download.link);
      final cues = SrtSubtitleParser.parse(content);
      if (cues.isEmpty) {
        return MovieRoleLabSubtitleEvidence(
          available: false,
          status: '字幕已下载，但解析不到有效 SRT 时间轴。文件：${selected.fileName}',
          source: 'OpenSubtitles',
          language: selected.language,
          subtitleName: selected.fileName,
        );
      }
      final evidenceCues = selectEvidenceCues(cues, character: character, ensemble: ensemble);
      return MovieRoleLabSubtitleEvidence(
        available: true,
        status: '已从 OpenSubtitles 下载并解析真实字幕。普通字幕通常没有说话人字段，因此角色归属只可推测，不能断言。',
        source: 'OpenSubtitles',
        language: selected.language,
        subtitleName: selected.fileName.isEmpty ? download.fileName : selected.fileName,
        cues: evidenceCues,
        warning: 'AI 只能基于这些真实字幕片段分析场景；如果片段不足，不得编造完整剧本或不存在的台词。',
      );
    } catch (e) {
      return MovieRoleLabSubtitleEvidence(
        available: false,
        status: '真实字幕拉取失败：$e',
      );
    }
  }

  Future<List<OpenSubtitleCandidate>> searchSubtitles({
    required MovieRoleLabConfig config,
    required String imdbId,
    required int tmdbMovieId,
  }) async {
    final languages = config.languageList.join(',');
    final params = <String, String>{
      'languages': languages,
      'order_by': 'download_count',
      'order_direction': 'desc',
    };
    if (imdbId.isNotEmpty) {
      params['imdb_id'] = imdbId;
    } else if (tmdbMovieId > 0) {
      params['tmdb_id'] = tmdbMovieId.toString();
    }
    final uri = Uri.parse('$_baseUrl/subtitles').replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers(config)).timeout(const Duration(seconds: 25));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('字幕搜索失败：${res.statusCode} ${res.body}');
    }
    final decoded = jsonDecode(res.body);
    final data = decoded is Map ? decoded['data'] : null;
    if (data is! List) return const <OpenSubtitleCandidate>[];
    final list = <OpenSubtitleCandidate>[];
    for (final item in data) {
      if (item is! Map) continue;
      final attrs = item['attributes'];
      if (attrs is! Map) continue;
      final files = attrs['files'];
      if (files is! List || files.isEmpty || files.first is! Map) continue;
      final firstFile = files.first as Map;
      final fileId = _asInt(firstFile['file_id']);
      if (fileId <= 0) continue;
      list.add(OpenSubtitleCandidate(
        fileId: fileId,
        subtitleId: (item['id'] ?? '').toString(),
        language: (attrs['language'] ?? '').toString(),
        fileName: (firstFile['file_name'] ?? attrs['release'] ?? _featureTitle(attrs) ?? '').toString(),
        rating: _asDouble(attrs['ratings']),
        downloads: _asInt(attrs['download_count']),
      ));
    }
    final preferred = config.languageList.map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toList();
    int langRank(OpenSubtitleCandidate c) {
      final idx = preferred.indexOf(c.language.trim().toLowerCase());
      return idx < 0 ? 999 : idx;
    }

    list.sort((a, b) {
      final byLang = langRank(a).compareTo(langRank(b));
      if (byLang != 0) return byLang;
      final byDownload = b.downloads.compareTo(a.downloads);
      if (byDownload != 0) return byDownload;
      return b.rating.compareTo(a.rating);
    });
    return list;
  }

  String? _featureTitle(Map attrs) {
    final details = attrs['feature_details'];
    if (details is Map) return details['title']?.toString();
    return null;
  }

  Future<String> login(MovieRoleLabConfig config) async {
    final uri = Uri.parse('$_baseUrl/login');
    final res = await http
        .post(
          uri,
          headers: {
            ..._headers(config),
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'username': config.openSubtitlesUsername.trim(),
            'password': config.openSubtitlesPassword.trim(),
          }),
        )
        .timeout(const Duration(seconds: 25));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('OpenSubtitles 登录失败：${res.statusCode} ${res.body}');
    }
    final decoded = jsonDecode(res.body);
    final token = decoded is Map ? (decoded['token'] ?? '').toString() : '';
    if (token.trim().isEmpty) throw Exception('OpenSubtitles 未返回 token');
    return token.trim();
  }

  Future<OpenSubtitleDownloadLink> createDownloadLink({
    required MovieRoleLabConfig config,
    required String token,
    required int fileId,
  }) async {
    final uri = Uri.parse('$_baseUrl/download');
    final res = await http
        .post(
          uri,
          headers: {
            ..._headers(config),
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'file_id': fileId}),
        )
        .timeout(const Duration(seconds: 25));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('字幕下载链接创建失败：${res.statusCode} ${res.body}');
    }
    final decoded = jsonDecode(res.body);
    final link = decoded is Map ? (decoded['link'] ?? '').toString() : '';
    final fileName = decoded is Map ? (decoded['file_name'] ?? '').toString() : '';
    if (link.trim().isEmpty) throw Exception('OpenSubtitles 未返回字幕下载链接');
    return OpenSubtitleDownloadLink(link: link.trim(), fileName: fileName.trim());
  }

  Future<String> downloadSubtitleText(String link) async {
    final res = await http.get(Uri.parse(link)).timeout(const Duration(seconds: 30));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('字幕文件下载失败：${res.statusCode}');
    }
    return utf8.decode(res.bodyBytes, allowMalformed: true);
  }

  Map<String, String> _headers(MovieRoleLabConfig config) => {
        'Api-Key': config.openSubtitlesApiKey.trim(),
        'User-Agent': config.openSubtitlesUserAgent.trim().isEmpty ? 'MovieRoleLab v1.0' : config.openSubtitlesUserAgent.trim(),
        'Accept': 'application/json',
      };

  List<MovieRoleLabSubtitleCue> selectEvidenceCues(
    List<MovieRoleLabSubtitleCue> all, {
    required MovieRoleLabCharacter character,
    required List<MovieRoleLabCharacter> ensemble,
  }) {
    final clean = all.where((e) => e.text.trim().isNotEmpty).toList();
    if (clean.isEmpty) return const <MovieRoleLabSubtitleCue>[];

    final terms = <String>{
      character.name,
      character.actorName,
      ...character.name.split(RegExp(r'[ /,，:：·・\-]+')),
      ...ensemble.take(8).map((e) => e.name),
    }
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.length >= 2)
        .toList();

    final selectedIndexes = <int>{};
    for (var i = 0; i < clean.length; i++) {
      final text = clean[i].text.toLowerCase();
      if (terms.any((term) => text.contains(term))) {
        for (var j = max(0, i - 4); j <= min(clean.length - 1, i + 6); j++) {
          selectedIndexes.add(j);
        }
      }
      if (selectedIndexes.length >= 24) break;
    }

    if (selectedIndexes.isNotEmpty) {
      final idx = selectedIndexes.toList()..sort();
      return idx.map((i) => clean[i]).take(30).toList();
    }

    final start = clean.indexWhere((e) => e.startMs >= 180000);
    final from = start < 0 ? 0 : start;
    return clean.skip(from).take(28).toList();
  }

  String _normalizeImdbId(String id) {
    final s = id.trim().toLowerCase();
    if (s.isEmpty) return '';
    return s.startsWith('tt') ? s.substring(2) : s;
  }

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }
}

class OpenSubtitleDownloadLink {
  final String link;
  final String fileName;

  const OpenSubtitleDownloadLink({required this.link, required this.fileName});
}

class SrtSubtitleParser {
  static List<MovieRoleLabSubtitleCue> parse(String content) {
    final normalized = content
        .replaceAll('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();
    if (normalized.isEmpty) return const <MovieRoleLabSubtitleCue>[];
    final blocks = normalized.split(RegExp(r'\n\s*\n'));
    final result = <MovieRoleLabSubtitleCue>[];
    for (final block in blocks) {
      final cue = _parseBlock(block);
      if (cue != null) result.add(cue);
    }
    return result;
  }

  static MovieRoleLabSubtitleCue? _parseBlock(String block) {
    final lines = block
        .trim()
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (lines.length < 2) return null;

    var timeIndex = 0;
    final maybeIndex = int.tryParse(lines.first);
    if (maybeIndex != null) timeIndex = 1;
    if (timeIndex >= lines.length || !lines[timeIndex].contains('-->')) return null;

    final parts = lines[timeIndex].split('-->');
    if (parts.length != 2) return null;
    final start = _parseTime(parts[0]);
    final end = _parseTime(parts[1]);
    if (start < 0 || end <= start) return null;

    final text = _clean(lines.skip(timeIndex + 1).join('\n'));
    if (text.trim().isEmpty) return null;
    return MovieRoleLabSubtitleCue(
      cueIndex: maybeIndex ?? 0,
      startMs: start,
      endMs: end,
      text: text,
    );
  }

  static int _parseTime(String value) {
    final cleaned = value.trim().replaceAll('.', ',').split(RegExp(r'\s+')).first;
    final m = RegExp(r'^(\d{1,2}):(\d{2}):(\d{2}),(\d{1,3})$').firstMatch(cleaned);
    if (m == null) return -1;
    final h = int.tryParse(m.group(1) ?? '') ?? 0;
    final min = int.tryParse(m.group(2) ?? '') ?? 0;
    final sec = int.tryParse(m.group(3) ?? '') ?? 0;
    final ms = int.tryParse((m.group(4) ?? '0').padRight(3, '0').substring(0, 3)) ?? 0;
    return h * 3600000 + min * 60000 + sec * 1000 + ms;
  }

  static String _clean(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'\{\\.*?\}'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join('\n')
        .trim();
  }
}
