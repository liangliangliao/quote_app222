import 'package:flutter/material.dart';

import '../data/kv_dao.dart';
import 'xiangji_campaign_action_pages.dart';
import 'xiangji_database.dart';
import 'xiangji_models.dart';
import 'xiangji_repository.dart';
import 'xiangji_rev3_models.dart';
import 'xiangji_ui_support.dart';

class XiangjiProblemListPage extends StatefulWidget {
  const XiangjiProblemListPage({
    super.key,
    required this.repository,
    required this.dao,
  });

  final XiangjiRepository repository;
  final XiangjiDao dao;

  @override
  State<XiangjiProblemListPage> createState() => _XiangjiProblemListPageState();
}

class _XiangjiProblemListPageState extends State<XiangjiProblemListPage> {
  bool _loading = true;
  List<XiangjiProblemRecord> _problems = const <XiangjiProblemRecord>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final problems = await widget.repository.problems();
      if (!mounted) return;
      setState(() {
        _problems = problems;
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
      title: '与军师开始一个新议题',
      note: '不需要懂分析方法，也不用填结构表。说清你的需要、发生的事或卡点即可。',
      fields: const <XiangjiFormFieldSpec>[
        XiangjiFormFieldSpec(
          keyName: 'question',
          label: '告诉军师真实处境',
          hint: '告诉我你想要什么、发生了什么，或者你现在卡在哪里。',
          required: true,
          maxLines: 6,
        ),
      ],
      submitLabel: '让军师自动分析',
    );
    if (values == null) return;
    try {
      final authorized =
          await KeyValueDao().getString(
                'xiangji_sensitive_cloud_authorized_v1',
              ) ==
              '1';
      final result = await widget.repository.consultStrategist(
        utterance: values['question']!,
        authorizedSensitiveContext: authorized,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => XiangjiProblemWorkspacePage(
            problemId: result.problemId,
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
        title: const Text('人生问题解题纸'),
        backgroundColor: XiangjiPalette.mist,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('新问题'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _problems.isEmpty
              ? XiangjiEmptyState(
                  title: '从一个真实问题开始',
                  message: '系统会保留你的原话，再依次区分事实、体验、解释、预测与未知项。',
                  action: FilledButton.icon(
                    onPressed: _create,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('写下问题'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _problems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final problem = _problems[index];
                      return Card(
                        elevation: 0,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(14),
                          title: Text(
                            problem.reframedQuestion.isEmpty
                                ? problem.rawQuestion
                                : problem.reframedQuestion,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              problem.reframedQuestion.isEmpty
                                  ? '用户原话仍是当前问题定义'
                                  : '原始问题：${problem.rawQuestion}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          trailing: XiangjiStateBadge(label: problem.state.label),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => XiangjiProblemWorkspacePage(
                                  problemId: problem.id,
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

class XiangjiProblemWorkspacePage extends StatefulWidget {
  const XiangjiProblemWorkspacePage({
    super.key,
    required this.problemId,
    required this.repository,
    required this.dao,
  });

  final String problemId;
  final XiangjiRepository repository;
  final XiangjiDao dao;

  @override
  State<XiangjiProblemWorkspacePage> createState() =>
      _XiangjiProblemWorkspacePageState();
}

class _XiangjiProblemWorkspacePageState
    extends State<XiangjiProblemWorkspacePage> {
  bool _loading = true;
  bool _working = false;
  XiangjiProblemRecord? _problem;
  List<Map<String, Object?>> _items = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _claims = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _debts = const <Map<String, Object?>>[];
  List<XiangjiActionRecord> _actions = const <XiangjiActionRecord>[];
  List<Map<String, Object?>> _artifacts = const <Map<String, Object?>>[];
  XiangjiDecisionDraftRecord? _decisionDraft;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait<Object?>(<Future<Object?>>[
        widget.dao.problem(widget.problemId),
        widget.dao.problemItems(widget.problemId),
        widget.dao.claimsForProblem(widget.problemId),
        widget.dao.debts(problemId: widget.problemId, openOnly: true),
        widget.dao.actions(problemId: widget.problemId),
        widget.dao.reasoningArtifacts(problemId: widget.problemId),
        widget.dao.latestDecisionDraft(problemId: widget.problemId),
      ]);
      if (!mounted) return;
      setState(() {
        _problem = values[0] as XiangjiProblemRecord?;
        _items = values[1] as List<Map<String, Object?>>;
        _claims = values[2] as List<Map<String, Object?>>;
        _debts = values[3] as List<Map<String, Object?>>;
        _actions = values[4] as List<XiangjiActionRecord>;
        _artifacts = values[5] as List<Map<String, Object?>>;
        _decisionDraft = values[6] as XiangjiDecisionDraftRecord?;
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

  Future<void> _formalize() async {
    final values = await showXiangjiFormDialog(
      context,
      title: '事实、体验、解释、预测、未知项分层',
      note: '每行一项。事实只能写可观察内容；“我觉得/他一定/将会”通常属于解释或预测。',
      fields: const <XiangjiFormFieldSpec>[
        XiangjiFormFieldSpec(
          keyName: 'facts',
          label: '可观察事实',
          hint: '每行一条，写清何时、何处、谁做了什么',
          required: true,
          maxLines: 4,
        ),
        XiangjiFormFieldSpec(
          keyName: 'body',
          label: '身体与直接体验',
          hint: '例如：胸口紧、睡眠减少、听到对方原话',
          maxLines: 3,
        ),
        XiangjiFormFieldSpec(
          keyName: 'interpretations',
          label: '我的解释（不是事实）',
          maxLines: 3,
        ),
        XiangjiFormFieldSpec(
          keyName: 'predictions',
          label: '我的预测（尚未发生）',
          maxLines: 3,
        ),
        XiangjiFormFieldSpec(
          keyName: 'unknowns',
          label: '会改变决定的未知项',
          hint: '每行一项；之后可转为信息行动或认识债务',
          maxLines: 3,
        ),
        XiangjiFormFieldSpec(
          keyName: 'causes',
          label: '竞争性原因假设',
          hint: '每行：原因假设 | 能区分它与其他解释的证据',
          maxLines: 4,
        ),
      ],
      submitLabel: '完成分层',
    );
    if (values == null) return;
    await _run(() => widget.repository.completeFormalization(
          problemId: widget.problemId,
          observedFacts: xiangjiLines(values['facts']!),
          bodyExperiences: xiangjiLines(values['body']!),
          userInterpretations: xiangjiLines(values['interpretations']!),
          predictions: xiangjiLines(values['predictions']!),
          criticalUnknowns: xiangjiLines(values['unknowns']!),
          causalHypotheses: xiangjiLines(values['causes']!),
        ));
  }

  Future<void> _reviewGrounding() async {
    var reviewed = false;
    var acceptDebt = false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('认识根据审查'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: reviewed,
                onChanged: (value) =>
                    setDialogState(() => reviewed = value ?? false),
                title: const Text('我已逐项检查：事实来源、解释跳跃与预测前提'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: acceptDebt,
                onChanged: (value) =>
                    setDialogState(() => acceptDebt = value ?? false),
                title: const Text('将未解决的关键未知项登记为认识债务，并生成侦察行动'),
              ),
              const Text(
                '不勾选第二项时，仍有关键未知项会阻止进入概念审查。',
                style: TextStyle(color: XiangjiPalette.muted, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: reviewed
                  ? () => Navigator.of(dialogContext).pop(true)
                  : null,
              child: const Text('完成审查'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await _run(() => widget.repository.completeEpistemicReview(
          problemId: widget.problemId,
          groundingReviewed: reviewed,
          acceptUnresolvedUnknowns: acceptDebt,
        ));
  }

  Future<void> _reframe() async {
    final values = await showXiangjiFormDialog(
      context,
      title: '确认真问题与现实判据',
      note: '概念复杂不等于更真实。请用自己的语言写出可以被现实检验的问题。',
      fields: const <XiangjiFormFieldSpec>[
        XiangjiFormFieldSpec(
          keyName: 'question',
          label: '重构后的真问题',
          required: true,
          maxLines: 2,
        ),
        XiangjiFormFieldSpec(
          keyName: 'goal',
          label: '想实现的目标',
          required: true,
          maxLines: 2,
        ),
        XiangjiFormFieldSpec(
          keyName: 'value',
          label: '它与什么价值有关',
          maxLines: 2,
        ),
        XiangjiFormFieldSpec(
          keyName: 'success',
          label: '现实中的成功判据',
          required: true,
          maxLines: 3,
        ),
        XiangjiFormFieldSpec(
          keyName: 'exit',
          label: '停止/退出判据',
          maxLines: 3,
        ),
        XiangjiFormFieldSpec(
          keyName: 'concepts',
          label: '关键概念与边界',
          hint: '每行：概念 = 当前定义 | 可观察判据1、判据2',
          required: true,
          maxLines: 4,
        ),
        XiangjiFormFieldSpec(
          keyName: 'days',
          label: '几天后复核',
          initialValue: '7',
          keyboardType: TextInputType.number,
          required: true,
        ),
      ],
      submitLabel: '确认问题定义',
    );
    if (values == null) return;
    final days = int.tryParse(values['days']!) ?? 7;
    await _run(() => widget.repository.confirmReframedProblem(
          problemId: widget.problemId,
          reframedQuestion: values['question']!,
          goalText: values['goal']!,
          valueLink: values['value']!,
          successCriteria: values['success']!,
          exitCriteria: values['exit']!,
          conceptDefinitions: xiangjiLines(values['concepts']!),
          reviewAtMs: DateTime.now()
              .add(Duration(days: days.clamp(1, 365).toInt()))
              .millisecondsSinceEpoch,
        ));
  }

  Future<void> _selectAction() async {
    final values = await showXiangjiFormDialog(
      context,
      title: '选定一个当前算子',
      note: '行动模式只给一个当前行动；这里必须写清四层“为什么”和事前预测。',
      fields: const <XiangjiFormFieldSpec>[
        XiangjiFormFieldSpec(
          keyName: 'title',
          label: '最小可执行行动',
          required: true,
          maxLines: 2,
        ),
        XiangjiFormFieldSpec(
          keyName: 'gap',
          label: '它消除哪个关键缺口',
          required: true,
          maxLines: 2,
        ),
        XiangjiFormFieldSpec(
          keyName: 'mechanism',
          label: '作用机制',
          required: true,
          maxLines: 2,
        ),
        XiangjiFormFieldSpec(
          keyName: 'meaning',
          label: '战略意义',
          required: true,
          maxLines: 2,
        ),
        XiangjiFormFieldSpec(
          keyName: 'grounding',
          label: '根据来自哪里',
          required: true,
          maxLines: 2,
        ),
        XiangjiFormFieldSpec(
          keyName: 'prediction',
          label: '事前预测',
          hint: '行动后预计出现什么可观察变化？',
          required: true,
          maxLines: 2,
        ),
        XiangjiFormFieldSpec(
          keyName: 'minutes',
          label: '预计分钟数',
          initialValue: '25',
          keyboardType: TextInputType.number,
          required: true,
        ),
      ],
      submitLabel: '锁定当前行动',
    );
    if (values == null) return;
    String? actionId;
    await _run(() async {
      actionId = await widget.repository.selectOperator(
        problemId: widget.problemId,
        title: values['title']!,
        targetGap: values['gap']!,
        mechanism: values['mechanism']!,
        strategicMeaning: values['meaning']!,
        groundingReason: values['grounding']!,
        prediction: values['prediction']!,
        expectedMinutes: int.tryParse(values['minutes']!) ?? 25,
      );
    });
    if (!mounted || actionId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => XiangjiActionModePage(
          actionId: actionId!,
          repository: widget.repository,
          dao: widget.dao,
        ),
      ),
    );
    await _load();
  }

  Future<void> _askStrategist() async {
    final problem = _problem;
    if (problem == null) return;
    final values = await showXiangjiFormDialog(
      context,
      title: '继续告诉军师',
      note: '补充新的事实、体验或需要即可；系统会自动选择并编排 Agent。',
      fields: const <XiangjiFormFieldSpec>[
        XiangjiFormFieldSpec(
          keyName: 'task',
          label: '新的现实、纠正或问题',
          hint: '例如：你理解错了，真正影响我的是……',
          required: true,
          maxLines: 6,
        ),
      ],
      submitLabel: '自动重算',
    );
    if (values == null) return;
    await _run(() async {
      final sensitiveCloudAuthorized =
          await KeyValueDao().getString(
                'xiangji_sensitive_cloud_authorized_v1',
              ) ==
              '1';
      await widget.repository.consultStrategist(
        utterance: values['task']!,
        problemId: problem.id,
        authorizedSensitiveContext: sensitiveCloudAuthorized,
        forceStrategic: problem.campaignId.isNotEmpty,
      );
    });
  }

  Future<void> _autoStrategist() async {
    final problem = _problem;
    if (problem == null) return;
    await _run(() async {
      final authorized =
          await KeyValueDao().getString(
                'xiangji_sensitive_cloud_authorized_v1',
              ) ==
              '1';
      await widget.repository.consultStrategist(
        utterance: problem.rawQuestion,
        problemId: problem.id,
        authorizedSensitiveContext: authorized,
        forceStrategic: problem.campaignId.isNotEmpty,
      );
    });
  }

  Future<void> _adoptDraft() async {
    final draft = _decisionDraft;
    if (draft == null) return;
    await _run(() => widget.repository.respondToDecisionDraft(
          decisionDraftId: draft.id,
          status: XiangjiDecisionDraftStatus.adopted,
        ));
    if (!mounted || draft.actionId.isEmpty) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => XiangjiActionModePage(
        actionId: draft.actionId,
        repository: widget.repository,
        dao: widget.dao,
      ),
    ));
    await _load();
  }

  Future<void> _modifyDraft() async {
    final draft = _decisionDraft;
    if (draft == null) return;
    final values = await showXiangjiFormDialog(
      context,
      title: '修改 AI 预填草案',
      note: '这里只校正军师建议和当前一步；原始草案与版本仍会保留。',
      fields: <XiangjiFormFieldSpec>[
        XiangjiFormFieldSpec(
          keyName: 'recommendation',
          label: '建议版本',
          initialValue: draft.recommendation,
          required: true,
          maxLines: 3,
        ),
        XiangjiFormFieldSpec(
          keyName: 'action',
          label: '唯一当前一步',
          initialValue: draft.currentAction,
          required: true,
          maxLines: 3,
        ),
      ],
      submitLabel: '保存我的版本',
    );
    if (values == null) return;
    await _run(() async {
      final authorized =
          await KeyValueDao().getString(
                'xiangji_sensitive_cloud_authorized_v1',
              ) ==
              '1';
      await widget.repository.correctAndRecalculate(
        problemId: widget.problemId,
        targetRef: 'decision_draft:${draft.id}',
        oldValue:
            '建议：${draft.recommendation}\n当前一步：${draft.currentAction}',
        correctedValue:
            '我的修改版建议：${values['recommendation']}\n我确认的当前一步：${values['action']}',
        reason: '用户修改 AI 预填军师草案',
        authorizedSensitiveContext: authorized,
      );
    });
  }

  Future<void> _opposeDraft() async {
    final draft = _decisionDraft;
    if (draft == null) return;
    final values = await showXiangjiFormDialog(
      context,
      title: '纠正军师理解',
      note: '说出正确情况即可；旧态势模型、推断和决策草案会标记 STALE 并自动重算。',
      fields: const <XiangjiFormFieldSpec>[
        XiangjiFormFieldSpec(
          keyName: 'correction',
          label: '哪里理解错了，正确情况是什么',
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
        problemId: widget.problemId,
        targetRef: 'decision_draft:${draft.id}',
        oldValue: draft.judgment,
        correctedValue: values['correction']!,
        authorizedSensitiveContext: authorized,
      );
    });
  }

  Future<void> _deferDraft() async {
    final draft = _decisionDraft;
    if (draft == null) return;
    await _run(() => widget.repository.respondToDecisionDraft(
          decisionDraftId: draft.id,
          status: XiangjiDecisionDraftStatus.deferred,
        ));
  }

  Future<void> _showReasoning() async {
    if (_artifacts.isEmpty) {
      xiangjiShowMessage(context, '当前还没有可下钻的 AI 推理工件。');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.84,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                '为什么这样判断',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              for (final artifact in _artifacts)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text((artifact['kind'] ?? '').toString()),
                  subtitle: Text(
                    '态势版本：${artifact['situation_model_id'] ?? ''}',
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SelectableText(
                        (artifact['json_payload'] ?? '{}').toString(),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nextStep(XiangjiProblemRecord problem) {
    final button = switch (problem.state) {
      XiangjiProblemState.captured ||
      XiangjiProblemState.formalizing ||
      XiangjiProblemState.epistemicReview ||
      XiangjiProblemState.conceptReview =>
        FilledButton.icon(
          onPressed: _working ? null : _autoStrategist,
          icon: const Icon(Icons.auto_awesome_outlined),
          label: const Text('让军师自动完成当前分析'),
        ),
      XiangjiProblemState.solving || XiangjiProblemState.backtracking =>
        FilledButton.icon(
          onPressed: _working ? null : _autoStrategist,
          icon: const Icon(Icons.auto_awesome_outlined),
          label: const Text('让军师生成候选算子与唯一当前一步'),
        ),
      XiangjiProblemState.actionReady ||
      XiangjiProblemState.executing ||
      XiangjiProblemState.verifying => FilledButton.icon(
          onPressed: _actions.isEmpty
              ? null
              : () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => XiangjiActionModePage(
                        actionId: _actions.first.id,
                        repository: widget.repository,
                        dao: widget.dao,
                      ),
                    ),
                  );
                  await _load();
                },
          icon: const Icon(Icons.play_circle_outline),
          label: const Text('进入出征行动'),
        ),
      XiangjiProblemState.resolved => const XiangjiStateBadge(
          label: '现实判据已满足',
          color: Color(0xFF2F7D5A),
        ),
      XiangjiProblemState.archived =>
        const XiangjiStateBadge(label: '已归档'),
    };
    return button;
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    return Scaffold(
      backgroundColor: XiangjiPalette.mist,
      appBar: AppBar(
        title: const Text('问题解题纸'),
        backgroundColor: XiangjiPalette.mist,
        actions: [
          PopupMenuButton<String>(
            tooltip: '高级手动校正（可选）',
            enabled: problem != null && !_working,
            onSelected: (value) {
              switch (value) {
                case 'formalize':
                  _formalize();
                  break;
                case 'grounding':
                  _reviewGrounding();
                  break;
                case 'reframe':
                  _reframe();
                  break;
                case 'operator':
                  _selectAction();
                  break;
              }
            },
            itemBuilder: (_) => <PopupMenuEntry<String>>[
              if (problem?.state == XiangjiProblemState.formalizing)
                const PopupMenuItem<String>(
                  value: 'formalize',
                  child: Text('高级：手动校正认识分层'),
                ),
              if (problem?.state == XiangjiProblemState.epistemicReview)
                const PopupMenuItem<String>(
                  value: 'grounding',
                  child: Text('高级：手动审查认识根据'),
                ),
              if (problem?.state == XiangjiProblemState.conceptReview)
                const PopupMenuItem<String>(
                  value: 'reframe',
                  child: Text('高级：手动修改真问题'),
                ),
              if (problem?.state == XiangjiProblemState.solving ||
                  problem?.state == XiangjiProblemState.backtracking)
                const PopupMenuItem<String>(
                  value: 'operator',
                  child: Text('高级：手动修改当前算子'),
                ),
            ],
            icon: const Icon(Icons.tune_outlined),
          ),
          IconButton(
            tooltip: '继续告诉军师',
            onPressed: problem == null || _working ? null : _askStrategist,
            icon: const Icon(Icons.auto_awesome_outlined),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : problem == null
              ? const XiangjiEmptyState(
                  title: '问题不存在',
                  message: '这条记录可能已被移除。',
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    XiangjiSectionCard(
                      title: '当前问题',
                      subtitle: '原话与重构版本并存；系统不会覆盖原始材料。',
                      trailing: XiangjiStateBadge(label: problem.state.label),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          XiangjiLabeledValue(
                            label: '用户原话',
                            value: problem.rawQuestion,
                          ),
                          XiangjiLabeledValue(
                            label: '确认后的真问题',
                            value: problem.reframedQuestion,
                          ),
                          XiangjiLabeledValue(
                            label: '现实目标',
                            value: problem.goalText,
                          ),
                          XiangjiLabeledValue(
                            label: '成功判据',
                            value: problem.successCriteria,
                          ),
                          XiangjiLabeledValue(
                            label: '停止/退出判据',
                            value: problem.exitCriteria,
                          ),
                          const SizedBox(height: 4),
                          _nextStep(problem),
                        ],
                      ),
                    ),
                    if (_decisionDraft != null) ...[
                      const SizedBox(height: 12),
                      XiangjiSectionCard(
                        title: 'AI 预填军师草案',
                        subtitle:
                            '可采用、修改、反对或暂缓；认识状态：${_decisionDraft!.epistemicStatus}',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_decisionDraft!.clarificationQuestion.isNotEmpty)
                              XiangjiLabeledValue(
                                label: '只需补充一个关键信息',
                                value: _decisionDraft!.clarificationQuestion,
                              ),
                            XiangjiLabeledValue(
                              label: '我理解的真正问题',
                              value: _decisionDraft!.trueProblem,
                            ),
                            XiangjiLabeledValue(
                              label: '军师判断',
                              value: _decisionDraft!.judgment,
                            ),
                            XiangjiLabeledValue(
                              label: '建议',
                              value: _decisionDraft!.recommendation,
                            ),
                            XiangjiLabeledValue(
                              label: '为什么',
                              value: _decisionDraft!.why,
                            ),
                            XiangjiLabeledValue(
                              label: '当前一步',
                              value: _decisionDraft!.currentAction,
                            ),
                            XiangjiLabeledValue(
                              label: '会改变建议的信号',
                              value: _decisionDraft!.changeSignals,
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (_decisionDraft!.clarificationQuestion.isEmpty)
                                  FilledButton(
                                    onPressed: _working ? null : _adoptDraft,
                                    child: const Text('采用'),
                                  ),
                                OutlinedButton(
                                  onPressed: _working ? null : _modifyDraft,
                                  child: const Text('修改'),
                                ),
                                OutlinedButton(
                                  onPressed: _working ? null : _opposeDraft,
                                  child: const Text('不认同'),
                                ),
                                TextButton(
                                  onPressed: _working ? null : _showReasoning,
                                  child: const Text('为什么？'),
                                ),
                                TextButton(
                                  onPressed: _working ? null : _deferDraft,
                                  child: const Text('暂缓'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    XiangjiSectionCard(
                      title: '认识分层',
                      subtitle: '由 AI 自动预填；点“高级校正”才需要手动修改。事实不与解释混写。',
                      child: _items.isEmpty
                          ? const Text('尚未进入分层阶段。')
                          : Column(
                              children: [
                                for (final kind in const <String>[
                                  'known',
                                  'body_experience',
                                  'user_interpretation',
                                  'prediction',
                                  'unknown',
                                  'assumption',
                                  'constraint',
                                  'causal_hypothesis',
                                  'information_action',
                                  'gap',
                                  'sub_goal',
                                  'operator_candidate',
                                  'operator',
                                ])
                                  if (_items.any((row) => row['kind'] == kind))
                                    ExpansionTile(
                                      tilePadding: EdgeInsets.zero,
                                      title: Text(_kindLabel(kind)),
                                      children: [
                                        for (final row in _items.where(
                                          (item) => item['kind'] == kind,
                                        ))
                                          ListTile(
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            leading: Icon(
                                              kind == 'known' ||
                                                      kind == 'body_experience'
                                                  ? Icons.visibility_outlined
                                                  : Icons.psychology_alt_outlined,
                                              size: 18,
                                            ),
                                            title: Text(
                                              (row['text'] ?? '').toString(),
                                            ),
                                          ),
                                      ],
                                    ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 12),
                    XiangjiSectionCard(
                      title: '候选判断与认识债务',
                      subtitle: '系统性与确定性分开显示；债务不会被流畅措辞掩盖。',
                      child: Column(
                        children: [
                          if (_claims.isEmpty && _debts.isEmpty)
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text('尚无候选判断或认识债务。'),
                            ),
                          for (final claim in _claims)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.chat_bubble_outline),
                              title: Text((claim['text'] ?? '').toString()),
                              subtitle: Text(
                                '认识状态：${claim['epistemic_status']} · 系统性：${claim['systematicity'] ?? 'unknown'}',
                              ),
                            ),
                          for (final debt in _debts)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.report_problem_outlined,
                                color: Color(0xFFC8641B),
                              ),
                              title: Text(
                                (debt['description'] ?? '').toString(),
                              ),
                              subtitle: Text(
                                '影响：${debt['decision_impact']} · 缺口：${debt['grounding_gap']}',
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_working) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                    const SizedBox(height: 28),
                  ],
                ),
    );
  }

  String _kindLabel(String kind) => switch (kind) {
        'known' => '可观察事实',
        'body_experience' => '身体与直接体验',
        'user_interpretation' => '用户解释',
        'prediction' => '事前预测',
        'unknown' => '关键未知项',
        'assumption' => '可被现实反驳的关键假设',
        'constraint' => '不可绕过的现实约束',
        'causal_hypothesis' => '竞争性原因假设',
        'information_action' => '信息行动',
        'gap' => '关键缺口',
        'sub_goal' => 'AND/OR 子目标',
        'operator_candidate' => '候选算子',
        'operator' => '当前算子',
        _ => kind,
      };
}
