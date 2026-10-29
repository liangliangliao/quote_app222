
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
import '../services/quote_author_signature_service.dart';
import '../data/dao.dart';
import '../widgets/quote_home_scene.dart';
import '../widgets/quote_library_sheet.dart';
import '../widgets/journey_design.dart';
import '../services/quote_library_store.dart';
import '../utils/debug_logger.dart';
import 'package:quote_app/services/native_guard.dart';



  bool isShortTopic(String s) {
    try { return s.runes.length < 15; } catch (_) { return s.length < 15; }
  }
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.signatures});
  final QuoteAuthorSignatureService? signatures;
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
  late final _signatures = widget.signatures ?? QuoteAuthorSignatureService.shared;
  String _signatureAuthor = '', _originalAuthorName = '';
  int _signatureRevision = 0;

  Future<void> _resolveOriginalAuthor(Map<String, dynamic> payload) async {
    final author = QuoteAuthorSignatureService.authorName((payload['author'] ?? '').toString());
    final supplied = (payload['author_original_name'] ?? '').toString();
    final revision = ++_signatureRevision;
    final immediate = _signatures.displayName(author, originalName: supplied) ?? '';
    if (mounted && (_signatureAuthor != author || _originalAuthorName != immediate)) {
      setState(() { _signatureAuthor = author; _originalAuthorName = immediate; });
    }
    final name = await _signatures.resolve(author, originalName: supplied);
    if (!mounted || revision != _signatureRevision || name == null ||
        _todayData == null || QuoteLibraryStore.identity(_todayData!) != QuoteLibraryStore.identity(payload)) return;
    if (_originalAuthorName != name) {
      setState(() => _originalAuthorName = name);
    }
    _todayData!['author_original_name'] = name;
    for (final row in _readingHistory) {
      if (QuoteLibraryStore.identity(row) == QuoteLibraryStore.identity(payload)) row['author_original_name'] = name;
    }
  }

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
    unawaited(_resolveOriginalAuthor(payload));
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
  bool _favoriteBusy = false, _nextBusy = false;
  int _favoriteGeneration = 0, _readingIndex = 0;
  final _readingHistory = <Map<String, dynamic>>[];

  bool _liked = false;
  bool _notifAsked = false;
  final Set<String> _avatarRepairAttempted = <String>{};

  void _openLeftDrawer() {
    try {
      final scaffold = Scaffold.maybeOf(context);
      scaffold?.openDrawer();
    } catch (_) {}
  }

  void _handleTopBarMenu(String value) async {
    switch (value) {
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

    // 每次从冷启动进入首页时，尝试弹出心情卡片
  }

  void _onBus() { _load(); }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SimpleBus.homeTick.removeListener(_onBus);
    QuoteCalligraphySettings.changeTick
        .removeListener(_onCalligraphyPreferenceChanged);
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
              'author': '老子',
              'source': '道德经',
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
        _requestNotifAfterFirstFrame();
      } else if (mapEquals(previousRow, latest) && _todayData != null) {
        // Keep the current poster selected from the library
        // when a tab switch or duplicate event carries no new database row.
        unawaited(_resolveOriginalAuthor(_todayData!));
        _requestNotifAfterFirstFrame();
      } else {
        _latestRow = latest;
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
        final payload = <String, dynamic>{
          'topic': (latest['theme'] ?? latest['topic'] ?? '').toString(),
          'quote': (latest['content'] ?? latest['quote'] ?? '').toString(),
          'author': authorName,
          'author_original_name': (latest['author_original_name'] ?? '').toString(),
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
        _requestNotifAfterFirstFrame();
      }
    } catch (e) {
      _latestRow = previousRow;
      await DLog.e('HOME', '查询异常：注入兜底内容；err=$e');
      // 异常也不擦掉已显示的随包兜底名言。
      _requestNotifAfterFirstFrame();
    }
  }

  Future<void> _copyLatest() async {
    final quote = (_todayData?['quote'] ?? '').toString().trim();
    final originalAuthor = (_todayData?['author_original_name'] ?? '').toString().trim();
    final author = originalAuthor.isNotEmpty
        ? originalAuthor : (_todayData?['author'] ?? '').toString().trim();
    final source = (_todayData?['source'] ?? '').toString().trim();
    final text = [quote, author, if (source.isNotEmpty) '《$source》']
        .where((value) => value.isNotEmpty).join('\n\n');
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('名言已复制，可粘贴分享'), behavior: SnackBarBehavior.floating, margin: const EdgeInsets.fromLTRB(18, 0, 18, 145)));
  }

  Future<void> _displayLibraryQuote(Map<String, dynamic> row) async {
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
    final payload = <String, dynamic>{
      'topic': theme,
      'quote': quote,
      'author': authorName,
      'author_original_name': (row['author_original_name'] ?? '').toString(),
      'source': source,
      'note': note,
      'avatarUrl': avatarUrl,
    };
    if (!mounted) return;
    setState(() {
      _todayData = payload;
    });
    unawaited(_activateFrame(payload));
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
        await _displayLibraryQuote(row);
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
    if (mounted && row != null) await _displayLibraryQuote(row);
  }

  void _readHistoryAt(int index) {
    if (index < 0 || index >= _readingHistory.length) return;
    final payload = _readingHistory[index];
    setState(() => _todayData = payload);
    unawaited(_activateFrame(payload));
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
    final authorName = QuoteAuthorSignatureService.authorName('${content['author'] ?? ''}');
    final originalAuthor = _signatureAuthor == authorName
        ? _originalAuthorName
        : (_signatures.displayName(authorName,
            originalName: '${content['author_original_name'] ?? ''}') ?? '');
    return Scaffold(
      backgroundColor: const Color(0xfff7f4ed),
      body: QuoteHomeScene(
        poster: PosterPureFlutter(
          topic: '${content['topic'] ?? ''}',
          quote: '${content['quote'] ?? ''}',
          author: '${content['author'] ?? ''}',
          originalAuthor: originalAuthor,
          signaturePending: originalAuthor.isEmpty && authorName.isNotEmpty,
          source: '${content['source'] ?? ''}',
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
        onNext: _nextQuote,
        onFavorite: _toggleFavorite,
        onCategories: _openLibrary,
        onShare: _copyLatest,
        favorite: _fav,
        nextBusy: _nextBusy,
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
