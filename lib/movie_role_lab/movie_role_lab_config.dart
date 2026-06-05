import '../data/dao.dart';
import '../data/kv_dao.dart';

class MovieRoleLabConfig {
  final String tmdbReadToken;
  final String tmdbApiKey;
  final String openSubtitlesApiKey;
  final String openSubtitlesUsername;
  final String openSubtitlesPassword;
  final String openSubtitlesUserAgent;
  final String subtitleLanguages;

  const MovieRoleLabConfig({
    required this.tmdbReadToken,
    required this.tmdbApiKey,
    required this.openSubtitlesApiKey,
    required this.openSubtitlesUsername,
    required this.openSubtitlesPassword,
    required this.openSubtitlesUserAgent,
    required this.subtitleLanguages,
  });

  bool get hasTmdbAuth => tmdbReadToken.trim().isNotEmpty || tmdbApiKey.trim().isNotEmpty;
  bool get hasOpenSubtitlesSearchAuth => openSubtitlesApiKey.trim().isNotEmpty && openSubtitlesUserAgent.trim().isNotEmpty;
  bool get hasOpenSubtitlesDownloadAuth => hasOpenSubtitlesSearchAuth && openSubtitlesUsername.trim().isNotEmpty && openSubtitlesPassword.trim().isNotEmpty;

  List<String> get languageList {
    final raw = subtitleLanguages.trim().isEmpty ? 'ze,zh-cn,en' : subtitleLanguages;
    return raw
        .split(RegExp(r'[,，;；\s]+'))
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  MovieRoleLabConfig copyWith({
    String? tmdbReadToken,
    String? tmdbApiKey,
    String? openSubtitlesApiKey,
    String? openSubtitlesUsername,
    String? openSubtitlesPassword,
    String? openSubtitlesUserAgent,
    String? subtitleLanguages,
  }) {
    return MovieRoleLabConfig(
      tmdbReadToken: tmdbReadToken ?? this.tmdbReadToken,
      tmdbApiKey: tmdbApiKey ?? this.tmdbApiKey,
      openSubtitlesApiKey: openSubtitlesApiKey ?? this.openSubtitlesApiKey,
      openSubtitlesUsername: openSubtitlesUsername ?? this.openSubtitlesUsername,
      openSubtitlesPassword: openSubtitlesPassword ?? this.openSubtitlesPassword,
      openSubtitlesUserAgent: openSubtitlesUserAgent ?? this.openSubtitlesUserAgent,
      subtitleLanguages: subtitleLanguages ?? this.subtitleLanguages,
    );
  }
}

class MovieRoleLabConfigStore {
  static const String tmdbApiKeyKey = 'mrl_tmdb_api_key';
  static const String openSubtitlesApiKeyKey = 'mrl_opensubtitles_api_key';
  static const String openSubtitlesUsernameKey = 'mrl_opensubtitles_username';
  static const String openSubtitlesPasswordKey = 'mrl_opensubtitles_password';
  static const String openSubtitlesUserAgentKey = 'mrl_opensubtitles_user_agent';
  static const String subtitleLanguagesKey = 'mrl_subtitle_languages';

  final ConfigDao _configDao;
  final KeyValueDao _kvDao;

  MovieRoleLabConfigStore({ConfigDao? configDao, KeyValueDao? kvDao})
      : _configDao = configDao ?? ConfigDao(),
        _kvDao = kvDao ?? KeyValueDao();

  Future<MovieRoleLabConfig> load() async {
    final token = await _configDao.getMovieToken();
    return MovieRoleLabConfig(
      tmdbReadToken: token.trim(),
      tmdbApiKey: ((await _kvDao.getString(tmdbApiKeyKey)) ?? '').trim(),
      openSubtitlesApiKey: ((await _kvDao.getString(openSubtitlesApiKeyKey)) ?? '').trim(),
      openSubtitlesUsername: ((await _kvDao.getString(openSubtitlesUsernameKey)) ?? '').trim(),
      openSubtitlesPassword: ((await _kvDao.getString(openSubtitlesPasswordKey)) ?? '').trim(),
      openSubtitlesUserAgent: ((await _kvDao.getString(openSubtitlesUserAgentKey)) ?? 'MovieRoleLab v1.0').trim(),
      subtitleLanguages: ((await _kvDao.getString(subtitleLanguagesKey)) ?? 'ze,zh-cn,en').trim(),
    );
  }

  Future<void> save(MovieRoleLabConfig config) async {
    await _configDao.setMovieToken(config.tmdbReadToken.trim());
    await _kvDao.setString(tmdbApiKeyKey, config.tmdbApiKey.trim());
    await _kvDao.setString(openSubtitlesApiKeyKey, config.openSubtitlesApiKey.trim());
    await _kvDao.setString(openSubtitlesUsernameKey, config.openSubtitlesUsername.trim());
    await _kvDao.setString(openSubtitlesPasswordKey, config.openSubtitlesPassword.trim());
    await _kvDao.setString(
      openSubtitlesUserAgentKey,
      config.openSubtitlesUserAgent.trim().isEmpty ? 'MovieRoleLab v1.0' : config.openSubtitlesUserAgent.trim(),
    );
    await _kvDao.setString(
      subtitleLanguagesKey,
      config.subtitleLanguages.trim().isEmpty ? 'ze,zh-cn,en' : config.subtitleLanguages.trim(),
    );
  }
}
