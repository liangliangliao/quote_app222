import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/kv_dao.dart';
import 'xiangji_agent_service.dart';
import 'xiangji_campaign_action_pages.dart';
import 'xiangji_database.dart';
import 'xiangji_models.dart';
import 'xiangji_repository.dart';
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
      title: '捕捉一个真实问题',
      note: '先保留你的原话。事实、解释和预测会在下一步分开，不会改写原始材料。',
      fields: const <XiangjiFormFieldSpec>[
        XiangjiFormFieldSpec(
          keyName: 'question',
          label: '你真正想解决的问题',
          hint: '例如：我是否应该在三个月内换工作？',
          required: true,
          maxLines: 2,
        ),
        XiangjiFormFieldSpec(
          keyName: 'context',
          label: '发生了什么（保留原话）',
          hint: '写下时间、人物、事件和当时处境；不用先下结论。',
          maxLines: 5,
        ),
      ],
      submitLabel: '保存原始材料',
    );
    if (values == null) return;
    try {
      final id = await widget.repository.createProblem(
        rawQuestion: values['question']!,
        rawContext: values['context']!,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => XiangjiProblemWorkspacePage(
            problemId: id,
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
      ]);
      if (!mounted) return;
      setState(() {
        _problem = values[0] as XiangjiProblemRecord?;
        _items = values[1] as List<Map<String, Object?>>;
        _claims = values[2] as List<Map<String, Object?>>;
        _debts = values[3] as List<Map<String, Object?>>;
        _actions = values[4] as List<XiangjiActionRecord>;
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
      title: '请军师协助当前阶段',
      note: 'AI 输出是候选判断，不会替你确认事实、推进状态或执行行动。',
      fields: const <XiangjiFormFieldSpec>[
        XiangjiFormFieldSpec(
          keyName: 'task',
          label: '希望协助什么',
          required: true,
          maxLines: 4,
        ),
        XiangjiFormFieldSpec(
          keyName: 'agent',
          label: '指定角色（可留空自动选择）',
          hint: 'A02 判断力仲裁 / A04 因果分析 / A05 真问题重构…',
        ),
      ],
      submitLabel: '运行认识审查与知识路由',
    );
    if (values == null) return;
    setState(() => _working = true);
    try {
      final sensitiveCloudAuthorized =
          await KeyValueDao().getString(
                'xiangji_sensitive_cloud_authorized_v1',
              ) ==
              '1';
      final requestedCode = values['agent']!
          .trim()
          .split(RegExp(r'\s+'))
          .first
          .toUpperCase();
      final requestedAgents = XiangjiAgentId.values
          .where((agent) => agent.code == requestedCode)
          .toList();
      final result = await widget.repository.runAgent(XiangjiAgentRequest(
        requestId: widget.repository.newId('xf_request'),
        task: values['task']!,
        agent: requestedAgents.isEmpty ? null : requestedAgents.first,
        problemId: problem.id,
        problemState: problem.state,
        authorizedSensitiveContext: sensitiveCloudAuthorized,
        additionalContext: <String, Object?>{
          'raw_question': problem.rawQuestion,
          'reframed_question': problem.reframedQuestion,
          'state': problem.state.wire,
          'items': _items,
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

  Widget _nextStep(XiangjiProblemRecord problem) {
    final button = switch (problem.state) {
      XiangjiProblemState.captured => FilledButton.icon(
          onPressed: _working
              ? null
              : () => _run(
                    () => widget.repository.beginFormalizing(problem.id),
                  ),
          icon: const Icon(Icons.layers_outlined),
          label: const Text('开始事实/解释分层'),
        ),
      XiangjiProblemState.formalizing => FilledButton.icon(
          onPressed: _working ? null : _formalize,
          icon: const Icon(Icons.account_tree_outlined),
          label: const Text('填写分层材料'),
        ),
      XiangjiProblemState.epistemicReview => FilledButton.icon(
          onPressed: _working ? null : _reviewGrounding,
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('审查认识根据'),
        ),
      XiangjiProblemState.conceptReview => FilledButton.icon(
          onPressed: _working ? null : _reframe,
          icon: const Icon(Icons.center_focus_strong_outlined),
          label: const Text('确认真问题'),
        ),
      XiangjiProblemState.solving || XiangjiProblemState.backtracking =>
        FilledButton.icon(
          onPressed: _working ? null : _selectAction,
          icon: const Icon(Icons.route_outlined),
          label: const Text('选择当前算子'),
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
          IconButton(
            tooltip: '请军师协助',
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
                    const SizedBox(height: 12),
                    XiangjiSectionCard(
                      title: '认识分层',
                      subtitle: '事实不与解释混写；预测保持可被现实反驳。',
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
                                  'causal_hypothesis',
                                  'information_action',
                                  'gap',
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
        'causal_hypothesis' => '竞争性原因假设',
        'information_action' => '信息行动',
        'gap' => '关键缺口',
        'operator' => '当前算子',
        _ => kind,
      };
}
