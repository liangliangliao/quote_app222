import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/nasa_api_service.dart';
import '../services/translation_service.dart';
import '../utils/image_downloader.dart';
import 'apod_detail_page.dart';
import 'epic_image_detail_page.dart';
import 'nasa_media_detail_page.dart';

/// "看宇宙" 页面：
/// - 每日 APOD（支持日期范围筛选、50 条分页、下拉加载）
/// - 图像搜索（支持日期范围筛选、50 条分页、下拉加载）
/// - 探测器照片（基于 NASA Image & Video Library，支持日期范围筛选、50 条分页、下拉加载）
/// - 火星照片（优先使用 Image & Video Library 的火星相关真实照片，避免 Mars-Rover API 404 波动）
/// - EPIC 地球（支持日期范围筛选，按天回溯加载，50 条分页）
/// - 地球影像（Earth Assets：按经纬度 + 日期范围返回可用影像列表，50 条分页）
class SpaceExplorerPage extends StatefulWidget {
  const SpaceExplorerPage({super.key});

  @override
  State<SpaceExplorerPage> createState() => _SpaceExplorerPageState();
}

/// Probe / mission presets for the “探测器照片” tab.
///
/// These are curated common missions/telescopes to help users who
/// don’t know what to search. (NASA does not provide a single API that
/// enumerates *all* probes across all datasets.)
class _ProbePreset {
  final String category;
  final String name;
  final String query;
  const _ProbePreset({
    required this.category,
    required this.name,
    required this.query,
  });
}

class _LatestSpaceFeedItem {
  final String source;
  final String title;
  final String subtitle;
  final String description;
  final String mediaType;
  final String imageUrl;
  final VoidCallback? onTap;

  const _LatestSpaceFeedItem({
    required this.source,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.mediaType,
    required this.imageUrl,
    this.onTap,
  });
}

class _SpaceExplorerPageState extends State<SpaceExplorerPage>
    with SingleTickerProviderStateMixin {
  // NASA API Key
  static const String _nasaApiKey = 'yl0Zwzo2DiDT6BvM3ITCieFjuiGhhgjFvak56sRS';
  static const String _nasaProxy =
      String.fromEnvironment('NASA_PROXY', defaultValue: '');

  late final NasaApiService _service;
  late final TranslationService _translator;
  late final TabController _tabController;

  // Translation
  String _targetLang = 'zh';
  String _targetLangName = '中文';

  // NASA 服务器“今天”日期（用于修正设备时间不准导致的日期筛选失败）
  DateTime _serverToday = DateTime.now();
  bool _serverDateReady = false;

  // -------------------- 最新天体图像 / 视频 --------------------
  bool _latestLoading = false;
  String? _latestError;
  List<_LatestSpaceFeedItem> _latestFeed = <_LatestSpaceFeedItem>[];

  // -------------------- Common helpers --------------------
  String _fmt(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<DateTime?> _pickDate(DateTime initial, DateTime first, DateTime last) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
  }

  // -------------------- APOD (paged by 50 days) --------------------
  final ScrollController _apodScroll = ScrollController();
  List<Apod> _apods = [];
  bool _apodLoading = false;
  bool _apodLoadingMore = false;
  bool _apodHasMore = true;
  String? _apodError;
  late DateTime _apodEndBound;
  late DateTime _apodStartBound;
  late DateTime _apodCursorEnd;
  final Map<String, String> _apodTitleT = <String, String>{}; // key: <lang>|<date>
  final Map<String, String> _apodExpT = <String, String>{}; // key: <lang>|<date>

  // -------------------- Image search (paged by 50 using buffer) --------------------
  final ScrollController _searchScroll = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  List<NasaMediaItem> _searchShown = [];
  final Map<String, String> _searchTitleT = <String, String>{}; // key: <lang>|<id>
  final Map<String, String> _mediaDescT = <String, String>{}; // key: <lang>|<id>
  final List<NasaMediaItem> _searchBuffer = [];
  bool _searchLoading = false;
  bool _searchLoadingMore = false;
  bool _searchHasMore = true;
  String? _searchError;
  int _searchPage = 1;
  late DateTime _searchStart;
  late DateTime _searchEnd;

  // -------------------- Probe photos tab (same as search) --------------------
  final ScrollController _probeScroll = ScrollController();
  final TextEditingController _probeQueryController =
      TextEditingController(text: 'spacecraft');
  // will be overwritten in initState based on presets
  String _probePresetName = '自定义（手动输入关键词）';
  late final List<_ProbePreset> _probePresets = _buildProbePresets();
  List<NasaMediaItem> _probeShown = [];
  final Map<String, String> _probeTitleT = <String, String>{};
  final List<NasaMediaItem> _probeBuffer = [];
  bool _probeLoading = false;
  bool _probeLoadingMore = false;
  bool _probeHasMore = true;
  String? _probeError;
  int _probePage = 1;
  late DateTime _probeStart;
  late DateTime _probeEnd;

  // -------------------- Mars photos tab (use images-api) --------------------
  final ScrollController _marsScroll = ScrollController();
  String _marsPreset = 'Mars rover';
  List<NasaMediaItem> _marsShown = [];
  final Map<String, String> _marsTitleT = <String, String>{};
  final List<NasaMediaItem> _marsBuffer = [];
  bool _marsLoading = false;
  bool _marsLoadingMore = false;
  bool _marsHasMore = true;
  String? _marsError;
  int _marsPage = 1;
  late DateTime _marsStart;
  late DateTime _marsEnd;

  // -------------------- EPIC (paged by dates) --------------------
  final ScrollController _epicScroll = ScrollController();
  List<EpicImage> _epicImages = [];
  bool _epicLoading = false;
  bool _epicLoadingMore = false;
  bool _epicHasMore = true;
  String? _epicError;
  late DateTime _epicStart;
  late DateTime _epicEnd;
  late DateTime _epicCursor;

  // -------------------- Earth imagery assets (list + paging) --------------------
  final ScrollController _earthScroll = ScrollController();
  final TextEditingController _latController = TextEditingController(text: '31.2304');
  final TextEditingController _lonController = TextEditingController(text: '121.4737');
  late DateTime _earthStart;
  late DateTime _earthEnd;
  List<EarthImage> _earthAll = [];
  List<EarthImage> _earthShown = [];
  bool _earthLoading = false;
  bool _earthLoadingMore = false;
  bool _earthHasMore = true;
  String? _earthError;
  int _earthShownCount = 0;

  @override
  void initState() {
    super.initState();
    _service = NasaApiService(
      apiKey: _nasaApiKey,
      proxyUrl: _nasaProxy.isEmpty ? null : _nasaProxy,
      allowBadCertificates: true,
    );

    _translator = TranslationService();

    _tabController = TabController(length: 7, vsync: this);

    // 先用本地时间做占位（如果用户设备时间不准，稍后会用 NASA 服务器时间修正）
    _applyDefaultRanges(DateTime.now());

    _apodScroll.addListener(() {
      if (_apodHasMore && !_apodLoadingMore && _apodScroll.position.pixels > _apodScroll.position.maxScrollExtent - 400) {
        _loadApodMore();
      }
    });
    _searchScroll.addListener(() {
      if (_searchHasMore && !_searchLoadingMore && _searchScroll.position.pixels > _searchScroll.position.maxScrollExtent - 400) {
        _loadSearchMore();
      }
    });
    _probeScroll.addListener(() {
      if (_probeHasMore && !_probeLoadingMore && _probeScroll.position.pixels > _probeScroll.position.maxScrollExtent - 400) {
        _loadProbeMore();
      }
    });
    _marsScroll.addListener(() {
      if (_marsHasMore && !_marsLoadingMore && _marsScroll.position.pixels > _marsScroll.position.maxScrollExtent - 400) {
        _loadMarsMore();
      }
    });
    _epicScroll.addListener(() {
      if (_epicHasMore && !_epicLoadingMore && _epicScroll.position.pixels > _epicScroll.position.maxScrollExtent - 400) {
        _loadEpicMore();
      }
    });
    _earthScroll.addListener(() {
      if (_earthHasMore && !_earthLoadingMore && _earthScroll.position.pixels > _earthScroll.position.maxScrollExtent - 400) {
        _loadEarthMore();
      }
    });

    _bootstrap();
  }

  void _applyDefaultRanges(DateTime now) {
    // 默认：过去 1 年范围（用户可自行调整）
    _apodEndBound = now;
    _apodStartBound = now.subtract(const Duration(days: 365));
    _apodCursorEnd = _apodEndBound;

    _searchEnd = now;
    _searchStart = now.subtract(const Duration(days: 365));

    _probeEnd = now;
    _probeStart = now.subtract(const Duration(days: 365));

    _marsEnd = now;
    _marsStart = now.subtract(const Duration(days: 365));

    _epicEnd = now;
    _epicStart = now.subtract(const Duration(days: 30));
    _epicCursor = _epicEnd;

    _earthEnd = now;
    _earthStart = now.subtract(const Duration(days: 30));
  }

  List<_ProbePreset> _buildProbePresets() {
    // NASA Images API is keyword-based search, and NASA does not provide a
    // single API that enumerates *all* probes. Here we provide a broad,
    // practical mission/telescope list (with good search keywords) so users
    // can pick without knowing mission names.
    return const <_ProbePreset>[
      _ProbePreset(category: '常用', name: '自定义（手动输入关键词）', query: 'spacecraft'),
      _ProbePreset(category: '常用', name: '深空/宇宙实拍（综合）', query: 'deep space telescope nebula galaxy star cluster'),
      _ProbePreset(category: '常用', name: '行星/卫星实拍（综合）', query: 'planet moon spacecraft image'),
      _ProbePreset(category: '常用', name: '火星实拍（综合）', query: 'mars rover surface image'),

      // --- Telescopes / Observatories ---
      _ProbePreset(category: '望远镜/天文台', name: 'James Webb（JWST）', query: 'james webb space telescope'),
      _ProbePreset(category: '望远镜/天文台', name: 'Hubble（哈勃）', query: 'hubble space telescope'),
      _ProbePreset(category: '望远镜/天文台', name: 'Chandra（钱德拉 X 射线）', query: 'chandra x-ray observatory'),
      _ProbePreset(category: '望远镜/天文台', name: 'Spitzer（斯皮策）', query: 'spitzer space telescope'),
      _ProbePreset(category: '望远镜/天文台', name: 'Kepler（开普勒）', query: 'kepler space telescope'),
      _ProbePreset(category: '望远镜/天文台', name: 'TESS（系外行星）', query: 'transiting exoplanet survey satellite tess'),
      _ProbePreset(category: '望远镜/天文台', name: 'WISE（红外巡天）', query: 'wide-field infrared survey explorer wise'),
      _ProbePreset(category: '望远镜/天文台', name: 'Fermi（伽马射线）', query: 'fermi gamma-ray space telescope'),
      _ProbePreset(category: '望远镜/天文台', name: 'Swift（伽马暴）', query: 'swift gamma ray burst mission'),
      _ProbePreset(category: '望远镜/天文台', name: 'GALEX（紫外）', query: 'galex ultraviolet telescope'),
      _ProbePreset(category: '望远镜/天文台', name: 'COBE（宇宙微波背景）', query: 'cobe cosmic background explorer'),
      _ProbePreset(category: '望远镜/天文台', name: 'WMAP（宇宙微波背景）', query: 'wmap wilkinson microwave anisotropy probe'),
      _ProbePreset(category: '望远镜/天文台', name: 'Planck（宇宙微波背景）', query: 'planck satellite cosmic microwave background'),

      // --- Solar / Heliophysics ---
      _ProbePreset(category: '太阳/日地空间', name: 'SOHO（太阳与日光层）', query: 'solar and heliospheric observatory soho'),
      _ProbePreset(category: '太阳/日地空间', name: 'SDO（太阳动力学）', query: 'solar dynamics observatory sdo'),
      _ProbePreset(category: '太阳/日地空间', name: 'STEREO（太阳立体）', query: 'stereo solar terrestrial relations observatory'),
      _ProbePreset(category: '太阳/日地空间', name: 'Parker Solar Probe（帕克）', query: 'parker solar probe'),
      _ProbePreset(category: '太阳/日地空间', name: 'Ulysses（尤利西斯）', query: 'ulysses solar probe'),
      _ProbePreset(category: '太阳/日地空间', name: 'ACE（先进成分探测）', query: 'advanced composition explorer ace spacecraft'),
      _ProbePreset(category: '太阳/日地空间', name: 'IBEX（星际边界探测）', query: 'interstellar boundary explorer ibex'),
      _ProbePreset(category: '太阳/日地空间', name: 'THEMIS（磁层）', query: 'themis mission magnetosphere'),

      // --- Human Spaceflight / Stations ---
      _ProbePreset(category: '载人/空间站', name: 'ISS（国际空间站）', query: 'international space station earth'),
      _ProbePreset(category: '载人/空间站', name: 'Space Shuttle（航天飞机）', query: 'space shuttle mission'),
      _ProbePreset(category: '载人/空间站', name: 'Apollo（月球任务）', query: 'apollo mission moon surface'),
      _ProbePreset(category: '载人/空间站', name: 'Gemini', query: 'gemini spacecraft mission'),
      _ProbePreset(category: '载人/空间站', name: 'Mercury（载人计划）', query: 'project mercury spacecraft'),

      // --- Moon ---
      _ProbePreset(category: '月球', name: 'LRO（月球勘测轨道器）', query: 'lunar reconnaissance orbiter lro'),
      _ProbePreset(category: '月球', name: 'GRAIL', query: 'grail mission moon'),
      _ProbePreset(category: '月球', name: 'LCROSS', query: 'lcross mission moon'),
      _ProbePreset(category: '月球', name: 'LADEE', query: 'lunar atmosphere and dust environment explorer ladee'),
      _ProbePreset(category: '月球', name: 'Clementine', query: 'clementine lunar mission'),

      // --- Mercury / Venus ---
      _ProbePreset(category: '水星/金星', name: 'MESSENGER（水星信使）', query: 'messenger spacecraft mercury'),
      _ProbePreset(category: '水星/金星', name: 'Mariner 10', query: 'mariner 10 mercury'),
      _ProbePreset(category: '水星/金星', name: 'Magellan（金星雷达）', query: 'magellan spacecraft venus'),
      _ProbePreset(category: '水星/金星', name: 'Pioneer Venus', query: 'pioneer venus orbiter'),
      _ProbePreset(category: '水星/金星', name: 'Mariner 2/5（早期金星）', query: 'mariner spacecraft venus'),

      // --- Mars (Rovers/Landers) ---
      _ProbePreset(category: '火星', name: 'Perseverance（毅力号）', query: 'perseverance rover mars surface'),
      _ProbePreset(category: '火星', name: 'Curiosity（好奇号）', query: 'curiosity rover mars surface'),
      _ProbePreset(category: '火星', name: 'Opportunity（机遇号）', query: 'opportunity rover mars surface'),
      _ProbePreset(category: '火星', name: 'Spirit（勇气号）', query: 'spirit rover mars surface'),
      _ProbePreset(category: '火星', name: 'InSight（洞察号）', query: 'insight lander mars'),
      _ProbePreset(category: '火星', name: 'Phoenix（凤凰号）', query: 'phoenix lander mars'),
      _ProbePreset(category: '火星', name: 'Viking（海盗号）', query: 'viking lander mars surface'),
      _ProbePreset(category: '火星', name: 'Pathfinder/Sojourner（探路者）', query: 'mars pathfinder sojourner'),

      // --- Mars (Orbiters) ---
      _ProbePreset(category: '火星轨道器', name: 'MRO（火星勘测轨道器）', query: 'mars reconnaissance orbiter mro'),
      _ProbePreset(category: '火星轨道器', name: 'Mars Odyssey', query: 'mars odyssey orbiter'),
      _ProbePreset(category: '火星轨道器', name: 'MAVEN', query: 'maven spacecraft mars'),
      _ProbePreset(category: '火星轨道器', name: 'Mars Global Surveyor', query: 'mars global surveyor'),

      // --- Jupiter / Saturn / Outer planets ---
      _ProbePreset(category: '木星/土星/外行星', name: 'Juno（朱诺号）', query: 'juno spacecraft jupiter'),
      _ProbePreset(category: '木星/土星/外行星', name: 'Galileo（伽利略号）', query: 'galileo spacecraft jupiter'),
      _ProbePreset(category: '木星/土星/外行星', name: 'Cassini-Huygens（卡西尼）', query: 'cassini huygens saturn spacecraft'),
      _ProbePreset(category: '木星/土星/外行星', name: 'Voyager 1（旅行者 1 号）', query: 'voyager 1 spacecraft'),
      _ProbePreset(category: '木星/土星/外行星', name: 'Voyager 2（旅行者 2 号）', query: 'voyager 2 spacecraft'),
      _ProbePreset(category: '木星/土星/外行星', name: 'Pioneer 10', query: 'pioneer 10 spacecraft'),
      _ProbePreset(category: '木星/土星/外行星', name: 'Pioneer 11', query: 'pioneer 11 spacecraft'),

      // --- Pluto / Kuiper belt ---
      _ProbePreset(category: '冥王星/柯伊伯带', name: 'New Horizons（新视野号）', query: 'new horizons spacecraft pluto kuiper'),

      // --- Asteroids / Comets / Small bodies ---
      _ProbePreset(category: '小天体', name: 'Dawn（灶神星/谷神星）', query: 'dawn spacecraft vesta ceres'),
      _ProbePreset(category: '小天体', name: 'OSIRIS-REx（贝努）', query: 'osiris-rex spacecraft bennu'),
      _ProbePreset(category: '小天体', name: 'NEAR Shoemaker', query: 'near shoemaker eros asteroid'),
      _ProbePreset(category: '小天体', name: 'Stardust', query: 'stardust spacecraft comet wild 2'),
      _ProbePreset(category: '小天体', name: 'Deep Impact', query: 'deep impact mission comet'),
      _ProbePreset(category: '小天体', name: 'Lucy（特洛伊小行星）', query: 'lucy spacecraft trojan asteroids'),
      _ProbePreset(category: '小天体', name: 'Psyche（16 Psyche）', query: 'psyche spacecraft asteroid'),

      // --- Earth observation / DSCOVR/EPIC ---
      _ProbePreset(category: '地球观测', name: 'DSCOVR（EPIC）', query: 'dscovr epic earth full disk'),
      _ProbePreset(category: '地球观测', name: 'Landsat（陆地卫星）', query: 'landsat satellite earth imagery'),
      _ProbePreset(category: '地球观测', name: 'Terra', query: 'terra satellite earth observing'),
      _ProbePreset(category: '地球观测', name: 'Aqua', query: 'aqua satellite earth observing'),
      _ProbePreset(category: '地球观测', name: 'Suomi NPP', query: 'suomi npp satellite'),
      _ProbePreset(category: '地球观测', name: 'Aura', query: 'aura satellite ozone'),
      _ProbePreset(category: '地球观测', name: 'ICESat', query: 'icesat satellite'),
      _ProbePreset(category: '地球观测', name: 'ICESat-2', query: 'icesat-2 satellite'),
      _ProbePreset(category: '地球观测', name: 'Sentinel（示例关键词）', query: 'sentinel satellite earth observation'),

      // --- Historic / General ---
      _ProbePreset(category: '历史任务', name: 'Mariner（系列）', query: 'mariner spacecraft'),
      _ProbePreset(category: '历史任务', name: 'Surveyor（月球软着陆）', query: 'surveyor lunar lander'),
      _ProbePreset(category: '历史任务', name: 'Ranger（月球撞击探测）', query: 'ranger mission moon'),
      _ProbePreset(category: '历史任务', name: 'Pioneer（系列）', query: 'pioneer spacecraft'),
    ];
  }

  Future<void> _bootstrap() async {
    // 获取 NASA 服务器日期，避免设备时间不准导致 APOD/Earth 等全部失败
    try {
      final serverToday = await _service.fetchServerToday();
      if (!mounted) return;
      setState(() {
        _serverToday = serverToday;
        _serverDateReady = true;
        _applyDefaultRanges(serverToday);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _serverToday = DateTime.now();
        _serverDateReady = false;
      });
    }
    await _loadLatestSpaceFeed();
    await _loadApodInitial();
  }


  DateTime _safeParseAnyDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<NasaMediaItem?> _loadLatestProbeOrVideo({required bool video}) async {
    final now = _serverToday;
    final start = DateTime(now.year - 2, 1, 1);
    final queries = video
        ? const <String>[
            'james webb telescope video',
            'hubble video galaxy nebula',
            'mars rover video',
            'cassini saturn video',
            'juno jupiter video',
          ]
        : const <String>[
            'james webb space telescope',
            'hubble space telescope',
            'cassini saturn',
            'juno jupiter',
            'new horizons pluto',
            'perseverance rover',
            'voyager interstellar',
          ];

    NasaMediaItem? newest;
    for (final q in queries) {
      try {
        final list = await _service.searchMedia(
          query: q,
          mediaType: video ? 'video' : 'image',
          page: 1,
          startDate: start,
          endDate: now,
        );
        for (final item in list) {
          if (item.thumbUrl.isEmpty && item.mediaUrl.isEmpty) continue;
          if (newest == null ||
              _safeParseAnyDate(item.date).isAfter(_safeParseAnyDate(newest.date))) {
            newest = item;
          }
        }
      } catch (_) {
        // ignore one failed query and continue with the next source.
      }
    }
    return newest;
  }

  Future<EpicImage?> _loadLatestEpicImage() async {
    for (int i = 0; i < 14; i++) {
      final d = _serverToday.subtract(Duration(days: i));
      try {
        final items = await _service.fetchEpicImagesForDate(date: d, natural: true);
        if (items.isNotEmpty) {
          items.sort((a, b) => b.date.compareTo(a.date));
          return items.first;
        }
      } catch (_) {
        // try previous date
      }
    }
    return null;
  }

  Future<void> _loadLatestSpaceFeed() async {
    if (mounted) {
      setState(() {
        _latestLoading = true;
        _latestError = null;
      });
    }
    try {
      final apod = await _service.fetchTodayApod();
      List<MarsPhoto> marsPhotos = const <MarsPhoto>[];
      try {
        marsPhotos = await _service.fetchMarsLatestPhotos(rover: 'perseverance');
      } catch (_) {
        marsPhotos = const <MarsPhoto>[];
      }
      final latestMars = marsPhotos.isNotEmpty ? marsPhotos.first : null;
      EpicImage? latestEpic;
      try {
        latestEpic = await _loadLatestEpicImage();
      } catch (_) {
        latestEpic = null;
      }
      NasaMediaItem? latestProbeImage;
      try {
        latestProbeImage = await _loadLatestProbeOrVideo(video: false);
      } catch (_) {
        latestProbeImage = null;
      }
      NasaMediaItem? latestProbeVideo;
      try {
        latestProbeVideo = await _loadLatestProbeOrVideo(video: true);
      } catch (_) {
        latestProbeVideo = null;
      }

      final items = <_LatestSpaceFeedItem>[
        _LatestSpaceFeedItem(
          source: 'NASA APOD',
          title: apod.title.isEmpty ? '今日天文图像/视频' : apod.title,
          subtitle: apod.date,
          description: apod.explanation,
          mediaType: apod.mediaType.isEmpty ? 'image' : apod.mediaType,
          imageUrl: apod.mediaType == 'image' ? apod.url : '',
          onTap: () => _openApodDetail(apod),
        ),
      ];

      if (latestProbeImage != null) {
        final probeImage = latestProbeImage;
        items.add(
          _LatestSpaceFeedItem(
            source: 'NASA Images 最新探测器影像',
            title: probeImage.title.isEmpty ? '最新探测器影像' : probeImage.title,
            subtitle: probeImage.date,
            description: probeImage.description,
            mediaType: 'image',
            imageUrl: probeImage.thumbUrl.isNotEmpty ? probeImage.thumbUrl : probeImage.mediaUrl,
            onTap: () => _openMediaDetail(probeImage),
          ),
        );
      }

      if (latestProbeVideo != null) {
        final probeVideo = latestProbeVideo;
        items.add(
          _LatestSpaceFeedItem(
            source: 'NASA Images 最新天体视频',
            title: probeVideo.title.isEmpty ? '最新天体视频' : probeVideo.title,
            subtitle: probeVideo.date,
            description: probeVideo.description,
            mediaType: 'video',
            imageUrl: probeVideo.thumbUrl.isNotEmpty ? probeVideo.thumbUrl : probeVideo.mediaUrl,
            onTap: () => _openMediaDetail(probeVideo),
          ),
        );
      }

      if (latestMars != null) {
        final marsItem = NasaMediaItem(
          id: 'mars_${latestMars.id}',
          title: '${latestMars.rover} · ${latestMars.camera}',
          description: 'NASA 火星车最新公开照片，拍摄日期 ${latestMars.earthDate}',
          date: latestMars.earthDate,
          thumbUrl: latestMars.imageUrl,
          mediaUrl: latestMars.imageUrl,
        );
        items.add(
          _LatestSpaceFeedItem(
            source: 'Mars Rover 最新照片',
            title: marsItem.title,
            subtitle: latestMars.earthDate,
            description: marsItem.description,
            mediaType: 'image',
            imageUrl: latestMars.imageUrl,
            onTap: () => _openMediaDetail(marsItem),
          ),
        );
      }

      if (latestEpic != null) {
        final epic = latestEpic;
        items.add(
          _LatestSpaceFeedItem(
            source: 'DSCOVR EPIC 最新地球影像',
            title: epic.caption.isEmpty ? 'EPIC 最新地球影像' : epic.caption,
            subtitle: epic.date,
            description: epic.caption,
            mediaType: 'image',
            imageUrl: epic.url,
            onTap: () {
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => EpicImageDetailPage(
                    image: epic,
                    translator: _translator,
                    targetLang: _targetLang,
                  ),
                ),
              );
            },
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _latestFeed = items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _latestError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _latestLoading = false;
        });
      }
    }
  }

  void _openLanguageSheet() {
    final langs = <Map<String, String>>[
      {'code': 'zh', 'name': '中文'},
      {'code': 'en', 'name': 'English'},
      {'code': 'ja', 'name': '日本語'},
      {'code': 'ko', 'name': '한국어'},
      {'code': 'es', 'name': 'Español'},
      {'code': 'fr', 'name': 'Français'},
      {'code': 'de', 'name': 'Deutsch'},
      {'code': 'ru', 'name': 'Русский'},
      {'code': 'ar', 'name': 'العربية'},
      {'code': 'pt', 'name': 'Português'},
    ];

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text('选择目标语言'),
                subtitle: Text('仅在进入详情页后，点击右上角“翻译”图标才会把当前页文字翻译为目标语言（读取全局 AI，若无效则不翻译）'),
              ),
              ...langs.map(
                (l) => RadioListTile<String>(
                  value: l['code']!,
                  groupValue: _targetLang,
                  onChanged: (v) {
                    Navigator.of(ctx).pop();
                    if (v != null) _setLanguage(v, l['name']!);
                  },
                  title: Text(l['name']!),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _setLanguage(String code, String name) async {
    setState(() {
      _targetLang = code;
      _targetLangName = name;
      _searchTitleT.clear();
      _probeTitleT.clear();
      _marsTitleT.clear();
      _mediaDescT.clear();
      _apodTitleT.clear();
      _apodExpT.clear();
    });

    // IMPORTANT (per requirement): changing target language does NOT trigger
    // any translation calls. Translation only happens inside detail pages when
    // user presses the translate icon.
  }

  @override
  void dispose() {
    _tabController.dispose();
    _apodScroll.dispose();
    _searchScroll.dispose();
    _probeScroll.dispose();
    _marsScroll.dispose();
    _epicScroll.dispose();
    _earthScroll.dispose();
    _searchController.dispose();
    _probeQueryController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  // -------------------- APOD loaders --------------------
  Future<void> _loadApodInitial() async {
    setState(() {
      _apodLoading = true;
      _apodError = null;
      _apods = [];
      _apodCursorEnd = _apodEndBound;
      _apodHasMore = true;
    });
    try {
      await _loadApodMore(initial: true);
    } finally {
      if (mounted) {
        setState(() {
          _apodLoading = false;
        });
      }
    }
  }

  Future<void> _loadApodMore({bool initial = false}) async {
    if (!_apodHasMore) return;
    if (!initial) {
      setState(() {
        _apodLoadingMore = true;
      });
    } else {
      _apodLoadingMore = true;
    }
    try {
      var end = _apodCursorEnd;
      if (end.isBefore(_apodStartBound)) {
        setState(() => _apodHasMore = false);
        return;
      }
      var start = end.subtract(const Duration(days: 49));
      if (start.isBefore(_apodStartBound)) start = _apodStartBound;

      final batch = await _service.fetchApods(startDate: start, endDate: end);
      batch.sort((a, b) => b.date.compareTo(a.date));

      // 过滤非图片项：用户需求主要是“图片显示”
      final images = batch.where((e) => e.mediaType == 'image' && e.url.isNotEmpty).toList();

      // IMPORTANT: list loading does NOT translate.
      if (mounted) {
        setState(() {
          _apods.addAll(images);
        });
      }

      // 下一页：往更早的日期
      _apodCursorEnd = start.subtract(const Duration(days: 1));
      if (_apodCursorEnd.isBefore(_apodStartBound)) {
        setState(() => _apodHasMore = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _apodError = e.toString();
          _apodHasMore = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _apodLoadingMore = false;
        });
      }
    }
  }

  // -------------------- Search / Probe / Mars loaders (50 items with buffer) --------------------
  Future<void> _resetAndSearch() async {
    setState(() {
      _searchShown = [];
      _searchBuffer.clear();
      _searchPage = 1;
      _searchHasMore = true;
      _searchError = null;
      _searchLoading = true;
    });
    try {
      await _loadSearchMore(initial: true);
    } finally {
      if (mounted) setState(() => _searchLoading = false);
    }
  }

  Future<void> _loadSearchMore({bool initial = false}) async {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;
    if (!_searchHasMore) return;
    if (!initial) setState(() => _searchLoadingMore = true);
    try {
      // 先把 buffer 的内容填到 50
      while (_searchBuffer.length < 50) {
        final res = await _service.searchMedia(
          query: q,
          mediaType: 'image',
          page: _searchPage,
          startDate: _searchStart,
          endDate: _searchEnd,
        );
        _searchPage++;
        if (res.isEmpty) {
          _searchHasMore = false;
          break;
        }
        _searchBuffer.addAll(res.where((e) => e.thumbUrl.isNotEmpty || e.mediaUrl.isNotEmpty));
        // 避免无限循环
        if (_searchPage > 50) break;
      }
      final take = _searchBuffer.take(50).toList();
      _searchBuffer.removeRange(0, take.length);

      // IMPORTANT: list loading does NOT translate.
      if (mounted) setState(() => _searchShown.addAll(take));
      if (take.isEmpty) _searchHasMore = false;
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchError = e.toString();
          _searchHasMore = false;
        });
      }
    } finally {
      if (mounted) setState(() => _searchLoadingMore = false);
    }
  }

  Future<void> _translateTitlesIfNeeded(
    List<NasaMediaItem> items,
    Map<String, String> titleMap,
  ) async {
    if (_targetLang == 'en') return;
    if (items.isEmpty) return;

    // Only translate titles we haven't cached yet.
    final toTranslate = <NasaMediaItem>[];
    final texts = <String>[];
    for (final it in items) {
      final k = '$_targetLang|${it.id}';
      if (titleMap.containsKey(k)) continue;
      final t = it.title.trim();
      if (t.isEmpty) continue;
      toTranslate.add(it);
      texts.add(t);
    }
    if (texts.isEmpty) return;

    try {
      final translated = await _translator.translateTexts(texts, targetLang: _targetLang);
      for (var i = 0; i < toTranslate.length; i++) {
        final k = '$_targetLang|${toTranslate[i].id}';
        titleMap[k] = translated.length > i ? translated[i] : toTranslate[i].title;
      }
    } catch (_) {
      // Ignore translation errors; fall back to English.
    }
  }

  Future<void> _translateApodTitlesIfNeeded(List<Apod> apods) async {
    if (_targetLang == 'en') return;
    if (apods.isEmpty) return;
    final todo = <Apod>[];
    final texts = <String>[];
    for (final a in apods) {
      final k = '$_targetLang|${a.date}';
      if (_apodTitleT.containsKey(k)) continue;
      final t = a.title.trim();
      if (t.isEmpty) continue;
      todo.add(a);
      texts.add(t);
    }
    if (texts.isEmpty) return;
    try {
      final translated = await _translator.translateTexts(texts, targetLang: _targetLang);
      for (var i = 0; i < todo.length; i++) {
        final k = '$_targetLang|${todo[i].date}';
        _apodTitleT[k] = translated.length > i ? translated[i] : todo[i].title;
      }
    } catch (_) {
      // Ignore
    }
  }

  Future<void> _openApodDetail(Apod a) async {
    // IMPORTANT: do not translate here.
    // Translating on tap blocks navigation and causes perceived "no response".
    if (!mounted) return;
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ApodDetailPage(
          apod: a,
          translator: _translator,
          targetLang: _targetLang,
        ),
      ),
    );
  }

  Future<void> _openMediaDetail(NasaMediaItem it) async {
    // IMPORTANT: do not translate here.
    // Translating on tap blocks navigation and causes perceived "no response".
    if (!mounted) return;
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => NasaMediaDetailPage(
          item: it,
          translator: _translator,
          targetLang: _targetLang,
        ),
      ),
    );
  }

  Future<void> _resetAndLoadProbe() async {
    setState(() {
      _probeShown = [];
      _probeBuffer.clear();
      _probePage = 1;
      _probeHasMore = true;
      _probeError = null;
      _probeLoading = true;
    });
    try {
      await _loadProbeMore(initial: true);
    } finally {
      if (mounted) setState(() => _probeLoading = false);
    }
  }

  Future<void> _loadProbeMore({bool initial = false}) async {
    final q = _probeQueryController.text.trim();
    if (q.isEmpty) return;
    if (!_probeHasMore) return;
    if (!initial) setState(() => _probeLoadingMore = true);
    try {
      while (_probeBuffer.length < 50) {
        final res = await _service.searchMedia(
          query: q,
          mediaType: 'image',
          page: _probePage,
          startDate: _probeStart,
          endDate: _probeEnd,
        );
        _probePage++;
        if (res.isEmpty) {
          _probeHasMore = false;
          break;
        }
        _probeBuffer.addAll(res);
        if (_probePage > 50) break;
      }
      final take = _probeBuffer.take(50).toList();
      _probeBuffer.removeRange(0, take.length);

      // IMPORTANT: list loading does NOT translate.
      if (mounted) setState(() => _probeShown.addAll(take));
      if (take.isEmpty) _probeHasMore = false;
    } catch (e) {
      if (mounted) {
        setState(() {
          _probeError = e.toString();
          _probeHasMore = false;
        });
      }
    } finally {
      if (mounted) setState(() => _probeLoadingMore = false);
    }
  }

  Future<void> _resetAndLoadMars() async {
    setState(() {
      _marsShown = [];
      _marsBuffer.clear();
      _marsPage = 1;
      _marsHasMore = true;
      _marsError = null;
      _marsLoading = true;
    });
    try {
      await _loadMarsMore(initial: true);
    } finally {
      if (mounted) setState(() => _marsLoading = false);
    }
  }

  Future<void> _loadMarsMore({bool initial = false}) async {
    if (!_marsHasMore) return;
    if (!initial) setState(() => _marsLoadingMore = true);
    try {
      while (_marsBuffer.length < 50) {
        final res = await _service.searchMedia(
          query: _marsPreset,
          mediaType: 'image',
          page: _marsPage,
          startDate: _marsStart,
          endDate: _marsEnd,
        );
        _marsPage++;
        if (res.isEmpty) {
          _marsHasMore = false;
          break;
        }
        _marsBuffer.addAll(res);
        if (_marsPage > 50) break;
      }
      final take = _marsBuffer.take(50).toList();
      _marsBuffer.removeRange(0, take.length);

      // IMPORTANT: list loading does NOT translate.
      if (mounted) setState(() => _marsShown.addAll(take));
      if (take.isEmpty) _marsHasMore = false;
    } catch (e) {
      if (mounted) {
        setState(() {
          _marsError = e.toString();
          _marsHasMore = false;
        });
      }
    } finally {
      if (mounted) setState(() => _marsLoadingMore = false);
    }
  }

  // -------------------- EPIC loaders --------------------
  Future<void> _resetAndLoadEpic() async {
    setState(() {
      _epicImages = [];
      _epicCursor = _epicEnd;
      _epicHasMore = true;
      _epicError = null;
      _epicLoading = true;
    });
    try {
      await _loadEpicMore(initial: true);
    } finally {
      if (mounted) setState(() => _epicLoading = false);
    }
  }

  Future<void> _loadEpicMore({bool initial = false}) async {
    if (!_epicHasMore) return;
    if (!initial) setState(() => _epicLoadingMore = true);
    try {
      final out = <EpicImage>[];
      var cursor = _epicCursor;
      while (out.length < 50) {
        if (cursor.isBefore(_epicStart)) {
          _epicHasMore = false;
          break;
        }
        try {
          final day = await _service.fetchEpicImagesForDate(date: cursor, natural: true);
          out.addAll(day);
        } catch (_) {
          // 某些日期可能没有数据，继续回溯
        }
        cursor = cursor.subtract(const Duration(days: 1));
      }
      _epicCursor = cursor;
      if (mounted) setState(() => _epicImages.addAll(out));
      if (out.isEmpty) _epicHasMore = false;
    } catch (e) {
      if (mounted) {
        setState(() {
          _epicError = e.toString();
          _epicHasMore = false;
        });
      }
    } finally {
      if (mounted) setState(() => _epicLoadingMore = false);
    }
  }

  // -------------------- Earth imagery loaders --------------------
  Future<void> _resetAndLoadEarthAssets() async {
    final lat = double.tryParse(_latController.text.trim());
    final lon = double.tryParse(_lonController.text.trim());
    if (lat == null || lon == null) {
      setState(() => _earthError = '请输入有效的经纬度');
      return;
    }
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
      setState(() => _earthError = '经纬度范围：lat ∈ [-90, 90]，lon ∈ [-180, 180]');
      return;
    }
    setState(() {
      _earthLoading = true;
      _earthError = null;
      _earthAll = [];
      _earthShown = [];
      _earthShownCount = 0;
      _earthHasMore = true;
    });
    try {
      final list = await _service.fetchEarthAssetsRange(
        lat: lat,
        lon: lon,
        begin: _earthStart,
        end: _earthEnd,
      );
      if (mounted) {
        setState(() {
          _earthAll = list;
        });
      }
      _loadEarthMore(initial: true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _earthError = e.toString();
          _earthHasMore = false;
        });
      }
    } finally {
      if (mounted) setState(() => _earthLoading = false);
    }
  }

  void _loadEarthMore({bool initial = false}) {
    if (!_earthHasMore) return;
    if (!initial) setState(() => _earthLoadingMore = true);
    final next = (_earthShownCount + 50).clamp(0, _earthAll.length);
    final add = _earthAll.sublist(_earthShownCount, next);
    _earthShownCount = next;
    if (mounted) {
      setState(() {
        _earthShown.addAll(add);
        _earthHasMore = _earthShownCount < _earthAll.length;
        _earthLoadingMore = false;
      });
    }
  }

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('看宇宙', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          TextButton.icon(
            onPressed: _openLanguageSheet,
            icon: const Icon(Icons.translate, size: 18, color: Colors.black87),
            label: Text(
              _targetLangName,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          // Requirement: shift the entire tab strip left by 45dp (so the
          // first tab has 45dp less left margin), and reduce the spacing
          // between tabs by 3dp.
          //
          // To avoid creating a visible blank region on the far right, we
          // slightly expand the TabBar's layout width and then clip.
          child: LayoutBuilder(
            builder: (context, constraints) {
              const shift = 45.0;
              return ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: constraints.maxWidth + shift,
                    child: Transform.translate(
                      offset: const Offset(-shift, 0),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        padding: EdgeInsets.zero,
                        // Previously 13; reduce by 3dp per requirement.
                        labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                        indicatorPadding: EdgeInsets.zero,
                        indicatorColor: Colors.blueAccent,
                        labelColor: Colors.blueAccent,
                        unselectedLabelColor: Colors.black54,
                        onTap: (i) {
                          // 首次进入时自动加载
                          if (i == 5 && _epicImages.isEmpty && !_epicLoading) {
                            _resetAndLoadEpic();
                          }
                        },
                        tabs: const [
                          Tab(text: '最新天体'),
                          Tab(text: '每日APOD'),
                          Tab(text: '图像搜索'),
                          Tab(text: '探测器照片'),
                          Tab(text: '火星照片'),
                          Tab(text: 'EPIC地球'),
                          Tab(text: '地球影像'),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLatestTab(),
          _buildApodTab(),
          _buildSearchTab(),
          _buildProbeTab(),
          _buildMarsTab(),
          _buildEpicTab(),
          _buildEarthTab(),
        ],
      ),
    );
  }

  Widget _buildDateRangeBar({
    required DateTime start,
    required DateTime end,
    required VoidCallback onPickStart,
    required VoidCallback onPickEnd,
    required VoidCallback onApply,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          const Text('开始:'),
          const SizedBox(width: 6),
          InkWell(
            onTap: onPickStart,
            child: Row(
              children: [
                Text(_fmt(start), style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                const Icon(Icons.calendar_month, size: 18),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Text('结束:'),
          const SizedBox(width: 6),
          InkWell(
            onTap: onPickEnd,
            child: Row(
              children: [
                Text(_fmt(end), style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                const Icon(Icons.calendar_month, size: 18),
              ],
            ),
          ),
          const Spacer(),
          TextButton(onPressed: onApply, child: const Text('应用')),
        ],
      ),
    );
  }

  Widget _buildError(String title, String msg, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$title\n$msg', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaList(
    ScrollController controller,
    List<NasaMediaItem> items, {
    bool showLoadingMore = false,
    Map<String, String>? titleTranslations,
  }) {
    return ListView.separated(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: items.length + (showLoadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, idx) {
        if (idx >= items.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final it = items[idx];
        // IMPORTANT: list does NOT translate.
        final displayTitle = it.title;
        final thumb = it.thumbUrl.isNotEmpty ? it.thumbUrl : it.mediaUrl;
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: thumb.isEmpty
                ? const SizedBox(width: 64, height: 64, child: Icon(Icons.image_not_supported))
                : Image.network(
                    thumb,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      width: 64,
                      height: 64,
                      child: Center(child: Icon(Icons.broken_image)),
                    ),
                  ),
          ),
          title: Text(displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(it.date.isEmpty ? '' : it.date.split('T').first),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await _openMediaDetail(it);
          },
        );
      },
    );
  }

  // -------------------- Tabs --------------------

  Widget _buildLatestTab() {
    if (_latestLoading && _latestFeed.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_latestError != null && _latestFeed.isEmpty) {
      return _buildError('加载 NASA 最新天体媒体失败', _latestError!, _loadLatestSpaceFeed);
    }
    return RefreshIndicator(
      onRefresh: _loadLatestSpaceFeed,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blueGrey.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              '这里聚合显示 NASA 当前可获取的最新天体图片或视频，包括每日天文图、探测器/望远镜素材、火星车照片和 EPIC 影像。',
              style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          ..._latestFeed.map((item) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: item.onTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          item.imageUrl.isNotEmpty
                              ? Image.network(
                                  item.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.black12,
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.broken_image, size: 34),
                                  ),
                                )
                              : Container(
                                  color: Colors.black12,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.image_not_supported, size: 34),
                                ),
                          Positioned(
                            left: 12,
                            top: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                item.source,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ),
                          if (item.mediaType.toLowerCase() == 'video')
                            const Center(
                              child: CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.black45,
                                child: Icon(Icons.play_arrow, color: Colors.white, size: 34),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.subtitle,
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                          if (item.description.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              item.description,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, height: 1.45),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (!_latestLoading && _latestFeed.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('暂时没有可显示的 NASA 最新天体媒体')),
            ),
        ],
      ),
    );
  }

  Widget _buildApodTab() {
    if (_apodLoading && _apods.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_apodError != null && _apods.isEmpty) {
      return _buildError('加载天文图失败', _apodError!, _loadApodInitial);
    }
    return Column(
      children: [
        _buildDateRangeBar(
          start: _apodStartBound,
          end: _apodEndBound,
          onPickStart: () async {
            final picked = await _pickDate(_apodStartBound, DateTime(1995, 6, 16), _apodEndBound);
            if (picked == null) return;
            setState(() => _apodStartBound = picked);
          },
          onPickEnd: () async {
            final picked = await _pickDate(_apodEndBound, _apodStartBound, _serverToday);
            if (picked == null) return;
            setState(() => _apodEndBound = picked);
          },
          onApply: _loadApodInitial,
        ),
        const Divider(height: 1),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadApodInitial,
            child: ListView.separated(
              controller: _apodScroll,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _apods.length + (_apodLoadingMore ? 1 : 0),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                if (idx >= _apods.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final a = _apods[idx];
                // IMPORTANT: list does NOT translate.
                final displayTitle = a.title;
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      a.url,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        width: 64,
                        height: 64,
                        child: Center(child: Icon(Icons.broken_image)),
                      ),
                    ),
                  ),
                  title: Text(displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(a.date),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _openApodDetail(a);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '输入关键词（如 moon, nebula, galaxy）',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchShown = [];
                          _searchBuffer.clear();
                          _searchError = null;
                          _searchHasMore = true;
                          _searchPage = 1;
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onSubmitted: (_) => _resetAndSearch(),
          ),
        ),
        _buildDateRangeBar(
          start: _searchStart,
          end: _searchEnd,
          onPickStart: () async {
            final picked = await _pickDate(_searchStart, DateTime(1900, 1, 1), _searchEnd);
            if (picked == null) return;
            setState(() => _searchStart = picked);
          },
          onPickEnd: () async {
            final picked = await _pickDate(_searchEnd, _searchStart, _serverToday);
            if (picked == null) return;
            setState(() => _searchEnd = picked);
          },
          onApply: _resetAndSearch,
        ),
        const Divider(height: 1),
        Expanded(
          child: _searchLoading && _searchShown.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : (_searchError != null && _searchShown.isEmpty)
                  ? _buildError('搜索失败', _searchError!, _resetAndSearch)
                  : RefreshIndicator(
                      onRefresh: _resetAndSearch,
                      child: _buildMediaList(
                        _searchScroll,
                        _searchShown,
                        showLoadingMore: _searchLoadingMore,
                        titleTranslations: _searchTitleT,
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildProbeTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(
            children: [
              const Text('探测器/任务:'),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _probePresetName,
                      items: _probePresets
                          .map((p) => DropdownMenuItem(value: p.name, child: Text(p.name)))
                          .toList(growable: false),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _probePresetName = v);
                        final preset = _probePresets.firstWhere(
                          (e) => e.name == v,
                          orElse: () => _probePresets.first,
                        );
                        _probeQueryController.text = preset.query;
                        _resetAndLoadProbe();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: TextField(
            controller: _probeQueryController,
            decoration: InputDecoration(
              hintText: '也可以手动输入关键词（英文），例如 voyager, cassini, hubble…',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onSubmitted: (_) {
              // Ensure Dropdown value always exists in items.
              setState(() => _probePresetName = _probePresets.first.name);
              _resetAndLoadProbe();
            },
          ),
        ),
        _buildDateRangeBar(
          start: _probeStart,
          end: _probeEnd,
          onPickStart: () async {
            final picked = await _pickDate(_probeStart, DateTime(1900, 1, 1), _probeEnd);
            if (picked == null) return;
            setState(() => _probeStart = picked);
          },
          onPickEnd: () async {
            final picked = await _pickDate(_probeEnd, _probeStart, _serverToday);
            if (picked == null) return;
            setState(() => _probeEnd = picked);
          },
          onApply: _resetAndLoadProbe,
        ),
        const Divider(height: 1),
        Expanded(
          child: _probeLoading && _probeShown.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : (_probeError != null && _probeShown.isEmpty)
                  ? _buildError('加载失败', _probeError!, _resetAndLoadProbe)
                  : RefreshIndicator(
                      onRefresh: _resetAndLoadProbe,
                      child: _buildMediaList(
                        _probeScroll,
                        _probeShown,
                        showLoadingMore: _probeLoadingMore,
                        titleTranslations: _probeTitleT,
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _chip(String label, String q) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        _probeQueryController.text = q;
        _resetAndLoadProbe();
      },
    );
  }

  Widget _buildMarsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(
            children: [
              const Text('类别:'),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _marsPreset,
                items: const [
                  DropdownMenuItem(value: 'Mars rover', child: Text('火星车实拍')),
                  DropdownMenuItem(value: 'Mars surface', child: Text('火星地表')),
                  DropdownMenuItem(value: 'Curiosity rover', child: Text('Curiosity')),
                  DropdownMenuItem(value: 'Perseverance rover', child: Text('Perseverance')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _marsPreset = v);
                  _resetAndLoadMars();
                },
              ),
              const Spacer(),
              TextButton(onPressed: _resetAndLoadMars, child: const Text('加载')),
            ],
          ),
        ),
        _buildDateRangeBar(
          start: _marsStart,
          end: _marsEnd,
          onPickStart: () async {
            final picked = await _pickDate(_marsStart, DateTime(1900, 1, 1), _marsEnd);
            if (picked == null) return;
            setState(() => _marsStart = picked);
          },
          onPickEnd: () async {
            final picked = await _pickDate(_marsEnd, _marsStart, _serverToday);
            if (picked == null) return;
            setState(() => _marsEnd = picked);
          },
          onApply: _resetAndLoadMars,
        ),
        const Divider(height: 1),
        Expanded(
          child: _marsLoading && _marsShown.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : (_marsError != null && _marsShown.isEmpty)
                  ? _buildError('加载失败', _marsError!, _resetAndLoadMars)
                  : RefreshIndicator(
                      onRefresh: _resetAndLoadMars,
                      child: _buildMediaList(
                        _marsScroll,
                        _marsShown,
                        showLoadingMore: _marsLoadingMore,
                        titleTranslations: _marsTitleT,
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildEpicTab() {
    if (_epicLoading && _epicImages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_epicError != null && _epicImages.isEmpty) {
      return _buildError('加载 EPIC 失败', _epicError!, _resetAndLoadEpic);
    }
    return Column(
      children: [
        _buildDateRangeBar(
          start: _epicStart,
          end: _epicEnd,
          onPickStart: () async {
            final picked = await _pickDate(_epicStart, DateTime(2015, 1, 1), _epicEnd);
            if (picked == null) return;
            setState(() => _epicStart = picked);
          },
          onPickEnd: () async {
            final picked = await _pickDate(_epicEnd, _epicStart, _serverToday);
            if (picked == null) return;
            setState(() => _epicEnd = picked);
          },
          onApply: _resetAndLoadEpic,
        ),
        const Divider(height: 1),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _resetAndLoadEpic,
            child: ListView.separated(
              controller: _epicScroll,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _epicImages.length + (_epicLoadingMore ? 1 : 0),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                if (idx >= _epicImages.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final e = _epicImages[idx];
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      e.url,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        width: 64,
                        height: 64,
                        child: Center(child: Icon(Icons.broken_image)),
                      ),
                    ),
                  ),
                  title: Text(e.caption.isEmpty ? 'EPIC 图像' : e.caption,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(e.date.split(' ').first),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => EpicImageDetailPage(
                          image: e,
                          translator: _translator,
                          targetLang: _targetLang,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEarthTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('获取地球卫星影像（按经纬度 + 日期范围）',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: _latController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '纬度 (lat)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _lonController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '经度 (lon)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
        _buildDateRangeBar(
          start: _earthStart,
          end: _earthEnd,
          onPickStart: () async {
            final picked = await _pickDate(_earthStart, DateTime(2000, 1, 1), _earthEnd);
            if (picked == null) return;
            setState(() => _earthStart = picked);
          },
          onPickEnd: () async {
            final picked = await _pickDate(_earthEnd, _earthStart, _serverToday);
            if (picked == null) return;
            setState(() => _earthEnd = picked);
          },
          onApply: _resetAndLoadEarthAssets,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            children: [
              ElevatedButton(
                onPressed: _earthLoading ? null : _resetAndLoadEarthAssets,
                child: const Text('获取列表'),
              ),
              const SizedBox(width: 12),
              if (_earthLoading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              const Spacer(),
              Text('共 ${_earthAll.length} 条'),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: (_earthError != null && _earthShown.isEmpty)
              ? _buildError('获取失败', _earthError!, _resetAndLoadEarthAssets)
              : RefreshIndicator(
                  onRefresh: _resetAndLoadEarthAssets,
                  child: ListView.separated(
                    controller: _earthScroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _earthShown.length + (_earthLoadingMore ? 1 : 0),
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      if (idx >= _earthShown.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final it = _earthShown[idx];
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            it.url,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(
                              width: 64,
                              height: 64,
                              child: Center(child: Icon(Icons.broken_image)),
                            ),
                          ),
                        ),
                        title: Text('日期：${it.date}'),
                        subtitle: Text('id: ${it.id}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (_) => _SimpleImagePage(title: '地球影像 ${it.date}', url: it.url),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _SimpleImagePage extends StatelessWidget {
  final String title;
  final String url;

  const _SimpleImagePage({required this.title, required this.url});

  @override
  Widget build(BuildContext context) {
    Future<void> promptDownload() async {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('下载并保存到系统相册'),
                  subtitle: const Text('下载完成后，可在相册/图库中查看'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('开始下载…')));
                    try {
                      final saved = await ImageDownloader.saveImageToGallery(url);
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('已保存到相册: $saved')));
                    } catch (e) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('下载/保存失败: $e')));
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: InteractiveViewer(
          child: GestureDetector(
            onLongPress: promptDownload,
            child: Image.network(
              url,
              errorBuilder: (_, __, ___) => const Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('图片加载失败，请检查网络后重试。'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
