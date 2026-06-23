import 'dart:convert';

import 'package:flutter/material.dart';

import 'realistic_optimism_training_ai_service.dart';
import 'realistic_optimism_training_dao.dart';
import 'realistic_optimism_training_models.dart';

class RotGuidedTrainingFlowPage extends StatefulWidget {
  final String initialScene;
  final String initialTemplate;
  final String extraContext;

  const RotGuidedTrainingFlowPage({
    super.key,
    required this.initialScene,
    this.initialTemplate = '',
    this.extraContext = '',
  });

  @override
  State<RotGuidedTrainingFlowPage> createState() => _RotGuidedTrainingFlowPageState();
}

class _RotGuidedTrainingFlowPageState extends State<RotGuidedTrainingFlowPage> {
  final RealisticOptimismTrainingAiService _ai = RealisticOptimismTrainingAiService();
  final RealisticOptimismTrainingDao _dao = RealisticOptimismTrainingDao();
  final Map<String, TextEditingController> _controllers = <String, TextEditingController>{};
  late String _scene;
  bool _generating = false;

  static const List<_RotScenario> _scenarios = <_RotScenario>[
    _RotScenario('intensity_check', '事件强度分级', Icons.traffic_outlined, '先判断 L1/L2/L3/L4，决定当前能不能重构、感恩或行动。'),
    _RotScenario('event_reframe', '今日事件重构', Icons.edit_note_outlined, '从真实事件进入完整闭环：情绪、事实、解释、双镜头、行动、证据。'),
    _RotScenario('emotion_container', '允许自己为人', Icons.favorite_border, '先容纳情绪，不急着积极；带着情绪找到一个小选择。'),
    _RotScenario('explanation_radar', '解释风格雷达', Icons.radar_outlined, '检查永久化、普遍化、人格化、灾难化、无力化、过滤化。'),
    _RotScenario('dual_lens', 'Fault/Benefit 双镜头', Icons.compare_arrows_outlined, '同一现实，用 Fault Finder 与 Benefit Finder 两种叙事对照。'),
    _RotScenario('process_action', '过程模拟行动器', Icons.route_outlined, '把目标转成时间、地点、工具、第一步、障碍和 If-Then。'),
    _RotScenario('failure_immunity', '失败免疫实验室', Icons.shield_outlined, '预测痛苦 vs 实际痛苦，预测恢复 vs 实际恢复，提取心理抗体。'),
    _RotScenario('controlled_failure_challenge', '可控失败挑战', Icons.science_outlined, '低风险练习承受不完美、拒绝、暴露或不确定性。'),
    _RotScenario('prime_design', '注意力 Prime 设计', Icons.wallpaper_outlined, '设计价值词、锁屏短句、照片/物品线索和 Benefit Finder 问题。'),
    _RotScenario('anti_prime_cleanup', 'Anti-Prime 环境清理', Icons.cleaning_services_outlined, '清理比较、拖延、无力感、负面信息等消极启动源。'),
    _RotScenario('gratitude_savoring', '感恩、品味与关系表达', Icons.local_florist_outlined, '具体感恩、30秒品味、轻量/具体/深度关系表达。'),
    _RotScenario('identity_evidence', '身份沉淀', Icons.badge_outlined, '把一次真实行动沉淀为“我正在成为……”的身份句。'),
    _RotScenario('weekly_baseline', '幸福基线周报', Icons.show_chart_outlined, '不是追求天天开心，而是追踪恢复能力和行动稳定性。'),
    _RotScenario('todo_goal_bridge', 'Todo/目标联动', Icons.task_alt_outlined, '把未完成任务转入情绪允许、解释重构和明日最小行动。'),
    _RotScenario('daily_review', '每日自动复盘', Icons.nightlight_round, '晚上汇总事件、行动证据、感恩品味、身份提醒和明日 Prime。'),
    _RotScenario('course_card', '课程知识卡', Icons.menu_book_outlined, '把课程概念变成一张可练习的现实主义乐观知识卡。'),
    _RotScenario('role_model_case', '榜样案例库', Icons.groups_outlined, '把榜样的失败解释、恢复行动和可模仿行为拆出来。'),
    _RotScenario('proactive_reminder', '主动提醒文案', Icons.notifications_active_outlined, '生成推送、锁屏、小组件可用的触发式提醒。'),
    _RotScenario('monthly_report', '周/月报图表', Icons.insights_outlined, '输出解释风格、行动证据、失败恢复和身份成长趋势。'),
  ];

  @override
  void initState() {
    super.initState();
    _scene = _scenarios.any((e) => e.id == widget.initialScene) ? widget.initialScene : 'event_reframe';
    _seedDefaults();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _seedDefaults() {
    _controller('raw_event').text = widget.initialTemplate;
    _controller('emotion').text = '';
    _controller('automatic_thought').text = '';
    _controller('goal').text = '';
    _controller('obstacle').text = '';
    _controller('failure_prediction').text = '';
    _controller('gratitude_object').text = '';
    _controller('person').text = '';
    _controller('environment_trigger').text = '';
  }

  TextEditingController _controller(String key) => _controllers.putIfAbsent(key, () => TextEditingController());

  _RotScenario get _currentScenario => _scenarios.firstWhere((e) => e.id == _scene, orElse: () => _scenarios[1]);

  Future<void> _run() async {
    final promptInput = _buildStructuredInput();
    if (promptInput.trim().length < 20) {
      _toast('请至少填写一个真实事件、目标、情绪或环境线索。');
      return;
    }
    setState(() => _generating = true);
    try {
      await _dao.ensureTables();
      final result = await _ai.generate(
        userInput: promptInput,
        scene: _scene,
        extraContext: widget.extraContext,
      );
      await _dao.upsertRecord(result.record);
      if (!mounted) return;
      Navigator.pop(context, result.record);
    } catch (e) {
      _toast('生成失败：$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  String _buildStructuredInput() {
    final map = <String, String>{
      '当前训练场景': _currentScenario.title,
      '真实事件或主题': _controller('raw_event').text.trim(),
      '最强情绪': _controller('emotion').text.trim(),
      '脑中自动解释/最强一句话': _controller('automatic_thought').text.trim(),
      '目标或任务': _controller('goal').text.trim(),
      '最大障碍/拖延理由': _controller('obstacle').text.trim(),
      '失败前预测/最坏想象': _controller('failure_prediction').text.trim(),
      '仍然值得感恩或品味的对象': _controller('gratitude_object').text.trim(),
      '想表达感谢的人': _controller('person').text.trim(),
      '环境触发源/Anti-Prime': _controller('environment_trigger').text.trim(),
    };
    final nonEmpty = map.entries.where((e) => e.value.isNotEmpty).map((e) => '${e.key}：${e.value}').join('\n');
    final requirements = _scenarioRequirements(_scene);
    return '$nonEmpty\n\n请严格按照最终版产品设计方案处理：\n$requirements\n\n必须输出完整 JSON，并且不要跳过情绪允许、事实-解释分离、解释风格、Fault/Benefit、可控点、5分钟行动、身份证据等适用字段。';
  }

  String _scenarioRequirements(String scene) {
    switch (scene) {
      case 'intensity_check':
        return '只先做 L1/L2/L3/L4 强度分级，明确当前适合和不适合的干预；L3 不强行找好处，L4 安全优先。';
      case 'emotion_container':
        return '先 Permission to Be Human：命名情绪、承认身体感受和痛苦合理性，再只给一个很小选择。';
      case 'explanation_radar':
        return '重点分析永久化、普遍化、人格化、灾难化、无力化、过滤化，每项给替代表达。';
      case 'dual_lens':
        return '必须并列展示 Fault Finder 叙事与 Benefit Finder 叙事，Benefit Finder 不得说坏事就是好事。';
      case 'process_action':
        return '必须生成结果画面、时间地点工具、第一步、三步过程、障碍预演、If-Then 和 5分钟启动动作。';
      case 'failure_immunity':
        return '必须对比预测痛苦/实际痛苦、预测恢复/实际恢复，提取心理抗体；缺失实际结果时先做失败前预测。';
      case 'controlled_failure_challenge':
        return '必须设计低风险挑战、安全边界、执行步骤、失败前预测和失败后复盘问题。';
      case 'prime_design':
        return '必须输出今日价值词、锁屏短句、现实 Prime、Benefit Finder 问题和今日行动线索。';
      case 'anti_prime_cleanup':
        return '必须识别消极启动源、影响、可移除项、降低接触项、替代 Prime 和今日最小清理动作。';
      case 'gratitude_savoring':
        return '必须具体感恩，加入30秒 Savoring；如果涉及某个人，生成轻量版、具体版、深度版关系表达。';
      case 'identity_evidence':
        return '必须基于实际行动生成身份层证据，不要空泛夸奖。';
      case 'weekly_baseline':
        return '必须生成周报：解释风格变化、行动证据、失败恢复、感恩敏感度、下周训练重点。';
      case 'todo_goal_bridge':
        return '必须把 Todo 未完成转成情绪允许、解释风格、Fault/Benefit、明日最小行动和行动证据问题。';
      case 'daily_review':
        return '必须汇总今日事件、解释风格、行动证据、三件具体感恩、30秒品味、身份提醒和明日 Prime。';
      case 'course_card':
        return '必须生成课程知识卡：概念、现实例子、练习问题和 5 分钟行动。';
      case 'role_model_case':
        return '必须生成榜样案例：失败、解释、恢复、行动和用户可模仿的最小行为。';
      case 'proactive_reminder':
        return '必须生成主动提醒：触发条件、推送文案、锁屏短句、小组件文字和行动线索。';
      case 'monthly_report':
        return '必须生成周/月报图表结构：解释风格、行动证据、失败恢复、Prime、感恩和身份成长趋势。';
      default:
        return '必须完成事件重构完整闭环。';
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final scenario = _currentScenario;
    return Scaffold(
      appBar: AppBar(
        title: const Text('现实主义乐观训练流程'),
        actions: <Widget>[
          TextButton.icon(
            onPressed: _generating ? null : _run,
            icon: _generating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_outlined),
            label: Text(_generating ? '生成中' : '生成闭环'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: <Widget>[
          _FlowHero(scenario: scenario),
          const SizedBox(height: 12),
          _ScenePicker(
            scenarios: _scenarios,
            selected: _scene,
            onChanged: (v) => setState(() => _scene = v),
          ),
          const SizedBox(height: 12),
          _FinalDesignLoopCard(scene: _scene),
          const SizedBox(height: 12),
          _InputSection(scene: _scene, controller: _controller),
          const SizedBox(height: 12),
          _OutputContractCard(scene: _scene),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _generating ? null : _run,
            icon: _generating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.psychology_alt_outlined),
            label: Text(_generating ? '正在生成完整训练结果……' : '按最终方案生成完整训练结果'),
          ),
        ],
      ),
    );
  }
}

class _RotScenario {
  final String id;
  final String title;
  final IconData icon;
  final String subtitle;
  const _RotScenario(this.id, this.title, this.icon, this.subtitle);
}

class _FlowHero extends StatelessWidget {
  final _RotScenario scenario;
  const _FlowHero({required this.scenario});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(colors: <Color>[Theme.of(context).colorScheme.primaryContainer.withOpacity(.90), Theme.of(context).colorScheme.secondaryContainer.withOpacity(.75)]),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        CircleAvatar(radius: 26, child: Icon(scenario.icon)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(scenario.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(scenario.subtitle, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 10),
          const Text('产品原则：先承认真实，再检查解释；先做过程行动，再沉淀证据；不做廉价正能量。', style: TextStyle(fontWeight: FontWeight.w700)),
        ])),
      ]),
    );
  }
}

class _ScenePicker extends StatelessWidget {
  final List<_RotScenario> scenarios;
  final String selected;
  final ValueChanged<String> onChanged;
  const _ScenePicker({required this.scenarios, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: selected,
      decoration: const InputDecoration(labelText: '选择独立训练入口', border: OutlineInputBorder()),
      items: scenarios.map((s) => DropdownMenuItem(value: s.id, child: Text(s.title))).toList(growable: false),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _InputSection extends StatelessWidget {
  final String scene;
  final TextEditingController Function(String key) controller;
  const _InputSection({required this.scene, required this.controller});

  @override
  Widget build(BuildContext context) {
    final fields = _fieldsForScene(scene);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          const Text('按真实训练流程填写', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('不用写得完美。越具体，AI 越能按最终方案把事件转成解释、行动和证据。', style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 12),
          ...fields.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: controller(f.key),
                  minLines: f.lines,
                  maxLines: f.lines + 3,
                  decoration: InputDecoration(
                    labelText: f.label,
                    hintText: f.hint,
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              )),
        ]),
      ),
    );
  }

  List<_FieldSpec> _fieldsForScene(String scene) {
    switch (scene) {
      case 'process_action':
        return const <_FieldSpec>[
          _FieldSpec('goal', '目标/任务', '例如：今晚学习英语 1 小时；写简历；运动 20 分钟', 3),
          _FieldSpec('obstacle', '最容易卡住的地方', '例如：手机干扰、害怕写不好、任务太大、状态不好', 3),
          _FieldSpec('automatic_thought', '脑中自动解释', '例如：我做不好，所以不如先逃避', 2),
        ];
      case 'failure_immunity':
      case 'controlled_failure_challenge':
        return const <_FieldSpec>[
          _FieldSpec('raw_event', '失败/挑战主题', '例如：面试失败；想提出一个可能被拒绝的小请求', 3),
          _FieldSpec('failure_prediction', '预测痛苦、最坏想象、恢复预测', '例如：我怕痛苦 9 分，觉得会一周恢复不了，别人会觉得我很差', 4),
          _FieldSpec('emotion', '现在的情绪', '例如：羞耻、害怕、紧张、失望', 2),
        ];
      case 'prime_design':
        return const <_FieldSpec>[
          _FieldSpec('goal', '今天最需要被启动的状态', '例如：行动、勇气、感恩、失败恢复、关系珍惜', 2),
          _FieldSpec('raw_event', '最近让我偏离这个状态的事件', '例如：刷短视频后更焦虑；一次失败后不想开始', 3),
        ];
      case 'anti_prime_cleanup':
        return const <_FieldSpec>[
          _FieldSpec('environment_trigger', '消极启动源', '例如：某个 App、某个人、某种内容、睡前手机、混乱桌面', 3),
          _FieldSpec('emotion', '它把我带入什么状态', '例如：比较、自责、拖延、无力、焦虑', 2),
        ];
      case 'gratitude_savoring':
        return const <_FieldSpec>[
          _FieldSpec('gratitude_object', '具体感恩/品味对象', '例如：今天朋友一句回复、傍晚阳光、自己完成了 10 分钟学习', 3),
          _FieldSpec('person', '想感谢的人（可选）', '例如：妈妈、朋友、同事、过去的自己', 2),
          _FieldSpec('raw_event', '这件事为什么对我重要', '越具体越好，不要只写“感谢生活”', 3),
        ];
      case 'identity_evidence':
        return const <_FieldSpec>[
          _FieldSpec('raw_event', '我刚刚做过/恢复过/珍惜过的一件事', '例如：虽然自责，但我打开文件改了一句话', 3),
          _FieldSpec('emotion', '当时我带着什么情绪完成它', '例如：焦虑、拖延、羞耻、失望', 2),
        ];
      case 'todo_goal_bridge':
        return const <_FieldSpec>[
          _FieldSpec('goal', '未完成的 Todo / 目标', '例如：写简历、学习英语、运动、投递工作', 2),
          _FieldSpec('obstacle', '未完成的真实卡点', '例如：任务太大、害怕失败、手机干扰、没有状态', 3),
          _FieldSpec('automatic_thought', '未完成后的自动解释', '例如：我永远坚持不了；我又失败了', 3),
        ];
      case 'daily_review':
      case 'monthly_report':
        return const <_FieldSpec>[
          _FieldSpec('raw_event', '今天/本周期主要事件', '写下主要事件、未完成事项、完成的小行动', 4),
          _FieldSpec('gratitude_object', '具体感恩或品味对象', '例如：一句支持、一个完成的小动作、一个环境细节', 3),
          _FieldSpec('goal', '下周期想训练的重点', '例如：减少永久化、增加行动证据、清理 Anti-Prime', 2),
        ];
      case 'course_card':
      case 'role_model_case':
      case 'proactive_reminder':
        return const <_FieldSpec>[
          _FieldSpec('goal', '主题', '例如：解释风格、失败免疫、Benefit Finder、Prime、感恩品味', 2),
          _FieldSpec('raw_event', '我的现实场景', '把知识卡/榜样/提醒应用到哪个真实场景？', 3),
        ];
      default:
        return const <_FieldSpec>[
          _FieldSpec('raw_event', '真实事件', '例如：今天我又没有学习，我感觉自己特别废，永远坚持不了。', 4),
          _FieldSpec('emotion', '最强情绪', '例如：自责、羞耻、失望、愤怒、害怕、麻木', 2),
          _FieldSpec('automatic_thought', '脑中最强烈的一句话', '例如：我永远坚持不了；我这个人很差；以后都没希望', 3),
          _FieldSpec('obstacle', '现在最想逃避或最卡住的地方', '例如：不敢打开材料；怕复盘；怕承认失败', 3),
        ];
    }
  }
}

class _FieldSpec {
  final String key;
  final String label;
  final String hint;
  final int lines;
  const _FieldSpec(this.key, this.label, this.hint, this.lines);
}

class _FinalDesignLoopCard extends StatelessWidget {
  final String scene;
  const _FinalDesignLoopCard({required this.scene});

  @override
  Widget build(BuildContext context) {
    final steps = <String>[
      '强度分级',
      '情绪允许',
      '事实-解释分离',
      '解释风格雷达',
      'Fault / Benefit 双镜头',
      '可控点',
      '过程行动',
      '证据沉淀',
      '感恩/Prime/身份',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          const Text('最终方案闭环检查', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: steps.map((s) => Chip(label: Text(s))).toList(growable: false)),
          const SizedBox(height: 8),
          Text(_sceneExplanation(scene), style: TextStyle(color: Colors.grey.shade700, height: 1.45)),
        ]),
      ),
    );
  }

  String _sceneExplanation(String scene) {
    if (scene == 'intensity_check') return '本场景重点是先判断是否适合继续做积极重构；不是所有痛苦都马上寻找意义。';
    if (scene == 'process_action') return '本场景重点是把目标拆成可执行过程，防止停留在结果幻想。';
    if (scene == 'gratitude_savoring') return '本场景重点是具体感恩、停留品味和关系表达，而不是抽象写“感谢生活”。';
    return '本场景会尽量返回完整训练闭环；严重痛苦会优先稳定和安全支持。';
  }
}

class _OutputContractCard extends StatelessWidget {
  final String scene;
  const _OutputContractCard({required this.scene});

  @override
  Widget build(BuildContext context) {
    final items = <String>[
      '必须承认情绪，不直接鸡汤安慰',
      '必须区分事实和解释',
      '必须指出 Fault Finder 叙事如何让人无力',
      'Benefit Finder 必须承认痛苦，不得说“一切都是最好的安排”',
      '必须给出 5 分钟内能开始的行动',
      '必须生成身份层证据，基于实际行动而不是空泛夸奖',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          const Text('输出验收标准', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ...items.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[const Text('✓  '), Expanded(child: Text(e))]),
              )),
        ]),
      ),
    );
  }
}
