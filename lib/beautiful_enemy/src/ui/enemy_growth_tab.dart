import 'package:flutter/material.dart';
import '../domain/enemy_engine.dart';
import '../domain/growth_profile.dart';
import '../data/models.dart';
import 'ui_helpers.dart';

class EnemyGrowthTab extends StatefulWidget {
  const EnemyGrowthTab({super.key, required this.engine, this.importer});
  final EnemyEngine engine;
  final GrowthProfileImporter? importer;
  @override
  State<EnemyGrowthTab> createState() => _EnemyGrowthTabState();
}

class _EnemyGrowthTabState extends State<EnemyGrowthTab> {
  EnemyGrowthProfile? _profile;
  List<Map<String, Object?>> _actions = [];
  bool _busy = false;
  String _error = '';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await widget.engine.settleOverdue();
      final p = await widget.engine.growth.load();
      final a = await widget.engine.growth.actions();
      if (mounted)
        setState(() {
          _profile = p;
          _actions = a;
        });
    } catch (_) {
      if (mounted) setState(() => _error = '档案读取失败，请下拉重试。');
    }
  }

  void _showError(Object e) {
    if (mounted)
      setState(() => _error = e is FormatException ? e.message : '操作未完成，请重试。');
  }

  Future<void> _edit({bool import = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      ({String name, String text})? document;
      if (import) {
        if (widget.importer == null)
          throw const FormatException('宿主尚未接入文件选择，可以先手动填写。');
        document = await widget.importer!();
        if (document == null) return;
      }
      if (!mounted) return;
      final profile = await Navigator.of(context).push<EnemyGrowthProfile>(
          MaterialPageRoute(
              builder: (_) => EnemyGrowthEditor(
                  profile: import ? null : _profile,
                  sourceName: document?.name,
                  extractedText: document?.text)));
      if (profile == null) return;
      await widget.engine.growth.save(profile);
      await _load();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _plan(GrowthWeakness w) async {
    final result = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) =>
            _GrowthActionEditor(engine: widget.engine, weakness: w)));
    if (result == true) await _load();
  }

  Future<void> _review(Map<String, Object?> a) async {
    final observation = await askText(context,
        title: '实际发生了什么？', hint: '写下具体行为和结果；自述不等于已验证的事实。');
    if (observation == null || observation.trim().isEmpty || !mounted) return;
    final adjustment =
        await askText(context, title: '下次怎样调整？', hint: '什么有效？遇到了什么障碍？下一步怎么改？');
    if (adjustment == null) return;
    try {
      await widget.engine.reviewGrowthAction(
          a['commitment_id'] as int, observation, adjustment);
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('删除成长档案？'),
                content:
                    const Text('原文、确认的弱点和关联复盘会删除。已接受的承诺保留在「字据」；已有对话内容仍在对话记录中。'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('取消')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('删除'))
                ]));
    if (ok != true) return;
    try {
      await widget.engine.growth.delete();
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    return RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('对人保持关爱，对事实保持诚实，对成长保持要求。',
              style: TextStyle(color: kEnemyAccent, height: 1.5)),
          const SizedBox(height: 12),
          const Text('我的弱点与成长档案',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('上传自我认识后，先核对提取文字，再确认希望改善的弱点。弱点是可修正的自述，你的价值不由它定义。',
              style: TextStyle(color: kEnemyMuted, height: 1.5)),
          const SizedBox(height: 8),
          const Text('原文件在本机读取；启用后，确认的条目和关联行动会随对话提供给设置中选择的 AI 服务。你可以编辑、停用或删除。',
              style: TextStyle(color: kEnemyMuted, height: 1.5)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            FilledButton.icon(
                onPressed: _busy ? null : () => _edit(import: true),
                icon: const Icon(Icons.upload_file),
                label: Text(p == null ? '上传弱点文件' : '上传并替换档案')),
            OutlinedButton(
                onPressed: _busy ? null : _edit,
                child: Text(p == null ? '手动填写' : '查看原文与编辑')),
          ]),
          const Text(
              '支持 txt、Word（doc/docx）、pdf，最多 12 MB / 60000 字。扫描 PDF 请先识别文字。',
              style: TextStyle(color: kEnemyMuted)),
          if (_busy) const LinearProgressIndicator(),
          if (_error.isNotEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_error,
                    style: const TextStyle(color: Colors.orangeAccent))),
          if (p != null) ...[
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('用于后续对话、挑战与复盘'),
                subtitle: Text('${p.sourceName} · 更新于 ${fmtTime(p.updatedMs)}'),
                value: p.enabled,
                onChanged: (v) async {
                  try {
                    await widget.engine.growth.setEnabled(v);
                    await _load();
                  } catch (e) {
                    _showError(e);
                  }
                }),
            if (p.values.isNotEmpty) Text('我重视的目标：${p.values}'),
            if (p.strengths.isNotEmpty) Text('可以依靠的优势：${p.strengths}'),
            for (final w in p.weaknesses)
              Card(
                  color: kEnemyCard,
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('我自述的弱点：${w.description}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text(
                                '希望改变：${w.goal.isEmpty ? '尚未填写，可在编辑中补充' : w.goal}'),
                            TextButton.icon(
                                onPressed: p.enabled ? () => _plan(w) : null,
                                icon: const Icon(Icons.flag_outlined),
                                label: const Text('为这个弱点制定行动')),
                          ]))),
            TextButton(onPressed: _delete, child: const Text('删除档案与弱点关联')),
          ],
          const SizedBox(height: 16),
          const Text('行动与复盘',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (_actions.isEmpty)
            const Text('选择一个弱点，约定小行动、截止时间、遇阻预案和验证证据。',
                style: TextStyle(color: kEnemyMuted)),
          for (final a in _actions)
            Card(
                color: kEnemyCard,
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('对应弱点：${a['weakness']}'),
                          Text('改变目标：${a['goal']}'),
                          Text('行动：${a['action']}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                              '截止：${fmtTime(a['due_ms'] as int)} · ${commitmentStatusLabels[a['status']] ?? a['status']}'),
                          Text('遇阻预案：${a['obstacle_plan']}'),
                          Text('验证证据：${a['evidence']}'),
                          if ((a['observation'] ?? '').toString().isNotEmpty)
                            Text('实际结果（自述）：${a['observation']}'),
                          if ((a['adjustment'] ?? '').toString().isNotEmpty)
                            Text('下一次调整：${a['adjustment']}'),
                          Wrap(spacing: 8, children: [
                            if (a['status'] == CommitmentStatus.open ||
                                a['status'] == CommitmentStatus.missed)
                              TextButton(
                                  onPressed: () async {
                                    try {
                                      await widget.engine
                                          .complete(a['commitment_id'] as int);
                                      await _load();
                                    } catch (e) {
                                      _showError(e);
                                    }
                                  },
                                  child: const Text('我已完成（自述）')),
                            TextButton(
                                onPressed: () => _review(a),
                                child: const Text('记录结果与调整')),
                          ]),
                        ]))),
        ]));
  }
}

class EnemyGrowthEditor extends StatefulWidget {
  const EnemyGrowthEditor(
      {super.key, this.profile, this.sourceName, this.extractedText});
  final EnemyGrowthProfile? profile;
  final String? sourceName;
  final String? extractedText;
  @override
  State<EnemyGrowthEditor> createState() => _EnemyGrowthEditorState();
}

class _WeaknessFields {
  _WeaknessFields(this.id, String description, String goal)
      : description = TextEditingController(text: description),
        goal = TextEditingController(text: goal);
  final String id;
  final TextEditingController description;
  final TextEditingController goal;
  void dispose() {
    description.dispose();
    goal.dispose();
  }
}

class _EnemyGrowthEditorState extends State<EnemyGrowthEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _text = TextEditingController(
      text: widget.extractedText ?? widget.profile?.originalText ?? '');
  late final TextEditingController _values =
      TextEditingController(text: widget.profile?.values ?? '');
  late final TextEditingController _strengths =
      TextEditingController(text: widget.profile?.strengths ?? '');
  late final List<_WeaknessFields> _items = widget.profile?.weaknesses
          .map((w) => _WeaknessFields(w.id, w.description, w.goal))
          .toList() ??
      [];
  String _error = '';
  int _serial = 0;
  void _add() => setState(() => _items.add(_WeaknessFields(
      '${DateTime.now().microsecondsSinceEpoch}_${_serial++}', '', '')));
  void _suggest() {
    final paragraphs = _text.text
        .split(RegExp(r'\n+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (paragraphs.isEmpty ||
        paragraphs.length > 20 ||
        paragraphs.any((s) => s.length > 500)) {
      setState(
          () => _error = '请先把原文整理为 1–20 段，每段不超过 500 字；也可以手动添加重点。不会截断或遗漏原文。');
      return;
    }
    setState(() {
      _error = '';
      for (final p in paragraphs) {
        _items.add(_WeaknessFields(
            '${DateTime.now().microsecondsSinceEpoch}_${_serial++}', p, ''));
      }
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _values.dispose();
    _strengths.dispose();
    for (final w in _items) {
      w.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    if (_items.isEmpty) {
      setState(() => _error = '请至少确认一个希望改善的弱点。');
      return;
    }
    Navigator.pop(
        context,
        EnemyGrowthProfile(
            sourceName:
                widget.sourceName ?? widget.profile?.sourceName ?? '手动填写',
            originalText: _text.text.trim(),
            weaknesses: _items
                .map((w) => GrowthWeakness(
                    id: w.id,
                    description: w.description.text.trim(),
                    goal: w.goal.text.trim()))
                .toList(),
            updatedMs: DateTime.now().millisecondsSinceEpoch,
            enabled: true,
            strengths: _strengths.text.trim(),
            values: _values.text.trim()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('核对并确认成长档案')),
      body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Text(
                '来源：${widget.sourceName ?? widget.profile?.sourceName ?? '手动填写'}'),
            const Text(
                '请核对提取结果，有乱码或遗漏可在此修正。仅下方亲自确认的条目用于后续活动。上传替换会保留已有承诺及历史行动。'),
            TextFormField(
                controller: _text,
                minLines: 4,
                maxLines: 8,
                maxLength: 60000,
                decoration: const InputDecoration(labelText: '原文预览（可编辑）')),
            TextFormField(
                controller: _values,
                maxLength: 500,
                decoration:
                    const InputDecoration(labelText: '我真正重视的目标 / 改变的理由（选填）')),
            TextFormField(
                controller: _strengths,
                maxLength: 500,
                decoration: const InputDecoration(labelText: '我的优势与可用支持（选填）')),
            OutlinedButton(
                onPressed: _items.isEmpty ? _suggest : null,
                child: const Text('从原文按段落整理候选弱点')),
            const Text('候选只是原文分段。请移除不属于弱点的内容，修正描述并补充希望改变的行为。'),
            const Text('逐项确认：我想改善什么',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            for (final w in _items)
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(children: [
                        TextFormField(
                            controller: w.description,
                            maxLength: 500,
                            maxLines: 3,
                            minLines: 1,
                            decoration: const InputDecoration(
                                labelText: '弱点原话 / 具体行为模式'),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? '请填写你确认的弱点'
                                : null),
                        TextFormField(
                            controller: w.goal,
                            maxLength: 300,
                            decoration:
                                const InputDecoration(labelText: '希望改变的具体行为'),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? '请说明希望改变什么行为'
                                : null),
                        TextButton(
                            onPressed: () {
                              setState(() => _items.remove(w));
                              WidgetsBinding.instance
                                  .addPostFrameCallback((_) => w.dispose());
                            },
                            child: const Text('移除此项')),
                      ]))),
            OutlinedButton(
                onPressed: _items.length >= 20 ? null : _add,
                child: const Text('添加一项弱点')),
            if (_error.isNotEmpty)
              Text(_error, style: const TextStyle(color: Colors.orange)),
            const Text('保存表示同意：后续活动参考这些自述和关联行动；AI 功能使用设置中选择的服务。你可随时停用或删除。'),
            FilledButton(onPressed: _save, child: const Text('确认保存并用于后续活动')),
          ])));
}

class _GrowthActionEditor extends StatefulWidget {
  const _GrowthActionEditor({required this.engine, required this.weakness});
  final EnemyEngine engine;
  final GrowthWeakness weakness;
  @override
  State<_GrowthActionEditor> createState() => _GrowthActionEditorState();
}

class _GrowthActionEditorState extends State<_GrowthActionEditor> {
  final _form = GlobalKey<FormState>();
  final _action = TextEditingController();
  final _obstacle = TextEditingController();
  final _evidence = TextEditingController();
  late DateTime _due =
      DateTime.fromMillisecondsSinceEpoch(widget.engine.nowMs())
          .add(const Duration(hours: 2));
  bool _saving = false;
  String _error = '';
  @override
  void dispose() {
    _action.dispose();
    _obstacle.dispose();
    _evidence.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.engine.addGrowthAction(
          weakness: widget.weakness,
          action: _action.text,
          obstaclePlan: _obstacle.text,
          evidence: _evidence.text,
          due: _due);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        setState(
            () => _error = e is FormatException ? e.message : '保存未完成，请重试。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(TextEditingController c, String label, int max) =>
      TextFormField(
          controller: c,
          maxLength: max,
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(labelText: label),
          validator: (v) => v == null || v.trim().isEmpty ? '请填写这一项' : null);
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('从认识到行动')),
      body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Text('对应弱点：${widget.weakness.description}'),
            Text('希望改变：${widget.weakness.goal}'),
            _field(_action, '下一小步：具体做什么？', 200),
            _field(_obstacle, '如果又不想做 / 遇到障碍，我准备……', 300),
            _field(_evidence, '用什么具体证据判断完成或改变？', 300),
            ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('约定截止时间'),
                subtitle: Text(fmtTime(_due.millisecondsSinceEpoch)),
                trailing: const Icon(Icons.edit_calendar),
                onTap: () async {
                  final now = DateTime.fromMillisecondsSinceEpoch(
                      widget.engine.nowMs());
                  final day = await showDatePicker(
                      context: context,
                      initialDate: _due,
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 365)));
                  if (day == null || !context.mounted) return;
                  final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_due));
                  if (time != null && mounted)
                    setState(() => _due = DateTime(
                        day.year, day.month, day.day, time.hour, time.minute));
                }),
            const Text('由你确认后才成为承诺。完成后核对证据，未完成时调整方法和难度。'),
            if (_error.isNotEmpty)
              Text(_error, style: const TextStyle(color: Colors.orange)),
            FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('我选择这个行动')),
          ])));
}
