import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'yangming_dao.dart';
import 'yangming_models.dart';

class YangmingContentImportPage extends StatefulWidget {
  final YangmingDao dao;
  final List<YangmingLesson> lessons;
  final Map<String, YangmingLessonContent> existingContents;
  final Future<void> Function() onChanged;

  const YangmingContentImportPage({
    super.key,
    required this.dao,
    required this.lessons,
    required this.existingContents,
    required this.onChanged,
  });

  @override
  State<YangmingContentImportPage> createState() => _YangmingContentImportPageState();
}

class _YangmingContentImportPageState extends State<YangmingContentImportPage> {
  final TextEditingController _rawCtrl = TextEditingController();
  bool _importing = false;
  String _result = '';
  late Map<String, YangmingLessonContent> _contents;

  Set<String> get _validLessonIds => widget.lessons.map((e) => e.id).toSet();

  @override
  void initState() {
    super.initState();
    _contents = Map<String, YangmingLessonContent>.from(widget.existingContents);
  }

  Future<void> _reloadContents() async {
    _contents = await widget.dao.loadLessonContents();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _rawCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['json', 'txt'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null || path.isEmpty) return;
    final raw = await File(path).readAsString();
    if (!mounted) return;
    setState(() => _rawCtrl.text = raw);
  }

  Future<void> _importRaw() async {
    final parsed = parseImportedLessonContents(_rawCtrl.text, _validLessonIds);
    if (parsed.isEmpty) {
      setState(() => _result = '没有解析到可导入内容。请检查 JSON 结构与 lessonId。');
      return;
    }
    setState(() => _importing = true);
    final normalized = parsed
        .map((e) => e.copyWith(source: e.source.isEmpty ? 'json_import' : e.source, updatedAt: DateTime.now().toIso8601String()))
        .toList();
    await widget.dao.saveLessonContentsBulk(normalized);
    await widget.onChanged();
    await _reloadContents();
    if (!mounted) return;
    setState(() {
      _importing = false;
      _result = '已导入 ${normalized.length} 段内容。';
    });
  }

  Future<void> _copyTemplate() async {
    final template = <String, dynamic>{
      'lessons': widget.lessons.take(3).map((lesson) => <String, dynamic>{
            'lessonId': lesson.id,
            'originalText': '在这里填入该段原文',
            'detailedExplanation': '在这里填入该段详细解释',
          }).toList(),
    };
    await Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(template)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制简易模板，可手动整理为合法 JSON。')));
  }

  Future<void> _openEditor(YangmingLesson lesson) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => YangmingLessonContentEditorPage(
          lesson: lesson,
          dao: widget.dao,
          initialContent: _contents[lesson.id],
        ),
      ),
    );
    await widget.onChanged();
    await _reloadContents();
  }

  @override
  Widget build(BuildContext context) {
    final importedCount = _contents.length;
    return Scaffold(
      appBar: AppBar(title: const Text('课程内容导入')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: <Widget>[
          _SimpleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('按原 PRD，这里用于导入 27 段对应的完整原文与详细解释。', style: TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF4B5563))),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    _StatChip(label: '课程总数', value: '${widget.lessons.length}'),
                    _StatChip(label: '已导入', value: '$importedCount'),
                    _StatChip(label: '待导入', value: '${widget.lessons.length - importedCount}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SimpleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('批量导入 JSON', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('支持两种结构：\n1. { "lessons": [ ... ] }\n2. [ { lessonId, originalText, detailedExplanation } ]', style: TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF6B7280))),
                const SizedBox(height: 12),
                TextField(
                  controller: _rawCtrl,
                  maxLines: 12,
                  decoration: InputDecoration(
                    hintText: '[{"lessonId":"ZX-01","originalText":"...","detailedExplanation":"..."}]',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    FilledButton.icon(onPressed: _importing ? null : _importRaw, icon: _importing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.file_upload_outlined), label: const Text('导入 JSON')),
                    OutlinedButton.icon(onPressed: _pickFile, icon: const Icon(Icons.attach_file_outlined), label: const Text('选择文件')),
                    OutlinedButton.icon(onPressed: _copyTemplate, icon: const Icon(Icons.copy_all_outlined), label: const Text('复制模板说明')),
                  ],
                ),
                if (_result.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(_result, style: const TextStyle(fontSize: 13, color: Color(0xFF1D4ED8))),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SimpleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('逐段编辑', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('如果你不想一次性导入全部内容，也可以逐段手动粘贴。', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                const SizedBox(height: 12),
                ...widget.lessons.map((lesson) {
                  final content = _contents[lesson.id];
                  final imported = content?.hasAnyContent ?? false;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(lesson.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(lesson.source, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                              const SizedBox(height: 6),
                              Text(imported ? '已导入内容' : '尚未导入', style: TextStyle(fontSize: 12, color: imported ? const Color(0xFF059669) : const Color(0xFF9CA3AF))),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(onPressed: () => _openEditor(lesson), child: Text(imported ? '编辑' : '导入')),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class YangmingLessonContentEditorPage extends StatefulWidget {
  final YangmingLesson lesson;
  final YangmingDao dao;
  final YangmingLessonContent? initialContent;

  const YangmingLessonContentEditorPage({
    super.key,
    required this.lesson,
    required this.dao,
    required this.initialContent,
  });

  @override
  State<YangmingLessonContentEditorPage> createState() => _YangmingLessonContentEditorPageState();
}

class _YangmingLessonContentEditorPageState extends State<YangmingLessonContentEditorPage> {
  late final TextEditingController _originalCtrl = TextEditingController(text: widget.initialContent?.originalText ?? '');
  late final TextEditingController _explanationCtrl = TextEditingController(text: widget.initialContent?.detailedExplanation ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _originalCtrl.dispose();
    _explanationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final content = YangmingLessonContent(
      lessonId: widget.lesson.id,
      originalText: _originalCtrl.text.trim(),
      detailedExplanation: _explanationCtrl.text.trim(),
      source: 'manual_editor',
      updatedAt: DateTime.now().toIso8601String(),
    );
    await widget.dao.saveLessonContent(content);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
  }

  Future<void> _clear() async {
    await widget.dao.deleteLessonContent(widget.lesson.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('编辑内容 · ${widget.lesson.id}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: <Widget>[
          _SimpleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(widget.lesson.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(widget.lesson.source, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _EditorBlock(label: '完整原文', controller: _originalCtrl, minLines: 8),
          const SizedBox(height: 12),
          _EditorBlock(label: '详细解释', controller: _explanationCtrl, minLines: 8),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined), label: const Text('保存内容')),
              OutlinedButton.icon(onPressed: _clear, icon: const Icon(Icons.delete_outline), label: const Text('清空此段内容')),
            ],
          ),
        ],
      ),
    );
  }
}

class _SimpleCard extends StatelessWidget {
  final Widget child;
  const _SimpleCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: child,
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(999)),
      child: Text('$label：$value', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _EditorBlock extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int minLines;
  const _EditorBlock({required this.label, required this.controller, this.minLines = 6});

  @override
  Widget build(BuildContext context) {
    return _SimpleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            minLines: minLines,
            maxLines: null,
            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
          ),
        ],
      ),
    );
  }
}
