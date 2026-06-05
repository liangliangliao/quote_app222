import 'package:flutter/material.dart';

import '../models/health_diet_agent_models.dart';
import '../repositories/health_diet_agent_repository.dart';
import '../repositories/health_profile_repository.dart';
import '../services/health_diet_options.dart';
import '../widgets/health_diet_data_source_banner.dart';

class HealthDietGoalPage extends StatefulWidget {
  const HealthDietGoalPage({super.key});

  @override
  State<HealthDietGoalPage> createState() => _HealthDietGoalPageState();
}

class _HealthDietGoalPageState extends State<HealthDietGoalPage> {
  final _repo = HealthDietAgentRepository();
  final _titleCtrl = TextEditingController();
  final _avoidCtrl = TextEditingController(text: '不极端节食、不完全戒主食、不做复杂菜');
  final _metricsCtrl = TextEditingController(text: '规律早餐、减少甜饮料、晚餐低油低盐、提高优质蛋白');

  HealthDietGoal? _active;
  List<HealthDietGoal> _goals = const [];
  String _goalType = 'restore_energy';
  String _difficulty = 'gentle';
  int _durationDays = 14;
  final Set<String> _preferences = {'chinese_food', 'light_taste', 'quick_meal'};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _avoidCtrl.dispose();
    _metricsCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final active = await _repo.activeGoal();
    final goals = await _repo.goals();
    if (!mounted) return;
    setState(() {
      _active = active;
      _goals = goals;
      if (active != null) {
        _goalType = active.goalType;
        _titleCtrl.text = active.goalTitle;
        _difficulty = active.difficulty;
        _durationDays = active.durationDays;
        _preferences
          ..clear()
          ..addAll(active.preferences.isEmpty ? const ['chinese_food', 'light_taste', 'quick_meal'] : active.preferences);
        _avoidCtrl.text = active.avoid.join('、');
        _metricsCtrl.text = active.successMetrics.join('、');
      }
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final title = _titleCtrl.text.trim().isEmpty ? HealthDietOptions.labelOf(HealthDietOptions.goals, _goalType) : _titleCtrl.text.trim();
    final goal = HealthDietGoal(
      userId: HealthProfileRepository.defaultUserId,
      goalType: _goalType,
      goalTitle: title,
      durationDays: _durationDays,
      difficulty: _difficulty,
      preferences: _preferences.toList(),
      avoid: _split(_avoidCtrl.text),
      successMetrics: _split(_metricsCtrl.text),
      status: 'active',
    );
    await _repo.saveGoal(goal);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('健康饮食目标已保存，Agent 会围绕该目标生成方案')));
    await _load();
  }

  List<String> _split(String text) => text
      .split(RegExp(r'[、,，;；\n]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的健康饮食目标')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                HealthDietDataSourceBanner(
                  sources: const ['用户健康目标', '健康档案', 'Agent 长期记忆'],
                  updatedAt: DateTime.now(),
                  note: '目标是 Agent 每日安排和复盘的方向盘；越明确，饮食计划越能聚焦。',
                ),
                _noticeCard(),
                const SizedBox(height: 12),
                if (_active != null) _activeCard(_active!),
                const SizedBox(height: 12),
                _sectionTitle('当前目标'),
                DropdownButtonFormField<String>(
                  value: _goalType,
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '目标类型'),
                  items: HealthDietOptions.goals.map((e) => DropdownMenuItem(value: e.code, child: Text(e.label))).toList(),
                  onChanged: (v) => setState(() => _goalType = v ?? _goalType),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '目标标题，可选',
                    hintText: '例如：14天恢复体力 + 调理肠胃',
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _durationDays,
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '目标周期'),
                      items: const [7, 14, 30, 60].map((e) => DropdownMenuItem(value: e, child: Text('$e 天'))).toList(),
                      onChanged: (v) => setState(() => _durationDays = v ?? 14),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _difficulty,
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '执行强度'),
                      items: const [
                        DropdownMenuItem(value: 'gentle', child: Text('温和')),
                        DropdownMenuItem(value: 'medium', child: Text('中等')),
                        DropdownMenuItem(value: 'strict', child: Text('严格')),
                      ],
                      onChanged: (v) => setState(() => _difficulty = v ?? 'gentle'),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                _sectionTitle('饮食偏好'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: HealthDietOptions.preferences
                      .map((e) => FilterChip(
                            selected: _preferences.contains(e.code),
                            label: Text(e.label),
                            onSelected: (selected) => setState(() {
                              if (selected) {
                                _preferences.add(e.code);
                              } else {
                                _preferences.remove(e.code);
                              }
                            }),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _avoidCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '不做事项 / 执行边界',
                    helperText: '例如：不极端节食、不完全戒奶茶、不做复杂菜。用顿号或逗号分隔。',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _metricsCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '成功指标',
                    helperText: 'Agent 会据此判断是否接近目标。用顿号或逗号分隔。',
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.flag_outlined),
                  label: Text(_saving ? '保存中...' : '保存并设为当前目标'),
                ),
                const SizedBox(height: 20),
                if (_goals.isNotEmpty) ...[
                  _sectionTitle('历史目标'),
                  ..._goals.map(_historyTile),
                ],
              ],
            ),
    );
  }

  Widget _noticeCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: const Text(
          'Agent 必须先知道“正在帮你实现什么目标”。保存目标后，营养膳食专家会围绕目标主动读取健康档案、Health Connect、每日饮食分享和历史习惯，生成有依据的饮食安排，而不是只做被动查询。',
          style: TextStyle(height: 1.5),
        ),
      );

  Widget _activeCard(HealthDietGoal goal) => Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: const [Icon(Icons.flag, color: Colors.green), SizedBox(width: 8), Text('当前 Agent 目标', style: TextStyle(fontWeight: FontWeight.bold))]),
            const SizedBox(height: 8),
            Text(goal.displayTitle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('${goal.durationDays} 天 · ${goal.difficultyLabel} · ${goal.status}', style: const TextStyle(color: Colors.black54)),
            if (goal.successMetrics.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('成功指标：${goal.successMetrics.join('、')}', style: const TextStyle(height: 1.4)),
            ],
          ]),
        ),
      );

  Widget _historyTile(HealthDietGoal goal) => ListTile(
        leading: Icon(goal.status == 'active' ? Icons.radio_button_checked : Icons.radio_button_off),
        title: Text(goal.displayTitle),
        subtitle: Text('${goal.durationDays}天 · ${goal.difficultyLabel} · ${goal.status}'),
        trailing: goal.status == 'active' ? const Text('当前') : null,
      );

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );
}
