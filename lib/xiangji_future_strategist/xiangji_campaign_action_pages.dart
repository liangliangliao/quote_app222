import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/kv_dao.dart';
import 'xiangji_agent_service.dart';
import 'xiangji_database.dart';
import 'xiangji_models.dart';
import 'xiangji_repository.dart';
import 'xiangji_state_machine.dart';
import 'xiangji_ui_support.dart';

class XiangjiCampaignListPage extends StatefulWidget {
  const XiangjiCampaignListPage({
    super.key,
    required this.repository,
    required this.dao,
  });

  final XiangjiRepository repository;
  final XiangjiDao dao;

  @override
  State<XiangjiCampaignListPage> createState() =>
      _XiangjiCampaignListPageState();
}

class _XiangjiCampaignListPageState extends State<XiangjiCampaignListPage> {
  bool _loading = true;
  List<XiangjiCampaignRecord> _campaigns = const <XiangjiCampaignRecord>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final campaigns = await widget.repository.campaigns();
      if (!mounted) return;
      setState(() {
        _campaigns = campaigns;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      xiangjiShowMessage(context, error);
    }
  }

  Future<void> _create() async {
    final values = await showXiangjiFormDialog(
      context,
      title: '建立一场战役',
      note: '战役不是普通愿望。创建后仍必须回答是否值得一战、胜利/止损和兵力预算。',
      fields: const <XiangjiFormFieldSpec>[
        XiangjiFormFieldSpec(
          keyName: 'title',
          label: '战役名称',
          required: true,
        ),
        XiangjiFormFieldSpec(
          keyName: 'north_star',
          label: '北极星',
          required: true,
          maxLines: 2,
        ),
        XiangjiFormFieldSpec(
          keyName: 'value',
          label: '战略价值',
          required: true,
          maxLines: 3,
        ),
      ],
      submitLabel: '保存战役构想',
    );
    if (values == null) return;
    try {
      final id = await widget.repository.createCampaign(
        title: values['title']!,
        northStar: values['north_star']!,
        strategicValue: values['value']!,
        isPrimary: _campaigns.isEmpty,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => XiangjiCampaignWorkspacePage(
            campaignId: id,
            repository: widget.repository,
            dao: widget.dao,
          ),
        ),
      );
      await _load();
    } catch (error) {
      if (mounted) xiangjiShowMessage(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XiangjiPalette.mist,
      appBar: AppBar(
        title: const Text('战役作战室'),
        backgroundColor: XiangjiPalette.mist,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('新战役'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _campaigns.isEmpty
              ? XiangjiEmptyState(
                  title: '目前没有战役',
                  message: '只把需要持续投入、存在竞争路线和明确止损的事项升级为战役。',
                  action: FilledButton.icon(
                    onPressed: _create,
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('建立战役'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _campaigns.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final campaign = _campaigns[index];
                      return Card(
                        elevation: 0,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(14),
                          leading: CircleAvatar(
                            backgroundColor: campaign.isPrimary
                                ? XiangjiPalette.pine
                                : XiangjiPalette.line,
                            foregroundColor: campaign.isPrimary
                                ? Colors.white
                                : XiangjiPalette.ink,
                            child: Icon(
                              campaign.isPrimary
                                  ? Icons.star_outline
                                  : Icons.flag_outlined,
                            ),
                          ),
                          title: Text(
                            campaign.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 7),
                            child: Text(
                              campaign.northStar,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          trailing:
                              XiangjiStateBadge(label: campaign.state.label),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => XiangjiCampaignWorkspacePage(
                                  campaignId: campaign.id,
                                  repository: widget.repository,
                                  dao: widget.dao,
                                ),
                              ),
                            );
                            await _load();
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class XiangjiCampaignWorkspacePage extends StatefulWidget {
  const XiangjiCampaignWorkspacePage({
    super.key,
    required this.campaignId,
    required this.repository,
    required this.dao,
  });

  final String campaignId;
  final XiangjiRepository repository;
  final XiangjiDao dao;

  @override
  State<XiangjiCampaignWorkspacePage> createState() =>
      _XiangjiCampaignWorkspacePageState();
}

class _XiangjiCampaignWorkspacePageState
    extends State<XiangjiCampaignWorkspacePage> {
  bool _loading = true;
  bool _working = false;
  XiangjiCampaignRecord? _campaign;
  List<Map<String, Object?>> _intel = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _options = const <Map<String, Object?>>[];
  List<XiangjiActionRecord> _actions = const <XiangjiActionRecord>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait<Object?>(<Future<Object?>>[
        widget.dao.campaign(widget.campaignId),
        widget.dao.campaignIntel(widget.campaignId),
        widget.dao.strategyOptions(widget.campaignId),
        widget.dao.actions(campaignId: widget.campaignId),
      ]);
      if (!mounted) return;
      setState(() {
        _campaign = values[0] as XiangjiCampaignRecord?;
        _intel = values[1] as List<Map<String, Object?>>;
        _options = values[2] as List<Map<String, Object?>>;
        _actions = values[3] as List<XiangjiActionRecord>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      xiangjiShowMessage(context, error);
    }
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await operation();
      await _load();
    } catch (error) {
      if (mounted) xiangjiShowMessage(context, error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _foundation() async {
    final campaign = _campaign;
    if (campaign == null) return;
    final values = await showXiangjiFormDialog(
      context,
      title: '值得一战与边界',
      note: '胜利、止损、兵力和复核时间共同约束战役，不能只写一个鼓舞性目标。',
      fields: <XiangjiFormFieldSpec>[
        XiangjiFormFieldSpec(
          keyName: 'worthiness',
          label: '为什么值得一战',
          initialValue: campaign.warWorthiness,
          required: true,
          maxLines: 3,
        ),
        XiangjiFormFieldSpec(
          keyName: 'victory',
          label: '胜利判据',
          initialValue: campaign.victoryCriteria,
          required: true,
          maxLines: 3,
        ),
        XiangjiFormFieldSpec(
          keyName: 'exit',
          label: '止损/退出判据',
          initialValue: campaign.exitCriteria,
          required: true,
          maxLines: 3,
        ),
        const XiangjiFormFieldSpec(
          keyName: 'time',
          label: '每周可投入小时',
          initialValue: '5',
          required: true,
          keyboardType: TextInputType.number,
        ),
        const XiangjiFormFieldSpec(
          keyName: 'money',
          label: '预算上限',
          initialValue: '0',
          required: true,
          keyboardType: TextInputType.number,
        ),
        const XiangjiFormFieldSpec(
          keyName: 'days',
          label: '几天后复核',
          initialValue: '7',
          required: true,
          keyboardType: TextInputType.number,
        ),
      ],
      submitLabel: '保存战役边界',
    );
    if (values == null) return;
    await _run(() => widget.repository.defineCampaignFoundation(
          campaignId: campaign.id,
          warWorthiness: values['worthiness']!,
          victoryCriteria: values['victory']!,
          exitCriteria: values['exit']!,
          resourceBudget: <String, Object?>{
            'weekly_hours': double.tryParse(values['time']!) ?? 0,
            'money_cap': double.tryParse(values['money']!) ?? 0,
          },
          reviewAtMs: DateTime.now()
              .add(Duration(
                days: (int.tryParse(values['days']!) ?? 7)
                    .clamp(1, 365)
                    .toInt(),
              ))
              .millisecondsSinceEpoch,
        ));
  }

  Future<void> _addIntel({String initialKind = 'fact'}) async {
    final values = await showXiangjiFormDialog(
      context,
      title: initialKind == 'red_team_review' ? '记录红队审查' : '添加战场情报',
      note: '请标注来源质量与新鲜度。未知项不能用相似文本或 AI 推断伪装成证据。',
      fields: <XiangjiFormFieldSpec>[
        XiangjiFormFieldSpec(
          keyName: 'kind',
          label: '类型',
          initialValue: initialKind,
          hint: 'fact / critical_unknown / red_team_review',
          required: true,
        ),
        const XiangjiFormFieldSpec(
          keyName: 'text',
          label: '内容',
          required: true,
          maxLines: 4,
        ),
        const XiangjiFormFieldSpec(
          keyName: 'source',
          label: '来源或定位信息',
          maxLines: 2,
        ),
        const XiangjiFormFieldSpec(
          keyName: 'quality',
          label: '来源质量',
          initialValue: 'user_observation',
          required: true,
        ),
        const XiangjiFormFieldSpec(
          keyName: 'freshness',
          label: '新鲜度',
          initialValue: 'current',
          required: true,
        ),
      ],
      submitLabel: '保存情报',
    );
    if (values == null) return;
    await _run(() => widget.repository.addCampaignIntel(
          campaignId: widget.campaignId,
          kind: values['kind']!,
          text: values['text']!,
          sourceRef: values['source']!,
          sourceQuality: values['quality']!,
          freshness: values['freshness']!,
          state: values['kind'] == 'critical_unknown'
              ? XiangjiClaimState.unresolved
              : XiangjiClaimState.provisional,
        ));
  }

  Future<void> _addOption() async {
    final values = await showXiangjiFormDialog(
      context,
      title: '添加真正不同的战略',
      note: '至少形成两个路线不同的方案，才能进入红队。每行一项。',
      fields: const <XiangjiFormFieldSpec>[
        XiangjiFormFieldSpec(
          keyName: 'name',
          label: '方案名称',
          required: true,
        ),
        XiangjiFormFieldSpec(
          keyName: 'type',
          label: '战略类型',
          hint: '集中 / 试探 / 结盟 / 等待 / 撤退…',
          required: true,
        ),
        XiangjiFormFieldSpec(
          keyName: 'benefits',
          label: '收益',
          required: true,
          maxLines: 3,
        ),
        XiangjiFormFieldSpec(
          keyName: 'costs',
          label: '成本',
          required: true,
          maxLines: 3,
        ),
        XiangjiFormFieldSpec(
          keyName: 'assumptions',
          label: '关键假设',
          required: true,
          maxLines: 3,
        ),
        XiangjiFormFieldSpec(
          keyName: 'stops',
          label: '停止条件',
          required: true,
          maxLines: 3,
        ),
        XiangjiFormFieldSpec(
          keyName: 'reversibility',
          label: '可逆性',
          initialValue: 'high',
          required: true,
        ),
      ],
      submitLabel: '加入方案比较',
    );
    if (values == null) return;
    await _run(() => widget.repository.addStrategyOption(
          campaignId: widget.campaignId,
          name: values['name']!,
          type: values['type']!,
          benefits: xiangjiLines(values['benefits']!),
          costs: xiangjiLines(values['costs']!),
          reversibility: values['reversibility']!,
          assumptions: xiangjiLines(values['assumptions']!),
          stopConditions: xiangjiLines(values['stops']!),
        ));
  }

  Future<void> _closeWithReview(XiangjiCampaignState outcome) async {
    final values = await showXiangjiFormDialog(
      context,
      title: '形成战史复盘',
      note: '先记录战前模型与转折点，再提炼候选教训；一次经历不会自动升级为稳定个人兵法。',
      fields: const <XiangjiFormFieldSpec>[
        XiangjiFormFieldSpec(
          keyName: 'turns',
          label: '关键转折点',
          required: true,
          maxLines: 4,
        ),
        XiangjiFormFieldSpec(
          keyName: 'outcome',
          label: '现实结果',
          required: true,
          maxLines: 4,
        ),
        XiangjiFormFieldSpec(
          keyName: 'lessons',
          label: '候选教训（每行一条）',
          required: true,
          maxLines: 4,
        ),
      ],
      submitLabel: '保存复盘并结束',
    );
    if (values == null) return;
    await _run(() async {
      await widget.dao.saveBattleReview(<String, Object?>{
        'id': widget.repository.newId('xf_review'),
        'campaign_id': widget.campaignId,
        'problem_id': '',
        'prewar_model_json': jsonEncode(<String, Object?>{
          'north_star': _campaign?.northStar,
          'war_worthiness': _campaign?.warWorthiness,
          'victory_criteria': _campaign?.victoryCriteria,
          'exit_criteria': _campaign?.exitCriteria,
        }),
        'strategy_json': jsonEncode(_options),
        'predictions_json': '[]',
        'turning_points_json': jsonEncode(xiangjiLines(values['turns']!)),
        'outcome_json': jsonEncode(<String, Object?>{
          'classification': outcome.wire,
          'reality': values['outcome'],
        }),
        'lessons_json': jsonEncode(xiangjiLines(values['lessons']!)),
        'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      });
      final current = _campaign?.state;
      if (current == XiangjiCampaignState.executing) {
        await widget.repository.transitionCampaign(
          campaignId: widget.campaignId,
          target: outcome,
          userConfirmed: true,
        );
      }
      await widget.repository.transitionCampaign(
        campaignId: widget.campaignId,
        target: XiangjiCampaignState.closed,
        reviewRecorded: true,
      );
    });
  }

  Future<void> _transition(XiangjiCampaignState target,
      {bool userConfirmed = false}) async {
    await _run(() => widget.repository.transitionCampaign(
          campaignId: widget.campaignId,
          target: target,
          userConfirmed: userConfirmed,
        ));
  }

  Future<void> _askStrategist() async {
    final campaign = _campaign;
    if (campaign == null) return;
    final suggested = switch (campaign.state) {
      XiangjiCampaignState.redTeam => XiangjiAgentId.redTeam,
      XiangjiCampaignState.decision => XiangjiAgentId.judgmentEngine,
      XiangjiCampaignState.executing => XiangjiAgentId.monitor,
      _ => XiangjiAgentId.strategist,
    };
    final values = await showXiangjiFormDialog(
      context,
      title: '${suggested.code} ${suggested.label}',
      note: 'AI 只提供谋划、反方和监督意见；不会替你推进战役状态。',
      fields: const <XiangjiFormFieldSpec>[
        XiangjiFormFieldSpec(
          keyName: 'task',
          label: '希望协助什么',
          required: true,
          maxLines: 4,
        ),
      ],
      submitLabel: '运行知识路由与军师分析',
    );
    if (values == null) return;
    setState(() => _working = true);
    try {
      final authorized =
          await KeyValueDao().getString(
                'xiangji_sensitive_cloud_authorized_v1',
              ) ==
              '1';
      final result = await widget.repository.runAgent(XiangjiAgentRequest(
        requestId: widget.repository.newId('xf_request'),
        task: values['task']!,
        agent: suggested,
        campaignId: campaign.id,
        isMajorDecision: campaign.state == XiangjiCampaignState.decision,
        hasUserConfirmation: campaign.userConfirmed,
        authorizedSensitiveContext: authorized,
        additionalContext: <String, Object?>{
          'campaign': <String, Object?>{
            'title': campaign.title,
            'state': campaign.state.wire,
            'north_star': campaign.northStar,
            'war_worthiness': campaign.warWorthiness,
            'victory_criteria': campaign.victoryCriteria,
            'exit_criteria': campaign.exitCriteria,
            'resource_budget': campaign.resourceBudget,
          },
          'intel': _intel,
          'strategy_options': _options,
        },
      ));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('${result.agent.code} ${result.agent.label}'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: SelectableText(
                const JsonEncoder.withIndent('  ').convert(result.output),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) xiangjiShowMessage(context, error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Widget _stageControls(XiangjiCampaignRecord campaign) {
    switch (campaign.state) {
      case XiangjiCampaignState.idea:
        return FilledButton(
          onPressed: _working
              ? null
              : () => _transition(XiangjiCampaignState.warWorthiness),
          child: const Text('开始“是否值得一战”审查'),
        );
      case XiangjiCampaignState.warWorthiness:
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton(onPressed: _working ? null : _foundation, child: const Text('填写战役边界')),
            FilledButton(
              onPressed: campaign.warWorthiness.isEmpty || _working
                  ? null
                  : () => _transition(XiangjiCampaignState.intel),
              child: const Text('确认值得，进入情报'),
            ),
          ],
        );
      case XiangjiCampaignState.intel:
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton(onPressed: _working ? null : _addIntel, child: const Text('添加情报')),
            FilledButton(
              onPressed: _working
                  ? null
                  : () => _transition(XiangjiCampaignState.planning),
              child: const Text('战争迷雾已处理，进入谋划'),
            ),
          ],
        );
      case XiangjiCampaignState.planning:
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton(onPressed: _working ? null : _addOption, child: const Text('添加战略方案')),
            FilledButton(
              onPressed: _options.length < 2 || _working
                  ? null
                  : () => _transition(XiangjiCampaignState.redTeam),
              child: Text('进入红队（${_options.length}/2）'),
            ),
          ],
        );
      case XiangjiCampaignState.redTeam:
        final reviewed = _intel.any((row) => row['kind'] == 'red_team_review');
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton(
              onPressed: _working
                  ? null
                  : () => _addIntel(initialKind: 'red_team_review'),
              child: const Text('记录反方、失败路径与边界'),
            ),
            FilledButton(
              onPressed: reviewed && !_working
                  ? () => _transition(XiangjiCampaignState.decision)
                  : null,
              child: const Text('完成红队与判断力仲裁'),
            ),
          ],
        );
      case XiangjiCampaignState.decision:
        return FilledButton.icon(
          onPressed: _working
              ? null
              : () => _transition(
                    XiangjiCampaignState.prepare,
                    userConfirmed: true,
                  ),
          icon: const Icon(Icons.how_to_vote_outlined),
          label: const Text('由我确认选择，进入准备'),
        );
      case XiangjiCampaignState.prepare:
        return FilledButton.icon(
          onPressed: _working
              ? null
              : () => _transition(
                    XiangjiCampaignState.executing,
                    userConfirmed: true,
                  ),
          icon: const Icon(Icons.play_arrow),
          label: const Text('正式推进战役'),
        );
      case XiangjiCampaignState.executing:
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(onPressed: _working ? null : () => _transition(XiangjiCampaignState.hold), child: const Text('暂停观察')),
            OutlinedButton(onPressed: _working ? null : () => _transition(XiangjiCampaignState.adjust), child: const Text('调整路线')),
            OutlinedButton(onPressed: _working ? null : () => _transition(XiangjiCampaignState.retreat), child: const Text('撤退')),
            FilledButton(onPressed: _working ? null : () => _closeWithReview(XiangjiCampaignState.won), child: const Text('胜利并复盘')),
            FilledButton.tonal(onPressed: _working ? null : () => _closeWithReview(XiangjiCampaignState.lost), child: const Text('失败并复盘')),
          ],
        );
      case XiangjiCampaignState.hold:
        return Wrap(
          spacing: 8,
          children: [
            OutlinedButton(onPressed: _working ? null : () => _transition(XiangjiCampaignState.intel), child: const Text('补充情报')),
            FilledButton(onPressed: _working ? null : () => _transition(XiangjiCampaignState.executing), child: const Text('恢复推进')),
          ],
        );
      case XiangjiCampaignState.adjust:
        return FilledButton(
          onPressed: _working ? null : () => _transition(XiangjiCampaignState.planning),
          child: const Text('回到谋划并形成新版本'),
        );
      case XiangjiCampaignState.retreat:
      case XiangjiCampaignState.won:
      case XiangjiCampaignState.lost:
        return FilledButton(
          onPressed: _working
              ? null
              : () => _closeWithReview(campaign.state),
          child: const Text('形成战史并关闭'),
        );
      case XiangjiCampaignState.closed:
        return const XiangjiStateBadge(label: '战役已关闭并进入战史');
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaign = _campaign;
    return Scaffold(
      backgroundColor: XiangjiPalette.mist,
      appBar: AppBar(
        title: const Text('战役作战室'),
        backgroundColor: XiangjiPalette.mist,
        actions: [
          IconButton(
            tooltip: '请军师协助当前阶段',
            onPressed: campaign == null || _working ? null : _askStrategist,
            icon: const Icon(Icons.auto_awesome_outlined),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : campaign == null
              ? const XiangjiEmptyState(
                  title: '战役不存在',
                  message: '这条记录可能已被移除。',
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    XiangjiSectionCard(
                      title: campaign.title,
                      subtitle: campaign.isPrimary ? '当前主战役' : '次要战役',
                      trailing: XiangjiStateBadge(label: campaign.state.label),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          XiangjiLabeledValue(label: '北极星', value: campaign.northStar),
                          XiangjiLabeledValue(label: '战略价值', value: campaign.strategicValue),
                          XiangjiLabeledValue(label: '为什么值得一战', value: campaign.warWorthiness),
                          XiangjiLabeledValue(label: '胜利判据', value: campaign.victoryCriteria),
                          XiangjiLabeledValue(label: '止损/退出', value: campaign.exitCriteria),
                          XiangjiLabeledValue(
                            label: '兵力预算',
                            value: campaign.resourceBudget.isEmpty
                                ? ''
                                : jsonEncode(campaign.resourceBudget),
                          ),
                          XiangjiLabeledValue(
                            label: '下次复核',
                            value: xiangjiDateTime(campaign.reviewAtMs),
                          ),
                          const SizedBox(height: 4),
                          _stageControls(campaign),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    XiangjiSectionCard(
                      title: '战场情报',
                      subtitle: '事实、未知项和红队意见都保留来源与认识状态。',
                      trailing: IconButton(
                        onPressed: _working ? null : _addIntel,
                        icon: const Icon(Icons.add),
                      ),
                      child: _intel.isEmpty
                          ? const Text('尚无情报。')
                          : Column(
                              children: [
                                for (final row in _intel)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      row['kind'] == 'critical_unknown'
                                          ? Icons.help_outline
                                          : row['kind'] == 'red_team_review'
                                              ? Icons.gavel_outlined
                                              : Icons.visibility_outlined,
                                    ),
                                    title: Text((row['text'] ?? '').toString()),
                                    subtitle: Text(
                                      '${row['kind']} · ${row['epistemic_status']} · 来源：${row['source_ref'] ?? '未标注'}',
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 12),
                    XiangjiSectionCard(
                      title: '战略方案比较',
                      subtitle: '至少两个真正不同的方案，并列出假设与停止条件。',
                      trailing: IconButton(
                        onPressed: _working ? null : _addOption,
                        icon: const Icon(Icons.add),
                      ),
                      child: _options.isEmpty
                          ? const Text('尚无战略方案。')
                          : Column(
                              children: [
                                for (final option in _options)
                                  ExpansionTile(
                                    tilePadding: EdgeInsets.zero,
                                    title: Text(
                                      (option['name'] ?? '').toString(),
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    subtitle: Text(
                                      '${option['strategy_type']} · 可逆性 ${option['reversibility']} · ${option['evidence_level']}',
                                    ),
                                    children: [
                                      XiangjiLabeledValue(label: '收益', value: option['benefits_json'].toString()),
                                      XiangjiLabeledValue(label: '成本', value: option['costs_json'].toString()),
                                      XiangjiLabeledValue(label: '关键假设', value: option['key_assumptions_json'].toString()),
                                      XiangjiLabeledValue(label: '停止条件', value: option['stop_conditions_json'].toString()),
                                    ],
                                  ),
                              ],
                            ),
                    ),
                    if (_actions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      XiangjiSectionCard(
                        title: '战役行动',
                        child: Column(
                          children: [
                            for (final action in _actions)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(action.title),
                                subtitle: Text(action.prediction),
                                trailing: XiangjiStateBadge(label: action.state.label),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => XiangjiActionModePage(
                                      actionId: action.id,
                                      repository: widget.repository,
                                      dao: widget.dao,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (_working) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                    const SizedBox(height: 28),
                  ],
                ),
    );
  }
}

class XiangjiActionListPage extends StatefulWidget {
  const XiangjiActionListPage({
    super.key,
    required this.repository,
    required this.dao,
  });

  final XiangjiRepository repository;
  final XiangjiDao dao;

  @override
  State<XiangjiActionListPage> createState() => _XiangjiActionListPageState();
}

class _XiangjiActionListPageState extends State<XiangjiActionListPage> {
  List<XiangjiActionRecord> _actions = const <XiangjiActionRecord>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final actions = await widget.repository.currentActions();
      if (!mounted) return;
      setState(() {
        _actions = actions;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      xiangjiShowMessage(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XiangjiPalette.mist,
      appBar: AppBar(
        title: const Text('出征行动'),
        backgroundColor: XiangjiPalette.mist,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _actions.isEmpty
              ? const XiangjiEmptyState(
                  title: '没有当前行动',
                  message: '请先在问题解题纸中完成认识审查、确认真问题并选定一个算子。',
                  icon: Icons.check_circle_outline,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _actions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final action = _actions[index];
                      return Card(
                        elevation: 0,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(14),
                          title: Text(action.title),
                          subtitle: Text('事前预测：${action.prediction}'),
                          trailing: XiangjiStateBadge(label: action.state.label),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => XiangjiActionModePage(
                                  actionId: action.id,
                                  repository: widget.repository,
                                  dao: widget.dao,
                                ),
                              ),
                            );
                            await _load();
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class XiangjiActionModePage extends StatefulWidget {
  const XiangjiActionModePage({
    super.key,
    required this.actionId,
    required this.repository,
    required this.dao,
  });

  final String actionId;
  final XiangjiRepository repository;
  final XiangjiDao dao;

  @override
  State<XiangjiActionModePage> createState() => _XiangjiActionModePageState();
}

class _XiangjiActionModePageState extends State<XiangjiActionModePage> {
  XiangjiActionRecord? _action;
  Map<String, Object?>? _reality;
  bool _loading = true;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final action = await widget.dao.action(widget.actionId);
      final reality = await widget.dao.realityResult(widget.actionId);
      if (!mounted) return;
      setState(() {
        _action = action;
        _reality = reality;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      xiangjiShowMessage(context, error);
    }
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await operation();
      await _load();
    } catch (error) {
      if (mounted) xiangjiShowMessage(context, error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _start() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认出征'),
        content: const Text('事前预测已经锁定。开始后请按现实反馈行动，而不是为了维护原判断。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('由我确认开始')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() => widget.repository.startAction(
          actionId: widget.actionId,
          userConfirmed: true,
        ));
  }

  Future<Map<String, String>?> _realityForm() => showXiangjiFormDialog(
        context,
        title: '回填现实结果',
        note: '只写行动后真实发生的内容。完成任务不等于问题已解决；没有现实结果不能验算。',
        fields: const <XiangjiFormFieldSpec>[
          XiangjiFormFieldSpec(
            keyName: 'facts',
            label: '可观察事实（1—5项，每行一项）',
            required: true,
            maxLines: 5,
          ),
          XiangjiFormFieldSpec(
            keyName: 'unexpected',
            label: '意外结果',
            maxLines: 3,
          ),
          XiangjiFormFieldSpec(
            keyName: 'refs',
            label: '证据/来源定位',
            maxLines: 3,
          ),
          XiangjiFormFieldSpec(
            keyName: 'interpretation',
            label: '我的解释（与事实分开）',
            maxLines: 3,
          ),
        ],
        submitLabel: '保存现实结果',
      );

  Future<void> _complete() async {
    final values = await _realityForm();
    if (values == null) return;
    final facts = xiangjiLines(values['facts']!).take(5).toList();
    await _run(() => widget.repository.completeAction(
          actionId: widget.actionId,
          realityFacts: facts,
          unexpected: xiangjiLines(values['unexpected']!),
          evidenceRefs: xiangjiLines(values['refs']!),
          userInterpretation: values['interpretation']!,
        ));
  }

  Future<void> _recordMissingReality() async {
    final values = await _realityForm();
    if (values == null) return;
    await _run(() => widget.repository.recordRealityForCompletedAction(
          actionId: widget.actionId,
          realityFacts: xiangjiLines(values['facts']!).take(5).toList(),
          unexpected: xiangjiLines(values['unexpected']!),
          evidenceRefs: xiangjiLines(values['refs']!),
          userInterpretation: values['interpretation']!,
        ));
  }

  Future<void> _block() async {
    final values = await showXiangjiFormDialog(
      context,
      title: '记录阻碍',
      fields: const <XiangjiFormFieldSpec>[
        XiangjiFormFieldSpec(
          keyName: 'blocker',
          label: '阻碍类型与现实情况',
          required: true,
          maxLines: 3,
        ),
      ],
      submitLabel: '标记受阻',
    );
    if (values == null) return;
    await _run(() => widget.repository.blockAction(
          actionId: widget.actionId,
          blockerType: values['blocker']!,
        ));
  }

  Future<void> _verify() async {
    final values = await showXiangjiFormDialog(
      context,
      title: '预测—现实验算',
      note: '结论只能是 supports / partly_supports / refutes / unknown。只有“支持且满足问题现实判据”才能解决问题。',
      fields: const <XiangjiFormFieldSpec>[
        XiangjiFormFieldSpec(
          keyName: 'verdict',
          label: '验算结论',
          initialValue: 'partly_supports',
          required: true,
        ),
        XiangjiFormFieldSpec(
          keyName: 'resolved',
          label: '是否满足问题成功判据（yes/no）',
          initialValue: 'no',
          required: true,
        ),
        XiangjiFormFieldSpec(
          keyName: 'correction',
          label: '若被反驳，正确修正是什么',
          maxLines: 3,
        ),
      ],
      submitLabel: '保存验算',
    );
    if (values == null) return;
    await _run(() => widget.repository.verifyAction(
          actionId: widget.actionId,
          verdict: values['verdict']!,
          resolutionCriteriaMet:
              values['resolved']!.toLowerCase() == 'yes' ||
                  values['resolved'] == '是',
          correction: values['correction']!,
        ));
  }

  Future<void> _bindTodo() async {
    await _run(() async {
      await widget.repository.bindActionToNewTodo(widget.actionId);
    });
    if (mounted) xiangjiShowMessage(context, '已写入 Todo；Todo 仍是完成状态的唯一来源。');
  }

  Widget _controls(XiangjiActionRecord action) {
    switch (action.state) {
      case XiangjiActionState.ready:
        return Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            FilledButton.icon(onPressed: _working ? null : _start, icon: const Icon(Icons.play_arrow), label: const Text('确认开始')),
            OutlinedButton.icon(onPressed: _working || action.todoRef.isNotEmpty ? null : _bindTodo, icon: const Icon(Icons.checklist), label: Text(action.todoRef.isEmpty ? '加入 Todo' : '已关联 Todo')),
          ],
        );
      case XiangjiActionState.inProgress:
        return Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            FilledButton.icon(onPressed: _working ? null : _complete, icon: const Icon(Icons.fact_check_outlined), label: const Text('完成并回填现实')),
            OutlinedButton(onPressed: _working ? null : _block, child: const Text('遇到阻碍')),
          ],
        );
      case XiangjiActionState.blocked:
        return Wrap(
          spacing: 9,
          children: [
            FilledButton(onPressed: _working ? null : () => _run(() => widget.repository.resumeAction(action.id)), child: const Text('阻碍已处理，恢复')),
            OutlinedButton(onPressed: _working ? null : _complete, child: const Text('以现有结果结束并回填')),
          ],
        );
      case XiangjiActionState.done:
        if (_reality == null) {
          return FilledButton.icon(onPressed: _working ? null : _recordMissingReality, icon: const Icon(Icons.warning_amber_outlined), label: const Text('补录现实结果（尚不能验算）'));
        }
        return FilledButton.icon(onPressed: _working ? null : _verify, icon: const Icon(Icons.compare_arrows), label: const Text('验算预测与现实'));
      case XiangjiActionState.planned:
      case XiangjiActionState.aborted:
      case XiangjiActionState.invalidated:
        return XiangjiStateBadge(label: action.state.label);
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = _action;
    return Scaffold(
      backgroundColor: XiangjiPalette.mist,
      appBar: AppBar(
        title: const Text('行动模式'),
        backgroundColor: XiangjiPalette.mist,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : action == null
              ? const XiangjiEmptyState(title: '行动不存在', message: '这条行动可能已被移除。')
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: XiangjiPalette.pine,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          XiangjiStateBadge(label: action.state.label, color: Colors.white),
                          const SizedBox(height: 14),
                          Text(
                            action.title,
                            style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w800, height: 1.25),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '预计 ${action.expectedMinutes} 分钟',
                            style: const TextStyle(color: Color(0xFFDDECE6)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    XiangjiSectionCard(
                      title: '事前预测',
                      subtitle: '行动开始前已保存；不会按结果倒写。',
                      child: Text(action.prediction, style: const TextStyle(height: 1.45)),
                    ),
                    const SizedBox(height: 12),
                    XiangjiSectionCard(
                      title: '现在只做这一件事',
                      subtitle: action.state == XiangjiActionState.done && _reality == null
                          ? '任务已完成，但缺少 RealityResult；问题不会因此自动解决。'
                          : '分析结构默认收起，需要时可回看。',
                      child: _controls(action),
                    ),
                    const SizedBox(height: 12),
                    ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: const Text('为什么做这件事（展开分析）'),
                      children: [
                        for (final entry in action.whyChain.entries)
                          XiangjiLabeledValue(
                            label: _whyLabel(entry.key),
                            value: entry.value.toString(),
                          ),
                      ],
                    ),
                    if (action.blockerType.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      XiangjiAlertBanner(
                        state: XiangjiAlertState.yellow,
                        reason: action.blockerType,
                      ),
                    ],
                    if (_reality != null) ...[
                      const SizedBox(height: 12),
                      XiangjiSectionCard(
                        title: '现实结果',
                        subtitle: '事实与用户解释分别保存。',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            XiangjiLabeledValue(label: '可观察事实', value: (_reality!['facts_json'] ?? '').toString()),
                            XiangjiLabeledValue(label: '意外结果', value: (_reality!['unexpected_json'] ?? '').toString()),
                            XiangjiLabeledValue(label: '用户解释', value: (_reality!['user_interpretation'] ?? '').toString()),
                            XiangjiLabeledValue(label: '验算结论', value: (_reality!['verdict'] ?? '').toString()),
                          ],
                        ),
                      ),
                    ],
                    if (_working) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                    const SizedBox(height: 28),
                  ],
                ),
    );
  }

  String _whyLabel(String key) => switch (key) {
        'strategic_meaning' => '战略意义',
        'key_gap' => '关键缺口',
        'operator_mechanism' => '作用机制',
        'epistemic_grounding' => '认识根据',
        _ => key,
      };
}
