import 'dart:async';

import 'package:flutter/material.dart';

import '../pages/ai_prompt_settings_page.dart';
import 'consistency_action_service.dart';

class ConsistencyActionHomePage extends StatefulWidget {
  const ConsistencyActionHomePage({super.key});

  @override
  State<ConsistencyActionHomePage> createState() =>
      _ConsistencyActionHomePageState();
}

class _ConsistencyActionHomePageState extends State<ConsistencyActionHomePage> {
  final _service = ConsistencyActionService();
  final _inputCtrl = TextEditingController(text: '我想学习心理学，但总是刷视频');
  final _evidenceCtrl = TextEditingController();
  final _identityCtrl = TextEditingController(text: '能用小行动靠近价值的人');
  final _oldExplanationCtrl = TextEditingController(text: '我必须有动力才开始');
  final _newExplanationCtrl = TextEditingController(text: '我可以在动力不足时完成一个小行动');

  String _scene = 'ca_scene_value_compass';
  String _selectedValue = '成长';
  String _selectedCategory = '学习证据';
  int _durationMinutes = 5;
  int _remainingSeconds = 0;
  Timer? _timer;
  bool _loading = false;
  String _result = '';
  List<ConsistencyActionRecord> _records = [];

  final _scenes = const <String, String>{
    'ca_scene_value_compass': '价值罗盘',
    'ca_scene_dissonance': '认知失调雷达',
    'ca_scene_dollar_action': '1美元行动设计器',
    'ca_scene_pre_action': '行动前承诺卡',
    'ca_scene_post_action': '行动后解释',
    'ca_scene_reward_noise': '奖励降噪',
    'ca_scene_rationalization': '合理化警报',
    'ca_scene_weekly_report': '一致性报告',
  };

  static const _values = <String>[
    '成长',
    '自由',
    '责任',
    '健康',
    '学习',
    '创造',
    '自律',
    '勇气',
    '关系',
    '真实自我',
  ];

  static const _categories = <String>[
    '自律证据',
    '勇气证据',
    '学习证据',
    '责任证据',
    '复盘证据',
    '面对不适证据',
    '从逃避中返回的证据',
  ];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _inputCtrl.dispose();
    _evidenceCtrl.dispose();
    _identityCtrl.dispose();
    _oldExplanationCtrl.dispose();
    _newExplanationCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    _records = await _service.records();
    if (mounted) setState(() {});
  }

  Future<void> _generate() async {
    final input = _inputCtrl.text.trim();
    if (input.isEmpty) return _toast('请先写下目标、拖延事件或内心冲突');
    setState(() => _loading = true);
    try {
      final scene = _scene == 'ca_scene_weekly_report'
          ? _service.buildConsistencyReport(_records)
          : await _service.generate(
              scenePromptId: _scene,
              input: input,
              valueName: _selectedValue,
              evidenceJson: await _service.evidenceJson(),
            );
      final record = ConsistencyActionRecord(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        scene: _scene,
        input: input,
        aiText: scene,
        createdAt: DateTime.now(),
        valueName: _selectedValue,
        identity: _identityCtrl.text.trim(),
        category: _selectedCategory,
        durationMinutes: _durationMinutes,
        oldExplanation: _oldExplanationCtrl.text.trim(),
        newExplanation: _newExplanationCtrl.text.trim(),
      );
      await _service.saveRecord(record);
      await _loadRecords();
      setState(() => _result = scene);
    } catch (e) {
      _toast('生成失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startTimer(int minutes) {
    _timer?.cancel();
    setState(() => _remainingSeconds = minutes * 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() => _remainingSeconds = 0);
        _toast('行动时间到：现在写一句行动后解释，把它变成证据。');
      } else {
        setState(() => _remainingSeconds -= 1);
      }
    });
  }

  Future<void> _markCompleted(ConsistencyActionRecord r) async {
    _evidenceCtrl.text = r.evidence.isEmpty
        ? '我完成了“${r.input}”的一小步；这说明旧模式不是绝对的。'
        : r.evidence;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('行动证据卡'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _evidenceCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '今天的行动证据',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _oldExplanationCtrl,
                decoration: const InputDecoration(
                  labelText: '它打破的旧解释',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _newExplanationCtrl,
                decoration: const InputDecoration(
                  labelText: '它支持的新解释',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _identityCtrl,
                decoration: const InputDecoration(
                  labelText: '它对应的新身份',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('存入账本'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.saveRecord(r.copyWith(
      completed: true,
      evidence: _evidenceCtrl.text.trim(),
      oldExplanation: _oldExplanationCtrl.text.trim(),
      newExplanation: _newExplanationCtrl.text.trim(),
      identity: _identityCtrl.text.trim(),
      valueName: _selectedValue,
      category: _selectedCategory,
      durationMinutes: _durationMinutes,
    ));
    await _loadRecords();
    _toast('已沉淀为身份证据');
  }

  Future<void> _recordComeback() async {
    final input = _inputCtrl.text.trim().isEmpty ? '从中断后回来' : _inputCtrl.text.trim();
    final record = ConsistencyActionRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      scene: 'return_after_break',
      input: input,
      aiText: '中断不清零。今天的重点不是完美连续，而是回来一次。',
      createdAt: DateTime.now(),
      completed: true,
      evidence: '我从中断或逃避中回来了，这比连续打卡更能说明恢复能力。',
      valueName: _selectedValue,
      identity: '能中断后重新开始的人',
      category: '从逃避中返回的证据',
      returnedAfterBreak: true,
    );
    await _service.saveRecord(record);
    await _loadRecords();
    _toast('已记录一次“回来”证据');
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );

  @override
  Widget build(BuildContext context) {
    final stats = _service.stats(_records);
    return Scaffold(
      appBar: AppBar(
        title: const Text('足下一致行动系统'),
        actions: [
          IconButton(
            tooltip: 'AI提示词配置',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const AiPromptSettingsPage(
                initialModuleId: 'consistency_action',
              ),
            )),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _hero(),
          const SizedBox(height: 14),
          _stats(stats),
          const SizedBox(height: 14),
          _flowCard(),
          const SizedBox(height: 14),
          _valueCompass(),
          const SizedBox(height: 14),
          _moduleTabs(),
          const SizedBox(height: 12),
          _inputCard(),
          const SizedBox(height: 14),
          _companionCard(),
          if (_result.isNotEmpty) ...[
            const SizedBox(height: 16),
            _aiResultCard(_result),
          ],
          const SizedBox(height: 18),
          _reportCard(),
          const SizedBox(height: 18),
          _ledger(stats),
        ],
      ),
    );
  }

  Widget _hero() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF172554), Color(0xFF4F46E5)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '不是等到相信才行动，而是在行动中重新相信。',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '用最小行动制造真实证据，用真实证据重塑自我认同。',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('价值澄清')),
                Chip(label: Text('失调识别')),
                Chip(label: Text('最小充分行动')),
                Chip(label: Text('行动后解释')),
                Chip(label: Text('身份内化')),
              ],
            ),
          ],
        ),
      );

  Widget _stats(ConsistencyActionStats stats) => Row(
        children: [
          Expanded(child: _metric('证据', '${stats.completed}', '不是连续，而是真实')),
          const SizedBox(width: 8),
          Expanded(child: _metric('回来', '${stats.comebackCount}', '中断不清零')),
          const SizedBox(width: 8),
          Expanded(child: _metric('14天', '${stats.recentCompleted}', '近期行动证据')),
        ],
      );

  Widget _metric(String title, String value, String note) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              Text(note, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      );

  Widget _flowCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('7步行动心理学闭环', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('价值澄清 → 失调识别 → 1美元行动 → 自主承诺 → 行动执行 → 行动后解释 → 身份证据沉淀'),
            ],
          ),
        ),
      );

  Widget _valueCompass() => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('我的价值', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _values
                    .map((v) => ChoiceChip(
                          label: Text(v),
                          selected: _selectedValue == v,
                          onSelected: (_) => setState(() => _selectedValue = v),
                        ))
                    .toList(),
              ),
              const Divider(height: 22),
              const Text('证据分类'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories
                    .map((c) => ChoiceChip(
                          label: Text(c),
                          selected: _selectedCategory == c,
                          onSelected: (_) => setState(() => _selectedCategory = c),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      );

  Widget _moduleTabs() => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _scenes.entries
            .map((e) => ChoiceChip(
                  label: Text(e.value),
                  selected: _scene == e.key,
                  onSelected: (_) => setState(() => _scene = e.key),
                ))
            .toList(),
      );

  Widget _inputCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              TextField(
                controller: _inputCtrl,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: '写下目标、困扰、拖延或矛盾事件',
                  hintText: '例如：我想考证，但总是刷短视频',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: _durationMinutes,
                decoration: const InputDecoration(
                  labelText: '行动陪伴时长',
                  border: OutlineInputBorder(),
                ),
                items: const [3, 5, 10]
                    .map((m) => DropdownMenuItem(value: m, child: Text('$m 分钟')))
                    .toList(),
                onChanged: (v) => setState(() => _durationMinutes = v ?? 5),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _generate,
                      icon: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: const Text('生成价值一致行动'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _recordComeback,
                      icon: const Icon(Icons.keyboard_return),
                      label: const Text('记录一次回来'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _companionCard() {
    final running = _remainingSeconds > 0;
    final mm = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final ss = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('行动陪伴模式', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('行动前少辩论，行动后再解释。现在只显示一个动作：开始。'),
            const SizedBox(height: 10),
            Center(
              child: Text(
                running ? '$mm:$ss' : '${_durationMinutes.toString().padLeft(2, '0')}:00',
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: FilledButton.icon(
                onPressed: running ? null : () => _startTimer(_durationMinutes),
                icon: const Icon(Icons.play_arrow),
                label: const Text('开始最小行动'),
              ),
            ),
            const SizedBox(height: 8),
            const Text('提醒：现在不需要证明你有多强，只需要完成这个最小动作。'),
          ],
        ),
      ),
    );
  }

  Widget _aiResultCard(String body) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('AI 引导结果', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text(body, style: const TextStyle(height: 1.45)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _records.isEmpty ? null : () => _markCompleted(_records.first),
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('已行动，生成证据卡'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _startTimer(_durationMinutes),
                    icon: const Icon(Icons.timer_outlined),
                    label: const Text('进入陪伴计时'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _reportCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('价值一致性复盘', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text(_service.buildConsistencyReport(_records), style: const TextStyle(height: 1.4)),
            ],
          ),
        ),
      );

  Widget _ledger(ConsistencyActionStats stats) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.account_balance_wallet_outlined),
              SizedBox(width: 6),
              Text('身份证据账本', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          if (_records.isEmpty)
            const Text('还没有证据卡。完成一次最小行动后，它会在这里累积成“我可以开始”的长期证据。'),
          if (stats.categories.isNotEmpty) _categorySummary(stats.categories),
          ..._records.take(24).map((r) => Card(
                child: ListTile(
                  leading: Icon(
                    r.completed ? Icons.workspace_premium : Icons.radio_button_unchecked,
                    color: r.completed ? Colors.indigo : null,
                  ),
                  title: Text(r.completed ? r.category : (_scenes[r.scene] ?? '一致行动')),
                  subtitle: Text(
                    r.completed
                        ? '${r.evidence}\n价值：${r.valueName.isEmpty ? '未标注' : r.valueName} · 新身份：${r.identity.isEmpty ? '能用小行动靠近价值的人' : r.identity}'
                        : '${r.input}\n待行动：完成后可沉淀为身份证据',
                  ),
                  isThreeLine: true,
                  trailing: r.completed
                      ? null
                      : TextButton(
                          onPressed: () => _markCompleted(r),
                          child: const Text('完成'),
                        ),
                ),
              )),
        ],
      );

  Widget _categorySummary(Map<String, int> map) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: map.entries
              .map((e) => Chip(label: Text('${e.key} × ${e.value}')))
              .toList(),
        ),
      );
}
