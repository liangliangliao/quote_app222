import 'package:url_launcher/url_launcher.dart';

/// Third-party movie websites exposed only as external browser search entries.
///
/// The app does not parse, store, embed, or play any third-party video source.
/// It only opens a normal web search in the user's external browser so the
/// third-party website remains responsible for its own content and playback UI.
enum MovieExternalWatchSite {
  xiaoya,
  fofo,
  nunu,
}

extension MovieExternalWatchSiteExt on MovieExternalWatchSite {
  String get label {
    switch (this) {
      case MovieExternalWatchSite.xiaoya:
        return '小鸭看看';
      case MovieExternalWatchSite.fofo:
        return 'FoFo影院';
      case MovieExternalWatchSite.nunu:
        return '努努影院';
    }
  }

  String get domain {
    switch (this) {
      case MovieExternalWatchSite.xiaoya:
        return 'xiaoyakankan.com';
      case MovieExternalWatchSite.fofo:
        return 'fofoyy.com';
      case MovieExternalWatchSite.nunu:
        return 'nnyy.in';
    }
  }
}

class MovieExternalWatchService {
  const MovieExternalWatchService();

  Uri buildSearchUri({
    required MovieExternalWatchSite site,
    required String title,
    String? originalTitle,
    String? releaseDate,
  }) {
    final safeTitle = title.trim();
    final safeOriginalTitle = originalTitle?.trim() ?? '';
    final year = _extractYear(releaseDate);

    final queryParts = <String>[
      'site:${site.domain}',
      if (safeTitle.isNotEmpty) safeTitle,
      if (safeOriginalTitle.isNotEmpty && safeOriginalTitle != safeTitle)
        safeOriginalTitle,
      if (year.isNotEmpty) year,
    ];

    final query = queryParts.join(' ');
    return Uri.https('www.google.com', '/search', {'q': query});
  }

  Future<void> openExternalSearch({
    required MovieExternalWatchSite site,
    required String title,
    String? originalTitle,
    String? releaseDate,
  }) async {
    final uri = buildSearchUri(
      site: site,
      title: title,
      originalTitle: originalTitle,
      releaseDate: releaseDate,
    );

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );

    if (!opened) {
      throw Exception('无法打开外部浏览器');
    }
  }

  String _extractYear(String? releaseDate) {
    final raw = releaseDate?.trim() ?? '';
    if (raw.length < 4) return '';
    final year = raw.substring(0, 4);
    final isYear = RegExp(r'^\d{4}$').hasMatch(year);
    return isYear ? year : '';
  }
}
