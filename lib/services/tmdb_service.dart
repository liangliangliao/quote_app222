import 'dart:convert';
import 'package:http/http.dart' as http;

/// A small helper service to fetch movie data from The Movie Database (TMDb).
///
/// Movie Role Lab can use either the TMDb v4 read access token or the v3 API
/// key. Existing pages that only pass [token] keep working. New pages can pass
/// [apiKey] when the user only configured a v3 key.
class TMDbService {
  /// The v4 read access token obtained from the TMDb developer console.
  final String token;

  /// Optional v3 API key.
  final String apiKey;

  TMDbService({required this.token, this.apiKey = ''});

  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String _imageBase = 'https://image.tmdb.org/t/p/';

  Future<Map<String, dynamic>> _get(String path, Map<String, String> params) async {
    final mergedParams = <String, String>{...params};
    final headers = <String, String>{'Accept': 'application/json'};
    if (token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    } else if (apiKey.trim().isNotEmpty) {
      mergedParams['api_key'] = apiKey.trim();
    } else {
      throw Exception('TMDb 未配置 API Read Access Token 或 API Key，请先到电影角色实验室配置页填写。');
    }
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: mergedParams);
    final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw Exception('TMDb API error: ${response.statusCode}, ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> discoverMovies({required int page, int voteCount = 5000}) async {
    return _get('/discover/movie', {
      'sort_by': 'vote_average.desc',
      'vote_count.gte': voteCount.toString(),
      'language': 'zh-CN',
      'page': page.toString(),
    });
  }

  Future<Map<String, dynamic>> topRatedMovies({required int page}) async {
    return _get('/movie/top_rated', {'language': 'zh-CN', 'page': page.toString()});
  }

  Future<Map<String, dynamic>> popularMovies({required int page}) async {
    return _get('/movie/popular', {'language': 'zh-CN', 'page': page.toString()});
  }

  Future<Map<String, dynamic>> nowPlayingMovies({required int page, String? region}) async {
    final params = {'language': 'zh-CN', 'page': page.toString()};
    if (region != null && region.trim().isNotEmpty) params['region'] = region.trim();
    return _get('/movie/now_playing', params);
  }

  Future<Map<String, dynamic>> upcomingMovies({required int page}) async {
    return _get('/movie/upcoming', {'language': 'zh-CN', 'page': page.toString()});
  }

  Future<Map<String, dynamic>> movieCredits(int movieId) async {
    return _get('/movie/$movieId/credits', {'language': 'zh-CN'});
  }

  Future<Map<String, dynamic>> movieDetails(int movieId) async {
    return _get('/movie/$movieId', {
      'language': 'zh-CN',
      'append_to_response': 'credits,keywords,external_ids',
    });
  }

  /// Fetches external IDs such as IMDb ID for accurate subtitle matching.
  Future<Map<String, dynamic>> movieExternalIds(int movieId) async {
    return _get('/movie/$movieId/external_ids', const <String, String>{});
  }

  static String? buildPosterUrl(String? path, {String size = 'w342'}) {
    if (path == null || path.isEmpty) return null;
    return '$_imageBase$size$path';
  }

  Future<Map<String, dynamic>> searchMovies({required String query, int page = 1}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return {'page': 1, 'total_pages': 1, 'results': <dynamic>[]};
    return _get('/search/movie', {
      'query': trimmed,
      'language': 'zh-CN',
      'page': page.toString(),
      'include_adult': 'false',
    });
  }
}
