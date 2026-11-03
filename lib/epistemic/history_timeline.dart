import 'package:flutter/material.dart';
import '../models/quote_insight.dart';
import '../widgets/quote_calligraphy_text.dart';

DateTime? quoteRecordedAt(Map<String, dynamic> row) {
  final inserted = DateTime.tryParse('${row['inserted_at'] ?? ''}');
  if (inserted != null) return inserted.toLocal();
  final raw = row['created_at'];
  if (raw is num && raw > 0)
    return DateTime.fromMillisecondsSinceEpoch(raw.toInt()).toLocal();
  return DateTime.tryParse('$raw')?.toLocal();
}

class QuoteTimelineEntry {
  final Map<String, dynamic> row;
  final DateTime? time;
  final int inputPosition;
  QuoteTimelineEntry(this.row, this.inputPosition)
      : time = quoteRecordedAt(row);
  QuoteReference get quote => QuoteReference.fromRow(row);
  String get instanceId => (row['quote_uid'] ?? row['fixed_uid'] ?? '').toString().isNotEmpty
      ? 'uid:${row['quote_uid'] ?? row['fixed_uid']}'
      : row['id'] != null ? 'row:${row['id']}' : 'position:$inputPosition:${quote.contentKey}';
  DateTime? get day =>
      time == null ? null : DateTime(time!.year, time!.month, time!.day);
}

class QuoteTimelineDay {
  final DateTime? day;
  final List<QuoteTimelineEntry> entries;
  const QuoteTimelineDay(this.day, this.entries);
  String get label =>
      day == null ? '记录时间未知' : '${day!.year}年${day!.month}月${day!.day}日';
}

/// One direction everywhere: oldest to newest, unknown dates last. Equal
/// timestamps use stable record identity and remain labelled simultaneous.
List<QuoteTimelineDay> groupTimelineRows(List<Map<String, dynamic>> rows) {
  final groups = <DateTime?, List<QuoteTimelineEntry>>{};
  for (final indexed in rows.indexed) {
    final entry = QuoteTimelineEntry(indexed.$2, indexed.$1);
    groups.putIfAbsent(entry.day, () => []).add(entry);
  }
  final days = groups.keys.toList()
    ..sort((a, b) => a == null
        ? 1
        : b == null
            ? -1
            : a.compareTo(b));
  return [
    for (final day in days)
      QuoteTimelineDay(
          day,
          groups[day]!
            ..sort((a, b) {
              final compared = a.time == null || b.time == null
                  ? 0
                  : a.time!.compareTo(b.time!);
              return compared != 0
                  ? compared
                  : a.instanceId.compareTo(b.instanceId);
            }))
  ];
}

class QuoteHistoryTimeline extends StatefulWidget {
  final List<Map<String, dynamic>> rows;
  final Set<String> selectedKeys;
  final void Function(Map<String, dynamic>) onOpen, onSelect;
  final Widget? controls;
  final bool hasMore, loading;
  final VoidCallback onLoadMore;
  const QuoteHistoryTimeline(
      {super.key,
      required this.rows,
      required this.selectedKeys,
      required this.onOpen,
      required this.onSelect,
      this.controls,
      required this.hasMore,
      required this.loading,
      required this.onLoadMore});
  @override
  State<QuoteHistoryTimeline> createState() => _QuoteHistoryTimelineState();
}

class _QuoteHistoryTimelineState extends State<QuoteHistoryTimeline> {
  String? _focusKey;
  final _scroll = ScrollController();
  @override
  void dispose() { _scroll.dispose(); super.dispose(); }
  String _relative(QuoteTimelineEntry entry, QuoteTimelineEntry focus) {
    if (entry.time == null) return '未标时';
    if (entry.instanceId == focus.instanceId) return '此刻';
    if (focus.time == null) return '已标时';
    if (entry.time == focus.time) return '同刻';
    final day = entry.day!, other = focus.day!;
    final delta = DateTime.utc(day.year, day.month, day.day)
        .difference(DateTime.utc(other.year, other.month, other.day))
        .inDays;
    if (delta == -1) return '前一日';
    if (delta < -1) return delta >= -9 ? '前${-delta}日' : '更早';
    if (delta > 0) return delta <= 9 ? '后$delta日' : '更后';
    return entry.time!.isBefore(focus.time!) ? '前一刻' : '后续';
  }

  @override
  Widget build(BuildContext context) {
    final groups = groupTimelineRows(widget.rows);
    final entries = groups.expand((g) => g.entries).toList();
    final known = groups.where((g) => g.day != null).lastOrNull?.entries ?? [];
    final focus =
        entries.where((e) => e.instanceId == _focusKey).firstOrNull ??
            (known.isNotEmpty
                ? known[known.length > 1 ? 1 : 0]
                : entries.firstOrNull);
    final pieces = <Widget>[
      const TimelineScenicHeader(),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('从早到晚 · “此刻”是所选记录的参照点', style: TextStyle(fontSize: 11))),
      Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }, child: const Text('定位已加载的最新记录'))),
      if (widget.controls != null) widget.controls!,
      if (entries.isEmpty)
        const Padding(
            padding: EdgeInsets.all(28), child: Text('暂无匹配名言，可先导入或保存名言。')),
    ];
    var ordinal = 0;
    for (final group in groups) {
      pieces.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                        colors: [Color(0xffe8def6), Color(0xfff0eaf9)])),
                child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(
                          group.day == null
                              ? Icons.help_outline
                              : Icons.calendar_month_outlined,
                          size: 18,
                          color: const Color(0xff75648d)),
                      Text(group.label,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ])),
          )));
      for (final entry in group.entries) {
        final selected = widget.selectedKeys.contains(entry.quote.contentKey);
        final focused = focus?.instanceId == entry.instanceId;
        final number = ++ordinal;
        pieces.add(_TimelineRecord(
            entry: entry,
            number: number,
            relative: _relative(entry, focus!),
            focused: focused,
            selected: selected,
            onFocus: () => setState(() => _focusKey = entry.instanceId),
            onOpen: () => widget.onOpen(entry.row),
            onSelect: () => widget.onSelect(entry.row)));
      }
    }
    if (widget.hasMore)
      pieces.add(Padding(
          padding: const EdgeInsets.all(12),
          child: TextButton.icon(
              onPressed: widget.loading ? null : widget.onLoadMore,
              icon: const Icon(Icons.expand_more),
              label: Text(widget.loading ? '正在读取' : '加载更多名言'))));
    pieces.add(const SizedBox(height: 20));
    return ColoredBox(
        color: const Color(0xfffcfaff),
        child: ListView.builder(
            key: const PageStorageKey('quote-history-timeline-scroll'),
            controller: _scroll,
            padding: EdgeInsets.zero,
            itemCount: pieces.length,
            itemBuilder: (_, i) => pieces[i]));
  }
}

class _TimelineRecord extends StatelessWidget {
  final QuoteTimelineEntry entry;
  final int number;
  final String relative;
  final bool focused, selected;
  final VoidCallback onFocus, onOpen, onSelect;
  const _TimelineRecord(
      {required this.entry,
      required this.number,
      required this.relative,
      required this.focused,
      required this.selected,
      required this.onFocus,
      required this.onOpen,
      required this.onSelect});
  @override
  Widget build(BuildContext context) {
    final quote = entry.quote;
    final large = MediaQuery.textScalerOf(context).scale(14) > 21;
    final ordinal =
        number <= 20 ? String.fromCharCode(0x2460 + number - 1) : '$number';
    final button = IconButton(
        tooltip: selected ? '取消比较选择' : '加入比较',
        onPressed: onSelect,
        color: const Color(0xff655b76),
        icon: Icon(selected ? Icons.check_circle : Icons.add_circle_outline));
    final text = Text(quote.content,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontSize: 16,
            height: 1.4,
            color: const Color(0xff282330),
            fontFamily: quotePrefersLiteraryEnglish(quote.content)
                ? quoteLiterarySerifFont
                : null));
    final author = Text(quote.author.isEmpty ? '作者待考' : quote.author,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            fontSize: 12, height: 1.4, color: Color(0xff726b7b)));
    final badge = SizedBox(
        width: 56,
        child: Center(
            child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                decoration: BoxDecoration(
                    color: focused
                        ? const Color(0xffe4d9f6)
                        : const Color(0xfff7f4fb),
                    border: Border.all(color: const Color(0xffe0d9e9)),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('$ordinal $relative',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xff746781))))));
    final dot = Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
                width: 2,
                color: focused
                    ? const Color(0xffa087cf)
                    : const Color(0xffc0b0db)),
            boxShadow: focused
                ? [
                    const BoxShadow(
                        color: Color(0xffd1bafa),
                        blurRadius: 7,
                        spreadRadius: 3)
                  ]
                : null));
    final focusButton = Semantics(
        button: true,
        selected: focused,
        label: '第$number条，$relative，设为时间参照',
        child: Tooltip(
            message: '以此条记录为“此刻”查看先后',
            child: InkResponse(
                key: ValueKey(
                    'timeline-node-${quote.id.isEmpty ? entry.instanceId : quote.id}'),
                radius: 24,
                onTap: onFocus,
                child: SizedBox(
                    width: 32, height: 48, child: Center(child: dot)))));
    final node = SizedBox(
        width: 32,
        child: CustomPaint(
            painter: _TimelineRibbonPainter(known: entry.time != null),
            child: Center(child: focusButton)));
    final content = Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 7, 11),
        child: large
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                text,
                const SizedBox(height: 6),
                Row(children: [Expanded(child: author), button])
              ])
            : Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [text, const SizedBox(height: 5), author])),
                button
              ]));
    final card = Expanded(
        child: Container(
            margin: const EdgeInsets.only(left: 4, top: 4, bottom: 12),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xfffaf7ff), Color(0xfff6f3fb)]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: selected
                        ? const Color(0xffa38ac8)
                        : const Color(0xffe4dbef),
                    width: 1.2),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xff75628b).withValues(alpha: .12),
                      blurRadius: 9,
                      offset: const Offset(0, 4))
                ]),
            child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                    key: ValueKey(
                        'timeline-quote-${quote.id.isEmpty ? entry.instanceId : quote.id}'),
                    borderRadius: BorderRadius.circular(16),
                    onTap: onOpen,
                    child: content))));
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: IntrinsicHeight(
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [badge, node, card])));
  }
}

class TimelineScenicHeader extends StatelessWidget {
  const TimelineScenicHeader({super.key});
  Widget _portrait() => ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => const LinearGradient(
          colors: [Colors.transparent, Colors.white],
          stops: [0, .65]).createShader(rect),
      child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.white, Colors.transparent],
              stops: [0, .6, 1]).createShader(rect),
          child: Opacity(
              opacity: .4,
              child: ColorFiltered(
                  colorFilter: const ColorFilter.matrix([
                    .08,
                    .28,
                    .04,
                    0,
                    155,
                    .08,
                    .28,
                    .04,
                    0,
                    150,
                    .08,
                    .28,
                    .04,
                    0,
                    169,
                    0,
                    0,
                    0,
                    1,
                    0
                  ]),
                  child: Image.asset('assets/avatars/schopenhauer.jpg',
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (_, __, ___) =>
                          const SizedBox.shrink())))));
  @override
  Widget build(BuildContext context) => Container(
      key: const ValueKey('timeline-scenic-header'),
      constraints: const BoxConstraints(minHeight: 110),
      child: Stack(children: [
        const Positioned.fill(
            child: CustomPaint(painter: _TimelineLandscapePainter())),
        Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            width: 120,
            child: ExcludeSemantics(child: _portrait())),
        Padding(
            padding: const EdgeInsets.fromLTRB(12, 18, 65, 18),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(
                  width: 46,
                  height: 56,
                  child: CustomPaint(painter: _HourglassPainter())),
              Container(
                  width: 1,
                  height: 38,
                  margin: const EdgeInsets.fromLTRB(6, 6, 12, 0),
                  color: const Color(0xffbfb0d2)),
              const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    Text('时间线 · 以继起呈现先后',
                        style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text('只记录先后，不证明思想之间存在因果',
                        style: TextStyle(
                            fontSize: 11,
                            height: 1.5,
                            color: Color(0xff82768e))),
                  ])),
            ])),
      ]));
}

class _TimelineRibbonPainter extends CustomPainter {
  final bool known;
  const _TimelineRibbonPainter({required this.known});
  @override
  void paint(Canvas canvas, Size size) {
    if (!known) return;
    final w = size.width, h = size.height;
    Path curve(double drift) => Path()
      ..moveTo(w / 2 + drift, 0)
      ..cubicTo(w * 1.3 + drift, h * .23, w / 2 + drift, h * .36, w / 2 + drift,
          h * .5)
      ..cubicTo(
          w / 2 + drift, h * .67, -w * .15 + drift, h * .78, w / 2 + drift, h);
    for (final layer in [(0.0, 13.0, .08), (1.5, 7.0, .12), (-1.5, 3.0, .2)]) {
      canvas.drawPath(
          curve(layer.$1),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = layer.$2
            ..color = const Color(0xffaa8ad6).withValues(alpha: layer.$3)
            ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_TimelineRibbonPainter old) => old.known != known;
}

class _TimelineLandscapePainter extends CustomPainter {
  const _TimelineLandscapePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height, w = size.width;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xfffbf8ff),
                Color(0xfff4eefb),
                Color(0xfffcfaff)
              ]).createShader(Offset.zero & size));
    for (var i = 0; i < 3; i++) {
      final y = h * (.7 + i * .09);
      final path = Path()
        ..moveTo(0, y)
        ..quadraticBezierTo(w * .17, y - 17, w * .3, y + 2)
        ..lineTo(w * .45, y - 12)
        ..lineTo(w * .54, y - 7)
        ..lineTo(w * .68, y - 25)
        ..lineTo(w * .8, y - 13)
        ..lineTo(w, y + 5)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(
          path,
          Paint()
            ..color =
                const Color(0xffbda9d4).withValues(alpha: .05 + i * .025));
    }
  }

  @override
  bool shouldRepaint(_TimelineLandscapePainter old) => false;
}

class _HourglassPainter extends CustomPainter {
  const _HourglassPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width,
        h = size.height,
        middle = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
        middle,
        w / 2,
        Paint()
          ..shader = const RadialGradient(
                  colors: [Color(0xffe0d3f3), Color(0x00e0d3f3)])
              .createShader(Offset.zero & size));
    final pen = Paint()
      ..color = const Color(0xff9b87b6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final path = Path()
      ..moveTo(w * .24, h * .18)
      ..cubicTo(w * .24, h * .39, w * .39, h * .4, w * .5, h * .5)
      ..cubicTo(w * .6, h * .62, w * .77, h * .64, w * .77, h * .84)
      ..lineTo(w * .23, h * .84)
      ..cubicTo(w * .23, h * .64, w * .4, h * .62, w * .5, h * .5)
      ..cubicTo(w * .6, h * .4, w * .76, h * .39, w * .76, h * .18)
      ..close();
    canvas.drawPath(path, pen);
    canvas.drawOval(Rect.fromLTWH(w * .2, h * .13, w * .6, h * .09), pen);
    canvas.drawOval(Rect.fromLTWH(w * .19, h * .81, w * .62, h * .09), pen);
    canvas.drawPath(
        Path()
          ..moveTo(w * .3, h * .78)
          ..quadraticBezierTo(w * .5, h * .6, w * .7, h * .78)
          ..close(),
        Paint()..color = const Color(0xffb19acb).withValues(alpha: .5));
    canvas.drawLine(middle, Offset(w / 2, h * .67), pen..strokeWidth = .7);
  }

  @override
  bool shouldRepaint(_HourglassPainter old) => false;
}
