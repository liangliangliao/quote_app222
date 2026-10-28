import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'journey_design.dart';

/// The room stays mounted while its quotation changes. Toolbar and reading
/// controls are outside the painting, so they never cover its text.
class QuoteHomeScene extends StatelessWidget {
  const QuoteHomeScene({
    super.key,
    required this.poster,
    required this.moreMenu,
    required this.onMenu,
    required this.onSearch,
    required this.onPin,
    required this.onNext,
    required this.onFavorite,
    required this.onCategories,
    required this.onShare,
    required this.onPinnedQuotes,
    required this.onHistory,
    this.favorite = false,
    this.pinned = false,
    this.nextBusy = false,
    this.pinnedCount = 0,
    this.historyCount = 1,
    this.historyIndex = 0,
    this.date,
  });
  final Widget poster, moreMenu;
  final VoidCallback onMenu,
      onSearch,
      onPin,
      onNext,
      onFavorite,
      onCategories,
      onShare,
      onPinnedQuotes;
  final ValueChanged<int> onHistory;
  final bool favorite, pinned, nextBusy;
  final int pinnedCount, historyCount, historyIndex;
  final DateTime? date;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final width = bounds.maxWidth;
      final inset = MediaQuery.paddingOf(context).top;
      final textScale = MediaQuery.textScalerOf(context).scale(30) / 30;
      final stackedHeader =
          (width < 360 && textScale > 1.1) || (width < 450 && textScale > 1.35);
      final extraTextHeight =
          (MediaQuery.textScalerOf(context).scale(30) - 30) * 2 +
          (stackedHeader ? 45 : 0);
      final minimumHeight = inset + 590 + extraTextHeight;
      final height = math.max(bounds.maxHeight, minimumHeight);
      final headerTop = inset + 68;
      final mastheadBottom = headerTop + 65 + extraTextHeight;
      final dockTop = height - 85;
      final maxSceneHeight = (dockTop - mastheadBottom - 48) / .702;
      final sceneWidth = math.min(
        math.min(width * 1.08, 620.0),
        maxSceneHeight / 1.5,
      );
      final sceneHeight = sceneWidth * 1.5;
      final sceneTop = mastheadBottom + 34 - sceneHeight * .111;
      final today = date ?? DateTime.now();
      const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
      final content = SizedBox(
        height: height,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            const Positioned.fill(child: ColoredBox(color: Color(0xfff7f4ed))),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: sceneTop + 110,
              child: const JourneyHeaderBackdrop(flip: true, opacity: .45),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 145,
              child: _RoomDeskBackdrop(),
            ),
            Positioned(
              top: sceneTop,
              left: (width - sceneWidth) / 2,
              width: sceneWidth,
              height: sceneHeight,
              child: RepaintBoundary(child: poster),
            ),
            Positioned(
              left: 13,
              right: 13,
              top: inset + 7,
              child: Row(
                children: [
                  _roundButton('home-menu', '打开卡片', Icons.menu_rounded, onMenu),
                  const Spacer(),
                  _roundButton(
                    'home-search',
                    '搜索名言',
                    Icons.search_rounded,
                    onSearch,
                  ),
                  const SizedBox(width: 10),
                  _roundButton(
                    'home-pin',
                    pinned ? '取消固定' : '固定名言',
                    pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                    onPin,
                  ),
                  const SizedBox(width: 10),
                  _buttonSurface(
                    SizedBox(width: 39, height: 39, child: moreMenu),
                  ),
                ],
              ),
            ),
            Positioned(
              left: math.max(30, (width - 620) / 2 + 42),
              right: math.max(28, (width - 620) / 2 + 33),
              top: headerTop,
              child: _HomeMasthead(
                today: today,
                weekdays: weekdays,
                stacked: stackedHeader,
              ),
            ),
            Positioned(
              bottom: 91,
              left: 18,
              right: 18,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < math.min(historyCount, 6); i++)
                    Semantics(
                      button: true,
                      selected: i == historyIndex,
                      label: '第 ${i + 1} 条已读名言',
                      child: InkResponse(
                        onTap: () => onHistory(i),
                        radius: 15,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 6,
                          ),
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == historyIndex
                                  ? const Color(0xff7b7b63)
                                  : Colors.transparent,
                              border: Border.all(
                                color: const Color(0xff9f9b80),
                                width: .8,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (pinnedCount > 0) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      key: const ValueKey('home-pinned-collection'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: onPinnedQuotes,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.push_pin_outlined,
                              size: 12,
                              color: Color(0xff777e68),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '固定集 · $pinnedCount',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xff777e68),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              left: width * .085,
              right: width * .085,
              bottom: 17,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0x99eee8dc),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: const Color(0x99ffffff)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 9,
                      ),
                      child: Row(
                        children: [
                          _action(
                            'home-next',
                            '换一条',
                            Icons.shuffle_rounded,
                            onNext,
                            busy: nextBusy,
                          ),
                          _action(
                            'home-favorite',
                            favorite ? '已收藏' : '收藏',
                            favorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            onFavorite,
                            selected: favorite,
                          ),
                          _action(
                            'home-categories',
                            '分类',
                            Icons.menu_book_outlined,
                            onCategories,
                          ),
                          _action(
                            'home-share',
                            '分享',
                            Icons.share_outlined,
                            onShare,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      return height > bounds.maxHeight + .5
          ? SingleChildScrollView(
              key: const PageStorageKey('home-small-screen'),
              child: content,
            )
          : content;
    },
  );

  Widget _buttonSurface(Widget child) => Material(
    color: const Color(0xf5ffffff),
    shape: const CircleBorder(),
    elevation: 1.5,
    shadowColor: const Color(0x22968c70),
    child: child,
  );

  Widget _roundButton(
    String key,
    String tooltip,
    IconData icon,
    VoidCallback onTap,
  ) => _buttonSurface(
    IconButton(
      key: ValueKey(key),
      tooltip: tooltip,
      icon: Icon(icon, color: const Color(0xff414b40), size: 21),
      onPressed: onTap,
      constraints: const BoxConstraints.tightFor(width: 39, height: 39),
      padding: EdgeInsets.zero,
    ),
  );

  Widget _action(
    String key,
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool selected = false,
    bool busy = false,
  }) => Expanded(
    child: Semantics(
      button: true,
      label: label,
      selected: selected,
      child: InkWell(
        key: ValueKey(key),
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xfffaf8f1),
                shape: BoxShape.circle,
              ),
              child: busy
                  ? const Padding(
                      padding: EdgeInsets.all(9),
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: journeyGreen,
                      ),
                    )
                  : Icon(
                      icon,
                      size: 21,
                      color: selected ? journeyGreen : const Color(0xff938875),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xff776e5e),
                fontSize: 10.5,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RoomDeskBackdrop extends StatelessWidget {
  const _RoomDeskBackdrop();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.white],
          stops: [0, .4],
        ).createShader(bounds),
        child: LayoutBuilder(
          builder: (context, bounds) => ClipRect(
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: -bounds.maxHeight * .88 / .12,
                  height: bounds.maxHeight / .12,
                  child: Image.asset(
                    'assets/bg-white-gallery.png',
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _HomeMasthead extends StatelessWidget {
  const _HomeMasthead({
    required this.today,
    required this.weekdays,
    required this.stacked,
  });
  final DateTime today;
  final List<String> weekdays;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    const heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '名人名言',
          key: ValueKey('home-heading'),
          style: TextStyle(
            fontFamily: 'QuoteKaiShu',
            fontSize: 30,
            height: 1.18,
            color: journeyInk,
            letterSpacing: 1.5,
          ),
        ),
        SizedBox(height: 6),
        Text(
          '一句话，照亮前行的路。',
          style: TextStyle(
            fontFamily: 'QuoteKaiShu',
            fontSize: 13,
            color: Color(0xff7c8272),
            height: 1.4,
          ),
        ),
      ],
    );
    final date = Text(
      '${today.month.toString().padLeft(2, '0')} / ${today.day.toString().padLeft(2, '0')}',
      style: const TextStyle(
        fontFamily: 'QuoteLiterarySerif',
        fontStyle: FontStyle.italic,
        color: Color(0xff4e503e),
        fontSize: 17,
      ),
    );
    final weekday = Text(
      '周${weekdays[today.weekday - 1]}',
      style: const TextStyle(
        fontFamily: 'QuoteKaiShu',
        color: Color(0xff8a8c7b),
        fontSize: 11,
      ),
    );
    if (stacked)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [date, const SizedBox(width: 10), weekday],
          ),
          const SizedBox(height: 7),
          heading,
        ],
      );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Padding(padding: EdgeInsets.only(top: 11), child: heading),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            date,
            const SizedBox(height: 4),
            weekday,
            const SizedBox(height: 10),
            const Text(
              '生活不在别处，\n就在此刻。',
              style: TextStyle(
                fontFamily: 'QuoteKaiShu',
                color: Color(0xff90927f),
                fontSize: 9,
                height: 1.35,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
