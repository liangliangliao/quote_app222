import 'dart:convert';

import '../data/dao.dart';
import '../data/movie_analysis_dao.dart';
import 'global_ai_settings.dart';
import 'tmdb_service.dart';
import 'unified_ai_service.dart';

class MovieAnalysisService {
  final GlobalAiSettings _settings = GlobalAiSettings();
  final UnifiedAiService _aiService = UnifiedAiService();
  final ConfigDao _configDao = ConfigDao();
  final MovieAnalysisDao _analysisDao = MovieAnalysisDao();

  Future<Map<String, dynamic>?> getSavedAnalysis(Map<String, dynamic> movie) {
    return _analysisDao.getByMovie(movie);
  }

  Future<String> analyzeMovie(Map<String, dynamic> movie) async {
    final title = (movie['title'] ?? movie['name'] ?? '').toString().trim();
    if (title.isEmpty) {
      throw Exception('电影标题为空，无法分析');
    }

    final movieIdRaw = movie['id'] ?? movie['tmdb_id'];
    final movieId = movieIdRaw is num ? movieIdRaw.toInt() : int.tryParse(movieIdRaw?.toString() ?? '');
    Map<String, dynamic> details = <String, dynamic>{};
    if (movieId != null && movieId > 0) {
      try {
        final token = await _configDao.getMovieToken();
        if (token.trim().isNotEmpty) {
          details = await TMDbService(token: token).movieDetails(movieId);
        }
      } catch (_) {
        // Existing card data is still enough to analyze. Do not block the user
        // when TMDb detail lookup fails or the token is missing.
      }
    }

    final mergedMovie = <String, dynamic>{
      ...movie,
      if (details.isNotEmpty) ...details,
    };

    final payload = <String, dynamic>{
      'id': mergedMovie['id'] ?? mergedMovie['tmdb_id'],
      'title': title,
      'original_title': mergedMovie['original_title'] ?? mergedMovie['original_name'] ?? '',
      'overview': mergedMovie['overview'] ?? '',
      'tagline': mergedMovie['tagline'] ?? '',
      'release_date': mergedMovie['release_date'] ?? mergedMovie['first_air_date'] ?? '',
      'runtime': mergedMovie['runtime'],
      'genres': mergedMovie['genres'],
      'vote_average': mergedMovie['vote_average'],
      'vote_count': mergedMovie['vote_count'],
      'popularity': mergedMovie['popularity'],
      'original_language': mergedMovie['original_language'],
      'keywords': mergedMovie['keywords'],
      'credits': _compactCredits(mergedMovie['credits']),
      'external_ids': mergedMovie['external_ids'],
      'raw_movie': mergedMovie,
      'tmdb_detail_loaded': details.isNotEmpty,
    };

    final template = await _settings.getMovieAnalysisPrompt();
    final prompt = _settings.renderTemplate(template, <String, String>{
      'movie_id': (payload['id'] ?? '').toString(),
      'movie_title': title,
      'movie_original_title': (payload['original_title'] ?? '').toString(),
      'movie_overview': (payload['overview'] ?? '').toString(),
      'movie_release_date': (payload['release_date'] ?? '').toString(),
      'movie_vote_average': (payload['vote_average'] ?? '').toString(),
      'movie_vote_count': (payload['vote_count'] ?? '').toString(),
      'movie_original_language': (payload['original_language'] ?? '').toString(),
      'movie_json': const JsonEncoder.withIndent('  ').convert(payload),
    });

    final aiState = await _settings.getState();
    final text = await _aiService.generateText(
      purpose: 'movie_analysis.deep_analysis',
      systemPrompt: prompt,
      prompt: jsonEncode(payload),
      maxTokens: 3600,
      expectJson: false,
      temperature: 0.45,
    );
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw Exception('AI 返回为空。请检查全局 AI 提供方、模型和 API Key 是否已配置。');
    }
    await _analysisDao.upsertAnalysis(
      movie: mergedMovie,
      analysisText: trimmed,
      provider: aiState['provider'],
      model: aiState['model'],
    );
    return trimmed;
  }

  Map<String, dynamic> _compactCredits(Object? value) {
    if (value is! Map) return <String, dynamic>{};
    final cast = (value['cast'] as List? ?? const [])
        .whereType<Map>()
        .take(12)
        .map((e) => {
              'name': e['name'],
              'character': e['character'],
              'order': e['order'],
            })
        .toList();
    final crew = (value['crew'] as List? ?? const [])
        .whereType<Map>()
        .where((e) {
          final job = (e['job'] ?? '').toString();
          return job == 'Director' || job == 'Writer' || job == 'Screenplay';
        })
        .take(12)
        .map((e) => {
              'name': e['name'],
              'job': e['job'],
            })
        .toList();
    return <String, dynamic>{'cast': cast, 'crew': crew};
  }
}
