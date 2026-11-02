import 'package:flutter/material.dart';

class CognitiveInputField {
  final String keyName, label, initialValue;
  final bool required;
  const CognitiveInputField(this.keyName, this.label,
      {this.initialValue = '', this.required = true});
}

/// Controllers live until the dialog route is actually removed, including its
/// closing animation, rather than being disposed when Navigator.pop completes.
class CognitiveInputDialog extends StatefulWidget {
  final String title, description, submitLabel;
  final List<CognitiveInputField> fields;
  const CognitiveInputDialog(
      {super.key,
      required this.title,
      required this.description,
      required this.submitLabel,
      required this.fields});
  @override
  State<CognitiveInputDialog> createState() => _CognitiveInputDialogState();
}

class _CognitiveInputDialogState extends State<CognitiveInputDialog> {
  late final _controllers = {
    for (final f in widget.fields)
      f.keyName: TextEditingController(text: f.initialValue)
  };
  bool _validate = false;
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
              width: 420,
              child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(widget.description),
                for (final f in widget.fields)
                  TextField(
                      controller: _controllers[f.keyName],
                      minLines: 2,
                      maxLines: 5,
                      maxLength: 8000,
                      decoration: InputDecoration(
                          labelText: f.label,
                          errorText: _validate &&
                                  f.required &&
                                  _controllers[f.keyName]!.text.trim().isEmpty
                              ? '请填写这项内容'
                              : null)),
              ]))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消')),
            FilledButton(
                onPressed: () {
                  if (widget.fields.any((f) =>
                      f.required &&
                      _controllers[f.keyName]!.text.trim().isEmpty)) {
                    setState(() => _validate = true);
                    return;
                  }
                  Navigator.pop(context, {
                    for (final f in widget.fields)
                      f.keyName: _controllers[f.keyName]!.text.trim()
                  });
                },
                child: Text(widget.submitLabel))
          ]);
}
