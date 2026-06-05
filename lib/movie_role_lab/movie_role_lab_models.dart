class MovieRoleLabMovie {
  final int id;
  final String title;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final String releaseDate;
  final double voteAverage;

  const MovieRoleLabMovie({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.releaseDate,
    required this.voteAverage,
  });

  factory MovieRoleLabMovie.fromTmdb(Map<String, dynamic> json) {
    return MovieRoleLabMovie(
      id: (json['id'] is num) ? (json['id'] as num).toInt() : int.tryParse('${json['id']}') ?? 0,
      title: (json['title'] ?? json['name'] ?? '').toString(),
      overview: (json['overview'] ?? '').toString(),
      posterPath: json['poster_path']?.toString(),
      backdropPath: json['backdrop_path']?.toString(),
      releaseDate: (json['release_date'] ?? '').toString(),
      voteAverage: (json['vote_average'] is num)
          ? (json['vote_average'] as num).toDouble()
          : double.tryParse('${json['vote_average']}') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'overview': overview,
        'posterPath': posterPath,
        'backdropPath': backdropPath,
        'releaseDate': releaseDate,
        'voteAverage': voteAverage,
      };

  factory MovieRoleLabMovie.fromJson(Map<String, dynamic> json) => MovieRoleLabMovie(
        id: (json['id'] is num) ? (json['id'] as num).toInt() : int.tryParse('${json['id']}') ?? 0,
        title: (json['title'] ?? '').toString(),
        overview: (json['overview'] ?? '').toString(),
        posterPath: json['posterPath']?.toString(),
        backdropPath: json['backdropPath']?.toString(),
        releaseDate: (json['releaseDate'] ?? '').toString(),
        voteAverage: (json['voteAverage'] is num)
            ? (json['voteAverage'] as num).toDouble()
            : double.tryParse('${json['voteAverage']}') ?? 0,
      );
}

class MovieRoleLabCharacter {
  final int id;
  final String name;
  final String actorName;
  final String? profilePath;
  final int order;
  final String department;

  const MovieRoleLabCharacter({
    required this.id,
    required this.name,
    required this.actorName,
    required this.profilePath,
    required this.order,
    required this.department,
  });

  factory MovieRoleLabCharacter.fromTmdb(Map<String, dynamic> json) {
    return MovieRoleLabCharacter(
      id: (json['cast_id'] is num) ? (json['cast_id'] as num).toInt() : int.tryParse('${json['cast_id']}') ?? 0,
      name: (json['character'] ?? '').toString().trim().isEmpty ? '未命名角色' : (json['character'] ?? '').toString(),
      actorName: (json['name'] ?? '').toString(),
      profilePath: json['profile_path']?.toString(),
      order: (json['order'] is num) ? (json['order'] as num).toInt() : int.tryParse('${json['order']}') ?? 9999,
      department: (json['known_for_department'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'actorName': actorName,
        'profilePath': profilePath,
        'order': order,
        'department': department,
      };

  factory MovieRoleLabCharacter.fromJson(Map<String, dynamic> json) => MovieRoleLabCharacter(
        id: (json['id'] is num) ? (json['id'] as num).toInt() : int.tryParse('${json['id']}') ?? 0,
        name: (json['name'] ?? '').toString(),
        actorName: (json['actorName'] ?? '').toString(),
        profilePath: json['profilePath']?.toString(),
        order: (json['order'] is num) ? (json['order'] as num).toInt() : int.tryParse('${json['order']}') ?? 9999,
        department: (json['department'] ?? '').toString(),
      );
}

class MovieRoleLabSubtitleCue {
  final int cueIndex;
  final int startMs;
  final int endMs;
  final String text;

  const MovieRoleLabSubtitleCue({
    this.cueIndex = 0,
    required this.startMs,
    required this.endMs,
    required this.text,
  });

  String get startLabel => formatMs(startMs);
  String get endLabel => formatMs(endMs);
  String get timeRangeLabel => '$startLabel - $endLabel';

  Map<String, dynamic> toJson() => {
        'cue_index': cueIndex,
        'start_ms': startMs,
        'end_ms': endMs,
        'start': startLabel,
        'end': endLabel,
        'text': text,
      };

  factory MovieRoleLabSubtitleCue.fromJson(Map<String, dynamic> json) => MovieRoleLabSubtitleCue(
        cueIndex: (json['cue_index'] is num) ? (json['cue_index'] as num).toInt() : int.tryParse('${json['cue_index']}') ?? 0,
        startMs: (json['start_ms'] is num) ? (json['start_ms'] as num).toInt() : int.tryParse('${json['start_ms']}') ?? 0,
        endMs: (json['end_ms'] is num) ? (json['end_ms'] as num).toInt() : int.tryParse('${json['end_ms']}') ?? 0,
        text: (json['text'] ?? '').toString(),
      );

  static String formatMs(int value) {
    final totalSeconds = value ~/ 1000;
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    String two(int n) => n < 10 ? '0$n' : '$n';
    return '${two(h)}:${two(m)}:${two(s)}';
  }
}

class MovieRoleLabStoredSubtitle {
  final int id;
  final int movieId;
  final String movieTitle;
  final String imdbId;
  final String source;
  final String language;
  final String subtitleName;
  final int importedAtMs;
  final List<MovieRoleLabSubtitleCue> cues;

  const MovieRoleLabStoredSubtitle({
    required this.id,
    required this.movieId,
    required this.movieTitle,
    required this.imdbId,
    required this.source,
    required this.language,
    required this.subtitleName,
    required this.importedAtMs,
    required this.cues,
  });

  String get importedAtLabel {
    final dt = DateTime.fromMillisecondsSinceEpoch(importedAtMs);
    String two(int n) => n < 10 ? '0$n' : '$n';
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String toDisplayText() {
    final buffer = StringBuffer();
    for (final cue in cues) {
      buffer.writeln('[${cue.timeRangeLabel}] ${cue.text}');
      buffer.writeln();
    }
    return buffer.toString().trimRight();
  }
}




class MovieRoleLabEpisodeRole {
  final String name;
  final String nameZh;
  final String nameEn;
  final String actorName;
  final String? profilePath;
  final String roleType;

  const MovieRoleLabEpisodeRole({
    required this.name,
    required this.nameZh,
    required this.nameEn,
    required this.actorName,
    required this.profilePath,
    required this.roleType,
  });

  String get displayName {
    final zh = nameZh.trim();
    final en = nameEn.trim();
    if (zh.isNotEmpty && en.isNotEmpty && zh != en) return '$zh / $en';
    if (zh.isNotEmpty) return zh;
    if (en.isNotEmpty) return en;
    return name.trim().isEmpty ? '未命名角色' : name.trim();
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'name_zh': nameZh,
        'name_en': nameEn,
        'actor_name': actorName,
        'profile_path': profilePath,
        'role_type': roleType,
      };

  factory MovieRoleLabEpisodeRole.fromJson(Map<String, dynamic> json) => MovieRoleLabEpisodeRole(
        name: (json['name'] ?? json['character_name'] ?? '').toString(),
        nameZh: (json['name_zh'] ?? json['character_name_zh'] ?? '').toString(),
        nameEn: (json['name_en'] ?? json['character_name_en'] ?? '').toString(),
        actorName: (json['actor_name'] ?? '').toString(),
        profilePath: json['profile_path']?.toString(),
        roleType: (json['role_type'] ?? '').toString(),
      );
}

class MovieRoleLabScriptLine {
  final int id;
  final int lineIndex;
  final int cueIndex;
  final int startMs;
  final int endMs;
  final String characterName;
  final String characterNameZh;
  final String characterNameEn;
  final String text;
  final String confidence;
  final String source;

  const MovieRoleLabScriptLine({
    this.id = 0,
    required this.lineIndex,
    this.cueIndex = 0,
    this.startMs = 0,
    this.endMs = 0,
    required this.characterName,
    required this.characterNameZh,
    required this.characterNameEn,
    required this.text,
    this.confidence = 'medium',
    this.source = 'ai_inferred_from_subtitle',
  });

  String get startLabel => MovieRoleLabSubtitleCue.formatMs(startMs);
  String get endLabel => MovieRoleLabSubtitleCue.formatMs(endMs);
  String get timeRangeLabel => '$startLabel - $endLabel';

  String get displaySpeaker {
    final zh = characterNameZh.trim();
    final en = characterNameEn.trim();
    if (zh.isNotEmpty && en.isNotEmpty && zh != en) return '$zh / $en';
    if (zh.isNotEmpty) return zh;
    if (en.isNotEmpty) return en;
    return characterName.trim().isEmpty ? '未知角色' : characterName.trim();
  }

  bool belongsTo(MovieRoleLabCharacter character) {
    final targets = <String>{
      character.name,
      character.actorName,
    }.map(_norm).where((e) => e.isNotEmpty).toSet();
    final mine = <String>{
      characterName,
      characterNameZh,
      characterNameEn,
    }.map(_norm).where((e) => e.isNotEmpty).toSet();
    if (targets.isEmpty || mine.isEmpty) return false;
    for (final a in targets) {
      for (final b in mine) {
        if (a == b || a.contains(b) || b.contains(a)) return true;
      }
    }
    return false;
  }

  static String _norm(String value) => value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]+'), '').trim();

  Map<String, dynamic> toJson() => {
        'id': id,
        'line_index': lineIndex,
        'cue_index': cueIndex,
        'start_ms': startMs,
        'end_ms': endMs,
        'start': startLabel,
        'end': endLabel,
        'character_name': characterName,
        'character_name_zh': characterNameZh,
        'character_name_en': characterNameEn,
        'text': text,
        'confidence': confidence,
        'source': source,
      };

  factory MovieRoleLabScriptLine.fromJson(Map<String, dynamic> json) => MovieRoleLabScriptLine(
        id: (json['id'] is num) ? (json['id'] as num).toInt() : int.tryParse('${json['id']}') ?? 0,
        lineIndex: (json['line_index'] is num) ? (json['line_index'] as num).toInt() : int.tryParse('${json['line_index']}') ?? 0,
        cueIndex: (json['cue_index'] is num) ? (json['cue_index'] as num).toInt() : int.tryParse('${json['cue_index']}') ?? 0,
        startMs: (json['start_ms'] is num) ? (json['start_ms'] as num).toInt() : int.tryParse('${json['start_ms']}') ?? 0,
        endMs: (json['end_ms'] is num) ? (json['end_ms'] as num).toInt() : int.tryParse('${json['end_ms']}') ?? 0,
        characterName: (json['character_name'] ?? json['speaker'] ?? '').toString(),
        characterNameZh: (json['character_name_zh'] ?? '').toString(),
        characterNameEn: (json['character_name_en'] ?? '').toString(),
        text: (json['text'] ?? json['line'] ?? '').toString(),
        confidence: (json['confidence'] ?? 'medium').toString(),
        source: (json['source'] ?? 'ai_inferred_from_subtitle').toString(),
      );
}

class MovieRoleLabEpisode {
  final int id;
  final int movieId;
  final int episodeIndex;
  final String title;
  final String summary;
  final String previousContext;
  final int startMs;
  final int endMs;
  final int createdAtMs;
  final List<MovieRoleLabEpisodeRole> roles;
  final List<MovieRoleLabScriptLine> lines;

  const MovieRoleLabEpisode({
    this.id = 0,
    required this.movieId,
    required this.episodeIndex,
    required this.title,
    required this.summary,
    required this.previousContext,
    required this.startMs,
    required this.endMs,
    this.createdAtMs = 0,
    this.roles = const <MovieRoleLabEpisodeRole>[],
    this.lines = const <MovieRoleLabScriptLine>[],
  });

  String get timeRangeLabel => '${MovieRoleLabSubtitleCue.formatMs(startMs)} - ${MovieRoleLabSubtitleCue.formatMs(endMs)}';

  String toScriptText() {
    final buffer = StringBuffer();
    buffer.writeln('第$episodeIndex集：$title');
    if (previousContext.trim().isNotEmpty) buffer.writeln('上回/前情：$previousContext');
    if (summary.trim().isNotEmpty) buffer.writeln('剧情概述：$summary');
    buffer.writeln('时间范围：$timeRangeLabel');
    buffer.writeln('参演角色：${roles.map((e) => e.displayName).join('、')}');
    buffer.writeln('');
    for (final line in lines) {
      buffer.writeln('[${line.timeRangeLabel}] ${line.displaySpeaker}：${line.text}');
    }
    return buffer.toString().trimRight();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'movie_id': movieId,
        'episode_index': episodeIndex,
        'title': title,
        'summary': summary,
        'previous_context': previousContext,
        'start_ms': startMs,
        'end_ms': endMs,
        'time_range': timeRangeLabel,
        'created_at_ms': createdAtMs,
        'roles': roles.map((e) => e.toJson()).toList(),
        'lines': lines.map((e) => e.toJson()).toList(),
      };
}

class MovieRoleLabSubtitleEvidence {
  final bool available;
  final String status;
  final String source;
  final String language;
  final String subtitleName;
  final List<MovieRoleLabSubtitleCue> cues;
  final String warning;

  const MovieRoleLabSubtitleEvidence({
    required this.available,
    required this.status,
    this.source = '',
    this.language = '',
    this.subtitleName = '',
    this.cues = const <MovieRoleLabSubtitleCue>[],
    this.warning = '',
  });

  Map<String, dynamic> toJson() => {
        'available': available,
        'status': status,
        'source': source,
        'language': language,
        'subtitle_name': subtitleName,
        'warning': warning,
        'cues': cues.map((e) => e.toJson()).toList(),
      };

  factory MovieRoleLabSubtitleEvidence.fromJson(Map<String, dynamic> json) => MovieRoleLabSubtitleEvidence(
        available: json['available'] == true,
        status: (json['status'] ?? '').toString(),
        source: (json['source'] ?? '').toString(),
        language: (json['language'] ?? '').toString(),
        subtitleName: (json['subtitle_name'] ?? json['subtitleName'] ?? '').toString(),
        warning: (json['warning'] ?? '').toString(),
        cues: ((json['cues'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => MovieRoleLabSubtitleCue.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class MovieRoleLabEntryBrief {
  final String title;
  final String scene;
  final String whoYouAre;
  final String whatYouWant;
  final String whatYouFear;
  final List<String> principles;
  final String directorHint;
  final String openingLine;
  final MovieRoleLabSubtitleEvidence subtitleEvidence;

  const MovieRoleLabEntryBrief({
    required this.title,
    required this.scene,
    required this.whoYouAre,
    required this.whatYouWant,
    required this.whatYouFear,
    required this.principles,
    required this.directorHint,
    required this.openingLine,
    this.subtitleEvidence = const MovieRoleLabSubtitleEvidence(
      available: false,
      status: '尚未加载真实字幕依据。',
    ),
  });

  factory MovieRoleLabEntryBrief.fromJson(Map<String, dynamic> json, {MovieRoleLabSubtitleEvidence? subtitleEvidence}) {
    final list = (json['principles'] is List)
        ? (json['principles'] as List).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
        : <String>[];
    return MovieRoleLabEntryBrief(
      title: (json['title'] ?? '进入角色').toString(),
      scene: (json['scene'] ?? '').toString(),
      whoYouAre: (json['who_you_are'] ?? json['whoYouAre'] ?? '').toString(),
      whatYouWant: (json['what_you_want'] ?? json['whatYouWant'] ?? '').toString(),
      whatYouFear: (json['what_you_fear'] ?? json['whatYouFear'] ?? '').toString(),
      principles: list,
      directorHint: (json['director_hint'] ?? json['directorHint'] ?? '').toString(),
      openingLine: (json['opening_line'] ?? json['openingLine'] ?? '').toString(),
      subtitleEvidence: subtitleEvidence ??
          (json['subtitle_evidence'] is Map
              ? MovieRoleLabSubtitleEvidence.fromJson(Map<String, dynamic>.from(json['subtitle_evidence'] as Map))
              : const MovieRoleLabSubtitleEvidence(available: false, status: '尚未加载真实字幕依据。')),
    );
  }
}

class MovieRoleLabTurnResult {
  final String directorFeedback;
  final List<String> castLines;
  final String innerState;
  final String sceneProgress;
  final List<String> suggestedActions;
  final bool accepted;
  final String stopReason;

  const MovieRoleLabTurnResult({
    required this.directorFeedback,
    required this.castLines,
    required this.innerState,
    required this.sceneProgress,
    required this.suggestedActions,
    this.accepted = true,
    this.stopReason = '',
  });

  factory MovieRoleLabTurnResult.fromJson(Map<String, dynamic> json) {
    List<String> toList(dynamic v) {
      if (v is List) {
        return v.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
      }
      return <String>[];
    }

    return MovieRoleLabTurnResult(
      directorFeedback: (json['director_feedback'] ?? json['directorFeedback'] ?? '').toString(),
      castLines: toList(json['cast_lines'] ?? json['castLines']),
      innerState: (json['inner_state'] ?? json['innerState'] ?? '').toString(),
      sceneProgress: (json['scene_progress'] ?? json['sceneProgress'] ?? '').toString(),
      suggestedActions: toList(json['suggested_actions'] ?? json['suggestedActions']),
      accepted: json['accepted'] == null ? true : json['accepted'] == true || json['accepted'].toString().toLowerCase() == 'true',
      stopReason: (json['stop_reason'] ?? json['stopReason'] ?? '').toString(),
    );
  }
}

class MovieRoleLabRecentExperience {
  final MovieRoleLabMovie movie;
  final MovieRoleLabCharacter character;
  final String updatedAt;

  const MovieRoleLabRecentExperience({
    required this.movie,
    required this.character,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'movie': movie.toJson(),
        'character': character.toJson(),
        'updatedAt': updatedAt,
      };

  factory MovieRoleLabRecentExperience.fromJson(Map<String, dynamic> json) => MovieRoleLabRecentExperience(
        movie: MovieRoleLabMovie.fromJson(Map<String, dynamic>.from(json['movie'] as Map)),
        character: MovieRoleLabCharacter.fromJson(Map<String, dynamic>.from(json['character'] as Map)),
        updatedAt: (json['updatedAt'] ?? '').toString(),
      );
}

class MovieRoleLabSearchHistoryItem {
  final int id;
  final String query;
  final MovieRoleLabMovie movie;
  final String rawJson;
  final int searchedAtMs;

  const MovieRoleLabSearchHistoryItem({
    required this.id,
    required this.query,
    required this.movie,
    required this.rawJson,
    required this.searchedAtMs,
  });

  String get searchedAtLabel {
    final dt = DateTime.fromMillisecondsSinceEpoch(searchedAtMs);
    String two(int n) => n < 10 ? '0$n' : '$n';
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'query': query,
        'movie': movie.toJson(),
        'raw_json': rawJson,
        'searched_at_ms': searchedAtMs,
      };
}

