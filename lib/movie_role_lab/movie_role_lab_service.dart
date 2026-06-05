import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../concept_engine/concept_engine_service.dart';
import '../data/kv_dao.dart';
import '../services/global_ai_settings.dart';
import '../services/tmdb_service.dart';
import '../services/unified_ai_service.dart';
import 'movie_role_lab_config.dart';
import 'movie_role_lab_models.dart';
import 'movie_role_lab_subtitle_dao.dart';
import 'movie_role_lab_subtitle_service.dart';

class MovieRoleLabService {
  final KeyValueDao _kvDao = KeyValueDao();
  final MovieRoleLabConfigStore _configStore = MovieRoleLabConfigStore();
  final MovieRoleLabSubtitleService _subtitleService = MovieRoleLabSubtitleService();
  final MovieRoleLabSubtitleDao _subtitleDao = MovieRoleLabSubtitleDao();
  final ConceptEngineService _conceptConfig = ConceptEngineService();
  final GlobalAiSettings _globalAiSettings = GlobalAiSettings();
  final UnifiedAiService _unifiedAiService = UnifiedAiService();
  final Random _random = Random();

  Future<List<MovieRoleLabMovie>> searchMovies(String query) async {
    final cfg = await _configStore.load();
    final res = await TMDbService(token: cfg.tmdbReadToken, apiKey: cfg.tmdbApiKey).searchMovies(query: query, page: 1);
    final rawResults = (res['results'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final list = rawResults
        .map((e) => MovieRoleLabMovie.fromTmdb(e))
        .where((e) => e.id > 0)
        .toList();
    await _subtitleDao.saveSearchResults(query: query, movies: list, rawResults: rawResults);
    return list;
  }

  Future<List<MovieRoleLabSearchHistoryItem>> loadSearchHistory({int limit = 80}) {
    return _subtitleDao.loadSearchHistory(limit: limit);
  }

  Future<List<MovieRoleLabCharacter>> fetchMovieCharacters(int movieId) async {
    final cfg = await _configStore.load();
    final res = await TMDbService(token: cfg.tmdbReadToken, apiKey: cfg.tmdbApiKey).movieCredits(movieId);
    final list = (res['cast'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => MovieRoleLabCharacter.fromTmdb(Map<String, dynamic>.from(e)))
        .where((e) => e.name.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return list.take(20).toList();
  }

  Future<List<MovieRoleLabEpisode>> loadEpisodes(MovieRoleLabMovie movie) {
    return _subtitleDao.loadEpisodesByMovieId(movie.id);
  }

  Future<void> clearEpisodes(MovieRoleLabMovie movie) {
    return _subtitleDao.clearEpisodesByMovieId(movie.id);
  }

  Future<void> deleteEpisode(int episodeId) {
    return _subtitleDao.deleteEpisode(episodeId);
  }

  Future<List<MovieRoleLabEpisode>> generateOrLoadEpisodes({
    required MovieRoleLabMovie movie,
    required List<MovieRoleLabCharacter> ensemble,
    bool forceRegenerate = false,
    bool replaceExisting = false,
  }) async {
    final existing = await _subtitleDao.loadEpisodesByMovieId(movie.id);
    if (existing.isNotEmpty && !replaceExisting) {
      throw Exception('该电影已经存在分集剧本。若要重新调用 AI，请在确认弹窗中允许自动清空旧分集后再继续。');
    }
    if (existing.isNotEmpty && replaceExisting) {
      await _subtitleDao.clearEpisodesByMovieId(movie.id);
    }

    final subtitle = await importOrLoadFullSubtitle(movie);
    final mainCharacter = _resolveMainCharacterName(ensemble);
    // 大模型给“整部电影逐行配角色+分集”是非常重的任务。
    // 之前 90 行字幕一块时，OpenRouter/gpt-oss 免费模型经常 HTTP 200
    // 但 message.content=null，或输出 JSON 被截断。这里把块降到 24 行，
    // 并允许单块失败后继续处理其它块，避免一个空响应导致整部电影失败。
    final chunks = _subtitleCueChunks(subtitle.cues, chunkSize: 60);
    final parsedAll = <MovieRoleLabEpisode>[];
    final failedChunks = <String>[];

    for (var chunkIndex = 0; chunkIndex < chunks.length; chunkIndex++) {
      final chunk = chunks[chunkIndex];
      if (chunk.isEmpty) continue;
      // Do not hammer OpenRouter/upstream providers with many back-to-back
      // JSON calls. This reduces provider-level 429 errors.
      if (chunkIndex > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 1800));
      }
      try {
        final parsed = await _generateEpisodeChunkWithRecovery(
          movie: movie,
          ensemble: ensemble,
          subtitle: subtitle,
          mainCharacter: mainCharacter,
          chunk: chunk,
          chunkIndex: chunkIndex,
          chunkCount: chunks.length,
          totalCueCount: subtitle.cues.length,
        );
        if (parsed.isNotEmpty) {
          parsedAll.addAll(parsed);
        } else {
          failedChunks.add('${chunkIndex + 1}/${chunks.length}');
        }
      } catch (e) {
        if (_isRateLimitError(e)) {
          throw Exception('OpenRouter upstream model is temporarily rate-limited. Please retry later, switch to another OpenRouter model, or configure BYOK. Original error: $e');
        }
        failedChunks.add('${chunkIndex + 1}/${chunks.length}: $e');
      }
    }

    if (parsedAll.isEmpty) {
      throw Exception('AI 返回中没有解析到 episodes。可能原因：当前模型返回 message.content=null、JSON 被截断，或模型不兼容严格 JSON 输出。建议先换用非免费/非推理模型，或使用“导入TXT分集剧本”。');
    }

    parsedAll.sort((a, b) {
      final c = a.startMs.compareTo(b.startMs);
      if (c != 0) return c;
      return a.episodeIndex.compareTo(b.episodeIndex);
    });
    final reindexed = _reindexEpisodes(parsedAll, startEpisodeIndex: 1);
    return _subtitleDao.saveEpisodesForMovie(movieId: movie.id, episodes: reindexed);
  }





  bool _isRateLimitError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('http 429') ||
        text.contains('rate-limited') ||
        text.contains('rate limited') ||
        text.contains('temporarily rate') ||
        text.contains('too many requests');
  }

  Future<List<MovieRoleLabEpisode>> _generateEpisodeChunkWithRecovery({
    required MovieRoleLabMovie movie,
    required List<MovieRoleLabCharacter> ensemble,
    required MovieRoleLabStoredSubtitle subtitle,
    required String mainCharacter,
    required List<MovieRoleLabSubtitleCue> chunk,
    required int chunkIndex,
    required int chunkCount,
    required int totalCueCount,
  }) async {
    final parsed = await _generateEpisodeChunkOnce(
      movie: movie,
      ensemble: ensemble,
      subtitle: subtitle,
      mainCharacter: mainCharacter,
      chunk: chunk,
      chunkIndex: chunkIndex,
      chunkCount: chunkCount,
      totalCueCount: totalCueCount,
      logSuffix: '${chunkIndex + 1}_of_$chunkCount',
      maxTokens: 1600,
    );
    if (parsed.isNotEmpty || chunk.length <= 10) return parsed;

    // 如果一个 24 行块仍然出现空响应/截断，就拆成更小的 8 行块重试。
    // 这会增加调用次数，但可以显著降低输出 JSON 被截断的概率。
    final recovered = <MovieRoleLabEpisode>[];
    final subChunks = _subtitleCueChunks(chunk, chunkSize: 20);
    for (var i = 0; i < subChunks.length; i++) {
      final sub = subChunks[i];
      final subParsed = await _generateEpisodeChunkOnce(
        movie: movie,
        ensemble: ensemble,
        subtitle: subtitle,
        mainCharacter: mainCharacter,
        chunk: sub,
        chunkIndex: chunkIndex,
        chunkCount: chunkCount,
        totalCueCount: totalCueCount,
        logSuffix: '${chunkIndex + 1}_${i + 1}_of_${subChunks.length}',
        maxTokens: 900,
      );
      recovered.addAll(subParsed);
    }
    return recovered;
  }

  Future<List<MovieRoleLabEpisode>> _generateEpisodeChunkOnce({
    required MovieRoleLabMovie movie,
    required List<MovieRoleLabCharacter> ensemble,
    required MovieRoleLabStoredSubtitle subtitle,
    required String mainCharacter,
    required List<MovieRoleLabSubtitleCue> chunk,
    required int chunkIndex,
    required int chunkCount,
    required int totalCueCount,
    required String logSuffix,
    required int maxTokens,
  }) async {
    if (chunk.isEmpty) return <MovieRoleLabEpisode>[];
    final userPayload = <String, dynamic>{
      'movie': movie.toJson(),
      'movie_background': movie.overview,
      'required_main_character': mainCharacter,
      'characters': ensemble.map((e) => e.toJson()).toList(),
      'subtitle': {
        'source': subtitle.source,
        'language': subtitle.language,
        'name': subtitle.subtitleName,
        'total_cue_count': totalCueCount,
        'current_chunk_index': chunkIndex + 1,
        'current_chunk_count': chunkCount,
        'current_chunk_start_cue_index': chunk.first.cueIndex,
        'current_chunk_end_cue_index': chunk.last.cueIndex,
        'current_chunk_start_time': chunk.first.startLabel,
        'current_chunk_end_time': chunk.last.endLabel,
      },
      'task': '只处理 current_chunk 对应的字幕范围：逐行推断说话角色，并在该范围内划分一个或多个连续剧情片段。每条 lines.text 必须来自当前字幕块原文。',
    };

    final prompt = _globalAiSettings.renderTemplate(
      await _globalAiSettings.getMovieRoleLabEpisodePrompt(),
      <String, String>{
        'movie_id': movie.id.toString(),
        'movie_title': movie.title,
        'movie_overview': movie.overview,
        'movie_release_date': movie.releaseDate,
        'main_character_name': mainCharacter,
        'ensemble_json': _encodePretty(ensemble.map((e) => e.toJson()).toList()),
        'full_subtitle_text': _subtitleChunkToDisplayText(
          chunk,
          chunkIndex: chunkIndex + 1,
          chunkCount: chunkCount,
          totalCueCount: totalCueCount,
        ),
        'movie_episode_input_json': _encodePretty(userPayload),
      },
    );
    try {
      final raw = await _runTextTask(
        logModule: 'movie_role_lab.episode_script.chunk_$logSuffix',
        systemPrompt: '$prompt\n\n【本次调用特别要求】只返回当前字幕块内的 episodes。不要等待处理整部电影。不要输出推理过程、解释、Markdown 或代码块；第一个字符必须是 {，最后一个字符必须是 }；顶层必须是 {"episodes":[...]}。为避免输出被截断，lines 里不要输出 text 字段，App 会按 cue_index 从本地字幕回填原文；每条 line 只输出 line_index、cue_index、character_name_zh、character_name_en、confidence、source。每个字幕块最多 1 到 3 个 episodes。如果无法判断角色，也要返回 Unknown，不要空答。',
        userPayload: userPayload,
        maxTokens: maxTokens,
        expectJson: true,
      );
      final parsed = _decodeEpisodesFromRaw(
        raw,
        movie: movie,
        ensemble: ensemble,
        subtitle: subtitle,
      );
      return parsed;
    } catch (e) {
      // Normal per-chunk parse failures should not abort the whole movie.
      // Rate-limit errors are different: do not split/retry more chunks or it
      // will amplify a provider-level 429 into many more requests.
      if (_isRateLimitError(e)) rethrow;
      return <MovieRoleLabEpisode>[];
    }
  }

  Future<List<MovieRoleLabEpisode>> importEpisodesFromTxtContents({
    required MovieRoleLabMovie movie,
    required List<MovieRoleLabCharacter> ensemble,
    required List<String> contents,
    int startEpisodeIndex = 1,
  }) async {
    final existing = await _subtitleDao.loadEpisodesByMovieId(movie.id);
    final parsed = <MovieRoleLabEpisode>[];
    var nextIndex = startEpisodeIndex <= 0 ? 1 : startEpisodeIndex;
    for (final content in contents) {
      final text = content.trim();
      if (text.isEmpty) continue;
      final jsonEpisodes = _tryDecodeEpisodesFromImportedJson(
        text,
        movie: movie,
        ensemble: ensemble,
        startEpisodeIndex: nextIndex,
      );
      if (jsonEpisodes.isNotEmpty) {
        parsed.addAll(jsonEpisodes);
        nextIndex = parsed.map((e) => e.episodeIndex).fold(nextIndex, (a, b) => b >= a ? b + 1 : a);
        continue;
      }
      final textEpisodes = _decodeEpisodesFromPlainText(
        text,
        movie: movie,
        ensemble: ensemble,
        startEpisodeIndex: nextIndex,
      );
      parsed.addAll(textEpisodes);
      nextIndex = parsed.map((e) => e.episodeIndex).fold(nextIndex, (a, b) => b >= a ? b + 1 : a);
    }
    if (parsed.isEmpty) {
      throw Exception('没有从 TXT 中解析到有效分集剧本。请使用“第1集：标题”或“[00:00:00 - 00:00:03] 角色：台词”这类格式。');
    }
    parsed.sort((a, b) {
      final c = a.episodeIndex.compareTo(b.episodeIndex);
      return c != 0 ? c : a.startMs.compareTo(b.startMs);
    });
    _validateNoDuplicateImportedEpisodes(existing, parsed);
    return _subtitleDao.appendEpisodesForMovie(movieId: movie.id, episodes: parsed);
  }

  List<MovieRoleLabEpisode> _tryDecodeEpisodesFromImportedJson(
    String raw, {
    required MovieRoleLabMovie movie,
    required List<MovieRoleLabCharacter> ensemble,
    required int startEpisodeIndex,
  }) {
    try {
      final decoded = jsonDecode(raw.replaceAll('```json', '').replaceAll('```', '').trim());
      final wrapper = decoded is List ? <String, dynamic>{'episodes': decoded} : Map<String, dynamic>.from(decoded as Map);
      final fakeSubtitle = MovieRoleLabStoredSubtitle(
        id: 0,
        movieId: movie.id,
        movieTitle: movie.title,
        imdbId: '',
        source: 'Imported TXT/JSON',
        language: 'mixed',
        subtitleName: 'imported_episode_script',
        importedAtMs: DateTime.now().millisecondsSinceEpoch,
        cues: const <MovieRoleLabSubtitleCue>[],
      );
      final episodes = _decodeEpisodesFromJson(wrapper, movie: movie, ensemble: ensemble, subtitle: fakeSubtitle);
      return episodes.map((e) => MovieRoleLabEpisode(
            movieId: e.movieId,
            episodeIndex: startEpisodeIndex + episodes.indexOf(e),
            title: e.title,
            summary: e.summary,
            previousContext: e.previousContext,
            startMs: e.startMs,
            endMs: e.endMs,
            roles: e.roles,
            lines: e.lines,
          )).toList();
    } catch (_) {
      return <MovieRoleLabEpisode>[];
    }
  }

  List<MovieRoleLabEpisode> _decodeEpisodesFromPlainText(
    String raw, {
    required MovieRoleLabMovie movie,
    required List<MovieRoleLabCharacter> ensemble,
    required int startEpisodeIndex,
  }) {
    final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    final matches = RegExp(r'(?=^\s*第\s*\d+\s*[集回幕场][：:\.、\s-]*)', multiLine: true).allMatches(normalized).toList();
    final parts = <String>[];
    if (matches.length <= 1) {
      parts.add(normalized);
    } else {
      for (var i = 0; i < matches.length; i++) {
        final start = matches[i].start;
        final end = i + 1 < matches.length ? matches[i + 1].start : normalized.length;
        final part = normalized.substring(start, end).trim();
        if (part.isNotEmpty) parts.add(part);
      }
    }

    final episodes = <MovieRoleLabEpisode>[];
    for (var i = 0; i < parts.length; i++) {
      final episode = _parsePlainTextEpisode(
        parts[i],
        movie: movie,
        ensemble: ensemble,
        episodeIndex: startEpisodeIndex + i,
      );
      if (episode != null) episodes.add(episode);
    }
    return episodes;
  }

  MovieRoleLabEpisode? _parsePlainTextEpisode(
    String part, {
    required MovieRoleLabMovie movie,
    required List<MovieRoleLabCharacter> ensemble,
    required int episodeIndex,
  }) {
    final linesRaw = part.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (linesRaw.isEmpty) return null;

    var title = '导入片段 $episodeIndex';
    var previousContext = '';
    var summary = '';
    final titleMatch = RegExp(r'^第\s*(\d+)\s*[集回幕场][：:\.、\s-]*(.*)$').firstMatch(linesRaw.first);
    if (titleMatch != null) {
      // 用户在导入前指定的保存序列优先于 TXT 内部标题数字，避免本地文件中的“第1集”覆盖用户指定顺序。
      final t = (titleMatch.group(2) ?? '').trim();
      if (t.isNotEmpty) title = t;
    } else if (RegExp(r'^(标题|片段|集名|名称)[：:]').hasMatch(linesRaw.first)) {
      title = linesRaw.first.replaceFirst(RegExp(r'^(标题|片段|集名|名称)[：:]\s*'), '').trim();
    } else {
      title = linesRaw.first.length > 28 ? '${linesRaw.first.substring(0, 28)}…' : linesRaw.first;
    }

    final scriptLines = <MovieRoleLabScriptLine>[];
    final summaryLines = <String>[];
    for (final rawLine in linesRaw) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (RegExp(r'^第\s*\d+\s*[集回幕场]').hasMatch(line)) continue;
      final prevMatch = RegExp(r'^(上回|前情|前情提示|previous_context)[：:]\s*(.*)$', caseSensitive: false).firstMatch(line);
      if (prevMatch != null) {
        previousContext = (prevMatch.group(2) ?? '').trim();
        continue;
      }
      final sumMatch = RegExp(r'^(剧情内容|剧情概述|summary|内容)[：:]\s*(.*)$', caseSensitive: false).firstMatch(line);
      if (sumMatch != null) {
        final v = (sumMatch.group(2) ?? '').trim();
        if (v.isNotEmpty) summaryLines.add(v);
        continue;
      }
      if (RegExp(r'^(本集参演角色|参演角色|角色名单|剧本预览|剧本内容|台词)[：:]?', caseSensitive: false).hasMatch(line)) {
        continue;
      }
      final parsed = _parsePlainScriptLine(line, scriptLines.length + 1, ensemble);
      if (parsed != null) {
        scriptLines.add(parsed);
      } else if (scriptLines.isEmpty && summaryLines.length < 6) {
        summaryLines.add(line);
      }
    }

    if (scriptLines.isEmpty) {
      var idx = 0;
      for (final line in linesRaw.skip(1)) {
        if (line.trim().isEmpty) continue;
        idx++;
        scriptLines.add(MovieRoleLabScriptLine(
          lineIndex: idx,
          characterName: 'Unknown',
          characterNameZh: '未知角色',
          characterNameEn: 'Unknown',
          text: line,
          confidence: 'low',
          source: 'imported_txt_unstructured',
        ));
      }
    }
    if (scriptLines.isEmpty) return null;

    final roles = _episodeRolesFromLines(<String, dynamic>{}, scriptLines, ensemble);
    summary = summaryLines.join('\n').trim();
    if (summary.isEmpty) {
      summary = '本集由本地 TXT 导入，包含 ${scriptLines.length} 句台词；请以剧本内容为准进行角色练习。';
    }
    return MovieRoleLabEpisode(
      movieId: movie.id,
      episodeIndex: episodeIndex,
      title: title.trim().isEmpty ? '导入片段 $episodeIndex' : title.trim(),
      summary: summary,
      previousContext: previousContext,
      startMs: scriptLines.first.startMs,
      endMs: scriptLines.last.endMs,
      roles: roles,
      lines: scriptLines,
    );
  }

  MovieRoleLabScriptLine? _parsePlainScriptLine(String rawLine, int lineIndex, List<MovieRoleLabCharacter> ensemble) {
    final patterns = <RegExp>[
      RegExp(r'^\[(\d{1,2}:\d{2}:\d{2})(?:\s*-\s*(\d{1,2}:\d{2}:\d{2}))?\]\s*(.+?)[：:]\s*(.+)$'),
      RegExp(r'^(\d{1,2}:\d{2}:\d{2})(?:\s*-\s*(\d{1,2}:\d{2}:\d{2}))?\s+(.+?)[：:]\s*(.+)$'),
      RegExp(r'^(.+?)[：:]\s*(.+)$'),
    ];
    for (final pattern in patterns) {
      final m = pattern.firstMatch(rawLine);
      if (m == null) continue;
      var start = 0;
      var end = 0;
      var speaker = '';
      var text = '';
      if (m.groupCount >= 4) {
        start = _parseHmsToMs(m.group(1) ?? '');
        end = _parseHmsToMs(m.group(2) ?? '') == 0 ? start : _parseHmsToMs(m.group(2) ?? '');
        speaker = (m.group(3) ?? '').trim();
        text = (m.group(4) ?? '').trim();
      } else {
        speaker = (m.group(1) ?? '').trim();
        text = (m.group(2) ?? '').trim();
      }
      if (speaker.isEmpty || text.isEmpty) return null;
      final names = _splitImportedSpeakerName(speaker);
      return MovieRoleLabScriptLine(
        lineIndex: lineIndex,
        startMs: start,
        endMs: end == 0 ? start : end,
        characterName: names['name'] ?? speaker,
        characterNameZh: names['zh'] ?? '',
        characterNameEn: names['en'] ?? '',
        text: text,
        confidence: 'high',
        source: 'imported_txt_user_provided',
      );
    }
    return null;
  }

  Map<String, String> _splitImportedSpeakerName(String speaker) {
    final cleaned = speaker.replaceAll(RegExp(r'^[-•\s]+'), '').trim();
    final parts = cleaned.split(RegExp(r'\s*/\s*|（|\(|）|\)')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    var zh = '';
    var en = '';
    for (final p in parts) {
      if (RegExp(r'[\u4e00-\u9fff]').hasMatch(p) && zh.isEmpty) zh = p;
      if (RegExp(r'[A-Za-z]').hasMatch(p) && en.isEmpty) en = p;
    }
    return {
      'name': en.isNotEmpty ? en : (zh.isNotEmpty ? zh : cleaned),
      'zh': zh,
      'en': en,
    };
  }

  int _parseHmsToMs(String value) {
    final m = RegExp(r'^(\d{1,2}):(\d{2}):(\d{2})$').firstMatch(value.trim());
    if (m == null) return 0;
    final h = int.tryParse(m.group(1) ?? '0') ?? 0;
    final min = int.tryParse(m.group(2) ?? '0') ?? 0;
    final sec = int.tryParse(m.group(3) ?? '0') ?? 0;
    return ((h * 3600) + (min * 60) + sec) * 1000;
  }

  String _resolveMainCharacterName(List<MovieRoleLabCharacter> ensemble) {
    for (final c in ensemble) {
      final n = c.name.toLowerCase();
      if (n.contains('chris') && n.contains('gardner')) return 'Chris Gardner（克里斯·迦纳）';
    }
    if (ensemble.isNotEmpty) return ensemble.first.name;
    return 'Chris Gardner（克里斯·迦纳）';
  }

  List<List<MovieRoleLabSubtitleCue>> _subtitleCueChunks(
    List<MovieRoleLabSubtitleCue> cues, {
    int chunkSize = 90,
  }) {
    if (cues.isEmpty) return const <List<MovieRoleLabSubtitleCue>>[];
    final safeSize = chunkSize <= 0 ? 90 : chunkSize;
    final chunks = <List<MovieRoleLabSubtitleCue>>[];
    for (var start = 0; start < cues.length; start += safeSize) {
      final end = min(start + safeSize, cues.length);
      chunks.add(cues.sublist(start, end));
    }
    return chunks;
  }

  String _subtitleChunkToDisplayText(
    List<MovieRoleLabSubtitleCue> cues, {
    required int chunkIndex,
    required int chunkCount,
    required int totalCueCount,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('【当前字幕块】第 $chunkIndex / $chunkCount 块；本块 ${cues.length} 行；整部电影共 $totalCueCount 行。');
    if (cues.isNotEmpty) {
      buffer.writeln('【本块时间范围】${cues.first.timeRangeLabel} 到 ${cues.last.timeRangeLabel}');
    }
    buffer.writeln('【注意】本次只处理下面这些字幕行，必须保持 cue_index、时间顺序和台词原文，不要跨块补写。');
    buffer.writeln('');
    for (final cue in cues) {
      buffer.writeln('[cue_index=${cue.cueIndex}] [${cue.timeRangeLabel}] ${cue.text}');
      buffer.writeln();
    }
    return buffer.toString().trimRight();
  }

  List<MovieRoleLabEpisode> _reindexEpisodes(
    List<MovieRoleLabEpisode> episodes, {
    required int startEpisodeIndex,
  }) {
    final result = <MovieRoleLabEpisode>[];
    for (var i = 0; i < episodes.length; i++) {
      final ep = episodes[i];
      result.add(MovieRoleLabEpisode(
        id: ep.id,
        movieId: ep.movieId,
        episodeIndex: startEpisodeIndex + i,
        title: ep.title.trim().isEmpty ? '片段 ${startEpisodeIndex + i}' : ep.title,
        summary: ep.summary,
        previousContext: ep.previousContext,
        startMs: ep.startMs,
        endMs: ep.endMs,
        createdAtMs: ep.createdAtMs,
        roles: ep.roles,
        lines: ep.lines,
      ));
    }
    return result;
  }

  void _validateNoDuplicateImportedEpisodes(
    List<MovieRoleLabEpisode> existing,
    List<MovieRoleLabEpisode> incoming,
  ) {
    final existingIndexes = existing.map((e) => e.episodeIndex).toSet();
    final incomingIndexes = <int>{};
    final existingFingerprints = existing.map(_episodeFingerprint).where((e) => e.isNotEmpty).toSet();
    final incomingFingerprints = <String>{};

    for (final ep in incoming) {
      if (existingIndexes.contains(ep.episodeIndex)) {
        throw Exception('导入失败：第${ep.episodeIndex}集已经存在。请在导入前重新指定剧本序列，或删除/清空冲突分集。');
      }
      if (!incomingIndexes.add(ep.episodeIndex)) {
        throw Exception('导入失败：本次导入内容里存在重复的第${ep.episodeIndex}集。');
      }
      final fp = _episodeFingerprint(ep);
      if (fp.isEmpty) continue;
      if (existingFingerprints.contains(fp)) {
        throw Exception('导入失败：检测到与本地已保存分集重复的剧本内容：第${ep.episodeIndex}集《${ep.title}》。');
      }
      if (!incomingFingerprints.add(fp)) {
        throw Exception('导入失败：本次选择的 TXT 中存在重复分集内容：第${ep.episodeIndex}集《${ep.title}》。');
      }
    }
  }

  String _episodeFingerprint(MovieRoleLabEpisode episode) {
    final text = episode.lines
        .map((line) => '${line.displaySpeaker}:${line.text}')
        .join('\n')
        .trim();
    if (text.isEmpty) return '';
    return _looseKey('${episode.title}\n$text');
  }

  String _looseKey(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]+'), '')
        .trim();
  }

  List<MovieRoleLabEpisode> _decodeEpisodesFromRaw(
    String raw, {
    required MovieRoleLabMovie movie,
    required List<MovieRoleLabCharacter> ensemble,
    required MovieRoleLabStoredSubtitle subtitle,
  }) {
    var cleaned = raw.replaceAll('```json', '').replaceAll('```', '').trim();
    // Defensive repair: if an older streaming path passes an SSE transcript here,
    // extract the final assistant content before attempting jsonDecode.
    if (cleaned.contains('data:') && cleaned.contains('choices')) {
      final extracted = UnifiedAiService.extractFinalTextFromSseStream(cleaned).trim();
      if (extracted.isNotEmpty) {
        cleaned = extracted.replaceAll('```json', '').replaceAll('```', '').trim();
      }
    }
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map) {
        return _decodeEpisodesFromJson(Map<String, dynamic>.from(decoded), movie: movie, ensemble: ensemble, subtitle: subtitle);
      }
      if (decoded is List) {
        return _decodeEpisodesFromJson({'episodes': decoded}, movie: movie, ensemble: ensemble, subtitle: subtitle);
      }
    } catch (_) {
      // 继续尝试抽取第一个 JSON 对象。
    }
    try {
      final obj = _decodeObject(cleaned);
      return _decodeEpisodesFromJson(obj, movie: movie, ensemble: ensemble, subtitle: subtitle);
    } catch (_) {
      final partial = _decodePartialEpisodesFromBrokenJson(cleaned, movie: movie, ensemble: ensemble, subtitle: subtitle);
      if (partial.isNotEmpty) return partial;
      return <MovieRoleLabEpisode>[];
    }
  }

  List<MovieRoleLabEpisode> _decodePartialEpisodesFromBrokenJson(
    String raw, {
    required MovieRoleLabMovie movie,
    required List<MovieRoleLabCharacter> ensemble,
    required MovieRoleLabStoredSubtitle subtitle,
  }) {
    if (!raw.contains('line_index') && !raw.contains('cue_index')) {
      return <MovieRoleLabEpisode>[];
    }
    final lineMaps = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final match in RegExp(r'\{[^{}]*(?:"line_index"|"cue_index")[^{}]*\}').allMatches(raw)) {
      final piece = match.group(0);
      if (piece == null || piece.isEmpty || !seen.add(piece)) continue;
      try {
        final decoded = jsonDecode(piece);
        if (decoded is Map) {
          lineMaps.add(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {
        // Ignore one malformed line object and keep salvaging earlier complete lines.
      }
    }
    if (lineMaps.isEmpty) return <MovieRoleLabEpisode>[];

    final firstCue = _intOf(lineMaps.first['cue_index'] ?? lineMaps.first['subtitle_index'] ?? lineMaps.first['index'], 1);
    final lastCue = _intOf(lineMaps.last['cue_index'] ?? lineMaps.last['subtitle_index'] ?? lineMaps.last['index'], firstCue);
    final title = _extractJsonStringField(raw, 'title') ?? 'AI部分分集片段';
    final summary = _extractJsonStringField(raw, 'summary') ?? 'AI 返回 JSON 被截断，已保留其中可解析的连续台词。';
    final previousContext = _extractJsonStringField(raw, 'previous_context') ?? '';
    final wrapper = <String, dynamic>{
      'episodes': <Map<String, dynamic>>[
        <String, dynamic>{
          'episode_index': _extractJsonIntField(raw, 'episode_index') ?? 1,
          'title': title,
          'previous_context': previousContext,
          'summary': summary,
          'start_ms': subtitle.cues.firstWhere((e) => e.cueIndex == firstCue, orElse: () => subtitle.cues.isNotEmpty ? subtitle.cues.first : const MovieRoleLabSubtitleCue(cueIndex: 0, startMs: 0, endMs: 0, text: '')).startMs,
          'end_ms': subtitle.cues.firstWhere((e) => e.cueIndex == lastCue, orElse: () => subtitle.cues.isNotEmpty ? subtitle.cues.last : const MovieRoleLabSubtitleCue(cueIndex: 0, startMs: 0, endMs: 0, text: '')).endMs,
          'lines': lineMaps,
        },
      ],
    };
    return _decodeEpisodesFromJson(wrapper, movie: movie, ensemble: ensemble, subtitle: subtitle);
  }

  String? _extractJsonStringField(String raw, String key) {
    final pattern = RegExp('"' + RegExp.escape(key) + r'"\s*:\s*"((?:\\.|[^"\\])*)"');
    final match = pattern.firstMatch(raw);
    if (match == null) return null;
    final value = match.group(1) ?? '';
    try {
      return jsonDecode('"$value"').toString();
    } catch (_) {
      return value;
    }
  }

  int? _extractJsonIntField(String raw, String key) {
    final pattern = RegExp('"' + RegExp.escape(key) + r'"\s*:\s*(\d+)');
    final match = pattern.firstMatch(raw);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  List<MovieRoleLabEpisode> _decodeEpisodesFromJson(
    Map<String, dynamic> json, {
    required MovieRoleLabMovie movie,
    required List<MovieRoleLabCharacter> ensemble,
    required MovieRoleLabStoredSubtitle subtitle,
  }) {
    dynamic raw = json['episodes'];
    if (raw == null && json['data'] is Map) raw = (json['data'] as Map)['episodes'];
    if (raw == null && json['result'] is Map) raw = (json['result'] as Map)['episodes'];
    if (raw == null && json['json'] is Map) raw = (json['json'] as Map)['episodes'];
    if (raw == null) {
      final textCarrier = json['content'] ?? json['text'] ?? json['output'] ?? json['message'];
      if (textCarrier != null) {
        final text = textCarrier.toString().trim();
        if (text.isNotEmpty) {
          try {
            final decoded = jsonDecode(_extractFirstJsonObject(text));
            if (decoded is Map && decoded['episodes'] is List) raw = decoded['episodes'];
            if (decoded is List) raw = decoded;
          } catch (_) {
            final imported = _decodeEpisodesFromPlainText(
              text,
              movie: movie,
              ensemble: ensemble,
              startEpisodeIndex: 1,
            );
            if (imported.isNotEmpty) return imported;
          }
        }
      }
    }
    if (raw == null && json['files'] is List) {
      final files = (json['files'] as List).whereType<Map>().toList();
      final collected = <dynamic>[];
      for (final f in files) {
        final content = (f['content'] ?? f['text'] ?? '').toString().trim();
        if (content.isEmpty) continue;
        try {
          final decoded = jsonDecode(_extractFirstJsonObject(content));
          if (decoded is Map && decoded['episodes'] is List) collected.addAll(decoded['episodes'] as List);
          if (decoded is List) collected.addAll(decoded);
        } catch (_) {
          final imported = _decodeEpisodesFromPlainText(
            content,
            movie: movie,
            ensemble: ensemble,
            startEpisodeIndex: collected.length + 1,
          );
          collected.addAll(imported.map((e) => e.toJson()));
        }
      }
      raw = collected;
    }
    if (raw is! List) return <MovieRoleLabEpisode>[];

    final cueByIndex = {for (final cue in subtitle.cues) cue.cueIndex: cue};
    final episodes = <MovieRoleLabEpisode>[];
    for (var i = 0; i < raw.length; i++) {
      final map = raw[i] is Map ? Map<String, dynamic>.from(raw[i] as Map) : <String, dynamic>{};
      final dynamic lineCandidate = map['lines'] ?? map['script_lines'] ?? map['subtitle_lines'];
      final lineRaw = lineCandidate is List ? lineCandidate : const [];
      final lines = <MovieRoleLabScriptLine>[];
      for (var j = 0; j < lineRaw.length; j++) {
        final lm = lineRaw[j] is Map ? Map<String, dynamic>.from(lineRaw[j] as Map) : <String, dynamic>{'text': lineRaw[j].toString()};
        final cueIndex = _intOf(lm['cue_index'] ?? lm['subtitle_index'] ?? lm['index'], j + 1);
        final cue = cueByIndex[cueIndex];
        final text = (lm['text'] ?? lm['subtitle_text'] ?? cue?.text ?? '').toString().trim();
        if (text.isEmpty) continue;
        final names = _normalizeCharacterNames(lm, ensemble);
        lines.add(MovieRoleLabScriptLine(
          lineIndex: _intOf(lm['line_index'], j + 1),
          cueIndex: cueIndex,
          startMs: _intOf(lm['start_ms'], cue?.startMs ?? 0),
          endMs: _intOf(lm['end_ms'], cue?.endMs ?? 0),
          characterName: names['name'] ?? '',
          characterNameZh: names['zh'] ?? '',
          characterNameEn: names['en'] ?? '',
          text: text,
          confidence: (lm['confidence'] ?? lm['speaker_confidence'] ?? 'medium').toString(),
          source: (lm['source'] ?? 'ai_inferred_from_subtitle').toString(),
        ));
      }
      if (lines.isEmpty) continue;
      final roles = _episodeRolesFromLines(map, lines, ensemble);
      episodes.add(MovieRoleLabEpisode(
        movieId: movie.id,
        episodeIndex: _intOf(map['episode_index'] ?? map['index'], i + 1),
        title: (map['title'] ?? map['episode_title'] ?? '片段 ${i + 1}').toString(),
        summary: (map['summary'] ?? map['plot_summary'] ?? map['content'] ?? '').toString(),
        previousContext: (map['previous_context'] ?? map['context'] ?? '').toString(),
        startMs: _intOf(map['start_ms'], lines.first.startMs),
        endMs: _intOf(map['end_ms'], lines.last.endMs),
        roles: roles,
        lines: lines,
      ));
    }
    episodes.sort((a, b) => a.startMs.compareTo(b.startMs));
    return episodes;
  }

  Map<String, String> _normalizeCharacterNames(Map<String, dynamic> lm, List<MovieRoleLabCharacter> ensemble) {
    final rawName = (lm['character_name'] ?? lm['speaker'] ?? lm['role'] ?? '').toString().trim();
    var zh = (lm['character_name_zh'] ?? lm['speaker_zh'] ?? '').toString().trim();
    var en = (lm['character_name_en'] ?? lm['speaker_en'] ?? '').toString().trim();
    var name = rawName;
    if (en.isEmpty && RegExp(r'[A-Za-z]').hasMatch(rawName)) en = rawName;
    if (zh.isEmpty && RegExp(r'[\u4e00-\u9fff]').hasMatch(rawName)) zh = rawName;
    for (final c in ensemble) {
      if (_looseMatch(rawName, c.name) || _looseMatch(en, c.name) || _looseMatch(zh, c.name)) {
        name = c.name;
        en = en.isEmpty ? c.name : en;
        break;
      }
    }
    return {'name': name, 'zh': zh, 'en': en};
  }

  List<MovieRoleLabEpisodeRole> _episodeRolesFromLines(
    Map<String, dynamic> map,
    List<MovieRoleLabScriptLine> lines,
    List<MovieRoleLabCharacter> ensemble,
  ) {
    final roles = <MovieRoleLabEpisodeRole>[];
    final seen = <String>{};
    final dynamic explicitCandidate = map['roles'] ?? map['characters'];
    final explicit = explicitCandidate is List ? explicitCandidate : const [];
    for (final item in explicit) {
      final m = item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{'name': item.toString()};
      final names = _normalizeCharacterNames(m, ensemble);
      final role = _roleFromNames(names, ensemble, roleType: (m['role_type'] ?? '').toString());
      if (seen.add(role.displayName)) roles.add(role);
    }
    for (final line in lines) {
      final role = _roleFromNames({
        'name': line.characterName,
        'zh': line.characterNameZh,
        'en': line.characterNameEn,
      }, ensemble, roleType: 'speaker');
      if (seen.add(role.displayName)) roles.add(role);
    }
    if (roles.isEmpty) {
      roles.add(const MovieRoleLabEpisodeRole(
        name: 'Unknown',
        nameZh: '未知角色',
        nameEn: 'Unknown',
        actorName: '',
        profilePath: null,
        roleType: 'speaker_unconfirmed',
      ));
    }
    return roles;
  }

  MovieRoleLabEpisodeRole _roleFromNames(Map<String, String> names, List<MovieRoleLabCharacter> ensemble, {String roleType = ''}) {
    final name = (names['name'] ?? '').trim();
    final zh = (names['zh'] ?? '').trim();
    final en = (names['en'] ?? '').trim();
    MovieRoleLabCharacter? matched;
    for (final c in ensemble) {
      if (_looseMatch(name, c.name) || _looseMatch(en, c.name) || _looseMatch(zh, c.name)) {
        matched = c;
        break;
      }
    }
    return MovieRoleLabEpisodeRole(
      name: matched?.name ?? name,
      nameZh: zh,
      nameEn: en.isNotEmpty ? en : (matched?.name ?? name),
      actorName: matched?.actorName ?? '',
      profilePath: matched?.profilePath,
      roleType: roleType,
    );
  }

  bool _looseMatch(String a, String b) {
    String n(String v) => v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]+'), '');
    final aa = n(a);
    final bb = n(b);
    if (aa.isEmpty || bb.isEmpty) return false;
    return aa == bb || aa.contains(bb) || bb.contains(aa);
  }

  int _intOf(dynamic value, int fallback) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  List<MovieRoleLabEpisode> _buildFallbackEpisodes({
    required MovieRoleLabMovie movie,
    required List<MovieRoleLabCharacter> ensemble,
    required MovieRoleLabStoredSubtitle subtitle,
    required String reason,
  }) {
    final chunks = <MovieRoleLabEpisode>[];
    final mainName = _resolveMainCharacterName(ensemble);
    const chunkSize = 80;
    for (var start = 0; start < subtitle.cues.length; start += chunkSize) {
      final part = subtitle.cues.skip(start).take(chunkSize).toList();
      if (part.isEmpty) continue;
      final lines = <MovieRoleLabScriptLine>[];
      for (var i = 0; i < part.length; i++) {
        final cue = part[i];
        lines.add(MovieRoleLabScriptLine(
          lineIndex: i + 1,
          cueIndex: cue.cueIndex,
          startMs: cue.startMs,
          endMs: cue.endMs,
          characterName: 'Unknown',
          characterNameZh: '未知角色',
          characterNameEn: 'Unknown',
          text: cue.text,
          confidence: 'low',
          source: 'fallback_unassigned_subtitle',
        ));
      }
      chunks.add(MovieRoleLabEpisode(
        movieId: movie.id,
        episodeIndex: chunks.length + 1,
        title: '待配角色片段 ${chunks.length + 1}',
        summary: 'AI 配角色分集失败，已按字幕时间顺序自动切分。失败原因：$reason',
        previousContext: chunks.isEmpty ? '电影开始。' : '承接上一片段的剧情发展。',
        startMs: part.first.startMs,
        endMs: part.last.endMs,
        roles: [
          MovieRoleLabEpisodeRole(
            name: mainName,
            nameZh: mainName.contains('（') ? mainName.substring(mainName.indexOf('（') + 1, mainName.indexOf('）')) : '',
            nameEn: mainName.split('（').first,
            actorName: '',
            profilePath: null,
            roleType: 'required_main_character',
          ),
          const MovieRoleLabEpisodeRole(
            name: 'Unknown',
            nameZh: '未知角色',
            nameEn: 'Unknown',
            actorName: '',
            profilePath: null,
            roleType: 'speaker_unconfirmed',
          ),
        ],
        lines: lines,
      ));
    }
    return chunks.take(30).toList();
  }


  Future<MovieRoleLabEntryBrief> buildEntryBrief({
    required MovieRoleLabMovie movie,
    required MovieRoleLabCharacter character,
    required List<MovieRoleLabCharacter> ensemble,
    MovieRoleLabEpisode? episode,
  }) async {
    final subtitleEvidence = await _loadSubtitleEvidence(movie: movie, character: character, ensemble: ensemble, episode: episode);
    try {
      final userPayload = <String, dynamic>{
        'movie': movie.toJson(),
        'character': character.toJson(),
        'ensemble': ensemble.take(12).map((e) => e.toJson()).toList(),
        if (episode != null) 'episode': episode.toJson(),
        if (episode != null) 'episode_script_text': episode.toScriptText(),
        'subtitle_evidence': subtitleEvidence.toJson(),
        'task': episode == null
            ? '基于真实字幕证据，为用户生成角色进入仪式。不得编造电影剧本；若字幕证据不足，必须标注不确定。'
            : '基于电影背景与当前片段剧本，为用户生成角色进入仪式。请保持理性分析，不要过度解读。',
      };
      final systemPrompt = _renderMovieRolePrompt(
        _withGroundingGuard(await _globalAiSettings.getMovieRoleLabEntryPrompt()),
        movie: movie,
        character: character,
        ensemble: ensemble,
        userPayload: userPayload,
        subtitleEvidence: subtitleEvidence,
        episode: episode,
      );
      final json = await _runJsonTask(
        logModule: 'movie_role_lab.entry',
        systemPrompt: systemPrompt,
        userPayload: userPayload,
        maxTokens: 1800,
      );
      return MovieRoleLabEntryBrief.fromJson(json, subtitleEvidence: subtitleEvidence);
    } catch (_) {
      return MovieRoleLabEntryBrief(
        title: '进入角色',
        scene: subtitleEvidence.available
            ? '已获取《${movie.title}》当前片段剧本。请结合该片段的实际台词、人物关系和场面压力进入角色；若角色归属来自 AI 推测，请保持不确定性。'
            : '暂未取得《${movie.title}》真实字幕依据，当前只能做角色练习框架，不能声称还原真实剧本。',
        whoYouAre: '你是${character.name}。你可以练习该角色的态度、处境和表达方式，但不能把未核验内容当成电影原台词。',
        whatYouWant: '先根据真实字幕片段理解场景压力，再用自己的话进行练习。',
        whatYouFear: '最需要避免的是把 AI 生成内容误认为电影真实剧本。',
        principles: const ['真实字幕优先', '不足就标不确定', '不编造原台词'],
        directorHint: subtitleEvidence.available
            ? '先阅读下方真实字幕依据，再进入练习；没有说话人信息的台词只可作为场景线索。'
            : '请先回到电影角色实验室搜索页导入并保存完整字幕；配置 OpenSubtitles 与 TMDb 后再重试。',
        openingLine: subtitleEvidence.available && subtitleEvidence.cues.isNotEmpty
            ? '真实字幕片段：${subtitleEvidence.cues.first.text}'
            : '当前没有真实字幕片段，不能生成所谓“原片开场台词”。',
        subtitleEvidence: subtitleEvidence,
      );
    }
  }

  Future<MovieRoleLabTurnResult> playTurn({
    required MovieRoleLabMovie movie,
    required MovieRoleLabCharacter character,
    required List<MovieRoleLabCharacter> ensemble,
    required List<Map<String, String>> history,
    required String userInput,
    required MovieRoleLabSubtitleEvidence subtitleEvidence,
    MovieRoleLabEpisode? episode,
    String dialogueMode = 'free_creative',
    MovieRoleLabScriptLine? expectedLine,
    int dialogueCursor = 0,
  }) async {
    try {
      final userPayload = <String, dynamic>{
        'movie': movie.toJson(),
        'character': character.toJson(),
        'ensemble': ensemble.take(8).map((e) => e.toJson()).toList(),
        'history': history,
        'latest_user_input': userInput,
        'subtitle_evidence': subtitleEvidence.toJson(),
        if (episode != null) 'episode': episode.toJson(),
        if (episode != null) 'episode_script_text': episode.toScriptText(),
        'dialogue_mode': dialogueMode,
        'dialogue_cursor': dialogueCursor,
        if (expectedLine != null) 'expected_user_line': expectedLine.toJson(),
        'task': '继续电影角色练习。三种模式分别处理：exact_script 要求逐字和顺序完全一致；semantic_script 要求用户语义与当前剧本台词高度一致，AI 其他角色台词必须照剧本；free_creative 允许在电影背景和当前片段前提下自由创造。',
      };
      final systemPrompt = _renderMovieRolePrompt(
        _withGroundingGuard(await _globalAiSettings.getMovieRoleLabTurnPrompt()),
        movie: movie,
        character: character,
        ensemble: ensemble,
        history: history,
        latestUserInput: userInput,
        userPayload: userPayload,
        subtitleEvidence: subtitleEvidence,
        episode: episode,
        dialogueMode: dialogueMode,
        expectedLine: expectedLine,
      );
      final json = await _runJsonTask(
        logModule: 'movie_role_lab.turn',
        systemPrompt: systemPrompt,
        userPayload: userPayload,
        maxTokens: 1800,
      );
      return MovieRoleLabTurnResult.fromJson(json);
    } catch (_) {
      return MovieRoleLabTurnResult(
        directorFeedback: subtitleEvidence.available
            ? '继续练习时请只把下方字幕片段当作真实依据；无法确认说话人时不要把它当作某个角色的原台词。'
            : '当前没有真实字幕依据，不能生成所谓电影原台词，只能给练习反馈。',
        castLines: subtitleEvidence.available && subtitleEvidence.cues.length > 1
            ? ['真实字幕片段参考：${subtitleEvidence.cues[1].text}']
            : const ['缺少可核验字幕证据，无法生成电影原台词；请用自己的话继续练习。'],
        innerState: '你需要在角色练习和真实剧本之间保持边界：真实字幕可引用，AI 生成只能作为练习。',
        sceneProgress: '本轮继续以真实字幕证据为边界推进。',
        suggestedActions: const ['先看字幕证据', '标出不确定处', '用自己的话练习'],
        accepted: false,
        stopReason: '缺少可核验字幕证据',
      );
    }
  }


  Future<MovieRoleLabStoredSubtitle?> loadLocalSubtitle(MovieRoleLabMovie movie) async {
    return _subtitleDao.findByMovieId(movie.id);
  }

  Future<MovieRoleLabStoredSubtitle> importOrLoadFullSubtitle(MovieRoleLabMovie movie) async {
    final local = await _subtitleDao.findByMovieId(movie.id);
    if (local != null && local.cues.isNotEmpty) return local;

    final cfg = await _configStore.load();
    if (!cfg.hasTmdbAuth) {
      throw Exception('未配置 TMDb API Key 或 Read Access Token，无法获取 IMDb ID 并精确匹配字幕。');
    }
    if (!cfg.hasOpenSubtitlesSearchAuth) {
      throw Exception('未配置 OpenSubtitles API Key 或 User-Agent，无法搜索字幕。');
    }
    if (!cfg.hasOpenSubtitlesDownloadAuth) {
      throw Exception('未配置 OpenSubtitles 用户名/密码，无法下载字幕。');
    }

    String imdbId = '';
    try {
      final ids = await TMDbService(token: cfg.tmdbReadToken, apiKey: cfg.tmdbApiKey).movieExternalIds(movie.id);
      imdbId = (ids['imdb_id'] ?? '').toString();
    } catch (e) {
      throw Exception('TMDb 外部 ID 获取失败：$e');
    }

    final normalizedImdb = imdbId.trim().toLowerCase().startsWith('tt')
        ? imdbId.trim().substring(2)
        : imdbId.trim();

    final candidates = await _subtitleService.searchSubtitles(
      config: cfg,
      imdbId: normalizedImdb,
      tmdbMovieId: movie.id,
    );
    if (candidates.isEmpty) {
      throw Exception('OpenSubtitles 未找到《${movie.title}》字幕。IMDb: ${imdbId.isEmpty ? '无' : imdbId}，TMDb: ${movie.id}');
    }

    final selected = candidates.first;
    final token = await _subtitleService.login(cfg);
    final download = await _subtitleService.createDownloadLink(
      config: cfg,
      token: token,
      fileId: selected.fileId,
    );
    final content = await _subtitleService.downloadSubtitleText(download.link);
    final cues = SrtSubtitleParser.parse(content);
    if (cues.isEmpty) {
      throw Exception('字幕已下载，但没有解析到有效 SRT 时间轴：${selected.fileName}');
    }

    return _subtitleDao.saveForMovie(
      movie: movie,
      imdbId: imdbId,
      source: 'OpenSubtitles',
      language: selected.language,
      subtitleName: selected.fileName.isEmpty ? download.fileName : selected.fileName,
      cues: cues,
    );
  }

  Future<String> exportSubtitleTxt(MovieRoleLabStoredSubtitle subtitle) {
    return _subtitleDao.exportTxt(subtitle);
  }

  Future<void> saveRecent(MovieRoleLabMovie movie, MovieRoleLabCharacter character) async {
    final current = await loadRecent();
    final updated = <MovieRoleLabRecentExperience>[
      MovieRoleLabRecentExperience(
        movie: movie,
        character: character,
        updatedAt: DateTime.now().toIso8601String(),
      ),
      ...current.where((e) => !(e.movie.id == movie.id && e.character.name == character.name)),
    ].take(8).toList();
    await _kvDao.setString('movie_role_lab_recent', jsonEncode(updated.map((e) => e.toJson()).toList()));
  }

  Future<List<MovieRoleLabRecentExperience>> loadRecent() async {
    try {
      final raw = await _kvDao.getString('movie_role_lab_recent');
      if (raw == null || raw.trim().isEmpty) return <MovieRoleLabRecentExperience>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <MovieRoleLabRecentExperience>[];
      return decoded
          .whereType<Map>()
          .map((e) => MovieRoleLabRecentExperience.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return <MovieRoleLabRecentExperience>[];
    }
  }

  String _renderMovieRolePrompt(
    String template, {
    required MovieRoleLabMovie movie,
    required MovieRoleLabCharacter character,
    required List<MovieRoleLabCharacter> ensemble,
    List<Map<String, String>> history = const <Map<String, String>>[],
    String latestUserInput = '',
    required Map<String, dynamic> userPayload,
    MovieRoleLabSubtitleEvidence subtitleEvidence = const MovieRoleLabSubtitleEvidence(
      available: false,
      status: '尚未加载真实字幕依据。',
    ),
    MovieRoleLabEpisode? episode,
    String dialogueMode = '',
    MovieRoleLabScriptLine? expectedLine,
  }) {
    final variables = <String, String>{
      'movie_id': movie.id.toString(),
      'movie_title': movie.title,
      'movie_overview': movie.overview,
      'movie_release_date': movie.releaseDate,
      'character_id': character.id.toString(),
      'character_name': character.name,
      'actor_name': character.actorName,
      'character_department': character.department,
      'ensemble_json': _encodePretty(ensemble.take(8).map((e) => e.toJson()).toList()),
      'history_json': _encodePretty(history),
      'latest_user_input': latestUserInput,
      'subtitle_evidence_json': _encodePretty(subtitleEvidence.toJson()),
      'episode_json': _encodePretty(episode?.toJson() ?? <String, dynamic>{}),
      'episode_script_text': episode?.toScriptText() ?? '',
      'dialogue_mode': dialogueMode,
      'expected_user_line_json': _encodePretty(expectedLine?.toJson() ?? <String, dynamic>{}),
      'movie_role_input_json': _encodePretty(userPayload),
    };
    return _globalAiSettings.renderTemplate(template, variables);
  }

  Future<MovieRoleLabSubtitleEvidence> _loadSubtitleEvidence({
    required MovieRoleLabMovie movie,
    required MovieRoleLabCharacter character,
    required List<MovieRoleLabCharacter> ensemble,
    MovieRoleLabEpisode? episode,
  }) async {
    if (episode != null && episode.lines.isNotEmpty) {
      final cues = episode.lines
          .map((line) => MovieRoleLabSubtitleCue(
                cueIndex: line.cueIndex,
                startMs: line.startMs,
                endMs: line.endMs,
                text: '${line.displaySpeaker}：${line.text}',
              ))
          .toList();
      return MovieRoleLabSubtitleEvidence(
        available: true,
        status: '已从本地数据库读取该集剧本。该剧本由 AI 基于完整字幕与演员表配角色并分集生成；普通字幕没有说话人字段，角色归属仍需人工复核。',
        source: 'LocalEpisodeScript',
        language: 'mixed',
        subtitleName: episode.title,
        cues: cues,
        warning: '本页分析基于《${movie.title}》电影背景和当前片段剧本。请理性分析，不要把 AI 推测的角色归属当作官方剧本事实。',
      );
    }

    final stored = await _subtitleDao.findByMovieId(movie.id);
    if (stored == null || stored.cues.isEmpty) {
      return const MovieRoleLabSubtitleEvidence(
        available: false,
        status: '本地数据库尚未导入完整电影字幕。请先回到电影角色实验室搜索页，点击该电影的“导入/查看完整字幕”；角色进入仪式不会再重复从 OpenSubtitles 下载字幕。',
      );
    }

    final evidenceCues = _subtitleService.selectEvidenceCues(
      stored.cues,
      character: character,
      ensemble: ensemble,
    );

    return MovieRoleLabSubtitleEvidence(
      available: true,
      status: '已从本地数据库读取完整电影字幕，并抽取与当前角色/场景相关的字幕片段。普通字幕通常没有说话人字段，因此角色归属只可推测，不能断言。',
      source: stored.source,
      language: stored.language,
      subtitleName: stored.subtitleName,
      cues: evidenceCues,
      warning: '完整字幕已保存在本地数据库；AI 只能基于本地字幕片段分析场景，不得重新下载字幕或编造完整剧本。',
    );
  }


  String _withGroundingGuard(String template) {
    const guard = '''

【真实字幕依据强制规则】
1. 必须优先使用 {{subtitle_evidence_json}} 中的真实字幕片段；不得编造、补全或声称还原电影中不存在的台词。
2. 普通 SRT 字幕通常没有说话人字段。除非字幕证据明确显示说话人，否则只能写“可能/无法确认”，不能断言某句一定属于某个角色。
3. 如果字幕证据 available=false 或 cues 为空，必须明确说明“没有真实字幕依据”，只能给练习建议，不能输出所谓真实剧本或真实台词。
4. cast_lines / opening_line 如不是字幕原句，必须表述为“练习用回应/模拟回应”，不得标记为原片台词。
''';
    if (template.contains('真实字幕依据强制规则')) return template;
    return '$template$guard';
  }

  String _encodePretty(Object? value) {
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }

  Future<Map<String, dynamic>> _runJsonTask({
    required String logModule,
    required String systemPrompt,
    required Map<String, dynamic> userPayload,
    required int maxTokens,
  }) async {
    final cfg = await _conceptConfig.loadRuntimeConfig();
    if (cfg.apiKey.trim().isEmpty && !cfg.useProxy) {
      throw Exception('未配置 AI 密钥');
    }
    if (cfg.useProxy) {
      return _postViaProxy(cfg: cfg, logModule: logModule, systemPrompt: systemPrompt, userPayload: userPayload, maxTokens: maxTokens);
    }
    return _postDirect(cfg: cfg, logModule: logModule, systemPrompt: systemPrompt, userPayload: userPayload, maxTokens: maxTokens);
  }

  Future<String> _runTextTask({
    required String logModule,
    required String systemPrompt,
    required Map<String, dynamic> userPayload,
    required int maxTokens,
    bool expectJson = false,
  }) async {
    final cfg = await _conceptConfig.loadRuntimeConfig();
    if (cfg.apiKey.trim().isEmpty && !cfg.useProxy) {
      throw Exception('未配置 AI 密钥');
    }
    if (cfg.useProxy) {
      final json = await _postViaProxy(cfg: cfg, logModule: logModule, systemPrompt: systemPrompt, userPayload: userPayload, maxTokens: maxTokens);
      return _encodePretty(json);
    }
    final effectiveMaxTokens = cfg.globalMaxOutputTokens == null || cfg.globalMaxOutputTokens! <= 0
        ? maxTokens
        : cfg.globalMaxOutputTokens!.clamp(64, 64000).toInt();
    final raw = await _unifiedAiService.generateText(
      purpose: logModule,
      systemPrompt: systemPrompt,
      prompt: jsonEncode(userPayload),
      maxTokens: effectiveMaxTokens,
      expectJson: expectJson,
      forcedProvider: cfg.provider,
      forcedModel: cfg.model,
      temperature: cfg.globalTemperature,
    );
    if (raw.trim().isEmpty) {
      throw Exception('${cfg.providerLabel} 返回为空');
    }
    return raw;
  }

  Future<Map<String, dynamic>> _postDirect({
    required ConceptEngineRuntimeConfig cfg,
    required String logModule,
    required String systemPrompt,
    required Map<String, dynamic> userPayload,
    required int maxTokens,
  }) async {
    final effectiveMaxTokens = cfg.globalMaxOutputTokens == null || cfg.globalMaxOutputTokens! <= 0
        ? maxTokens
        : cfg.globalMaxOutputTokens!.clamp(64, 64000).toInt();

    final raw = await _unifiedAiService.generateText(
      purpose: logModule,
      systemPrompt: systemPrompt,
      prompt: jsonEncode(userPayload),
      maxTokens: effectiveMaxTokens,
      expectJson: true,
      forcedProvider: cfg.provider,
      forcedModel: cfg.model,
      temperature: cfg.globalTemperature,
    );
    if (raw.trim().isEmpty) {
      throw Exception('${cfg.providerLabel} 返回为空');
    }
    return _decodeObject(raw);
  }

  Future<Map<String, dynamic>> _postViaProxy({
    required ConceptEngineRuntimeConfig cfg,
    required String logModule,
    required String systemPrompt,
    required Map<String, dynamic> userPayload,
    required int maxTokens,
  }) async {
    final uri = Uri.parse(cfg.proxyEndpoint);
    final effectiveMaxTokens = cfg.globalMaxOutputTokens == null || cfg.globalMaxOutputTokens! <= 0
        ? maxTokens
        : cfg.globalMaxOutputTokens!.clamp(64, 64000).toInt();
    final body = {
      'route': 'concept_engine_json_task',
      'provider': cfg.provider,
      'target_endpoint': cfg.endpoint,
      'model': cfg.model,
      'response_format': 'json_object',
      'max_tokens': effectiveMaxTokens,
      'system_prompt': systemPrompt,
      if (cfg.globalTemperature != null) 'temperature': cfg.globalTemperature,
      if (cfg.globalTopP != null) 'top_p': cfg.globalTopP,
      'user_payload': userPayload,
      'module': logModule,
      'trace_id': _traceId(),
    };
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (cfg.proxyAuthToken.trim().isNotEmpty) 'Authorization': 'Bearer ${cfg.proxyAuthToken.trim()}',
      },
      body: jsonEncode(body),
    ).timeout(Duration(seconds: cfg.timeoutSeconds));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('AI网关请求失败：${res.statusCode} ${res.body}');
    }
    final decoded = jsonDecode(res.body);
    return _extractProxyPayload(decoded);
  }

  Map<String, dynamic> _extractProxyPayload(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      if (decoded['json'] is Map) return Map<String, dynamic>.from(decoded['json'] as Map);
      if (decoded['result'] is Map) return Map<String, dynamic>.from(decoded['result'] as Map);
      if (decoded['data'] is Map) return Map<String, dynamic>.from(decoded['data'] as Map);
      if (decoded['content'] != null) return _decodeObject(decoded['content'].toString());
      return decoded;
    }
    return _decodeObject(decoded.toString());
  }

  Map<String, dynamic> _decodeObject(String raw) {
    final normalized = _extractFirstJsonObject(raw);
    final decoded = jsonDecode(normalized);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw Exception('返回结果不是 JSON 对象');
  }

  String _extractFirstJsonObject(String raw) {
    final s = raw.replaceAll('```json', '').replaceAll('```', '').trim();
    final start = s.indexOf('{');
    if (start < 0) return s;
    int depth = 0;
    for (int i = start; i < s.length; i++) {
      final ch = s[i];
      if (ch == '{') depth++;
      if (ch == '}') {
        depth--;
        if (depth == 0) return s.substring(start, i + 1);
      }
    }
    return s.substring(start);
  }

  String _traceId() => 'mrl_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(1 << 20)}';
}
