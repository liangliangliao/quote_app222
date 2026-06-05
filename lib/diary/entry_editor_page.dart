import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:characters/characters.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as pth;

import '../data/db.dart';
import 'diary_theme.dart';
import 'diary_dao.dart';
import 'tag_picker_page.dart';
import 'weather.dart';
import 'diary_text_controller.dart';

// ===== 块级编辑器（更接近三星备忘录的体验）=====
// 说明：
// - 正文内部不再用单个 TextField + WidgetSpan 表示图片/语音；
// - 改为“文本块/图片块/语音块”的列表渲染，避免图片随回车/退格在大段空行里上下漂移。
abstract class _EditorBlock {
  const _EditorBlock();
}

class _TextBlock extends _EditorBlock {
  final TextEditingController controller;
  final FocusNode focusNode;
  _TextBlock(String text)
      : controller = TextEditingController(text: text),
        focusNode = FocusNode();
}

class _ImageBlock extends _EditorBlock {
  final String path;
  // widthFactor: 0.3 ~ 1.0, controls how wide the image occupies in the editor/reader (Samsung Notes-like resize).
  final double widthFactor;
  const _ImageBlock(this.path, {this.widthFactor = 1.0});
}

class _AudioBlock extends _EditorBlock {
  final String path;
  const _AudioBlock(this.path);
}

class EntryEditorPage extends StatefulWidget {
  final int notebookId;
  final int? entryId;
  // 从阅读页进入编辑时，是否强制在首行自动聚焦并弹出键盘。
  final bool focusAtStart;
  // Whether this page should paint its own diary background. When this
  // page is embedded in EntryEditorPagerPage, the pager already paints
  // the shared background image so we can turn this off to avoid
  // ghosting/double backgrounds.
  final bool useBackground;
  // Whether this page should intercept back navigation and auto-save.
  // When embedded in EntryEditorPagerPage, set to false so the pager controls saving/pop.
  final bool handleWillPop;


  const EntryEditorPage({super.key, required this.notebookId, this.entryId, this.focusAtStart = false, this.useBackground = true, this.handleWillPop = true});

  @override
  State<EntryEditorPage> createState() => EntryEditorPageState();
}

class EntryEditorPageState extends State<EntryEditorPage> {
  /// 将从文件选择器选中的临时文件复制到应用私有目录，返回新的可长期访问的绝对路径。
  Future<String> _persistAttachment(String srcPath, {required String subdir, String? ext}) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(pth.join(base.path, 'attachments', subdir));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final String name = '${DateTime.now().millisecondsSinceEpoch}${ext ?? pth.extension(srcPath)}';
    final String dst = pth.join(dir.path, name);
    try {
      await File(srcPath).copy(dst);
      return dst;
    } catch (_) {
      // 回退方案：若复制失败，仍然返回原路径以避免数据丢失。
      return srcPath;
    }
  }

  // 根据屏幕高度自适应计算底部“点击补行区域”的高度，避免固定 80px 带来的
  // 小屏过高/大屏过矮的问题。限定在 [48, 120] 区间。
  double get _bottomTapAreaHeight {
    final h = MediaQuery.of(context).size.height;
    final v = (h * 0.06).clamp(48.0, 120.0);
    return v;
  }

  final _dao = DiaryDao();
  final _fmt = DateFormat('yyyy年MM月dd日 HH:mm');
  final _textCtrl = DiaryContentController();
  final List<_EditorBlock> _blocks = <_EditorBlock>[];
  int _activeTextBlock = 0; // 当前获得焦点的文本块索引
  int? _selectedBlockIndex; // 选中的图片/语音块索引（用于显示删除按钮）


  int _entryId = 0;
  DateTime _time = DateTime.now();
  int? _weatherCode;
  String? _moodName;
  String? _moodIcon;
  bool _starred = false;

  bool _dirty = false;

  // Edit mode: existing entries open in read-only mode by default.
  // New entries (entryId == null) start in edit mode.
  bool _editMode = false;

  // AppBar title for existing entries: first non-empty text line (full line).
  // Calculated once when loading the entry; avoids rebuilding on every keystroke.
  String? _cachedTitle;

  // Audio players and playing state for audio blocks.  Each audio path has
  // its own AudioPlayer and playing notifier so multiple audios can be
  // independently controlled.  The player resources are disposed in
  // dispose().
  final Map<String, AudioPlayer> _audioPlayers = {};
  final Map<String, ValueNotifier<bool>> _audioPlaying = {};

  String _lastText = '';
  TextSelection _lastSel = const TextSelection.collapsed(offset: 0);


  String? _bgPath;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _contentScrollController = ScrollController();
  bool _contentScrollable = false;

  final GlobalKey _textBoxKey = GlobalKey();

  double _bgOpacity = 0.25;

  final List<int> _tagIds = [];
  final Map<int, String> _tagNameById = {};

  /// Returns the first audio attachment path in the current editor blocks.
  /// Used by the bottom toolbar play/pause button (Samsung Notes-like).
  String? _firstAudioPath() {
    for (final b in _blocks) {
      if (b is _AudioBlock) return b.path;
    }
    // Fallback: parse from raw text (in case blocks are not yet initialized).
    final m = RegExp(r'^\[语音\]\s*(.+)$', multiLine: true).firstMatch(_textCtrl.text);
    return m?.group(1)?.trim();
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

  void _updateContentScrollPhysics() {
    if (!_contentScrollController.hasClients) return;

    final position = _contentScrollController.position;
    if (!position.hasContentDimensions) return;

    // 方案说明：
    // 1）优先按照 ScrollPosition 的 extentTotal / extentInside 判断内容是否超出可见区域；
    // 2）同时结合正文编辑区域（_textBoxKey 对应的 RenderBox）实际高度做一道“兜底”判断，
    //    只有在两者都认为“内容确实超出一屏”时，才允许竖向滚动，从而避免一行文字也能
    //    滚出一大段空白的问题。
    final double extentInside = position.extentInside;
    final double extentTotal = position.extentTotal;
    double overflow = extentTotal - extentInside;

    // 如果拿得到正文区域的 RenderBox，则用它的高度再算一遍溢出量，取两者中的较小值，
    // 这样可以尽可能“保守”地认定是否需要滚动。
    final BuildContext? ctx = _textBoxKey.currentContext;
    if (ctx != null) {
      final RenderBox? box = ctx.findRenderObject() as RenderBox?;
      if (box != null) {
        double contentHeight = box.size.height;
        final double viewportHeight = position.viewportDimension;

        // 对于非空文档，我们在块编辑器的最底部额外插入了一个 80px 的“点击补行区域”，
        // 这部分只是为了方便点击追加内容，不应该被视为“内容溢出”的依据。否则会出现
        // “文字还没真正占满一屏，但已经因为这 80px 而被判定为可滚动”的问题。
        if (_blocks.isNotEmpty) {
          final double kBottomTapAreaHeight = _bottomTapAreaHeight;
          contentHeight = math.max(0.0, contentHeight - kBottomTapAreaHeight);
        }

        final double overflowByHeight = contentHeight - viewportHeight;
        overflow = math.min(overflow, overflowByHeight);
      }
    }

    final double kMinOverflowToScroll = _bottomTapAreaHeight;
    final bool shouldScroll = overflow > kMinOverflowToScroll;
    if (shouldScroll != _contentScrollable) {
      setState(() {
        _contentScrollable = shouldScroll;
        // 当从“可滚动”切换到“不可滚动”时，强制把偏移重置到 0，避免残留位移感。
        if (!shouldScroll && _contentScrollController.offset != 0.0) {
          _contentScrollController.jumpTo(0.0);
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();

    // New entries start editable; existing entries open in read-only mode.
    _editMode = widget.entryId == null;

    // 初始化块级编辑器（先空文档，后续 _bootstrap 载入真实内容后会再次初始化）
    _initBlocksFromRaw('');

    _textCtrl.addListener(() { if (mounted) setState(() {}); });
    _bootstrap();
    WidgetsBinding.instance.addPostFrameCallback((_)=>_precacheBg());
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateContentScrollPhysics());
    _textCtrl.addListener(() {
      if (!_dirty) setState(() => _dirty = true);
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateContentScrollPhysics());
    });
  }

  @override
  void didUpdateWidget(covariant EntryEditorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // PageView may reuse an existing EntryEditorPage State for a different
    // entryId. When that happens, reload all per-entry fields so the UI always
    // matches the currently displayed entry.
    if (oldWidget.entryId != widget.entryId || oldWidget.notebookId != widget.notebookId) {
      _dirty = false;
      _entryId = 0;
      _time = DateTime.now();
      _weatherCode = null;
      _moodName = null;
      _moodIcon = null;
      _starred = false;
      _tagIds.clear();
      _tagNameById.clear();
      _textCtrl.text = '';
      _initBlocksFromRaw('');

      // Reset edit mode for the new entry context.
      _editMode = widget.entryId == null;
      _bootstrap();
      WidgetsBinding.instance.addPostFrameCallback((_)=>_precacheBg());
    }
  }

  @override
  void dispose() {
    // 块级编辑器资源释放
    for (final b in _blocks) {
      if (b is _TextBlock) {
        b.controller.dispose();
        b.focusNode.dispose();
      }
    }
    _blocks.clear();

    _contentScrollController.dispose();
    _focusNode.dispose();
    _textCtrl.dispose();
    // Dispose audio players
    for (final player in _audioPlayers.values) {
      try {
        player.dispose();
      } catch (_) {}
    }
    _audioPlayers.clear();
    _audioPlaying.clear();
    super.dispose();
  }

  

  // ===== 块级编辑器：解析/序列化 =====
  void _initBlocksFromRaw(String raw) {
    // 清理旧块
    for (final b in _blocks) {
      if (b is _TextBlock) {
        b.controller.dispose();
        b.focusNode.dispose();
      }
    }
    _blocks.clear();
    _selectedBlockIndex = null;
    _activeTextBlock = 0;

    final lines = raw.split('\n');
    final buf = StringBuffer();

    void flushText() {
      final text = buf.toString();
      if (text.isNotEmpty) {
        _blocks.add(_TextBlock(text));
        buf.clear();
      }
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('[图片]')) {
        flushText();
        final rest = trimmed.substring('[图片]'.length).trim();

        // Marker format (current):
        //   [图片] /abs/path/to/file.jpg|w=0.50
        // Legacy format:
        //   [图片] /abs/path#wf=0.50
        String path = rest;
        double wf = 1.0;

        // Parse current "|w=" suffix (most common, produced by _serializeBlocksToRaw).
        final pipeIdx = rest.indexOf('|w=');
        if (pipeIdx >= 0) {
          path = rest.substring(0, pipeIdx).trim();
          final vStr = rest.substring(pipeIdx + 3).trim();
          final v = double.tryParse(vStr);
          if (v != null && v > 0 && v <= 1.0) wf = v;
        } else {
          // Parse legacy "#wf=" suffix (backward compatible).
          final hash = rest.indexOf('#');
          if (hash >= 0) {
            path = rest.substring(0, hash).trim();
            final tail = rest.substring(hash + 1).trim();
            final parts = tail.split('=');
            if (parts.length == 2 && parts.first.trim() == 'wf') {
              final v = double.tryParse(parts.last.trim());
              if (v != null && v > 0 && v <= 1.0) wf = v;
            }
          }
        }
        if (path.isNotEmpty) _blocks.add(_ImageBlock(path, widthFactor: wf));
      } else if (trimmed.startsWith('[语音]')) {
        flushText();
        final path = trimmed.substring('[语音]'.length).trim();
        if (path.isNotEmpty) _blocks.add(_AudioBlock(path));
      } else {
        // 保留用户真实换行
        buf.writeln(line);
      }
    }
    flushText();

    if (_blocks.isEmpty || _blocks.whereType<_TextBlock>().isEmpty) {
      _blocks.add(_TextBlock(''));
      _activeTextBlock = _blocks.indexWhere((b) => b is _TextBlock);
      if (_activeTextBlock < 0) _activeTextBlock = 0;
    }

    // 统一为所有文本块挂载监听，并在获得焦点时更新 _activeTextBlock。
    for (final b in _blocks) {
      if (b is _TextBlock) {
        b.controller.addListener(_syncRawFromBlocks);
        b.focusNode.addListener(() {
          if (b.focusNode.hasFocus) {
            final idx = _blocks.indexOf(b);
            if (idx >= 0) _activeTextBlock = idx;
          }
        });
      }
    }

    // 如果是“空白新文档”（新增日记，原始内容为空或仅包含空白，且只有一个空的文本块），
    // 则在页面构建完成后自动把光标移动到首个文本块开头，让用户一进页面就能直接输入。
    final bool isNewEmptyDoc = widget.entryId == null;
    if (isNewEmptyDoc) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final tb = _blocks.firstWhere((b) => b is _TextBlock) as _TextBlock;
        FocusScope.of(context).requestFocus(tb.focusNode);
        tb.controller.selection = TextSelection.collapsed(offset: 0);
        SystemChannels.textInput.invokeMethod('TextInput.show');
      });
    }

    // 从阅读页强制进入编辑态时（focusAtStart = true），即便是已有日记，也在首个文本块开头聚焦并弹出键盘。
    if (!isNewEmptyDoc && widget.entryId != null && widget.focusAtStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final tb = _blocks.firstWhere((b) => b is _TextBlock, orElse: () => _TextBlock('')) as _TextBlock;
        if (!_blocks.contains(tb)) {
          _blocks.insert(0, tb);
        }
        FocusScope.of(context).requestFocus(tb.focusNode);
        tb.controller.selection = const TextSelection.collapsed(offset: 0);
        SystemChannels.textInput.invokeMethod('TextInput.show');
      });
    }


    _syncRawFromBlocks();
  }


  String _serializeBlocksToRaw() {
    // Serialize blocks back into raw multiline text.  Only insert
    // additional newline characters between consecutive text blocks.  This
    // avoids creating blank lines above image or audio attachments.
    final out = StringBuffer();
    for (var i = 0; i < _blocks.length; i++) {
      final b = _blocks[i];
      if (b is _TextBlock) {
        final text = b.controller.text;
        // Write the text as-is; it may already include newlines.
        out.write(text);
        final bool hasTrailingNewline = text.endsWith('\n');
        final bool nextIsText = (i + 1 < _blocks.length) && (_blocks[i + 1] is _TextBlock);
        final bool nextIsAttachment = (i + 1 < _blocks.length) && (_blocks[i + 1] is! _TextBlock);
        // Insert a newline when the next block is another text block and the
        // current text does not already end with a newline.  Also insert
        // a newline when the next block is an attachment (image or audio)
        // to ensure the attachment marker appears on its own line.  This
        // avoids merging the marker with the end of the previous text.
        if ((nextIsText || nextIsAttachment) && !hasTrailingNewline) {
          out.write('\n');
        }
      } else if (b is _ImageBlock) {
        // Serialize image marker.  Include width factor only if significantly
        // different from 1.0.  Always end with a newline.
        out.write('[图片] ${b.path}${(b.widthFactor < 0.999) ? '|w=${b.widthFactor.toStringAsFixed(2)}' : ''}');
        out.write('\n');
      } else if (b is _AudioBlock) {
        // Serialize audio marker.  Always end with a newline.
        out.write('[语音] ${b.path}');
        out.write('\n');
      }
    }
    return out.toString();
  }

  void _syncRawFromBlocks() {
    final raw = _serializeBlocksToRaw();
    if (raw == _textCtrl.text) return;
    _textCtrl.text = raw;
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  int _ensureActiveTextBlock() {
    if (_blocks.isEmpty) {
      _blocks.add(_TextBlock(''));
      _activeTextBlock = 0;
      return 0;
    }
    if (_activeTextBlock < 0 || _activeTextBlock >= _blocks.length || _blocks[_activeTextBlock] is! _TextBlock) {
      final idx = _blocks.indexWhere((b) => b is _TextBlock);
      _activeTextBlock = idx >= 0 ? idx : 0;
      if (_blocks[_activeTextBlock] is! _TextBlock) {
        _blocks.insert(0, _TextBlock(''));
        _activeTextBlock = 0;
      }
    }
    return _activeTextBlock;
  }

  void _focusTextBlockStart(int index) {
    if (index < 0 || index >= _blocks.length) return;
    final b = _blocks[index];
    if (b is! _TextBlock) return;
    FocusScope.of(context).requestFocus(b.focusNode);
    b.controller.selection = const TextSelection.collapsed(offset: 0);
    _activeTextBlock = index;
    setState(() {});
  }

  void _enterEditMode() {
    if (_editMode) return;
    setState(() {
      _editMode = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final idx = _blocks.indexWhere((b) => b is _TextBlock);
      _focusTextBlockStart(idx >= 0 ? idx : 0);
      SystemChannels.textInput.invokeMethod('TextInput.show');
    });
  }
  bool _handleBackspaceInTextBlock(_TextBlock block, RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.backspace) return false;

    final selection = block.controller.selection;
    // 仅在光标在该文本块的起始位置且无选区时触发
    if (!selection.isValid || !selection.isCollapsed || selection.baseOffset != 0) {
      return false;
    }

    final index = _blocks.indexOf(block);
    if (index <= 0) return false;
    final prev = _blocks[index - 1];
    if (prev is! _ImageBlock && prev is! _AudioBlock) {
      return false;
    }

    // 删除前一个图片/语音块
    _deleteBlockAt(index - 1);
    return true;
  }

  /// Toggle play/pause for the given audio path.  Ensures a
  /// corresponding AudioPlayer and playing state exist.  When
  /// starting playback, previously playing audio on this path will be
  /// paused before resuming.
  Future<void> _toggleAudio(String path) async {
    final player = _audioPlayers.putIfAbsent(path, () => AudioPlayer());
    final playing = _audioPlaying.putIfAbsent(path, () => ValueNotifier<bool>(false));
    try {
      if (playing.value) {
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

  void _moveCaretToLineStart(_TextBlock block, Offset localPos, double maxWidth, TextStyle style) {
    final text = block.controller.text;
    if (text.isEmpty) {
      block.controller.selection = const TextSelection.collapsed(offset: 0);
      return;
    }
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    )..layout(maxWidth: maxWidth);

    double dy = localPos.dy;
    if (dy < 0) dy = 0;
    if (dy > painter.height) dy = painter.height;

    final pos = painter.getPositionForOffset(Offset(0, dy));
    final range = painter.getLineBoundary(pos);
    int start = range.start;
    if (start < 0) start = 0;
    if (start > text.length) start = text.length;
    block.controller.selection = TextSelection.collapsed(offset: start);
  }

  void _deleteBlockAt(int index) {
    if (index < 0 || index >= _blocks.length) return;
    final b = _blocks[index];
    if (b is _TextBlock) {
      b.controller.dispose();
      b.focusNode.dispose();
    }
    _blocks.removeAt(index);
    if (_blocks.whereType<_TextBlock>().isEmpty) {
      _blocks.insert(0, _TextBlock(''));
      _activeTextBlock = 0;
    } else {
      _activeTextBlock = _blocks.indexWhere((x) => x is _TextBlock);
      if (_activeTextBlock < 0) _activeTextBlock = 0;
    }
    _selectedBlockIndex = null;
    _syncRawFromBlocks();
    setState(() {});
  }

Future<void> _bootstrap() async {
    // config: diary bg image & opacity（优先使用内存缓存，避免进入编辑页时先白底再切换背景）
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
        final img = rows.first['diary_bg_image'];
        _bgPath = img == null ? null : img.toString();
        final op = rows.first['diary_bg_opacity'];
        if (op != null) _bgOpacity = double.tryParse(op.toString()) ?? _bgOpacity;
      }
    } catch (_) {}

    // recent mood from emotions
    try {
      final rows = await db.query('emotions', orderBy: 'inserted_at DESC', limit: 1);
      if (rows.isNotEmpty) {
        _moodName = (rows.first['emoji_name'] ?? '').toString();
        _moodIcon = (rows.first['emoji_char'] ?? '').toString();
      }
    } catch (_) {}

    await _dao.ensureSchema();

    if (widget.entryId != null) {
      final e = await _dao.getEntry(widget.entryId!);
      if (e != null) {
        _entryId = e.id;
        _time = DateTime.fromMillisecondsSinceEpoch(e.entryTime);
        _weatherCode = e.weatherCode;
        // 使用日记条目的心情（有可能为空），不要回落到最近心情
        _moodName = e.moodName;
        _moodIcon = e.moodIcon;
        _textCtrl.text = e.content;
        _initBlocksFromRaw(_textCtrl.text);
        _starred = (e.starred == 1);

        // Cache AppBar title (first non-empty text line) for edit page.
        _cachedTitle = _deriveShortTitle(_textCtrl.text);

        final tags = await _dao.tagsForEntry(e.id);
        _tagIds
          ..clear()
          ..addAll(tags.map((t) => t.id));
        for (final t in tags) {
          _tagNameById[t.id] = t.name;
        }
      }
    }

    // If no entryId, keep defaults but build tag name map for future display
    await _refreshTagNameMap();

    if (mounted) setState(() {});
  }

  String _deriveShortTitle(String raw) {
    // Pick first non-empty text line, skipping attachment markers.
    final lines = raw.split(RegExp(r'\r?\n'));
    String first = '';
    for (final l in lines) {
      final t = l.trim();
      if (t.isEmpty) continue;
      if (t.startsWith('[图片]') || t.startsWith('[语音]')) continue;
      first = t;
      break;
    }
    // 用户要求：标题取首行完整文字；若日记内容为空则标题为空白。
    if (first.isEmpty) return '';
    return first;
  }

  Future<void> _refreshTagNameMap() async {
    try {
      final all = await _dao.listTags();
      for (final t in all) {
        _tagNameById[t.id] = t.name;
      }
    } catch (_) {}
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

  Future<bool> _handleWillPop() async {
    // Auto-save before leaving this editor page.
    await saveIfDirty(popAfterSave: true);
    return false;
  }

  /// Save current entry if there are pending changes.
  /// When [popAfterSave] is true, the page will be popped after saving.
  /// Returns the entry id (or null if nothing was saved / new empty entry).
  Future<int?> saveIfDirty({bool popAfterSave = false}) async {
    if (!_dirty) {
      if (popAfterSave && mounted) {
        // For an existing entry, return id; for a new empty entry, pop without result.
        if (_entryId != 0) {
          Navigator.pop(context, _entryId);
        } else {
          Navigator.pop(context);
        }
      }
      return _entryId != 0 ? _entryId : null;
    }

    final w = weatherByCode(_weatherCode);
    // Update the cached title (first text line) after edits.
    _cachedTitle = _deriveShortTitle(_textCtrl.text);
    final e = DiaryEntry(
      id: _entryId,
      notebookId: widget.notebookId,
      entryTime: _time.millisecondsSinceEpoch,
      weatherCode: _weatherCode,
      weatherName: _weatherCode == null ? null : w.name,
      moodName: _moodName,
      moodIcon: _moodIcon,
      content: _textCtrl.text,
      preview: _preview(_textCtrl.text),
      starred: _starred ? 1 : 0,
    );
    final id = await _dao.upsertEntry(e);
    _entryId = id;
    await _dao.touchNotebook(widget.notebookId);
    await _dao.setTagsForEntry(id, _tagIds);

    _dirty = false;

    if (!mounted) return id;
    if (popAfterSave) {
      Navigator.pop(context, id);
    }
    return id;
  }

  Future<void> _cancel() async {
    if (!_dirty) {
      if (mounted) {
        Navigator.pop(context);
      }
      return;
    }
    // Auto-save current content to avoid losing data.
    await saveIfDirty(popAfterSave: true);
  }


  Future<void> _pickTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _time,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (d == null) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_time));
    if (t == null) return;
    setState(() {
      _time = DateTime(d.year, d.month, d.day, t.hour, t.minute);
      _dirty = true;
    });
  }

  Future<void> _pickTags() async {
    final res = await Navigator.push<List<int>?>(
      context,
      MaterialPageRoute(builder: (_) => TagPickerPage(dao: _dao, initialSelected: _tagIds)),
    );
    if (res == null) return;
    setState(() {
      _tagIds
        ..clear()
        ..addAll(res);
      _dirty = true;
    });
    await _refreshTagNameMap();
    if (mounted) setState(() {});
  }
  Widget _bgWrap(Widget child) {
    if (!widget.useBackground) {
      // When embedded in the multi-page editor, the pager is responsible
      // for painting the diary background image. In that case we keep
      // this page fully transparent so only the content scrolls over the
      // shared background.
      return child;
    }
    // Requirement: diary pages default to pure white when no background image
    // is configured. We still paint a solid base first so the page does not
    // show a black/transparent canvas while the background config loads.
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

  @override
  
  
  
  
void _openAttachmentSheet() {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) {
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('图片'),
              onTap: () {
                Navigator.pop(context);
                _insertImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.mic_none_outlined),
              title: const Text('录音/音频'),
              onTap: () {
                Navigator.pop(context);
                _insertAudio();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

Future<void> _insertImage() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image);
    if (res == null || res.files.isEmpty) return;
    final path0 = res.files.first.path;
    if (path0 == null) return;

    final newPath = await _persistAttachment(path0, subdir: 'images');

    final insertAt = _ensureActiveTextBlock();
    final b = _blocks[insertAt];
    if (b is! _TextBlock) return;

    final text = b.controller.text;
    final sel = b.controller.selection;
    int caret = sel.isValid ? sel.baseOffset : text.length;
    if (caret < 0) caret = 0;
    if (caret > text.length) caret = text.length;

    final before = text.substring(0, caret);
    final after = text.substring(caret);

    // Remove trailing newline characters from the portion before the caret.  When
    // inserting an attachment at the beginning of a new line, the preceding
    // text may end with one or more newline characters.  Keeping those
    // newlines would otherwise become their own empty text block and
    // introduce a blank line above the inserted attachment.  Trim only
    // trailing newline characters (\n or \r\n), but preserve other
    // whitespace so caret positions remain accurate.
    final String trimmedBefore = before.replaceAll(RegExp(r'(?:\r?\n)+\$'), '');

    final newBlocks = <_EditorBlock>[];
    for (final bb in _blocks.take(insertAt)) {
      if (bb is _TextBlock) {
        newBlocks.add(_TextBlock(bb.controller.text));
      } else {
        newBlocks.add(bb);
      }
    }

    // 避免“图片上方出现空白”：如果光标在一个空文本块的开头，就不保留这个空块。
    // 仅当光标前的文本（去除末尾换行）包含非空内容时，才保留该文本块。
    final bool keepBeforeText = trimmedBefore.trim().isNotEmpty;
    if (keepBeforeText) {
      newBlocks.add(_TextBlock(trimmedBefore));
    }

    newBlocks.add(_ImageBlock(newPath, widthFactor: 0.5));

    // 图片下方始终保留一个文本块用于继续输入（即使 after 为空）
    newBlocks.add(_TextBlock(after));

    for (final bb in _blocks.skip(insertAt + 1)) {
      if (bb is _TextBlock) {
        newBlocks.add(_TextBlock(bb.controller.text));
      } else {
        newBlocks.add(bb);
      }
    }

    // 释放旧块资源
    for (final old in _blocks) {
      if (old is _TextBlock) {
        old.controller.removeListener(_syncRawFromBlocks);
        old.controller.dispose();
        old.focusNode.dispose();
      }
    }

    _blocks
      ..clear()
      ..addAll(newBlocks);

    // 重新绑定监听
    for (final bb in _blocks) {
      if (bb is _TextBlock) {
        bb.controller.addListener(_syncRawFromBlocks);
        bb.focusNode.addListener(() {
          if (bb.focusNode.hasFocus) {
            final idx = _blocks.indexOf(bb);
            if (idx >= 0) _activeTextBlock = idx;
          }
        });
      }
    }

    _syncRawFromBlocks();

    // 插入完成：按方案A，把光标放到图片下方文本块的“行首列”
    final focusIdx = (keepBeforeText ? insertAt + 1 : insertAt) + 1; // 图片后面的文本块
    _focusTextBlockStart(focusIdx);
  }


  
  Future<void> _deleteEntry() async {
    if (_entryId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除日记'),
        content: const Text('确定要删除该日记吗？此操作不可撤销。'),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(_, false), child: const Text('取消')),
          FilledButton(onPressed: ()=>Navigator.pop(_, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    final db = await AppDatabase.instance();
    await db.delete('entry_tags', where: 'entry_id=?', whereArgs: [_entryId]);
    await db.delete('entries', where: 'id=?', whereArgs: [_entryId]);
    if (mounted) Navigator.pop(context, true);
  }
Future<void> _insertAudio() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (res == null || res.files.isEmpty) return;
    final path = res.files.first.path;
    if (path == null) return;

    final insertAt = _ensureActiveTextBlock();
    final b = _blocks[insertAt];
    if (b is! _TextBlock) return;

    final text = b.controller.text;
    final sel = b.controller.selection;
    int caret = sel.isValid ? sel.baseOffset : text.length;
    if (caret < 0) caret = 0;
    if (caret > text.length) caret = text.length;

    final before = text.substring(0, caret);
    final after = text.substring(caret);

    // Remove trailing newline characters from the portion before the caret.  See
    // `_insertImage()` for detailed rationale.  This prevents a stray blank
    // line appearing above an inserted audio attachment when the cursor sits
    // at the beginning of a new line.
    final String trimmedBefore = before.replaceAll(RegExp(r'(?:\r?\n)+\$'), '');

    final newBlocks = <_EditorBlock>[];
    for (final bb in _blocks.take(insertAt)) {
      if (bb is _TextBlock) {
        newBlocks.add(_TextBlock(bb.controller.text));
      } else {
        newBlocks.add(bb);
      }
    }

    // 如果光标前的文本除了换行和空格外还有内容，则保留该文本块。仅当
    // 去除末尾换行后的文本不为空时才添加。
    final bool keepBeforeText = trimmedBefore.trim().isNotEmpty;
    if (keepBeforeText) {
      newBlocks.add(_TextBlock(trimmedBefore));
    }

    newBlocks.add(_AudioBlock(path));
    newBlocks.add(_TextBlock(after));

    for (final bb in _blocks.skip(insertAt + 1)) {
      if (bb is _TextBlock) {
        newBlocks.add(_TextBlock(bb.controller.text));
      } else {
        newBlocks.add(bb);
      }
    }

    for (final old in _blocks) {
      if (old is _TextBlock) {
        old.controller.removeListener(_syncRawFromBlocks);
        old.controller.dispose();
        old.focusNode.dispose();
      }
    }

    _blocks
      ..clear()
      ..addAll(newBlocks);

    for (final bb in _blocks) {
      if (bb is _TextBlock) {
        bb.controller.addListener(_syncRawFromBlocks);
        bb.focusNode.addListener(() {
          if (bb.focusNode.hasFocus) {
            final idx = _blocks.indexOf(bb);
            if (idx >= 0) _activeTextBlock = idx;
          }
        });
      }
    }

    _syncRawFromBlocks();

    final focusIdx = (keepBeforeText ? insertAt + 1 : insertAt) + 1;
    _focusTextBlockStart(focusIdx);
  }


    void _onTextChanged(String s) {
    // 标记内容已修改
    if (mounted && !_dirty) {
      setState(() {
        _dirty = true;
      });
    }

    final TextSelection curSel = _textCtrl.selection;
    final String prevText = _lastText;
    final TextSelection prevSel = _lastSel;
    _lastText = s;
    _lastSel = curSel;

    if (prevText.isEmpty) return;
    if (!curSel.isCollapsed || !prevSel.isValid) return;

    final int deleted = prevText.length - s.length;
    if (deleted != 1) return; // 只处理单次退格

    // 找出被删除的那个字符在旧文本中的位置。
    int diffIndex = 0;
    final int minLen = s.length;
    while (diffIndex < minLen &&
        prevText.codeUnitAt(diffIndex) == s.codeUnitAt(diffIndex)) {
      diffIndex++;
    }
    if (diffIndex < 0 || diffIndex >= prevText.length) return;

    final int deletedCodeUnit = prevText.codeUnitAt(diffIndex);

    // 1）如果删除的是换行符，统一按普通换行处理，不额外删除附件。
    //    这样在图片“下方第一行行首”按一次退格，只会删掉空行，图片本身仍然存在。
    if (deletedCodeUnit == 10) {
      return;
    }

    // 2）删除的是其它字符：检查该字符所在行是不是附件标记行。
    int lineStart = 0;
    for (int i = 0; i < diffIndex; i++) {
      if (prevText.codeUnitAt(i) == 10) {
        lineStart = i + 1;
      }
    }
    int lineEnd = prevText.length;
    for (int i = diffIndex + 1; i < prevText.length; i++) {
      if (prevText.codeUnitAt(i) == 10) {
        lineEnd = i + 1; // 包含这一行结尾的换行
        break;
      }
    }

    final String line =
        prevText.substring(lineStart, lineEnd).trimLeft();

    final bool isMarker =
        line.startsWith('[图片]') || line.startsWith('[语音]');
    if (!isMarker) {
      // 删除的是普通字符，与附件无关。
      return;
    }

    // 3）删除的是附件标记行中的某个字符：视为删除整个附件行。
    final String newText =
        prevText.substring(0, lineStart) + prevText.substring(lineEnd);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _textCtrl.text = newText;
      _textCtrl.selection =
          TextSelection.collapsed(offset: lineStart);
      setState(() {});
    });
  }




  void _handleTextTap() {
    // 当点击 TextField 内部时，把光标移动到当前行的最左侧。
    final sel = _textCtrl.selection;
    if (!sel.isValid) return;
    final text = _textCtrl.text;
    if (text.isEmpty) return;
    int off = sel.baseOffset;
    if (off < 0) off = 0;
    if (off > text.length) off = text.length;
    while (off > 0 && text.codeUnitAt(off - 1) != 10) {
      off--;
    }
    _textCtrl.selection = TextSelection.collapsed(offset: off);
  }

    
void _handleDoubleTapDown(TapDownDetails details) {
  // 新实现：只根据点击的纵坐标把光标移动到对应行的行首，
  // 不再在正文中自动插入或删除换行符，从而避免图片/语音等附件
  // 在连续回车 / 退格时跟随光标上下“漂移”的问题。
  final BuildContext? ctx = _textBoxKey.currentContext;
  if (ctx == null) return;
  final RenderBox? box = ctx.findRenderObject() as RenderBox?;
  if (box == null) return;

  final Offset local = box.globalToLocal(details.globalPosition);
  final Size size = box.size;
  final TextStyle baseStyle = DefaultTextStyle.of(ctx).style;
  final String text = _textCtrl.text;

  // 文本为空：直接把光标放在文首即可，由用户自己回车补行。
  if (text.isEmpty) {
    FocusScope.of(context).requestFocus(_focusNode);
    _textCtrl.selection = const TextSelection.collapsed(offset: 0);
    setState(() {});
    return;
  }

  // 利用 controller 当前的 buildTextSpan 计算布局，获取每一行大致的 y 位置。
  final TextSpan span = _textCtrl.buildTextSpan(
    context: ctx,
    style: baseStyle,
    withComposing: false,
  );
  final TextPainter painter = TextPainter(
    text: span,
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.left,
  )..layout(maxWidth: size.width);

  // 点击纵坐标限制在文本内容高度范围内——超出底部就按最后一行处理。
  double dy = local.dy;
  if (dy < 0) dy = 0;
  if (dy > painter.height) dy = painter.height;

  final TextPosition pos = painter.getPositionForOffset(Offset(0, dy));
  int off = pos.offset;
  if (off < 0) off = 0;
  if (off > text.length) off = text.length;

  // 回退到这一行的行首（上一行的换行符后面）。
  while (off > 0 && text.codeUnitAt(off - 1) != 10) {
    off--;
  }

  FocusScope.of(context).requestFocus(_focusNode);
  _textCtrl.selection = TextSelection.collapsed(offset: off);
  setState(() {});
}
Widget _attachmentsPreview() {
    final content = _textCtrl.text;
    final lines = content.split(RegExp(r'\r?\n'));
    final widgets = <Widget>[];

    final imgReg = RegExp(r'^\[图片\]\s*(.+)$');
    final audioReg = RegExp(r'^\[语音\]\s*(.+)$');

    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.isEmpty) continue;

      final mImg = imgReg.firstMatch(line);
      final mAud = audioReg.firstMatch(line);

            if (mImg != null) {
        // 图片在正文中以内联方式展示，这里不再重复渲染。
        continue;
      } else if (mAud != null) {
        final path = mAud.group(1)!;
        widgets.add(_AudioTile(path: path));
      }
    }

    if (widgets.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets),
    );
  }





  Widget _buildBlocksEditor(TextStyle textStyle) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final children = <Widget>[];
      final bool isEmptyDoc = _blocks.isEmpty ||
          (_blocks.length == 1 &&
           _blocks.first is _TextBlock &&
           (_blocks.first as _TextBlock).controller.text.isEmpty);
      if (isEmptyDoc) {
        // 页面为空时：点击任意位置可以在相应行首插入光标。根据点击的纵坐标估算行数，插入若干换行。
        children.add(SizedBox(
          height: constraints.maxHeight,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (details) {
              _selectedBlockIndex = null;
              final lineHeight = (textStyle.fontSize ?? 16.0) * 1.3;
              double dy = details.localPosition.dy;
              if (dy < 0) dy = 0;
              int extraLines = (dy / lineHeight).floor();
              if (extraLines < 0) extraLines = 0;
              final text = '\n' * extraLines;
              final tb = _TextBlock(text);
              tb.controller.addListener(_syncRawFromBlocks);
              tb.focusNode.addListener(() {
                if (tb.focusNode.hasFocus) {
                  _activeTextBlock = _blocks.indexOf(tb);
                }
              });
              _blocks.add(tb);
              _activeTextBlock = _blocks.length - 1;
              _syncRawFromBlocks();
              setState(() {});
              // 将光标移动到插入的文本块末尾（行首）
              FocusScope.of(context).requestFocus(tb.focusNode);
              tb.controller.selection = TextSelection.collapsed(offset: text.length);
            },
          ),
        ));
      }
    for (int i = 0; i < _blocks.length; i++) {
      final b = _blocks[i];
      if (b is _TextBlock) {
        children.add(
          DragTarget<int>(
            onWillAccept: (from) => from != null && from != i,
            onAccept: (from) {
              setState(() {
                final moved = _blocks.removeAt(from);
                final insert = i > from ? i - 1 : i;
                _blocks.insert(insert, moved);
                _dirty = true;
                _syncRawFromBlocks();
              });
            },
            builder: (context, cand, rej) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: (d) {
                  // Read-only mode: do not enter text editing or show keyboard.
                  if (!_editMode) return;
                  _selectedBlockIndex = null;
                  _activeTextBlock = i;
                  FocusScope.of(context).requestFocus(b.focusNode);
                  _moveCaretToLineStart(
                    b,
                    d.localPosition,
                    constraints.maxWidth,
                    textStyle,
                  );
                  setState(() {});
                },
                child: Focus(
                  onKey: (node, event) {
                    final handled = _handleBackspaceInTextBlock(b, event);
                    return handled ? KeyEventResult.handled : KeyEventResult.ignored;
                  },
                  child: AbsorbPointer(
                    absorbing: !_editMode,
                    child: TextField(
                      controller: b.controller,
                      focusNode: b.focusNode,
                      maxLines: null,
                      readOnly: !_editMode,
                      showCursor: _editMode,
                      scrollPhysics: const NeverScrollableScrollPhysics(),
                      textAlignVertical: TextAlignVertical.top,
                      style: textStyle,
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: '写点什么',
                      ),
                    ),
                  ),
                ),
                  );
                },
              );
            },
          ),
        );
      } else if (b is _ImageBlock) {
        final selected = _selectedBlockIndex == i;
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (!_editMode) return;
                setState(() {
                  _selectedBlockIndex = selected ? null : i;
                });
              },
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  Container(
                    decoration: selected
                        ? BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          )
                        : null,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final file = File(b.path);
                        if (!file.existsSync()) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Theme.of(context).dividerColor),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('图片加载失败：${b.path}',
                                style: textStyle),
                          );
                        }

                        final wf = (b.widthFactor < 0.3)
                            ? 0.3
                            : (b.widthFactor > 1.0 ? 1.0 : b.widthFactor);

                        if (!_editMode) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: wf,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(file, fit: BoxFit.fitWidth),
                              ),
                            ),
                          );
                        }

                        return LongPressDraggable<int>(
                          data: i,
                          feedback: Material(
                            color: Colors.transparent,
                            child: SizedBox(
                              width: constraints.maxWidth * wf,
                              child: Image.file(file, fit: BoxFit.fitWidth),
                            ),
                          ),
                          child: DragTarget<int>(
                            onWillAccept: (from) => from != null && from != i,
                            onAccept: (from) {
                              setState(() {
                                final moved = _blocks.removeAt(from);
                                final insert = i > from ? i - 1 : i;
                                _blocks.insert(insert, moved);
                                _dirty = true;
                                _syncRawFromBlocks();
                              });
                            },
                            builder: (context, cand, rej) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: wf,
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        child: Stack(
                                          children: [
                                            Image.file(file,
                                                fit: BoxFit.fitWidth),
                                            Positioned(
                                              bottom: 0,
                                              left: 0,
                                              child: SizedBox(
                                                width: 28,
                                                height: 28,
                                                child: GestureDetector(
                                                  onTap: () {
                                                    // 光标放到图片“之前”
                                                    final prevTextIdx =
                                                        (i - 1 >= 0 &&
                                                                _blocks[i - 1]
                                                                    is _TextBlock)
                                                            ? i - 1
                                                            : i;
                                                    _focusTextBlockStart(
                                                        prevTextIdx);
                                                  },
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              bottom: 0,
                                              right: 0,
                                              child: SizedBox(
                                                width: 28,
                                                height: 28,
                                                child: GestureDetector(
                                                  onTap: () {
                                                    // 光标放到图片“之后”
                                                    final nextTextIdx =
                                                        (i + 1 <
                                                                    _blocks
                                                                        .length &&
                                                                _blocks[i + 1]
                                                                    is _TextBlock)
                                                            ? i + 1
                                                            : i;
                                                    _focusTextBlockStart(
                                                        nextTextIdx);
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (selected)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.photo_size_select_small,
                                            size: 18,
                                          ),
                                          Expanded(
                                            child: Slider(
                                              value: wf,
                                              min: 0.3,
                                              max: 1.0,
                                              divisions: 14,
                                              label:
                                                  '${(wf * 100).round()}%',
                                              onChanged: (v) {
                                                // 更新当前图片块宽度比例，并同步到 raw
                                                final blk = _blocks[i];
                                                if (blk is _ImageBlock) {
                                                  _blocks[i] = _ImageBlock(
                                                    blk.path,
                                                    widthFactor: v,
                                                  );
                                                  _syncRawFromBlocks();
                                                  if (mounted) {
                                                    setState(() {});
                                                  }
                                                }
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  if (_editMode && selected)
                    IconButton(
                      icon: const Icon(Icons.delete),
                      tooltip: '删除图片',
                      onPressed: () => _deleteBlockAt(i),
                    ),
                ],
              ),
            ),
          ),
        );
      } else if (b is _AudioBlock) {
        final selected = _selectedBlockIndex == i;
        children.add(
          DragTarget<int>(
            onWillAccept: (from) => from != null && from != i,
            onAccept: (from) {
              setState(() {
                final moved = _blocks.removeAt(from);
                final insert = i > from ? i - 1 : i;
                _blocks.insert(insert, moved);
                _dirty = true;
                _syncRawFromBlocks();
              });
            },
            builder: (context, cand, rej) {
              return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (!_editMode) return;
                setState(() {
                  _selectedBlockIndex = selected ? null : i;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).dividerColor,
                  ),
                ),
                child: Builder(
                  builder: (context) {
                    final path = b.path;
                    // Ensure player and state exist
                    final player = _audioPlayers.putIfAbsent(path, () => AudioPlayer());
                    final playing = _audioPlaying.putIfAbsent(path, () => ValueNotifier<bool>(false));
                    return ValueListenableBuilder<bool>(
                      valueListenable: playing,
                      builder: (context, isPlaying, _) {
                        return Row(
                          children: [
                            IconButton(
                              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                              onPressed: () => _toggleAudio(path),
                              tooltip: isPlaying ? '暂停播放' : '播放语音',
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                path.split('/').last,
                                style: textStyle,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_editMode && selected)
                              IconButton(
                                icon: const Icon(Icons.delete),
                                tooltip: '删除语音',
                                onPressed: () => _deleteBlockAt(i),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          );
            },
          ),
        );
      }
    }

    // 底部留出可点击区域：点击后在末尾补足空行并把光标置于该行首
    if (_blocks.isNotEmpty) {
      children.add(
        SizedBox(
          height: _bottomTapAreaHeight,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (details) {
              if (!_editMode) return;
              _selectedBlockIndex = null;
              // 若最后不是文本块，则在末尾补一个文本块
              if (_blocks.isEmpty || _blocks.last is! _TextBlock) {
                final tbNew = _TextBlock('');
                tbNew.controller.addListener(_syncRawFromBlocks);
                tbNew.focusNode.addListener(() {
                  if (tbNew.focusNode.hasFocus) {
                    _activeTextBlock = _blocks.indexOf(tbNew);
                  }
                });
                _blocks.add(tbNew);
                _activeTextBlock = _blocks.length - 1;
              }
              final tb = _blocks.last as _TextBlock;
              // 根据点击纵坐标计算需要补充的换行数，至少1行
              final lineHeight = (textStyle.fontSize ?? 16.0) * 1.3;
              double dy = details.localPosition.dy;
              if (dy < 0) dy = 0;
              int lines = (dy / lineHeight).ceil();
              if (lines < 1) lines = 1;
              tb.controller.text += '\n' * lines;
              _syncRawFromBlocks();
              setState(() {});
              // 焦点与光标移动到文本末尾
              FocusScope.of(context).requestFocus(tb.focusNode);
              tb.controller.selection =
                  TextSelection.collapsed(offset: tb.controller.text.length);
              _activeTextBlock = _blocks.length - 1;
            },
            child: const SizedBox.expand(),
          ),
        ),
      );
    }


      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    },
  );
}

  Widget build(BuildContext context) {
    final w = weatherByCode(_weatherCode);
    final textStyle = Theme.of(context).textTheme.bodyLarge ?? const TextStyle(fontSize: 16);

    WidgetsBinding.instance.addPostFrameCallback((_) => _updateContentScrollPhysics());

		const Color _mintBg = Color(0xFFDDEFE6);
		// Android 系统底部三键区域（systemNavigationBar）颜色策略：
		// - 默认全局是白色（main.dart 已设置）。
		// - 仅日记相关页面在配置了背景图片时，跟随日记背景的底色（薄荷绿）。
		final bool _hasDiaryBgImage = (_bgPath != null && _bgPath!.isNotEmpty);
		// 用户要求：日记相关页面底部三键区域不出现额外白边/空白。
		// 为此启用 edge-to-edge：systemNavigationBar 设为透明，并让 body extend 到底部。
		final Color _navBarColor = Colors.transparent;

	return AnnotatedRegion<SystemUiOverlayStyle>(
	  value: SystemUiOverlayStyle(systemNavigationBarColor: _navBarColor,
            systemNavigationBarDividerColor: _navBarColor,
            systemNavigationBarContrastEnforced: false,
            // Keep transparent (edge-to-edge) so page background can extend.
	    statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemNavigationBarIconBrightness: Brightness.dark),
      child: _bgWrap(
        WillPopScope(
          onWillPop: widget.handleWillPop ? _handleWillPop : () async => true,
          child: Scaffold(
          // Edge-to-edge：让内容/背景延伸到系统三键区域，避免底部白边。
          extendBody: true,
          extendBodyBehindAppBar: true,
          // IMPORTANT: keep Scaffold transparent so the configured background
          // image (painted by _bgWrap) remains visible.
          backgroundColor: Colors.transparent,
		  appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            systemOverlayStyle: const SystemUiOverlayStyle(statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light),
            title: Transform.translate(
              offset: const Offset(-25, 0),
              child: Text(
                widget.entryId == null ? '写日记' : (_cachedTitle ?? ''),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            actions: [
              IconButton(
                tooltip: '标签',
                onPressed: _editMode ? _pickTags : null,
                icon: const Icon(Icons.label_outline),
              ),
              IconButton(
                tooltip: '附件',
                onPressed: _editMode ? _openAttachmentSheet : null,
                icon: const Icon(Icons.attach_file),
              ),
              if (_entryId != null) ...[
                IconButton(
                  tooltip: '删除日记',
                  onPressed: _deleteEntry,
                  icon: const Icon(Icons.delete_forever_outlined),
                ),
                // Requirement: add an Edit icon to the right of delete.
                IconButton(
                  tooltip: '编辑',
                  onPressed: _editMode ? null : _enterEditMode,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ],
          ),
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (_) {
              if (_selectedBlockIndex != null) setState(() => _selectedBlockIndex = null);
            },
            child: SafeArea(
              bottom: false,
              child: Stack(
          children: [
            Column(
              children: [
                Material(
                  color: Colors.transparent,
                  elevation: 0,
                  child: Padding(
                    padding: EdgeInsets.zero,
                    child: Row(
                      children: [
                        // 时间：左侧边距增加 15dp；删除左侧图标，避免被截断，允许换行显示到分钟。
                        Expanded(
                          flex: 5,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 15),
                            child: InkWell(
                              onTap: _editMode ? _pickTime : null,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _fmt.format(_time),
                                  maxLines: 2,
                                  softWrap: true,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 天气：整体向左移动 20dp；同时将天气文字在横线上微调向右 3dp。
                        Expanded(
                          flex: 3,
                          child: Center(
                            child: Transform.translate(
                              offset: const Offset(-20, 0),
                              child: DropdownButton<int>(
                                value: _weatherCode,
                                hint: const Text('天气'),
                                items: weatherOptions
                                    .map((w) => DropdownMenuItem<int>(
                                          value: w.code,
                                          child: Row(
                                            children: [
                                              Icon(w.icon, size: 18),
                                              // 6 -> 9：天气文字向右移动 3dp
                                              const SizedBox(width: 9),
                                              Text(w.name),
                                            ],
                                          ),
                                        ))
                                    .toList(),
                                onChanged: !_editMode
                                    ? null
                                    : (v) => setState(() {
                                          _weatherCode = v;
                                          _dirty = true;
                                        }),
                              ),
                            ),
                          ),
                        ),

                        // 心情：与天气同步整体向左移动。
                        if ((_moodIcon != null && _moodIcon!.isNotEmpty) || (_moodName != null && _moodName!.isNotEmpty))
                          Transform.translate(
                            offset: const Offset(-20, 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_moodIcon != null && _moodIcon!.isNotEmpty)
                                    Text(_moodIcon!, style: const TextStyle(fontSize: 16)),
                                  if (_moodIcon != null && _moodIcon!.isNotEmpty)
                                    const SizedBox(width: 6),
                                  Text(_moodName ?? '心情'),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _contentScrollController,
                    physics: _contentScrollable
                        ? const ClampingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.only(bottom: _contentScrollable ? 96.0 : 0.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          key: _textBoxKey,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildBlocksEditor(textStyle),
                        ),
                        const SizedBox(height: 0),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _attachmentsPreview(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
                          runSpacing: 6,
                          children: _tagIds
                              .map((id) => Chip(
                                    label: Text(_tagNameById[id] ?? '标签#$id'),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                    // NOTE: 按需求移除底部麦克风按钮（仍保留语音相关逻辑以兼容旧数据）。
                    

                  ],
                ),
              ),
            ),
          ],
        ),
      )),
    ))));
  }
}


class _AudioTile extends StatefulWidget {
  final String path;
  const _AudioTile({required this.path});
  @override
  State<_AudioTile> createState() => _AudioTileState();
}

class _AudioTileState extends State<_AudioTile> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play(DeviceFileSource(widget.path));
    }
    if (mounted) setState(() => _playing = !_playing);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: IconButton(icon: Icon(_playing ? Icons.pause : Icons.play_arrow), onPressed: _toggle),
      title: const Text('语音'),
      subtitle: const Text('点击播放'),
      tileColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}