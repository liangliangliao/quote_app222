
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show mapEquals;
import 'package:quote_app/widgets/poster_pure_flutter.dart';
import 'package:quote_app/widgets/quote_adaptive_frame.dart';
import 'package:quote_app/services/quote_frame_theme.dart';
import 'package:quote_app/services/quote_frame_ai_service.dart';
import 'package:quote_app/services/quote_calligraphy_settings.dart';
import 'package:quote_app/services/notification_service.dart';
import 'package:quote_app/services/quote_ai_service.dart';
import '../data/dao.dart';
import '../widgets/quote_home_scene.dart';
import '../widgets/quote_library_sheet.dart';
import '../widgets/journey_design.dart';
import '../services/quote_library_store.dart';
import '../utils/debug_logger.dart';
import 'package:quote_app/services/native_guard.dart';



String _buildAuthorLine(String authorName, String source) {
  authorName = (authorName).trim();
  source = (source).trim();
  if (authorName.isEmpty && source.isEmpty) return '';
  final s = StringBuffer('——');
  if (authorName.isNotEmpty) {
    s.write(authorName);
    if (source.isNotEmpty) s.write('《' + source + '》');
  } else if (source.isNotEmpty) {
    s.write('《' + source + '》');
  }
  return s.toString();
}


  bool isShortTopic(String s) {
    try { return s.runes.length < 15; } catch (_) { return s.length < 15; }
  }
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  // Truncate huge strings for logging to avoid performance issues on phone.
  String _truncateForLog(String? s, {int maxLen = 140}) {
    if (s == null) return '';
    final str = s;
    if (str.startsWith('data:image/')) {
      final comma = str.indexOf(',');
      final header = comma < 0 ? 'data:image' : str.substring(0, comma);
      return '$header,<omitted ${str.length} chars>';
    }
    if (str.length <= maxLen) return str;
    return str.substring(0, maxLen) + '...(truncated)';
  }

  Future<void> _logInject(String source, Map<String, dynamic> data) async {
    try {
      final _lp = Map<String, dynamic>.from(data);
      _lp['avatarUrl'] = _truncateForLog((_lp['avatarUrl'] ?? _lp['avatar'])?.toString());
      if (_lp.containsKey('bgUrl')) _lp['bgUrl'] = _truncateForLog((_lp['bgUrl'] ?? '').toString());
      if (_lp.containsKey('bgDataUrl')) _lp['bgDataUrl'] = _truncateForLog((_lp['bgDataUrl'] ?? '').toString());
      await LogDao().add(taskUid: 'home_inject', detail: json.encode({'source': source, 'payload': _lp}));
    } catch (_) {}
  }

  bool _sessionPrompted = false;

  Map<String, dynamic>? _todayData;

  final QuoteFrameAiService _frameAi = QuoteFrameAiService();
  final QuoteCalligraphySettings _calligraphySettings =
      QuoteCalligraphySettings();
  final Set<String> _frameAttempted = <String>{};
  String _visibleFrameKey = '';
  String? _frameImagePath;
  bool _frameAuto = false;
  bool _frameGenerating = false;
  int _frameRevision = 0;
  bool _quoteCalligraphyEnabled = false;
  QuoteCalligraphyStyle _quoteCalligraphyStyle =
      QuoteCalligraphyStyle.xingshu;
  QuoteEnglishFontStyle _quoteEnglishFontStyle =
      QuoteEnglishFontStyle.baskerville;

  Future<void> _loadCalligraphyPreference() async {
    try {
      final preference = await _calligraphySettings.load();
      if (!mounted) return;
      setState(() {
        _quoteCalligraphyEnabled = preference.animationEnabled;
        _quoteCalligraphyStyle = preference.style;
        _quoteEnglishFontStyle = preference.englishFontStyle;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _quoteCalligraphyEnabled = false;
        _quoteCalligraphyStyle = QuoteCalligraphyStyle.xingshu;
        _quoteEnglishFontStyle = QuoteEnglishFontStyle.baskerville;
      });
    }
  }

  void _onCalligraphyPreferenceChanged() {
    unawaited(_loadCalligraphyPreference());
  }

  Future<void> _initFramePreference() async {
    try {
      final auto = await _frameAi.autoEnabled;
      if (!mounted) return;
      setState(() => _frameAuto = auto);
      if (_todayData != null) unawaited(_activateFrame(_todayData!));
    } catch (e) {
      await DLog.e('FRAME', '配画设置加载失败: $e');
    }
  }

  Future<void> _activateFrame(Map<String, dynamic> payload) async {
    unawaited(_loadFavoriteFor(payload));
    final topic = (payload['topic'] ?? '').toString();
    final quote = (payload['quote'] ?? '').toString();
    final key = _frameAi.cacheKey(topic, quote);
    final int revision = ++_frameRevision;
    if (_visibleFrameKey != key && mounted) {
      setState(() {
        _visibleFrameKey = key;
        final readingKey = QuoteLibraryStore.identity(payload);
        _readingIndex = _readingHistory.indexWhere((row) => QuoteLibraryStore.identity(row) == readingKey);
        if (_readingIndex < 0) {
          _readingHistory.add(Map<String, dynamic>.from(payload));
          if (_readingHistory.length > 6) _readingHistory.removeAt(0);
          _readingIndex = _readingHistory.length - 1;
        }
        _frameImagePath = null; // 不展示上一条名言的画面
      });
    }
    if (quote.trim().isEmpty) return;
    try {
      final cached = await _frameAi.findCached(topic, quote);
      if (!mounted || revision != _frameRevision) return;
      if (cached != null) {
        // AI 只替换用户木质画框中的画芯，不改变画框与房间背景。
        setState(() => _frameImagePath = cached);
      } else if (_frameAuto && !_frameAttempted.contains(key)) {
        unawaited(_generateFrameFor(payload, userInitiated: false));
      }
    } catch (e) {
      await DLog.e('FRAME', '读取图片缓存失败: $e');
    }
  }

  Future<void> _generateFrameFor(Map<String, dynamic> payload, {required bool userInitiated}) async {
    if (_frameGenerating) {
      if (userInitiated && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已有一幅画正在生成')));
      }
      return;
    }
    final topic = (payload['topic'] ?? '').toString();
    final quote = (payload['quote'] ?? '').toString();
    if (quote.trim().isEmpty) return;
    final key = _frameAi.cacheKey(topic, quote);
    _frameAttempted.add(key);
    setState(() => _frameGenerating = true);
    try {
      final style = QuoteFrameTheme.resolve(topic: topic, quote: quote, note: (payload['note'] ?? '').toString());
      final path = await _frameAi.generate(
        topic: topic, quote: quote, note: (payload['note'] ?? '').toString(),
        theme: style, force: userInitiated,
      );
      if (!mounted) return;
      if (_visibleFrameKey == key) {
        setState(() => _frameImagePath = path);
      }
      if (userInitiated) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('名言配画已生成并放入木质画框')));
    } catch (e) {
      await DLog.e('FRAME', 'AI 生成配画失败: $e');
      if (userInitiated && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI 配画失败，已保留默认木质画框：$e')));
      }
    } finally {
      if (mounted) {
        setState(() => _frameGenerating = false);
        // 生成期间若切换名言，则接着处理最新一条，不让它卡在无图状态。
        final current = _todayData;
        if (_frameAuto && current != null &&
            _frameAi.cacheKey((current['topic'] ?? '').toString(), (current['quote'] ?? '').toString()) != key) {
          unawaited(_activateFrame(current));
        }
      }
    }
  }

  Future<void> _showFrameInterpretation() async {
    final payload = _todayData;
    if (payload == null) return;
    final topic = (payload['topic'] ?? '').toString();
    final quote = (payload['quote'] ?? '').toString();
    final script = await _frameAi.readCachedScript(topic, quote);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('名言如何变成画面'),
        content: SingleChildScrollView(
          child: Text(script == null
            ? '当前尚未生成 AI 视觉脚本。请先选择「AI 生成/重绘框内配画」。默认始终使用你提供的木质画框。'
            : '原句含义：${script.meaning}\n\n核心视觉类比：${script.metaphor}\n\n可见场景：${script.scene}\n\n为什么这样画：${script.relationship}\n\n氛围：${script.mood}\n\n固定画框：你提供的木质画框；AI 只替换框内画面。\n\n分析来源：${script.fromAi ? 'AI 语义解析' : '本地有限规则兜底（不代表 AI 已理解）'}'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('关闭')),
        ],
      ),
    );
  }

  Future<void> _requestManualFrame() async {
    final payload = _todayData;
    if (payload == null || _frameGenerating) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('为当前名言生成框内配画？'),
        content: const Text('系统将先调用文字 AI 提炼名言的核心命题、对比或因果关系，再让图片模型把它变成直观画面，并只替换木框内的白色画芯。两次调用都可能产生 API 费用；重新生成会再次计费。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('生成')),
        ],
      ),
    );
    if (confirmed == true && mounted) unawaited(_generateFrameFor(payload, userInitiated: true));
  }

  Future<void> _setFrameAuto() async {
    if (!_frameAuto) {
      final agreed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('开启 AI 自动配画？'),
          content: const Text('新名言会先调用文字 AI 形成可解释的视觉脚本，再调用图片 AI 生成框内画面。两次模型调用可能分别收费；每句有缓存，重复打开不会重复生成。关闭后显示你提供的默认木质画框和白色画芯。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('开启')),
          ],
        ),
      );
      if (agreed != true || !mounted) return;
    }
    final enabled = !_frameAuto;
    try {
      await _frameAi.setAutoEnabled(enabled);
      if (!mounted) return;
      setState(() => _frameAuto = enabled);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(enabled ? 'AI 自动配画已开启' : 'AI 自动配画已关闭，默认木质画框继续生效')));
      if (enabled && _todayData != null) unawaited(_activateFrame(_todayData!));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存配画设置失败：$e')));
    }
  }



// ---------------------------------------------------------------------------
// Avatar assets fuzzy match (assets/avatars/)
// ---------------------------------------------------------------------------
List<String>? _avatarAssetsCache;

Future<List<String>> _listAvatarAssets() async {
  if (_avatarAssetsCache != null) return _avatarAssetsCache!;
  try {
    final manifestStr = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifest = json.decode(manifestStr);

    final keys = manifest.keys
        .where((k) => k.startsWith('assets/avatars/'))
        // Only keep real image assets, exclude placeholder files.
        .where((k) {
          final lower = k.toLowerCase();
          final isImage = lower.endsWith('.png') ||
              lower.endsWith('.jpg') ||
              lower.endsWith('.jpeg') ||
              lower.endsWith('.webp');
          final isTrash =
              lower.endsWith('.gitkeep') || lower.endsWith('readme.txt');
          return isImage && !isTrash;
        })
        .toList();

    _avatarAssetsCache = keys;
    return keys;
  } catch (_) {
    _avatarAssetsCache = <String>[];
    return _avatarAssetsCache!;
  }
}

String _normName(String s) {
  return s
      .toLowerCase()
      .replaceAll(RegExp(r'[—\-–_\s]+'), '')
      .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fa5]+'), '');
}

/// Extract a fuzzy author name from author field like:
/// "— Albert Camus, The Myth of Sisyphus" -> "Albert Camus"
String _extractAuthorName(String author) {
  var a = author.trim();
  a = a.replaceFirst(RegExp(r'^[—\-–\s]+'), '');
  for (final sep in [',', '，', '(', '（']) {
    final idx = a.indexOf(sep);
    if (idx > 0) a = a.substring(0, idx);
  }
  return a.trim();
}

/// Match avatar asset by checking if filename contains author signature (fuzzy).
Future<String?> _matchAvatarAssetByAuthor(String author) async {
  final knownAsset = QuoteAvatarAssetResolver.forAuthor(author);
  if (knownAsset.isNotEmpty) return knownAsset;

  final assets = await _listAvatarAssets();
  if (assets.isEmpty) return null;

  final authorName = _extractAuthorName(author);
  if (authorName.isEmpty) return null;

  final normAuthor = _normName(authorName);

  String? best;
  int bestScore = -1;
  for (final p in assets) {
    final file = p.split('/').last;
    final stem = file.replaceAll(RegExp(r'\.[^.]+$'), '');
    final normStem = _normName(stem);
    if (normStem.contains(normAuthor) || normAuthor.contains(normStem)) {
      final score = normStem.length;
      if (score > bestScore) {
        bestScore = score;
        best = p;
      }
    }
  }
  return best;
}

  Map<String, dynamic>? _latestRow;
  bool _firstLoaded = false;
  bool _homeLoading = false;
  bool _homeReloadQueued = false;
  bool _fav = false;
  final _library = QuoteLibraryStore();
  bool _favoriteBusy = false, _nextBusy = false, _pinnedGalleryOpen = false;
  int _favoriteGeneration = 0, _readingIndex = 0;
  final _readingHistory = <Map<String, dynamic>>[];
  final _pinnedCollectionTick = ValueNotifier<int>(0);

  bool _liked = false;
  bool _notifAsked = false;
  final Set<String> _avatarRepairAttempted = <String>{};

  // Pinned (fixed) quotes state.  These lists store the loaded fixed quotes for
  // the bottom grey area.  `_pinnedQuotes` holds the current batch of
  // records, `_pinnedHasMore` indicates whether more can be loaded from the
  // database, and `_loadingPinned` prevents concurrent loads.  A dedicated
  // scroll controller listens for horizontal scrolls to trigger loading
  // additional pages.  `_pinnedActive` tracks whether the currently
  // displayed large quote is pinned.
  List<Map<String, dynamic>> _pinnedQuotes = [];
  int _pinnedTotal = 0;
  int _pinnedJumpRevision = 0;
  bool _pinnedHasMore = false;
  bool _loadingPinned = false;
  final ScrollController _pinnedController = ScrollController();
  bool _pinnedActive = false;
  bool _showPinnedJumpToStart = false;
  bool _showPinnedJumpToEnd = false;
  bool _pinnedEndToastShown = false;

  // UI animation helpers for pinned small frames
  int? _animInsertPinnedId; // id of newly inserted pinned card (leftmost)
  int? _animRemovePinnedId; // id of pinned card being removed
  static const double _pinnedCardWidth = 200;
  static const double _pinnedCardGap = 0;

  void _openLeftDrawer() {
    try {
      final scaffold = Scaffold.maybeOf(context);
      scaffold?.openDrawer();
    } catch (_) {}
  }

  void _handleTopBarMenu(String value) async {
    switch (value) {
      case 'pinned_quotes':
        await _showPinnedGallery();
        break;
      case 'favorite_quotes':
        await _openLibrary(favoritesOnly: true);
        break;
      case 'frame_generate':
        unawaited(_requestManualFrame());
        break;
      case 'frame_toggle':
        unawaited(_setFrameAuto());
        break;
      case 'frame_explain':
        unawaited(_showFrameInterpretation());
        break;
      case 'share':
        // 沿用原来的分享行为：复制当前名言到剪贴板并提示
        await _copyLatest();
        break;
      case 'favorite':
        await _toggleFavorite();
        break;
      case 'like':
        setState(() {
          _liked = !_liked;
        });
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_liked ? '已标记为喜欢' : '已取消喜欢'),
              duration: const Duration(milliseconds: 800),
            ),
          );
        } catch (_) {}
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SimpleBus.homeTick.addListener(_onBus);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      NotificationService.markHomeVisible();
      _checkNotificationPermission();
    });
    unawaited(_initFramePreference());
    QuoteCalligraphySettings.changeTick
        .addListener(_onCalligraphyPreferenceChanged);
    unawaited(_loadCalligraphyPreference());
    _load();
    _pinnedController.addListener(_handlePinnedScroll);
    // Load pinned quotes immediately on first build
    _loadPinned(reset: true);

    // 每次从冷启动进入首页时，尝试弹出心情卡片
  }

  void _onBus() { _load(); }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SimpleBus.homeTick.removeListener(_onBus);
    QuoteCalligraphySettings.changeTick
        .removeListener(_onCalligraphyPreferenceChanged);
    _pinnedController.removeListener(_handlePinnedScroll);
    // Dispose the pinned scroll controller to free resources
    _pinnedController.dispose();
    _pinnedCollectionTick.dispose();
    super.dispose();
  }

  // removed redundant lifecycle reload to avoid non-first re-render

  Future<String> _resolveAvatarSource(String raw) async {
    final s = raw.trim();
    if (s.isEmpty) return '';
    if (s.startsWith('data:') ||
        s.startsWith('http://') ||
        s.startsWith('https://') ||
        s.startsWith('assets/')) {
      return s;
    }
    try {
      final f = File(s);
      if (await f.exists() && await f.length() > 0) return s;
    } catch (_) {}
    return '';
  }

  bool _isIdentityVerifiedAvatar(
    Map<String, dynamic> quote,
    String author,
    String avatar,
  ) {
    final value = avatar.trim();
    if (value.isEmpty) return false;
    if (QuoteAvatarDownloader.isIdentityVerifiedLocalPath(value)) return true;
    // Covers AI quote rows created before task_type was consistently stored.
    if (p.basename(value).startsWith('quote_avatar_')) return false;
    if ((quote['task_type'] ?? '').toString() != 'auto') return true;
    final bundled = QuoteAvatarAssetResolver.forAuthor(author);
    if (bundled.isNotEmpty && value == bundled) return true;
    return false;
  }

  Future<void> _repairQuoteAvatar(
    Map<String, dynamic> quote,
    String author,
  ) async {
    final quoteUid = (quote['quote_uid'] ?? '').toString().trim();
    final taskUid = (quote['task_uid'] ?? '').toString().trim();
    final key = quoteUid.isNotEmpty
        ? quoteUid
        : '${quote['id'] ?? ''}|$author';
    if (author.trim().isEmpty ||
        taskUid.isEmpty ||
        !_avatarRepairAttempted.add(key)) {
      return;
    }

    try {
      final task = await TaskDao().getByUid(taskUid);
      if (task == null || (task['type'] ?? '').toString() != 'auto') return;
      if (!QuoteAiTaskConfig.fromTask(task).downloadAvatar) return;

      final avatar = await QuoteAvatarDownloader().resolveAndDownload(
        author: author,
        searchQuery: author,
        preferredUrl: '',
      );
      if (avatar == null) {
        await DLog.w('QUOTE_AI', '首页校验或补全人物头像失败：$author');
        return;
      }
      if (quoteUid.isNotEmpty) {
        await QuoteDao().updateAvatarByUid(quoteUid, avatar.path);
      }
      if (!mounted ||
          (_latestRow?['quote_uid'] ?? '').toString() != quoteUid) {
        return;
      }
      final source = await _resolveAvatarSource(avatar.path);
      if (!mounted || source.isEmpty) return;
      setState(() {
        _latestRow = <String, dynamic>{...?_latestRow, 'avatar': avatar.path};
        _todayData = <String, dynamic>{...?_todayData, 'avatarUrl': source};
      });
      await DLog.i('QUOTE_AI', '首页已校验、补全并保存人物头像：$author');
    } catch (error) {
      await DLog.w('QUOTE_AI', '首页校验或补全人物头像异常：$author；$error');
    }
  }


  void _requestNotifAfterFirstFrame() {
    if (_notifAsked) return;
    _notifAsked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
            NotificationService.markHomeVisible();
try {
        bool enabled = true;
        try {
          enabled = await NotificationService.areNotificationsEnabled();
        } catch (_) { enabled = false; }
        if (enabled != true) {
          try { await NotificationService.request(); } catch (_) {}
        }
      } catch (_) {}
    });
  }

  /// Load a fallback quote from camus_fallback.json using a shuffle-bag.
/// When multiple fallback quotes exist, selection is randomized per cycle,
/// adjacent injections won't repeat (when count > 1), and appearances stay balanced.
  /// When multiple fallback quotes exist, they are injected sequentially and looped.
  /// Adjacent injections won't repeat (when count > 1), and appearances stay balanced.
  
Future<Map<String, dynamic>> _loadNextFallbackQuote() async {
  final fbStr = await rootBundle.loadString('assets/fallback/camus_fallback.json');
  dynamic decoded;
  try {
    decoded = json.decode(fbStr);
  } catch (e) {
    // Fallback asset JSON may be malformed on some devices/builds; avoid breaking the home page.
    decoded = [
      {
        'topic': '兜底',
        'quote': '先深呼吸，再慢慢来。',
        'author': '',
        'note': '',
        'avatarUrl': '',
        'bgUrl': '',
      }
    ];
  }
  final List<dynamic> all = decoded is List
      ? decoded
      : (decoded is Map<String, dynamic> ? [decoded] : <dynamic>[]);
  if (all.isEmpty) return <String, dynamic>{};

  int idx = 0;
  try {
    idx = await QuoteDao().nextCamusFallbackIndex(all.length)
        .timeout(const Duration(milliseconds: 300),
          onTimeout: () => (DateTime.now().millisecondsSinceEpoch ~/ 60000) % all.length);
  } catch (_) {
    idx = 0;
  }

  final item = all[idx];
  if (item is Map) {
    final map = Map<String, dynamic>.from(item);

    // Fuzzy match local avatar assets by author signature.
    final author = (map['author'] ?? '').toString();
    final matched = await _matchAvatarAssetByAuthor(author);
    if (matched != null && matched.isNotEmpty) {
      map['avatarUrl'] = matched; // PosterPureFlutter will load AssetImage
    }

    return map;
  }
  return <String, dynamic>{};
}

  Future<void> _load() async {
    if (_homeLoading) {
      _homeReloadQueued = true;
      return;
    }
    _homeLoading = true;
    try {
      await _loadSnapshot();
    } finally {
      _homeLoading = false;
      if (_homeReloadQueued && mounted) {
        _homeReloadQueued = false;
        unawaited(_load());
      }
    }
  }

  Future<void> _loadSnapshot() async {
    if (!_firstLoaded && mounted) setState(() => _firstLoaded = true);
    // 先加载随包发布的几十条默认名言，再异步请求 SQLite。
    // 旧逻辑先等 latestNotifiedToday()，首次启动/数据库受阻时整张画一直空白。
    if (_todayData == null) {
      try {
        final fallback = await _loadNextFallbackQuote();
        if (!mounted) return;
        if (_todayData == null &&
            (fallback['quote'] ?? '').toString().trim().isNotEmpty) {
          setState(() => _todayData = fallback);
          unawaited(_activateFrame(fallback));
        }
      } catch (e) {
        await DLog.e('HOME', '兜底名言加载失败: $e');
        if (mounted && _todayData == null) {
          setState(
            () => _todayData = <String, dynamic>{
              'topic': '每日名言',
              'quote': '千里之行，始于足下。',
              'author': '——《道德经》',
              'note': '从眼前的一小步开始。',
            },
          );
        }
      }
    }
    final previousRow = _latestRow;
    try {
      final dao = QuoteDao();
      final latest = await dao.latestNotifiedToday();
      if (!mounted) return;
      if (latest == null ||
          (latest['content'] ?? latest['quote'] ?? '')
              .toString()
              .trim()
              .isEmpty) {
        _latestRow = null;
        if (previousRow != null) {
          final fallback = await _loadNextFallbackQuote();
          if (mounted &&
              (fallback['quote'] ?? '').toString().trim().isNotEmpty) {
            setState(() => _todayData = fallback);
            unawaited(_activateFrame(fallback));
          }
        }
        // 没有今日有效记录时，保留刚刚即时显示的默认名言，不让首页回到空白。
        await DLog.i('HOME', '今日未检索到有效记录：显示默认名言');
        await _checkPinnedState();
        _requestNotifAfterFirstFrame();
      } else if (mapEquals(previousRow, latest) && _todayData != null) {
        // Keep the current poster (including a user-selected pinned quote)
        // when a tab switch or duplicate event carries no new database row.
        await _checkPinnedState();
        _requestNotifAfterFirstFrame();
      } else {
        _latestRow = latest;
        // 根据署名和出处组装 author 字段。若存在署名或出处则前缀“——”，否则为空
        final String authorName =
            (latest['author_name'] ?? latest['author'] ?? '').toString().trim();
        final String source = (latest['source_from'] ?? latest['source'] ?? '')
            .toString()
            .trim();
        final storedAvatar = (latest['avatar'] ?? '').toString().trim();
        final storedAvatarVerified = _isIdentityVerifiedAvatar(
          latest,
          authorName,
          storedAvatar,
        );
        // Old auto-downloaded files were selected without identity checking.
        // Never render them while the new resolver validates the author again.
        var avatarUrl = storedAvatarVerified
            ? await _resolveAvatarSource(storedAvatar)
            : '';
        if (avatarUrl.isEmpty) {
          avatarUrl = (await _matchAvatarAssetByAuthor(authorName)) ?? '';
        }
        if (!storedAvatarVerified || avatarUrl.isEmpty) {
          unawaited(_repairQuoteAvatar(latest, authorName));
        }
        String authorLine = '';
        if (authorName.isNotEmpty || source.isNotEmpty) {
          // 如果署名不为空，使用“——署名 出处”，否则仅加前缀
          authorLine = '——';
          if (authorName.isNotEmpty) {
            authorLine += authorName;
            if (source.isNotEmpty) {
              authorLine += '《' + source + '》';
            }
          } else {
            authorLine += (source.isNotEmpty ? ('《' + source + '》') : '');
          }
        }
        final payload = <String, dynamic>{
          'topic': (latest['theme'] ?? latest['topic'] ?? '').toString(),
          'quote': (latest['content'] ?? latest['quote'] ?? '').toString(),
          // 将 author 字段设置为包含署名和出处的组合文本
          'author': authorLine,
          'source': source,
          'note': (latest['explanation'] ?? latest['note'] ?? '').toString(),
          'avatarUrl': avatarUrl,
        };
        await DLog.i('HOME', '已检索到今日最新已通知记录：准备注入');
        await _logInject('db', payload);
        if (mounted)
          setState(() {
            _todayData = payload;
          });
        if (mounted) unawaited(_activateFrame(payload));
        // Update pinned state after injecting DB content
        await _checkPinnedState();
        _requestNotifAfterFirstFrame();
      }
    } catch (e) {
      _latestRow = previousRow;
      await DLog.e('HOME', '查询异常：注入兜底内容；err=$e');
      // 异常也不擦掉已显示的随包兜底名言。
      // Update pinned state after error fallback
      await _checkPinnedState();
      _requestNotifAfterFirstFrame();
    }
  }

  Future<void> _copyLatest() async {
    final quote = (_todayData?['quote'] ?? '').toString().trim();
    final author = (_todayData?['author'] ?? '').toString().trim();
    final text = [quote, author].where((value) => value.isNotEmpty).join('\n\n');
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('名言已复制，可粘贴分享'), behavior: SnackBarBehavior.floating, margin: const EdgeInsets.fromLTRB(18, 0, 18, 145)));
  }

  /// Load fixed quotes from the database.  When [reset] is true, clear the
  /// existing list and start from offset 0.  Otherwise, append the next
  /// page of results.  Each page fetches up to 20 records.  Updates
  /// [_pinnedQuotes], [_pinnedHasMore] and [_loadingPinned] accordingly.
  Future<void> _loadPinned({bool reset = false}) async {
    if (_loadingPinned) return;
    _loadingPinned = true;
    try {
      final dao = QuoteFixedDao();
      final offset = reset ? 0 : _pinnedQuotes.length;
      final rows = await dao.all(limit: 20, offset: offset);
      final total = await dao.count();
      final hydratedRows = rows.map((row) {
        final avatar = (row['avatar'] ?? '').toString().trim();
        final author = (row['author_name'] ?? row['author'] ?? '').toString();
        if (_isIdentityVerifiedAvatar(row, author, avatar)) return row;
        final asset = QuoteAvatarAssetResolver.forAuthor(author);
        return <String, dynamic>{...row, 'avatar': asset};
      }).toList();
      if (!mounted) return;
      setState(() {
        _pinnedTotal = total;
        if (reset) {
          _pinnedQuotes = List<Map<String, dynamic>>.from(hydratedRows);
          _pinnedEndToastShown = false;
        } else {
          _pinnedQuotes.addAll(hydratedRows);
        }
        _pinnedHasMore = rows.length == 20;
        _loadingPinned = false;
      });
      _pinnedCollectionTick.value++;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (reset && _pinnedController.hasClients) {
          _pinnedController.jumpTo(0);
        }
        _updatePinnedJumpButtons();
        if (!_pinnedHasMore && !_pinnedEndToastShown && _pinnedQuotes.length > 20) {
          _pinnedEndToastShown = true;
          final messenger = ScaffoldMessenger.maybeOf(context);
          messenger?.hideCurrentSnackBar();
          messenger?.showSnackBar(
            const SnackBar(
              content: Text('已经到底了'),
              behavior: SnackBarBehavior.floating, margin: const EdgeInsets.fromLTRB(18, 0, 18, 145),
              duration: Duration(milliseconds: 900),
            ),
          );
        }
      });
    } catch (_) {
      _loadingPinned = false;
    }
  }

  void _handlePinnedScroll() {
    if (!_pinnedController.hasClients) {
      return;
    }
    _updatePinnedJumpButtons();
    final position = _pinnedController.position;
    if (!_loadingPinned && _pinnedHasMore && position.extentAfter < 320) {
      _loadPinned(reset: false);
    }
  }

  void _updatePinnedJumpButtons() {
    if (!_pinnedController.hasClients || _pinnedQuotes.length <= 1) {
      if (_showPinnedJumpToStart || _showPinnedJumpToEnd) {
        setState(() {
          _showPinnedJumpToStart = false;
          _showPinnedJumpToEnd = false;
        });
        if (_pinnedGalleryOpen) _pinnedCollectionTick.value++;
      }
      return;
    }
    final position = _pinnedController.position;
    final bool showStart = position.pixels > 24;
    final bool showEnd = position.pixels < (position.maxScrollExtent - 24);
    if (showStart != _showPinnedJumpToStart || showEnd != _showPinnedJumpToEnd) {
      setState(() {
        _showPinnedJumpToStart = showStart;
        _showPinnedJumpToEnd = showEnd;
      });
      if (_pinnedGalleryOpen) _pinnedCollectionTick.value++;
    }
  }

  Future<void> _jumpPinnedToEdge({required bool toStart}) async {
    final revision = ++_pinnedJumpRevision;
    bool current() => mounted && revision == _pinnedJumpRevision && _pinnedController.hasClients;
    if (!current()) return;
    if (!toStart) {
      while (_pinnedHasMore && current()) {
        await _loadPinned(reset: false);
        await WidgetsBinding.instance.endOfFrame;
      }
    }
    var previousTarget = -1.0;
    while (current()) {
      final position = _pinnedController.position;
      final target = toStart ? 0.0 : position.maxScrollExtent;
      if (!toStart && target <= previousTarget + .5) return;
      previousTarget = target;
      await position.animateTo(target, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
      if (!current()) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!current() || toStart) return;
      final settled = _pinnedController.position;
      // Appending cards can extend the modal's scroll bounds during animation.
      // Continue only if the old endpoint was reached; a user drag cancels it.
      if (settled.extentAfter < .5 || (settled.pixels - target).abs() > 1) return;
    }
  }

  /// Build a single fixed quote card using the same default wooden-frame photo
  /// as the main home poster.
  Widget _buildFixedCard(Map<String, dynamic> row) => Semantics(
    button: true,
    label: '阅读固定名言：${row['theme'] ?? ''}',
    child: GestureDetector(
      key: ValueKey('pinned-quote-${row['id'] ?? row['fixed_uid']}'),
      onTap: () {
        unawaited(_switchToPinned(row));
        if (_pinnedGalleryOpen) Navigator.of(context).pop();
      },
      child: PosterPureFlutter(
        topic: (row['theme'] ?? '').toString(),
        quote: (row['content'] ?? '').toString(),
        author: _buildAuthorLine(
          (row['author_name'] ?? '').toString(),
          (row['source_from'] ?? '').toString(),
        ),
        note: (row['explanation'] ?? '').toString(),
        avatar: (row['avatar'] ?? '').toString(),
        calligraphyStyle: _quoteCalligraphyStyle,
        englishFontStyle: _quoteEnglishFontStyle,
      ),
    ),
  );

  /// Build the grey area widget that displays pinned quotes.  When the list is
  /// empty, returns an empty widget.  When there is one item, centers it.
  /// Otherwise, lays out cards horizontally with lazy loading and a trailing
  /// message when all data has loaded.
  Widget _buildPinnedContent() {
    if (_pinnedQuotes.isEmpty) {
      return const SizedBox.shrink();
    }
    final double bottomInset = MediaQuery.of(context).padding.bottom;
    const double cardHeight = 230;
    final double viewportHeight = cardHeight + bottomInset + 12;
    final EdgeInsets listPadding = EdgeInsets.fromLTRB(6, 0, 6, bottomInset + 6);

    Widget buildItemCard(Map<String, dynamic> row) {
      final int? id = row['id'] is int ? row['id'] as int : null;
      Widget card = SizedBox(
        width: _pinnedCardWidth,
        height: cardHeight,
        child: _buildFixedCard(row),
      );
      if (id != null && id == _animInsertPinnedId) {
        card = TweenAnimationBuilder<Offset>(
          tween: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: card,
          builder: (context, offset, child) =>
              FractionalTranslation(translation: offset, child: child),
        );
      } else if (id != null && id == _animRemovePinnedId) {
        card = TweenAnimationBuilder<Offset>(
          tween: Tween<Offset>(begin: Offset.zero, end: const Offset(0, -1)),
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInCubic,
          child: card,
          builder: (context, offset, child) =>
              FractionalTranslation(translation: offset, child: child),
        );
      }
      return card;
    }

    final Widget listView = ListView.builder(
      controller: _pinnedController,
      scrollDirection: Axis.horizontal,
      itemExtent: _pinnedCardWidth + _pinnedCardGap,
      physics: const ClampingScrollPhysics(),
      padding: listPadding,
      itemCount: _pinnedQuotes.length + (_pinnedHasMore ? 0 : 1),
      itemBuilder: (context, idx) {
        if (idx < _pinnedQuotes.length) {
          return buildItemCard(_pinnedQuotes[idx]);
        }
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '已经到底了',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
        );
      },
    );

    return Container(
      height: viewportHeight,
      width: double.infinity,
      color: const Color(0xFFF5F5F5),
      child: Stack(
        children: [
          if (_pinnedQuotes.length == 1)
            Padding(
              padding: listPadding,
              child: Align(
                alignment: Alignment.topCenter,
                child: buildItemCard(_pinnedQuotes.first),
              ),
            )
          else
            listView,
          if (_showPinnedJumpToStart)
            Positioned(
              left: 6,
              top: 84,
              child: _buildPinnedJumpButton(
                icon: Icons.chevron_left,
                tooltip: '跳到最新固定的名言',
                onTap: () => _jumpPinnedToEdge(toStart: true),
              ),
            ),
          if (_showPinnedJumpToEnd)
            Positioned(
              right: 6,
              top: 84,
              child: _buildPinnedJumpButton(
                icon: Icons.chevron_right,
                tooltip: '跳到最早固定的名言',
                onTap: () => _jumpPinnedToEdge(toStart: false),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPinnedJumpButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(message: tooltip, child: Material(
      color: Colors.white.withOpacity(0.96),
      elevation: 4,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: Colors.black87, size: 26),
        ),
      ),
    ));
  }

  /// Check whether the currently displayed quote is already pinned.  Updates
  /// the [_pinnedActive] flag accordingly.  Invoked whenever [_todayData]
  /// changes.
  Future<void> _checkPinnedState() async {
    final content = (_todayData?['quote'] ?? '').toString();
    final theme = (_todayData?['topic'] ?? '').toString();
    if (content.trim().isEmpty) {
      if (mounted) setState(() { _pinnedActive = false; });
      return;
    }
    final dao = QuoteFixedDao();
    final row = await dao.findByContentAndTheme(content, theme);
    if (!mounted) return;
    setState(() { _pinnedActive = row != null; });
  }

  /// Toggle the pin state for the current large quote.  If the quote is
  /// already pinned, this will remove it; otherwise, it attempts to insert
  /// it into the fixed table.  Displays feedback via SnackBar.
  Future<void> _togglePin() async {
    final content = (_todayData?['quote'] ?? '').toString();
    final theme = (_todayData?['topic'] ?? '').toString();
    if (content.trim().isEmpty) return;
    final fixedDao = QuoteFixedDao();
    final existing = await fixedDao.findByContentAndTheme(content, theme);
    if (existing != null) {
      // Unpin with slide-up + list shift animation
      final int? removingId = existing['id'] is int ? existing['id'] as int : null;
      if (mounted && removingId != null) {
        setState(() { _animRemovePinnedId = removingId; });
      }
      await fixedDao.deleteByContentAndTheme(content, theme);
      if (mounted) {
        setState(() { _pinnedActive = false; });
      }
      // allow the card to slide up before removing from list
      await Future.delayed(const Duration(milliseconds: 260));
      await _loadPinned(reset: true);
      if (mounted) {
        setState(() { _animRemovePinnedId = null; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已取消固定名言'),
            behavior: SnackBarBehavior.floating, margin: const EdgeInsets.fromLTRB(18, 0, 18, 145),
          ),
        );
      }
      return;
    }
    // Not pinned; search in quotes table
    final quoteDao = QuoteDao();
    final row = await quoteDao.findByContentAndTheme(content, theme)
        ?? QuoteLibraryStore.normalize(_todayData ?? {});
    final int? quoteId = row['id'] is int ? row['id'] as int : null;
    await fixedDao.insert(
      content: content,
      theme: theme,
      authorName: (row['author_name'] ?? row['author'] ?? '').toString(),
      sourceFrom: (row['source_from'] ?? row['source'] ?? '').toString(),
      explanation: (row['explanation'] ?? row['note'] ?? '').toString(),
      avatar: () {
        final saved = (row['avatar'] ?? row['avatarUrl'] ?? '').toString();
        if (saved.trim().isNotEmpty) return saved;
        return QuoteAvatarAssetResolver.forAuthor(
          (row['author_name'] ?? row['author'] ?? '').toString(),
        );
      }(),
      quoteId: quoteId,
    );
    if (mounted) {
      setState(() { _pinnedActive = true; });
    }
    await Future.delayed(const Duration(milliseconds: 260));
    await _loadPinned(reset: true);
    // mark the new leftmost card to slide down from top
    if (mounted && _pinnedQuotes.isNotEmpty) {
      final int? newId = _pinnedQuotes.first['id'] is int ? _pinnedQuotes.first['id'] as int : null;
      setState(() { _animInsertPinnedId = newId; });
      Future.delayed(const Duration(milliseconds: 360), () {
        if (mounted) setState(() { _animInsertPinnedId = null; });
      });
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('名言已固定在底部'),
          behavior: SnackBarBehavior.floating, margin: const EdgeInsets.fromLTRB(18, 0, 18, 145),
        ),
      );
    }
  }

  /// Switch the large poster to display a pinned quote.  Builds the
  /// corresponding payload and updates [_todayData], then refreshes the
  /// pinned state.
  Future<void> _switchToPinned(Map<String, dynamic> row) async {
    final authorName = (row['author_name'] ?? '').toString().trim();
    final savedAvatar = (row['avatar'] ?? '').toString();
    var avatarUrl = _isIdentityVerifiedAvatar(row, authorName, savedAvatar)
        ? await _resolveAvatarSource(savedAvatar)
        : '';
    if (avatarUrl.isEmpty) {
      avatarUrl = QuoteAvatarAssetResolver.forAuthor(authorName);
    }
    final String theme = (row['theme'] ?? '').toString();
    final String quote = (row['content'] ?? '').toString();
    final String source = (row['source_from'] ?? '').toString().trim();
    final String note = (row['explanation'] ?? '').toString();
    String authorLine = '';
    if (authorName.isNotEmpty || source.isNotEmpty) {
      authorLine = '——';
      if (authorName.isNotEmpty) {
        authorLine += authorName;
        if (source.isNotEmpty) {
          authorLine += '《' + source + '》';
        }
      } else {
        authorLine += (source.isNotEmpty ? ('《' + source + '》') : '');
      }
    }
    final payload = <String, dynamic>{
      'topic': theme,
      'quote': quote,
      'author': authorLine,
      'source': source,
      'note': note,
      'avatarUrl': avatarUrl,
    };
    if (!mounted) return;
    setState(() {
      _todayData = payload;
    });
    unawaited(_activateFrame(payload));
    // After switching, update pinned state
    await _checkPinnedState();
  }

  @override
  Widget build(BuildContext context) {
    try {
      return _buildScaffold(context);
    } catch (e, st) {
      try { DLog.e('HOME', 'HomePage build failed: $e\n$st'); } catch (_) {}
      // 兜底：避免 release 白屏，并把异常信息显示出来（便于定位）。
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '首页渲染异常：\n$e',
                style: const TextStyle(fontSize: 14, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }
  }

  Future<void> _loadFavoriteFor(Map<String, dynamic> payload) async {
    final generation = ++_favoriteGeneration;
    try {
      final favorite = await _library.isFavorite(payload);
      if (mounted && generation == _favoriteGeneration && _fav != favorite)
        setState(() => _fav = favorite);
    } catch (_) {
      /* Keep the current collection marker during a short read failure. */
    }
  }

  Future<void> _toggleFavorite() async {
    final payload = _todayData;
    if (payload == null || _favoriteBusy) return;
    _favoriteBusy = true;
    final identity = QuoteLibraryStore.identity(payload);
    try {
      final selected = !(await _library.isFavorite(payload));
      await _library.setFavorite(payload, selected);
      if (!mounted) return;
      if (_todayData != null &&
          QuoteLibraryStore.identity(_todayData!) == identity) {
        ++_favoriteGeneration;
        setState(() => _fav = selected);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(selected ? '已收藏，可在名言书房中再读' : '已取消收藏'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 145),
        ),
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('收藏未能保存，请重试')));
    } finally {
      _favoriteBusy = false;
    }
  }

  Future<void> _nextQuote() async {
    if (_nextBusy || _todayData == null) return;
    setState(() => _nextBusy = true);
    try {
      Map<String, dynamic>? row;
      try {
        row = await _library.randomOther(
          (_todayData?['quote'] ?? '').toString(),
        );
      } catch (_) {}
      row ??= QuoteLibraryStore.normalize(await _loadNextFallbackQuote());
      if (mounted && (row['content'] ?? '').toString().trim().isNotEmpty)
        await _switchToPinned(row);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('暂时未能换一条，请重试')));
    } finally {
      if (mounted) setState(() => _nextBusy = false);
    }
  }

  Future<void> _openLibrary({
    bool search = false,
    bool favoritesOnly = false,
  }) async {
    final row = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: journeyPaper,
      builder: (_) =>
          QuoteLibrarySheet(autofocus: search, favoritesOnly: favoritesOnly),
    );
    if (mounted && row != null) await _switchToPinned(row);
  }

  Future<void> _showPinnedGallery() async {
    _pinnedGalleryOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: journeyPaper,
        builder: (_) => SafeArea(
          top: false,
          child: ValueListenableBuilder<int>(
            valueListenable: _pinnedCollectionTick,
            builder: (context, _, __) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _pinnedGalleryOpen) _updatePinnedJumpButtons();
              });
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 0, 24, 7),
                    child: Text(
                      '固定的好思想',
                      style: TextStyle(
                        fontFamily: 'QuoteKaiShu',
                        fontSize: 24,
                        color: journeyInk,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: Text(
                      '左右滑动，轻点一幅，再读一次。',
                      style: TextStyle(fontSize: 12, color: journeyMuted),
                    ),
                  ),
                  _pinnedQuotes.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(30),
                          child: Center(
                            child: Text(
                              '用画面右上角的图钉，把喜欢的名言留在这里。',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: journeyMuted),
                            ),
                          ),
                        )
                      : _buildPinnedContent(),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
        ),
      );
    } finally {
      _pinnedGalleryOpen = false;
    }
  }

  void _readHistoryAt(int index) {
    if (index < 0 || index >= _readingHistory.length) return;
    final payload = _readingHistory[index];
    setState(() => _todayData = payload);
    unawaited(_activateFrame(payload));
    unawaited(_checkPinnedState());
  }

  Widget _buildScaffold(BuildContext context) {
    final content =
        _todayData ??
        const <String, dynamic>{
          'topic': '每日名言',
          'quote': '名言加载中…',
          'author': '',
          'note': '',
        };
    return Scaffold(
      backgroundColor: const Color(0xfff7f4ed),
      body: QuoteHomeScene(
        poster: PosterPureFlutter(
          topic: '${content['topic'] ?? ''}',
          quote: '${content['quote'] ?? ''}',
          author: '${content['author'] ?? ''}',
          note: '${content['note'] ?? ''}',
          avatar: '${content['avatar'] ?? content['avatarUrl'] ?? ''}',
          woodBgAsset: QuoteAdaptiveFrame.defaultBackgroundAsset,
          aiFramePath: _frameImagePath,
          animateCalligraphy: _quoteCalligraphyEnabled,
          calligraphyStyle: _quoteCalligraphyStyle,
          englishFontStyle: _quoteEnglishFontStyle,
        ),
        moreMenu: _buildMoreMenu(),
        onMenu: _openLeftDrawer,
        onSearch: () => _openLibrary(search: true),
        onPin: _togglePin,
        onNext: _nextQuote,
        onFavorite: _toggleFavorite,
        onCategories: _openLibrary,
        onShare: _copyLatest,
        onPinnedQuotes: _showPinnedGallery,
        favorite: _fav,
        pinned: _pinnedActive,
        nextBusy: _nextBusy,
        pinnedCount: _pinnedTotal,
        historyCount: _readingHistory.isEmpty ? 1 : _readingHistory.length,
        historyIndex: _readingIndex,
        onHistory: _readHistoryAt,
      ),
    );
  }

  Widget _buildMoreMenu() => PopupMenuButton<String>(
    tooltip: '更多操作',
    constraints: const BoxConstraints(maxWidth: 310),
    iconSize: 21,
    padding: const EdgeInsets.all(8),
    icon: const Icon(Icons.more_vert, color: Colors.black87),
    onSelected: _handleTopBarMenu,
    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
      const PopupMenuItem<String>(
        value: 'pinned_quotes',
        child: Text('固定的名言集'),
      ),
      const PopupMenuItem<String>(
        value: 'favorite_quotes',
        child: Text('我收藏的名言'),
      ),
      const PopupMenuDivider(),
      PopupMenuItem<String>(
        value: 'frame_generate',
        child: Row(
          children: [
            Icon(_frameGenerating ? Icons.hourglass_top : Icons.auto_awesome),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_frameGenerating ? '正在生成配画' : 'AI 生成/重绘框内配画（可能收费）'),
            ),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'frame_toggle',
        child: Row(
          children: [
            Icon(_frameAuto ? Icons.check_box : Icons.check_box_outline_blank),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_frameAuto ? '关闭 AI 自动配画' : '开启 AI 自动配画（可能收费）'),
            ),
          ],
        ),
      ),
      const PopupMenuItem<String>(
        value: 'frame_explain',
        child: Row(
          children: [
            Icon(Icons.auto_stories_outlined),
            SizedBox(width: 8),
            Expanded(child: Text('查看名言视觉化解释')),
          ],
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem<String>(
        value: 'share',
        child: Row(
          children: const [Icon(Icons.share), SizedBox(width: 8), Text('分享')],
        ),
      ),
      PopupMenuItem<String>(
        value: 'favorite',
        child: Row(
          children: [
            Icon(_fav ? Icons.favorite : Icons.favorite_border),
            const SizedBox(width: 8),
            Text(_fav ? '取消收藏' : '收藏'),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'like',
        child: Row(
          children: const [
            Icon(Icons.thumb_up_alt_outlined),
            SizedBox(width: 8),
            Text('喜欢'),
          ],
        ),
      ),
    ],
  );

  /// 每次进入首页（首开/重启/被杀后重启/从后台恢复）仅检查一次；未开仅触发系统默认通知权限弹窗。
  Future<void> _checkNotificationPermission() async {
    if (_sessionPrompted) return;
    _sessionPrompted = true;
    bool enabled = true;
    try { enabled = await NotificationService.areNotificationsEnabled(); } catch (_){ enabled = false; }
    if (enabled != true) {
      try { await NotificationService.request(); } catch (_){}
    }
  }
}
