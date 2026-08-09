import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../data/kv_dao.dart';
import 'xiangji_database.dart';
import 'xiangji_models.dart';
import 'xiangji_repository.dart';
import 'xiangji_rev3_models.dart';
import 'xiangji_rev4_models.dart';
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
      title: '把一个重大议题交给军师',
      note: '说清你想做什么或正在犹豫什么。军师会自动完成值得一战、情报、多战略、资源、红队和止损草案。',
      fields: const <XiangjiFormFieldSpec>[
        XiangjiFormFieldSpec(
          keyName: 'topic',
          label: '重大议题与真实处境',
          hint: '例如：我想在半年内转行，但不能让家庭现金流中断。',
          required: true,
          maxLines: 6,
        ),
      ],
      submitLabel: '让军师自动谋划',
    );
    if (values == null) return;
    try {
      final authorized =
          await KeyValueDao().getString(
                'xiangji_sensitive_cloud_authorized_v1',
              ) ==
              '1';
      final result = await widget.repository.consultStrategist(
        utterance: values['topic']!,
        authorizedSensitiveContext: authorized,
        forceStrategic: true,
      );
      final id = result.campaignId;
      if (id.isEmpty) throw StateError('军师未能形成战役草案。');
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
  List<Map<String, Object?>> _contingencies = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _indicators = const <Map<String, Object?>>[];
  List<XiangjiActionRecord> _actions = const <XiangjiActionRecord>[];
  XiangjiDecisionDraftRecord? _decisionDraft;

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
        widget.dao.latestDecisionDraft(campaignId: widget.campaignId),
        widget.dao.contingencies(widget.campaignId),
        widget.dao.indicators(widget.campaignId),
      ]);
      if (!mounted) return;
      setState(() {
        _campaign = values[0] as XiangjiCampaignRecord?;
        _intel = values[1] as List<Map<String, Object?>>;
        _options = values[2] as List<Map<String, Object?>>;
        _actions = values[3] as List<XiangjiActionRecord>;
        _decisionDraft = values[4] as XiangjiDecisionDraftRecord?;
        _contingencies = values[5] as List<Map<String, Object?>>;
        _indicators = values[6] as List<Map<String, Object?>>;
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
          initialValue: switch (initialKind) {
            'critical_unknown' => '会改变路线的未知',
            'red_team_review' => '反方与失败路径',
            _ => '可观察事实',
          },
          hint: '可观察事实 / 会改变路线的未知 / 反方与失败路径',
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
          initialValue: '我的直接观察',
          required: true,
        ),
        const XiangjiFormFieldSpec(
          keyName: 'freshness',
          label: '新鲜度',
          initialValue: '当前仍有效',
          required: true,
        ),
      ],
      submitLabel: '保存情报',
    );
    if (values == null) return;
    final kind = switch (values['kind']!.trim()) {
      '会改变路线的未知' => 'critical_unknown',
      '反方与失败路径' => 'red_team_review',
      _ => 'fact',
    };
    await _run(() => widget.repository.addCampaignIntel(
          campaignId: widget.campaignId,
          kind: kind,
          text: values['text']!,
          sourceRef: values['source']!,
          sourceQuality: values['quality'] == '我的直接观察'
              ? 'user_observation'
              : values['quality']!,
          freshness: values['freshness'] == '当前仍有效'
              ? 'current'
              : values['freshness']!,
          state: kind == 'critical_unknown'
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
          keyName: 'target_gap',
          label: '这条路线要缩小的关键差距',
          required: true,
          maxLines: 2,
        ),
        XiangjiFormFieldSpec(
          keyName: 'mechanism',
          label: '为什么它对这次具体情况可能有效',
          required: true,
          maxLines: 3,
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
          keyName: 'opportunity_cost',
          label: '机会成本',
          required: true,
          maxLines: 2,
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
          keyName: 'why_not_others',
          label: '相比其他路线，它的取舍是什么',
          required: true,
          maxLines: 3,
        ),
        XiangjiFormFieldSpec(
          keyName: 'switch_trigger',
          label: '出现什么现实信号就切换路线',
          required: true,
          maxLines: 2,
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
          opportunityCost: values['opportunity_cost']!,
          reversibility: values['reversibility']!,
          assumptions: xiangjiLines(values['assumptions']!),
          stopConditions: xiangjiLines(values['stops']!),
          targetGap: values['target_gap']!,
          mechanismForThisCase: values['mechanism']!,
          whyNotOtherOptions: values['why_not_others']!,
          switchTrigger: values['switch_trigger']!,
          userSummary: '${values['name']}：${values['target_gap']}',
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
    final values = await showXiangjiFormDialog(
      context,
      title: '继续与总军师议事',
      note: '补充新的现实、体验或纠正即可；它会更新同一道题并自动重新比较路线，无需选择内部角色。',
      fields: const <XiangjiFormFieldSpec>[
        XiangjiFormFieldSpec(
          keyName: 'task',
          label: '新的事实、顾虑、纠正或目标',
          required: true,
          maxLines: 6,
        ),
      ],
      submitLabel: '自动重算战略与红队',
    );
    if (values == null) return;
    await _run(() async {
      final authorized =
          await KeyValueDao().getString(
                'xiangji_sensitive_cloud_authorized_v1',
              ) ==
              '1';
      await widget.repository.planCampaignWithStrategist(
        campaignId: campaign.id,
        utterance: values['task']!,
        authorizedSensitiveContext: authorized,
      );
    });
  }

  Future<void> _autoPlan() async {
    final campaign = _campaign;
    if (campaign == null) return;
    await _run(() async {
      final authorized =
          await KeyValueDao().getString(
                'xiangji_sensitive_cloud_authorized_v1',
              ) ==
              '1';
      await widget.repository.planCampaignWithStrategist(
        campaignId: campaign.id,
        utterance:
            '${campaign.title}。北极星：${campaign.northStar}。战略价值：${campaign.strategicValue}',
        authorizedSensitiveContext: authorized,
      );
    });
  }

  Future<void> _deferDecision() async {
    final draft = _decisionDraft;
    if (draft == null) return;
    await _run(() => widget.repository.respondToDecisionDraft(
          decisionDraftId: draft.id,
          status: XiangjiDecisionDraftStatus.deferred,
        ));
  }

  Future<void> _adoptDecision() async {
    final draft = _decisionDraft;
    await _run(() async {
      if (draft != null) {
        await widget.repository.respondToDecisionDraft(
          decisionDraftId: draft.id,
          status: XiangjiDecisionDraftStatus.adopted,
        );
      } else {
        await widget.repository.transitionCampaign(
          campaignId: widget.campaignId,
          target: XiangjiCampaignState.prepare,
          userConfirmed: true,
        );
      }
    });
  }

  Future<void> _modifyDecision() async {
    final draft = _decisionDraft;
    if (draft == null) {
      await _foundation();
      return;
    }
    final values = await showXiangjiFormDialog(
      context,
      title: '修改军师首选',
      note: 'AI 的原始草案保留；这里保存你的建议版本与当前一步。',
      fields: <XiangjiFormFieldSpec>[
        XiangjiFormFieldSpec(
          keyName: 'recommendation',
          label: '我采用的战略版本',
          initialValue: draft.recommendation,
          required: true,
          maxLines: 4,
        ),
        XiangjiFormFieldSpec(
          keyName: 'action',
          label: '当前一步',
          initialValue: draft.currentAction,
          required: true,
          maxLines: 3,
        ),
      ],
      submitLabel: '保存修改',
    );
    if (values == null) return;
    await _run(() async {
      final authorized =
          await KeyValueDao().getString(
                'xiangji_sensitive_cloud_authorized_v1',
              ) ==
              '1';
      await widget.repository.correctAndRecalculate(
        problemId: draft.problemId,
        targetRef: 'decision_draft:${draft.id}',
        oldValue: '建议：${draft.recommendation}\n当前一步：${draft.currentAction}',
        correctedValue:
            '建议：${values['recommendation']}\n当前一步：${values['action']}',
        reason: '用户修改战略草案',
        authorizedSensitiveContext: authorized,
      );
    });
  }

  Future<void> _opposeDecision() async {
    final draft = _decisionDraft;
    if (draft == null) {
      await _askStrategist();
      return;
    }
    final values = await showXiangjiFormDialog(
      context,
      title: '告诉军师哪里不成立',
      note: '旧理解和派生战略会保留为历史版本，随后按你的纠正自动重新谋划。',
      fields: const <XiangjiFormFieldSpec>[
        XiangjiFormFieldSpec(
          keyName: 'correction',
          label: '正确情况 / 反对理由',
          required: true,
          maxLines: 5,
        ),
      ],
      submitLabel: '纠正并重算',
    );
    if (values == null) return;
    await _run(() async {
      final authorized =
          await KeyValueDao().getString(
                'xiangji_sensitive_cloud_authorized_v1',
              ) ==
              '1';
      await widget.repository.correctAndRecalculate(
        problemId: draft.problemId,
        targetRef: 'decision_draft:${draft.id}',
        oldValue: draft.judgment,
        correctedValue: values['correction']!,
        authorizedSensitiveContext: authorized,
      );
    });
  }

  Future<void> _showDecisionWhy() async {
    final draft = _decisionDraft;
    if (draft == null) return;
    final values = await Future.wait<Object?>(<Future<Object?>>[
      widget.dao.latestExplanationCard(draft.problemId),
      widget.dao.cognitiveExperiences(
        problemId: draft.problemId,
        limit: 12,
      ),
    ]);
    if (!mounted) return;
    final explanation = values[0] as Map<String, Object?>?;
    final experiences = values[1] as List<XiangjiCognitiveExperienceDraft>;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.82,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                '为什么军师这么判断？',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
              const Text(
                '这是当前可修订的战略理解；新的现实、反例或边界变化都可能改变首选。',
                style: TextStyle(color: XiangjiPalette.muted, height: 1.45),
              ),
              const SizedBox(height: 10),
              XiangjiLabeledValue(
                label: '已确认的事实 / 体验',
                value: _listText(explanation?['facts_json']),
              ),
              XiangjiLabeledValue(
                label: '当前解释',
                value: (explanation?['interpretation'] ?? draft.judgment)
                    .toString(),
              ),
              XiangjiLabeledValue(
                label: '反例 / 不支持材料',
                value: _listText(explanation?['counterevidence_json']),
              ),
              XiangjiLabeledValue(
                label: '最脆弱前提',
                value: (explanation?['weakest_premise'] ??
                        draft.weakestPremise)
                    .toString(),
              ),
              XiangjiLabeledValue(
                label: '什么会改变首选',
                value: (explanation?['what_changes_it'] ??
                        draft.changeSignals)
                    .toString(),
              ),
              const Divider(height: 28),
              for (final experience in experiences)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(experience.headline),
                  subtitle: Text(experience.userMessage),
                  children: [
                    for (final detail in experience.details.entries)
                      XiangjiLabeledValue(
                        label: detail.key,
                        value: detail.value,
                      ),
                    if (experience.methodText.isNotEmpty)
                      XiangjiLabeledValue(
                        label: '这次使用的方法',
                        value: experience.methodText,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stageControls(XiangjiCampaignRecord campaign) {
    if (<XiangjiCampaignState>{
      XiangjiCampaignState.idea,
      XiangjiCampaignState.warWorthiness,
      XiangjiCampaignState.intel,
      XiangjiCampaignState.planning,
      XiangjiCampaignState.redTeam,
    }.contains(campaign.state)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.icon(
            onPressed: _working ? null : _autoPlan,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('让军师自动完成谋划与红队'),
          ),
          const SizedBox(height: 6),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('高级手动校正（可选）'),
            subtitle: const Text('复杂结构已有 AI 草案；仅在需要精细修改时展开。'),
            children: [_manualStageControls(campaign)],
          ),
        ],
      );
    }
    return _manualStageControls(campaign);
  }

  Widget _manualStageControls(XiangjiCampaignRecord campaign) {
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
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _working ? null : _adoptDecision,
              icon: const Icon(Icons.how_to_vote_outlined),
              label: const Text('采用'),
            ),
            OutlinedButton(
              onPressed: _working ? null : _modifyDecision,
              child: const Text('修改'),
            ),
            OutlinedButton(
              onPressed: _working ? null : _opposeDecision,
              child: const Text('不认同'),
            ),
            TextButton(
              onPressed: _working ? null : _showDecisionWhy,
              child: const Text('为什么 / 证据 / 方法'),
            ),
            TextButton(
              onPressed: _working ? null : _deferDecision,
              child: const Text('暂缓'),
            ),
          ],
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

  String _listText(Object? raw) {
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is List) {
        final values = decoded
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
        return values.isEmpty ? '当前没有已确认内容' : values.join('；');
      }
    } catch (_) {}
    final value = (raw ?? '').toString().trim();
    return value.isEmpty ? '当前没有已确认内容' : value;
  }

  String _budgetText(Map<String, Object?> budget) {
    final values = <String>[];
    final hours = budget['weekly_hours'];
    final money = budget['money_cap'];
    final time = budget['time'];
    final reserve = budget['reserve'];
    if (hours != null) values.add('每周最多 $hours 小时');
    if (money != null) values.add('资金上限 $money');
    if (time != null) values.add(time.toString());
    if (reserve != null) values.add(reserve.toString());
    return values.isEmpty ? '资源边界仍需确认' : values.join('；');
  }

  String _intelKind(String value) => switch (value) {
        'critical_unknown' => '会改变路线的未知',
        'red_team_review' => '反方与失败路径',
        'fact' => '可观察事实',
        _ => '当前战场材料',
      };

  String _epistemicLabel(String value) => switch (value.toUpperCase()) {
        'SUPPORTED' => '现实支持较强',
        'PROVISIONAL' => '当前材料暂时支持',
        'SCOUTING' => '正在现实侦察',
        'UNRESOLVED' || 'EPISTEMIC_DEBT' => '仍需补证',
        _ => '当前可修订',
      };

  String _sourceLabel(String value) => value.trim().isEmpty
      ? '来源尚未标注'
      : value.startsWith('situation:') || value.startsWith('raw_event:')
          ? '来自当前问题记录'
          : value.contains(':')
              ? '来自已记录的可追溯材料'
              : '来源：$value';

  String _routeType(String value) => switch (value) {
        'case_discriminating_scout' => '现实区分路线',
        'case_bounded_commitment' => '限额推进路线',
        'case_hold_with_trigger' => '保全并等待触发',
        'case_retreat' => '停止加码路线',
        'case_opportunity_concentration' => '核实后集中路线',
        _ => '当前案例候选路线',
      };

  String _reversibilityLabel(String value) => switch (value.toLowerCase()) {
        'high' => '容易撤回或调整',
        'medium' => '可调整但有一定成本',
        'low' => '撤回成本较高',
        _ => '可逆边界仍需确认',
      };

  String _indicatorLabel(String value) => switch (value.toLowerCase()) {
        'leading' => '提前显示路线是否有效的信号',
        'lagging' => '最终结果信号',
        _ => '现实监测信号',
      };

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
                          XiangjiLabeledValue(label: '军师首选', value: campaign.grandStrategy),
                          XiangjiLabeledValue(label: '为什么值得一战', value: campaign.warWorthiness),
                          XiangjiLabeledValue(label: '胜利判据', value: campaign.victoryCriteria),
                          XiangjiLabeledValue(label: '止损/退出', value: campaign.exitCriteria),
                          XiangjiLabeledValue(
                            label: '兵力预算',
                            value: campaign.resourceBudget.isEmpty
                                ? ''
                                : _budgetText(campaign.resourceBudget),
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
                      subtitle: '由 AI 预生成；事实、未知项和红队意见都保留来源与认识状态，可在高级模式校正。',
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
                                      '${_intelKind((row['kind'] ?? '').toString())} · ${_epistemicLabel((row['epistemic_status'] ?? '').toString())} · ${_sourceLabel((row['source_ref'] ?? '').toString())}',
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 12),
                    XiangjiSectionCard(
                      title: '战略方案比较',
                      subtitle: '军师自动给出至少两个真正不同的方案、假设、机会成本与停止条件。',
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
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            (option['name'] ?? '').toString(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        if (option['preferred'] == 1)
                                          const XiangjiStateBadge(
                                            label: '军师首选',
                                            color: XiangjiPalette.pine,
                                          ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      (option['user_summary'] ?? '')
                                              .toString()
                                              .trim()
                                              .isNotEmpty
                                          ? (option['user_summary'] ?? '')
                                              .toString()
                                          : '${_routeType((option['strategy_type'] ?? '').toString())} · ${_reversibilityLabel((option['reversibility'] ?? '').toString())}',
                                    ),
                                    children: [
                                      XiangjiLabeledValue(label: '这条路线要减少的差距', value: (option['target_gap'] ?? '').toString()),
                                      XiangjiLabeledValue(label: '它在这件事里怎样起作用', value: (option['mechanism_for_this_case'] ?? '').toString()),
                                      XiangjiLabeledValue(label: '关键假设', value: (option['key_assumption'] ?? _listText(option['key_assumptions_json'])).toString()),
                                      if ((option['why_preferred'] ?? '').toString().trim().isNotEmpty)
                                        XiangjiLabeledValue(label: '为什么把它作为首选', value: (option['why_preferred'] ?? '').toString()),
                                      XiangjiLabeledValue(label: '为什么现在不选其他路线', value: (option['why_not_other_options'] ?? '').toString()),
                                      XiangjiLabeledValue(label: '什么时候切换路线', value: (option['switch_trigger'] ?? '').toString()),
                                      XiangjiLabeledValue(label: '可能收益', value: _listText(option['benefits_json'])),
                                      XiangjiLabeledValue(label: '成本', value: _listText(option['costs_json'])),
                                      XiangjiLabeledValue(label: '机会成本', value: (option['opportunity_cost'] ?? '').toString()),
                                      XiangjiLabeledValue(label: '停止条件', value: _listText(option['stop_conditions_json'])),
                                    ],
                                  ),
                              ],
                            ),
                    ),
                    if (_contingencies.isNotEmpty || _indicators.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      XiangjiSectionCard(
                        title: '锦囊、止损与指标',
                        subtitle: 'AI 已预填 If-Then、领先/滞后指标；复杂战略默认折叠。',
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('展开条件式预案与监测指标'),
                          children: [
                            for (final item in _contingencies)
                              XiangjiLabeledValue(
                                label: '当：${item['trigger_expression']}',
                                value: '出现这个信号时：${item['action_plan']}',
                              ),
                            for (final item in _indicators)
                              XiangjiLabeledValue(
                                label: _indicatorLabel(
                                  (item['indicator_type'] ?? '').toString(),
                                ),
                                value:
                                    '${item['metric']} · 阈值 ${item['threshold_text']} · 窗口 ${item['window_text']}',
                              ),
                          ],
                        ),
                      ),
                    ],
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
                  message: '直接与军师对话即可；AI 会自动完成认识审查、求解并提出一个可确认的当前行动。',
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

  Future<String?> _realityForm() => showDialog<String>(
        context: context,
        builder: (_) => const _XiangjiRealityFeedbackDialog(),
      );

  Future<void> _complete() async {
    final feedback = await _realityForm();
    if (feedback == null || feedback.trim().isEmpty) return;
    XiangjiCouncilResult? result;
    await _run(() async {
      final authorized =
          await KeyValueDao().getString(
                'xiangji_sensitive_cloud_authorized_v1',
              ) ==
              '1';
      result = await widget.repository.reconcileRealityFromNaturalLanguage(
        actionId: widget.actionId,
        feedback: feedback,
        authorizedSensitiveContext: authorized,
      );
    });
    if (!mounted || result == null) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('现实已回流，模型已重算'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            XiangjiLabeledValue(
              label: '新的军师判断',
              value: result!.draft.judgment,
            ),
            XiangjiLabeledValue(
              label: '新的当前一步',
              value: result!.draft.currentAction,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _recordMissingReality() async {
    await _complete();
  }

  Future<void> _reconcileExistingReality() async {
    final reality = _reality;
    if (reality == null) return;
    List<String> strings(Object? raw) {
      try {
        final value = jsonDecode((raw ?? '[]').toString());
        return value is List
            ? value.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList()
            : const <String>[];
      } catch (_) {
        return const <String>[];
      }
    }

    final feedback = <String>[
      ...strings(reality['facts_json']),
      ...strings(reality['experience_json']),
      ...strings(reality['unexpected_json']),
      (reality['user_interpretation'] ?? '').toString().trim(),
    ].where((item) => item.isNotEmpty).join('。');
    if (feedback.isEmpty) {
      xiangjiShowMessage(context, '已有现实记录没有可验算内容，请在高级验算中补充。');
      return;
    }
    XiangjiCouncilResult? result;
    await _run(() async {
      final authorized =
          await KeyValueDao().getString(
                'xiangji_sensitive_cloud_authorized_v1',
              ) ==
              '1';
      result = await widget.repository.reconcileRealityFromNaturalLanguage(
        actionId: widget.actionId,
        feedback: feedback,
        authorizedSensitiveContext: authorized,
      );
    });
    if (!mounted || result == null) return;
    xiangjiShowMessage(context, '已对照事前预测完成验算，并生成新的军师草案。');
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
      note: '只有“现实支持事前预测”并且满足问题的现实成功判据，才会把问题标为阶段性解决。',
      fields: const <XiangjiFormFieldSpec>[
        XiangjiFormFieldSpec(
          keyName: 'verdict',
          label: '验算结论',
          hint: '现实支持 / 部分支持 / 现实反驳 / 仍无法判断',
          initialValue: '部分支持',
          required: true,
        ),
        XiangjiFormFieldSpec(
          keyName: 'resolved',
          label: '是否满足问题的现实成功判据（是/否）',
          initialValue: '否',
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
    final verdict = switch (values['verdict']!.trim()) {
      '现实支持' || '支持' => 'supports',
      '现实反驳' || '反驳' => 'refutes',
      '仍无法判断' || '无法判断' => 'unknown',
      _ => 'partly_supports',
    };
    await _run(() => widget.repository.verifyAction(
          actionId: widget.actionId,
          verdict: verdict,
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
        if ((_reality!['verdict'] ?? 'unreviewed').toString() ==
            'unreviewed') {
          return FilledButton.icon(
            onPressed: _working ? null : _reconcileExistingReality,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('让军师自动验算已有现实'),
          );
        }
        return const XiangjiStateBadge(label: '现实已记录，军师已自动验算');
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
          PopupMenuButton<String>(
            tooltip: '高级验算（可选）',
            enabled: _reality != null && !_working,
            onSelected: (_) => _verify(),
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'verify',
                child: Text('高级：手动覆盖验算结论'),
              ),
            ],
            icon: const Icon(Icons.tune_outlined),
          ),
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
                    const XiangjiSectionCard(
                      title: '完成后只需告诉军师',
                      subtitle: '不用写完整复盘；3—5 个现实事实就够了。',
                      child: Text(
                        '• 实际做了什么\n• 实际耗时\n• 观察到的结果\n• 与事前预测是否一致\n• 有什么意外',
                        style: TextStyle(height: 1.55),
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
                          ? '任务已完成，但还没有现实结果；问题不会因此自动解决。'
                          : '分析结构默认收起，需要时可回看。',
                      child: _controls(action),
                    ),
                    const SizedBox(height: 12),
                    ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: const Text('为什么做这件事（展开分析）'),
                      children: [
                        for (final entry in action.whyChain.entries.where(
                          (entry) => <String>{
                            'strategic_meaning',
                            'key_gap',
                            'operator_mechanism',
                            'epistemic_grounding',
                          }.contains(entry.key),
                        ))
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
                            XiangjiLabeledValue(label: '可观察事实', value: _listText(_reality!['facts_json'])),
                            XiangjiLabeledValue(label: '真实体验', value: _listText(_reality!['experience_json'])),
                            XiangjiLabeledValue(label: '意外结果', value: _listText(_reality!['unexpected_json'])),
                            XiangjiLabeledValue(label: '用户解释', value: (_reality!['user_interpretation'] ?? '').toString()),
                            XiangjiLabeledValue(label: '验算结论', value: _verdictLabel((_reality!['verdict'] ?? '').toString())),
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
        _ => '补充理由',
      };

  String _listText(Object? raw) {
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is List) {
        final values = decoded
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
        return values.isEmpty ? '当前没有记录' : values.join('；');
      }
    } catch (_) {}
    final value = (raw ?? '').toString().trim();
    return value.isEmpty ? '当前没有记录' : value;
  }

  String _verdictLabel(String value) => switch (value.toLowerCase()) {
        'supports' => '现实支持事前预测',
        'partly_supports' => '现实只支持其中一部分',
        'refutes' => '现实反驳了事前预测，已启动回溯',
        'unknown' || 'unreviewed' => '现有现实还不足以判断',
        _ => '等待进一步验算',
      };
}

class _XiangjiRealityFeedbackDialog extends StatefulWidget {
  const _XiangjiRealityFeedbackDialog();

  @override
  State<_XiangjiRealityFeedbackDialog> createState() =>
      _XiangjiRealityFeedbackDialogState();
}

class _XiangjiRealityFeedbackDialogState
    extends State<_XiangjiRealityFeedbackDialog> {
  final TextEditingController _controller = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  bool _listening = false;

  @override
  void dispose() {
    _speech.stop();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleVoice() async {
    if (_speech.isListening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final available = await _speech.initialize(
      onStatus: (status) {
        if (mounted && status == 'done') {
          setState(() => _listening = false);
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => _listening = false);
        xiangjiShowMessage(context, '语音识别暂不可用：${error.errorMsg}');
      },
    );
    if (!available) {
      if (mounted) xiangjiShowMessage(context, '当前设备没有可用的语音识别服务。');
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        _controller.value = TextEditingValue(
          text: result.recognizedWords,
          selection: TextSelection.collapsed(
            offset: result.recognizedWords.length,
          ),
        );
      },
    );
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      xiangjiShowMessage(context, '请直接告诉军师实际发生了什么。');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('直接告诉军师实际发生了什么'),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '不需要选择验算结论或填写复盘表。AI 会自动抽取事实、体验与意外，并对照事前预测。',
                style: TextStyle(color: XiangjiPalette.muted, height: 1.45),
              ),
              const SizedBox(height: 14),
              Semantics(
                textField: true,
                label: '行动后的现实反馈',
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  minLines: 4,
                  maxLines: 9,
                  decoration: const InputDecoration(
                    hintText: '例如：我发出了 3 封邮件，但两天后仍没人回复；我比预想更焦虑。',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _toggleVoice,
                icon: Icon(
                  _listening ? Icons.mic : Icons.mic_none_outlined,
                  color: _listening ? Colors.red : null,
                ),
                label: Text(_listening ? '停止语音输入' : '语音输入'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('让军师自动验算'),
        ),
      ],
    );
  }
}
