import 'package:flutter/material.dart';

import '../data/models.dart';
import '../domain/controller.dart';

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

/// 一个页面的外壳：标题、控制器变化时重建、统一的边距。
class ZPage extends StatelessWidget {
  const ZPage({
    super.key,
    required this.title,
    required this.controller,
    required this.content,
  });

  final String title;
  final ZhaojianController controller;
  final List<Widget> Function(BuildContext context) content;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext ctx, Widget? child) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(title),
            backgroundColor: Colors.white,
            foregroundColor: zInk,
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: content(ctx),
          ),
        );
      },
    );
  }
}

/// 表单里的一个输入框。
class ZFieldSpec {
  const ZFieldSpec(this.key, this.hint, {this.lines = 1});

  final String key;
  final String hint;
  final int lines;
}

/// 一组输入框加一个提交按钮；提交成功后清空。
/// [required] 里的键必须非空；留空则要求至少有一个框非空。
class ZForm extends StatefulWidget {
  const ZForm({
    super.key,
    required this.fields,
    required this.submitLabel,
    required this.onSubmit,
    this.required = const <String>[],
  });

  final List<ZFieldSpec> fields;
  final String submitLabel;
  final Future<void> Function(Map<String, String> values) onSubmit;
  final List<String> required;

  @override
  State<ZForm> createState() => _ZFormState();
}

class _ZFormState extends State<ZForm> {
  late final Map<String, TextEditingController> _c =
      <String, TextEditingController>{
    for (final ZFieldSpec f in widget.fields) f.key: TextEditingController(),
  };

  @override
  void dispose() {
    for (final TextEditingController c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final Map<String, String> v = <String, String>{
      for (final MapEntry<String, TextEditingController> e in _c.entries)
        e.key: e.value.text.trim(),
    };
    final bool ok = widget.required.isEmpty
        ? v.values.any((String t) => t.isNotEmpty)
        : widget.required.every((String k) => (v[k] ?? '').isNotEmpty);
    if (!ok) {
      zSnack(context, '先写点内容');
      return;
    }
    await widget.onSubmit(v);
    if (!mounted) return;
    for (final TextEditingController c in _c.values) {
      c.clear();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final ZFieldSpec f in widget.fields) ...<Widget>[
          TextField(
            controller: _c[f.key],
            minLines: 1,
            maxLines: f.lines,
            decoration: zInput(f.hint),
          ),
          const SizedBox(height: 8),
        ],
        FilledButton(onPressed: _submit, child: Text(widget.submitLabel)),
      ],
    );
  }
}

/// 「这个行为表达了哪条主线」的选择：点假设，再选表达或背离；再点一次取消。
Widget zHypPicker({
  required List<ZHypothesis> hyps,
  required int? current,
  required String kind,
  required void Function(int? hypId, String kind) onChange,
}) {
  final List<ZHypothesis> shown =
      hyps.length > 6 ? hyps.sublist(hyps.length - 6) : hyps;
  if (shown.isEmpty) return const SizedBox.shrink();
  final int idx = current == null
      ? -1
      : shown.indexWhere((ZHypothesis h) => h.id == current);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      const ZNote('这个行为表达了哪条主线？（可选，会自动计入该假设的支持或反驳）'),
      zChoice(
        labels: shown.map((ZHypothesis h) => h.text).toList(),
        selected: idx < 0 ? null : idx,
        onSelect: (int i) {
          final int? hid = shown[i].id;
          onChange(current == hid ? null : hid, kind);
        },
      ),
      if (current != null)
        zChoice(
          labels: <String>['表达了它', '背离了它'],
          selected: kind == 'ref' ? 1 : 0,
          onSelect: (int i) => onChange(current, i == 0 ? 'sup' : 'ref'),
        ),
    ],
  );
}
