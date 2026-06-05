import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/db.dart';
import 'diary_theme.dart';
import 'diary_dao.dart';
import 'entry_editor_page.dart';

class EntryEditorPagerPage extends StatefulWidget {
  final int notebookId;
  final int initialEntryId;
  const EntryEditorPagerPage({super.key, required this.notebookId, required this.initialEntryId});

  @override
  State<EntryEditorPagerPage> createState() => _EntryEditorPagerPageState();
}

class _EntryEditorPagerPageState extends State<EntryEditorPagerPage> {
  // Stable base background used during page transitions to avoid white/black
  // flashes. Matches the diary reader mint base.
  static const Color _mintBg = Color(0xFFFFFFFF);


  final _dao = DiaryDao();
  final PageController _controller = PageController(initialPage: 1);
  // 动态边界锁定状态：通过 ValueNotifier 与自定义 ScrollPhysics 共享，
  // 避免依赖 ScrollPhysics 构造参数在首次创建后就固定导致的越界判断失效。
  final ValueNotifier<bool> _lockToStart = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _lockToEnd = ValueNotifier<bool>(false);
  final ValueNotifier<int> _realStartPage = ValueNotifier<int>(1);
  final ValueNotifier<int> _realEndPage = ValueNotifier<int>(0);

  final Map<int, GlobalKey<EntryEditorPageState>> _pageKeys = <int, GlobalKey<EntryEditorPageState>>{};

  int _globalIndex = 0;
  int _total = 0;
  bool _hasDiaryBgImage = false;
  String? _diaryBgImagePath;
  double _bgOpacity = 0.25;
  final List<DiaryEntry> _pages = []; // loaded entries
  int _index = 1; // current PageView index within (0.._pages.length+1)

  bool _edgeReboundScheduled = false;

  Future<void> _savePageViewIndex(int pageIndex, {bool awaitSave = false}) async {
    if (_pages.isEmpty) return;
    if (pageIndex < 1 || pageIndex > _pages.length) return;
    final entryId = _pages[pageIndex - 1].id;
    final key = _pageKeys[entryId];
    final st = key?.currentState;
    if (st == null) return;
    final fut = st.saveIfDirty(popAfterSave: false);
    if (awaitSave) {
      await fut;
    } else {
      unawaited(fut);
    }
  }

  int _currentEntryId() {
    if (_pages.isEmpty) return widget.initialEntryId;
    // _index is the PageView index where 1.._pages.length correspond to real pages.
    final int realIndex = (_index - 1).clamp(0, _pages.length - 1);
    return _pages[realIndex].id;
  }

  void _scheduleEdgeSnapBack() {
    if (_edgeReboundScheduled) return;
    _edgeReboundScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _edgeReboundScheduled = false;
      if (!mounted) return;
      if (_controller.hasClients) {
        _controller.jumpToPage(_index);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _pages.clear();
    // 直接使用内存中的日记背景配置，避免每次进入编辑分页页都额外查库，
    // 也能保证与其它日记页面的背景表现保持一致。
    try {
      final cfg = DiaryTheme.current;
      _diaryBgImagePath = cfg.imagePath;
      _hasDiaryBgImage = cfg.hasImage;
      _bgOpacity = cfg.opacity;
    } catch (_) {
      // ignore
    }
    final e = await _dao.getEntry(widget.initialEntryId);
    if (e != null) _pages.add(e);
    _total = await _dao.countEntries(widget.notebookId);
    final pos = await _dao.positionOfEntry(widget.notebookId, widget.initialEntryId) ?? 0;
    if (mounted) {
      setState(() {
        _globalIndex = pos;
        // _hasDiaryBgImage already derived from configs.
      });
    }
  }

  Future<bool> _ensureOlder() async {
    if (_pages.isEmpty) return false;
    final cur = _pages.last;
    final older = await _dao.neighbor(notebookId: widget.notebookId, cur: cur, newer: false);
    if (older == null) return false;
    if (mounted) setState(() => _pages.add(older));
    return true;
  }

  Future<bool> _ensureNewer() async {
    if (_pages.isEmpty) return false;
    final cur = _pages.first;
    final newer = await _dao.neighbor(notebookId: widget.notebookId, cur: cur, newer: true);
    if (newer == null) return false;
    if (mounted) {
      setState(() {
        _pages.insert(0, newer);
        _index++; // current visual index shifts right by 1
      });
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final hasBgImage = _diaryBgImagePath != null && _diaryBgImagePath!.isNotEmpty;
    final baseBgColor = hasBgImage ? Colors.transparent : Colors.white;
    // Page numbers are 1-based for user-facing logic.
    final int currentPageNo = _globalIndex + 1;
    final int lastPageNo = _total;
    // 绝对页码边界（基于数据库中的总条数）
    final bool atAbsoluteFirst = lastPageNo > 0 && _globalIndex <= 0;
    final bool atAbsoluteLast = lastPageNo > 0 && _globalIndex >= lastPageNo - 1;
    // PageView 内部索引边界（1.._pages.length 为真实内容页）
    final bool isFirstViewPage = _index <= 1;
    final bool isLastViewPage = _index >= _pages.length;
    // 仅当“绝对第一页 + 视图第一页”时锁右滑；仅当“绝对最后一页 + 视图最后一页”时锁左滑。
    // 这样可以避免在懒加载过程中误判，保证非边界页的正常滑动。
    final bool lockRightSwipe = atAbsoluteFirst && isFirstViewPage;
    final bool lockLeftSwipe = atAbsoluteLast && isLastViewPage;

    // 将当前边界状态同步到 ScrollPhysics 使用的 ValueNotifier，
    // 这样即使 PageView 的 ScrollPosition 只在首次创建时绑定 physics，
    // 物理计算仍然可以读取到最新的锁定信息，保证边界页真正“纹丝不动”。
    _lockToStart.value = lockRightSwipe;
    _lockToEnd.value = lockLeftSwipe;
    _realStartPage.value = 1;
    _realEndPage.value = _pages.length;


    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: hasBgImage ? Colors.transparent : Colors.white,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: WillPopScope(
        onWillPop: () async {
          await _savePageViewIndex(_index, awaitSave: true);
          Navigator.pop(context, _currentEntryId());
          return false;
        },
        child: Scaffold(
          backgroundColor: baseBgColor,
          extendBody: hasBgImage,
          body: SafeArea(
          top: false,
          bottom: false,
          child: Stack(
            children: [
              // Stable background layer: always paint a white base first so
              // that when the configured background becomes more "transparent"
              // we reveal white instead of the default black canvas.
              const Positioned.fill(child: ColoredBox(color: Colors.white)),
              if (hasBgImage && _diaryBgImagePath != null && _diaryBgImagePath!.isNotEmpty)
                Positioned.fill(
                  child: Opacity(
                    opacity: (1.0 - _bgOpacity).clamp(0.0, 1.0),
                    child: Image.file(
                      File(_diaryBgImagePath!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

              ScrollConfiguration(
                behavior: const _NoOverscrollBehavior(),
                child: NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    // EdgeLockPagePhysics 已经保证了在第一页/最后一页禁止越界方向的拖动，
                    // 这里不再额外触发回弹动画，避免产生任何轻微抖动。
                    return false;
                  },
child: PageView.builder(
                  physics: EdgeLockPagePhysics(
                    lockToStart: _lockToStart,
                    lockToEnd: _lockToEnd,
                    realStartPage: _realStartPage,
                    realEndPage: _realEndPage,
                    // NOTE: we keep Clamping to avoid Android glow.
                    parent: const ClampingScrollPhysics(),
                  ),
                  controller: _controller,
                  itemCount: _pages.length + 2,
                  onPageChanged: (i) async {
                    final prevIndex = _index;
                    // Fire-and-forget save of the page we just left.
                    _savePageViewIndex(prevIndex, awaitSave: false);
                    // Sentinel: swiping to older
                    if (i == _pages.length + 1) {
                      final ok = await _ensureOlder();
                      if (ok == true) {
                        if (!mounted) return;
                        setState(() {
                          _index = _pages.length;
                          _globalIndex = (_globalIndex + 1).clamp(0, _total - 1);
                        });
                        _controller.jumpToPage(_pages.length);
                      } else {
                        if (mounted) _controller.jumpToPage(_pages.length);
                      }
                      return;
                    }
                    // Sentinel: swiping to newer
                    if (i == 0) {
                      final ok = await _ensureNewer();
                      if (ok == true) {
                        if (!mounted) return;
                        setState(() {
                          _index = 1;
                          _globalIndex = (_globalIndex - 1).clamp(0, _total - 1);
                        });
                        _controller.jumpToPage(1);
                      } else {
                        if (mounted) _controller.jumpToPage(1);
                      }
                      return;
                    }
  
                    final prev = prevIndex;
                    if (mounted) {
                      setState(() {
                        _index = i;
                        _globalIndex = (_globalIndex + (i - prev)).clamp(0, _total - 1);
                      });
                    }
                  },
                  itemBuilder: (ctx, i) {
                    // Keep sentinels for lazy loading.
                    if (i == 0 || i == _pages.length + 1) {
                      // Sentinel page: when a diary background image is configured we
                      // must not paint an opaque white here, otherwise users will see
                      // a white "sheet" flash while they drag and cancel a swipe on
                      // the first/last page. In that case we keep it fully
                      // transparent so the real diary background (image) is visible.
                      // When there is no background image we fall back to the normal
                      // mint/white base color.
                      final Color sentinelColor = hasBgImage ? Colors.transparent : _mintBg;
                      return ColoredBox(color: sentinelColor);
                    }
                    final e = _pages[i - 1];
                    final k = _pageKeys.putIfAbsent(e.id, () => GlobalKey<EntryEditorPageState>());
                    return EntryEditorPage(
                      key: k,
                      notebookId: widget.notebookId,
                      entryId: e.id,
                      // Background is painted once by the pager itself.
                      useBackground: false,
                      // Pager controls back/save/pop.
                      handleWillPop: false,
                    );
                  },
                ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                child: IgnorePointer(
                  child: SafeArea(
                    top: false,
                    bottom: true,
                    minimum: EdgeInsets.zero,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          '${_globalIndex + 1}/$_total',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
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
      ),
    );
  }
}

class _NoOverscrollBehavior extends ScrollBehavior {
  const _NoOverscrollBehavior();
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

/// Physics copied from reader to keep UX identical.
///
/// We hard-disable dragging past the first/last entry to avoid revealing
/// any background (white/black) during edge drags.
class EdgeLockPagePhysics extends PageScrollPhysics {
  // 通过 ValueNotifier 读取当前边界锁定状态与真实内容页范围，
  // 避免 ScrollPhysics 在 ScrollPosition 创建之后参数被“定死”导致的判断失效。
  final ValueNotifier<bool> lockToStart;
  final ValueNotifier<bool> lockToEnd;
  final ValueNotifier<int> realStartPage;
  final ValueNotifier<int> realEndPage;

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

  // Use a small fraction of the viewport as tolerance so the edge lock still
  // works even when `position.pixels` is slightly off due to fractional pages.
  static const double _epsFraction = 0.02; // 2% of viewport

  double _edgeEps(ScrollMetrics position) {
    final vp = position.viewportDimension;
    if (vp.isFinite && vp > 0) return vp * _epsFraction;
    return 8.0;
  }

  double _startPx(ScrollMetrics position) => realStartPage.value * position.viewportDimension;

  double _endPx(ScrollMetrics position) => realEndPage.value * position.viewportDimension;

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // Hard clamp the scroll extents for the real content pages.
    // This prevents even a tiny drag into the sentinel pages at either end.
    final startPx = _startPx(position);
    final endPx = _endPx(position);
    if (lockToStart.value && value < startPx) {
      return value - startPx;
    }
    if (lockToEnd.value && value > endPx) {
      return value - endPx;
    }
    return super.applyBoundaryConditions(position, value);
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // When locked at an edge, hard-disable drag in the forbidden direction
    // to keep the page perfectly still (no tiny bounce/peek).
    if (lockToStart.value && offset > 0) return 0.0;
    if (lockToEnd.value && offset < 0) return 0.0;

    final startPx = _startPx(position);
    final endPx = _endPx(position);
    final eps = _edgeEps(position);

    if (lockToStart.value && position.pixels <= startPx + eps && offset > 0) {
      return 0.0;
    }
    if (lockToEnd.value && position.pixels >= endPx - eps && offset < 0) {
      return 0.0;
    }
    return super.applyPhysicsToUserOffset(position, offset);
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    // 依赖默认的 PageScrollPhysics 弹性处理。
    // 方向锁主要通过 [applyPhysicsToUserOffset] + 边界条件完成，
    // 这里不额外阻断，以避免误伤合法方向的正常滑动。
    return super.createBallisticSimulation(position, velocity);
  }
}