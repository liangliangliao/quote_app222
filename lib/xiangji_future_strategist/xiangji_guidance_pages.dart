import 'package:flutter/material.dart';

import 'xiangji_practical_product.dart';
import 'xiangji_repository.dart';
import 'xiangji_schopenhauer_core_catalog.dart';
import 'xiangji_ui_support.dart';
import 'xiangji_usage_assistant_service.dart';

class XiangjiUsageAssistantPage extends StatefulWidget {
  const XiangjiUsageAssistantPage({
    super.key,
    this.service,
  });

  final XiangjiUsageAssistantService? service;

  @override
  State<XiangjiUsageAssistantPage> createState() =>
      _XiangjiUsageAssistantPageState();
}

class _XiangjiUsageAssistantPageState
    extends State<XiangjiUsageAssistantPage> {
  final TextEditingController _controller = TextEditingController();
  late final XiangjiUsageAssistantService _service;
  XiangjiUsageAssistantAnswer? _answer;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? XiangjiUsageAssistantService();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ask([String? suggested]) async {
    final question = (suggested ?? _controller.text).trim();
    if (question.isEmpty) return;
    setState(() => _working = true);
    final answer = await _service.answer(question);
    if (!mounted) return;
    setState(() {
      _answer = answer;
      _working = false;
      _controller.text = question;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('使用助手'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const XiangjiUserGuidePage()),
            ),
            child: const Text('完整说明'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const XiangjiSectionCard(
            title: '不知道怎么用，直接问',
            subtitle: '我知道未来军师每个入口、完整流程、填写方式和知识依据；也可以直接把你带到正确入口。',
            icon: Icons.support_agent_outlined,
            child: Text(
              '你不需要先判断该用哪个功能。问“我现在该从哪里开始”“行动没做怎么办”“为什么只做一步”都可以。',
              style: TextStyle(height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('xiangji_usage_assistant_input'),
            controller: _controller,
            minLines: 2,
            maxLines: 5,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _ask(),
            decoration: InputDecoration(
              hintText: '例如：我完全不知道该怎么开始',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: '询问使用助手',
                onPressed: _working ? null : _ask,
                icon: const Icon(Icons.send_outlined),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final question in const <String>[
                '我该从哪里开始？',
                '行动没完成怎么办？',
                '为什么只让我做一步？',
                '思想知识到底怎样起作用？',
                '我想看完整案例',
              ])
                ActionChip(
                  label: Text(question),
                  onPressed: _working ? null : () => _ask(question),
                ),
            ],
          ),
          if (_working) ...[
            const SizedBox(height: 18),
            const LinearProgressIndicator(),
          ],
          if (_answer != null && !_working) ...[
            const SizedBox(height: 16),
            _answerCard(_answer!),
          ],
        ],
      ),
    );
  }

  Widget _answerCard(XiangjiUsageAssistantAnswer answer) =>
      XiangjiSectionCard(
        title: answer.title,
        subtitle: answer.aiEnhanced
            ? 'AI 已根据内置产品合同组织回答'
            : '由内置产品合同直接回答，离线也可用',
        icon: answer.aiEnhanced
            ? Icons.auto_awesome_outlined
            : Icons.menu_book_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(answer.answer, style: const TextStyle(height: 1.55)),
            const SizedBox(height: 12),
            const Text('最短操作步骤',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            for (var index = 0; index < answer.steps.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text('${index + 1}. ${answer.steps[index]}',
                    style: const TextStyle(height: 1.45)),
              ),
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('为什么这样设计 / 知识依据'),
              childrenPadding: EdgeInsets.zero,
              children: [
                XiangjiLabeledValue(
                  label: '依据',
                  value: answer.knowledgeSource,
                ),
                XiangjiLabeledValue(
                  label: '对应的叔本华 L0 概念',
                  value: _conceptNames(answer.coreConceptIds),
                ),
              ],
            ),
            if (answer.destination.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(answer),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('按这个开始'),
                ),
              ),
            ],
          ],
        ),
      );
}

class XiangjiUserGuidePage extends StatelessWidget {
  const XiangjiUserGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('未来军师使用说明')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const XiangjiSectionCard(
            title: '产品只负责一件事',
            subtitle: XiangjiPracticalProductContract.mission,
            icon: Icons.track_changes_outlined,
            child: Text(
              '复杂认识建模、原因比较、根据审查和求解在后台完成。默认情况下，你只需要讲真实处境、选择、行动和反馈。',
              style: TextStyle(height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          XiangjiSectionCard(
            title: '固定四步闭环',
            subtitle: '每一轮必须产生现实动作或现实修订；阅读知识不算完成。',
            child: Column(
              children: [
                for (final step in XiangjiPracticalProductContract.coreLoop)
                  _flowStep(step),
              ],
            ),
          ),
          const SizedBox(height: 12),
          XiangjiSectionCard(
            title: '每个功能怎么用',
            subtitle: '逐项说明是什么、何时用、填什么、产出什么和知识依据。',
            child: Column(
              children: [
                for (final guide
                    in XiangjiPracticalProductContract.featureGuides)
                  _guideTile(guide),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const XiangjiSectionCard(
            title: '持续使用边界',
            subtitle: '帮助形成能力，而不是制造依赖。',
            icon: Icons.volunteer_activism_outlined,
            child: Text(
              XiangjiPracticalProductContract.ethicalBoundary,
              style: TextStyle(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _flowStep(XiangjiPracticalFlowStep step) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(step.title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('你做：${step.userAction}', style: const TextStyle(height: 1.4)),
            Text('军师做：${step.systemWork}',
                style: const TextStyle(color: XiangjiPalette.muted, height: 1.4)),
            Text('产出：${step.output}',
                style: const TextStyle(color: XiangjiPalette.pine, height: 1.4)),
          ],
        ),
      );

  Widget _guideTile(XiangjiFeatureGuide guide) => ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(guide.title,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(guide.problemSolved),
        childrenPadding: const EdgeInsets.only(bottom: 12),
        children: [
          XiangjiLabeledValue(label: '这是什么', value: guide.what),
          XiangjiLabeledValue(label: '什么时候用', value: guide.whenToUse),
          XiangjiLabeledValue(label: '需要填写什么', value: guide.whatToProvide),
          XiangjiLabeledValue(label: '怎样做', value: guide.steps.join(' → ')),
          XiangjiLabeledValue(label: '最终产出', value: guide.output),
          XiangjiLabeledValue(label: '为什么这样做', value: guide.why),
          XiangjiLabeledValue(label: '知识依据', value: guide.knowledgeSource),
          XiangjiLabeledValue(
            label: '对应 L0 概念',
            value: _conceptNames(guide.coreConceptIds),
          ),
        ],
      );
}

class XiangjiGuidedCasesPage extends StatelessWidget {
  const XiangjiGuidedCasesPage({
    super.key,
    required this.cases,
  });

  final List<XiangjiGuidedCase> cases;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('完整案例与操作示范')),
      body: cases.isEmpty
          ? const XiangjiEmptyState(
              title: '案例暂未加载',
              message: '返回后重试即可；你的个人问题不会受影响。',
              icon: Icons.menu_book_outlined,
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: cases.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final example = cases[index];
                return Card(
                  elevation: 0,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const CircleAvatar(
                      backgroundColor: XiangjiPalette.mist,
                      child: Icon(Icons.route_outlined,
                          color: XiangjiPalette.pine),
                    ),
                    title: Text(example.title,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('${example.category} · ${example.summary}'),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final starter = await Navigator.of(context).push<String>(
                        MaterialPageRoute(
                          builder: (_) =>
                              XiangjiGuidedCaseDetailPage(example: example),
                        ),
                      );
                      if (starter != null && context.mounted) {
                        Navigator.of(context).pop(starter);
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}

class XiangjiGuidedCaseDetailPage extends StatelessWidget {
  const XiangjiGuidedCaseDetailPage({
    super.key,
    required this.example,
  });

  final XiangjiGuidedCase example;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(example.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          XiangjiSectionCard(
            title: '原始需要',
            subtitle: '用户只需要从这样一句话开始。',
            child: Text(example.need,
                style: const TextStyle(fontSize: 17, height: 1.5)),
          ),
          const SizedBox(height: 10),
          XiangjiSectionCard(
            title: '1. 军师怎样理解现实',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                XiangjiLabeledValue(
                    label: '实际发生', value: example.realityFacts.join('；')),
                XiangjiLabeledValue(
                    label: '用户的解释（不是新增事实）',
                    value: example.userInterpretations.join('；')),
                XiangjiLabeledValue(
                    label: '需要区分的原因',
                    value: example.competingCauses.join('；')),
              ],
            ),
          ),
          const SizedBox(height: 10),
          XiangjiSectionCard(
            title: '2. 目标与关键差距',
            child: Column(
              children: [
                XiangjiLabeledValue(label: '可观察目标', value: example.goal),
                XiangjiLabeledValue(label: '当前先解决', value: example.keyGap),
              ],
            ),
          ),
          const SizedBox(height: 10),
          XiangjiSectionCard(
            title: '3. 三种可选办法',
            subtitle: '负担不同，但都服务同一道题；用户拥有最终选择权。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final route in example.routeChoices)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Text('• $route', style: const TextStyle(height: 1.45)),
                  ),
                const Divider(height: 22),
                XiangjiLabeledValue(label: '示例采用', value: example.selectedAction),
                XiangjiLabeledValue(label: '事前预测', value: example.prediction),
              ],
            ),
          ),
          const SizedBox(height: 10),
          XiangjiSectionCard(
            title: '4. 现实怎样改变下一步',
            child: Column(
              children: [
                XiangjiLabeledValue(label: '示例现实结果', value: example.realityResult),
                XiangjiLabeledValue(label: '军师改判', value: example.revision),
                XiangjiLabeledValue(label: '下一步', value: example.nextStep),
              ],
            ),
          ),
          const SizedBox(height: 10),
          XiangjiSectionCard(
            title: '知识依据不是装饰',
            subtitle: example.sourceLabel,
            child: XiangjiLabeledValue(
              label: '本案例实际使用的 L0 概念',
              value: _conceptNames(example.coreConceptIds),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(example.need),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('把这句话改成我的处境并开始'),
          ),
        ],
      ),
    );
  }
}

class XiangjiPreferenceSetupPage extends StatefulWidget {
  const XiangjiPreferenceSetupPage({
    super.key,
    required this.repository,
    required this.initialProfile,
  });

  final XiangjiRepository repository;
  final XiangjiUserPreferenceProfile initialProfile;

  @override
  State<XiangjiPreferenceSetupPage> createState() =>
      _XiangjiPreferenceSetupPageState();
}

class _XiangjiPreferenceSetupPageState
    extends State<XiangjiPreferenceSetupPage> {
  late Set<String> _interests;
  late Set<String> _values;
  late Set<String> _strengths;
  late String _energy;
  late String _style;
  late int _minutes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _interests = widget.initialProfile.interestTags.toSet();
    _values = widget.initialProfile.valueTags.toSet();
    _strengths = widget.initialProfile.strengthTags.toSet();
    _energy = widget.initialProfile.energyLevel;
    _style = widget.initialProfile.supportStyle;
    _minutes = widget.initialProfile.preferredMinutes;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final profile = XiangjiUserPreferenceProfile(
      interestTags: _interests.toList(),
      valueTags: _values.toList(),
      strengthTags: _strengths.toList(),
      energyLevel: _energy,
      supportStyle: _style,
      preferredMinutes: _minutes,
    );
    try {
      await widget.repository.saveUserPreferenceProfile(profile);
      if (!mounted) return;
      Navigator.of(context).pop(profile);
    } catch (error) {
      if (mounted) xiangjiShowMessage(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('60 秒选择我的使用方式')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Text(
            '这不是人格诊断，只决定行动负担、表达方式和优先呈现；随时可以修改或跳过。',
            style: TextStyle(color: XiangjiPalette.muted, height: 1.45),
          ),
          const SizedBox(height: 16),
          _multiSection(
            '什么更容易让我愿意开始？',
            const <String>['轻松开始', '清晰步骤', '看见进展', '探索挑战', '有人陪伴'],
            _interests,
          ),
          _multiSection(
            '这段时间我最想保护或获得什么？',
            const <String>['成长', '自由', '稳定', '成就', '关系', '健康'],
            _values,
          ),
          _multiSection(
            '我愿意借力的优势（可不选）',
            const <String>['好奇', '细致', '坚持', '创造', '勇气', '沟通'],
            _strengths,
          ),
          _singleSection(
            '现在通常有多少能量？',
            const <String, String>{
              'low': '较低',
              'medium': '一般',
              'high': '可以挑战',
            },
            _energy,
            (value) => setState(() => _energy = value),
          ),
          _singleSection(
            '希望军师怎样说？',
            const <String, String>{
              'gentle': '温和陪伴',
              'direct': '简洁直接',
              'challenge': '友好挑战',
            },
            _style,
            (value) => setState(() => _style = value),
          ),
          const Text('每次更愿意投入多久？',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const <ButtonSegment<int>>[
              ButtonSegment(value: 3, label: Text('3 分钟')),
              ButtonSegment(value: 10, label: Text('10 分钟')),
              ButtonSegment(value: 20, label: Text('20 分钟')),
            ],
            selected: <int>{_minutes},
            onSelectionChanged: (values) =>
                setState(() => _minutes = values.first),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '正在保存…' : '保存我的使用方式'),
          ),
        ],
      ),
    );
  }

  Widget _multiSection(
    String title,
    List<String> values,
    Set<String> selected,
  ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final value in values)
                  FilterChip(
                    label: Text(value),
                    selected: selected.contains(value),
                    onSelected: (enabled) => setState(() {
                      if (enabled) {
                        selected.add(value);
                      } else {
                        selected.remove(value);
                      }
                    }),
                  ),
              ],
            ),
          ],
        ),
      );

  Widget _singleSection(
    String title,
    Map<String, String> values,
    String selected,
    ValueChanged<String> onChanged,
  ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final entry in values.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: selected == entry.key,
                    onSelected: (_) => onChanged(entry.key),
                  ),
              ],
            ),
          ],
        ),
      );
}

String _conceptNames(List<String> ids) => ids
    .map((id) {
      try {
        return XiangjiSchopenhauerCoreCatalog.forId(id).displayName;
      } catch (_) {
        return id;
      }
    })
    .join('；');
