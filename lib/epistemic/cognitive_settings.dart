import 'package:flutter/material.dart';
import 'cognitive_preferences.dart';
import 'cognitive_usage_view.dart';

class CognitiveSettingsSection extends StatefulWidget {
  const CognitiveSettingsSection({super.key});
  @override
  State<CognitiveSettingsSection> createState() =>
      _CognitiveSettingsSectionState();
}

class _CognitiveSettingsSectionState extends State<CognitiveSettingsSection> {
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    CognitivePreferenceStore.instance.load();
  }

  Future<void> _set(String key, Object value) async {
    setState(() => _saving = true);
    try {
      final store = CognitivePreferenceStore.instance;
      await store.update(store.value.change(key, value));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('认识偏好暂未保存，请重试')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<
          CognitivePreferences>(
      valueListenable: CognitivePreferenceStore.instance,
      builder: (context, prefs, _) => Card(
          color: const Color(0xfffaf6ee),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('阅读与认知风格',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                        key: const ValueKey('schopenhauer-style-toggle'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('叔本华认知风格'),
                        subtitle: Text(CognitivePreferenceStore.active
                            ? '已开启：按直观、概念、比较、判断与修订展开；首页保持原样。'
                            : '默认模式：沿用现有页面和交互。开启后可体验认知风格。'),
                        value: CognitivePreferenceStore.active,
                        onChanged:
                            _saving || !CognitivePreferenceStore.enabledInBuild
                                ? null
                                : (v) => _set('enabled', v)),
                    if (CognitivePreferenceStore.active) ...[
                      const Text(
                          '偏好只调整展开方式，不定义你的性格或认识水平。关闭风格开关可恢复默认模式，已保存的认识注释会保留。'),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                          builder: (context, constraints) =>
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                for (final style in CognitiveStyle.values)
                                  SizedBox(
                                      width: constraints.maxWidth < 330
                                          ? constraints.maxWidth
                                          : (constraints.maxWidth - 16) / 3,
                                      child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                              backgroundColor:
                                                  prefs.style == style
                                                      ? Theme.of(context)
                                                          .colorScheme
                                                          .secondaryContainer
                                                      : null,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 16)),
                                          onPressed: _saving
                                              ? null
                                              : () => _set('style', style.name),
                                          child: Column(children: [
                                            Icon(switch (style) {
                                              CognitiveStyle.intuitive =>
                                                Icons.landscape_outlined,
                                              CognitiveStyle.conceptual =>
                                                Icons.hub_outlined,
                                              CognitiveStyle.comparative =>
                                                Icons.compare_arrows
                                            }),
                                            const SizedBox(height: 8),
                                            Text(switch (style) {
                                              CognitiveStyle.intuitive =>
                                                '直观优先',
                                              CognitiveStyle.conceptual =>
                                                '概念优先',
                                              CognitiveStyle.comparative =>
                                                '比较优先'
                                            })
                                          ]))),
                              ])),
                      for (final item in [
                        ('relations', '显示概念关系图', prefs.relations),
                        ('prompts', '启用判断力训练提示', prefs.prompts),
                        ('grounds', '显示不同根据视角', prefs.grounds),
                        (
                          'evidence_reminders',
                          '新材料修订提示',
                          prefs.evidenceReminders
                        ),
                        ('reduce_motion', '减弱展开与关系动效', prefs.reduceMotion),
                        ('usage_enabled', '匿名使用记录（仅此设备）', prefs.usageEnabled),
                      ])
                        SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.$2),
                            value: item.$3,
                            onChanged: _saving || !prefs.enabled
                                ? null
                                : (v) => _set(item.$1, v)),
                      const Text(
                          '匿名记录默认关闭；开启后仅累计展开、采纳、修正、跳过及错误类别，不记录正文，也不上传。关闭后停止新增记录，原有计数可清除。',
                          style: TextStyle(fontSize: 12, height: 1.5)),
                      TextButton(
                          onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) => const CognitiveUsageDialog()),
                          child: const Text('查看 / 清除本地匿名计数')),
                      const Text(
                          '普通阅读不追加模型请求。只有主动分析所选材料时才使用已有全局 AI 配置；来源状态始终如实显示。',
                          style: TextStyle(fontSize: 12, height: 1.5)),
                    ],
                  ]))));
}
