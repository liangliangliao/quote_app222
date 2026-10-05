import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'evidence_growth_form_drafts.dart';
import 'evidence_growth_guidance.dart';
import 'evidence_growth_journey_models.dart';

typedef GrowthFormLoader = Future<GrowthData> Function(bool refresh);

class GrowthSmartForm extends StatefulWidget {
  const GrowthSmartForm({
    super.key,
    required this.title,
    required this.fields,
    this.initial = const {},
    this.fieldOrigins = const {},
    this.requiredKeys = const [],
    this.contextData = const {},
    this.loader,
    this.boundary,
    this.source = '用户记录／确认',
    this.sourceReason = '',
  });
  final String title, source, sourceReason;
  final Map<String, String> fields, initial, fieldOrigins;
  final List<String> requiredKeys;
  final GrowthData contextData;
  final GrowthFormLoader? loader;
  final String? boundary;
  static Future<Map<String, String>?> show(
    BuildContext context, {
    required String title,
    required Map<String, String> fields,
    Map<String, String> initial = const {},
    Map<String, String> fieldOrigins = const {},
    List<String> requiredKeys = const [],
    GrowthData contextData = const {},
    GrowthFormLoader? loader,
    String? boundary,
    String source = '用户记录／确认',
    String sourceReason = '',
  }) =>
      showDialog<Map<String, String>>(
        context: context,
        builder: (_) => GrowthSmartForm(
          title: title,
          fields: fields,
          initial: initial,
          fieldOrigins: fieldOrigins,
          requiredKeys: requiredKeys,
          contextData: contextData,
          loader: loader,
          boundary: boundary,
          source: source,
          sourceReason: sourceReason,
        ),
      );
  @override
  State<GrowthSmartForm> createState() => _SmartFormState();
}

class _SmartFormState extends State<GrowthSmartForm> {
  late final defaults = GrowthFormDrafts.defaults(
    widget.fields,
    widget.contextData,
  );
  late final controllers = {
    for (final k in widget.fields.keys)
      k: TextEditingController(
        text: (widget.initial[k] ?? '').trim().isNotEmpty
            ? widget.initial[k]
            : defaults[k],
      ),
  };
  late final origins = {
    for (final k in widget.fields.keys)
      k: (widget.initial[k] ?? '').trim().isNotEmpty
          ? (widget.fieldOrigins[k] ?? widget.source)
          : '默认建议 · 待核对',
  };
  final dirty = <String>{};
  bool loading = false;
  late bool checked = widget.boundary == null;
  late String reason = widget.sourceReason;
  @override
  void initState() {
    super.initState();
    if (widget.loader != null) unawaited(fill(false));
  }

  @override
  void dispose() {
    for (final c in controllers.values) c.dispose();
    super.dispose();
  }

  Future<void> fill(bool refresh) async {
    if (loading) return;
    setState(() => loading = true);
    try {
      final result = await widget.loader!(refresh);
      if (!mounted) return;
      final values = growthMap(result['fields']);
      setState(() {
        reason = '${result['reason'] ?? ''}';
        for (final k in widget.fields.keys) {
          // Never clobber a user edit or an already recorded value, including during a slow response.
          if (dirty.contains(k) || (widget.initial[k] ?? '').trim().isNotEmpty)
            continue;
          if (values[k] is String) {
            controllers[k]!.text = values[k] as String;
            origins[k] = GrowthGuidance.label(result['origin'] as String?);
          }
        }
      });
    } catch (_) {
      if (mounted) setState(() => reason = 'AI 预填暂未完成，本地草案仍可修改。');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget field(String key) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TextFormField(
          key: ValueKey('form_$key'),
          controller: controllers[key],
          minLines: 1,
          maxLines: 4,
          onChanged: (_) => setState(() => dirty.add(key)),
          decoration: InputDecoration(
            labelText: widget.fields[key]!.replaceAll('（可选）', ''),
            alignLabelWithHint: true,
            helperText: dirty.contains(key) ? '你已修改' : origins[key],
            helperMaxLines: 2,
            border: const OutlineInputBorder(),
          ),
        ),
      );
  @override
  Widget build(BuildContext context) {
    final primary = widget.requiredKeys.isEmpty
        ? widget.fields.keys.take(3).toList()
        : widget.requiredKeys;
    final extra =
        widget.fields.keys.where((k) => !primary.contains(k)).toList();
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('先看最重要的几项。草案已备好，可直接改成符合你的说法；更多细节也已预填。'),
              if (loading) const LinearProgressIndicator(),
              if (reason.isNotEmpty) Text(reason),
              for (final k in primary) field(k),
              if (extra.isNotEmpty)
                ExpansionTile(
                  title: Text('更多细节（${extra.length} 项，已预填可修改）'),
                  children: [for (final k in extra) field(k)],
                ),
              if (widget.loader != null)
                TextButton.icon(
                  onPressed: loading ? null : () => fill(true),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('AI 重新补齐未修改项'),
                ),
              if (widget.boundary != null) Text(widget.boundary!),
              if (widget.boundary != null)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: checked,
                  onChanged: (v) => setState(() => checked = v ?? false),
                  title: Text(
                    widget.boundary == null
                        ? '我已核对草案，未知内容仍保留为未知'
                        : '我已核对知识前提和边界，未知条件先查证',
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: !checked ||
                  widget.requiredKeys.any(
                    (k) => controllers[k]!.text.trim().isEmpty,
                  )
              ? null
              : () => Navigator.pop(context, {
                    for (final e in controllers.entries)
                      e.key: e.value.text.trim(),
                    '_field_origins': jsonEncode({
                      for (final k in widget.fields.keys)
                        k: dirty.contains(k) ? 'USER_EDITED' : origins[k],
                    }),
                  }),
          child: const Text('确认并继续'),
        ),
      ],
    );
  }
}
