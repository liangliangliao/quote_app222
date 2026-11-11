import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../beautiful_enemy/src/domain/guard.dart' show SafetyValve;
import '../../prp_plugin/prp_plugin.dart';
import 'tal_ai_contract.dart';
import 'tal_catalog.dart';
import 'tal_ledger.dart';
import 'tal_models.dart';

/// Registered by the existing PRP host. The local workflow also works before
/// registration and while the optional PRP plugin / AI switches are off.
class TalEnvironment {
  TalEnvironment(
      {TalLessonLedger? ledger,
      this.host = const NoopPrpHost(),
      this.aiEnabled,
      this.onCrisis})
      : ledger = ledger ?? TalLessonLedger();
  static TalEnvironment instance = TalEnvironment();
  final TalLessonLedger ledger;
  final PrpHost host;
  final bool Function()? aiEnabled;
  final Future<void> Function()? onCrisis;
  Future<void> safetyExit() async {
    if (onCrisis != null) {
      await onCrisis!();
    } else {
      await host.safetyExit();
    }
  }
}

const talSignalLabels = <String, String>{
  'self_condemnation': '因为情绪责怪自己',
  'catastrophizing': '把这次扩大成一辈子',
  'fatigue_or_sleep_concern': '疲劳 / 睡眠不足',
  'overloaded': '负担太多',
  'cannot_repeat': '偶尔能做，难持续',
  'prior_method_not_helped': '先前的方法没帮助',
  'hard_to_start': '愿意做但难启动',
  'physical_conditions_ok': '身体与休息条件允许',
  'avoids_due_to_failure_fear': '因为怕失败而回避',
  'challenge_is_safe': '这次尝试的损失可以承受',
  'challenge_too_large': '挑战一开始太难',
  'valued_positive_trait_linked_to_negative_trait': '怕改变后失去珍视的品质',
  'user_requests_benefit_finding': '我想寻找真实教训 / 收获',
  'emotionally_ready': '我现在愿意探索收获',
  'goal_no_longer_fits': '目标可能已不合适',
};

class TalReflectionPage extends StatelessWidget {
  const TalReflectionPage({super.key, this.eventId, this.environment});
  final String? eventId;
  final TalEnvironment? environment;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('今天一件没有按计划发生的事')),
        body: SafeArea(
            child: SingleChildScrollView(
                child: TalReflectionPanel(
          eventId: eventId,
          environment: environment,
          onSaved: (record) async {
            if (context.mounted)
              await Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                      builder: (_) => TalRecordPage(
                          eventId: record.eventId, environment: environment)));
          },
        ))),
      );
}

class TalReflectionPanel extends StatefulWidget {
  const TalReflectionPanel(
      {super.key,
      this.environment,
      this.eventId,
      this.subjectKey = '',
      this.initialPlan = '',
      this.initialObserved = '',
      this.source = 'manual',
      this.confirmed = false,
      this.onSaved,
      this.onLegacyExercise});
  final TalEnvironment? environment;
  final String? eventId;
  final String subjectKey, initialPlan, initialObserved, source;
  final bool confirmed;
  final Future<void> Function(TalRecord)? onSaved;
  final VoidCallback? onLegacyExercise;
  @override
  State<TalReflectionPanel> createState() => _TalReflectionPanelState();
}

class _TalReflectionPanelState extends State<TalReflectionPanel> {
  static const _fields = [
    'plan',
    'observed',
    'did',
    'thought',
    'felt_then',
    'felt_now',
    'lessons',
    'known_unknown',
    'permission',
    'reconstruction',
    'perspective',
    'keep_value',
    'reduce_behavior',
    'hypothesis',
    'basis',
    'contradiction',
    'action',
    'trigger',
    'check'
  ];
  final _inputs = {for (final key in _fields) key: TextEditingController()};
  late final String _eventId =
      widget.eventId ?? 'manual:${DateTime.now().microsecondsSinceEpoch}';
  TalEnvironment get env => widget.environment ?? TalEnvironment.instance;
  TalCatalog? _catalog;
  TalRecord? _record;
  final Set<String> _signals = {};
  final Set<String> _rejected = {};
  String? _method;
  String _mode = 'quick';
  String _prpStep = 'permission';
  TalChoice _choice = TalChoice.undecided;
  String _message = '';
  bool _busy = false, _crisis = false, _aiConsent = false;
  bool _reminderConsent = false;
  int _editEpoch = 0;

  @override
  void initState() {
    super.initState();
    _inputs['plan']!.text = widget.initialPlan;
    _inputs['observed']!.text = widget.initialObserved;
    for (final c in _inputs.values) {
      c.addListener(_edited);
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final catalog = await TalCatalog.load();
      final old =
          widget.eventId == null ? null : await env.ledger.get(_eventId);
      if (!mounted) return;
      if (old != null) {
        _inputs['plan']!.text = old.plan;
        _inputs['observed']!.text = old.observed;
        for (final e in old.reflection.entries) {
          _inputs[e.key]?.text = e.value;
        }
        _rejected.addAll(old.rejectedMethods);
        _choice = old.choice;
        _reminderConsent = old.reminderConsent;
        if (old.trials.any((t) => t.state == TalState.outcomeNotHelped)) {
          _signals.add('prior_method_not_helped');
        }
      }
      setState(() {
        _catalog = catalog;
        _record = old;
      });
    } catch (_) {
      if (mounted) setState(() => _message = '暂时无法读取记录，请返回后重试。');
    }
  }

  void _edited() {
    _editEpoch++;
    if (_method == 'five_minute_takeoff' &&
        _allSignals.any({
          'prior_method_not_helped',
          'fatigue_or_sleep_concern',
          'overloaded'
        }.contains)) {
      _method = null;
    }
    if (!_crisis && _inputs.values.any((c) => SafetyValve.isCrisis(c.text))) {
      _enterSafety();
    } else if (mounted && !_crisis) {
      setState(() {});
    }
  }

  void _enterSafety() {
    if (!mounted) return;
    setState(() {
      _crisis = true;
      _aiConsent = false;
      _editEpoch++;
    });
    unawaited(env.safetyExit().catchError((Object _) {}));
  }

  @override
  void dispose() {
    _aiConsent = false;
    _editEpoch++;
    for (final c in _inputs.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> get _observedSignals => TalRouter.observedSignals([
        'observed',
        'thought',
        'did',
        'felt_then',
        'felt_now',
        'known_unknown'
      ].map((key) => _inputs[key]!.text).join('\n'));
  Set<String> get _allSignals => {..._signals, ..._observedSignals.keys};
  Set<String> get _routingSignals => {
        ..._allSignals,
        'user_wants_reflection',
        if (widget.confirmed || _record?.confirmed == true)
          'event_user_confirmed',
        if (_choice == TalChoice.continueGoal || _choice == TalChoice.adjust)
          'user_chooses_goal',
        if (_allSignals.contains('prior_method_not_helped'))
          'user_wants_new_trial',
        if (_allSignals
            .contains('valued_positive_trait_linked_to_negative_trait'))
          'user_interested_in_exploration',
        if (_mode == 'prp') ...[
          'user_opted_in_to_prp',
          'user_wants_to_process_failure_emotion'
        ],
        if (_aiConsent) 'consented_ai',
        if (_choice == TalChoice.exit) 'goal_no_longer_fits',
      };
  TalRoute get _route => TalRouter(_catalog!)
          .route(_routingSignals, rejected: _rejected, notHelped: {
        for (final t in _record?.trials ?? <TalTrial>[])
          if (t.state == TalState.outcomeNotHelped) t.methodId
      });

  String _basisLabel(String signal) {
    final label = talSignalLabels[signal] ??
        const {
          'user_wants_reflection': '愿意记录或反思',
          'event_user_confirmed': '已确认这次经历',
          'user_chooses_goal': '自主选择继续目标',
          'user_wants_new_trial': '愿意换一种实测',
          'user_interested_in_exploration': '愿意探索价值冲突',
          'user_opted_in_to_prp': '主动选择 PRP',
          'user_wants_to_process_failure_emotion': '愿意处理这次体验',
        }[signal] ??
        signal;
    final quote = _observedSignals[signal];
    return quote == null ? label : '$label（原话：“$quote”）';
  }

  Widget _field(String key, String label, {String? hint}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: TextField(
          key: ValueKey('tal_$key'),
          controller: _inputs[key],
          minLines: 1,
          maxLines: 4,
          maxLength: 10000,
          decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              counterText: '',
              border: const OutlineInputBorder()),
        ),
      );

  Future<void> _save({bool planAction = false}) async {
    if (_busy || _crisis) return;
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      if (_inputs.values.any((c) => SafetyValve.isCrisis(c.text))) {
        _enterSafety();
        return;
      }
      if (planAction &&
          ['action', 'trigger', 'check']
              .any((k) => _inputs[k]!.text.trim().isEmpty)) {
        throw const FormatException('补上具体动作、时机和检查方式，或选择只保存记录。');
      }
      var r = _record ??
          await env.ledger.captureManualEvent(
              eventId: _eventId,
              subjectKey: widget.subjectKey,
              plan: _inputs['plan']!.text,
              observed: _inputs['observed']!.text,
              source: widget.source,
              confirmed: widget.confirmed);
      r = await env.ledger.saveDraft(r.eventId,
          plan: _inputs['plan']!.text,
          observed: _inputs['observed']!.text,
          reflection: {
            ...?_record?.reflection,
            for (final e in _inputs.entries)
              if (!['plan', 'observed', 'action', 'trigger', 'check']
                  .contains(e.key))
                e.key: e.value.text
          },
          choice: _choice,
          reminderConsent:
              _reminderConsent && (planAction || _record?.currentTrial != null),
          aiConsent: _aiConsent);
      for (final id in _rejected) {
        r = await env.ledger.rejectMethod(r.eventId, id);
      }
      if (planAction) {
        r = await env.ledger.recordTrial(r.eventId,
            methodId: _method ?? 'personal_trial',
            action: _inputs['action']!.text.trim(),
            trigger: _inputs['trigger']!.text.trim(),
            check: _inputs['check']!.text.trim(),
            reason: _method == null
                ? '用户自主选择的个人试验'
                : _route.methods
                    .where((m) => m.method.id == _method)
                    .map((m) => m.basis.join(' / '))
                    .join());
      }
      if (!mounted || _crisis) return;
      _record = r;
      PrpPlugin.changed();
      setState(() => _message = '已保存在学习卡 · ${r.state.label}。尚未验证可以保持原样。');
      await widget.onSaved?.call(r);
    } on TalCrisisException {
      _enterSafety();
    } catch (e) {
      if (mounted)
        setState(() => _message = e is FormatException
            ? e.message
            : e is StateError
                ? e.message
                : '保存未完成，请稍后重试。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _useAi() async {
    if (_busy || _crisis || _catalog == null) return;
    if (env.aiEnabled?.call() != true) {
      setState(() => _message = 'AI 未开启。可继续使用本地模板；如需 AI，请在现有 PRP 设置中独立授权。');
      return;
    }
    final original = _inputs.entries
        .where((e) => !['action', 'trigger', 'check'].contains(e.key))
        .map((e) => e.value.text)
        .where((v) => v.isNotEmpty)
        .join('\n');
    final consent = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('本次发送 AI 的内容'),
              content: SingleChildScrollView(
                  child: Text('将通过已有 AI 服务发送以下本次输入及候选方法说明，不读取其他历史。'
                      '结果仅作参考，不会替你确认行动或教训。\n\n$original')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('仅用本地')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('同意本次发送'))
              ],
            ));
    if (consent != true || !mounted || _crisis) return;
    final epoch = _editEpoch;
    setState(() {
      _aiConsent = true;
      _busy = true;
    });
    final assistant = TalAiAssistant(
        contract: TalAiContract(_catalog!),
        call: (input) => env.host.callAi('tal_extract', input),
        consented: () =>
            mounted &&
            !_crisis &&
            _aiConsent &&
            env.aiEnabled?.call() == true &&
            _editEpoch == epoch);
    final result = await assistant.extract(
        original, _route.methods.map((m) => m.method.id).toSet());
    if (!mounted) return;
    setState(() => _busy = false);
    if (result == null || _editEpoch != epoch) {
      setState(() => _message = 'AI 暂不可用、内容不符合契约或输入已修改；本地模板继续可用。');
      return;
    }
    // Review only: an AI result never overwrites the user's current writing.
    await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('AI 候选 · 尚待你核对'),
              content: SingleChildScrollView(
                  child: Text(
                      '可观察事实：${(result['capture']['facts'] as List).map((e) => e['text']).join('；')}\n'
                      '未知：${(result['capture']['unknowns'] as List).join('；')}\n'
                      '待验证的认识：${result['meaning']['tentative_learning']}\n'
                      '可选行动：${result['proposed_trial']['action']}\n'
                      '时机：${result['proposed_trial']['trigger_or_time']}\n'
                      '检查：${result['proposed_trial']['completion_evidence']}\n'
                      '可以不采用，也可以在自己的记录中改写。')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('返回我的记录'))
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    if (_crisis) return const TalSafetyCard();
    if (_catalog == null)
      return Padding(
          padding: const EdgeInsets.all(20),
          child: Text(_message.isEmpty ? '正在读取本地练习…' : _message));
    final route = _route;
    return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('这次没有按计划发生什么？', style: Theme.of(context).textTheme.titleLarge),
            const Text('也可以记录成功经验。所有反思字段都可跳过，原因不清楚也可以保存。'),
            const Text('若涉及对他人的真实损失，可以先考虑承担责任和适当补救。'),
            const SizedBox(height: 12),
            SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'quick', label: Text('简短 1–3 分钟')),
                  ButtonSegment(value: 'standard', label: Text('标准')),
                  ButtonSegment(value: 'prp', label: Text('PRP 三步')),
                ],
                selected: {
                  _mode
                },
                onSelectionChanged:
                    _busy ? null : (v) => setState(() => _mode = v.single)),
            if (_mode == 'standard')
              const Text('标准书写约 10–15 分钟；按自己的节奏，也可以跳过任何字段。'),
            _field('plan', '原计划（可留空）'),
            _field('observed', '实际发生了什么（可留空）'),
            if (_mode == 'prp') ...[
              const Text('塔尔原著 PRP：Permission → Reconstruction → Perspective。'
                  '三步骤可以往返；不需要先完成情绪接纳，也不强迫寻找好处。'),
              Wrap(spacing: 6, children: [
                for (final step in const {
                  'permission': '允许事实与情绪',
                  'reconstruction': '重构',
                  'perspective': '拉远视野',
                }.entries)
                  ChoiceChip(
                      label: Text(step.value),
                      selected: _prpStep == step.key,
                      onSelected: (_) => setState(() => _prpStep = step.key))
              ]),
              _field(
                  _prpStep,
                  switch (_prpStep) {
                    'permission' => '此刻真实的情绪和事实（可停留）',
                    'reconstruction' => '能学到或调整什么（也可以暂时没有）',
                    _ => '放在一年后和全部生活里看（不淡化真实伤害）',
                  }),
            ],
            ExpansionTile(
                key: ValueKey('tal_experience_$_mode'),
                title: const Text('当时做了什么、想了什么、有什么感受？（可跳过）'),
                initiallyExpanded: _mode == 'standard',
                children: [
                  _field('did', '当时做了什么'),
                  _field('thought', '当时的想法 / 解释'),
                  _field('felt_then', '当时的感受'),
                  if (_mode == 'standard') _field('felt_now', '现在的感受'),
                  TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () async {
                              final epoch = _editEpoch;
                              final text = await env.host.dictate();
                              if (mounted &&
                                  text != null &&
                                  _editEpoch == epoch) {
                                _inputs['did']!.text = text;
                              } else if (mounted && text == null) {
                                setState(() => _message = '设备听写不可用，可以直接输入。');
                              }
                            },
                      icon: const Icon(Icons.mic_none),
                      label: const Text('设备离线听写（可选）')),
                ]),
            _field('lessons', '目前获得的认识', hint: '还不清楚 / 暂时没有，也可以'),
            _field('known_unknown', '哪些仍不知道？（可留空）'),
            DropdownButtonFormField<TalChoice>(
                key: ValueKey(_choice),
                initialValue: _choice,
                decoration: const InputDecoration(labelText: '下一次由你决定'),
                items: [
                  for (final c in TalChoice.values)
                    DropdownMenuItem(value: c, child: Text(c.label))
                ],
                onChanged: _busy
                    ? null
                    : (c) => setState(() {
                          _choice = c!;
                          _editEpoch++;
                        })),
            if (_choice == TalChoice.exit) const Text('退出不合适的目标是一种选择，不自动算失败。'),
            ExpansionTile(title: const Text('选择方法（可拒绝，也可以不用）'), children: [
              const Text('只按你主动选择的情况推荐。以下是产品工程规则，不是心理诊断。'),
              Wrap(spacing: 6, children: [
                for (final e in talSignalLabels.entries)
                  FilterChip(
                      label: Text(e.value),
                      selected: _signals.contains(e.key),
                      onSelected: (v) => setState(() {
                            v ? _signals.add(e.key) : _signals.remove(e.key);
                            _editEpoch++;
                            _method = null;
                          }))
              ]),
              if (route.route == 'review_goal_no_failure_label')
                const Text('先重新评估目标是否适合，允许继续、调整或退出。'),
              for (final recommendation in route.methods)
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(recommendation.method.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              Text(
                                  '选择依据：${recommendation.basis.map(_basisLabel).join('、')}'),
                              Text('为什么试它：${recommendation.method.exercise}'),
                              Text(recommendation.uncertainty),
                              Text('适用边界：${recommendation.method.limit}'),
                              Text(recommendation.whenToSwitch),
                              Text(recommendation.method.attribution),
                              Wrap(spacing: 6, children: [
                                TextButton(
                                    onPressed: () => setState(() {
                                          _method = recommendation.method.id;
                                          _editEpoch++;
                                        }),
                                    child: Text(
                                        _method == recommendation.method.id
                                            ? '已选作本次干预'
                                            : '本次试这一种')),
                                TextButton(
                                    onPressed: () => setState(() {
                                          _rejected
                                              .add(recommendation.method.id);
                                          if (_method ==
                                              recommendation.method.id)
                                            _method = null;
                                          _editEpoch++;
                                        }),
                                    child: const Text('不适用')),
                              ]),
                              TalSourceLinks(
                                  catalog: _catalog!,
                                  ids: recommendation.method.sources),
                            ]))),
              if (_method == 'unbundling') ...[
                _field('keep_value', '我希望保留的品质 / 价值'),
                _field('reduce_behavior', '我希望减少的行为 / 负担'),
              ],
              TextButton(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => TalCasePage(
                              catalog: _catalog!, methodId: _method))),
                  child: const Text('塔尔真实案例与原始出处')),
            ]),
            if (_choice == TalChoice.continueGoal ||
                _choice == TalChoice.adjust) ...[
              const Text('行动与后续验证是 App 扩展；一次试验只选一项主要干预。'),
              _field('action', '下一次的具体动作（可先不计划）', hint: '例如：打开招聘页，收藏 1 个合适岗位'),
              _field('trigger', '什么时候 / 什么情境下做'),
              _field('check', '怎么检查是否做了、结果如何'),
              CheckboxListTile(
                  value: _reminderConsent,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) =>
                      setState(() => _reminderConsent = v == true),
                  title: const Text('在下一次同类行动处显示这条计划'),
                  subtitle: const Text('可随时关闭；沿用现有回访额度与静默设置，不新增闹钟。')),
              FilledButton(
                  onPressed: _busy ? null : () => _save(planAction: true),
                  child: const Text('保存行动计划，等待验证')),
            ],
            ExpansionTile(title: const Text('主动深入（可选）'), children: [
              _field('hypothesis', '我目前的原因假设（尚未确认）'),
              _field('basis', '支持它的具体证据 / 原话'),
              _field('contradiction', '与它不一致的证据'),
              const Text('允许原因未知。涉及其他人的真实损失时，先考虑承担责任和适当补救。'),
            ]),
            TextButton(
                onPressed: _busy ? null : _useAi,
                child: const Text('可选：让已有 AI 帮我整理')),
            if (_aiConsent)
              TextButton(
                  onPressed: () async {
                    setState(() {
                      _aiConsent = false;
                      _editEpoch++;
                    });
                    if (_record != null) await env.ledger.revokeAi(_eventId);
                  },
                  child: const Text('撤销本次 AI 授权')),
            const Text('默认仅保存在本机。Explore Your Failures 来自塔尔原著；'
                '方法路由、行动计划、证据层级和回访均是 App 整合设计。'),
            if (widget.onLegacyExercise != null)
              TextButton(
                  onPressed: _busy ? null : widget.onLegacyExercise,
                  child: const Text('改用已有 App 完整练习（双栏 / 盖印等扩展）')),
            if (_message.isNotEmpty)
              Padding(padding: const EdgeInsets.all(8), child: Text(_message)),
            const SizedBox(height: 8),
            OutlinedButton(
                key: const ValueKey('tal_save_draft'),
                onPressed: _busy ? null : () => _save(),
                child: Text(_busy ? '保存中…' : '只保存记录 / 暂不分析')),
          ],
        ));
  }
}

class TalSafetyCard extends StatelessWidget {
  const TalSafetyCard({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('先照顾你的安全',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text('已停止复盘引导，这段危机文字不会保存或发送 AI。'
                '请联系可信任的人陪伴你；如果可能马上伤害自己，请联系当地急救或紧急服务，'
                '并尽量远离可用于伤害自己的物品。也可以向当地危机热线或专业人员求助。'),
          ]));
}

class TalSourceLinks extends StatelessWidget {
  const TalSourceLinks({super.key, required this.catalog, required this.ids});
  final TalCatalog catalog;
  final List<String> ids;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final id in ids)
          if (catalog.sources[id] case final Map source)
            TextButton(
                onPressed: () async {
                  final url = Uri.tryParse('${source['url']}');
                  if (url != null && url.scheme == 'https') {
                    try {
                      await launchUrl(url,
                          mode: LaunchMode.externalApplication);
                    } catch (_) {}
                  }
                },
                child: Text('$id · ${source['title']}'
                    '${source['caution'] == null ? '' : '\n${source['caution']}'}'
                    '${source['scope'] == null ? '' : '\n${source['scope']}'}'))
      ]);
}

class TalCasePage extends StatelessWidget {
  const TalCasePage({super.key, required this.catalog, this.methodId});
  final TalCatalog catalog;
  final String? methodId;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('真实案例 · 事实与边界')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('案例按来源库展示，不让 AI 补写作者内心。个人故事不能保证对你有效。'),
          for (final story in catalog.storiesFor(methodId))
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${story['title']}',
                              style: Theme.of(context).textTheme.titleMedium),
                          Text(
                              '亲历事实与确定性：${story['evidence_level'] == 'external_report' ? '记者报道' : story['evidence_level'] == 'later_interpretation' ? '后来的个人诠释，事件当时的采用过程不详' : '作者亲述 / 原著记载'}'),
                          Text('当时遇到的问题：${story['problem']}'),
                          Text('明确做过什么：${story['reported_action'] ?? '不详'}'),
                          Text('可确认结果：${story['reported_outcome'] ?? '不详'}'),
                          Text(
                              '可对应练习：${(story['mapped_method_ids'] as List).map((id) => catalog.methods[id]?.name ?? id).join('、')}\n${story['mapping_disclaimer']}'),
                          const Text(
                              '本地体验实验（产品设计）：自愿选一个可承受、可观察的小调整，记录时机与结果；不愿尝试可以只阅读。'),
                          TalSourceLinks(
                              catalog: catalog,
                              ids: List<String>.from(
                                  story['source_ids'] as List)),
                        ]))),
        ]),
      );
}

class TalRecordPage extends StatefulWidget {
  const TalRecordPage({super.key, required this.eventId, this.environment});
  final String eventId;
  final TalEnvironment? environment;
  @override
  State<TalRecordPage> createState() => _TalRecordPageState();
}

class _TalRecordPageState extends State<TalRecordPage> {
  TalEnvironment get env => widget.environment ?? TalEnvironment.instance;
  TalRecord? _record;
  String _message = '';
  final _observation = TextEditingController();
  final _context = TextEditingController();
  final _revision = TextEditingController();
  final _personalReminder = TextEditingController();
  late String _evidenceId = 'feedback:${DateTime.now().microsecondsSinceEpoch}';
  String _done = 'unknown', _outcome = 'unclear';
  bool _busy = false, _crisis = false;
  @override
  void initState() {
    super.initState();
    for (final c in [_observation, _context, _revision, _personalReminder]) {
      c.addListener(_guardInput);
    }
    _load();
  }

  void _guardInput() {
    if (!_crisis &&
        [
          _observation.text,
          _context.text,
          _revision.text,
          _personalReminder.text
        ].any(SafetyValve.isCrisis)) {
      setState(() => _crisis = true);
      unawaited(env.safetyExit().catchError((Object _) {}));
    }
  }

  Future<void> _load() async {
    try {
      final r = await env.ledger.get(widget.eventId);
      _personalReminder.text = r?.reflection['personal_reminder'] ?? '';
      if (mounted)
        setState(() {
          _record = r;
          _message = r == null ? '记录已删除。' : '';
        });
    } catch (_) {
      if (mounted) setState(() => _message = '记录暂时无法读取，请稍后重试。');
    }
  }

  @override
  void dispose() {
    _observation.dispose();
    _context.dispose();
    _revision.dispose();
    _personalReminder.dispose();
    super.dispose();
  }

  Future<void> _run(Future<TalRecord> Function() action) async {
    if (_busy || _crisis) return;
    if ([
      _observation.text,
      _context.text,
      _revision.text,
      _personalReminder.text
    ].any(SafetyValve.isCrisis)) {
      setState(() => _crisis = true);
      await env.safetyExit();
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await action();
      PrpPlugin.changed();
      if (mounted)
        setState(() {
          _record = r;
          _message = '已保存，历史证据保留。';
        });
    } on TalCrisisException {
      if (mounted) setState(() => _crisis = true);
      await env.safetyExit();
    } catch (e) {
      if (mounted)
        setState(() => _message = e is StateError
            ? e.message
            : e is FormatException
                ? e.message
                : '操作未完成，请稍后重试。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _record;
    return Scaffold(
        appBar: AppBar(title: const Text('学习卡 · 行动与证据')),
        body: _crisis
            ? const TalSafetyCard()
            : r == null
                ? Center(child: Text(_message.isEmpty ? '正在读取…' : _message))
                : ListView(padding: const EdgeInsets.all(16), children: [
                    Text('${r.level} · ${r.state.label}',
                        style: Theme.of(context).textTheme.titleLarge),
                    Text('原计划：${r.plan}\n实际：${r.observed}'),
                    Text('目前的认识：${r.lesson.isEmpty ? '还不清楚' : r.lesson}'),
                    Text('选择：${r.choice.label}'),
                    const Text('单次结果是个人观察，不能确定因果；没有日志不代表失败。'),
                    for (final e in r.reflection.entries)
                      if (e.value.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child:
                                Text('${_reflectionLabel(e.key)}：${e.value}')),
                    for (final t in r.trials)
                      Card(
                          child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${t.state.label} · ${t.methodId}'),
                                    Text(
                                        '动作：${t.action}\n时机：${t.trigger}\n检查：${t.check}'),
                                    for (final e in t.evidence)
                                      Text(
                                          '行动：${e['action_done'] == true ? '已做' : e['action_done'] == false ? '没做' : '未知'}；'
                                          '结果：${e['outcome']}\n${e['observed_outcome']}\n证据引用：${(e['evidence_refs'] as List? ?? []).join('、')}'),
                                  ]))),
                    if (r.currentTrial != null) ...[
                      const SizedBox(height: 12),
                      const Text('现实行动后，只核对有没有做、结果如何'),
                      DropdownButtonFormField<String>(
                          key: ValueKey('done:$_done'),
                          initialValue: _done,
                          decoration:
                              const InputDecoration(labelText: '计划动作发生了吗？'),
                          items: const [
                            DropdownMenuItem(
                                value: 'unknown', child: Text('还不知道')),
                            DropdownMenuItem(value: 'yes', child: Text('做了')),
                            DropdownMenuItem(value: 'no', child: Text('没有做'))
                          ],
                          onChanged:
                              _busy ? null : (v) => setState(() => _done = v!)),
                      DropdownButtonFormField<String>(
                          key: ValueKey('outcome:$_outcome'),
                          initialValue: _outcome,
                          decoration: const InputDecoration(labelText: '实际效果'),
                          items: const [
                            DropdownMenuItem(
                                value: 'unclear', child: Text('效果未知')),
                            DropdownMenuItem(
                                value: 'helped', child: Text('有帮助')),
                            DropdownMenuItem(
                                value: 'not_helped', child: Text('没有帮助'))
                          ],
                          onChanged: _busy
                              ? null
                              : (v) => setState(() => _outcome = v!)),
                      TextField(
                          key: const ValueKey('tal_feedback_observation'),
                          controller: _observation,
                          decoration:
                              const InputDecoration(labelText: '观察到的具体结果 / 证据'),
                          maxLines: 3),
                      TextField(
                          controller: _context,
                          decoration:
                              const InputDecoration(labelText: '这次的实际情境（可留空）')),
                      FilledButton(
                          key: const ValueKey('tal_save_feedback'),
                          onPressed: _busy
                              ? null
                              : () async {
                                  await _run(
                                      () => env.ledger.appendOutcome(r.eventId,
                                          trialId: r.currentTrial!.id,
                                          evidenceId: _evidenceId,
                                          actionDone: _done == 'yes'
                                              ? true
                                              : _done == 'no'
                                                  ? false
                                                  : null,
                                          outcome: _outcome,
                                          observation: _observation.text,
                                          context: _context.text));
                                },
                          child: const Text('记录这次反馈')),
                      TextButton(
                          onPressed: _busy
                              ? null
                              : () {
                                  setState(() {
                                    _evidenceId =
                                        'feedback:${DateTime.now().microsecondsSinceEpoch}';
                                    _done = 'unknown';
                                    _outcome = 'unclear';
                                    _observation.clear();
                                    _context.clear();
                                  });
                                },
                          child: const Text('开始记录另一次真实反馈')),
                      TextButton(
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  () => env.ledger.validateLesson(r.eventId)),
                          child: const Text('我确认：这条认识有相关改善证据')),
                      TextButton(
                          onPressed: _busy
                              ? null
                              : () => _run(() => env.ledger.validateLesson(
                                  r.eventId,
                                  consolidated: true)),
                          child: const Text('我确认：多次情境已保持改善')),
                    ],
                    TextField(
                        controller: _revision,
                        decoration: const InputDecoration(
                            labelText: '有了新事实，我想把认识改为…（可留空）'),
                        maxLines: 3),
                    OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() => env.ledger
                                .reviseLesson(r.eventId, _revision.text)),
                        child: const Text('保存新版本，保留旧证据')),
                    ExpansionTile(
                        title: Text('认识版本（${r.revisions.length}）'),
                        children: [
                          for (final revision in r.revisions)
                            ListTile(
                                title: Text(
                                    'v${revision['version']} · ${revision['statement']}'),
                                subtitle: Text(
                                    '当时的证据引用：${(revision['evidence_ids'] as List).join('、')}')),
                        ]),
                    TextButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                await Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                        builder: (_) => TalReflectionPage(
                                            eventId: r.eventId,
                                            environment: widget.environment)));
                                if (mounted) await _load();
                              },
                        child: const Text('继续 / 调整 / 暂时放下 / 退出目标')),
                    if (r.reminderConsent)
                      TextButton(
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  () => env.ledger.cancelReminders(r.eventId)),
                          child: const Text('关闭这条行动回访')),
                    if (r.aiConsent)
                      TextButton(
                          onPressed: _busy
                              ? null
                              : () =>
                                  _run(() => env.ledger.revokeAi(r.eventId)),
                          child: const Text('撤销此记录的 AI 授权')),
                    ExpansionTile(
                        key: const ValueKey('tal_personal_reminder_section'),
                        title: const Text('可选：改写为自己的个人提醒'),
                        children: [
                          const Text('只在你逐条同意并开启现有首页个人提醒开关后显示。'
                              '这是自己的待验证认识，不是名人名言，也不代表改变成功。'),
                          TextField(
                              key: const ValueKey('tal_personal_reminder'),
                              controller: _personalReminder,
                              maxLength: 120,
                              decoration: const InputDecoration(
                                  labelText: '用自己的话写一句提醒')),
                          TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _run(() => env.ledger
                                      .setPersonalReminder(
                                          r.eventId, _personalReminder.text,
                                          approved: true)),
                              child: const Text('我同意将这一句作为首页个人提醒')),
                          if (r.quoteConsent)
                            TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _run(() => env.ledger
                                        .setPersonalReminder(
                                            r.eventId, _personalReminder.text,
                                            approved: false)),
                                child: const Text('撤销此条首页展示授权')),
                        ]),
                    TextButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                await Clipboard.setData(
                                    ClipboardData(text: r.exportJson));
                                if (mounted)
                                  setState(() => _message =
                                      '已复制 JSON；包含原文、版本和证据，请自行选择分享对象。');
                              },
                        child: const Text('导出本条记录（复制 JSON）')),
                    TextButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                            title: const Text('删除这条学习卡及其证据？'),
                                            content: const Text(
                                                '将删除本条记录的反思、版本、行动与回访；其他旧记录保留。'),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, false),
                                                  child: const Text('保留')),
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, true),
                                                  child: const Text('删除'))
                                            ]));
                                if (ok == true) {
                                  await env.ledger.delete(r.eventId);
                                  PrpPlugin.changed();
                                  if (context.mounted) Navigator.pop(context);
                                }
                              },
                        child: const Text('删除该记录')),
                    if (_message.isNotEmpty) Text(_message),
                  ]));
  }

  String _reflectionLabel(String key) =>
      const {
        'did': '当时做了什么',
        'thought': '当时的想法',
        'felt_then': '当时的感受',
        'felt_now': '现在的感受',
        'lessons': '目前的认识',
        'known_unknown': '仍不知道',
        'permission': '允许事实与情绪',
        'reconstruction': '重构',
        'perspective': '拉远视野',
        'keep_value': '希望保留',
        'reduce_behavior': '希望减少',
        'hypothesis': '原因假设（未确认）',
        'basis': '支持证据',
        'contradiction': '相反证据',
        'personal_reminder': '自己的个人提醒',
      }[key] ??
      key;
}
