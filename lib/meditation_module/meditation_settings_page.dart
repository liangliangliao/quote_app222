import 'package:flutter/material.dart';

import 'meditation_settings_service.dart';

class MeditationSettingsPage extends StatefulWidget {
  const MeditationSettingsPage({super.key});

  @override
  State<MeditationSettingsPage> createState() => _MeditationSettingsPageState();
}

class _MeditationSettingsPageState extends State<MeditationSettingsPage> {
  final _service = MeditationSettingsService();
  MeditationFeatureSettings _settings = MeditationFeatureSettings.defaults();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await _service.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _loading = false;
    });
  }

  Future<void> _save(MeditationFeatureSettings settings) async {
    setState(() {
      _settings = settings;
      _saving = true;
    });
    await _service.save(settings);
    if (!mounted) return;
    setState(() => _saving = false);
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 8),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      );

  Widget _card(List<Widget> children) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: Column(children: children),
      );

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(height: 1.35)),
      value: value,
      onChanged: onChanged,
    );
  }

  Future<void> _saveCompletionRecordPageEnabled(bool enabled) async {
    await _save(_settings.copyWith(
      showCompletionRecordPage: enabled,
      showCompletionFeedbackCard: enabled,
      showCompletionMoodRatings: enabled,
      showCompletionNoteInput: enabled,
      showPracticeAiFeedback: enabled,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('冥想设置'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _sectionTitle('记录与 AI 显示'),
                _card([
                  _switchTile(
                    title: '显示本周 AI 静心总结',
                    subtitle: '关闭后，静心轨迹页面不再显示周总结入口和历史周总结内容。',
                    value: _settings.showWeeklyAiSummary,
                    onChanged: (v) => _save(_settings.copyWith(showWeeklyAiSummary: v)),
                  ),
                  const Divider(height: 1),
                  _switchTile(
                    title: '完成后显示完成记录页',
                    subtitle: '关闭后，冥想完成会自动保存一条基础记录并直接退出，不再显示评分、觉察和反馈页面。',
                    value: _settings.showCompletionRecordPage,
                    onChanged: _saveCompletionRecordPageEnabled,
                  ),
                ]),
                _sectionTitle('完成记录页内容'),
                _card([
                  _switchTile(
                    title: '显示完成反馈文案',
                    subtitle: '关闭后，完成记录页顶部不再显示本地或 AI 反馈文案。',
                    value: _settings.showCompletionRecordPage && _settings.showCompletionFeedbackCard,
                    onChanged: _settings.showCompletionRecordPage
                        ? (v) => _save(_settings.copyWith(showCompletionFeedbackCard: v))
                        : null,
                  ),
                  const Divider(height: 1),
                  _switchTile(
                    title: '显示练习前后评分',
                    subtitle: '关闭后，不再要求填写紧张/烦乱、分心、身体放松等评分。',
                    value: _settings.showCompletionRecordPage && _settings.showCompletionMoodRatings,
                    onChanged: _settings.showCompletionRecordPage
                        ? (v) => _save(_settings.copyWith(showCompletionMoodRatings: v))
                        : null,
                  ),
                  const Divider(height: 1),
                  _switchTile(
                    title: '显示一句觉察输入',
                    subtitle: '关闭后，完成记录页不显示文字记录输入框。',
                    value: _settings.showCompletionRecordPage && _settings.showCompletionNoteInput,
                    onChanged: _settings.showCompletionRecordPage
                        ? (v) => _save(_settings.copyWith(showCompletionNoteInput: v))
                        : null,
                  ),
                  const Divider(height: 1),
                  _switchTile(
                    title: '显示 AI 练习后反馈',
                    subtitle: '关闭后，不再显示“生成 AI 反馈”按钮，也不会在完成页展示 AI 反馈区域。',
                    value: _settings.showCompletionRecordPage && _settings.showPracticeAiFeedback,
                    onChanged: _settings.showCompletionRecordPage
                        ? (v) => _save(_settings.copyWith(showPracticeAiFeedback: v))
                        : null,
                  ),
                ]),
                _sectionTitle('冥想播放'),
                _card([
                  _switchTile(
                    title: '循环重复当前冥想',
                    subtitle: '开启后，当前冥想播放到结尾会从第一句重新开始，直到手动完成或达到自动结束时间。',
                    value: _settings.loopPlaybackEnabled,
                    onChanged: (v) => _save(_settings.copyWith(loopPlaybackEnabled: v)),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('定时自动结束并退出冥想', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        const Text('到达指定时间后自动保存为已完成并退出播放页。关闭时按冥想本身时长结束；若循环开启且未设置自动结束，则会持续循环。', style: TextStyle(color: Colors.black54, height: 1.4)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <int>[0, 5, 10, 15, 20, 30, 45, 60, 90, 120].map((m) {
                            return ChoiceChip(
                              label: Text(m == 0 ? '关闭' : '$m 分钟'),
                              selected: _settings.autoExitMinutes == m,
                              onSelected: (_) => _save(_settings.copyWith(autoExitMinutes: m)),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
