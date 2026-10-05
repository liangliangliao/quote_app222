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
    this.repository,
  });

  final XiangjiUsageAssistantService? service;
  final XiangjiRepository? repository;

  @override
  State<XiangjiUsageAssistantPage> createState() =>
      _XiangjiUsageAssistantPageState();
}

class _XiangjiUsageAssistantPageState
    extends State<XiangjiUsageAssistantPage> {
  final TextEditingController _controller = TextEditingController();
  late final XiangjiUsageAssistantService _service;
  XiangjiUsageAssistantAnswer? _answer;
  XiangjiUsageAssistantContext? _usageContext;
  bool _loadingContext = false;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? XiangjiUsageAssistantService();
    _loadUsageContext();
  }

  Future<void> _loadUsageContext() async {
    final repository = widget.repository;
    if (repository == null) return;
    setState(() => _loadingContext = true);
    try {
      final value = await repository.usageAssistantContext();
      if (mounted) setState(() => _usageContext = value);
    } catch (_) {
      // The full feature guide remains available when there is no live state.
    } finally {
      if (mounted) setState(() => _loadingContext = false);
    }
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
    final answer = await _service.answer(
      question,
      context: _usageContext,
    );
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
          if (widget.repository != null) ...[
            const SizedBox(height: 10),
            XiangjiSectionCard(
              title: _loadingContext
                  ? '正在读取你的当前进度'
                  : _usageContext?.hasCurrentAction == true
                      ? '我知道你此刻在做哪一步'
                      : _usageContext?.hasProblem == true
                          ? '我知道你正在解哪道题'
                          : '目前还没有进行中的问题',
              subtitle: _usageContext?.hasCurrentAction == true
                  ? '${_usageContext!.actionStateLabel}·${_usageContext!.currentAction}'
                  : _usageContext?.problem ?? '你可以直接问如何开始。',
              icon: Icons.my_location_outlined,
              child: const Text(
                '问“我现在该做什么”、“我卡住了”或“为什么是这一步”，助手会根据当前状态回答，不会只背说明书。',
                style: TextStyle(height: 1.5),
              ),
            ),
          ],
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
                  label: '核心思想家',
                  value: answer.thinkerNames.join('、'),
                ),
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
          XiangjiLabeledValue(
            label: '核心思想家',
            value: guide.thinkerNames.join('、'),
          ),
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
          OutlinedButton.icon(
            key: const ValueKey<String>('xiangji_rehearse_guided_case'),
            onPressed: () async {
              final starter = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => XiangjiGuidedCasePracticePage(
                    example: example,
                  ),
                ),
              );
              if (context.mounted && starter != null) {
                Navigator.of(context).pop(starter);
              }
            },
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('用 2 分钟按四步演练这个案例'),
          ),
          const SizedBox(height: 8),
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

class XiangjiGuidedCasePracticePage extends StatefulWidget {
  const XiangjiGuidedCasePracticePage({
    super.key,
    required this.example,
  });

  final XiangjiGuidedCase example;

  @override
  State<XiangjiGuidedCasePracticePage> createState() =>
      _XiangjiGuidedCasePracticePageState();
}

class _XiangjiGuidedCasePracticePageState
    extends State<XiangjiGuidedCasePracticePage> {
  int _step = 0;

  XiangjiGuidedCase get example => widget.example;

  @override
  Widget build(BuildContext context) {
    final titles = <String>[
      '1. 从真实需要开始',
      '2. 把事实与解释分开',
      '3. 选一个能产生现实的办法',
      '4. 让现实改判并带走方法',
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('四步案例演练')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: _navigationControls(),
        ),
      ),
      body: ListView(
        key: ValueKey<String>('xiangji_case_practice_step_$_step'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          LinearProgressIndicator(value: (_step + 1) / 4),
          const SizedBox(height: 14),
          Text(
            titles[_step],
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '你正在演练，不会写入个人数据。每一步都要看到“填什么—为什么—产出什么”。',
            style: const TextStyle(color: XiangjiPalette.muted, height: 1.45),
          ),
          const SizedBox(height: 14),
          _stepCard(),
          const SizedBox(height: 12),
          XiangjiSectionCard(
            title: '这一步的思想与概念依据',
            subtitle: example.sourceLabel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const XiangjiLabeledValue(
                  label: '核心思想家',
                  value: '叔本华',
                ),
                XiangjiLabeledValue(
                  label: '本案例实际使用的 L0 概念',
                  value: _conceptNames(example.coreConceptIds),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _navigationControls() => Row(
        children: [
          if (_step > 0)
            TextButton.icon(
              onPressed: () => setState(() => _step -= 1),
              icon: const Icon(Icons.arrow_back),
              label: const Text('上一步'),
            ),
          const Spacer(),
          if (_step < 3)
            FilledButton.icon(
              key: const ValueKey<String>('xiangji_case_practice_next'),
              onPressed: () => setState(() => _step += 1),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('下一步'),
            )
          else
            FilledButton.icon(
              key: const ValueKey<String>('xiangji_case_practice_finish'),
              onPressed: () => Navigator.of(context).pop(example.need),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('用我的处境开始'),
            ),
        ],
      );

  Widget _stepCard() => switch (_step) {
        0 => XiangjiSectionCard(
            title: '你填什么',
            subtitle: '只用一句原话，不需要理论词汇。',
            child: Column(
              children: [
                XiangjiLabeledValue(label: '案例输入', value: example.need),
                const XiangjiLabeledValue(
                  label: '为什么',
                  value: '经验世界必须保留原话，不先被一个概念改写。',
                ),
                const XiangjiLabeledValue(
                  label: '产出',
                  value: '一个稳定的真实问题身份，后续行动和现实都回到同一道题。',
                ),
              ],
            ),
          ),
        1 => XiangjiSectionCard(
            title: '军师怎样处理',
            subtitle: '体验是真的，外部原因仍是待验候选。',
            child: Column(
              children: [
                XiangjiLabeledValue(
                  label: '可观察事实',
                  value: example.realityFacts.join('；'),
                ),
                XiangjiLabeledValue(
                  label: '用户解释',
                  value: example.userInterpretations.join('；'),
                ),
                XiangjiLabeledValue(
                  label: '竞争原因',
                  value: example.competingCauses.join('；'),
                ),
                XiangjiLabeledValue(label: '当前产出', value: example.keyGap),
              ],
            ),
          ),
        2 => XiangjiSectionCard(
            title: '不阅读概念，直接选一种现实负担',
            subtitle: '三个办法都服务同一目标，但用户有最终选择权。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final route in example.routeChoices)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Text('• $route', style: const TextStyle(height: 1.45)),
                  ),
                const Divider(height: 22),
                XiangjiLabeledValue(label: '案例选择', value: example.selectedAction),
                XiangjiLabeledValue(label: '事前预测', value: example.prediction),
                const XiangjiLabeledValue(
                  label: '产出',
                  value: '现实行为或外部结果，而不是新的计划文字。',
                ),
              ],
            ),
          ),
        _ => XiangjiSectionCard(
            title: '现实有最终修订权',
            subtitle: '失败也要产出新知识，不得只归因为意志薄弱。',
            child: Column(
              children: [
                XiangjiLabeledValue(label: '实际结果', value: example.realityResult),
                XiangjiLabeledValue(label: '改判', value: example.revision),
                XiangjiLabeledValue(label: '新的一步', value: example.nextStep),
                XiangjiLabeledValue(
                  label: '可迁移练习',
                  value: '下次遇到相似情境时，你要如何更早地区分事实、解释与候选原因？',
                ),
              ],
            ),
          ),
      };
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
  late Set<String> _obstacles;
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
    _obstacles = widget.initialProfile.obstacleTags.toSet();
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
      obstacleTags: _obstacles.toList(),
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
            '哪些生活领域会让我更愿意投入？',
            const <String>['创作', '学习', '事业', '关系', '身心', '探索'],
            _interests,
          ),
          _multiSection(
            '什么样的体验更容易让我开始？',
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
          _multiSection(
            '我现在最容易卡在哪里？（可不选，不是诊断）',
            const <String>[
              '开始前压力很大',
              '任务看起来太大',
              '担心被评价',
              '环境总打断',
              '缺少工具或资源',
              '目标还不够清楚',
            ],
            _obstacles,
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
          const SizedBox(height: 18),
          XiangjiSectionCard(
            title: '这些选择会如何真正改变方案',
            subtitle: '不改写现实事实，只改变你怎样更容易做出成果。',
            child: Text(
              '军师会把你选择的领域变成具体任务情境，用“${_strengths.isEmpty ? '你已有的优势' : _strengths.first}”设计执行方式；如果卡住，会针对“${_obstacles.isEmpty ? '当时实际阻碍' : _obstacles.first}”给出降级动作，并把产出与“${_values.isEmpty ? '真正想要的结果' : _values.first}”连接。当前优先用 $_minutes 分钟形成一个可观察成果。',
              style: const TextStyle(height: 1.5),
            ),
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
