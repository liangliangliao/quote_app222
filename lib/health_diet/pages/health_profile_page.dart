import 'package:flutter/material.dart';

import '../models/health_profile.dart';
import '../repositories/health_profile_repository.dart';
import '../services/health_diet_options.dart';
import '../widgets/health_diet_data_source_banner.dart';

class HealthProfilePage extends StatefulWidget {
  const HealthProfilePage({super.key});

  @override
  State<HealthProfilePage> createState() => _HealthProfilePageState();
}

class _HealthProfilePageState extends State<HealthProfilePage> {
  final _repository = HealthProfileRepository();
  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String _gender = 'unknown';
  String _activityLevel = 'normal';
  String _mainGoal = 'balanced';
  final Set<String> _conditions = <String>{};
  final Set<String> _restrictions = <String>{};
  final Set<String> _preferences = <String>{'chinese_food', 'light_taste'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await _repository.latestProfile();
    if (!mounted) return;
    if (profile != null) {
      _gender = profile.gender;
      _activityLevel = profile.activityLevel;
      _mainGoal = profile.mainGoal;
      _ageCtrl.text = profile.age?.toString() ?? '';
      _heightCtrl.text = profile.heightCm == null ? '' : _trimDouble(profile.heightCm!);
      _weightCtrl.text = profile.weightKg == null ? '' : _trimDouble(profile.weightKg!);
      _conditions
        ..clear()
        ..addAll(profile.conditions);
      _restrictions
        ..clear()
        ..addAll(profile.restrictions);
      _preferences
        ..clear()
        ..addAll(profile.preferences);
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final profile = HealthProfile(
      userId: HealthProfileRepository.defaultUserId,
      gender: _gender,
      age: int.tryParse(_ageCtrl.text.trim()),
      heightCm: double.tryParse(_heightCtrl.text.trim()),
      weightKg: double.tryParse(_weightCtrl.text.trim()),
      activityLevel: _activityLevel,
      mainGoal: _mainGoal,
      conditions: _conditions.toList(),
      restrictions: _restrictions.toList(),
      preferences: _preferences.toList(),
    );
    await _repository.saveProfile(profile);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('健康档案已保存，后续饮食推荐会优先读取这些信息')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的健康档案'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('保存'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                HealthDietDataSourceBanner(
                  sources: const ['用户手动填写', '本地健康档案库'],
                  updatedAt: DateTime.now(),
                  note: '健康档案是 Agent 决策的长期基础数据；保存后今日调理、复盘和菜谱都会读取。',
                ),
                _introCard(),
                const SizedBox(height: 14),
                _sectionTitle('基础信息'),
                _dropdown(
                  label: '性别',
                  value: _gender,
                  options: HealthDietOptions.genders,
                  onChanged: (v) => setState(() => _gender = v ?? 'unknown'),
                ),
                Row(
                  children: [
                    Expanded(child: _numberField(_ageCtrl, '年龄', '岁')),
                    const SizedBox(width: 10),
                    Expanded(child: _numberField(_heightCtrl, '身高', 'cm')),
                    const SizedBox(width: 10),
                    Expanded(child: _numberField(_weightCtrl, '体重', 'kg')),
                  ],
                ),
                _dropdown(
                  label: '活动量',
                  value: _activityLevel,
                  options: HealthDietOptions.activityLevels,
                  onChanged: (v) => setState(() => _activityLevel = v ?? 'normal'),
                ),
                _dropdown(
                  label: '当前饮食调理目标',
                  value: _mainGoal,
                  options: HealthDietOptions.goals,
                  onChanged: (v) => setState(() => _mainGoal = v ?? 'balanced'),
                ),
                const SizedBox(height: 14),
                _sectionTitle('健康状况'),
                _hint('这些信息只用于本地生成饮食参考。若涉及疾病、用药、孕期、术后恢复等情况，后续推荐会强制显示专业医疗提示。'),
                _chips(HealthDietOptions.conditions, _conditions),
                const SizedBox(height: 14),
                _sectionTitle('忌口 / 过敏 / 饮食限制'),
                _chips(HealthDietOptions.restrictions, _restrictions),
                const SizedBox(height: 14),
                _sectionTitle('口味与烹饪偏好'),
                _chips(HealthDietOptions.preferences, _preferences),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save),
                  label: const Text('保存健康档案'),
                ),
                const SizedBox(height: 12),
                const Text(
                  '提示：本模块提供健康饮食和营养搭配参考，不能替代医生、注册营养师或临床诊疗建议。',
                  style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.5),
                ),
              ],
            ),
    );
  }

  Widget _introCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEFF6FF), Color(0xFFF0FDF4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('先让系统了解你的身体状态', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(
            '第一阶段先保存健康档案。后续“今日饮食调理、食物利弊查询、健康菜谱制作”都会把这里作为个性化推荐的基础。',
            style: TextStyle(height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _hint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4)),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<HealthDietOption> options,
    required ValueChanged<String?> onChanged,
  }) {
    final safeValue = options.any((option) => option.code == value) ? value : options.first.code;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: safeValue,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: options
            .map((option) => DropdownMenuItem<String>(
                  value: option.code,
                  child: Text(option.label),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label, String suffix) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _chips(List<HealthDietOption> options, Set<String> selected) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selected.contains(option.code);
        return FilterChip(
          label: Text(option.label),
          selected: isSelected,
          onSelected: (checked) {
            setState(() {
              if (checked) {
                selected.add(option.code);
              } else {
                selected.remove(option.code);
              }
            });
          },
        );
      }).toList(),
    );
  }

  String _trimDouble(double value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.0001) return rounded.toInt().toString();
    return value.toStringAsFixed(1);
  }
}
