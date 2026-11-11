import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../beautiful_enemy/src/domain/guard.dart' show SafetyValve;
import '../../prp_plugin/prp_plugin.dart';
import 'tal_ai_contract.dart';
import 'tal_catalog.dart';
import 'tal_ledger.dart';
import 'tal_models.dart';
import 'tal_practice.dart';
import 'tal_shared_views.dart';
import 'tal_outcome.dart';

export 'tal_shared_views.dart' show TalSafetyCard, TalSourceLinks;

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
  const TalReflectionPage(
      {super.key,
      this.eventId,
      this.environment,
      this.returnAfterSave = false});
  final String? eventId;
  final TalEnvironment? environment;
  final bool returnAfterSave;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('记录一次经历')),
        body: SafeArea(
            child: SingleChildScrollView(
                child: TalReflectionPanel(
          eventId: eventId,
          environment: environment,
          onSaved: (record) async {
            if (!context.mounted) return;
            if (returnAfterSave) {
              Navigator.of(context).pop(record);
            } else {
              await Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                      builder: (_) => TalRecordPage(
                          eventId: record.eventId, environment: environment)));
            }
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
    'other_gains',
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
          if (e.key.startsWith('draft_')) continue;
          if (!_inputs.containsKey(e.key)) {
            _inputs[e.key] = TextEditingController()..addListener(_edited);
          }
          _inputs[e.key]!.text = e.value;
        }
        _rejected.addAll(old.rejectedMethods);
        _choice = old.choice;
        _reminderConsent = old.reminderConsent;
        _inputs['action']!.text =
            old.reflection['draft_action'] ?? old.currentTrial?.action ?? '';
        _inputs['trigger']!.text =
            old.reflection['draft_trigger'] ?? old.currentTrial?.trigger ?? '';
        _inputs['check']!.text =
            old.reflection['draft_check'] ?? old.currentTrial?.check ?? '';
        _method = old.currentTrial?.methodId == 'personal_trial'
            ? null
            : old.currentTrial?.methodId;
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

  Future<void> _save(
      {bool planAction = false, bool pauseAction = false}) async {
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
      if (pauseAction) _choice = TalChoice.pause;
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
            'draft_action': _inputs['action']!.text,
            'draft_trigger': _inputs['trigger']!.text,
            'draft_check': _inputs['check']!.text,
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
            reason: _chosenReason.isNotEmpty
                ? _chosenReason
                : _method == null
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
    final adopt = await showDialog<bool>(
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
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('不采用，返回记录')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('采用候选，放进可编辑草稿'))
              ],
            ));
    if (adopt != true ||
        !mounted ||
        _crisis ||
        !_aiConsent ||
        env.aiEnabled?.call() != true ||
        _editEpoch != epoch) return;
    final trial = result['proposed_trial'] as Map;
    for (final e in const {
      'action': 'action',
      'trigger': 'trigger_or_time',
      'check': 'completion_evidence'
    }.entries) {
      _inputs[e.key]!.text = trial[e.value] as String;
    }
    if (_inputs['lessons']!.text.trim().isEmpty) {
      _inputs['lessons']!.text =
          result['meaning']['tentative_learning'] as String;
    }
    _goStep(3);
    setState(() {
      _message = '已放入草稿，可以修改。是否继续、调整或退出，仍由你决定。';
    });
  }

  int _step = 0;
  String _chosenReason = '';
  static const _stepNames = ['事实', '经历', '认识', '下一次', '保存'];

  void _goStep(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted)
        unawaited(Scrollable.ensureVisible(context,
            alignment: 0, duration: const Duration(milliseconds: 180)));
    });
  }

  Future<void> _openPractice(String id, {String? caseId}) async {
    if (_busy || _crisis) return;
    final method = _catalog!.methods[id];
    if (method == null) return;
    final result = await Navigator.of(context).push<TalPracticeDraft>(
        MaterialPageRoute(
            builder: (_) => TalPracticePage(
                catalog: _catalog!,
                method: method,
                initialValues: {
                  for (final e in _inputs.entries) e.key: e.value.text
                },
                caseId: caseId,
                onCrisis: _enterSafety,
                previouslyNotHelped: _record?.trials.any((t) =>
                            t.methodId == id &&
                            t.state == TalState.outcomeNotHelped) ==
                        true ||
                    id == 'five_minute_takeoff' &&
                        _allSignals.contains('prior_method_not_helped'))));
    if (mounted && result != null && !_crisis) _applyPractice(result);
  }

  void _applyPractice(TalPracticeDraft result) {
    for (final e in result.values.entries) {
      if (!_inputs.containsKey(e.key)) {
        _inputs[e.key] = TextEditingController()..addListener(_edited);
      }
      _inputs[e.key]!.text = e.value;
    }
    if (result.caseId != null &&
        result.values.values.any((s) => s.trim().isNotEmpty)) {
      _inputs
          .putIfAbsent('source_case',
              () => TextEditingController()..addListener(_edited))
          .text = result.caseId!;
    }
    _goStep(result.pause ? 4 : 2);
    setState(() {
      _signals.addAll(result.affirmedSignals);
      _method = result.methodId;
      _chosenReason = result.caseId == null
          ? '用户主动选择练习并保留了自己的记录'
          : '用户从案例 ${result.caseId} 选择练习；案例映射不代表作者采用了 App 步骤';
      if (result.pause) _choice = TalChoice.pause;
      _message = '练习已带回当前草稿，保存后才进入学习卡。';
    });
  }

  Future<void> _openCases() async {
    final result = await Navigator.of(context).push<TalPracticeDraft>(
        MaterialPageRoute(
            builder: (_) => TalCasePage(
                catalog: _catalog!,
                initialValues: {
                  for (final e in _inputs.entries) e.key: e.value.text
                },
                onCrisis: _enterSafety)));
    if (mounted && result != null && !_crisis) _applyPractice(result);
  }

  Future<void> _methods() async {
    final route = _route;
    final selected = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (ctx) => SizedBox(
            height: MediaQuery.sizeOf(ctx).height * .78,
            child: ListView(padding: const EdgeInsets.all(20), children: [
              Text('需要时，选一个练习', style: Theme.of(ctx).textTheme.titleLarge),
              const Text('可直接返回自己的记录，不用为了复盘把所有方法都做一遍。'),
              if (route.route == 'review_goal_no_failure_label')
                const Text('先考虑这个目标是否还适合，退出也可以。'),
              for (final recommendation in route.methods)
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                  talMethodNames[recommendation.method.id] ??
                                      recommendation.method.name,
                                  style: Theme.of(ctx).textTheme.titleMedium),
                              Text(
                                  '依据：${recommendation.basis.map(_basisLabel).join('、')}'),
                              ExpansionTile(
                                  title: const Text('为什么推荐、什么时候换方法'),
                                  children: [
                                    Text(recommendation.method.exercise),
                                    Text(recommendation.uncertainty),
                                    Text(recommendation.method.limit),
                                    Text(recommendation.whenToSwitch),
                                    TalSourceLinks(
                                        catalog: _catalog!,
                                        ids: recommendation.method.sources),
                                  ]),
                              FilledButton(
                                  onPressed: () => Navigator.pop(
                                      ctx, recommendation.method.id),
                                  child: const Text('做这个练习')),
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx,
                                      'reject:${recommendation.method.id}'),
                                  child: const Text('不适用，换一种')),
                            ]))),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, 'cases'),
                  child: const Text('从塔尔的真实案例选一个练习')),
              ExpansionTile(title: const Text('自己选择其他练习'), children: [
                for (final m in _catalog!.methods.values)
                  if (!_rejected.contains(m.id))
                    ListTile(
                        title: Text(talMethodNames[m.id] ?? m.name),
                        subtitle: Text(m.limit),
                        onTap: () => Navigator.pop(ctx, m.id)),
              ]),
            ])));
    if (!mounted || selected == null || _crisis) return;
    if (selected.startsWith('reject:')) {
      final id = selected.substring(7);
      setState(() {
        _rejected.add(id);
        if (_method == id) _method = null;
      });
      if (_record != null)
        _record = await env.ledger.rejectMethod(_eventId, id);
      if (mounted) await _methods();
    } else if (selected == 'cases') {
      await _openCases();
    } else {
      await _openPractice(selected);
    }
  }

  Future<void> _more() async {
    final selection = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  title: const Text('简短记录 · 1–3 分钟'),
                  onTap: () => Navigator.pop(ctx, 'quick')),
              ListTile(
                  title: const Text('标准书写 · 10–15 分钟'),
                  onTap: () => Navigator.pop(ctx, 'standard')),
              ListTile(
                  title: const Text('原著 PRP 三步 · 可自由往返'),
                  onTap: () => Navigator.pop(ctx, 'prp')),
              ListTile(
                  title: const Text('塔尔真实案例'),
                  onTap: () => Navigator.pop(ctx, 'cases')),
              ListTile(
                  title: const Text('可选 AI 整理'),
                  onTap: () => Navigator.pop(ctx, 'ai')),
              if (widget.onLegacyExercise != null)
                ListTile(
                    title: const Text('改用已有 App 完整练习（双栏 / 盖印等扩展）'),
                    onTap: () => Navigator.pop(ctx, 'legacy')),
            ])));
    if (!mounted || selection == null || _crisis) return;
    switch (selection) {
      case 'quick':
        setState(() => _mode = 'quick');
      case 'standard':
        setState(() {
          _mode = 'standard';
        });
        _goStep(1);
      case 'prp':
        await _openPractice('prp');
      case 'cases':
        await _openCases();
      case 'ai':
        await _useAi();
      case 'legacy':
        widget.onLegacyExercise?.call();
    }
  }

  bool get _hasPlan =>
      [TalChoice.continueGoal, TalChoice.adjust].contains(_choice) &&
      ['action', 'trigger', 'check']
          .every((k) => _inputs[k]!.text.trim().isNotEmpty);

  Widget _stepContent() => switch (_step) {
        0 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('先记事实，不急着给这次经历下结论。也可以记录成功经验。'),
            _field('plan', '原计划是什么？（可跳过）'),
            _field('observed', '实际发生了什么？（可跳过）'),
            TextButton(
                onPressed: () => _goStep(3), child: const Text('我想直接考虑下一次')),
          ]),
        1 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(_mode == 'standard'
                ? '完整写一写这次经历；所有问题仍可跳过。'
                : '随便记一点：当时做了什么、想了什么、有什么感受。不必找出原因。'),
            _field('did', _mode == 'standard' ? '当时做了什么？' : '当时的经历（可留空）'),
            if (_mode == 'standard') ...[
              _field('thought', '当时的想法'),
              _field('felt_then', '当时的感受'),
              _field('felt_now', '现在的感受'),
              _field('other_gains', '可能的其他收获（没有也可以）'),
            ] else
              ExpansionTile(title: const Text('我想把想法和感受分开记'), children: [
                _field('thought', '当时的想法'),
                _field('felt_then', '当时的感受'),
              ]),
            TextButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        final epoch = _editEpoch;
                        final text = await env.host.dictate();
                        if (mounted && text != null && _editEpoch == epoch)
                          _inputs['did']!.text = text;
                        else if (mounted && text == null)
                          setState(() => _message = '设备听写不可用，可以输入或跳过。');
                      },
                icon: const Icon(Icons.mic_none),
                label: const Text('用设备离线听写')),
          ]),
        2 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_method != null)
              ExpansionTile(
                  initiallyExpanded: true,
                  title: Text('刚才的练习：${talMethodNames[_method] ?? _method}'),
                  children: [
                    for (final key in [
                      'permission',
                      'reconstruction',
                      'perspective',
                      'keep_value',
                      'reduce_behavior',
                      'acknowledged_loss',
                      'basis',
                      'contradiction',
                      'prior_attempt',
                      'trial_result',
                      'recovery_condition'
                    ])
                      if (_inputs[key]?.text.trim().isNotEmpty == true)
                        _summaryLine(
                            const {
                              'permission': '允许',
                              'reconstruction': '重构',
                              'perspective': '拉远视野',
                              'keep_value': '希望保留',
                              'reduce_behavior': '希望减少',
                              'acknowledged_loss': '真实损失',
                              'basis': '支持事实',
                              'contradiction': '补充事实',
                              'prior_attempt': '先前尝试',
                              'trial_result': '先前结果',
                              'recovery_condition': '恢复条件'
                            }[key]!,
                            _inputs[key]!.text),
                    TextButton(
                        onPressed: () => _openPractice(_method!),
                        child: const Text('回到刚才的练习，继续改写')),
                  ]),
            const Text('现在知道一点什么？还不知道什么？没有教训也能保存。'),
            _field('lessons', '目前获得的认识（可留空）'),
            Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                    label: const Text('还不清楚'),
                    onPressed: () => _inputs['lessons']!.text = '还不清楚')),
            _field('known_unknown', '仍然不清楚的地方（可跳过）'),
            TextButton(onPressed: _methods, child: const Text('需要帮助时，试一个练习')),
            TextButton(
                onPressed: _openCases, child: const Text('看看塔尔怎样处理类似经历')),
          ]),
        3 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('这个目标接下来怎么处理，由你决定。'),
            Wrap(spacing: 8, children: [
              for (final choice in const [
                TalChoice.continueGoal,
                TalChoice.adjust,
                TalChoice.exit,
                TalChoice.pause
              ])
                ChoiceChip(
                    label: Text(choice.label),
                    selected: _choice == choice,
                    onSelected: (_) => setState(() => _choice = choice))
            ]),
            if (_choice == TalChoice.exit)
              const Text('退出不合适的目标是一个选择，不自动计为失败。')
            else if (_choice == TalChoice.pause)
              const Text('可以先放下，不安排新行动，也不催你复盘。')
            else if ([TalChoice.continueGoal, TalChoice.adjust]
                .contains(_choice)) ...[
              const Text('如果愿意，只选一个具体变化；也可以先不定行动。'),
              if (_method != null)
                Text('本次参考：${talMethodNames[_method] ?? _method}'),
              _field('action', '下一次具体做什么？', hint: '例如：收藏 1 个符合条件的岗位'),
              _field('trigger', '什么时候或什么情境下做？'),
              _field('check', '怎么检查是否做了、结果怎样？'),
              TextButton(
                  onPressed: _methods, child: const Text('想不到做法，选一个练习试试')),
            ],
          ]),
        _ => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _summaryLine('原计划', _inputs['plan']!.text),
            _summaryLine('实际', _inputs['observed']!.text),
            _summaryLine('目前的认识', _inputs['lessons']!.text),
            _summaryLine('接下来', _choice.label),
            if (_hasPlan) ...[
              _summaryLine('只试这一项', _inputs['action']!.text),
              _summaryLine('时机', _inputs['trigger']!.text),
              _summaryLine('检查', _inputs['check']!.text),
              CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _reminderConsent,
                  onChanged: (v) =>
                      setState(() => _reminderConsent = v == true),
                  title: const Text('下次相关行动时，显示这条计划'),
                  subtitle: const Text('可关闭，沿用现有静默与额度。')),
              const Text('先保存计划，现实中做过以后，只记录有没有做和实际结果。'),
            ] else
              Text(_choice == TalChoice.exit
                  ? '这次保存退出的选择。'
                  : _choice == TalChoice.pause
                      ? '先保存，暂不安排回访。'
                      : '先保存记录。没定完整的行动会保留在草稿里，不算已经执行。'),
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
          ]),
      };

  Widget _summaryLine(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Text('$label：${value.trim().isEmpty ? '暂未填写' : value}'));

  @override
  Widget build(BuildContext context) {
    if (_crisis) return const TalSafetyCard();
    if (_catalog == null)
      return Padding(
          padding: const EdgeInsets.all(20),
          child: Text(_message.isEmpty ? '正在读取本地练习…' : _message));
    return Padding(
        padding: const EdgeInsets.all(20),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('这次没有按计划发生什么？', style: Theme.of(context).textTheme.titleLarge),
          Row(children: [
            Expanded(
                child: Text(
                    _mode == 'standard' ? '标准书写 · 按自己的节奏' : '简短记录 · 约 1–3 分钟')),
            TextButton(
                onPressed: _busy ? null : _more, child: const Text('练习方式'))
          ]),
          Wrap(spacing: 4, children: [
            for (var i = 0; i < _stepNames.length; i++)
              ChoiceChip(
                  key: ValueKey('tal_step_$i'),
                  label: Text(_stepNames[i]),
                  showCheckmark: false,
                  selected: _step == i,
                  onSelected: _busy ? null : (_) => _goStep(i))
          ]),
          const SizedBox(height: 16),
          Text('${_step + 1}/5 · ${_stepNames[_step]}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          _stepContent(),
          if (_step == 0)
            const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('涉及他人真实损失时，可以先考虑承担责任和适当补救。')),
          if (_message.isNotEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_message)),
          const SizedBox(height: 18),
          if (_step < 4) ...[
            FilledButton(
                key: const ValueKey('tal_flow_next'),
                onPressed: _busy ? null : () => _goStep(_step + 1),
                child: const Text('下一步')),
            TextButton(
                key: const ValueKey('tal_flow_skip'),
                onPressed: _busy ? null : () => _goStep(_step + 1),
                child: const Text('跳过这一步')),
          ] else
            FilledButton(
                key: const ValueKey('tal_save_flow'),
                onPressed: _busy ? null : () => _save(planAction: _hasPlan),
                child: Text(_busy
                    ? '保存中…'
                    : _hasPlan
                        ? '保存计划，等待现实验证'
                        : '保存这次记录')),
          OutlinedButton(
              key: const ValueKey('tal_save_draft'),
              onPressed: _busy ? null : () => _save(pauseAction: true),
              child: const Text('先保存到这里，暂不行动')),
          if (_step > 0)
            TextButton(
                onPressed: _busy ? null : () => _goStep(_step - 1),
                child: const Text('上一步')),
        ]));
  }
}

/// A follow-up never opens the whole learning card or a reflection form.
Future<TalRecord?> showTalOutcome(BuildContext context,
    {required TalRecord record,
    TalEnvironment? environment,
    Future<void> Function()? onCrisis}) async {
  if (record.currentTrial == null) return null;
  final env = environment ?? TalEnvironment.instance;
  final saved = await showModalBottomSheet<TalRecord>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => TalOutcomeSheet(
          record: record,
          ledger: env.ledger,
          onCrisis: onCrisis ?? env.safetyExit));
  if (saved != null) PrpPlugin.changed();
  return saved;
}

class TalCasePage extends StatelessWidget {
  const TalCasePage(
      {super.key,
      required this.catalog,
      this.methodId,
      this.initialValues = const {},
      this.onCrisis});
  final TalCatalog catalog;
  final String? methodId;
  final Map<String, String> initialValues;
  final VoidCallback? onCrisis;

  Future<void> _practice(
      BuildContext context, Map<String, dynamic> story, String id) async {
    final result =
        await Navigator.of(context).push<TalPracticeDraft>(MaterialPageRoute(
            builder: (_) => TalPracticePage(
                catalog: catalog,
                method: catalog.methods[id]!,
                initialValues: initialValues,
                caseId: '${story['case_id'] ?? story['id']}',
                onCrisis: onCrisis ??
                    () {
                      TalEnvironment.instance.safetyExit();
                    })));
    if (context.mounted && result != null) Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final stories = catalog.storiesFor(methodId);
    return Scaffold(
        appBar: AppBar(title: const Text('塔尔的真实案例')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('从一个与你有关的经历开始。只阅读也可以；故事不保证对你有效。'),
          for (var i = 0; i < stories.length; i++)
            Card(
                child: ExpansionTile(
                    key: ValueKey(
                        'tal_case_${stories[i]['case_id'] ?? stories[i]['id']}'),
                    initiallyExpanded: i == 0,
                    title: Text('${stories[i]['title']}'),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  Text(
                      '亲历事实与确定性：${stories[i]['evidence_level'] == 'external_report' ? '记者报道' : stories[i]['evidence_level'] == 'later_interpretation' ? '后来的个人诠释，事件当时的采用过程不详' : '作者亲述 / 原著记载'}'),
                  const SizedBox(height: 8),
                  Text('当时遇到的问题：${stories[i]['problem']}'),
                  const SizedBox(height: 8),
                  Text('明确做过什么：${stories[i]['reported_action'] ?? '不详'}'),
                  const SizedBox(height: 8),
                  Text('可确认结果：${stories[i]['reported_outcome'] ?? '不详'}'),
                  const SizedBox(height: 8),
                  Text(
                      '可对应练习：${(stories[i]['mapped_method_ids'] as List).map((id) => talMethodNames[id] ?? catalog.methods[id]?.name ?? id).join('、')}'),
                  Text('${stories[i]['mapping_disclaimer']}'),
                  const SizedBox(height: 12),
                  const Text(
                      '本地体验实验（App 设计）：选下面一个练习，把你的实际经历带进去。可以只保留认识，也可以自主选一个可承受的调整。'),
                  for (final id in List<String>.from(
                      stories[i]['mapped_method_ids'] as List))
                    if (catalog.methods.containsKey(id))
                      OutlinedButton(
                          key: ValueKey(
                              'tal_case_practice_${stories[i]['case_id'] ?? stories[i]['id']}_$id'),
                          onPressed: () => _practice(context, stories[i], id),
                          child: Text(
                              '试一试：${talMethodNames[id] ?? catalog.methods[id]!.name}')),
                  ExpansionTile(title: const Text('核对案例来源'), children: [
                    TalSourceLinks(
                        catalog: catalog,
                        ids: List<String>.from(
                            stories[i]['source_ids'] as List)),
                  ]),
                ])),
        ]));
  }
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
  final _revision = TextEditingController();
  final _personalReminder = TextEditingController();
  bool _busy = false, _crisis = false;
  @override
  void initState() {
    super.initState();
    for (final c in [_revision, _personalReminder]) {
      c.addListener(_guardInput);
    }
    _load();
  }

  void _guardInput() {
    if (!_crisis &&
        [_revision.text, _personalReminder.text].any(SafetyValve.isCrisis)) {
      setState(() => _crisis = true);
      unawaited(env.safetyExit().catchError((Object _) {}));
    }
  }

  Future<void> _load() async {
    try {
      final r = await env.ledger.get(widget.eventId);
      if (!mounted) return;
      _personalReminder.text = r?.reflection['personal_reminder'] ?? '';
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
    _revision.dispose();
    _personalReminder.dispose();
    super.dispose();
  }

  Future<void> _run(Future<TalRecord> Function() action) async {
    if (_busy || _crisis) return;
    _guardInput();
    if (_crisis) return;
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

  Future<void> _edit(TalRecord r) async {
    await Navigator.of(context).push<TalRecord>(MaterialPageRoute(
        builder: (_) => TalReflectionPage(
            eventId: r.eventId,
            environment: widget.environment,
            returnAfterSave: true)));
    if (mounted) await _load();
  }

  Widget _line(String label, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Text('$label：${text.trim().isEmpty ? '暂未填写' : text}'));

  String _feedback(Map<String, dynamic> e) =>
      '行动${e['action_done'] == true ? '做了' : e['action_done'] == false ? '没有做' : '还不确定'}；'
      '${e['outcome'] == 'helped' ? '这次有帮助' : e['outcome'] == 'not_helped' ? '这次没帮助' : '效果还不清楚'}'
      '${'${e['observed_outcome'] ?? ''}'.isEmpty ? '' : '\n${e['observed_outcome']}'}';

  @override
  Widget build(BuildContext context) {
    final r = _record;
    final trial = r?.currentTrial;
    final inactive =
        r?.choice == TalChoice.pause || r?.choice == TalChoice.exit;
    return Scaffold(
        appBar: AppBar(title: const Text('这次记录')),
        body: _crisis
            ? const TalSafetyCard()
            : r == null
                ? Center(child: Text(_message.isEmpty ? '正在读取…' : _message))
                : ListView(padding: const EdgeInsets.all(20), children: [
                    Text(
                        inactive
                            ? r.state.label
                            : trial == null
                                ? '已保存，可以先到这里'
                                : trial.evidence.isEmpty
                                    ? '计划已保存，等待现实验证'
                                    : '已记录这次实际结果',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    _line('原计划', r.plan),
                    _line('实际', r.observed),
                    _line('目前的认识', r.lesson.isEmpty ? '还不清楚' : r.lesson),
                    _line('接下来', r.choice.label),
                    if (trial != null && !inactive) ...[
                      Card(
                          child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _line('只试这一项', trial.action),
                                    _line('时机', trial.trigger),
                                    _line('检查', trial.check),
                                    if (trial.evidence.isNotEmpty)
                                      _line('最近一次反馈',
                                          _feedback(trial.evidence.last)),
                                  ]))),
                      const SizedBox(height: 12),
                      FilledButton(
                          key: const ValueKey('tal_open_feedback'),
                          onPressed: _busy
                              ? null
                              : () async {
                                  final result = await showTalOutcome(context,
                                      record: r,
                                      environment: env, onCrisis: () async {
                                    if (mounted) setState(() => _crisis = true);
                                    await env.safetyExit();
                                  });
                                  if (mounted && result != null)
                                    setState(() {
                                      _record = result;
                                      _message = '';
                                    });
                                },
                          child: Text(trial.evidence.isEmpty
                              ? '行动后，记录这次结果'
                              : '记录另一次实际结果')),
                      const Text('回访只核对行动和结果。未知可以保持未知，没有记录不代表失败。'),
                    ] else
                      Text(r.choice == TalChoice.exit
                          ? '退出不合适的目标，不计为失败。'
                          : r.choice == TalChoice.pause
                              ? '先放下，不安排新行动或催促回访。'
                              : '还没定行动也没关系，想继续时再回来。'),
                    OutlinedButton(
                        key: const ValueKey('tal_edit_record'),
                        onPressed: _busy ? null : () => _edit(r),
                        child: const Text('继续记录 / 调整 / 暂时放下 / 退出')),
                    if (_message.isNotEmpty) Text(_message),
                    const SizedBox(height: 12),
                    ExpansionTile(
                        key: const ValueKey('tal_history_section'),
                        title: const Text('查看练习、认识与证据历史'),
                        children: [
                          Text('${r.level} · ${r.state.label}'),
                          const Text('个人观察不确定因果；理解、计划、执行和稳定改变分别保留。'),
                          for (final e in r.reflection.entries)
                            if (e.value.trim().isNotEmpty &&
                                e.key != 'lessons' &&
                                !e.key.startsWith('draft_'))
                              _line(_reflectionLabel(e.key), e.value),
                          for (var i = 0; i < r.trials.length; i++)
                            Card(
                                child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                              '第 ${i + 1} 次计划 · ${talMethodNames[r.trials[i].methodId] ?? '个人试验'}'),
                                          _line('动作', r.trials[i].action),
                                          _line('时机', r.trials[i].trigger),
                                          _line('检查', r.trials[i].check),
                                          _line('选择依据', r.trials[i].reason),
                                          for (final e in r.trials[i].evidence)
                                            _line('实际反馈', _feedback(e)),
                                        ]))),
                          for (final revision in r.revisions)
                            ListTile(
                                title: Text(
                                    '认识 v${revision['version']} · ${revision['statement']}'),
                                subtitle: Text(
                                    '当时的证据引用：${(revision['evidence_ids'] as List).join('、')}')),
                          TextField(
                              key: const ValueKey('tal_lesson_revision'),
                              controller: _revision,
                              maxLines: 3,
                              maxLength: 10000,
                              decoration: const InputDecoration(
                                  labelText: '有了新事实，我想把认识改为…（可留空）')),
                          TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _run(() => env.ledger
                                      .reviseLesson(r.eventId, _revision.text)),
                              child: const Text('保存新认识，保留旧证据')),
                          if (r.trials.any((t) => t.evidence.any((e) =>
                              e['action_done'] == true &&
                              e['outcome'] == 'helped' &&
                              '${e['observed_outcome'] ?? ''}'
                                  .trim()
                                  .isNotEmpty))) ...[
                            TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _run(() =>
                                        env.ledger.validateLesson(r.eventId)),
                                child: const Text('我确认：这条认识有相关改善证据')),
                            TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _run(() => env.ledger
                                        .validateLesson(r.eventId,
                                            consolidated: true)),
                                child: const Text('我确认：多次情境已保持改善')),
                          ],
                        ]),
                    ExpansionTile(
                        key: const ValueKey('tal_personal_reminder_section'),
                        title: const Text('可选：改写为自己的个人提醒'),
                        children: [
                          const Text(
                              '逐条同意并开启首页个人提醒开关后，才显示自己的待验证认识，不作为名人名言或改变成果。'),
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
                    ExpansionTile(title: const Text('管理这条记录'), children: [
                      if (r.reminderConsent)
                        TextButton(
                            onPressed: _busy
                                ? null
                                : () => _run(() =>
                                    env.ledger.cancelReminders(r.eventId)),
                            child: const Text('关闭这条行动回访')),
                      if (r.aiConsent)
                        TextButton(
                            onPressed: _busy
                                ? null
                                : () =>
                                    _run(() => env.ledger.revokeAi(r.eventId)),
                            child: const Text('撤销此记录的 AI 授权')),
                      TextButton(
                          onPressed: _busy
                              ? null
                              : () async {
                                  await Clipboard.setData(
                                      ClipboardData(text: r.exportJson));
                                  if (mounted)
                                    setState(() =>
                                        _message = '已复制包含原文、版本与证据的 JSON。');
                                },
                          child: const Text('导出本条记录（复制 JSON）')),
                      TextButton(
                          onPressed: _busy
                              ? null
                              : () async {
                                  final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                              title: const Text('删除这条记录及其证据？'),
                                              content: const Text(
                                                  '将删除这条记录的反思、版本、行动与回访。'),
                                              actions: [
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, false),
                                                    child: const Text('保留')),
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, true),
                                                    child: const Text('删除'))
                                              ]));
                                  if (ok == true) {
                                    await env.ledger.delete(r.eventId);
                                    PrpPlugin.changed();
                                    if (context.mounted) Navigator.pop(context);
                                  }
                                },
                          child: const Text('删除该记录')),
                    ]),
                  ]));
  }

  String _reflectionLabel(String key) =>
      const {
        'did': '当时的经历',
        'thought': '当时的想法',
        'felt_then': '当时的感受',
        'felt_now': '现在的感受',
        'other_gains': '可能的其他收获',
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
        'acknowledged_loss': '承认的损失',
        'ritual_value': '珍视的价值',
        'risk_bounds': '停止界限',
        'recovery_condition': '恢复条件',
        'prior_attempt': '先前的尝试',
        'trial_result': '先前结果',
        'change_entry': '改变的入口',
        'source_case': '参考案例',
      }[key] ??
      key;
}
