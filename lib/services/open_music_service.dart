import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/kv_dao.dart';

/// Search adapters for open / licensed music sources that can be played as
/// normal audio streams. These sources are intended for background playback.
///
/// YouTube is intentionally not handled here because its policies require the
/// official visible player and do not allow background audio playback.
class OpenMusicService {
  OpenMusicService({KeyValueDao? kvDao}) : _kvDao = kvDao ?? KeyValueDao();

  static const String jamendoClientIdKvKey = 'jamendo_client_id';

  final KeyValueDao _kvDao;

  Future<String> getJamendoClientId() async {
    return ((await _kvDao.getString(jamendoClientIdKvKey)) ?? '').trim();
  }

  Future<List<OpenMusicTrack>> search(String query, {int maxResults = 12}) async {
    final q = query.trim();
    if (q.isEmpty) return <OpenMusicTrack>[];

    final safeMax = maxResults.clamp(1, 20).toInt();
    final jamendoClientId = await getJamendoClientId();

    final parts = <List<OpenMusicTrack>>[];

    // Internet Archive does not require a key, so it is the default open source.
    parts.add(await _searchInternetArchive(q, maxResults: safeMax));

    // Jamendo is optional. If the user enters an invalid Client ID, do not let
    // it break Internet Archive playback results.
    if (jamendoClientId.isNotEmpty) {
      try {
        parts.add(await _searchJamendo(q, clientId: jamendoClientId, maxResults: safeMax));
      } catch (_) {}
    }

    final seen = <String>{};
    final merged = <OpenMusicTrack>[];
    for (final list in parts) {
      for (final item in list) {
        final key = '${item.provider}:${item.sourceId}:${item.audioUrl}';
        if (seen.add(key)) merged.add(item);
        if (merged.length >= safeMax) return merged;
      }
    }
    return merged;
  }

  Future<List<OpenMusicTrack>> _searchInternetArchive(
    String query, {
    int maxResults = 12,
  }) async {
    final rowsToFetch = (maxResults * 3).clamp(8, 30).toInt();
    final uri = Uri.https('archive.org', '/advancedsearch.php', <String, dynamic>{
      'q': '($query) AND mediatype:audio',
      'fl[]': <String>['identifier', 'title', 'creator', 'description', 'date', 'licenseurl'],
      'rows': rowsToFetch.toString(),
      'page': '1',
      'output': 'json',
      'sort[]': <String>['downloads desc'],
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 18));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OpenMusicException('Internet Archive 搜索失败（HTTP ${response.statusCode}）');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return <OpenMusicTrack>[];
    final responseNode = decoded['response'];
    if (responseNode is! Map) return <OpenMusicTrack>[];
    final docs = responseNode['docs'];
    if (docs is! List) return <OpenMusicTrack>[];

    final results = <OpenMusicTrack>[];
    for (final raw in docs.whereType<Map>()) {
      if (results.length >= maxResults) break;
      final identifier = (raw['identifier'] ?? '').toString().trim();
      if (identifier.isEmpty) continue;
      final track = await _resolveInternetArchiveItem(
        identifier: identifier,
        titleFallback: _firstString(raw['title']),
        creatorFallback: _firstString(raw['creator']),
        descriptionFallback: _firstString(raw['description']),
        licenseFallback: _firstString(raw['licenseurl']),
      );
      if (track != null) results.add(track);
    }

    return results;
  }

  Future<OpenMusicTrack?> _resolveInternetArchiveItem({
    required String identifier,
    required String titleFallback,
    required String creatorFallback,
    required String descriptionFallback,
    required String licenseFallback,
  }) async {
    try {
      final uri = Uri.https('archive.org', '/metadata/$identifier');
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;

      final metadata = decoded['metadata'] is Map ? Map<String, dynamic>.from(decoded['metadata'] as Map) : <String, dynamic>{};
      final files = decoded['files'];
      if (files is! List) return null;

      Map<String, dynamic>? chosen;
      var chosenScore = -1;
      for (final rawFile in files.whereType<Map>()) {
        final file = Map<String, dynamic>.from(rawFile);
        final name = (file['name'] ?? '').toString();
        final lower = name.toLowerCase();
        final format = (file['format'] ?? '').toString().toLowerCase();
        final source = (file['source'] ?? '').toString().toLowerCase();

        var score = -1;
        if (lower.endsWith('.mp3')) score = 100;
        if (format.contains('vbr mp3')) score = 120;
        if (format == 'mp3' || format.contains('mp3')) score = score < 110 ? 110 : score;
        if (lower.endsWith('.m4a')) score = score < 90 ? 90 : score;
        if (lower.endsWith('.ogg') || format.contains('ogg')) score = score < 70 ? 70 : score;
        if (lower.endsWith('.flac')) score = score < 50 ? 50 : score;
        if (source.contains('derivative')) score += 5;

        // Skip metadata, images, torrents, playlists and tiny support files.
        if (lower.endsWith('.xml') ||
            lower.endsWith('.json') ||
            lower.endsWith('.txt') ||
            lower.endsWith('.jpg') ||
            lower.endsWith('.png') ||
            lower.endsWith('.gif') ||
            lower.endsWith('.torrent') ||
            lower.endsWith('.m3u')) {
          score = -1;
        }

        if (score > chosenScore) {
          chosenScore = score;
          chosen = file;
        }
      }
      if (chosen == null || chosenScore < 0) return null;

      final filename = (chosen['name'] ?? '').toString();
      final title = _firstString(metadata['title']).isNotEmpty ? _firstString(metadata['title']) : titleFallback;
      final creator = _firstString(metadata['creator']).isNotEmpty ? _firstString(metadata['creator']) : creatorFallback;
      final description = _firstString(metadata['description']).isNotEmpty ? _firstString(metadata['description']) : descriptionFallback;
      final license = _firstString(metadata['licenseurl']).isNotEmpty ? _firstString(metadata['licenseurl']) : licenseFallback;

      return OpenMusicTrack(
        provider: OpenMusicProvider.internetArchive,
        sourceId: identifier,
        title: title.isNotEmpty ? title : identifier,
        creator: creator.isNotEmpty ? creator : 'Internet Archive',
        audioUrl: 'https://archive.org/download/${Uri.encodeComponent(identifier)}/${Uri.encodeComponent(filename)}',
        thumbnailUrl: 'https://archive.org/services/img/${Uri.encodeComponent(identifier)}',
        sourceUrl: 'https://archive.org/details/${Uri.encodeComponent(identifier)}',
        license: license,
        description: description,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<OpenMusicTrack>> _searchJamendo(
    String query, {
    required String clientId,
    int maxResults = 12,
  }) async {
    final uri = Uri.https('api.jamendo.com', '/v3.0/tracks/', <String, String>{
      'client_id': clientId,
      'format': 'json',
      'limit': maxResults.toString(),
      'search': query,
      'include': 'musicinfo',
      'audioformat': 'mp31',
      'order': 'popularity_total',
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OpenMusicException('Jamendo 搜索失败（HTTP ${response.statusCode}）');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return <OpenMusicTrack>[];
    final results = decoded['results'];
    if (results is! List) return <OpenMusicTrack>[];

    return results.whereType<Map>().map((raw) {
      final item = Map<String, dynamic>.from(raw);
      final id = (item['id'] ?? '').toString();
      final title = (item['name'] ?? '').toString();
      final artist = (item['artist_name'] ?? '').toString();
      final audio = (item['audio'] ?? '').toString();
      final image = (item['album_image'] ?? item['image'] ?? '').toString();
      final license = (item['license_ccurl'] ?? '').toString();
      return OpenMusicTrack(
        provider: OpenMusicProvider.jamendo,
        sourceId: id,
        title: title.isNotEmpty ? title : 'Jamendo Track',
        creator: artist.isNotEmpty ? artist : 'Jamendo',
        audioUrl: audio,
        thumbnailUrl: image,
        sourceUrl: id.isEmpty ? 'https://www.jamendo.com' : 'https://www.jamendo.com/track/$id',
        license: license,
        description: '',
      );
    }).where((track) => track.audioUrl.isNotEmpty).toList(growable: false);
  }

  static String _firstString(dynamic value) {
    if (value == null) return '';
    if (value is List && value.isNotEmpty) return _firstString(value.first);
    return value.toString().trim();
  }
}

class OpenMusicException implements Exception {
  final String message;
  const OpenMusicException(this.message);

  @override
  String toString() => message;
}

enum OpenMusicProvider { internetArchive, jamendo }

class OpenMusicTrack {
  final OpenMusicProvider provider;
  final String sourceId;
  final String title;
  final String creator;
  final String audioUrl;
  final String thumbnailUrl;
  final String sourceUrl;
  final String license;
  final String description;

  const OpenMusicTrack({
    required this.provider,
    required this.sourceId,
    required this.title,
    required this.creator,
    required this.audioUrl,
    required this.thumbnailUrl,
    required this.sourceUrl,
    required this.license,
    required this.description,
  });

  String get providerName {
    switch (provider) {
      case OpenMusicProvider.internetArchive:
        return 'Internet Archive';
      case OpenMusicProvider.jamendo:
        return 'Jamendo';
    }
  }

  Uri get audioUri => Uri.parse(audioUrl);
  Uri get sourceUri => Uri.parse(sourceUrl);
  Uri? get thumbnailUri => thumbnailUrl.isEmpty ? null : Uri.tryParse(thumbnailUrl);

  String get shortDescription {
    final normalized = description.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 120) return normalized;
    return '${normalized.substring(0, 120)}…';
  }
}
