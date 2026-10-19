import 'package:flutter/material.dart';
import 'self_os_models.dart';
import 'self_os_widgets.dart';

class OsInput {
  const OsInput(this.keyName, this.label,
      {this.options,
      this.required = false,
      this.kind = 'text',
      this.hint,
      this.max = 100});
  final String keyName, label, kind;
  final String? hint;
  final Map<String, String>? options;
  final bool required;
  final double max;
}

Future<Map<String, dynamic>?> osRecordEditor(
  BuildContext context, {
  required String title,
  required List<OsInput> fields,
  Map<String, dynamic> initial = const {},
  String? note,
  String? Function(Map<String, dynamic>)? validate,
}) =>
    showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _OsRecordEditor(
            title: title,
            fields: fields,
            initial: initial,
            note: note,
            validate: validate));

class _OsRecordEditor extends StatefulWidget {
  const _OsRecordEditor(
      {required this.title,
      required this.fields,
      required this.initial,
      this.note,
      this.validate});
  final String title;
  final String? note;
  final List<OsInput> fields;
  final Map<String, dynamic> initial;
  final String? Function(Map<String, dynamic>)? validate;
  @override
  State<_OsRecordEditor> createState() => _OsRecordEditorState();
}

class _OsRecordEditorState extends State<_OsRecordEditor> {
  final _form = GlobalKey<FormState>();
  late final values = osClone(widget.initial);
  late final controllers = <String, TextEditingController>{
    for (final f
        in widget.fields.where((f) => f.options == null && f.kind != 'bool'))
      f.keyName: TextEditingController(
          text: values[f.keyName] == null ? '' : '${values[f.keyName]}')
  };
  String? error;
  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> pickMoment(OsInput f) async {
    final now = DateTime.now();
    final existing =
        DateTime.tryParse(controllers[f.keyName]!.text)?.toLocal() ?? now;
    final day = await showDatePicker(
        context: context,
        initialDate:
            existing.year < 2000 || existing.year > 2100 ? now : existing,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100, 12, 31));
    if (day == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(existing));
    if (time == null || !mounted) return;
    controllers[f.keyName]!.text =
        DateTime(day.year, day.month, day.day, time.hour, time.minute)
            .toIso8601String();
  }

  void save() {
    if (!_form.currentState!.validate()) return;
    for (final f in widget.fields) {
      if (f.options != null || f.kind == 'bool') continue;
      final text = controllers[f.keyName]!.text.trim();
      values[f.keyName] = f.kind == 'number' ? osNumber(text, f.max) : text;
    }
    final invalid = widget.validate?.call(values);
    if (invalid != null) {
      setState(() => error = invalid);
      return;
    }
    Navigator.pop(context, values);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: SizedBox(
            width: 540,
            child: Form(
                key: _form,
                child: SingleChildScrollView(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      if (widget.note != null) OsNote(widget.note!),
                      for (final f in widget.fields)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: f.kind == 'bool'
                                ? SwitchListTile.adaptive(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(f.label),
                                    value: values[f.keyName] == true,
                                    onChanged: (v) =>
                                        setState(() => values[f.keyName] = v))
                                : f.options != null
                                    ? DropdownButtonFormField<String>(
                                        key: ValueKey('v37_edit_${f.keyName}'),
                                        isExpanded: true,
                                        initialValue: f.options!
                                                .containsKey(values[f.keyName])
                                            ? values[f.keyName] as String
                                            : null,
                                        decoration:
                                            InputDecoration(labelText: f.label),
                                        items: f.options!.entries
                                            .map((e) => DropdownMenuItem(
                                                value: e.key,
                                                child: Text(e.value,
                                                    overflow:
                                                        TextOverflow.ellipsis)))
                                            .toList(),
                                        onChanged: (v) => setState(
                                            () => values[f.keyName] = v),
                                        validator: (v) =>
                                            f.required && (v ?? '').isEmpty
                                                ? '请选择${f.label}'
                                                : null,
                                      )
                                    : TextFormField(
                                        key: ValueKey('v37_edit_${f.keyName}'),
                                        controller: controllers[f.keyName],
                                        minLines: 1,
                                        maxLines: f.kind == 'text' ? 4 : 1,
                                        maxLength:
                                            f.kind == 'text' ? 5000 : 100,
                                        keyboardType: f.kind == 'number'
                                            ? const TextInputType
                                                .numberWithOptions(
                                                decimal: true)
                                            : TextInputType.multiline,
                                        decoration: InputDecoration(
                                            labelText: f.label,
                                            hintText: f.hint,
                                            counterText: '',
                                            suffixIcon: f.kind == 'datetime'
                                                ? IconButton(
                                                    tooltip: '选择日期和时间',
                                                    onPressed: () =>
                                                        pickMoment(f),
                                                    icon:
                                                        const Icon(Icons.event))
                                                : null),
                                        validator: (v) {
                                          final text = (v ?? '').trim();
                                          if (f.required && text.isEmpty)
                                            return '请填写${f.label}';
                                          if (text.isNotEmpty &&
                                              f.kind == 'number') {
                                            final n = double.tryParse(text);
                                            if (n == null ||
                                                !n.isFinite ||
                                                n < 0 ||
                                                n > f.max)
                                              return '请输入 0–${f.max.toInt()}，未知可留空';
                                          }
                                          if (text.isNotEmpty &&
                                              f.kind == 'datetime' &&
                                              DateTime.tryParse(text) == null)
                                            return '请选择有效日期和时间';
                                          return null;
                                        },
                                      )),
                      if (error != null)
                        Text(error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                    ])))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(onPressed: save, child: const Text('保存'))
        ],
      );
}

class OsPill extends StatelessWidget {
  const OsPill(this.text, {super.key, this.color = osForest});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(8)),
        child: Text(text,
            style: TextStyle(
                color: color,
                fontSize: 11,
                height: 1.4,
                fontWeight: FontWeight.w600)),
      );
}

class OsRecordCard extends StatelessWidget {
  const OsRecordCard(
      {super.key,
      required this.title,
      required this.children,
      this.onEdit,
      this.tag});
  final String title;
  final String? tag;
  final List<Widget> children;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: osPaper,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE3E7DF))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, height: 1.5))),
            if (onEdit != null)
              IconButton(
                  onPressed: onEdit,
                  tooltip: '编辑$title',
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  visualDensity: VisualDensity.compact),
          ]),
          if (tag != null)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: OsPill(tag!)),
          ...children,
        ]),
      );
}

String osMoment(DateTime? time) {
  if (time == null) return '尚未安排';
  final t = time.toLocal();
  return '${t.month}月${t.day}日 ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
