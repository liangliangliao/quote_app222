
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:characters/characters.dart';
import 'package:quote_app/widgets/poster_pure_flutter.dart';
import 'package:quote_app/widgets/quote_adaptive_frame.dart';
import 'package:quote_app/widgets/quote_portrait_cutout.dart';
import 'package:quote_app/widgets/quote_calligraphy_text.dart';
import 'package:quote_app/services/quote_frame_theme.dart';
import 'package:quote_app/services/quote_frame_ai_service.dart';
import 'package:quote_app/services/quote_calligraphy_settings.dart';
import 'package:quote_app/services/notification_service.dart';
import 'package:quote_app/services/quote_ai_service.dart';
import '../models/quote_insight.dart';
import '../data/dao.dart';
import '../utils/debug_logger.dart';
import '../epistemic/cognitive_mode.dart';
import '../epistemic/quote_cognitive_reader.dart';
import 'package:quote_app/services/native_guard.dart';



/// Local scroll behavior to hide glow/scrollbar and use clamping physics,
/// mirroring the helpers used in other widgets.
class _NoIndicatorScroll extends ScrollBehavior {
  @override
  Widget buildViewportChrome(BuildContext context, Widget child, AxisDirection axisDirection) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const ClampingScrollPhysics();
}


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
    final topic = (payload['topic'] ?? '').toString();
    final quote = (payload['quote'] ?? '').toString();
    final key = _frameAi.cacheKey(topic, quote);
    final int revision = ++_frameRevision;
    if (_visibleFrameKey != key && mounted) {
      setState(() {
        _visibleFrameKey = key;
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(script == null
            ? '当前尚未生成 AI 视觉脚本。请先选择「AI 生成/重绘框内配画」。默认始终使用你提供的木质画框。'
            : '原句含义：${script.meaning}\n\n核心视觉类比：${script.metaphor}\n\n可见场景：${script.scene}\n\n为什么这样画：${script.relationship}\n\n氛围：${script.mood}\n\n固定画框：你提供的木质画框；AI 只替换框内画面。\n\n分析来源：${script.fromAi ? 'AI 语义解析' : '本地有限规则兜底（不代表 AI 已理解）'}'),
            if (script != null) CognitiveMode(child: QuoteVisualExplanation(
                topic: topic, quote: quote, script: script)),
          ]),
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
  bool _fav = false;

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
  double get _pinnedShift => _pinnedCardWidth + _pinnedCardGap;
  double _pinnedAreaExtraWidth = 0.0; // extra width for grey area, expands symmetrically when pin/unpin

  void _openLeftDrawer() {
    try {
      final scaffold = Scaffold.maybeOf(context);
      scaffold?.openDrawer();
    } catch (_) {}
  }

  void _handleTopBarMenu(String value) async {
    switch (value) {
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
        setState(() {
          _fav = !_fav;
        });
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
    if (!_firstLoaded && mounted) setState(() => _firstLoaded = true);
    // 先加载随包发布的几十条默认名言，再异步请求 SQLite。
    // 旧逻辑先等 latestNotifiedToday()，首次启动/数据库受阻时整张画一直空白。
    try {
      final fallback = await _loadNextFallbackQuote();
      if (!mounted) return;
      if (_latestRow == null && (fallback['quote'] ?? '').toString().trim().isNotEmpty) {
        setState(() => _todayData = fallback);
        unawaited(_activateFrame(fallback));
      }
    } catch (e) {
      await DLog.e('HOME', '兜底名言加载失败: $e');
      if (mounted && _todayData == null) {
        setState(() => _todayData = <String, dynamic>{
          'topic': '每日名言',
          'quote': '千里之行，始于足下。',
          'author': '——《道德经》',
          'note': '从眼前的一小步开始。',
        });
      }
    }
    try {
      final dao = QuoteDao();
      final latest = await dao.latestNotifiedToday();
      if (!mounted) return;
      _latestRow = latest;
      if (latest == null || (latest['content'] ?? latest['quote'] ?? '').toString().trim().isEmpty) {
        // 没有今日有效记录时，保留刚刚即时显示的默认名言，不让首页回到空白。
        await DLog.i('HOME', '今日未检索到有效记录：显示默认名言');
        await _checkPinnedState();
        _requestNotifAfterFirstFrame();
      } else {
        // 根据署名和出处组装 author 字段。若存在署名或出处则前缀“——”，否则为空
        final String authorName = (latest['author_name'] ?? latest['author'] ?? '').toString().trim();
        final String source = (latest['source_from'] ?? latest['source'] ?? '').toString().trim();
        final storedAvatar = (latest['avatar'] ?? '').toString().trim();
        final storedAvatarVerified =
            _isIdentityVerifiedAvatar(latest, authorName, storedAvatar);
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
            authorLine += authorName; if (source.isNotEmpty) { authorLine += '《' + source + '》'; }
          } else { authorLine += (source.isNotEmpty ? ('《' + source + '》') : ''); }
        }
        final payload = <String, dynamic>{
          'topic': (latest['theme'] ?? latest['topic'] ?? '').toString(),
          'quote': (latest['content'] ?? latest['quote'] ?? '').toString(),
          // 将 author 字段设置为包含署名和出处的组合文本
          'author': authorLine,
          'source': source,
          'quoteAuthor': authorName,
          'quoteUid': (latest['quote_uid'] ?? '').toString(),
          'note': (latest['explanation'] ?? latest['note'] ?? '').toString(),
          'avatarUrl': avatarUrl,
        };
        await DLog.i('HOME', '已检索到今日最新已通知记录：准备注入');
        await _logInject('db', payload);
        if (mounted) setState(() { _todayData = payload; });
        if (mounted) unawaited(_activateFrame(payload));
      // Update pinned state after injecting DB content
      await _checkPinnedState();
      _requestNotifAfterFirstFrame();
      }
    } catch (e) {
      await DLog.e('HOME', '查询异常：注入兜底内容；err=$e');
      // 异常也不擦掉已显示的随包兜底名言。
        // Update pinned state after error fallback
        await _checkPinnedState();
        _requestNotifAfterFirstFrame();
        }
  }

  Future<void> _copyLatest() async {
    final text = (_latestRow?['content'] ?? '').toString();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制'), behavior: SnackBarBehavior.floating));
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
      final hydratedRows = rows.map((row) {
        final avatar = (row['avatar'] ?? '').toString().trim();
        final author = (row['author_name'] ?? row['author'] ?? '').toString();
        if (_isIdentityVerifiedAvatar(row, author, avatar)) return row;
        final asset = QuoteAvatarAssetResolver.forAuthor(author);
        return <String, dynamic>{...row, 'avatar': asset};
      }).toList();
      if (!mounted) return;
      setState(() {
        if (reset) {
          _pinnedQuotes = List<Map<String, dynamic>>.from(hydratedRows);
          _pinnedEndToastShown = false;
        } else {
          _pinnedQuotes.addAll(hydratedRows);
        }
        _pinnedHasMore = rows.length == 20;
        _loadingPinned = false;
      });
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
              behavior: SnackBarBehavior.floating,
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
    }
  }

  Future<void> _jumpPinnedToEdge({required bool toStart}) async {
    if (!_pinnedController.hasClients) return;
    if (!toStart) {
      while (_pinnedHasMore && mounted) {
        await _loadPinned(reset: false);
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
      if (!_pinnedController.hasClients) return;
    }
    final position = _pinnedController.position;
    final double target = toStart ? 0.0 : position.maxScrollExtent;
    await _pinnedController.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  /// Build a single fixed quote card using the same default wooden-frame photo
  /// as the main home poster.
  Widget 
_buildFixedCard(Map<String, dynamic> row) {

ImageProvider _imageFrom(String? any) {
  final String s = (any ?? '').toString().trim();
  if (s.isEmpty || s.toLowerCase() == 'null') {
    return const AssetImage('assets/bg-wood-upload.jpg');
  }
  if (s.startsWith('data:')) {
    final b64 = s.substring(s.indexOf(',') + 1);
    return MemoryImage(base64.decode(b64));
  }
  if (s.startsWith('http')) return NetworkImage(s);
  if (s.startsWith('file://')) {
    try { return FileImage(File(Uri.parse(s).toFilePath())); } catch (_) { return const AssetImage('assets/bg-wood-upload.jpg'); }
  }
  if (s.startsWith('/')) {
    try { return FileImage(File(s)); } catch (_) { return const AssetImage('assets/bg-wood-upload.jpg'); }
  }
  if (s.startsWith('assets/')) return AssetImage(s);
  return const AssetImage('assets/bg-wood-upload.jpg');
}

    return GestureDetector(
      onTap: () => _switchToPinned(row),
      child: SizedBox(
        width: 200,
        child: AspectRatio(
          aspectRatio: 0.87,
          child: LayoutBuilder(
            builder: (context, cons) {
              final short = (cons.maxWidth < cons.maxHeight) ? cons.maxWidth : cons.maxHeight;
              // Font sizes scale with the background image size, tuned to roughly
              // match the ratios used in the large poster.
              final tTitle = (short * 0.095).clamp(8.5, 14.0);
              final tQuote = (short * 0.155).clamp(8.5, 16.0);
              final tAuth  = (short * 0.075).clamp(7.0, 11.0);
              final tNote  = (short * 0.030).clamp(10.5, 12.4);
              final avatarSize = (short * 0.28 * 0.85).clamp(36.0, 56.0);
              final innerPadH = (((short * 0.10).clamp(8.0, 14.0)) - 5.0).clamp(0.0, 9999.0);
              final innerPadV = (short * 0.12).clamp(8.0, 16.0);

              final topic = (row['theme'] ?? row['topic'] ?? '') as String;
              final quote = (row['content'] ?? row['quote'] ?? '') as String;
              final authorName = (row['author_name'] ?? row['author'] ?? '') as String;
              final sourceFrom = (row['source_from'] ?? row['source'] ?? '') as String;
              final note = (row['explanation'] ?? row['note'] ?? '') as String;
              final avatar = (row['avatar'] ?? row['avatarUrl'] ?? '') as String;
              final authorLine = _buildAuthorLine(authorName, sourceFrom);
              final hasAvatar = avatar.trim().isNotEmpty && avatar.trim().toLowerCase() != 'null';
              final bool shortTopic = topic.length < 15;

              return Stack(
                fit: StackFit.expand,
                children: [
                  // 与首页主画面一致的唯一默认木质画框。
                  Positioned.fill(
                    child: QuoteAdaptiveFrame(quoteCharacters: quote.runes.length),
                  ),
                  // 画布内容
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        innerPadH + 15,
                        12,
                        innerPadH + 15,
                        12, // vertical padding reduced by 10dp as requested
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        clipBehavior: Clip.hardEdge,
                        child: ScrollConfiguration(
                        behavior: _NoIndicatorScroll(),
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 10), // add top outer margin for topic/avatar
                            // 主题 + 头像（固定在顶部）
                            hasAvatar
                                ? Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.only(left: 12),
                                          child: Text(
                                            topic,
                                            maxLines: null,
                                            overflow: TextOverflow.visible,
                                            style: TextStyle(
                                              color: Colors.black87,
                                              fontSize: tTitle,
                                              height: 1.25,
                                              fontWeight: FontWeight.w400,
                                      letterSpacing: 0.6, ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: innerPadH * 0.6),
                                      QuotePortraitCutout(
                                        image: _imageFrom(avatar),
                                        width: avatarSize,
                                        height: avatarSize * 1.22,
                                      ),
                                    ],
                                  )
                                : Center(
                                    child: Text(
                                      topic,
                                      textAlign: TextAlign.center,
                                      softWrap: true,
                                      maxLines: null,
                                      overflow: TextOverflow.visible,
                                      style: TextStyle(
                                        color: Colors.black87,
                                        fontSize: tTitle,
                                        height: 1.25,
                                        fontWeight: FontWeight.w400,
                                      letterSpacing: 0.6, ),
                                    ),
                                  ),
                            SizedBox(height: innerPadV * 0.6),
                            // 可滚动正文+署名+注解
                            Expanded(
                              child: ScrollConfiguration(
                                behavior: _NoIndicatorScroll(),
                                child: SingleChildScrollView(
                                  physics: const ClampingScrollPhysics(),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text.rich(
                                        quoteBodyTextSpan(
                                          quote,
                                          const TextStyle(
                                            color: Colors.black87,
                                            fontSize: 20,
                                            height: 1.45,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 2.0,
                                          ),
                                          _quoteCalligraphyStyle,
                                          _quoteEnglishFontStyle,
                                        ),
                                        textScaler: TextScaler.noScaling,
                                      ),
                                      SizedBox(height: innerPadV * 0.5 - 5),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: QuoteAuthorSignature(
                                          _buildAuthorLine(authorName, sourceFrom),
                                          textAlign: TextAlign.right,
                                          softWrap: true,
                                          overflow: TextOverflow.visible,
                                          style: TextStyle(
                                            color: Colors.black87,
                                            fontSize: tAuth - 1,
                                            height: 1.40,
                                            fontWeight: FontWeight.w400,
                                      letterSpacing: 0, ),
                                        ),
                                      ),
                                      if (note.trim().isNotEmpty) ...[
                                        SizedBox(height: innerPadV * 0.5),
                                        Text(
                                          note,
                                          style: TextStyle(
                                            color: Colors.black87,
                                            fontSize: tNote,
                                            height: 1.40,
                                            fontWeight: FontWeight.w400,
                                      letterSpacing: 0.5,
                                          ),
                                        ),
                                        SizedBox(height: 10), // add bottom outer margin for note
                                      ]
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        ),
                      ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }


  /// Layout inner contents of a fixed quote card.  Dynamically scales font
  /// sizes relative to the card width to ensure readability on small cards.
  Widget _buildFixedCardContent(Map<String, dynamic> row) {
    final String theme = (row['theme'] ?? '').toString();
    final String quote = (row['content'] ?? '').toString();
    final String authorName = (row['author_name'] ?? '').toString();
    final String sourceFrom = (row['source_from'] ?? '').toString();
    final String explanation = (row['explanation'] ?? '').toString();
    String authorLine = '';
    if (authorName.isNotEmpty || sourceFrom.isNotEmpty) {
      authorLine = '——';
      if (authorName.isNotEmpty) {
        authorLine += authorName;
        if (sourceFrom.isNotEmpty) {
          authorLine += '《' + sourceFrom + '》';
        }
      } else {
        authorLine += (sourceFrom.isNotEmpty ? ('《' + sourceFrom + '》') : '');
      }
    }
    return LayoutBuilder(
      builder: (context, cons) {
        final w = cons.maxWidth;
        final topicSize = (w * 0.10).clamp(10.0, 16.0);
        final quoteSize = (w * 0.15).clamp(12.0, 20.0);
        final authorSize = (w * 0.08).clamp(8.0, 14.0);
        final noteSize = (w * 0.030).clamp(10.5, 12.4);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 64),
              child: SingleChildScrollView(
                child: Text(
                  theme,
                  textAlign: (theme.characters.length < 20) ? TextAlign.center : TextAlign.left,
                  softWrap: true,
                  style: TextStyle(
                color: Colors.black87,
                fontSize: topicSize - 1,
                fontWeight: FontWeight.w400,
                                      letterSpacing: 0.6,
                height: 1.2,
              )
                ),
              ),
            ),
            SizedBox(height: w * 0.05),
            Expanded(
              child: Text.rich(
                quoteBodyTextSpan(
                  quote,
                  const TextStyle(
                    color: Colors.black87,
                    fontSize: 20,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                  ),
                  _quoteCalligraphyStyle,
                  _quoteEnglishFontStyle,
                ),
                textScaler: TextScaler.noScaling,
                maxLines: 3,
                overflow: TextOverflow.visible,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: QuoteAuthorSignature(
                authorLine,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: authorSize,
                  fontWeight: FontWeight.w400,
                                      letterSpacing: 0,
                  height: 1.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.visible,
              ),
            ),
            SizedBox(height: w * 0.02),
            Text(
              explanation,
              style: TextStyle(
                color: Colors.black87,
                fontSize: noteSize,
                fontWeight: FontWeight.w400,
                                      letterSpacing: 0.5,
                height: 1.40,
              ),
              maxLines: null,
              overflow: TextOverflow.visible,
            ),
          ],
        );
      },
    );
  }

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

    final Widget listView = ListView.separated(
      controller: _pinnedController,
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      padding: listPadding,
      itemCount: _pinnedQuotes.length + (_pinnedHasMore ? 0 : 1),
      separatorBuilder: (_, __) => const SizedBox(width: _pinnedCardGap),
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
                onTap: () => _jumpPinnedToEdge(toStart: true),
              ),
            ),
          if (_showPinnedJumpToEnd)
            Positioned(
              right: 6,
              top: 84,
              child: _buildPinnedJumpButton(
                icon: Icons.chevron_right,
                onTap: () => _jumpPinnedToEdge(toStart: false),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPinnedJumpButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
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
    );
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
      // after card is removed, collapse grey area back symmetrically
      if (mounted) {
        setState(() { _pinnedAreaExtraWidth = _pinnedQuotes.isNotEmpty ? _pinnedShift : 0.0; });
      }
      if (mounted) {
        setState(() { _animRemovePinnedId = null; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已取消固定名言'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    // Not pinned; search in quotes table
    final quoteDao = QuoteDao();
    final row = await quoteDao.findByContentAndTheme(content, theme);
    if (row == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('此名言不存在，固定名言失败'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
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
    // before showing the new leftmost card, expand grey area width symmetrically to make space
    if (mounted) {
      setState(() { _pinnedAreaExtraWidth = _pinnedShift; });
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
          behavior: SnackBarBehavior.floating,
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
      'quoteAuthor': authorName,
      'quoteUid': (row['quote_uid'] ?? row['fixed_uid'] ?? '').toString(),
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

  Widget _buildScaffold(BuildContext context) {
    // 永远不要把空对象渲染成整张无字相框。
    final content = _todayData ?? const <String, dynamic>{
      'topic': '每日名言',
      'quote': '名言加载中…',
      'author': '',
      'note': '',
    };
    final media = MediaQuery.of(context);
    final topPad = media.padding.top;
    final contentPad = topPad;
    final double bottomInset = media.padding.bottom;
    final bool showPinnedArea = _pinnedQuotes.isNotEmpty;
    final double pinnedViewportHeight = showPinnedArea ? (230 + bottomInset + 12) : 0;
    final double pinnedBottomGap = bottomInset + 2;
    final double posterBottomReserve = showPinnedArea
        ? (pinnedViewportHeight + pinnedBottomGap - 24)
        : 0;
    final double posterLayoutWidth = media.size.width;
    final double posterLayoutHeight = posterLayoutWidth * 1.5;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: contentPad),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: posterBottomReserve),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
                        child: ClipRect(
                          child: FittedBox(
                            // 完整展示 2:3 背景，不再以 cover 放大并裁掉左右场景。
                            fit: BoxFit.contain,
                            alignment: showPinnedArea
                                ? Alignment.topCenter
                                // 原图中的木框中心略高于整张照片中心；在竖屏
                                // 留白内轻微下移照片，使木框本身落在屏幕视觉中心。
                                : const Alignment(0, .45),
                            child: SizedBox(
                              width: posterLayoutWidth,
                              height: posterLayoutHeight,
                              child: PosterPureFlutter(
                                topic: '${content?['topic'] ?? ''}',
                                quote: '${content?['quote'] ?? ''}',
                                author: '${content?['author'] ?? ''}',
                                note: '${content?['note'] ?? ''}',
                                quoteReference: QuoteReference.fromPosterPayload(content),
                                avatar: '${content?['avatar'] ?? content?['avatarUrl'] ?? ''}',
                                woodBgAsset: QuoteAdaptiveFrame.defaultBackgroundAsset,
                                aiFramePath: _frameImagePath,
                                animateCalligraphy: _quoteCalligraphyEnabled,
                                calligraphyStyle: _quoteCalligraphyStyle,
                                englishFontStyle: _quoteEnglishFontStyle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showPinnedArea)
            Positioned(
              left: 0,
              right: 0,
              bottom: pinnedBottomGap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                width: media.size.width,
                alignment: Alignment.center,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (Widget child, Animation<double> anim) {
                    final slide = Tween<Offset>(begin: const Offset(0, 1.0), end: Offset.zero)
                        .chain(CurveTween(curve: Curves.easeOutCubic))
                        .animate(anim);
                    return ClipRect(
                      child: SlideTransition(
                        position: slide,
                        child: FadeTransition(opacity: anim, child: child),
                      ),
                    );
                  },
                  child: _buildPinnedContent(),
                ),
              ),
            ),
// 顶栏区域（悬浮白底按钮）
          Positioned(
            top: topPad,
            left: 0,
            right: 0,
            height: kToolbarHeight,
            child: IgnorePointer(
              ignoring: false,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.all(5),
                    child: Material(
                      color: Colors.white,
                      elevation: 6,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: '打开卡片',
                        icon: const Icon(Icons.menu, color: Colors.black87),
                        onPressed: _openLeftDrawer,
                      ),
                    ),
                  ),
                  const Expanded(child: SizedBox()),
                  Padding(
                    padding: const EdgeInsets.all(5),
                    child: Material(
                      color: Colors.white,
                      elevation: 6,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: _pinnedActive ? '取消固定' : '固定名言',
                        icon: Icon(
                          _pinnedActive ? Icons.push_pin : Icons.push_pin_outlined,
                          color: Colors.black87,
                        ),
                        onPressed: _togglePin,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.all(5),
                    child: Material(
                      color: Colors.white,
                      elevation: 6,
                      shape: const CircleBorder(),
                      child: PopupMenuButton<String>(
                        tooltip: '更多操作',
                        icon: const Icon(Icons.more_vert, color: Colors.black87),
                        onSelected: _handleTopBarMenu,
                        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'frame_generate',
                            child: Row(children: [
                              Icon(_frameGenerating ? Icons.hourglass_top : Icons.auto_awesome),
                              const SizedBox(width: 8),
                              Text(_frameGenerating ? '正在生成配画' : 'AI 生成/重绘框内配画（可能收费）'),
                            ]),
                          ),
                          PopupMenuItem<String>(
                            value: 'frame_toggle',
                            child: Row(children: [
                              Icon(_frameAuto ? Icons.check_box : Icons.check_box_outline_blank),
                              const SizedBox(width: 8),
                              Text(_frameAuto ? '关闭 AI 自动配画' : '开启 AI 自动配画（可能收费）'),
                            ]),
                          ),
                          const PopupMenuItem<String>(
                            value: 'frame_explain',
                            child: Row(children: [
                              Icon(Icons.auto_stories_outlined),
                              SizedBox(width: 8),
                              Text('查看名言视觉化解释'),
                            ]),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem<String>(
                            value: 'share',
                            child: Row(
                              children: const [
                                Icon(Icons.share),
                                SizedBox(width: 8),
                                Text('分享'),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'favorite',
                            child: Row(
                              children: const [
                                Icon(Icons.favorite_border),
                                SizedBox(width: 8),
                                Text('收藏'),
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
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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
