import 'package:flutter/material.dart';

const osForest = Color(0xFF244D43);
const osPaper = Color(0xFFF6F5EF);
const osGold = Color(0xFFB58143);

class SelfOsTheme extends StatelessWidget {
  const SelfOsTheme({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
              seedColor: osForest,
              brightness: Brightness.light,
              surface: osPaper),
          scaffoldBackgroundColor: osPaper,
          appBarTheme: const AppBarTheme(
              backgroundColor: osPaper,
              foregroundColor: osForest,
              elevation: 0,
              centerTitle: false),
          inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFDDE4DE))),
              contentPadding: const EdgeInsets.all(14)),
          textTheme: Theme.of(context).textTheme.apply(
              bodyColor: const Color(0xFF263C35),
              displayColor: const Color(0xFF263C35)),
        ),
        child: child,
      );
}

class OsSection extends StatelessWidget {
  const OsSection(
      {super.key,
      required this.title,
      this.subtitle,
      required this.children,
      this.trailing});
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE3E7DF))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700))),
            if (trailing != null) trailing!
          ]),
          if (subtitle != null)
            Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(subtitle!,
                    style: const TextStyle(
                        color: Color(0xFF68786E), height: 1.5, fontSize: 13))),
          const SizedBox(height: 14),
          ...children,
        ]),
      );
}

class OsNote extends StatelessWidget {
  const OsNote(this.text, {super.key, this.icon = Icons.info_outline});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFEDF2EC),
            borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: osForest),
          const SizedBox(width: 9),
          Expanded(
              child:
                  Text(text, style: const TextStyle(fontSize: 13, height: 1.5)))
        ]),
      );
}

class OsScore extends StatelessWidget {
  const OsScore(
      {super.key,
      required this.label,
      required this.value,
      required this.onChanged,
      this.max = 100,
      this.help});
  final String label;
  final String? help;
  final double? value;
  final double max;
  final ValueChanged<double?> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(
                value == null
                    ? '未记录'
                    : '${value!.toStringAsFixed(0)}${max == 100 ? '%' : '/10'}',
                style: const TextStyle(color: osForest))
          ]),
          if (help != null)
            Text(help!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF68786E))),
          if (value == null)
            TextButton.icon(
                onPressed: () => onChanged(max / 2),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('记录我的估计'))
          else
            Row(children: [
              Expanded(
                  child: Slider(
                      semanticFormatterCallback: (v) => '${v.round()}',
                      value: value!.clamp(0, max),
                      max: max,
                      divisions: max.toInt(),
                      onChanged: onChanged)),
              IconButton(
                  tooltip: '清除估计，保留未知',
                  onPressed: () => onChanged(null),
                  icon: const Icon(Icons.close, size: 18))
            ]),
        ]),
      );
}

void osMessage(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
String osDate(DateTime date) =>
    '${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

Future<Map<String, String>?> osEditDialog(BuildContext context,
        {required String title,
        required Map<String, String> labels,
        Map<String, String> initial = const {},
        Set<String> requiredFields = const {},
        String? hint}) =>
    showDialog<Map<String, String>>(
        context: context,
        builder: (_) => _OsEditDialog(
            title: title,
            labels: labels,
            initial: initial,
            requiredFields: requiredFields,
            hint: hint));

class _OsEditDialog extends StatefulWidget {
  const _OsEditDialog(
      {required this.title,
      required this.labels,
      required this.initial,
      required this.requiredFields,
      this.hint});
  final String title;
  final Map<String, String> labels, initial;
  final Set<String> requiredFields;
  final String? hint;
  @override
  State<_OsEditDialog> createState() => _OsEditDialogState();
}

class _OsEditDialogState extends State<_OsEditDialog> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers = {
    for (final key in widget.labels.keys)
      key: TextEditingController(text: widget.initial[key] ?? '')
  };
  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: SizedBox(
            width: 480,
            child: Form(
                key: _form,
                child: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (widget.hint != null) OsNote(widget.hint!),
                  for (final entry in widget.labels.entries)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                            key: ValueKey('dialog_${entry.key}'),
                            controller: _controllers[entry.key],
                            minLines: 1,
                            maxLines: 4,
                            maxLength: 3000,
                            decoration: InputDecoration(
                                labelText: entry.value, counterText: ''),
                            validator: (v) =>
                                widget.requiredFields.contains(entry.key) &&
                                        (v ?? '').trim().isEmpty
                                    ? '请填写${entry.value}'
                                    : null)),
                ])))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
              onPressed: () {
                if (_form.currentState!.validate())
                  Navigator.pop(context,
                      _controllers.map((k, v) => MapEntry(k, v.text.trim())));
              },
              child: const Text('保存'))
        ],
      );
}
