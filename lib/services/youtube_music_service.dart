import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/kv_dao.dart';

/// Lightweight YouTube music search adapter.
///
/// This service only uses the official YouTube Data API for search metadata.
/// Playback is handled by embedding the official YouTube player in the UI;
/// it never extracts, downloads, caches, or separates audio streams.
class YoutubeMusicService {
  YoutubeMusicService({KeyValueDao? kvDao}) : _kvDao = kvDao ?? KeyValueDao();

  static const String apiKeyKvKey = 'youtube_data_api_key';

  final KeyValueDao _kvDao;

  Future<String> getApiKey() async {
    return ((await _kvDao.getString(apiKeyKvKey)) ?? '').trim();
  }

  Future<bool> hasApiKey() async => (await getApiKey()).isNotEmpty;

  Future<List<YoutubeMusicTrack>> search(
    String query, {
    int maxResults = 12,
    String? regionCode,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return <YoutubeMusicTrack>[];

    final apiKey = await getApiKey();
    if (apiKey.isEmpty) {
      throw const YoutubeMusicException('请先在设置页配置 YouTube Data API Key');
    }

    final safeMax = maxResults.clamp(1, 25).toInt();
    final params = <String, String>{
      'part': 'snippet',
      'type': 'video',
      'videoCategoryId': '10', // Music category.
      'maxResults': safeMax.toString(),
      'q': q,
      'key': apiKey,
      'safeSearch': 'none',
      // Prefer videos that YouTube says can be embedded and played outside youtube.com.
      // This reduces in-app player failures caused by video-owner or syndication limits.
      'videoEmbeddable': 'true',
      'videoSyndicated': 'true',
    };
    final region = regionCode?.trim().toUpperCase();
    if (region != null && region.length == 2) {
      params['regionCode'] = region;
    }

    final uri = Uri.https('www.googleapis.com', '/youtube/v3/search', params);
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    final decoded = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _extractApiError(decoded) ?? 'YouTube 搜索失败（HTTP ${response.statusCode}）';
      throw YoutubeMusicException(message);
    }

    if (decoded is! Map<String, dynamic>) return <YoutubeMusicTrack>[];
    final items = decoded['items'];
    if (items is! List) return <YoutubeMusicTrack>[];

    return items
        .whereType<Map>()
        .map((raw) => YoutubeMusicTrack.fromSearchItem(Map<String, dynamic>.from(raw)))
        .where((track) => track.videoId.isNotEmpty)
        .toList(growable: false);
  }

  String? _extractApiError(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message']?.toString().trim();
        if (message != null && message.isNotEmpty) return message;
      }
    }
    return null;
  }
}

class YoutubeMusicException implements Exception {
  final String message;
  const YoutubeMusicException(this.message);

  @override
  String toString() => message;
}

class YoutubeMusicTrack {
  final String videoId;
  final String title;
  final String channelTitle;
  final String thumbnailUrl;
  final DateTime? publishedAt;

  const YoutubeMusicTrack({
    required this.videoId,
    required this.title,
    required this.channelTitle,
    required this.thumbnailUrl,
    this.publishedAt,
  });

  factory YoutubeMusicTrack.fromSearchItem(Map<String, dynamic> item) {
    final id = item['id'];
    final snippet = item['snippet'];
    final videoId = id is Map ? (id['videoId'] ?? '').toString() : '';
    final rawSnippet = snippet is Map ? snippet : const <String, dynamic>{};
    final thumbnails = rawSnippet['thumbnails'];
    String thumb = '';
    if (thumbnails is Map) {
      for (final key in const <String>['high', 'medium', 'default']) {
        final node = thumbnails[key];
        if (node is Map && (node['url'] ?? '').toString().isNotEmpty) {
          thumb = node['url'].toString();
          break;
        }
      }
    }
    DateTime? published;
    final publishedRaw = rawSnippet['publishedAt']?.toString();
    if (publishedRaw != null && publishedRaw.isNotEmpty) {
      published = DateTime.tryParse(publishedRaw);
    }
    return YoutubeMusicTrack(
      videoId: videoId,
      title: _decodeHtmlEntities((rawSnippet['title'] ?? '').toString()),
      channelTitle: _decodeHtmlEntities((rawSnippet['channelTitle'] ?? '').toString()),
      thumbnailUrl: thumb,
      publishedAt: published,
    );
  }

  Uri get watchUri => Uri.https('www.youtube.com', '/watch', {'v': videoId});

  Uri get embedUri => Uri.https('www.youtube-nocookie.com', '/embed/$videoId', {
        'autoplay': '1',
        'playsinline': '1',
        'controls': '1',
        'rel': '0',
        'modestbranding': '1',
      });

  static String _decodeHtmlEntities(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');
  }
}
