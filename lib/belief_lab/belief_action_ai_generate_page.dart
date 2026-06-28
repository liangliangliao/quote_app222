import 'package:flutter/material.dart';

import 'belief_action_ai_service.dart';
import 'belief_action_models.dart';
import 'belief_action_template_editor_page.dart';
import 'belief_action_runtime.dart';
import 'belief_dao.dart';
import 'belief_flow_page.dart';
import 'belief_models.dart';

class BeliefActionAIGeneratePage extends StatefulWidget {
  final String conceptId;
  final String conceptTitle;

  const BeliefActionAIGeneratePage({super.key, required this.conceptId, required this.conceptTitle});

  @override
  State<BeliefActionAIGeneratePage> createState() => _BeliefActionAIGeneratePageState();
}

class _BeliefActionAIGeneratePageState extends State<BeliefActionAIGeneratePage> {
  final _svc = BeliefActionAIService();
  final _dao = BeliefDao();

  final _keywords = TextEditingController();
  final _scene = TextEditingController();

  String _provider = 'global';
  String _mode = 'quick';

  bool _loading = false;
  BeliefActionTemplate? _result;
  String? _err;

  @override
  void dispose() {
    _keywords.dispose();
    _scene.dispose();
    super.dispose();
  }

  List<BeliefStep> _stepsFromTemplate(BeliefActionTemplate t) =>
      buildBeliefActionStepsFromTemplate(template: t, conceptTitle: widget.conceptTitle);

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _err = null;
      _result = null;
    });

    try {
      final t = await _svc.generate(
        provider: _provider,
        conceptId: widget.conceptId,
        conceptTitle: widget.conceptTitle,
        keywords: _keywords.text,
        scene: _scene.text,
        mode: _mode,
      );
      if (!mounted) return;
      setState(() => _result = t);
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _saveToMine(BeliefActionTemplate t) async {
    final key = 'actiontpl:${widget.conceptId}:${t.id}';
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存到“我的模板”')));
  }

  Future<void> _start(BeliefActionTemplate t) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final runKey = 'actionrun:${t.id}:$ts';

    final title = '行动模板：${t.title}';
    final subtitle = '${widget.conceptTitle} · ${t.modeLabel} · ${t.version}';

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BeliefFlowPage(
          kind: BeliefFlowKind.mission,
          id: 'actionrun_${t.id}_$ts',
          title: title,
          subtitle: subtitle,
          steps: _stepsFromTemplate(t),
          progressKeyOverride: runKey,
          extraPayload: {
            'title': title,
            'subtitle': subtitle,
            'conceptId': t.conceptId,
            'templateId': t.id,
            'template': t.toJson(),
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('AI 生成行动模板 · ${widget.conceptTitle}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        children: [
          _field('关键词（你当前的卡点/目标）', _keywords, hint: '例：拖延、面试、失眠、关系冲突…'),
          const SizedBox(height: 12),
          _field('场景/领域', _scene, hint: '例：工作、学校、家庭、爱情、人际…'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _providerField()),
              const SizedBox(width: 12),
              Expanded(child: _modeField()),
            ],
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _loading ? null : _generate,
            icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
            label: Text(_loading ? '生成中…' : '生成模板'),
          ),
          if (_err != null) ...[
            const SizedBox(height: 10),
            Text(_err!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 18),
          if (_result != null) _resultCard(_result!),
          if (_result == null) ...[
            const SizedBox(height: 10),
            Text(
              '说明：\n- 本地模式不联网，适合先跑通结构。\n- 统一 AI 会读取设置页中的全局 AI 提供方、模型与版本（可为 OpenAI / DeepSeek / OpenRouter / Eden AI / xGrok / Gemini）；若未配置，将自动回退到本地生成。\n- 生成后建议“编辑后保存”，确保概念与行动完全一致。',
              style: TextStyle(color: Colors.black.withOpacity(0.7), height: 1.35),
            ),
          ],
        ],
      ),
    );
  }

  Widget _resultCard(BeliefActionTemplate t) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(blurRadius: 14, spreadRadius: 0, offset: Offset(0, 6), color: Color(0x1A000000))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('${t.categoryPath} · ${t.modeLabel} · ${t.version}', style: TextStyle(color: Colors.black.withOpacity(0.7))),
          const SizedBox(height: 10),
          Text('操作性定义：\n${t.operationalDefinition}', style: TextStyle(color: Colors.black.withOpacity(0.82), height: 1.35)),
          const SizedBox(height: 10),
          Text('成功判据：\n${t.successCriteria}', style: TextStyle(color: Colors.black.withOpacity(0.82), height: 1.35)),
          const SizedBox(height: 10),
          const Text('行动清单：', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          ...t.actionChecklist.take(7).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• ${e.trim()}', style: TextStyle(color: Colors.black.withOpacity(0.78))),
              )),
          if (t.actionChecklist.length > 7) Text('…（共 ${t.actionChecklist.length} 条）', style: TextStyle(color: Colors.black.withOpacity(0.6))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _start(t),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('开始行动'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => _saveToMine(t),
                icon: const Icon(Icons.save_outlined),
                label: const Text('保存'),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: '编辑后保存',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BeliefActionTemplateEditorPage(
                        conceptId: widget.conceptId,
                        conceptTitle: widget.conceptTitle,
                        initial: t,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _providerField() {
    return InputDecorator(
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        labelText: '生成方式',
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _provider,
          items: const [
            DropdownMenuItem(value: 'global', child: Text('统一 AI（读取设置页）')),
            DropdownMenuItem(value: 'local', child: Text('本地（不联网）')),
          ],
          onChanged: (v) => setState(() => _provider = v ?? 'global'),
        ),
      ),
    );
  }

  Widget _modeField() {
    return InputDecorator(
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        labelText: '模式',
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

  Widget _field(String label, TextEditingController c, {String? hint}) {
    return TextField(
      controller: c,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: label,
        hintText: hint,
      ),
    );
  }
}

