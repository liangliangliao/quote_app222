import 'dart:io';

import 'package:flutter/material.dart';

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
