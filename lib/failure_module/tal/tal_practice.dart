import 'package:flutter/material.dart';
import '../../beautiful_enemy/src/domain/guard.dart' show SafetyValve;
import 'tal_catalog.dart';
import 'tal_shared_views.dart';

class TalPracticeDraft {
  const TalPracticeDraft(
      {required this.methodId,
      required this.values,
      this.caseId,
      this.pause = false,
      this.affirmedSignals = const {}});
  final String methodId;
  final Map<String, String> values;
  final String? caseId;
  final bool pause;
  final Set<String> affirmedSignals;
}

const talMethodNames = {
  'prp': 'PRP：允许、重构、拉远视野',
  'explore_failures': '完整写一次经历',
  'permission_to_be_human': '先允许此刻的感受',
  'three_ms': '检查有没有遗漏事实',
  'benefit_finding': '寻找真实的教训或收获',
  'unbundling': '分开想保留和想减少的部分',
  'learn_to_fail': '尝试一次可承受的挑战',
  'stretch_zone': '把挑战调整到可承受的范围',
  'five_minute_takeoff': '自愿试着开始五分钟',
  'creating_rituals': '给一个重要行为安排固定时机',
  'three_rs': '安排提醒、重复和惯例',
  'mvi': '选一个有用的小调整',
  'spire': '先看看休息和生活条件',
  'trial_error': '根据上次结果换一个调整',
  'abc_change': '选择一个改变的入口',
};

/// The fields are exercise-specific. They return a draft to the user's current
/// event; browsing or practising never creates a second event or a commitment.
const _practiceFields = <String, Map<String, String>>{
  'prp': {
    'permission': '此刻的事实和感受',
    'reconstruction': '承认损失后，我能学到或调整什么？',
    'perspective': '放在更长时间和生活里，我怎么看这件事？'
  },
  'explore_failures': {
    'did': '我当时做了什么？',
    'thought': '当时有什么想法？',
    'felt_then': '当时的感受',
    'felt_now': '现在的感受',
    'lessons': '目前能学到什么？也可以还不清楚'
  },
  'permission_to_be_human': {
    'felt_then': '此刻有什么真实感受？',
    'permission': '我愿意怎样允许这个感受存在？也可以先不写'
  },
  'three_ms': {
    'thought': '我现在对这件事的判断',
    'basis': '哪些具体事实支持这个判断？',
    'contradiction': '有没有被我忽略或与它不同的事实？',
    'reconstruction': '补上这些事实后，我会怎样重新描述？'
  },
  'benefit_finding': {
    'acknowledged_loss': '先承认这次真实的损失',
    'lessons': '有没有真实可用的教训或收获？可以写暂时没有'
  },
  'unbundling': {
    'keep_value': '我希望保留的品质或价值',
    'reduce_behavior': '我希望减少的行为或负担',
    'lessons': '怎样保留前者，同时调整后者？可以先不知道'
  },
  'learn_to_fail': {
    'action': '我愿意尝试的一件小挑战',
    'risk_bounds': '可承受的损失与停止界限',
    'check': '向谁获取反馈，或怎样查看实际结果？'
  },
  'stretch_zone': {
    'action': '现在可承受、对目标仍有用的一步',
    'risk_bounds': '什么时候停止或降低难度？',
    'check': '怎样判断这次挑战是否合适？'
  },
  'five_minute_takeoff': {'action': '我愿意先开始做什么？', 'check': '怎样看见启动确实发生？'},
  'creating_rituals': {
    'action': '具体要做的行为',
    'trigger': '具体时间或稳定的生活线索',
    'ritual_value': '它与我珍视的什么价值有关？',
    'check': '在相关情境下怎样检查是否做了？'
  },
  'three_rs': {
    'action': '准备重复的具体行为',
    'trigger': '什么稳定线索可以提醒我？',
    'ritual_value': '这个行为为什么值得保留？',
    'check': '怎样检查实际执行，而不只数提醒？'
  },
  'mvi': {
    'action': '一个小而有实际价值的调整',
    'ritual_value': '它怎样帮助真正的目标？',
    'check': '怎样看见这一步确实发生？'
  },
  'spire': {
    'recovery_condition': '休息、负担、支持或生活条件中，什么值得先照顾？',
    'action': '如果愿意，我先恢复或减少哪一件事？'
  },
  'trial_error': {
    'prior_attempt': '先前试过什么？',
    'trial_result': '实际反馈是什么？未知就写未知',
    'action': '下一次只改变哪一项主要做法？',
    'check': '用什么实际变化比较这次结果？'
  },
  'abc_change': {
    'change_entry': '我愿意从感受、行为还是想法入手？',
    'action': '这个入口对应的一个具体调整',
    'check': '怎样观察有没有实际帮助？'
  },
};

class TalPracticePage extends StatefulWidget {
  const TalPracticePage(
      {super.key,
      required this.catalog,
      required this.method,
      required this.initialValues,
      required this.onCrisis,
      this.caseId,
      this.previouslyNotHelped = false});
  final TalCatalog catalog;
  final TalMethod method;
  final Map<String, String> initialValues;
  final VoidCallback onCrisis;
  final String? caseId;
  final bool previouslyNotHelped;
  @override
  State<TalPracticePage> createState() => _TalPracticePageState();
}

class _TalPracticePageState extends State<TalPracticePage> {
  late final fields = _practiceFields[widget.method.id]!;
  late final inputs = {
    for (final key in fields.keys)
      key: TextEditingController(text: widget.initialValues[key] ?? '')
  };
  String _prpStep = 'permission';
  bool _crisis = false, _gateAccepted = false;
  bool get _needsGate => [
        'learn_to_fail',
        'stretch_zone',
        'five_minute_takeoff',
        'benefit_finding'
      ].contains(widget.method.id);
  @override
  void initState() {
    super.initState();
    for (final input in inputs.values) {
      input.addListener(_guard);
    }
  }

  void _guard() {
    if (!_crisis && inputs.values.any((c) => SafetyValve.isCrisis(c.text))) {
      setState(() => _crisis = true);
      widget.onCrisis();
    }
  }

  @override
  void dispose() {
    for (final c in inputs.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _finish({bool pause = false}) {
    if (_crisis) return;
    Navigator.pop(
        context,
        TalPracticeDraft(
            methodId: widget.method.id,
            values: {for (final e in inputs.entries) e.key: e.value.text},
            pause: pause,
            caseId: widget.caseId,
            affirmedSignals: {
              if (_gateAccepted &&
                  ['learn_to_fail', 'stretch_zone'].contains(widget.method.id))
                'challenge_is_safe',
              if (_gateAccepted &&
                  widget.method.id == 'five_minute_takeoff') ...[
                'physical_conditions_ok',
                if (widget.previouslyNotHelped) 'user_asks_to_retry'
              ],
              if (_gateAccepted && widget.method.id == 'benefit_finding') ...[
                'user_requests_benefit_finding',
                'emotionally_ready'
              ],
            }));
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.method.id;
    return Scaffold(
        appBar: AppBar(title: Text(talMethodNames[id] ?? widget.method.name)),
        body: _crisis
            ? const TalSafetyCard()
            : ListView(padding: const EdgeInsets.all(20), children: [
                Text(widget.method.exercise,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                Text(widget.method.limit),
                if (widget.caseId != null)
                  const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('这是从案例得到的练习启发；不表示作者当时采用了 App 的流程。')),
                if (_needsGate && !_gateAccepted) ...[
                  const SizedBox(height: 20),
                  Text(switch (id) {
                    'benefit_finding' => '你现在愿意找一点真实的教训或收获吗？不愿意可以先停留。',
                    'five_minute_takeoff' => widget.previouslyNotHelped
                        ? '你之前记录过没有帮助。这次是你主动想换情境重试，且休息和身体条件允许吗？'
                        : '你仍想做这件事，而且现在的休息和身体条件允许吗？',
                    _ => '这次尝试的风险和损失，是你能够承受的吗？不确定时先不做挑战。',
                  }),
                  const SizedBox(height: 12),
                  FilledButton(
                      onPressed: () => setState(() => _gateAccepted = true),
                      child: Text(id == 'benefit_finding' ? '我愿意' : '是，我确认')),
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('先不做这个练习')),
                ] else ...[
                  if (id == 'prp') ...[
                    const SizedBox(height: 16),
                    const Text('三个入口可自由往返。可以先拉远视野，也可以停留；不必完成全部。'),
                    Wrap(spacing: 6, children: [
                      for (final step in const {
                        'permission': '允许',
                        'reconstruction': '重构',
                        'perspective': '拉远视野'
                      }.entries)
                        ChoiceChip(
                            label: Text(step.value),
                            selected: _prpStep == step.key,
                            onSelected: (_) =>
                                setState(() => _prpStep = step.key))
                    ]),
                  ],
                  for (final field in fields.entries)
                    if (id != 'prp' || field.key == _prpStep)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: TextField(
                              key: ValueKey('practice_${field.key}'),
                              controller: inputs[field.key],
                              minLines: 2,
                              maxLines: 5,
                              maxLength: 10000,
                              decoration: InputDecoration(
                                  labelText: field.value,
                                  counterText: '',
                                  border: const OutlineInputBorder()))),
                  const SizedBox(height: 14),
                  FilledButton(
                      key: const ValueKey('tal_use_practice'),
                      onPressed: _finish,
                      child: const Text('带回这次记录，继续由我决定')),
                  TextButton(
                      onPressed: () => _finish(pause: true),
                      child: const Text('先留在这里，暂不行动')),
                ],
                ExpansionTile(title: const Text('出处与适用边界'), children: [
                  Text(widget.method.attribution),
                  const Text('练习问题的组织和下一行动的安排由 App 补充。'),
                  TalSourceLinks(
                      catalog: widget.catalog, ids: widget.method.sources),
                ]),
              ]));
  }
}
