import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'tag_picker_page.dart';
import 'diary_dao.dart';
import 'weather.dart';
import '../data/db.dart';
import 'diary_theme.dart';
import 'diary_text_controller.dart';
import 'entry_editor_page.dart';

/// Disable Android stretch-overscroll/glow for PageView.
///
/// Why: even with a full-screen Stack background, the platform overscroll
/// indicator can briefly reveal the window background as a white/black band
/// during fast swipes or when the user keeps dragging at edges.
class _NoOverscrollBehavior extends ScrollBehavior {
  const _NoOverscrollBehavior();

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

// Toggle: show inline edit icons (mic/image) on reader page
const bool kReaderInlineEdits = false;

class EntryReaderPage extends StatefulWidget {
  final int notebookId;
  final int initialEntryId;
  const EntryReaderPage({super.key, required this.notebookId, required this.initialEntryId});

  @override
  State<EntryReaderPage> createState() => _EntryReaderPageState();
}

class _EntryReaderPageState extends State<EntryReaderPage> {
  final GlobalKey _readerTextBoxKey = GlobalKey();
  final FocusNode _readerFocusNode = FocusNode();

  
void _handleDoubleTapDownReader(TapDownDetails d, TextEditingController ctrl) {
  final RenderBox? box = _readerTextBoxKey.currentContext?.findRenderObject() as RenderBox?;
  if (box == null) return;

  final Offset local = box.globalToLocal(d.globalPosition);
  final Size size = box.size;
  final String text = ctrl.text;
  final TextStyle baseStyle = Theme.of(context).textTheme.bodyLarge ?? const TextStyle(fontSize: 16);

  // 行高测量：仅用来估算点击位置是第几行。
  final TextPainter measurePainter = TextPainter(
    text: TextSpan(text: '示', style: baseStyle),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout(maxWidth: size.width);
  final double lineHeight = measurePainter.preferredLineHeight;

  // 文本为空时，双击任意位置：自动补足若干空行，让光标出现在该行最左侧。
  if (text.isEmpty) {
    double dy = local.dy.clamp(0.0, size.height);
    int extraLines = (dy / lineHeight).floor();
    if (extraLines < 0) extraLines = 0;
    final String newText = extraLines > 0 ? '\n' * extraLines : '';
    final int caretOffset = newText.length;
    ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: caretOffset),
    );
    _readerFocusNode.requestFocus();
    return;
  }

  // 使用与编辑页相同的逻辑：如果 controller 支持自定义 buildTextSpan，
  // 则复用它，从而正确计算包含图片在内的整体高度。
  final InlineSpan span;
  if (ctrl is DiaryContentController) {
    span = ctrl.buildTextSpan(
      context: context,
      style: baseStyle,
      withComposing: false,
    );
  } else {
    span = TextSpan(text: text, style: baseStyle);
  }

  final TextPainter tp = TextPainter(
    text: span,
    textDirection: TextDirection.ltr,
    maxLines: null,
  )..layout(maxWidth: size.width);

  // 计算末尾光标的位置，用于判断是否点击在现有内容下方。
  final Offset endCaret = tp.getOffsetForCaret(
    TextPosition(offset: text.length),
    Rect.zero,
  );

  double dy = local.dy;
  if (dy < 0) dy = 0;

  // 点击在现有内容下方：根据距离自动补足若干空行，让光标落在新行行首。
  if (dy > endCaret.dy + lineHeight / 2) {
    final double extraDy = dy - endCaret.dy;
    int extraLines = (extraDy / lineHeight).ceil();
    if (extraLines < 1) extraLines = 1;
    final String newText = text + ('\n' * extraLines);
    ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
    _readerFocusNode.requestFocus();
    return;
  }

  final double maxDy = endCaret.dy;
  if (dy > maxDy) dy = maxDy;

  // 根据点击位置计算所在行，再把光标移动到该行的最左侧。
  final TextPosition pos = tp.getPositionForOffset(Offset(0, dy));
  final TextRange boundary = tp.getLineBoundary(pos);
  final int start = boundary.start.clamp(0, text.length);
  ctrl.selection = TextSelection.collapsed(offset: start);
  _readerFocusNode.requestFocus();
}
	int _totalCount = 0;
	int _globalIndex = 0;

	// Absolute edge flags based on database neighbor existence.
	// These are more reliable than `_globalIndex` when sentinel pages or
	// partial loading is involved.
	bool _noNewer = false; // already at the newest (no newer entry)
	bool _noOlder = false; // already at the oldest (no older entry)
  final _dao = DiaryDao();
  final _fmt = DateFormat('yyyy年MM月dd日 HH:mm');
  final _controller = PageController(initialPage: 1);
  final List<DiaryEntry> _pages = [];
  final Map<int, DateTime> _timeById = {};
  final Map<int, int?> _weatherById = {};
  final Map<int, List<int>> _tagIdsById = {};

  final Map<int, DiaryContentController> _contentCtrls = {};
  final Map<String, AudioPlayer> _players = {};
  final Map<String, ValueNotifier<bool>> _playing = {};
  int _index = 1; // keep in sync with PageController(initialPage: 1)

  DiaryEntry? get _currentEntry {
    if (_pages.isEmpty) return null;
    if (_index <= 0 || _index > _pages.length) return null;
    final real = (_index - 1).clamp(0, _pages.length - 1);
    return _pages[real];
  }

  Future<void> _openEditorFor(DiaryEntry e) async {
    await Navigator.push<int?>(
      context,
      MaterialPageRoute(
        builder: (_) => EntryEditorPage(
          notebookId: widget.notebookId,
          entryId: e.id,
          focusAtStart: true,
          useBackground: false,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _editCurrentEntry() async {
    final e = _currentEntry;
    if (e == null) return;
    await _openEditorFor(e);
  }

  Future<void> _editTagsForCurrentEntry() async {
    final e = _currentEntry;
    if (e == null) return;
    await _pickTagsFor(e.id);
  }


  String? _bgPath;
  double _bgOpacity = 0.25;

  
  
  Future<void> _saveIfChanged(DiaryEntry e, TextEditingController c) async {
    // 内容或元数据有变化才保存
    final t = _timeById[e.id] ?? DateTime.fromMillisecondsSinceEpoch(e.entryTime);
    final wc = _weatherById[e.id] ?? e.weatherCode;
    final changed = c.text != e.content || t.millisecondsSinceEpoch != e.entryTime || wc != e.weatherCode;
    if (!changed) return;

    final preview = _preview(c.text);
    final w = weatherByCode(wc);
    final updated = DiaryEntry(
      id: e.id,
      notebookId: e.notebookId,
      entryTime: t.millisecondsSinceEpoch,
      weatherCode: wc,
      weatherName: wc == null ? null : w.name,
      moodName: e.moodName,
      moodIcon: e.moodIcon,
      content: c.text,
      preview: preview,
      starred: e.starred,
    );
    final id = await _dao.upsertEntry(updated);
    final tags = _tagIdsById[e.id] ?? <int>[];
    await _dao.setTagsForEntry(id, tags);
    await _dao.touchNotebook(e.notebookId);
  }


  Future<void> _saveCurrentIfChanged() async {
    if (_pages.isEmpty) return;
    final i = _index;
    if (i <= 0 || i > _pages.length) return;
    final real = (i - 1).clamp(0, _pages.length - 1);
    final e = _pages[real];
          // 初始化页内可编辑元数据（时间/天气/标签）
          _timeById.putIfAbsent(e.id, () => DateTime.fromMillisecondsSinceEpoch(e.entryTime));
          _weatherById.putIfAbsent(e.id, () => e.weatherCode);
          if (!_tagIdsById.containsKey(e.id)) {
            _dao.tagsForEntry(e.id).then((list) {
              if (!mounted) return;
              setState(() { _tagIdsById[e.id] = list.map((t) => t.id).toList(); });
            });
          }

    final c = _contentCtrls[e.id];
    if (c != null) {
      await _saveIfChanged(e, c);
    }
  }

  String _preview(String content) {
    final lines = content.split(RegExp(r'\r?\n'));
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('[图片]') || line.startsWith('[语音]')) continue;
      return line.length > 50 ? line.substring(0, 50) : line;
    }
    return '（空白日记）';
  }
@override
  void dispose() {
    for (final p in _players.values) {
      try { p.dispose(); } catch (_) {}
    }
    for (final n in _playing.values) {
      try { n.dispose(); } catch (_) {}
    }
    super.dispose();
  }


  Future<void> _precacheBg() async {
    final p = _bgPath;
    if (p == null || p.isEmpty) return;
    try {
      final f = File(p);
      if (!f.existsSync()) return;
      final provider = FileImage(f);
      if (!mounted) return;
      await precacheImage(provider, context);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
    WidgetsBinding.instance.addPostFrameCallback((_)=>_precacheBg());
  }

  Future<void> _bootstrap() async {
    // 背景样式优先使用内存缓存，避免阅读页先出现白底再刷新出背景图
    final theme = DiaryTheme.current;
    _bgPath = theme.imagePath;
    _bgOpacity = theme.opacity;

    final db = await AppDatabase.instance();
    try {
      final rows = await db.rawQuery(
        "SELECT * FROM configs "
        "WHERE (diary_bg_image IS NOT NULL AND diary_bg_image != '') "
        "   OR diary_bg_opacity IS NOT NULL "
        "   OR (diary_pin IS NOT NULL AND diary_pin != '') "
        "ORDER BY id DESC LIMIT 1"
      );
      if (rows.isNotEmpty) {
        _bgPath = (rows.first['diary_bg_image'] ?? '') as String?;
        final op = rows.first['diary_bg_opacity'];
        if (op != null) _bgOpacity = double.tryParse(op.toString()) ?? _bgOpacity;
      }
    } catch (_) {}
    final e = await _dao.getEntry(widget.initialEntryId);
    final total = await _dao.countEntries(widget.notebookId);
    final pos = await _dao.positionOfEntry(widget.notebookId, widget.initialEntryId) ?? 0;

    // Determine absolute edges by checking database neighbors.
    // This avoids "edge swipe lock not working" when sentinel pages are used.
    bool noNewer = false;
    bool noOlder = false;
    if (e != null) {
      try {
        final newer = await _dao.neighbor(notebookId: widget.notebookId, cur: e, newer: true);
        final older = await _dao.neighbor(notebookId: widget.notebookId, cur: e, newer: false);
        noNewer = newer == null;
        noOlder = older == null;
      } catch (_) {}
    }

    if (!mounted) return;
    if (e != null) {
      setState(() {
        _pages.add(e);
        _totalCount = total;
        _globalIndex = pos;
        // Always drive edge-locking off the absolute index to avoid
        // "edge disable not taking effect" when the loaded window changes.
        _noNewer = (total > 0 && pos <= 0) || noNewer;
        _noOlder = (total > 0 && pos >= total - 1) || noOlder;
      });
    }
  }
  Widget _bgWrap(Widget child) {
    // Always paint a stable paper-like base layer first.
    // This prevents BOTH white-flash and black-flash when the page (or the
    // system status bar area) is momentarily transparent during PageView drags.
    // 日记阅读页面底色策略：
    // - 若未配置背景图：统一使用纯白底色，和列表/编辑页保持一致；
    // - 若配置了背景图：仍然先绘制一层稳定底色，避免透明时出现黑色闪烁，
    //   然后再叠加背景图片的不透明度效果。
    Color baseBg = Colors.white;

    final bg = _bgPath;
    File? f;
    var ok = false;
    if (bg != null && bg.isNotEmpty) {
      try {
        f = File(bg);
        ok = f.existsSync();
      } catch (_) {
        ok = false;
      }
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: baseBg),
        if (ok && f != null)
          Opacity(
            opacity: (1.0 - _bgOpacity).clamp(0.0, 1.0),
            child: Image.file(
              f,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
        child,
      ],
    );
  }

  
  /// Ensure there is a newer (more recent) entry loaded at the front of
  /// the [_pages] list.  Returns true if a new entry was added.
  Future<bool?> _ensureNewer() async {
    if (_pages.isEmpty) return false;
    final first = _pages.first;
    final next = await _dao.neighbor(notebookId: widget.notebookId, cur: first, newer: true);
    if (next == null) {
      if (mounted) setState(() { _noNewer = true; });
      return false;
    }
    setState(() { _pages.insert(0, next); _noNewer = false; });
    return true;
  }

  /// Ensure there is an older entry loaded at the end of the [_pages]
  /// list.  Returns true if a new entry was added.  Does not perform
  /// any PageController jumping; callers should handle navigation.
  Future<bool?> _ensureOlder() async {
    if (_pages.isEmpty) return false;
    final last = _pages.last;
    final next = await _dao.neighbor(notebookId: widget.notebookId, cur: last, newer: false);
    if (next == null) {
      if (mounted) setState(() { _noOlder = true; });
      return false;
    }
    setState(() { _pages.add(next); _noOlder = false; });
    return true;
  }

  
Widget _buildContent(BuildContext context, String content) {
  final lines = content.split(RegExp(r'\r?\n'));
  final widgets = <Widget>[];
  final imgReg = RegExp(r'^\[图片\]\s*(.+)$');
  final audioReg = RegExp(r'^\[语音\]\s*(.+)$');

  for (final raw in lines) {
    final line = raw.trimRight();
    if (line.isEmpty) { continue; }

    final m1 = imgReg.firstMatch(line);
    final m2 = audioReg.firstMatch(line);

    if (m1 != null) {
      final payload = m1.group(1)!.trim();
String path = payload;
double wf = 1.0;
final parts = payload.split('|w=');
if (parts.isNotEmpty) {
  path = parts.first.trim();
  if (parts.length > 1) {
    final v = double.tryParse(parts[1].trim());
    if (v != null && v >= 0.3 && v <= 1.0) wf = v;
  }
}
            final f = File(path);
      if (f.existsSync()) {
        widgets.add(Padding(
          padding: EdgeInsets.zero,
          child: LayoutBuilder(
  builder: (context, constraints) {
    final ww = constraints.maxWidth;
    final wff = (wf < 0.3) ? 0.3 : (wf > 1.0 ? 1.0 : wf);
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: wff,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            f,
            fit: BoxFit.fitWidth,
          ),
        ),
      ),
    );
  },
),
        ));
      } else {
        widgets.add(const SizedBox.shrink());
}
    } else if (m2 != null) {
      final path = m2.group(1)!;
      final p = _players.putIfAbsent(path, () => AudioPlayer());
      final playing = _playing.putIfAbsent(path, () => ValueNotifier<bool>(false));
      widgets.add(_InlineAudioTile(path: path, player: p, playing: playing));
    } else {
      widgets.add(Text(line, style: Theme.of(context).textTheme.bodyLarge));
    }
  }

  
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
}

  // === Helpers to insert attachments into the inline marker model ===
  void _insertMarkerAtTopLines(TextEditingController ctrl, String marker, String path, {String? extra}) {
    final base = ctrl.text;
    final lines = base.split(RegExp(r'\r?\n'));
    if (lines.isEmpty) { lines.add(''); }
    // Insert as early as possible: line 1 if empty, otherwise line 2; then 4, 6, ...
    int target = lines.isNotEmpty && lines[0].trim().isNotEmpty ? 1 : 0;
    while (true) {
      if (target >= lines.length) {
        while (lines.length <= target) { lines.add(''); }
      }
      if (lines[target].trim().isEmpty) break;
      target += 2;
    }
    lines.insert(target, '[$marker] ' + path + (extra ?? ''));
    // Trim trailing empty lines to reduce extra vertical space in TextField
    while (lines.isNotEmpty && lines.last.trim().isEmpty && lines.length > target + 1) {
      lines.removeLast();
    }
    final newText = lines.join('\n');
    ctrl.text = newText;
    // Put cursor to the start to avoid showing the path as typed content.
    ctrl.selection = const TextSelection.collapsed(offset: 0);
    if (mounted) setState(() {});
    if (mounted) _precacheBg();
  }

  Future<void> _insertImageFor(TextEditingController ctrl) async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image);
    if (res == null || res.files.isEmpty) return;
    final path = res.files.first.path;
    if (path == null) return;
    _insertMarkerAtTopLines(ctrl, '图片', path, extra: '|w=0.50');
  }

  Future<void> _insertAudioFor(TextEditingController ctrl) async {
    final res = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (res == null || res.files.isEmpty) return;
    final path = res.files.first.path;
    if (path == null) return;
    _insertMarkerAtTopLines(ctrl, '语音', path);
  }

  // 播放控制：获取文本中的第一条 [语音] 路径
  String? _firstAudioPath(String text) {
    final m = RegExp(r'^\[语音\]\s*(.+)\$', multiLine: true).firstMatch(text);
    return m == null ? null : m.group(1);
  }

  // 在工具栏（与麦克风同行）提供一个“播放/暂停”按钮，播放当前页第一条语音
  Future<void> _togglePlayFirstAudioFor(TextEditingController ctrl) async {
    final p = _firstAudioPath(ctrl.text);
    if (p == null || p.isEmpty) return;
    final player = _players[p] ?? AudioPlayer();
    _players[p] = player;
    final flag = _playing[p] ?? ValueNotifier<bool>(false);
    _playing[p] = flag;
    try {
      if (flag.value) {
        await player.pause();
        flag.value = false;
      } else {
        await player.play(DeviceFileSource(p));
        flag.value = true;
      }
    } catch (_) {
      flag.value = false;
    }
    if (mounted) setState(() {});
    if (mounted) _precacheBg();
  }


  Future<void> _pickTagsFor(int entryId) async {
    final initial = _tagIdsById[entryId] ?? <int>[];
    final picked = await Navigator.push<List<int>>(context, MaterialPageRoute(
      builder: (_) => TagPickerPage(dao: _dao, initialSelected: initial),
    ));
    if (picked != null) {
      setState(() { _tagIdsById[entryId] = picked; });
    }
  }

Widget _attachmentsPreviewFor(String text) {
    final lines = text.split(RegExp(r'\r?\n'));
    final widgets = <Widget>[];
    final imgReg = RegExp(r'^\[图片\]\s*(.+)$');
    final audioReg = RegExp(r'^\[语音\]\s*(.+)$');
    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.isEmpty) continue;
      final m1 = imgReg.firstMatch(line);
      final m2 = audioReg.firstMatch(line);
            if (m1 != null) {
        // 图片在正文中以内联方式展示，这里不再重复渲染。
        continue;
      } else if (m2 != null) {
        final path = m2.group(1)!;
        final p = _players.putIfAbsent(path, () => AudioPlayer());
        final playing = _playing.putIfAbsent(path, () => ValueNotifier<bool>(false));
        widgets.add(_InlineAudioTile(path: path, player: p, playing: playing));
      }
    }
    if (widgets.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }
@override
  Widget build(BuildContext context) {
    const Color _mintBg = Color(0xFFDDEFE6); // 薄荷绿
    final bool _hasDiaryBgImage = (_bgPath != null && _bgPath!.isNotEmpty);
    final Color _navBarColor = _hasDiaryBgImage ? _mintBg : Colors.white;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // NOTE: don't use `const` here because `_paperBg` is a local constant.
      // Keeping this non-const avoids any accidental const-evaluation issues.
      value: SystemUiOverlayStyle(
        // Make status bar transparent so the diary background (image/paper)
        // can extend behind it.
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: _navBarColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: WillPopScope(
      onWillPop: () async {
        await _saveCurrentIfChanged();
        try { Navigator.pop(context, true); } catch (_) {}
        return false;
      },
      child: _bgWrap(Scaffold(
        backgroundColor: _mintBg,
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: const Text('日记阅读'),
          // 标题整体向左微移约 5dp，视觉上更贴近返回箭头。
          titleSpacing: 11.0,
          centerTitle: false,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          actions: [
            // 编辑按钮：在标题右侧、标签按钮左侧。
            IconButton(
              tooltip: '编辑',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _editCurrentEntry,
            ),
            IconButton(
              tooltip: '标签',
              icon: const Icon(Icons.label_outline),
              onPressed: _editTagsForCurrentEntry,
            ),
          ],
          // Fix: ensure the Android status bar icons are visible.
          // With a transparent app bar, Flutter may choose a light overlay style
          // which makes icons disappear on a light (white/paper) background.
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
        body: SafeArea(
          // We intentionally disable top padding so that the background image
          // can extend behind the system status bar.  Without this, the
          // image stops at the safe area and leaves a blank band at the top.
          top: false,
          child: NotificationListener<ScrollNotification>(
            // IMPORTANT:
            // At the very first / very last entry, Android can still allow a
            // tiny overscroll drag. With our transparent backgrounds this can
            // reveal a white strip on the left/right.
            //
            // We hard-stop any overscroll at global edges by snapping back to
            // the current page immediately.
            onNotification: (n) {
              if (n is OverscrollNotification) {
                final atStart = _totalCount > 0 && _globalIndex <= 0;
                final atEnd = _totalCount > 0 && _globalIndex >= _totalCount - 1;
                if (atStart || atEnd) {
                  if (_controller.hasClients) {
                    // Defer to the next frame to avoid re-entrancy.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _controller.jumpToPage(_index);
                    });
                  }
                  return true;
                }
              }
              return false;
            },
            child: ScrollConfiguration(
              behavior: const _NoOverscrollBehavior(),
              child: PageView.builder(
                key: const PageStorageKey<String>('entry_reader_pv'),
              physics: EdgeLockPagePhysics(
                // Disable edge-direction drag ONLY when the database confirms
                // there is no neighbor beyond the current absolute edge.
                lockToStart: _noNewer,
                lockToEnd: _noOlder,
                // We use sentinel pages (real pages are 1.._pages.length).
                realStartPage: 1,
                realEndPage: _pages.length,
                parent: const ClampingScrollPhysics(),
              ),
                controller: _controller,
                itemCount: _pages.length + 2,
                onPageChanged: (i) async {
          // Save the current page before navigation
          if (_pages.isNotEmpty) {
            final prev = _index;
            if (prev > 0 && prev <= _pages.length) {
              final real = (prev - 1).clamp(0, _pages.length - 1);
              final ePrev = _pages[real];
              final cPrev = _contentCtrls[ePrev.id];
              if (cPrev != null) {
                await _saveIfChanged(ePrev, cPrev);
              }
            }
          }
          // Sentinel: swiping right to newer entries
          if (i == 0) {
            final ok = await _ensureNewer();
            if (ok == true) {
              setState(() {
                _index = 1;
                _globalIndex = (_globalIndex - 1).clamp(0, _totalCount - 1);
                _noNewer = (_totalCount > 0 && _globalIndex <= 0);
                _noOlder = (_totalCount > 0 && _globalIndex >= _totalCount - 1);
              });
              if (mounted) _controller.jumpToPage(1);
            } else {
              if (mounted) _controller.jumpToPage(1);
            }
            return;
          }
          // Sentinel: swiping left to older entries
          if (i == _pages.length + 1) {
            final ok = await _ensureOlder();
            if (ok == true) {
              setState(() {
                _index = _pages.length;
                _globalIndex = (_globalIndex + 1).clamp(0, _totalCount - 1);
                _noNewer = (_totalCount > 0 && _globalIndex <= 0);
                _noOlder = (_totalCount > 0 && _globalIndex >= _totalCount - 1);
              });
              if (mounted) _controller.jumpToPage(_pages.length);
            } else {
              if (mounted) _controller.jumpToPage(_pages.length);
            }
            return;
          }
          // Regular page change within loaded pages
          final prev = _index;
          setState(() {
            _index = i;
            _globalIndex = (_globalIndex + (i - prev)).clamp(0, _totalCount - 1);
            _noNewer = (_totalCount > 0 && _globalIndex <= 0);
            _noOlder = (_totalCount > 0 && _globalIndex >= _totalCount - 1);
          });
                },
                itemBuilder: (context, i) {
          // Map PageView index (with 2 sentinels) to _pages index.
          // IMPORTANT:
          // We keep the two "sentinel" pages (index 0 and last) for lazy loading,
          // but when the user is already at the very first / very last entry,
          // dragging to the sentinel would reveal a blank (white) page edge.
          // Instead of returning an empty widget, we render a non-interactive
          // duplicate of the nearest real page so that *no white gap can appear*
          // even during a partial drag.
          if (_pages.isEmpty) return const SizedBox.shrink();
          final bool isEdgeSentinel = (i == 0 || i == _pages.length + 1);
          final int real = isEdgeSentinel
              ? (i == 0 ? 0 : (_pages.length - 1))
              : (i - 1).clamp(0, _pages.length - 1);
          final e = _pages[real];
          final w = weatherByCode(e.weatherCode);
          // Obtain or create a DiaryContentController for this entry.  If a
          // controller already exists, ensure its text stays in sync with
          // the entry content so that swiping between pages refreshes
          // properly.  When an entry is revisited, update the controller
          // instead of reusing stale content.
          DiaryContentController? ctrl = _contentCtrls[e.id];
          if (ctrl == null) {
            ctrl = DiaryContentController(text: e.content);
            _contentCtrls[e.id] = ctrl;
          } else {
            if (ctrl.text != e.content) {
              ctrl.text = e.content;
            }
          }
          final page = Padding(
            key: ValueKey(isEdgeSentinel ? 'sentinel_${i}_${e.id}' : e.id),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: Stack(
              children: [
                Card(
                  color: Colors.transparent,
                  elevation: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                DateTime base = _timeById[e.id] ?? DateTime.fromMillisecondsSinceEpoch(e.entryTime);
                                final date = await showDatePicker(context: context, initialDate: base, firstDate: DateTime(2000), lastDate: DateTime(2100));
                                if (date != null) {
                                  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(base));
                                  final picked = DateTime(date.year, date.month, date.day, (time?.hour ?? base.hour), (time?.minute ?? base.minute));
                                  setState(() { _timeById[e.id] = picked; });
                                }
                              },
                              child: Row(
                                children: [
                                  const Icon(Icons.schedule, size: 18),
                                  const SizedBox(width: 6),
                                  Text(_fmt.format((_timeById[e.id] ?? DateTime.fromMillisecondsSinceEpoch(e.entryTime)))),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 使用 Flexible 包裹天气选择器，限制宽度防止与时间文字重叠
                          Flexible(
                            flex: 0,
                            child: DropdownButton<int>(
                              value: _weatherById[e.id] ?? e.weatherCode,
                              hint: const Text('天气'),
                              items: weatherOptions
                                  .map((w) => DropdownMenuItem<int>(
                                        value: w.code,
                                        child: Row(
                                          children: [
                                            Icon(w.icon, size: 18),
                                            const SizedBox(width: 6),
                                            Text(w.name),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(() { _weatherById[e.id] = v; }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if ((e.moodIcon ?? '').isNotEmpty || (e.moodName ?? '').isNotEmpty)
                            Flexible(
                              flex: 0,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if ((e.moodIcon ?? '').isNotEmpty)
                                    Text(e.moodIcon!, style: const TextStyle(fontSize: 18)),
                                  if ((e.moodIcon ?? '').isNotEmpty && (e.moodName ?? '').isNotEmpty)
                                    const SizedBox(width: 4),
                                  if ((e.moodName ?? '').isNotEmpty)
                                    Text(e.moodName!),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                // `ctrl` is a DiaryContentController which extends TextEditingController.
                                // Cast it to non-null when passing to the handler to satisfy the type system.
                                onTapDown: (d) => _handleDoubleTapDownReader(d, ctrl!),
                                onDoubleTapDown: (d) => _handleDoubleTapDownReader(d, ctrl!),
                                child: Container(
                                  key: _readerTextBoxKey,
                                  alignment: Alignment.topLeft,
                                  width: double.infinity,
                                  constraints: BoxConstraints(
                                    minHeight: MediaQuery.of(context).size.height,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      TextField(
                                        controller: ctrl,
                                        focusNode: _readerFocusNode,
                                        maxLines: null,
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          isCollapsed: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        onChanged: (_) {
                                          // Refresh inline previews (图片/语音) immediately.
                                          if (mounted) setState(() {});
    if (mounted) _precacheBg();
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                      _attachmentsPreviewFor(ctrl.text),
                                    ],
                                  ),
                                ),
                              ),
                            ],
),
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    minimum: EdgeInsets.zero,
                    child: Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Wrap(
                              spacing: 8,
                              children: (_tagIdsById[e.id] ?? const <int>[]).map((id) => Chip(
                                label: Text('标签#' + id.toString()),
                              )).toList(),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '插入语音',
                          // Cast ctrl to non-null when invoking insertion helpers
                          onPressed: () => _insertAudioFor(ctrl!),
                          icon: const Icon(Icons.mic_none),
                        ),
                        IconButton(
                          tooltip: '插入图片',
                          // Cast ctrl to non-null when invoking insertion helpers
                          onPressed: () => _insertImageFor(ctrl!),
                          icon: const Icon(Icons.image_outlined),
                        ),
                        OutlinedButton.icon(
  onPressed: () async {
    await Navigator.push<int?>(
      context,
      MaterialPageRoute(
        builder: (_) => EntryEditorPage(notebookId: widget.notebookId, entryId: e.id),
      ),
    );
    if (!mounted) return;
    setState(() {}); // 返回后刷新UI（必要时可进一步拉取最新内容）
  },
  icon: const Icon(Icons.edit_outlined),
  label: const Text('编辑'),
),

OutlinedButton.icon(
                          onPressed: () => _pickTagsFor(e.id),
                          icon: const Icon(Icons.label_outline),
                          label: const Text('标签'),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: SafeArea(
                    top: false,
                    minimum: EdgeInsets.zero,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _hasDiaryBgImage ? Colors.transparent : Colors.black54,
                      ),
                      child: Text(
                        '${_globalIndex + 1}/$_totalCount',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );

          // Sentinels are only used for edge-drag/loading; disable interaction.
          if (isEdgeSentinel) {
            return IgnorePointer(ignoring: true, child: page);
          }
          return page;

	                },
	              ), // PageView.builder
	            ), // ScrollConfiguration
	          ), // NotificationListener
	        ), // SafeArea
	      )))); //Scaffold + _bgWrap + WillPopScope + AnnotatedRegion;
  }
}

class _InlineAudioTile extends StatelessWidget {
  final String path;
  final AudioPlayer player;
  final ValueNotifier<bool> playing;
  const _InlineAudioTile({required this.path, required this.player, required this.playing});

  Future<void> _toggle(BuildContext context, bool isPlaying) async {
    try {
      if (isPlaying) {
        await player.pause();
        playing.value = false;
      } else {
        await player.play(DeviceFileSource(path));
        playing.value = true;
      }
    } catch (_) {
      playing.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: playing,
      builder: (context, isPlaying, _) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: IconButton(
          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
          onPressed: () => _toggle(context, isPlaying),
        ),
        title: const Text('语音'),
        subtitle: const Text('点击播放'),
      ),
    );
  }
}


class EdgeLockPagePhysics extends PageScrollPhysics {
  final bool lockToStart;
  final bool lockToEnd;
  final int realStartPage;
  final int realEndPage;

  const EdgeLockPagePhysics({
    required this.lockToStart,
    required this.lockToEnd,
    required this.realStartPage,
    required this.realEndPage,
    ScrollPhysics? parent,
  }) : super(parent: parent);

  @override
  EdgeLockPagePhysics applyTo(ScrollPhysics? ancestor) => EdgeLockPagePhysics(
        lockToStart: lockToStart,
        lockToEnd: lockToEnd,
        realStartPage: realStartPage,
        realEndPage: realEndPage,
        parent: buildParent(ancestor),
      );

  static const double _eps = 0.0;

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    final double vp = position.viewportDimension;
    final double startPx = realStartPage * vp;
    final double endPx   = realEndPage   * vp;

    if (lockToStart && position.pixels <= startPx + _eps && offset > 0) {
      return 0.0;
    }
    if (lockToEnd && position.pixels >= endPx - _eps && offset < 0) {
      return 0.0;
    }
    return super.applyPhysicsToUserOffset(position, offset);
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final double vp = position.viewportDimension;
    final double startPx = realStartPage * vp;
    final double endPx   = realEndPage   * vp;

    if (lockToStart && position.pixels <= startPx + _eps && velocity > 0) {
      return null;
    }
    if (lockToEnd && position.pixels >= endPx - _eps && velocity < 0) {
      return null;
    }
    return super.createBallisticSimulation(position, velocity);
  }
}