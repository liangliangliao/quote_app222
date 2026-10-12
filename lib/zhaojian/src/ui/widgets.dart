import 'package:flutter/material.dart';

const Color zAccent = Color(0xFF2C5D70);
const Color zInk = Color(0xFF2B2B2B);
const Color zMuted = Color(0xFF8A7F6E);
const Color zCard = Color(0xFFF6F3EE);
const Color zWarn = Color(0xFFA65D28);
const Color zChipOn = Color(0xFFD7E5EA);

/// 带标题的一块内容。
class ZSection extends StatelessWidget {
  const ZSection({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                title!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: zInk,
                ),
              ),
            ),
          ...children,
        ],
      ),
    );
  }
}

/// 小字说明。
class ZNote extends StatelessWidget {
  const ZNote(this.text, {super.key, this.warn = false});

  final String text;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          height: 1.5,
          color: warn ? zWarn : zMuted,
        ),
      ),
    );
  }
}

/// 一块带左边线的内容（对应原型里的 .it）。
class ZItem extends StatelessWidget {
  const ZItem({super.key, required this.child, this.warn = false});

  final Widget child;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: warn ? zWarn : zAccent, width: 3),
        ),
      ),
      child: child,
    );
  }
}

/// 单选：点中的下标。selected 为 null 表示都没选。
Widget zChoice({
  required List<String> labels,
  required int? selected,
  required void Function(int index) onSelect,
}) {
  return Wrap(
    spacing: 6,
    runSpacing: 2,
    children: <Widget>[
      for (int i = 0; i < labels.length; i++)
        ChoiceChip(
          label: Text(labels[i], style: const TextStyle(fontSize: 13)),
          selected: selected == i,
          selectedColor: zChipOn,
          onSelected: (_) => onSelect(i),
        ),
    ],
  );
}

/// 多选：selected 里是被选中的文字。
Widget zMulti({
  required List<String> labels,
  required Iterable<String> selected,
  required void Function(String label) onToggle,
}) {
  final Set<String> on = selected.toSet();
  return Wrap(
    spacing: 6,
    runSpacing: 2,
    children: <Widget>[
      for (final String l in labels)
        FilterChip(
          label: Text(l, style: const TextStyle(fontSize: 13)),
          selected: on.contains(l),
          selectedColor: zChipOn,
          onSelected: (_) => onToggle(l),
        ),
    ],
  );
}

/// 横条：value 在 0 到 1。
class ZBar extends StatelessWidget {
  const ZBar({super.key, required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final double v = value.isNaN ? 0 : value.clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 12, color: zMuted)),
          const SizedBox(height: 2),
          LinearProgressIndicator(
            value: v,
            minHeight: 8,
            backgroundColor: const Color(0xFFE3E0D8),
            valueColor: const AlwaysStoppedAnimation<Color>(zAccent),
          ),
        ],
      ),
    );
  }
}

InputDecoration zInput(String hint) {
  return InputDecoration(
    hintText: hint,
    isDense: true,
    border: const OutlineInputBorder(),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
  );
}

void zSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

String zPercent(double? v) {
  if (v == null) return '-';
  return '${(v * 100).round()}%';
}
