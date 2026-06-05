import 'package:flutter/material.dart';

import 'belief_action_models.dart';
import 'belief_dao.dart';

class BeliefActionTemplateEditorPage extends StatefulWidget {
  final String conceptId;
  final String conceptTitle;
  final BeliefActionTemplate? initial;

  const BeliefActionTemplateEditorPage({
    super.key,
    required this.conceptId,
    required this.conceptTitle,
    this.initial,
  });

  @override
  State<BeliefActionTemplateEditorPage> createState() => _BeliefActionTemplateEditorPageState();
}

class _BeliefActionTemplateEditorPageState extends State<BeliefActionTemplateEditorPage> {
  final _dao = BeliefDao();

  late final TextEditingController _title;
  late final TextEditingController _version;
  late final TextEditingController _category;
  late final TextEditingController _op;
  late final TextEditingController _success;
  late final TextEditingController _refSeg;
  late final TextEditingController _learnTags;
  late final TextEditingController _change;

  String _mode = 'quick';
  final List<TextEditingController> _steps = [];

  @override
  void initState() {
    super.initState();
    final t = widget.initial;

    _title = TextEditingController(text: t?.title ?? '');
    _version = TextEditingController(text: t?.version.isNotEmpty == true ? t!.version : '基础版');
    _category = TextEditingController(text: t?.categoryPath ?? '');
    _op = TextEditingController(text: t?.operationalDefinition ?? '');
    _success = TextEditingController(text: t?.successCriteria ?? '');
    _refSeg = TextEditingController(text: (t?.refSegmentKeys ?? const []).join(','));
    _learnTags = TextEditingController(text: (t?.learningTags ?? const []).join(','));
    _change = TextEditingController(text: t?.changePath ?? '');

    _mode = t?.mode ?? 'quick';

    final initSteps = (t?.actionChecklist ?? const <String>[]).isEmpty
        ? const <String>['']
        : (t!.actionChecklist);

    for (final s in initSteps) {
      _steps.add(TextEditingController(text: s));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _version.dispose();
    _category.dispose();
    _op.dispose();
    _success.dispose();
    _refSeg.dispose();
    _learnTags.dispose();
    _change.dispose();
    for (final c in _steps) {
      c.dispose();
    }
    super.dispose();
  }

  String _newId() {
    // stable enough in local
    return 'u_${DateTime.now().millisecondsSinceEpoch}';
  }

  List<String> _splitComma(String s) {
    return s
        .split(RegExp('[,，]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final category = _category.text.trim();
    final op = _op.text.trim();
    final success = _success.text.trim();

    final steps = _steps.map((c) => c.text.trim()).where((e) => e.isNotEmpty).toList();

    if (title.isEmpty || category.isEmpty || op.isEmpty || success.isEmpty || steps.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少填写：标题、类别、操作性定义、成功判据、以及≥1条行动步骤。')),
      );
      return;
    }

    final id = widget.initial?.id ?? _newId();

    final t = BeliefActionTemplate(
      id: id,
      conceptId: widget.conceptId,
      title: title,
      version: _version.text.trim().isEmpty ? '基础版' : _version.text.trim(),
      categoryPath: category,
      mode: _mode,
      operationalDefinition: op,
      successCriteria: success,
      actionChecklist: steps,
      refSegmentKeys: _splitComma(_refSeg.text),
      learningTags: _splitComma(_learnTags.text),
      changePath: _change.text.trim(),
    );

    final key = 'actiontpl:${widget.conceptId}:$id';

    await _dao.upsertProgress(
      key,
      status: 0,
      payload: {
        'title': t.title,
        'subtitle': '${widget.conceptTitle} · ${t.modeLabel} · ${t.version}',
        'template': t.toJson(),
        'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
      },
    );

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '编辑模板' : '新建模板'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        children: [
          _field('模板标题', _title, hint: '例：工作：桌面启动改造（30分钟）'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _field('版本', _version, hint: '基础版/进阶版/困难版…')),
              const SizedBox(width: 12),
              Expanded(
                child: _modeField(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _field('类别（概念树路径）', _category, hint: '例：工作/效率/桌面启动'),
          const SizedBox(height: 12),
          _field('操作性定义（概念→行动）', _op, hint: '用1-3句话把概念翻译成可执行动作', maxLines: 4),
          const SizedBox(height: 12),
          _field('成功判据（如何验证一致性）', _success, hint: '例：完成≥3次练习；记录证据；评分提升', maxLines: 4),
          const SizedBox(height: 12),
          _stepsEditor(),
          const SizedBox(height: 12),
          _field('参考段落（可选，逗号分隔）', _refSeg, hint: '例：L6#21,L6#22'),
          const SizedBox(height: 12),
          _field('学习标签（可选，逗号分隔）', _learnTags, hint: '例：强化,刺激控制'),
          const SizedBox(height: 12),
          _field('改变路径（可选）', _change, hint: '若涉及坏习惯：触发→替代→强化→复盘', maxLines: 4),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '提示：\n- “操作性定义”与“成功判据”决定了概念与行动是否一致。\n- 类别路径用于未来做概念树与推荐。\n- 参考段落用于回溯 57 段资料库。',
              style: TextStyle(color: Colors.black.withOpacity(0.7), height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeField() {
    return InputDecorator(
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        labelText: '行动模式',
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _mode,
          items: const [
            DropdownMenuItem(value: 'planned', child: Text('计划模式')),
            DropdownMenuItem(value: 'quick', child: Text('非计划模式')),
          ],
          onChanged: (v) => setState(() => _mode = v ?? 'quick'),
        ),
      ),
    );
  }

  Widget _stepsEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('行动步骤（清单）', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...List.generate(_steps.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _steps[i],
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: '步骤 ${i + 1}',
                    ),
                    maxLines: 2,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    if (_steps.length <= 1) {
                      _steps[i].text = '';
                      setState(() {});
                      return;
                    }
                    final c = _steps.removeAt(i);
                    c.dispose();
                    setState(() {});
                  },
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              ],
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: () {
            _steps.add(TextEditingController(text: ''));
            setState(() {});
          },
          icon: const Icon(Icons.add),
          label: const Text('新增步骤'),
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController c, {String? hint, int maxLines = 1}) {
    return TextField(
      controller: c,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: label,
        hintText: hint,
        alignLabelWithHint: maxLines > 1,
      ),
      maxLines: maxLines,
    );
  }
}

