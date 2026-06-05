import 'dart:convert';
import 'package:flutter/material.dart';

/// A minimal dynamic form renderer.
///
/// Supported field types:
/// - text
/// - textarea
/// - number
/// - list_text
/// - choice
class FpTemplateForm extends StatefulWidget {
  final String schemaJson;
  final Map<String, dynamic>? initial;
  final void Function(Map<String, dynamic> result) onSubmit;
  final String submitText;

  const FpTemplateForm({
    super.key,
    required this.schemaJson,
    this.initial,
    required this.onSubmit,
    this.submitText = '保存',
  });

  @override
  State<FpTemplateForm> createState() => _FpTemplateFormState();
}

class _FpTemplateFormState extends State<FpTemplateForm> {
  final _formKey = GlobalKey<FormState>();
  late Map<String, dynamic> _model;

  @override
  void initState() {
    super.initState();
    _model = Map<String, dynamic>.from(widget.initial ?? {});
  }

  List<Map<String, dynamic>> _fields() {
    try {
      final m = jsonDecode(widget.schemaJson);
      if (m is Map && m['fields'] is List) {
        return (m['fields'] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      }
    } catch (_) {}
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final fields = _fields();
    return Form(
      key: _formKey,
      child: Column(
        children: [
          for (final f in fields) ...[
            _buildField(context, f),
            const SizedBox(height: 12),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () {
                if (!(_formKey.currentState?.validate() ?? false)) return;
                _formKey.currentState?.save();
                widget.onSubmit(_model);
              },
              child: Text(widget.submitText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(BuildContext context, Map<String, dynamic> f) {
    final id = (f['id'] ?? '').toString();
    final label = (f['label'] ?? '').toString();
    final type = (f['type'] ?? 'text').toString();
    final hint = (f['hint'] ?? '').toString();

    if (type == 'list_text') {
      final items = (_model[id] is List) ? List<String>.from(_model[id]) : <String>[];
      return _ListTextEditor(
        label: label,
        hint: hint,
        initial: items,
        onChanged: (xs) => setState(() => _model[id] = xs),
      );
    }

    if (type == 'choice') {
      final options = (f['options'] is List) ? (f['options'] as List).map((e) => e.toString()).toList() : <String>[];
      final cur = (_model[id] ?? '').toString();
      return InputDecorator(
        decoration: InputDecoration(labelText: label, helperText: hint.isEmpty ? null : hint),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: options.contains(cur) ? cur : (options.isNotEmpty ? options.first : null),
            isExpanded: true,
            items: [
              for (final o in options) DropdownMenuItem(value: o, child: Text(o)),
            ],
            onChanged: (v) => setState(() => _model[id] = v ?? ''),
          ),
        ),
      );
    }

    final controller = TextEditingController(text: (_model[id] ?? '').toString());
    final isNumber = type == 'number';
    final isArea = type == 'textarea';
    return TextFormField(
      controller: controller,
      maxLines: isArea ? 6 : 1,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint.isEmpty ? null : hint,
        border: const OutlineInputBorder(),
      ),
      validator: (v) {
        if (isNumber && (v ?? '').trim().isNotEmpty) {
          final n = num.tryParse((v ?? '').trim());
          if (n == null) return '请输入数字';
          final min = f['min'];
          final max = f['max'];
          if (min is num && n < min) return '最小为 $min';
          if (max is num && n > max) return '最大为 $max';
        }
        return null;
      },
      onSaved: (v) {
        if (isNumber) {
          final n = num.tryParse((v ?? '').trim());
          _model[id] = n;
        } else {
          _model[id] = (v ?? '');
        }
      },
    );
  }
}

class _ListTextEditor extends StatefulWidget {
  final String label;
  final String hint;
  final List<String> initial;
  final void Function(List<String>) onChanged;

  const _ListTextEditor({
    required this.label,
    required this.hint,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<_ListTextEditor> createState() => _ListTextEditorState();
}

class _ListTextEditorState extends State<_ListTextEditor> {
  late List<String> _items;

  @override
  void initState() {
    super.initState();
    _items = List<String>.from(widget.initial);
    if (_items.isEmpty) _items.add('');
  }

  void _emit() {
    widget.onChanged(_items.where((e) => e.trim().isNotEmpty).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w700)),
        if (widget.hint.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(widget.hint, style: TextStyle(color: Colors.black.withOpacity(0.6))),
        ],
        const SizedBox(height: 8),
        for (int i = 0; i < _items.length; i++) ...[
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _items[i],
                  decoration: InputDecoration(
                    hintText: '第 ${i + 1} 条',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    _items[i] = v;
                    _emit();
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  setState(() {
                    _items.removeAt(i);
                    if (_items.isEmpty) _items.add('');
                  });
                  _emit();
                },
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              setState(() => _items.add(''));
            },
            icon: const Icon(Icons.add),
            label: const Text('添加一条'),
          ),
        ),
      ],
    );
  }
}
