import 'dart:io';

import 'package:flutter/material.dart';

import 'artwork.dart';
import 'local_recognition.dart';
import 'region_geometry.dart';

Future<String?> askForName(
  BuildContext context, {
  required String title,
  required String field,
  String initial = '',
}) =>
    showDialog<String>(
      context: context,
      builder: (context) =>
          _NameDialog(title: title, field: field, initial: initial),
    );

class _NameDialog extends StatefulWidget {
  const _NameDialog(
      {required this.title, required this.field, required this.initial});
  final String title;
  final String field;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final value = _text.text.trim();
    if (value.isNotEmpty) Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(
          controller: _text,
          autofocus: true,
          maxLength: 60,
          decoration: InputDecoration(labelText: widget.field),
          onSubmitted: (_) => _save(),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ListenableBuilder(
            listenable: _text,
            builder: (context, _) => FilledButton(
              onPressed: _text.text.trim().isEmpty ? null : _save,
              child: const Text('保存'),
            ),
          ),
        ],
      );
}

typedef RuleTrial = Future<void> Function(
    ImageRegion region, TouchAction action);

Future<ImageRegion?> editRegionRules(
        BuildContext context, ImageRegion region, RuleTrial tryAction) =>
    showModalBottomSheet<ImageRegion>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _RuleEditor(region: region, tryAction: tryAction),
    );

class _RuleEditor extends StatefulWidget {
  const _RuleEditor({required this.region, required this.tryAction});
  final ImageRegion region;
  final RuleTrial tryAction;

  @override
  State<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<_RuleEditor> {
  late ImageRegion _region = widget.region;
  late final _name = TextEditingController(text: widget.region.label);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('区域与手势', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              TextField(
                  controller: _name,
                  maxLength: 60,
                  decoration: const InputDecoration(
                      labelText: '区域名称', border: OutlineInputBorder())),
              DropdownButtonFormField<RegionGroup>(
                initialValue: _region.group,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: '部位分类', border: OutlineInputBorder()),
                items: [
                  for (final group in RegionGroup.values)
                    DropdownMenuItem(value: group, child: Text(group.label))
                ],
                onChanged: (group) =>
                    setState(() => _region = _region.copyWith(group: group)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('启用互动'),
                value: _region.enabled,
                onChanged: (enabled) => setState(
                    () => _region = _region.copyWith(enabled: enabled)),
              ),
              Row(
                children: [
                  Expanded(child: Text('触摸优先级  ${_region.priority}')),
                  IconButton(
                    tooltip: '降低优先级',
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _region.priority <= -10
                        ? null
                        : () => setState(() => _region =
                            _region.copyWith(priority: _region.priority - 1)),
                  ),
                  IconButton(
                    tooltip: '提高优先级',
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _region.priority >= 10
                        ? null
                        : () => setState(() => _region =
                            _region.copyWith(priority: _region.priority + 1)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final gesture in TouchGesture.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<TouchAction>(
                          initialValue: _region.rules[gesture],
                          isExpanded: true,
                          hint: const Text('无反馈'),
                          decoration: InputDecoration(
                              labelText: gesture.label,
                              border: const OutlineInputBorder()),
                          items: [
                            const DropdownMenuItem(child: Text('无反馈')),
                            for (final action in TouchAction.values)
                              DropdownMenuItem(
                                  value: action, child: Text(action.label)),
                          ],
                          onChanged: (action) {
                            final rules = Map<TouchGesture, TouchAction>.of(
                                _region.rules);
                            if (action == null) {
                              rules.remove(gesture);
                            } else {
                              rules[gesture] = action;
                            }
                            setState(
                                () => _region = _region.copyWith(rules: rules));
                          },
                        ),
                      ),
                      IconButton(
                        tooltip: '试播${gesture.label}反馈',
                        icon: const Icon(Icons.play_circle_outline),
                        onPressed: _region.rules[gesture] == null
                            ? null
                            : () => widget.tryAction(
                                _region, _region.rules[gesture]!),
                      ),
                    ],
                  ),
                ),
              ListenableBuilder(
                listenable: _name,
                builder: (context, _) => FilledButton(
                  onPressed: _name.text.trim().isEmpty
                      ? null
                      : () {
                          final name = _name.text.trim();
                          final edited = _region.source.isAutomatic &&
                              (name != widget.region.label ||
                                  _region.group != widget.region.group);
                          Navigator.pop(
                              context,
                              _region.copyWith(
                                  label: name,
                                  source: edited ? RegionSource.manual : null));
                        },
                  child: const Text('保存规则'),
                ),
              ),
            ],
          ),
        ),
      );
}

Future<RecognitionTarget?> chooseRecognitionTarget(
  BuildContext context,
  File preview,
  double aspectRatio,
  List<RecognitionTarget> targets,
) =>
    showModalBottomSheet<RecognitionTarget>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('选择识别目标', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('图片里有多个候选，请点选一个目标。'),
              const SizedBox(height: 12),
              SizedBox(
                height: 236,
                child: LayoutBuilder(builder: (context, box) {
                  final rect = artworkRect(box.biggest, aspectRatio);
                  return ColoredBox(
                    color: const Color(0xFF131621),
                    child: Stack(children: [
                      Positioned.fromRect(
                          rect: rect,
                          child: Image.file(preview,
                              fit: BoxFit.fill, excludeFromSemantics: true)),
                      for (final (index, target) in targets.indexed) ...[
                        Positioned.fromRect(
                          rect: Rect.fromPoints(
                              imagePoint(target.bounds.topLeft, rect),
                              imagePoint(target.bounds.bottomRight, rect)),
                          child: IgnorePointer(
                              child: DecoratedBox(
                                  decoration: BoxDecoration(
                            border: Border.all(
                                color: const Color(0xFFA6F0DF), width: 1.5),
                            borderRadius: BorderRadius.circular(4),
                          ))),
                        ),
                        Positioned(
                          left: (imagePoint(target.bounds.center, rect).dx - 22)
                              .clamp(0.0, box.maxWidth - 44),
                          top: (imagePoint(target.bounds.center, rect).dy - 22)
                              .clamp(0.0, box.maxHeight - 44),
                          width: 44,
                          height: 44,
                          child: FloatingActionButton.small(
                            heroTag: null,
                            tooltip: _targetLabel(index, target),
                            onPressed: () => Navigator.pop(context, target),
                            child: Text('${index + 1}'),
                          ),
                        ),
                      ],
                    ]),
                  );
                }),
              ),
              for (final (index, target) in targets.indexed)
                ListTile(
                  title: Text(_targetLabel(index, target)),
                  subtitle: Text('${target.regions.length} 个候选区域'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, target),
                ),
            ],
          ),
        ),
      ),
    );

String _targetLabel(int index, RecognitionTarget target) =>
    '${target.handOnly ? '手部' : '人物'} ${index + 1}';
