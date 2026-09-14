import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'evidence_growth_dao.dart';
import 'evidence_growth_journey_models.dart';
import 'evidence_growth_journey_store.dart';
import 'evidence_growth_notification_service.dart';
import '../platform/exact_alarm_permission_coordinator.dart';

typedef JourneyAction = Future<void> Function(GrowthJourney journey);
typedef JourneyTrial = Future<void> Function(String id);
typedef JourneyDraft = Future<GrowthData> Function(
    GrowthJourney journey, String purpose);
const _teal = Color(0xff24766c);

class EvidenceGrowthJourneyHome extends StatefulWidget {
  const EvidenceGrowthJourneyHome(
      {super.key, required this.dao, required this.onOpen});
  final EvidenceGrowthDao dao;
  final JourneyAction onOpen;
  @override
  State<EvidenceGrowthJourneyHome> createState() => _JourneyHomeState();
}

class _JourneyHomeState extends State<EvidenceGrowthJourneyHome> {
  final input = TextEditingController();
  List<GrowthJourney> journeys = [];
  GrowthData portfolio = {}, arbitration = {};
  bool busy = false;
  @override
  void initState() {
    super.initState();
    unawaited(reload());
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    final items = await widget.dao.journeys.list();
    final p = await widget.dao.journeys.portfolio();
    final a = await widget.dao.journeys.arbitration();
    if (mounted)
      setState(() {
        journeys = items;
        portfolio = p;
        arbitration = a;
      });
  }

  Future<void> enter() async {
    if (input.text.trim().isEmpty || busy) return;
    setState(() => busy = true);
    try {
      final text = input.text.trim();
      GrowthJourney? bound;
      if (journeys.any((j) => !j.terminal)) {
        final choice = await _choose(context, '这件事属于哪个目标？', {
          'new': '开启新的目标或探索',
          for (final j in journeys.where((j) => !j.terminal)) j.id: j.safeTitle
        });
        if (choice == null) return;
        if (choice != 'new') bound = journeys.firstWhere((j) => j.id == choice);
      }
      bound = bound == null
          ? await widget.dao.journeys.create(text)
          : await widget.dao.journeys.change(bound, 'entry', {'text': text});
      input.clear();
      if (mounted) await widget.onOpen(bound);
      await reload();
    } catch (e) {
      if (mounted) _error(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> budget() async {
    final current = growthMap(portfolio['budgets']);
    final values = await _fields(
        context,
        '这一阶段能投入多少？',
        {
          'minutes': '每日可用分钟',
          'money': '可用资金（自定同一单位）',
          'energy': '每日精力容量（0–10）',
          'risk': '可承受损失预算',
          'attention': '同时高优先目标数量'
        },
        initial: current.map((k, v) => MapEntry(k, '$v')));
    if (values == null) return;
    try {
      await widget.dao.journeys
          .savePortfolio(growthInt(portfolio['version']), {'budgets': values});
      await reload();
    } catch (e) {
      if (mounted) _error(context, e);
    }
  }

  Future<void> reserve(bool recovery) async {
    final range = await _timeRange(context);
    if (range == null) return;
    final field = recovery ? 'protected_recovery' : 'hard_commitments';
    await widget.dao.journeys.savePortfolio(growthInt(portfolio['version']), {
      field: [...growthRows(portfolio[field]), range]
    });
    await reload();
  }

  @override
  Widget build(BuildContext context) {
    final active = journeys
        .where((j) =>
            !j.terminal && !const ['PAUSED', 'PARKED'].contains(j.status))
        .toList();
    active.sort((a, b) => growthInt(
            growthMap(a.data['allocation'])['priority'], 2)
        .compareTo(growthInt(growthMap(b.data['allocation'])['priority'], 2)));
    return RefreshIndicator(
        onRefresh: reload,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('当前现实焦点',
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800, color: _teal)),
          const SizedBox(height: 8),
          const Text('从正在发生的事出发，让每次行动带回下一步所需的证据。'),
          const SizedBox(height: 16),
          TextField(
              key: const Key('journey-entry'),
              controller: input,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                  hintText: '想实现什么、遇到什么，或还不知道自己想要什么……',
                  border: OutlineInputBorder())),
          const SizedBox(height: 8),
          FilledButton.icon(
              onPressed: busy ? null : enter,
              icon: const Icon(Icons.arrow_forward),
              label: Text(busy ? '正在承接…' : '从这件事继续')),
          if (journeys.isEmpty)
            Wrap(
                spacing: 6,
                children: ['我不知道自己想要什么', '我想保持每周运动', '我又没开始，想换个办法']
                    .map((s) => ActionChip(
                        label: Text(s), onPressed: () => input.text = s))
                    .toList()),
          if (growthStrings(arbitration['conflicts']).isNotEmpty)
            _card(
                '先调整现实容量',
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ...growthStrings(arbitration['conflicts'])
                      .map((s) => Text('• $s')),
                  const SizedBox(height: 8),
                  const Text('可以降低范围、错开时间，或先把一个目标放下。')
                ])),
          const SizedBox(height: 16),
          ...active.take(3).map(tile),
          ExpansionTile(
              title: Text('全部目标与暂存（${journeys.length}）'),
              children: journeys.map(tile).toList()),
          ExpansionTile(
              title: const Text('时间、精力与恢复'),
              subtitle: const Text('组合预算与固定承诺共同约束行动安排'),
              children: [
                ListTile(
                    title: Text(
                        '每天 ${growthMap(portfolio['budgets'])['minutes'] ?? 120} 分钟 · 精力 ${growthMap(portfolio['budgets'])['energy'] ?? 6}'),
                    trailing: TextButton(
                        onPressed: budget, child: const Text('调整预算'))),
                Wrap(spacing: 8, children: [
                  TextButton.icon(
                      onPressed: () => reserve(true),
                      icon: const Icon(Icons.spa_outlined),
                      label: const Text('保护恢复时段')),
                  TextButton.icon(
                      onPressed: () => reserve(false),
                      icon: const Icon(Icons.event_available),
                      label: const Text('已有固定承诺'))
                ]),
                for (final field in ['protected_recovery', 'hard_commitments'])
                  for (final slot in growthRows(portfolio[field]))
                    ListTile(
                        title: Text(
                            field == 'protected_recovery' ? '恢复时段' : '固定承诺'),
                        subtitle: Text(
                            '${_date(growthInt(slot['start']))} — ${_date(growthInt(slot['end']))}'),
                        trailing: IconButton(
                            tooltip: '移除此时段',
                            icon: const Icon(Icons.close),
                            onPressed: () async {
                              await widget.dao.journeys.savePortfolio(
                                  growthInt(portfolio['version']), {
                                field: growthRows(portfolio[field])
                                    .where((s) => s['start'] != slot['start'])
                                    .toList()
                              });
                              await reload();
                            })),
              ]),
        ]));
  }

  Widget tile(GrowthJourney j) => Card(
      child: ListTile(
          title:
              Text(j.safeTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text('${j.statusLabel} · ${j.nodeLabel} · 第 ${j.cycle} 轮'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await widget.onOpen(j);
            await reload();
          }));
}

class EvidenceGrowthJourneyPage extends StatefulWidget {
  const EvidenceGrowthJourneyPage(
      {super.key,
      required this.journey,
      required this.dao,
      required this.onAction,
      required this.onTrial,
      required this.draft});
  final GrowthJourney journey;
  final EvidenceGrowthDao dao;
  final JourneyAction onAction;
  final JourneyTrial onTrial;
  final JourneyDraft draft;
  @override
  State<EvidenceGrowthJourneyPage> createState() => _JourneyPageState();
}

class _JourneyPageState extends State<EvidenceGrowthJourneyPage> {
  late GrowthJourney j = widget.journey;
  List<GrowthData> history = [];
  GrowthData deps = {};
  bool busy = false;
  String feedbackState = '';
  EvidenceGrowthJourneyStore get store => widget.dao.journeys;
  @override
  void initState() {
    super.initState();
    unawaited(reload());
  }

  Future<void> reload() async {
    final current = await store.find(j.id);
    final records = await store.history(j.id);
    final dependency = await store.dependencies(j.id);
    final feedback = await widget.dao
        .getSetting('feedback_state_${current?.trialId ?? j.trialId}');
    if (mounted)
      setState(() {
        j = current ?? j;
        history = records;
        deps = dependency;
        feedbackState = feedback;
      });
    unawaited(const EvidenceGrowthNotificationService().reconcile());
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      await reload();
    } catch (e) {
      if (mounted) _error(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> change(String op, [GrowthData b = const {}]) async {
    j = await store.change(j, op, b);
  }

  Future<void> contract() async {
    final draft = await widget.draft(j, 'contract');
    if (!mounted) return;
    final first = !j.confirmed;
    final v = await _fields(
        context, j.profile.mode == 'EXPLORE' ? '先定义本轮探索问题' : '核对目标与现实标准', {
      'goal': j.profile.mode == 'EXPLORE' ? '这轮想弄清什么' : '希望现实发生什么',
      'current': '现在已知的事实',
      'criterion': j.profile.mode == 'EXPLORE' ? '哪些现实反馈能帮助选择' : '什么事实算达到标准',
      'quality': '不能牺牲的边界（可选）',
      'belief': '当前判断或担心（可选）'
    },
        initial: {
          'goal': j.confirmed
              ? j.title
              : j.profile.mode == 'EXPLORE'
                  ? '通过低成本体验，了解可能想追求的方向'
                  : j.title,
          'current': j.data['current'] ?? j.data['raw_input'] ?? '',
          'criterion': j.contract['criterion'] ?? draft['criterion'] ?? '',
          'quality': j.contract['quality'] ?? '',
          'belief': j.data['belief'] ?? draft['belief'] ?? ''
        },
        requiredKeys: [
          'goal',
          'current',
          'criterion'
        ]);
    if (v == null) return;
    await change('contract', v);
    if (first &&
        j.data['legacy'] != true &&
        j.profile.fragments.any((f) => f['node'] == 'OUTCOME')) {
      if (!mounted) return;
      final choice = await _choose(context, '原话中提到了已经发生的结果',
          {'record': '核对这次结果，再决定是否复盘', 'later': '先保留原话，准备下一行动'});
      if (choice == 'record') await outcome();
    }
  }

  Future<void> outcome() async {
    final trial = j.trialId.isEmpty ? null : await widget.dao.byId(j.trialId);
    if (!mounted) return;
    final v = trial != null
        ? <String, String>{'facts': trial.actualOutcome}
        : await _fields(context, '核对实际发生了什么', {
            'facts': '只记录事实，不替对方推测想法'
          }, initial: {
            'facts': growthMap(j.data['outcome'])['facts'] ??
                j.data['pending_entry'] ??
                j.data['current'] ??
                j.data['raw_input'] ??
                ''
          }, requiredKeys: [
            'facts'
          ]);
    if (v == null || !mounted) return;
    var object = 'UNKNOWN';
    var explicit = false;
    if (RegExp(r'拒绝|不愿意|不同意').hasMatch(v['facts']!)) {
      object = await _choose(context, '明确被拒绝的是什么？', {
            'UNKNOWN': '暂不确定，保留事实',
            'INVITATION': '这次邀请',
            'PROPOSAL': '求婚或进入下一阶段',
            'RELATIONSHIP': '继续这段关系',
            'CONTACT': '继续联系',
            'APPLICATION': '申请或录用',
            'EVENT': '这次共同事件'
          }) ??
          'UNKNOWN';
      explicit = object != 'UNKNOWN';
    }
    await change('outcome',
        {'facts': v['facts'], 'object': object, 'explicit': explicit});
  }

  Future<void> readiness(String value) async {
    await change('readiness', {'value': value});
  }

  Future<void> remindReview() async {
    final at = await _pickDateTime(context);
    if (at == null || !mounted) return;
    final notifications = await const EvidenceGrowthNotificationService()
        .ensureNotificationsEnabled();
    if (!mounted) return;
    final allowed = await ExactAlarmPermissionCoordinator.ensureGranted(context,
        featureName: '稍后检查', explanation: '只按你选定的时间提醒一次，可继续暂缓。');
    if (notifications && allowed)
      await change('readiness',
          {'value': 'DEFERRED', 'remind_at_ms': at.millisecondsSinceEpoch});
  }

  Future<void> review() async {
    if (j.trialId.isNotEmpty) {
      await widget.onTrial(j.trialId);
      return;
    }
    final d = await widget.draft(j, 'review');
    if (!mounted) return;
    final v = await _fields(
        context, '从事实中带走一条学习', {'learning': '实际发生与原先想法有什么差异？'},
        initial: {'learning': d['learning'] ?? ''}, requiredKeys: ['learning']);
    if (v != null) await change('review', v);
  }

  Future<void> confirmChange() async {
    if (j.trialId.isNotEmpty) {
      await widget.onTrial(j.trialId);
      return;
    }
    final choice = await _choose(context, '这次学习改变哪一步？', {
      'KEEP': '保持有效条件',
      'MODIFY': '修改一个行动条件',
      'RECOVER': '先恢复，再继续',
      'NO_ACTION_YET': '暂不采取新行动',
      'EXIT': '停止当前尝试或路线'
    });
    if (choice == null || !mounted) return;
    final d = await widget.draft(j, 'change');
    if (!mounted) return;
    final v = await _fields(context, '确认一个具体改变', {
      'reason': '为什么这样调整',
      'next_action': '接下来具体怎么做（可选）',
      'belief_after': '现在如何看待原来的判断（可选）'
    }, initial: {
      'reason': d['reason'] ?? j.data['learning'] ?? '',
      'next_action': d['next_action'] ?? '',
      'belief_after': d['belief_after'] ?? ''
    }, requiredKeys: [
      'reason'
    ]);
    if (v != null) await change('change', {'target': choice, ...v});
  }

  Future<void> criterion() async {
    final v = await _fields(context, '补充达成依据', {'facts': '支持或不支持目标标准的现实事实'},
        requiredKeys: ['facts']);
    if (v == null || !mounted) return;
    final met = await _choose(
        context, '是否满足你定义的标准和质量边界？', {'no': '尚未全部满足', 'yes': '我确认已全部满足'});
    if (met != null)
      await change('criterion-evidence', {
        'facts': v['facts'],
        'met': met == 'yes',
        'quality_met': met == 'yes'
      });
  }

  Future<void> plan() async {
    final kind = await _choose(context, '计划如何改变？', {
      'MODIFY': '修改一处',
      'KEEP': '保留有效条件',
      'ADD': '增加一个条件',
      'REMOVE': '移除无效条件'
    });
    if (kind == null || !mounted) return;
    final field = await _choose(context, '调整计划的哪一部分？', {
      'strategy': '行动策略',
      'cadence': '行动节奏',
      'schedule': '时间安排',
      'resource_limit': '资源上限',
      'stop_rule': '停止规则',
      'selection_rule': '选择规则'
    });
    if (field == null || !mounted) return;
    final v = await _fields(
        context,
        '计划 v${growthInt(j.plan['version'])} → v${growthInt(j.plan['version']) + 1}',
        {
          'reason': '为什么要改',
          'evidence': '哪些实际反馈支持这次调整',
          'change': '具体保留、移除或改变什么',
          'expected_signal': '下一轮期待看到什么信号'
        },
        initial: {
          'evidence': j.data['current'] ?? '',
          'reason': j.data['learning'] ?? '',
          'change': j.plan[field] ?? ''
        },
        requiredKeys: [
          'reason',
          'evidence',
          'change',
          'expected_signal'
        ]);
    if (v != null)
      await change('plan', {'operation': kind, 'field': field, ...v});
  }

  Future<void> maintenance() async {
    final v = await _fields(
        context,
        '保持区间与恢复规则',
        {
          'acceptable_band': '可接受的稳定区间',
          'ritual': '要保留的习惯或环境条件',
          'check_days': '每隔几天检查一次',
          'drift_signals': '什么信号说明出现偏离',
          'recovery_rule': '偏离后如何温和恢复'
        },
        initial:
            growthMap(j.data['maintenance']).map((k, v) => MapEntry(k, '$v'))
              ..putIfAbsent('check_days', () => '7'),
        requiredKeys: [
          'acceptable_band',
          'ritual',
          'check_days',
          'drift_signals',
          'recovery_rule'
        ]);
    if (v != null) await change('maintenance-contract', v);
  }

  Future<void> maintenanceCheck() async {
    final v = await _fields(context, '一次低频检查', {'facts': '最近的实际状态'},
        requiredKeys: ['facts']);
    if (v == null || !mounted) return;
    final choice = await _choose(
        context, '目前还在可接受区间吗？', {'yes': '是，继续保持', 'no': '出现偏离，开启恢复周期'});
    if (choice != null)
      await change('maintenance-gate',
          {'facts': v['facts'], 'in_band': choice == 'yes'});
  }

  Future<void> candidate() async {
    final d = await widget.draft(j, 'candidate');
    if (!mounted) return;
    final v = await _fields(context, '保存候选方向', {
      'statement': '可能想尝试的方向',
      'evidence': '来自哪次现实样本',
      'positive': '感兴趣、有能量的部分（可选）',
      'negative': '不喜欢或有成本的部分（可选）',
      'unknowns': '仍需验证什么（可选）'
    }, initial: {
      'statement': d['statement'] ?? '',
      'evidence': j.data['current'] ?? ''
    }, requiredKeys: [
      'statement',
      'evidence'
    ]);
    if (v != null) await change('candidate', v);
  }

  Future<void> profile() async {
    const labels = {
      'scope': '目标尺度',
      'goal_mode': '目标方式',
      'control_type': '控制权',
      'ownership_mode': '所有权',
      'structure_type': '目标结构',
      'lifecycle_type': '生命周期'
    };
    final key = await _choose(context, '纠正系统对这件事的理解', labels);
    if (key == null || !mounted) return;
    final names = {
      'EPISODE': '一次事件',
      'SHORT_HORIZON': '短期',
      'LONG_HORIZON': '长期',
      'CONTINUOUS': '持续保持',
      'RECURRING': '周期保持',
      'EXPLORE': '探索方向',
      'SOLVE': '解决问题',
      'CREATE': '创造成果',
      'ENRICH': '丰富体验',
      'MAINTAIN': '保持',
      'REPAIR': '修复',
      'SELF': '由我控制',
      'MIXED': '部分可控',
      'EXTERNAL_DEPENDENT': '取决于外部回应',
      'SHARED_OWNED': '共同拥有',
      'SINGLE_OWNER': '个人所有',
      'SHARED_OWNER': '共同所有',
      'CONTRIBUTOR': '贡献者',
      'EXTERNAL_ACTOR': '外部参与者',
      'SINGLE': '单目标',
      'NESTED': '父子目标',
      'DEPENDENCY_GRAPH': '目标有前置关系',
      'PORTFOLIO': '多个目标组合',
      'FINITE': '有限目标',
      'EXPLORATORY': '探索',
      'REOPENED': '重新开启'
    };
    final value = await _choose(context, labels[key]!, {
      for (final v in GrowthProblemProfile.dimensions[key]!) v: names[v] ?? v
    });
    if (value != null)
      await change('profile', {
        key: value,
        if (key == 'goal_mode' && value == 'EXPLORE')
          'lifecycle_type': 'EXPLORATORY',
        if (key == 'lifecycle_type' &&
            const ['CONTINUOUS', 'RECURRING'].contains(value))
          'goal_mode': 'MAINTAIN'
      });
  }

  Future<void> options() async {
    final choice = await _choose(context, '目标工具', {
      'allocation': '本目标的资源与优先级',
      'dependency': '添加前置或关联目标',
      'external': '更新外部条件',
      'stage': '设置当前阶段',
      'route': '增加一条路线',
      'participant': '记录共同参与者',
      'change-attempt': '记录一个改变尝试',
      'shared-evidence': '记录共同事件证据',
      'asset': '迁移自己的有效规则',
      'episode': '从本目标开启一次事件',
      'metric': '设置数字的用途'
    });
    if (choice == null || !mounted) return;
    if (choice == 'allocation') {
      final v = await _fields(
          context,
          '本目标每天占用的资源',
          {
            'minutes': '分钟',
            'money': '资金',
            'energy': '精力（0–10）',
            'risk': '风险预算',
            'priority': '优先级（1 高 / 2 普通 / 3 低）'
          },
          initial:
              growthMap(j.data['allocation']).map((k, v) => MapEntry(k, '$v')));
      if (v != null) await change('allocation', v);
    } else if (choice == 'dependency') {
      final all = await store.list();
      if (!mounted) return;
      final target = await _choose(context, '关联哪个目标？', {
        'external': '一个尚未满足的外部条件',
        for (final item in all.where((g) => g.id != j.id))
          item.id: item.safeTitle
      });
      if (target == null || !mounted) return;
      String ref = target;
      if (target == 'external') {
        final v = await _fields(context, '外部前置条件', {'title': '条件名称'},
            requiredKeys: ['title']);
        if (v == null) return;
        ref = 'external:${EvidenceGrowthJourneyStore.newId()}';
        final p = await store.portfolio();
        await store.savePortfolio(growthInt(p['version']), {
          'external_conditions': {
            ...growthMap(p['external_conditions']),
            ref: false
          },
          'condition_labels': {
            ...growthMap(p['condition_labels']),
            ref: v['title']
          }
        });
      }
      if (!mounted) return;
      final type = await _choose(context, '当前目标与它的关系', {
        'REQUIRES': '必须先满足它',
        'BLOCKS': '它需要等待当前目标',
        'ENABLES': '当前目标完成会帮助它',
        'CONFLICTS_WITH': '两个目标不能同时推进',
        'SHARES_RESOURCE_WITH': '共享同一资源',
        'ALTERNATIVE_TO': '互为替代路线',
        'CONTRIBUTES_TO': '当前目标为它提供支持'
      });
      if (type != null) await store.addDependency(j.id, ref, type);
    } else if (choice == 'external') {
      final p = await store.portfolio();
      if (!mounted) return;
      final conditions = growthMap(p['external_conditions']);
      if (conditions.isEmpty) {
        _error(context, '还没有外部条件，请先添加前置关系');
        return;
      }
      final ref = await _choose(context, '哪个条件的现实状态发生了变化？', {
        for (final c in conditions.entries)
          c.key:
              '${growthMap(p['condition_labels'])[c.key] ?? '外部条件'} · ${c.value == true ? '已满足' : '待满足'}'
      });
      if (ref != null)
        await store.savePortfolio(growthInt(p['version']), {
          'external_conditions': {...conditions, ref: conditions[ref] != true}
        });
    } else if (choice == 'stage' || choice == 'route') {
      final v = await _fields(
          context,
          choice == 'stage' ? '当前阶段' : '一条可独立停止的路线',
          choice == 'stage'
              ? {
                  'title': '阶段名称',
                  'entry_condition': '进入阶段的现实条件',
                  'exit_condition': '进入下一阶段需要什么事实'
                }
              : {'title': '路线名称（避免第三方隐私）'},
          requiredKeys: choice == 'stage'
              ? ['title', 'entry_condition', 'exit_condition']
              : ['title']);
      if (v != null) await change(choice, v);
    } else if (choice == 'participant') {
      final v = await _fields(context, '记录你所报告的共同参与', {'alias': '称呼或匿名代号'},
          requiredKeys: ['alias']);
      if (v == null || !mounted) return;
      final role = await _choose(context, '对方实际扮演的角色', {
        'CO_OWNER': '共同拥有者',
        'CONTRIBUTOR': '贡献者',
        'APPROVER': '审批者',
        'OBSERVER': '观察者',
        'EXTERNAL_ACTOR': '外部决定者'
      });
      if (role != null)
        await change('participant', {'alias': v['alias'], 'role': role});
    } else if (choice == 'change-attempt') {
      final v = await _fields(context, '改变的是行为模式，不是给自己贴标签', {
        'observed_pattern': '具体观察到的行为',
        'context': '通常发生在什么情境',
        'impact': '造成什么实际影响',
        'desired_pattern': '希望换成什么行为',
        'intervention': '本次尝试的最小改变',
        'baseline': '改变前的实际表现',
        'signal': '用什么现实信号观察变化'
      }, requiredKeys: [
        'observed_pattern',
        'context',
        'impact',
        'desired_pattern',
        'intervention',
        'baseline',
        'signal'
      ]);
      if (v != null) await change('change-attempt', v);
    } else if (choice == 'shared-evidence') {
      final type = await _choose(context, '这条证据属于谁？', {
        'SELF_EXPERIENCE': '我的体验',
        'OBSERVED_BEHAVIOR': '可观察的行为',
        'EXPLICIT_PARTNER_FEEDBACK': '对方明确表达的反馈',
        'SHARED_CONFIRMED_FACT': '双方实际确认过的事实'
      });
      if (type == null || !mounted) return;
      final v = await _fields(
          context, '保留最少的必要信息', {'facts': '事实摘要，不记录第三方私密细节'},
          requiredKeys: ['facts']);
      if (v != null)
        await change('shared-evidence', {
          'type': type,
          'mutually_confirmed': type == 'SHARED_CONFIRMED_FACT',
          ...v
        });
    } else if (choice == 'asset') {
      final all = await store.list();
      if (!mounted) return;
      final target = await _choose(context, '把自己的规则用于哪个目标？', {
        for (final item
            in all.where((g) => g.id != j.id && !g.profile.sensitive))
          item.id: item.safeTitle
      });
      if (target == null || !mounted) return;
      final v = await _fields(context, '迁移规则，重新取证', {
        'rule': '自己的技能、习惯或环境规则',
        'evidence': '它在当前目标中的实际依据',
        'transfer': '在新目标中的真实反馈（尚未应用则留空）'
      }, requiredKeys: [
        'rule',
        'evidence'
      ]);
      if (v != null)
        await store.shareAsset(j, target, v['rule']!, v['evidence']!,
            transferFacts: v['transfer'] ?? '');
    } else if (choice == 'episode') {
      final v = await _fields(context, '从父目标开启一次事件', {'text': '这次具体想发生什么'},
          requiredKeys: ['text']);
      if (v == null) return;
      final p = GrowthProblemProfile.resolve(v['text']!);
      final child = await store.create(v['text']!,
          parentId: j.id,
          profile: GrowthProblemProfile({
            ...p.data,
            'scope': 'EPISODE',
            'structure_type': 'NESTED',
            'lifecycle_type': 'FINITE'
          }));
      if (mounted)
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => EvidenceGrowthJourneyPage(
                    journey: child,
                    dao: widget.dao,
                    onAction: widget.onAction,
                    onTrial: widget.onTrial,
                    draft: widget.draft)));
    } else if (choice == 'metric') {
      final v = await _fields(context, '先决定数字的身份', {'text': '数字与含义'},
          requiredKeys: ['text']);
      if (v == null || !mounted) return;
      final role = await _choose(context, '这个数字用来做什么？', {
        'PREFERENCE': '偏好参考',
        'WINDOW': '时间窗口',
        'MEASUREMENT': '观察测量',
        'CONSTRAINT': '约束上限',
        'KPI': '我明确选择的自主可控指标'
      });
      if (role != null)
        await change('metric', {
          'text': v['text'],
          'role': role,
          'confirmed': true,
          'self_controlled': role == 'KPI'
        });
    }
  }

  Future<void> reopen() async {
    final v = await _fields(context, '保留旧成果，开启新周期', {'reason': '出现了什么新的现实变化？'},
        requiredKeys: ['reason']);
    if (v != null) await change('reopen', v);
  }

  Widget action(String label, Future<void> Function() fn,
          {bool primary = false}) =>
      Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 8),
          child: primary
              ? FilledButton(
                  onPressed: busy ? null : () => run(fn), child: Text(label))
              : OutlinedButton(
                  onPressed: busy ? null : () => run(fn), child: Text(label)));
  @override
  Widget build(BuildContext context) {
    final active =
        !j.terminal && !const ['PAUSED', 'PARKED'].contains(j.status);
    final profile = j.profile;
    final fact =
        growthMap(j.data['outcome'])['facts'] ?? j.data['current'] ?? '';
    return Scaffold(
        appBar: AppBar(title: const Text('我的目标旅程'), actions: [
          IconButton(
              tooltip: '目标工具',
              onPressed: busy ? null : () => run(options),
              icon: const Icon(Icons.tune))
        ]),
        body: RefreshIndicator(
            onRefresh: reload,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Text(j.title,
                  style: const TextStyle(
                      fontSize: 23, fontWeight: FontWeight.w800, color: _teal)),
              const SizedBox(height: 8),
              Text(
                  '${GrowthJourney.labels[profile.lifecycle] ?? profile.lifecycle} · ${j.statusLabel} · 第 ${j.cycle} 轮'),
              if (busy) const LinearProgressIndicator(),
              if (feedbackState == 'NO_REALITY_FEEDBACK')
                _card('暂未收到现实反馈',
                    const Text('已达到你设置的提醒次数，停止重复催促。随时可以回来记录已做、未做或中止。')),
              if (j.data['parent_id'] != null)
                const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('这次事件结束只回写本次证据，不自动完成父目标。')),
              _card(
                  '六节点是一条完整链',
                  Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        'BELIEF',
                        'GOAL',
                        'ACTION',
                        'OUTCOME',
                        'REVIEW',
                        'CHANGE'
                      ]
                          .map((n) => Chip(
                              avatar: Icon(
                                  n == j.node
                                      ? Icons.play_circle
                                      : Icons.circle_outlined,
                                  size: 17,
                                  color: _teal),
                              label: Text(GrowthJourney.labels[n]!)))
                          .toList())),
              if (profile.mode == 'EXPLORE')
                const Text('先探索，不急着给自己定终局目标；一次体验也不代表永久适合。'),
              if (profile.data['gap'] != '' && profile.data['gap'] != null)
                _card(
                    '当前依据边界',
                    Text(profile.blocked
                        ? '当前有安全或结构缺口，请先核对。'
                        : '六模块提供过程方法；当前缺少可靠领域依据，不能替代专业判断。')),
              if (profile.data['self_judgment'] != null)
                _card(
                    '把评价还原为可观察模式',
                    const Text(
                        '“我很懒／我有缺点”是待检验的判断。记录具体行为、情境、影响与想尝试的改变，偶尔复发不会让进展归零。')),
              if (!j.confirmed)
                Wrap(children: [
                  action('核对目标与现实标准', contract, primary: true),
                  action('纠正系统理解', this.profile)
                ]),
              if (j.confirmed)
                _card(
                    '目标合同 v${j.contract['version']}',
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('现实标准：${j.contract['criterion']}'),
                          if ('${j.contract['quality'] ?? ''}'.isNotEmpty)
                            Text('边界：${j.contract['quality']}'),
                          Text('当前事实：$fact'),
                          Text(
                              '计划 v${j.plan['version']}：${j.plan['strategy'] ?? ''}')
                        ])),
              if (growthStrings(deps['blocked_by']).isNotEmpty)
                _card(
                    '等待前置条件', const Text('先满足关联目标或外部条件。这段等待不会被记为行动失败，提醒也会暂停。')),
              if (j.data['pending_entry'] != null &&
                  '${j.data['pending_entry']}'.isNotEmpty)
                _card('刚才补充的现实信息', Text('${j.data['pending_entry']}')),
              if (profile.intimate)
                _card(
                    '共同事件随时可以暂停',
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('时长只作参考，不计完成绩效。意愿随时变化，以当前双方意愿为准。'),
                          Wrap(children: [
                            action('确认当前双方自愿', () async {
                              final v = await _fields(
                                  context, '当前双方的明确意愿', {'facts': '实际确认了什么'},
                                  requiredKeys: ['facts']);
                              if (v != null)
                                await change('mutuality', {
                                  'value': 'MUTUAL_READY',
                                  'user_attested': true,
                                  ...v
                                });
                            }),
                            action('暂停',
                                () => change('mutuality', {'value': 'PAUSED'})),
                            action(
                                '撤回／停止',
                                () =>
                                    change('mutuality', {'value': 'WITHDRAWN'}))
                          ])
                        ])),
              if (profile.scope == 'EPISODE' && active)
                Wrap(children: [
                  action('进入事件，保持静默',
                      () => change('event', {'phase': 'IN_EVENT_QUIET'})),
                  action('事件结束，回到记录',
                      () => change('event', {'phase': 'POST_EVENT'}))
                ]),
              if (j.confirmed && active && j.status != 'MAINTAINING')
                _card(
                    '现在这一步 · ${j.nodeLabel}',
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (j.node == 'ACTION')
                            Wrap(children: [
                              action(j.trialId.isEmpty ? '准备下一次现实行动' : '继续本轮行动',
                                  () async {
                                if (j.trialId.isEmpty)
                                  await widget.onAction(j);
                                else
                                  await widget.onTrial(j.trialId);
                              }, primary: true),
                              if (j.trialId.isEmpty)
                                action('已有结果，核对事实', outcome)
                            ]),
                          if (j.node == 'OUTCOME')
                            action('核对结果与影响范围', outcome, primary: true),
                          if (j.node == 'REVIEW') ...[
                            const Text('你现在想如何处理这段经历？'),
                            Wrap(children: [
                              action('现在可以复盘', () => readiness('READY_NOW')),
                              action('先记事实', () => readiness('FACTS_ONLY')),
                              action('晚点再说', () => readiness('DEFERRED')),
                              action('先恢复', () => readiness('RECOVERY_HOLD'))
                            ]),
                            Text(GrowthJourney
                                    .labels['${j.data['readiness']}'] ??
                                '由你决定什么时候继续'),
                            if (j.data['readiness'] == 'READY_NOW')
                              action('比较事实，提炼学习', review, primary: true),
                            if (j.data['readiness'] == 'DEFERRED')
                              action('约定一次提醒（可选）', remindReview),
                          ],
                          if (j.node == 'CHANGE')
                            action('确认一个改变，回到信念校准', confirmChange,
                                primary: true),
                          if (j.node.endsWith('_GATE')) ...[
                            const Text('本轮改变已保存并完成信念校准。下一步由目标类型和真实证据决定。'),
                            if (j.node == 'GOAL_GATE')
                              Wrap(children: [
                                action('补充达成依据', criterion),
                                action(
                                    '核验达成',
                                    () =>
                                        change('gate', {'choice': 'ACHIEVED'}))
                              ]),
                            if (j.node == 'MAINTENANCE_GATE')
                              Wrap(children: [
                                action('定义保持区间', maintenance),
                                action('检查稳定状态', maintenanceCheck,
                                    primary: true)
                              ]),
                            if (j.data['contract_revision_required'] == true)
                              const Text('本轮调整涉及目标，请先确认新合同。'),
                            Wrap(children: [
                              action('继续下一轮',
                                  () => change('gate', {'choice': 'CONTINUE'}),
                                  primary: j.node != 'MAINTENANCE_GATE'),
                              action('修订执行计划', plan),
                              action('调整目标合同', contract),
                              action('暂缓',
                                  () => change('gate', {'choice': 'PAUSE'})),
                              action('有依据结束', () async {
                                final v = await _fields(
                                    context, '结束这个目标', {'reason': '停止追求的依据或选择'},
                                    requiredKeys: ['reason']);
                                if (v != null)
                                  await change(
                                      'gate', {'choice': 'CLOSE', ...v});
                              })
                            ]),
                          ],
                        ])),
              if (j.status == 'MAINTAINING')
                _card(
                    '保持中',
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '区间：${growthMap(j.data['maintenance'])['acceptable_band']}'),
                          Text(
                              '下次检查：${_date(growthInt(j.data['check_at_ms']))}'),
                          Wrap(children: [
                            action('记录稳定／偏离', maintenanceCheck, primary: true),
                            action('新的现实变化', reopen)
                          ])
                        ])),
              if (profile.mode == 'EXPLORE')
                _card(
                    '候选方向',
                    Column(children: [
                      action('保存一个候选方向', candidate),
                      for (final c in growthRows(j.data['candidates']))
                        ListTile(
                            title: Text('${c['statement']}'),
                            subtitle: Text(
                                '${c['evidence']}\n${c['disposition'] == 'PROMOTE' ? '已选择，正式目标待核对标准' : c['disposition'] == 'DROP' ? '已放下' : c['disposition'] == 'PARKED' ? '已暂存' : '仍在探索'}'),
                            onTap: () => run(() async {
                                  final choice = await _choose(
                                      context, '由你决定这个方向', {
                                    'TEST_MORE': '继续现实验证',
                                    'PROMOTE': '明确选择为正式目标',
                                    'PARKED': '暂存',
                                    'DROP': '放下'
                                  });
                                  if (choice != null)
                                    await change('candidate-disposition', {
                                      'id': c['id'],
                                      'value': choice,
                                      'confirmed': choice == 'PROMOTE'
                                    });
                                }))
                    ])),
              if (j.terminal)
                Wrap(children: [action('出现新变化，重新开启', reopen, primary: true)]),
              if (const ['PAUSED', 'PARKED'].contains(j.status))
                action(
                    '我准备好了，恢复进度', () => change('status', {'value': 'ACTIVE'}),
                    primary: true),
              ExpansionTile(title: const Text('阶段、路线与共同参与'), children: [
                if (growthMap(j.data['stage']).isNotEmpty)
                  ListTile(
                      title:
                          Text('当前阶段：${growthMap(j.data['stage'])['title']}'),
                      subtitle: Text(
                          '下一阶段条件：${growthMap(j.data['stage'])['exit_condition']}')),
                for (final r in growthRows(j.data['routes']))
                  ListTile(
                      title: Text('${r['title']}'),
                      subtitle: Text(
                          r['status'] == 'CLOSED' ? '此路线已关闭，父目标仍保留' : '当前路线'),
                      trailing: r['status'] == 'CLOSED'
                          ? null
                          : TextButton(
                              onPressed: () => run(() async {
                                    final v = await _fields(
                                        context, '停止这条路线', {'reason': '依据'},
                                        requiredKeys: ['reason']);
                                    if (v != null)
                                      await change(
                                          'close-route', {'id': r['id'], ...v});
                                  }),
                              child: const Text('关闭路线'))),
                for (final p in growthRows(j.data['participants']))
                  ListTile(
                      title: Text('${p['alias']}'),
                      subtitle: Text('${const {
                        'CO_OWNER': '共同拥有者',
                        'CONTRIBUTOR': '贡献者',
                        'APPROVER': '审批者',
                        'OBSERVER': '观察者',
                        'EXTERNAL_ACTOR': '外部决定者'
                      }[p['role']]} · 用户报告，未替对方确认承诺'),
                      trailing: p['status'] == 'WITHDRAWN'
                          ? null
                          : TextButton(
                              onPressed: () => run(() => change(
                                  'participant-withdraw', {'id': p['id']})),
                              child: const Text('已退出'))),
                const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('当前只为实际使用本 App 的你安排任务。共同参与记录不会向第三方发送消息。'))
              ]),
              ExpansionTile(title: const Text('行为改变与历次尝试'), children: [
                for (final a in growthRows(j.data['change_attempts']))
                  ListTile(
                      title: Text(
                          '${a['observed_pattern']} → ${a['desired_pattern']}'),
                      subtitle: Text(
                          '基线：${a['baseline']} · ${growthRows(a['observations']).length} 次现实观察'),
                      onTap: () => run(() async {
                            final v = await _fields(
                                context, '记录本次表现', {'facts': '实际发生了什么'},
                                requiredKeys: ['facts']);
                            if (v == null || !mounted) return;
                            final state = await _choose(context, '本次变化', {
                              'ADJUSTING': '继续调整',
                              'LAPSE': '旧模式又出现了',
                              'CONSOLIDATING': '正在巩固',
                              'STABLE': '按观察标准已稳定'
                            });
                            if (state != null)
                              await change('change-observation',
                                  {'id': a['id'], 'state': state, ...v});
                          }))
              ]),
              ExpansionTile(
                  title: const Text('依据与不可改写的历史'),
                  subtitle: const Text('区分知识依据、个人事实、AI 草案和工程规则'),
                  children: [
                    for (final r in history.reversed)
                      ListTile(
                          title: Text(
                              '${_recordLabel(r)} · 第 ${r['cycle'] ?? 1} 轮'),
                          subtitle: Text(_date(growthInt(r['at']))),
                          onTap: () => _showRecord(context, r)),
                  ]),
              if (!j.terminal)
                Wrap(children: [
                  action('暂存这个目标', () => change('status', {'value': 'PARKED'})),
                  action('归档', () => change('status', {'value': 'ARCHIVED'}))
                ]),
            ])));
  }
}

Widget _card(String title, Widget child) => Card(
    margin: const EdgeInsets.symmetric(vertical: 8),
    child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          child
        ])));
void _error(BuildContext context, Object e) =>
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Bad state: ', ''))));
String _date(int ms) => ms == 0
    ? '尚未约定'
    : DateTime.fromMillisecondsSinceEpoch(ms)
        .toLocal()
        .toString()
        .substring(0, 16);
Future<String?> _choose(
        BuildContext context, String title, Map<String, String> choices) =>
    showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
            title: Text(title),
            children: choices.entries
                .map((e) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, e.key),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(e.value))))
                .toList()));
Future<Map<String, String>?> _fields(
    BuildContext context, String title, Map<String, String> fields,
    {Map<String, String> initial = const {},
    List<String> requiredKeys = const []}) async {
  final controllers = {
    for (final key in fields.keys)
      key: TextEditingController(text: initial[key] ?? '')
  };
  final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
                  title: Text(title),
                  content: SizedBox(
                      width: 500,
                      child: SingleChildScrollView(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        for (final e in fields.entries)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: TextField(
                                  controller: controllers[e.key],
                                  minLines: 1,
                                  maxLines: 4,
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                      labelText: e.value,
                                      border: const OutlineInputBorder())))
                      ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消')),
                    FilledButton(
                        onPressed: requiredKeys
                                .any((k) => controllers[k]!.text.trim().isEmpty)
                            ? null
                            : () => Navigator.pop(
                                context,
                                controllers
                                    .map((k, c) => MapEntry(k, c.text.trim()))),
                        child: const Text('确认保存'))
                  ])));
  // Dialog transition can still paint its fields during the closing frame.
  await Future<void>.delayed(const Duration(milliseconds: 250));
  for (final c in controllers.values) c.dispose();
  return result;
}

Future<DateTime?> _pickDateTime(BuildContext context) async {
  final now = DateTime.now();
  final day = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)));
  if (day == null || !context.mounted) return null;
  final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))));
  return time == null
      ? null
      : DateTime(day.year, day.month, day.day, time.hour, time.minute);
}

Future<GrowthData?> _timeRange(BuildContext context) async {
  final start = await _pickDateTime(context);
  if (start == null || !context.mounted) return null;
  final v = await _fields(context, '保留多长时间？', {'minutes': '分钟'},
      initial: const {'minutes': '30'}, requiredKeys: ['minutes']);
  final minutes = int.tryParse(v?['minutes'] ?? '');
  if (minutes == null || minutes < 1) return null;
  return {
    'start': start.millisecondsSinceEpoch,
    'end': start.add(Duration(minutes: minutes)).millisecondsSinceEpoch
  };
}

String _recordLabel(GrowthData r) => r['kind'] == 'NODE_RUN'
    ? '${GrowthJourney.labels[r['node']] ?? r['node']}工序'
    : const {
          'ACHIEVEMENT_DOSSIER': '达成档案',
          'MAINTENANCE_DOSSIER': '稳定期档案',
          'REOPEN': '重开事件',
          'GOAL_CONTRACT': '目标合同版本',
          'PLAN_REVISION': '计划差异',
          'ACTION_PLAN': '行动计划',
          'ENTRY': '现实入口',
          'CYCLE': '循环开始',
          'SHARED_ASSET': '可复用规则',
          'ASSET_TRANSFER': '迁移观察',
          'OUTCOME': '结果确认',
          'REVIEW': '学习确认',
          'CHANGE': '改变确认',
          'READINESS': '加工准备选择',
          'CRITERION-EVIDENCE': '目标证据',
          'DRIFT_DETECTED': '现实偏离'
        }[r['kind']] ??
        '旅程记录';
Future<void> _showRecord(BuildContext context, GrowthData r) =>
    showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(_recordLabel(r)),
                content: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      if (r['input'] != null)
                        Text('上游记录：${jsonEncode(r['input'])}'),
                      if (r['output'] != null)
                        Text('本次产出：${jsonEncode(r['output'])}'),
                      for (final node in growthRows(r['knowledge_evidence']))
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                                '${node['title']}\n${node['claim']}\n${jsonEncode(node['source_locator'])}')),
                      const Text(
                          '知识支持过程方法；你的现实反馈只属于相应情境。生命周期、资源治理与状态门属于 ENG-2.7。'),
                      ExpansionTile(title: const Text('完整审计记录'), children: [
                        SelectableText(
                            const JsonEncoder.withIndent('  ').convert(r))
                      ]),
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('关闭'))
                ]));
