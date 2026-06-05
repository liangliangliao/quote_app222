import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../data/dao.dart';

/// A simple service for fetching astronomy pictures from NASA's public APIs.
///
/// This service currently exposes methods to retrieve the Astronomy Picture
/// of the Day (APOD) for a single day or a range of dates. The API key
/// must be provided by callers. NASA provides generous rate limits for
/// personal keys; if you do not supply a key your requests will fall back
/// to the built in demo key which is more restricted.
///
/// See: https://api.nasa.gov/#apod for full documentation.
class NasaApiService {
  /// Your NASA API key. See https://api.nasa.gov for instructions on
  /// generating a key. If omitted the service will use the public demo
  /// key which is subject to stricter rate limits.
  final String apiKey;

  // Local cache to avoid repeated requests when data already exists.
  final ApiCacheDao _apiCacheDao = ApiCacheDao();

  /// Optional proxy endpoint.
  ///
  /// If set, requests will be sent to:
  ///   {proxyUrl}?url=<URL-ENCODED-ORIGINAL-URL>
  ///
  /// This is useful in some network environments where NASA domains are
  /// unreachable (TLS handshake fails). You can deploy a tiny reverse-proxy
  /// (Cloudflare Worker / Nginx / your own backend) to forward requests.
  final String? proxyUrl;

  /// Whether to allow bad TLS certificates for NASA endpoints.
  ///
  /// Some older Android devices / custom ROMs have incomplete root CAs which
  /// can cause TLS handshake failures to NASA/GSFC/Heroku domains.
  ///
  /// ⚠️ SECURITY: Keep this `false` in production if possible.
  final bool allowBadCertificates;

  late final http.Client _client;

  DateTime? _serverTodayCache;

  NasaApiService({
    required this.apiKey,
    this.proxyUrl,
    this.allowBadCertificates = true,
  }) {
    if (allowBadCertificates) {
      final httpClient = HttpClient();
      httpClient.badCertificateCallback = (X509Certificate cert, String host, int port) {
        // Limit scope to NASA-related hosts.
        return host.contains('nasa.gov') ||
            host.contains('gsfc.nasa.gov') ||
            host.contains('herokuapp.com') ||
            host.contains('images-api.nasa.gov');
      };
      _client = IOClient(httpClient);
    } else {
      _client = http.Client();
    }
  }

  static const String _baseUrl = 'https://api.nasa.gov/planetary/apod';

  /// Returns NASA's "server date" (based on APOD's `date` field).
  ///
  /// This is more reliable than the device clock when users have a wrong
  /// system time (e.g. set to the future), which can break all date filters.
  Future<DateTime> fetchServerToday() async {
    final cached = _serverTodayCache;
    if (cached != null) return cached;
    final apod = await fetchTodayApod();
    // APOD uses YYYY-MM-DD.
    final parts = apod.date.split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) {
        _serverTodayCache = DateTime(y, m, d);
        return _serverTodayCache!;
      }
    }
    // Fallback: cache local now if parsing fails.
    _serverTodayCache = DateTime.now();
    return _serverTodayCache!;
  }

  /// Attempts to parse the APOD error message returned by NASA when a date
  /// range is out of bounds. Example:
  /// "Date must be between Jun 16, 1995 and Dec 31, 2025.".
  /// Returns a (min,max) tuple, or null if parsing fails.
  ({DateTime min, DateTime max})? _parseApodBounds(String body) {
    final lower = body.toLowerCase();
    final idx = lower.indexOf('date must be between');
    if (idx < 0) return null;
    final re = RegExp(r'between\s+([A-Za-z]{3,9}\s+\d{1,2},\s*\d{4})\s+and\s+([A-Za-z]{3,9}\s+\d{1,2},\s*\d{4})');
    final m = re.firstMatch(body);
    if (m == null) return null;
    DateTime? _parseHuman(String s) {
      // Accept: "Jun 16, 1995" or "June 16, 1995"
      final parts = s.replaceAll(',', '').split(RegExp(r'\s+'));
      if (parts.length != 3) return null;
      final monStr = parts[0].toLowerCase();
      const months = {
        'jan': 1,
        'january': 1,
        'feb': 2,
        'february': 2,
        'mar': 3,
        'march': 3,
        'apr': 4,
        'april': 4,
        'may': 5,
        'jun': 6,
        'june': 6,
        'jul': 7,
        'july': 7,
        'aug': 8,
        'august': 8,
        'sep': 9,
        'sept': 9,
        'september': 9,
        'oct': 10,
        'october': 10,
        'nov': 11,
        'november': 11,
        'dec': 12,
        'december': 12,
      };
      final mon = months[monStr];
      final day = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (mon == null || day == null || year == null) return null;
      return DateTime(year, mon, day);
    }

    final min = _parseHuman(m.group(1) ?? '');
    final max = _parseHuman(m.group(2) ?? '');
    if (min == null || max == null) return null;
    return (min: min, max: max);
  }

  /// Fetches the APOD for today. If the network request fails an
  /// [Exception] is thrown. On success a single [Apod] object is
  /// returned.
  Future<Apod> fetchTodayApod() async {
    final uri = Uri.parse('$_baseUrl?api_key=$apiKey');
    final res = await _get(uri);
    if (res.statusCode != 200) {
      throw Exception('NASA API error: ${res.statusCode}, ${res.body}');
    }
    final Map<String, dynamic> data = jsonDecode(res.body);
    return Apod.fromJson(data);
  }

  /// Fetches APOD entries between [startDate] and [endDate] inclusive.
  /// The NASA API supports returning a list of results when both
  /// `start_date` and `end_date` are supplied. If the response body is
  /// not a list a single element list will be returned.
  Future<List<Apod>> fetchApods({required DateTime startDate, required DateTime endDate}) async {
    DateTime s = startDate;
    DateTime e = endDate;

    String _ck(DateTime s0, DateTime e0) => 'apod|${_formatDate(s0)}|${_formatDate(e0)}';

    // Cache hit: no network request.
    final cachedBody = await _apiCacheDao.getJson(_ck(s, e));
    if (cachedBody != null && cachedBody.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(cachedBody);
        if (decoded is List) {
          return decoded.map<Apod>((e) => Apod.fromJson(e as Map<String, dynamic>)).toList();
        } else if (decoded is Map<String, dynamic>) {
          return [Apod.fromJson(decoded)];
        }
      } catch (_) {
        // If cache is corrupted, ignore and refetch.
        await _apiCacheDao.delete(_ck(s, e));
      }
    }

    Future<http.Response> _request(DateTime s0, DateTime e0) async {
      final start = _formatDate(s0);
      final end = _formatDate(e0);
      final uri = Uri.parse('$_baseUrl?api_key=$apiKey&start_date=$start&end_date=$end');
      return _get(uri);
    }

    http.Response res = await _request(s, e);
    if (res.statusCode != 200) {
      // Auto-clamp once if NASA tells us the valid bounds.
      final bounds = _parseApodBounds(res.body);
      if (bounds != null) {
        if (e.isAfter(bounds.max)) e = bounds.max;
        if (s.isBefore(bounds.min)) s = bounds.min;
        if (s.isAfter(e)) s = e;
        res = await _request(s, e);
      }
    }
    if (res.statusCode != 200) {
      throw Exception('NASA API error: ${res.statusCode}, ${res.body}');
    }

    // Save successful response to cache.
    await _apiCacheDao.putJson(_ck(s, e), res.body);
    final decoded = jsonDecode(res.body);
    if (decoded is List) {
      return decoded.map<Apod>((e) => Apod.fromJson(e as Map<String, dynamic>)).toList();
    } else if (decoded is Map<String, dynamic>) {
      return [Apod.fromJson(decoded)];
    }
    throw Exception('Unexpected NASA API response format');
  }

  /// Searches the NASA Image and Video Library for the given [query]. The
  /// optional [mediaType] filters results by type (e.g. `image`,
  /// `video`, `audio`). Results are paginated; [page] defaults to 1.
  /// Returns a list of [NasaMediaItem]s. On error an [Exception] is
  /// thrown.
  Future<List<NasaMediaItem>> searchMedia({
    required String query,
    String mediaType = 'image',
    int page = 1,
    DateTime? startDate,
    DateTime? endDate,
    // NOTE: previously we enabled an extra "real space photo" heuristic filter.
    // That filter is intentionally disabled by default to avoid performance
    // regressions and accidental false positives/negatives.
    bool spaceOnly = false,
  }) async {
    final qp = <String, String>{
      'q': query,
      'media_type': mediaType,
      'page': page.toString(),
    };
    // NASA Images API only supports year granularity.
    if (startDate != null) qp['year_start'] = startDate.year.toString();
    if (endDate != null) qp['year_end'] = endDate.year.toString();

    final uri = Uri.parse('https://images-api.nasa.gov/search').replace(queryParameters: qp);

    final cacheKey = 'images_search|q=$query|type=$mediaType|page=$page|ys=${startDate?.year ?? ""}|ye=${endDate?.year ?? ""}|spaceOnly=$spaceOnly';
    String body;
    final cachedBody = await _apiCacheDao.getJson(cacheKey);
    if (cachedBody != null && cachedBody.trim().isNotEmpty) {
      body = cachedBody;
    } else {
      final response = await _get(uri);
      if (response.statusCode != 200) {
        throw Exception('NASA Image search error: ${response.statusCode}, ${response.body}');
      }
      body = response.body;
      await _apiCacheDao.putJson(cacheKey, body);
    }
    final Map<String, dynamic> json = jsonDecode(body);
    final collection = json['collection'] as Map<String, dynamic>?;
    final items = collection != null ? collection['items'] as List<dynamic>? : null;
    if (items == null) return <NasaMediaItem>[];
    final List<NasaMediaItem> results = [];
    for (final item in items) {
      try {
        final map = item as Map<String, dynamic>;
        if (spaceOnly) {
          final dataList = map['data'] as List<dynamic>?;
          final data = (dataList != null && dataList.isNotEmpty && dataList.first is Map<String, dynamic>)
              ? dataList.first as Map<String, dynamic>
              : <String, dynamic>{};
          if (!_isLikelyRealSpacePhoto(data)) {
            continue;
          }
        }
        results.add(NasaMediaItem.fromSearchResult(map));
      } catch (_) {
        // Skip malformed items
      }
    }
    return results;
  }

  bool _isLikelyRealSpacePhoto(Map<String, dynamic> data) {
    final title = (data['title'] ?? '').toString().toLowerCase();
    final desc = ((data['description_508'] ?? data['description'] ?? '')).toString().toLowerCase();
    final kwAny = data['keywords'];
    String keywords = '';
    if (kwAny is List) {
      keywords = kwAny.map((e) => e.toString()).join(' ').toLowerCase();
    } else {
      keywords = (kwAny ?? '').toString().toLowerCase();
    }
    final combined = '$title\n$desc\n$keywords';

    // 排除：海报/概念图/徽章/宣传物料/人物写真等
    const deny = [
      'poster',
      'logo',
      'patch',
      'infographic',
      'illustration',
      'artist',
      'concept',
      'render',
      'rendering',
      'simulation',
      'animation',
      'diagram',
      'brochure',
      'flyer',
      'advertisement',
      'press kit',
      'wallpaper',
      'portrait',
      'headshot',
      'crew',
      'astronaut',
      'people',
      'human',
      'employee',
      'team',
    ];
    for (final w in deny) {
      if (combined.contains(w)) return false;
    }

    // 允许：天体/望远镜/深空/行星探测相关关键词
    const allow = [
      'nebula',
      'galaxy',
      'star',
      'stars',
      'planet',
      'mars',
      'jupiter',
      'saturn',
      'uranus',
      'neptune',
      'mercury',
      'venus',
      'earth',
      'moon',
      'lunar',
      'solar',
      'sun',
      'comet',
      'asteroid',
      'meteor',
      'eclipse',
      'supernova',
      'exoplanet',
      'milky way',
      'andromeda',
      'hubble',
      'jwst',
      'james webb',
      'webb',
      'telescope',
      'observatory',
      'deep field',
      'cosmic',
      'interstellar',
      'iss',
      'international space station',
      'spacecraft',
      'probe',
      'rover',
      'voyager',
      'cassini',
      'juno',
      'new horizons',
      'perseverance',
      'curiosity',
      'apollo',
    ];
    for (final w in allow) {
      if (combined.contains(w)) return true;
    }
    return false;
  }

  /// Fetches photos taken by a Mars rover on a given Earth [earthDate]. The
  /// [rover] parameter selects which rover's photos to return (e.g.
  /// `curiosity`, `opportunity`, `spirit`, `perseverance`).
  Future<List<MarsPhoto>> fetchMarsPhotos({
    String rover = 'curiosity',
    required DateTime earthDate,
  }) async {
    final dateStr = _formatDate(earthDate);
    // NOTE:
    // The Mars Rover Photos API has historically been served from api.nasa.gov.
    // There have been periods where this endpoint returns a 404 HTML page
    // ("No such app"). For resilience, we try api.nasa.gov first, then fall
    // back to the Heroku mirror.
    final nasaUri = Uri.parse(
        'https://api.nasa.gov/mars-photos/api/v1/rovers/$rover/photos?earth_date=$dateStr&api_key=$apiKey');
    http.Response res;
    try {
      res = await _get(nasaUri, timeout: const Duration(seconds: 20));
    } catch (_) {
      // Network error/timeouts - fall back below.
      res = http.Response('', 599);
    }

    bool _looksLikeJson(http.Response r) {
      final ct = (r.headers['content-type'] ?? '').toLowerCase();
      if (ct.contains('application/json')) return true;
      final b = r.body.trimLeft();
      return b.startsWith('{') || b.startsWith('[');
    }

    // The api.nasa.gov endpoint sometimes returns a 404 HTML page ("No such app")
    // or other non-JSON responses. In those cases, fall back to the Heroku mirror.
    final shouldFallback = res.statusCode != 200 || !_looksLikeJson(res);
    if (shouldFallback) {
      final herokuUri = Uri.parse(
          'https://mars-photos.herokuapp.com/api/v1/rovers/$rover/photos?earth_date=$dateStr');
      res = await _get(herokuUri, timeout: const Duration(seconds: 20));
    }

    if (res.statusCode != 200) {
      throw Exception('Mars photos API error: ${res.statusCode}');
    }

    final Map<String, dynamic> data = jsonDecode(res.body);
    final List<dynamic>? photos = data['photos'] as List<dynamic>?;
    if (photos == null) return <MarsPhoto>[];
    final List<MarsPhoto> results = [];
    for (final p in photos) {
      try {
        results.add(MarsPhoto.fromJson(p as Map<String, dynamic>));
      } catch (_) {
        // Skip malformed photos
      }
    }
    return results;
  }

  /// Fetches the latest available photos for a Mars rover.
  ///
  /// This is more user-friendly than choosing a date that might have no
  /// data (e.g. device clock in the future). Tries api.nasa.gov first, then
  /// falls back to the Heroku mirror.
  Future<List<MarsPhoto>> fetchMarsLatestPhotos({String rover = 'curiosity'}) async {
    final nasaUri = Uri.parse(
        'https://api.nasa.gov/mars-photos/api/v1/rovers/$rover/latest_photos?api_key=$apiKey');
    http.Response res;
    try {
      res = await _get(nasaUri, timeout: const Duration(seconds: 20));
    } catch (_) {
      res = http.Response('', 599);
    }

    bool _looksLikeJson(http.Response r) {
      final ct = (r.headers['content-type'] ?? '').toLowerCase();
      if (ct.contains('application/json')) return true;
      final b = r.body.trimLeft();
      return b.startsWith('{') || b.startsWith('[');
    }

    final shouldFallback = res.statusCode != 200 || !_looksLikeJson(res);
    if (shouldFallback) {
      final herokuUri =
          Uri.parse('https://mars-photos.herokuapp.com/api/v1/rovers/$rover/latest_photos');
      res = await _get(herokuUri, timeout: const Duration(seconds: 20));
    }

    if (res.statusCode != 200) {
      // NASA has archived the Mars Rover API and the historical latest_photos
      // endpoint may now return 404 for some deployments. For the “最新天体”
      // aggregate feed we treat this as an empty source instead of failing the
      // whole page.
      if (res.statusCode == 404) {
        return <MarsPhoto>[];
      }
      throw Exception('Mars latest photos API error: ${res.statusCode}');
    }
    final dynamic decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      return <MarsPhoto>[];
    }
    final List<dynamic>? photos = decoded['latest_photos'] as List<dynamic>?;
    if (photos == null) return <MarsPhoto>[];
    final List<MarsPhoto> results = [];
    for (final p in photos) {
      if (p is! Map<String, dynamic>) continue;
      try {
        results.add(MarsPhoto.fromJson(p));
      } catch (_) {
        // Skip malformed records.
      }
    }
    return results;
  }

  /// Retrieves a list of EPIC images. When [natural] is true the
  /// `natural` collection is used; otherwise the `enhanced` set is
  /// returned. Each item includes a fully qualified image URL.
  Future<List<EpicImage>> fetchEpicImages({bool natural = true}) async {
    final collection = natural ? 'natural' : 'enhanced';
    // Prefer the EPIC primary service which has stable archive URLs.
    // The api.nasa.gov service is a mirror and may occasionally fail.
    http.Response res;
    try {
      res = await _get(
        Uri.parse('https://epic.gsfc.nasa.gov/api/$collection'),
        timeout: const Duration(seconds: 20),
      );
    } catch (_) {
      res = http.Response('', 599);
    }

    if (res.statusCode != 200) {
      // Fallback to api.nasa.gov mirror
      final mirrorUri = Uri.parse('https://api.nasa.gov/EPIC/api/$collection?api_key=$apiKey');
      res = await _get(mirrorUri, timeout: const Duration(seconds: 20));
    }

    if (res.statusCode != 200) {
      throw Exception('EPIC API error: ${res.statusCode}');
    }

    final List<dynamic> list = jsonDecode(res.body) as List<dynamic>;
    final List<EpicImage> results = [];
    for (final item in list) {
      try {
        final map = item as Map<String, dynamic>;
        // Construct the image URL using the date and image name.
        final dateStr = (map['date'] ?? '').toString();
        final imageName = (map['image'] ?? '').toString();
        if (dateStr.isEmpty || imageName.isEmpty) continue;
        final datePart = dateStr.split(' ').first;
        final parts = datePart.split('-');
        if (parts.length != 3) continue;
        final year = parts[0];
        final month = parts[1];
        final day = parts[2];
        // Images are hosted under the EPIC archive. Prefer epic.gsfc.
        final url = 'https://epic.gsfc.nasa.gov/archive/$collection/$year/$month/$day/png/$imageName.png';
        results.add(EpicImage(
          date: dateStr,
          imageName: imageName,
          caption: (map['caption'] ?? '').toString(),
          url: url,
        ));
      } catch (_) {
        // skip
      }
    }
    return results;
  }

  /// Fetches a single Earth imagery from the NASA Earth Imagery API. The
  /// [lat] and [lon] coordinates must be specified. If [date] is
  /// provided the image closest to that date is returned; otherwise
  /// the most recent image is fetched. Returns an [EarthImage].
  Future<EarthImage> fetchEarthImagery({
    required double lat,
    required double lon,
    DateTime? date,
  }) async {
    // The /assets endpoint returns available dates/ids, not a direct url.
    // We then build an /imagery url (returns image bytes) and use that URL
    // directly in Image.network.

    final params = <String, String>{
      'lat': lat.toString(),
      'lon': lon.toString(),
      'api_key': apiKey,
    };
    if (date != null) params['date'] = _formatDate(date);

    final assetsUri = Uri.parse('https://api.nasa.gov/planetary/earth/assets')
        .replace(queryParameters: params);
    final res = await _get(assetsUri, timeout: const Duration(seconds: 35));
    if (res.statusCode != 200) {
      throw Exception('Earth assets API error: ${res.statusCode}, ${res.body}');
    }

    final Map<String, dynamic> data = jsonDecode(res.body);
    String pickedDate = '';
    String pickedId = '';

    if (data['date'] is String) pickedDate = data['date'] as String;
    if (data['id'] != null) pickedId = data['id'].toString();
    final results = data['results'];
    if (results is List && results.isNotEmpty) {
      final first = results.first;
      if (first is Map<String, dynamic>) {
        pickedDate = (first['date'] ?? pickedDate).toString();
        pickedId = (first['id'] ?? pickedId).toString();
      }
    }

    if (pickedDate.isEmpty) {
      throw Exception('该坐标在所选日期附近没有可用的卫星影像');
    }
    final dateOnly = pickedDate.split('T').first;
    final imageryUrl = buildEarthImageryUrl(lat: lat, lon: lon, date: dateOnly);
    return EarthImage(date: dateOnly, id: pickedId, url: imageryUrl);
  }

  /// Returns an imagery URL that points to image bytes.
  /// Use this URL directly in Image.network.
  String buildEarthImageryUrl({
    required double lat,
    required double lon,
    required String date,
    double dim = 0.15,
  }) {
    final qp = {
      'lat': lat.toString(),
      'lon': lon.toString(),
      'date': date,
      'dim': dim.toString(),
      'api_key': apiKey,
    };
    return Uri.parse('https://api.nasa.gov/planetary/earth/imagery')
        .replace(queryParameters: qp)
        .toString();
  }

  /// Fetches Earth "assets" in a date range. Each result is converted into an
  /// imagery url that can be displayed.
  Future<List<EarthImage>> fetchEarthAssetsRange({
    required double lat,
    required double lon,
    required DateTime begin,
    required DateTime end,
  }) async {
    // IMPORTANT (per requirement): the legacy NASA Earth Assets API is
    // unreliable / can time out. Instead of calling it, we generate imagery
    // URLs using NASA Earthdata GIBS (WMS). This avoids request timeouts when
    // fetching the list.

    DateTime start = begin;
    DateTime finish = end;
    if (start.isAfter(finish)) {
      final tmp = start;
      start = finish;
      finish = tmp;
    }

    // Choose a sensible sampling step so extremely long ranges do not create
    // tens of thousands of items.
    final totalDays = finish.difference(start).inDays.abs() + 1;
    const maxItems = 365;
    final step = totalDays <= maxItems ? 1 : (totalDays / maxItems).ceil();

    final cacheKey = 'earth_wms|lat=$lat|lon=$lon|start=${_formatDate(start)}|end=${_formatDate(finish)}|step=$step';
    final cachedBody = await _apiCacheDao.getJson(cacheKey);
    if (cachedBody != null && cachedBody.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(cachedBody);
        if (decoded is List) {
          return decoded
              .whereType<Map<String, dynamic>>()
              .map<EarthImage>((m) => EarthImage.fromJson(m))
              .toList();
        }
      } catch (_) {
        await _apiCacheDao.delete(cacheKey);
      }
    }

    const layer = 'MODIS_Terra_CorrectedReflectance_TrueColor';
    const baseWms = 'https://gibs.earthdata.nasa.gov/wms/epsg4326/best/wms.cgi';

    String buildGibsWmsUrl(String dateOnly) {
      // WMS 1.1.1 uses lon,lat bbox order (avoids EPSG:4326 axis confusion in 1.3.0).
      const double halfSize = 0.5; // degrees
      final latMin = (lat - halfSize).clamp(-90.0, 90.0);
      final latMax = (lat + halfSize).clamp(-90.0, 90.0);
      final lonMin = (lon - halfSize).clamp(-180.0, 180.0);
      final lonMax = (lon + halfSize).clamp(-180.0, 180.0);
      final qp = <String, String>{
        'SERVICE': 'WMS',
        'REQUEST': 'GetMap',
        'VERSION': '1.1.1',
        'LAYERS': layer,
        'STYLES': '',
        'FORMAT': 'image/jpeg',
        'TRANSPARENT': 'FALSE',
        'SRS': 'EPSG:4326',
        'BBOX': '$lonMin,$latMin,$lonMax,$latMax',
        'WIDTH': '512',
        'HEIGHT': '512',
        'TIME': dateOnly,
      };
      return Uri.parse(baseWms).replace(queryParameters: qp).toString();
    }

    final out = <EarthImage>[];
    // Newest first.
    for (var d = finish; !d.isBefore(start); d = d.subtract(Duration(days: step))) {
      final dateOnly = _formatDate(d);
      out.add(EarthImage(
        date: dateOnly,
        id: 'gibs_$dateOnly',
        url: buildGibsWmsUrl(dateOnly),
      ));
      // Safety to prevent infinite loops when step is weird.
      if (out.length > maxItems + 5) break;
    }

    // Persist generated list.
    try {
      await _apiCacheDao.putJson(
        cacheKey,
        jsonEncode(out.map((e) => e.toJson()).toList()),
      );
    } catch (_) {
      // ignore cache save failures
    }
    return out;
  }

  /// Fetch EPIC images for a specific date.
  Future<List<EpicImage>> fetchEpicImagesForDate({
    required DateTime date,
    bool natural = true,
  }) async {
    final collection = natural ? 'natural' : 'enhanced';
    final d = _formatDate(date);

    final cacheKey = 'epic|$collection|$d';
    String body;
    final cachedBody = await _apiCacheDao.getJson(cacheKey);
    if (cachedBody != null && cachedBody.trim().isNotEmpty) {
      body = cachedBody;
    } else {
      http.Response res;
      try {
        res = await _get(
          Uri.parse('https://epic.gsfc.nasa.gov/api/$collection/date/$d'),
          timeout: const Duration(seconds: 20),
        );
      } catch (_) {
        res = http.Response('', 599);
      }
      if (res.statusCode != 200) {
        final mirrorUri = Uri.parse(
            'https://api.nasa.gov/EPIC/api/$collection/date/$d?api_key=$apiKey');
        res = await _get(mirrorUri, timeout: const Duration(seconds: 20));
      }
      if (res.statusCode != 200) {
        throw Exception('EPIC API error: ${res.statusCode}');
      }
      body = res.body;
      await _apiCacheDao.putJson(cacheKey, body);
    }

    final List<dynamic> list = jsonDecode(body) as List<dynamic>;
    final List<EpicImage> results = [];
    for (final item in list) {
      try {
        final map = item as Map<String, dynamic>;
        final dateStr = (map['date'] ?? '').toString();
        final imageName = (map['image'] ?? '').toString();
        if (dateStr.isEmpty || imageName.isEmpty) continue;
        final datePart = dateStr.split(' ').first;
        final parts = datePart.split('-');
        if (parts.length != 3) continue;
        final year = parts[0];
        final month = parts[1];
        final day = parts[2];
        final url =
            'https://epic.gsfc.nasa.gov/archive/$collection/$year/$month/$day/png/$imageName.png';
        results.add(EpicImage(
          date: dateStr,
          imageName: imageName,
          caption: (map['caption'] ?? '').toString(),
          url: url,
        ));
      } catch (_) {}
    }
    return results;
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Uri _wrapWithProxy(Uri uri) {
    final p = proxyUrl;
    if (p == null || p.trim().isEmpty) return uri;
    return Uri.parse(p).replace(queryParameters: {
      'url': uri.toString(),
    });
  }

  Future<http.Response> _get(
    Uri uri, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final wrapped = _wrapWithProxy(uri);
    try {
      // 简单重试（握手/临时网络抖动时更稳定）
      http.Response res;
      try {
        res = await _client.get(
          wrapped,
          headers: const {
            'User-Agent': 'SpaceExplorerApp/1.0',
            'Accept': 'application/json,*/*',
          },
        ).timeout(timeout);
      } catch (_) {
        // retry once
        res = await _client.get(
          wrapped,
          headers: const {
            'User-Agent': 'SpaceExplorerApp/1.0',
            'Accept': 'application/json,*/*',
          },
        ).timeout(timeout);
      }
      return res;
    } on HandshakeException {
      throw Exception('网络 TLS 握手失败：可能是网络限制/证书问题。\n建议：开启系统自动时间，或使用代理/加速网络后重试。');
    } on SocketException {
      throw Exception('网络连接失败：请检查网络后重试。');
    } on TimeoutException {
      throw Exception('请求超时：请检查网络或稍后重试。');
    }
  }
}

/// A model representing NASA's Astronomy Picture of the Day entry.
///
/// Most APOD entries are images but the API also returns videos on
/// occasion; callers should check [mediaType] and handle non‑image
/// entries appropriately.
class Apod {
  final String date;
  final String title;
  final String explanation;
  final String mediaType;
  final String url;
  final String? hdUrl;

  Apod({
    required this.date,
    required this.title,
    required this.explanation,
    required this.mediaType,
    required this.url,
    this.hdUrl,
  });

  factory Apod.fromJson(Map<String, dynamic> json) {
    return Apod(
      date: (json['date'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      explanation: (json['explanation'] ?? '').toString(),
      mediaType: (json['media_type'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      hdUrl: json['hdurl']?.toString(),
    );
  }
}

/// Represents a single item returned by the NASA Image and Video
/// Library search API. Each item contains minimal metadata and
/// thumbnail/full image URLs. Some items may not include thumbnails;
/// callers should handle empty strings accordingly.
class NasaMediaItem {
  final String id;
  final String title;
  final String description;
  final String date;
  final String thumbUrl;
  final String mediaUrl;

  NasaMediaItem({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.thumbUrl,
    required this.mediaUrl,
  });

  /// Creates a [NasaMediaItem] from a search result item structure
  /// returned by the NASA Images API. The structure contains a list
  /// under `data` with the metadata and a list under `links` with
  /// preview URLs. This factory extracts the first available preview
  /// and basic descriptive fields.
  factory NasaMediaItem.fromSearchResult(Map<String, dynamic> item) {
    final dataList = item['data'] as List<dynamic>?;
    final linksList = item['links'] as List<dynamic>?;
    final data = dataList != null && dataList.isNotEmpty
        ? dataList.first as Map<String, dynamic>
        : <String, dynamic>{};
    final String id = (data['nasa_id'] ?? '').toString();
    final String title = (data['title'] ?? '').toString();
    final String description = (data['description'] ?? '').toString();
    final String date = (data['date_created'] ?? '').toString();
    String thumbUrl = '';
    String mediaUrl = '';
    if (linksList != null && linksList.isNotEmpty) {
      // Pick the first link with a render hint of image or a preview.
      for (final l in linksList) {
        final link = l as Map<String, dynamic>;
        final rel = (link['rel'] ?? '').toString();
        final render = (link['render'] ?? '').toString();
        final href = (link['href'] ?? '').toString();
        if (href.isNotEmpty && (render == 'image' || rel == 'preview')) {
          thumbUrl = href;
          mediaUrl = href;
          break;
        }
      }
      // Fallback: use the first link's href for both thumb and media
      if (thumbUrl.isEmpty) {
        final first = linksList.first as Map<String, dynamic>;
        final href = (first['href'] ?? '').toString();
        thumbUrl = href;
        mediaUrl = href;
      }
    }
    return NasaMediaItem(
      id: id,
      title: title,
      description: description,
      date: date,
      thumbUrl: thumbUrl,
      mediaUrl: mediaUrl,
    );
  }
}

/// Represents a single photo taken by a Mars rover. Contains the
/// image URL as well as identifying information about the rover,
/// camera and Earth date when it was captured.
class MarsPhoto {
  final int id;
  final String imageUrl;
  final String rover;
  final String camera;
  final String earthDate;

  MarsPhoto({
    required this.id,
    required this.imageUrl,
    required this.rover,
    required this.camera,
    required this.earthDate,
  });

  factory MarsPhoto.fromJson(Map<String, dynamic> json) {
    final rover = json['rover'] as Map<String, dynamic>?;
    final camera = json['camera'] as Map<String, dynamic>?;
    return MarsPhoto(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      imageUrl: (json['img_src'] ?? '').toString(),
      rover: (rover?['name'] ?? '').toString(),
      camera: (camera?['full_name'] ?? '').toString(),
      earthDate: (json['earth_date'] ?? '').toString(),
    );
  }
}

/// Represents an image from the Earth Polychromatic Imaging Camera (EPIC)
/// instrument. Each entry includes the full URL to the PNG image as
/// well as the capture date and caption.
class EpicImage {
  final String date;
  final String imageName;
  final String caption;
  final String url;

  EpicImage({
    required this.date,
    required this.imageName,
    required this.caption,
    required this.url,
  });
}

/// Represents imagery returned from the NASA Earth Imagery endpoint.
/// Contains the image capture date, an identifier and a direct image
/// URL. The URL points to a static image; further metadata is
/// available via the `id` if needed.
class EarthImage {
  final String date;
  final String id;
  final String url;

  EarthImage({
    required this.date,
    required this.id,
    required this.url,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'date': date,
        'id': id,
        'url': url,
      };

  factory EarthImage.fromJson(Map<String, dynamic> json) {
    return EarthImage(
      date: (json['date'] ?? '').toString(),
      id: (json['id'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
    );
  }
}