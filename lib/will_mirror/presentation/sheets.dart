import 'package:flutter/material.dart';

import '../ai/protocol.dart';
import '../application/controller.dart';
import '../domain/model.dart';
import '../domain/failures.dart';
import 'design.dart';

Future<T?> mirrorSheet<T>(BuildContext context,
        {required String title, required Widget child}) =>
    showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        constraints: const BoxConstraints(maxWidth: 760),
        builder: (context) => Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .88),
                child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 6, 22, 28),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(title,
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 18),
                          child
                        ])))));

class TextQuestion {
  const TextQuestion(this.key, this.label,
      {this.initial = '',
      this.hint = '',
      this.required = false,
      this.maxLength = 8000,
      this.lines = 2});
  final String key, label, initial, hint;
  final bool required;
  final int lines, maxLength;
}

Future<Map<String, String>?> askText(BuildContext context,
    {required String title,
    required List<TextQuestion> questions,
    String? explanation,
    String confirm = '保存'}) async {
  final inputs = {
    for (final q in questions) q.key: TextEditingController(text: q.initial)
  };
  final key = GlobalKey<FormState>();
  final result = await mirrorSheet<Map<String, String>>(context,
      title: title,
      child: Builder(
          builder: (sheetContext) => Form(
              key: key,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (explanation != null) ...[
                      Text(explanation),
                      const SizedBox(height: 16)
                    ],
                    for (final q in questions) ...[
                      TextFormField(
                          controller: inputs[q.key],
                          minLines: q.lines,
                          maxLines: q.lines + 2,
                          maxLength: q.maxLength,
                          decoration: InputDecoration(
                              labelText: q.label,
                              hintText: q.hint,
                              counterText: ''),
                          validator: (value) =>
                              q.required && (value ?? '').trim().isEmpty
                                  ? '请填写这一项'
                                  : (value ?? '').runes.length > q.maxLength
                                      ? '请保留在 ${q.maxLength} 字以内'
                                      : null),
                      const SizedBox(height: 14)
                    ],
                    FilledButton(
                        onPressed: () {
                          if (key.currentState!.validate())
                            Navigator.pop(sheetContext, {
                              for (final q in questions)
                                q.key: inputs[q.key]!.text.trim()
                            });
                        },
                        child: Text(confirm)),
                  ]))));
  // The sheet's reverse transition still owns its text fields briefly.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  for (final input in inputs.values) {
    input.dispose();
  }
  return result;
}

Future<String?> chooseOption(BuildContext context,
        {required String title,
        required Map<String, String> options,
        String? explanation}) =>
    mirrorSheet<String>(context, title: title,
        child: Builder(builder: (sheetContext) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (explanation != null) ...[
          Text(explanation),
          const SizedBox(height: 12)
        ],
        for (final entry in options.entries)
          Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.all(16)),
                  onPressed: () => Navigator.pop(sheetContext, entry.key),
                  child: Text(entry.value))),
      ]);
    }));

Future<DateTime?> pickMoment(BuildContext context,
    {DateTime? initial, bool future = false}) async {
  final now = DateTime.now();
  final start = initial ?? now;
  final date = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate:
          future ? DateTime(now.year, now.month, now.day) : DateTime(1970),
      lastDate: DateTime(now.year + 10));
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
      context: context, initialTime: TimeOfDay.fromDateTime(start));
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

Future<AnalysisConsent?> askAnalysisConsent(
  BuildContext context,
  MirrorController controller,
  CaseFile file, {
  String action = '分析这个课题',
  String? scope,
}) async {
  List<MirrorNode> selectable(CaseFile f) => f.nodes
      .where((n) =>
          n.usable &&
          n.kind != NodeKind.permission &&
          (n.isFact ||
              n.origin == EvidenceOrigin.deviceEvent ||
              n.kind == NodeKind.capability))
      .toList();
  final own = selectable(file);
  final external = controller.files
      .where((f) =>
          f.id != file.id && controller.preferences.crossCaseIds.contains(f.id))
      .toList();
  final selected =
      own.where((n) => !n.flag('sensitive')).map((n) => n.id).toSet();
  final sourceCases = <String>{};
  final all = [...own, ...external.expand(selectable)];
  return mirrorSheet<AnalysisConsent>(context,
      title: '这次允许 AI 使用哪些资料？',
      child: StatefulBuilder(
          builder: (sheetContext, setState) =>
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(
                    '${controller.providerLabel}\n只发送勾选记录，以及依赖这些来源的有效候选与封存对照。未选的其他课题不会发送。'),
                if (scope != null) ...[
                  const SizedBox(height: 12),
                  MirrorCard(child: Text('本次只做：$scope')),
                ],
                const SizedBox(height: 16),
                for (final node in own)
                  CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: selected.contains(node.id),
                      title: Text(nodeTitle(node),
                          maxLines: 3, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                          '${sourceLabel(node.origin)} · ${phaseLabel(node.phase)}${node.flag('sensitive') ? ' · 含敏感资料' : ''}'),
                      onChanged: (value) => setState(() {
                            if (value == true) {
                              selected.add(node.id);
                            } else {
                              selected.remove(node.id);
                            }
                          })),
                if (external.isNotEmpty) ...[
                  const Divider(),
                  Text('可选的历史经历',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Text('你已允许复用这些课题；本次仍由你选择。'),
                  for (final source in external)
                    ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(source.issue,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        children: [
                          for (final node in selectable(source))
                            CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                value: selected.contains(node.id),
                                title: Text(nodeTitle(node),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis),
                                subtitle: Text(node.flag('sensitive')
                                    ? '包含敏感资料，选择后本次会发送'
                                    : '${sourceLabel(node.origin)} · ${phaseLabel(node.phase)}'),
                                onChanged: (value) => setState(() {
                                      if (value == true) {
                                        selected.add(node.id);
                                        sourceCases.add(source.id);
                                      } else {
                                        selected.remove(node.id);
                                      }
                                    })),
                        ])
                ],
                const SizedBox(height: 16),
                Text('分析会分阶段调用模型，使用所配置服务的额度。可以随时停止；已保存内容可继续离线查看。',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: selected.isEmpty
                        ? null
                        : () => Navigator.pop(
                            sheetContext,
                            AnalysisConsent(
                                runId: newId('run'),
                                caseId: file.id,
                                revision: file.revision,
                                evidenceIds: selected,
                                sourceCaseIds: sourceCases,
                                sensitiveAllowed: all.any((n) =>
                                    selected.contains(n.id) &&
                                    n.flag('sensitive')),
                                grantedAt: DateTime.now().toUtc())),
                    child: Text('允许本次使用，$action')),
                TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('暂不发送，继续本地记录')),
              ])));
}

const fieldLabels = <String, String>{
  'clarity': '这一步的简要理解',
  'stuckPoint': '当前卡点',
  'perspective': '可以重新看的一点',
  'whyThisStep': '为什么先做这一步',
  'question': '可以补充的一点',
  'scoredAt': '在线评分时间',
  'timeContext': '当时的时间与处境',
  'source': '记录来源',
  'sensitive': '包含敏感内容',
  'scope': '授权范围',
  'riskFlags': '风险线索',
  'quote': '原话',
  'label': '内容',
  'keyQuestion': '当前需要核实的问题',
  'facts': '能回到原话的事实',
  'explanation': '解释',
  'decisionModes': '可能的决意机制',
  'control': '可以怎样影响',
  'behaviorQualification': '行为证据的七项条件',
  'basis': '判断依据',
  'summary': '概述',
  'claim': '候选认识',
  'title': '名称',
  'description': '具体做法',
  'text': '记录原文',
  'contexts': '适用情境',
  'alternatives': '其他解释或走法',
  'alternativeExplanations': '其他解释',
  'falsifier': '什么会推翻它',
  'nextTest': '下一次怎样验证',
  'specificity': '个体证据程度',
  'attractionSources': '吸引的来源',
  'immediateBenefit': '当前收益',
  'longTermCost': '可能的长远代价',
  'kind': '类型',
  'realityStatus': '事实状态',
  'confidence': '本人确信程度（可不填）',
  'awareness': '何时知道或想起',
  'influence': '是否实际影响仍需观察',
  'verify': '待核实的事实',
  'representation': '理由形式',
  'approach': '趋近／回避',
  'horizon': '时间视角',
  'factStatus': '事实依据',
  'personalBasis': '个人关联依据',
  'materiality': '对这次选择的重要性',
  'riskWarning': '需要审查风险',
  'unknowns': '目前不知道',
  'counterReason': '值得保留的反方',
  'directionByRoute': '对各条路线的作用',
  'relation': '关系',
  'reason': '依据与原因',
  'newClaim': '可以考虑的新认识',
  'operator': '采用的方法',
  'operatorWhy': '为什么采用这个方法',
  'mechanism': '可能改变什么',
  'oldMayBeRight': '旧认识也可能成立',
  'test': '低风险核实',
  'conditions': '适用条件',
  'firstStep': '第一小步',
  'family': '手段类别',
  'constraints': '现实限制',
  'reversibility': '可撤回程度',
  'safety': '安全门槛',
  'feasibility': '现实可行性',
  'protective': '用于核实或保护',
  'dailyProcess': '日常需要做什么',
  'expectedBenefits': '预期得到什么',
  'expectedCosts': '预期承担什么',
  'explorationState': '探索状态',
  'wantFit': '欲求适配',
  'bodySkillFit': '任务与能力适配',
  'externalFeasibility': '外部条件',
  'motivationCognition': '当前认识与动机',
  'hardSafetyGate': '独立安全门槛',
  'difficulty': '行动难度（1–5）',
  'difficultyFactors': '难度来源',
  'factor': '维度',
  'assessment': '判断与来源',
  'level': '当前难度',
  'matrix': '欲求与时间的比较',
  'effect': '可能影响',
  'exploratoryIndex': '探索性指数，非科学测量',
  'indexDimensions': '指数的独立维度',
  'uncertainty': '不确定性',
  'window': '时间窗口',
  'expectedAt': '预期回看时间',
  'pattern': '后果的发生方式',
  'assumptions': '尚需成立的假设',
  'loss': '失去的性质',
  'restoreConditions': '可能恢复的条件',
  'statement': '待审查的障碍',
  'stageAffected': '可能卡在哪一步',
  'locus': '影响来自哪里',
  'mechanisms': '可能机制',
  'evidenceStatus': '证据状态',
  'controllability': '可以怎样影响',
  'objectiveStatus': '客观条件',
  'believedAtT0': '事前如何理解',
  'workaround': '绕行或支持',
  'riskGate': '安全门槛',
  'taskStep': '任务环节',
  'requirement': '功能要求',
  'precision': '要求程度',
  'riskIfUnmet': '未满足时的风险',
  'status': '目前状态',
  'validUntil': '条件有效期',
  'functionalDomain': '具体能力领域',
  'stability': '当前可改变程度',
  'state': '记录状态',
  'action': '可观察的行动',
  'prerequisite': '需要先具备什么',
  'cost': '资源与代价',
  'risk': '可能风险',
  'consentRequired': '需要相关人同意',
  'availability': '支持是否真实可用',
  'resource': '共同资源',
  'capacityBasis': '容量或时间依据',
  'irreversibility': '窗口与恢复限制',
  'mode': '方式',
  'restoreCondition': '恢复探索的条件',
  'userConfirmed': '本人确认',
  'baseline': '如果条件不改变',
  'possibleWithChanges': '改变条件后的可能性',
  'unchangeable': '当前需要尊重的限制',
  'forecast': '事前预测',
  'triggerSignal': '怎样才算条件出现',
  'verifyFirst': '先核实什么',
  'safetyException': '何时暂停或改道',
  'fallback': '备用方式',
  'implementationEvidence': '怎样知道准备确实做了',
  'reversible': '可以撤回',
  'detail': '本人补充',
  'frames': '预演画面',
  'claimType': '画面性质',
  'fieldCue': '现场短提示',
  'ifThen': '如果……就先……',
  'durationSeconds': '可选预演时长（秒）',
  'response': '你的感受',
  'comment': '补充',
  'intention': '条件性意向',
  'remindAt': '自选提醒时间',
  'expiresAt': '条件失效窗口',
  'sealedAt': '封存时间',
  'clockWarning': '设备时间变化提示',
  'signal': '等待的可观察条件',
  'scheduledAt': '预约时间',
  'verificationRequired': '仍需核实真实条件',
  'occurredAt': '本人报告的发生时间',
  'changes': '现场新变化',
  'immediateMotive': '此刻真实想法',
  'safetyChanged': '安全条件有变化',
  'choice': '现场自主选择',
  'declaration': '决意陈述',
  'type': '记录性质',
  'jamesCandidates': '这次决意过程的候选解释',
  'autonomy': '自主条件',
  'tradeoff': '实际承受的取舍',
  'evidenceQuality': '行为证据资格',
  'dimension': '维度',
  'stage': '当前环节',
  'actionState': '实际行动',
  'externalOutcome': '外部结果',
  'outcomeState': '外部结果是否已知',
  'feeling': '真实感受',
  'context': '当时条件',
  'domains': '涉及的生活领域',
  'benefits': '实际体验到的收益',
  'costs': '实际承担的负担',
  'reviewAt': '自选后续回看',
  'earliestDeviation': '首次可观察偏差',
  'knownFacts': '已经知道的事实',
  'hypotheses': '竞争性解释',
  'confounders': '仍可能影响判断的其他条件',
  'regretTypes': '后悔的可能来源',
  'revisedClaims': '哪些旧判断需要变化',
  'satisfactionGap': '预期与获得后体验的差异',
  'why': '为什么考虑补救',
  'risks': '需要留意什么',
  'nextStep': '接下来能做的一步',
  'category': '经验所属方面',
  'maturity': '经验支持程度',
  'reviewReason': '为什么需要重新对照',
  'ifCondition': '什么情境下',
  'thenAction': '可观察的做法',
  'exceptionRule': '哪些情况下不适用',
  'fit': '与当前课题的关系',
  'changedConditions': '已经不同的条件',
  'exposure': '呈现情况',
  'recall': '现场是否想起',
  'application': '是否真的采用',
  'classification': '现实可改变性',
  'timeReference': '这个判断属于何时',
  'contextRequirements': '需要哪些条件',
  'safeAlternatives': '安全的替代方向',
  'reviewCondition': '什么时候重新检查',
  'ownActions': '自己可以做的事',
  'otherAutonomy': '对方自主决定的部分',
  'verifiedObligations': '已有来源的义务',
  'unknownObligations': '仍需核实的义务',
  'safeOptions': '可选择的安全方向',
  'nextVerification': '下一步核实',
  'direction': '新证据对原判断的影响',
};

Future<void> showNodeDetails(
        BuildContext context, MirrorController controller, MirrorNode node,
        {bool allowRetraction = true}) =>
    mirrorSheet<void>(context,
        title: kindLabel(node.kind),
        child: AnimatedBuilder(
            animation: controller,
            builder: (sheetContext, _) {
              final current = controller.resolve(node.id);
              if (current == null) return const Text('这条资料已删除。');
              node = current;
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      AiOriginLabel(
                          node: node,
                          resolve: controller.resolve,
                          showHumanSource: true),
                      MirrorTag(phaseLabel(node.phase)),
                      MirrorTag(statusLabel(node.status))
                    ]),
                    const SizedBox(height: 16),
                    Text(
                        '发生：${timeLabel(node.happenedAt)}\n得知：${timeLabel(node.knownAt)}\n记录：${timeLabel(node.recordedAt)}',
                        style: Theme.of(context).textTheme.bodySmall),
                    const Divider(),
                    if (node.body['redacted'] == true)
                      const Text('这条资料或其来源已撤回，正文与相关解释已停止使用。')
                    else ...[
                      ..._bodyWidgets(sheetContext, controller, node.body),
                      if (node.evidenceIds.isNotEmpty) ...[
                        const Divider(),
                        Text('支持与来源',
                            style: Theme.of(context).textTheme.titleMedium),
                        ..._sourceTiles(
                            sheetContext, controller, node.evidenceIds)
                      ],
                      if (node.counterIds.isNotEmpty) ...[
                        const Divider(),
                        Text('相反证据',
                            style: Theme.of(context).textTheme.titleMedium),
                        ..._sourceTiles(
                            sheetContext, controller, node.counterIds)
                      ],
                      if (node.counterIds.isEmpty &&
                          node.origin == EvidenceOrigin.aiHypothesis)
                        const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text('尚无已记录的反证，并不表示这个解释已经证实。')),
                    ],
                    if (node.revisionOf != null) ...[
                      const Divider(),
                      TextButton.icon(
                          onPressed: () {
                            final old = controller.resolve(node.revisionOf!);
                            if (old != null)
                              showNodeDetails(sheetContext, controller, old);
                          },
                          icon: const Icon(Icons.history),
                          label: const Text('查看这条记录的上一版本'))
                    ],
                    if (node.usable && node.kind == NodeKind.evidence)
                      TextButton.icon(
                          onPressed: () async {
                            final changed = await askText(sheetContext,
                                title: '更正这条记录',
                                explanation: '原版本仍保留，更正按现在得知的时点记录。相关解释需要重新核实。',
                                questions: [
                                  TextQuestion('text', '准确的记录是什么？',
                                      initial: node.text('text'),
                                      required: true,
                                      lines: 3)
                                ]);
                            if (changed != null && sheetContext.mounted)
                              await runUiAction(sheetContext, () async {
                                await controller.correctEvidence(
                                    node.caseId, node.id, changed['text']!);
                                if (sheetContext.mounted)
                                  Navigator.pop(sheetContext);
                              });
                          },
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('更正原始记录')),
                    if (node.usable && node.kind == NodeKind.consequence)
                      TextButton.icon(
                          onPressed: () async {
                            final changed = await askText(sheetContext,
                                title: '调整观察的时间窗口',
                                questions: [
                                  TextQuestion('window', '在哪个实际窗口观察？',
                                      initial: node.text('window'),
                                      required: true)
                                ]);
                            if (changed == null || !sheetContext.mounted)
                              return;
                            final at =
                                await pickMoment(sheetContext, future: true);
                            if (sheetContext.mounted)
                              await runUiAction(sheetContext, () async {
                                await controller.recordNode(
                                    node.caseId,
                                    NodeKind.consequence,
                                    {
                                      ...node.body,
                                      'window': changed['window'],
                                      'expectedAt':
                                          at?.toUtc().toIso8601String()
                                    },
                                    evidenceIds: node.evidenceIds,
                                    counterIds: node.counterIds,
                                    links: node.links,
                                    revisionOf: node.id);
                                if (sheetContext.mounted)
                                  Navigator.pop(sheetContext);
                              });
                          },
                          icon: const Icon(Icons.date_range_outlined),
                          label: const Text('调整未来观察窗口')),
                    if (allowRetraction &&
                        node.status != NodeStatus.retracted) ...[
                      const Divider(),
                      TextButton.icon(
                          onPressed: () async {
                            final answer = await chooseOption(sheetContext,
                                title: '撤回这条资料？',
                                explanation:
                                    '原文及依赖它的解释、旧快照中的相关内容会停止使用。相关提醒也会取消。',
                                options: {
                                  'cancel': '保留记录',
                                  'retract': '撤回资料与相关解释'
                                });
                            if (answer == 'retract') {
                              await controller.retract(node.id);
                              if (sheetContext.mounted)
                                Navigator.pop(sheetContext);
                            }
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('撤回这条资料及相关解释'))
                    ],
                  ]);
            }));

List<Widget> _sourceTiles(
        BuildContext context, MirrorController controller, List<String> ids) =>
    [
      for (final id in ids)
        Builder(builder: (context) {
          final ref = controller.resolve(id);
          return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link, size: 18),
              title: Text(ref == null ? '来源已不可用' : nodeTitle(ref),
                  maxLines: 3, overflow: TextOverflow.ellipsis),
              subtitle: ref == null
                  ? null
                  : Text(
                      '${contentSourceLabel(ref, resolve: controller.resolve)} · ${timeLabel(ref.recordedAt)}'),
              onTap: ref == null
                  ? null
                  : () => showNodeDetails(context, controller, ref));
        }),
    ];

List<Widget> _bodyWidgets(
    BuildContext context, MirrorController controller, Json body) {
  final widgets = <Widget>[];
  for (final entry in body.entries) {
    final key = entry.key, value = entry.value;
    if (key.endsWith('Id') || key.endsWith('Ids')) {
      final ids = value is String ? [value] : stringList(value);
      if (ids.isNotEmpty)
        widgets.addAll(_sourceTiles(context, controller, ids));
      continue;
    }
    if (!fieldLabels.containsKey(key)) continue;
    if (value is List && value.isEmpty) continue;
    widgets.add(Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(fieldLabels[key]!,
            style: Theme.of(context).textTheme.labelLarge)));
    if (value is List) {
      for (final item in value) {
        if (item is Map) {
          widgets.add(Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _bodyWidgets(context, controller, jsonMap(item)))));
        } else {
          widgets.add(Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text('· ${humanValue(item.toString())}')));
        }
      }
    } else if (value is Map) {
      widgets.addAll(_bodyWidgets(context, controller, jsonMap(value)));
    } else {
      widgets.add(Text(value == null
          ? '未知'
          : value is bool
              ? (value ? '是' : '否')
              : humanValue(value.toString())));
    }
  }
  return widgets;
}

Future<void> runUiAction(
    BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (error) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error is MirrorProblem
              ? analysisFailureMessage(error)
              : '操作未完成，原有资料已保留')));
  }
}
