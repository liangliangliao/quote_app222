import 'package:flutter/material.dart';

import 'xiangji_models.dart';
import 'xiangji_rev3_models.dart';
import 'xiangji_schopenhauer_core_catalog.dart';
import 'xiangji_ui_support.dart';

/// The single user-facing means-ends chain required by the Rev.5.2 Master PRD.
///
/// Internal solver vocabulary deliberately stays out of the default surface.
/// The same view is used in the conversation result and the full problem
/// workspace so a user never has to infer where the actual solver lives.
class XiangjiSolverCockpitView extends StatelessWidget {
  const XiangjiSolverCockpitView({
    super.key,
    required this.problem,
    required this.currentState,
    required this.goal,
    required this.keyGap,
    required this.activeHypothesis,
    required this.subgoal,
    required this.currentAction,
    required this.mechanism,
    required this.prediction,
    this.originalNeed = '',
    this.realityFacts = const <String>[],
    this.epistemicStatus = '',
    this.keyGapReason = '',
    this.actionBoundary = '',
    this.progressLabel = '',
    this.currentFocus = '',
    this.footer,
  });

  final String problem;
  final String currentState;
  final String goal;
  final String keyGap;
  final String activeHypothesis;
  final String subgoal;
  final String currentAction;
  final String mechanism;
  final String prediction;
  final String originalNeed;
  final List<String> realityFacts;
  final String epistemicStatus;
  final String keyGapReason;
  final String actionBoundary;
  final String progressLabel;
  final String currentFocus;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return XiangjiSectionCard(
      title: '军师解题台',
      subtitle: '始终聚焦同一道真实问题：看清现状、找到最大差距、行动，再让现实验算。',
      trailing: progressLabel.trim().isEmpty
          ? null
          : XiangjiStateBadge(label: progressLabel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (originalNeed.trim().isNotEmpty &&
              originalNeed.trim() != problem.trim())
            XiangjiLabeledValue(label: '你最初带来的需要', value: originalNeed),
          XiangjiLabeledValue(label: '这道题', value: problem),
          if (currentFocus.trim().isNotEmpty)
            XiangjiLabeledValue(label: '现在解到哪里', value: currentFocus),
          XiangjiLabeledValue(label: '现在实际处于什么状态', value: currentState),
          if (realityFacts.isNotEmpty)
            XiangjiLabeledValue(
              label: '当前最重要的事实与体验',
              value: realityFacts.take(5).join('；'),
            ),
          XiangjiLabeledValue(label: '希望现实变成什么样', value: goal),
          XiangjiLabeledValue(label: '目前最关键的差距', value: keyGap),
          if (keyGapReason.trim().isNotEmpty)
            XiangjiLabeledValue(label: '为什么先解决它', value: keyGapReason),
          XiangjiLabeledValue(
            label: '军师正在区分的原因',
            value: activeHypothesis,
            empty: '尚未需要区分新的原因',
          ),
          if (epistemicStatus.trim().isNotEmpty)
            XiangjiLabeledValue(label: '当前判断有多稳', value: epistemicStatus),
          XiangjiLabeledValue(label: '先解决哪一小步', value: subgoal),
          XiangjiLabeledValue(label: '当前唯一行动', value: currentAction),
          if (actionBoundary.trim().isNotEmpty)
            XiangjiLabeledValue(label: '时间与边界', value: actionBoundary),
          XiangjiLabeledValue(
            label: '为什么这个办法可能有效',
            value: mechanism,
          ),
          XiangjiLabeledValue(
            label: '如果有效，现实中应该看到什么',
            value: prediction,
          ),
          if (footer != null) ...[
            const SizedBox(height: 2),
            footer!,
          ],
        ],
      ),
    );
  }
}

/// Makes model participation visible without exposing hidden chain-of-thought.
class XiangjiAiContributionCard extends StatelessWidget {
  const XiangjiAiContributionCard({
    super.key,
    required this.summary,
    this.onConfigureAi,
    this.onReviewSensitiveConsent,
  });

  final XiangjiAiExecutionSummary summary;
  final VoidCallback? onConfigureAi;
  final VoidCallback? onReviewSensitiveConsent;

  @override
  Widget build(BuildContext context) {
    final cloudUsed = summary.cloudAiUsed;
    final sensitiveBlocked = summary.sensitiveConsentRequired;
    final title = cloudUsed
        ? 'AI 军师已参与本轮推演'
        : sensitiveBlocked
            ? '敏感内容未发送给云端 AI'
            : summary.aiConfigured
                ? '本轮由本地安全内核完成'
                : 'AI 未配置，本轮由本地求解内核完成';
    final subtitle = cloudUsed
        ? '${_providerLabel(summary.provider)} · ${summary.model} · '
            '${summary.cloudAgentCount}/${summary.plannedAgentCount} 个认知角色使用云端模型'
        : sensitiveBlocked
            ? '检测到${summary.sensitiveCategories.join('、')}；未获授权前保持本地处理。'
            : summary.aiConfigured
                ? '安全门或服务降级阻止了本轮云端调用，结果仍由确定性求解器保持连续。'
                : '配置任一全局 AI 服务后，普通问题会自动进入多角色模型推演。';

    return XiangjiSectionCard(
      title: title,
      subtitle: subtitle,
      icon: cloudUsed
          ? Icons.auto_awesome_outlined
          : sensitiveBlocked
              ? Icons.privacy_tip_outlined
              : Icons.memory_outlined,
      trailing: XiangjiStateBadge(
        label: cloudUsed ? '云端 AI' : '本地模式',
        color: cloudUsed ? const Color(0xFF3468C0) : XiangjiPalette.muted,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cloudUsed) ...[
            XiangjiLabeledValue(
              label: 'AI 实际形成或更新了什么',
              value: summary.changedArtifacts.join('；'),
            ),
            XiangjiLabeledValue(
              label: '本轮参与的认知角色',
              value: summary.cloudAgentLabels.take(10).join('、'),
            ),
            XiangjiLabeledValue(
              label: '可核对的运行凭证',
              value: <String>[
                '云端完成 ${summary.cloudAgentCount} 项',
                if (summary.localAgentCount > 0)
                  '本地完成 ${summary.localAgentCount} 项',
                if (summary.failedAgentCount > 0)
                  '云端失败并降级 ${summary.failedAgentCount} 项',
                if (summary.totalLatencyMs > 0)
                  '累计模型耗时 ${_duration(summary.totalLatencyMs)}',
                if (summary.redactedFieldCount > 0)
                  '外发前隐藏 ${summary.redactedFieldCount} 个直接标识',
              ].join(' · '),
            ),
            const Text(
              '这些是可修订的 AI 推断，不是关于你的最终事实；你修改或提供新现实时，派生结果会重新计算。',
              style: TextStyle(
                color: XiangjiPalette.muted,
                height: 1.45,
              ),
            ),
          ] else ...[
            Text(
              sensitiveBlocked
                  ? '本地原始记录和求解结果已经保存。你可以继续使用本地模式，或明确授权这些敏感类别后让下一轮调用已配置 AI；手机号、邮箱、证件号等直接标识仍会自动隐藏。'
                  : summary.aiConfigured
                      ? '本地 SCK 规则和持续求解器已完成基础草案，但本轮没有把结果伪装成 AI 输出。你可以继续使用，或检查 AI 服务后重新对话。'
                      : '当前结果来自本地 SCK 认识规则与持续求解器，不会伪装成云端 AI。请在全局设置中配置 API Key 与模型，随后普通问题会直接使用 AI。',
              style: const TextStyle(height: 1.5),
            ),
            const SizedBox(height: 10),
            if (sensitiveBlocked && onReviewSensitiveConsent != null)
              FilledButton.tonalIcon(
                onPressed: onReviewSensitiveConsent,
                icon: const Icon(Icons.privacy_tip_outlined),
                label: const Text('查看敏感数据授权'),
              )
            else if (onConfigureAi != null)
              FilledButton.tonalIcon(
                onPressed: onConfigureAi,
                icon: const Icon(Icons.settings_suggest_outlined),
                label: const Text('配置或检查 AI 服务'),
              ),
          ],
        ],
      ),
    );
  }

  String _providerLabel(String provider) => switch (provider.toLowerCase()) {
        'openai' => 'OpenAI',
        'deepseek' => 'DeepSeek',
        'openrouter' => 'OpenRouter',
        'gemini' => 'Gemini',
        'azure' => 'Azure',
        'xgrok' => 'xGrok',
        'edenai' => 'Eden AI',
        _ => provider.isEmpty ? '已配置 AI' : provider,
      };

  String _duration(int milliseconds) {
    if (milliseconds < 1000) return '$milliseconds ms';
    return '${(milliseconds / 1000).toStringAsFixed(1)} 秒';
  }
}

/// The frozen epistemic architecture from the V5 product proposal.
///
/// Keeping this as a shared widget ensures the knowledge center and the user's
/// own epistemic world present the same concepts instead of two parallel
/// vocabularies.
class XiangjiEpistemicArchitectureCard extends StatelessWidget {
  const XiangjiEpistemicArchitectureCard({
    super.key,
    this.showLayerMap = true,
  });

  final bool showLayerMap;

  @override
  Widget build(BuildContext context) {
    return XiangjiSectionCard(
      title: '叔本华 L0：军师怎样认识与修正',
      subtitle: showLayerMap
          ? '这是所有 AI、求解器和行动方法都必须遵守的认识论内核，不是可有可无的哲学说明。'
          : '所有判断先回到现实根据，行动后再由现实修订。',
      icon: Icons.account_balance_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            XiangjiSchopenhauerCoreCatalog.frozenArchitecture,
            style: TextStyle(fontWeight: FontWeight.w700, height: 1.5),
          ),
          if (showLayerMap) ...[
            const SizedBox(height: 8),
            const Text(
              '经验世界保存实际发生；抽象世界保存概念、判断与计划；认识根据决定两者能否合法相连；行动后的新现实拥有最终修订权。',
              style: TextStyle(color: XiangjiPalette.muted, height: 1.45),
            ),
            const SizedBox(height: 10),
            for (final layer in XiangjiSchopenhauerCoreCatalog.layerArchitecture)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text('• $layer', style: const TextStyle(height: 1.4)),
              ),
          ],
        ],
      ),
    );
  }
}

/// Contextual method feedback from the Rev.5.2 experience contract.
///
/// It exposes the trigger and the user-relevant before/after change, while
/// deliberately omitting internal IDs, JSON and solver vocabulary.
class XiangjiMethodEffectCard extends StatelessWidget {
  const XiangjiMethodEffectCard({
    super.key,
    required this.event,
    this.footer,
  });

  final XiangjiMethodEvent event;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final changed = event.changedState;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: changed
          ? const Color(0xFFFFF3DD)
          : const Color(0xFFEAF4EF),
      child: ExpansionTile(
        leading: Icon(
          changed ? Icons.change_circle_outlined : Icons.fact_check_outlined,
          color: changed ? const Color(0xFFC8641B) : XiangjiPalette.pine,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${event.methodTradition} · ${event.capabilityName}',
              style: const TextStyle(
                color: XiangjiPalette.pine,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${changed ? '军师改判' : '本轮已检查'} · ${event.methodLabel}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        subtitle: Text(_userLanguage(event.userVisibleSummary)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          XiangjiLabeledValue(
            label: '产品方案中的方法',
            value: event.capabilityName,
          ),
          XiangjiLabeledValue(
            label: '对应的原概念 / 求解概念',
            value: event.sourceConcept,
          ),
          XiangjiLabeledValue(
            label: '本轮受哪些叔本华 L0 原则约束',
            value: event.coreConceptNames.join('；'),
          ),
          XiangjiLabeledValue(
            label: '这个概念在产品中意味着什么',
            value: event.philosophyPrinciple,
          ),
          XiangjiLabeledValue(
            label: '军师在这道题里怎样使用',
            value: _userLanguage(event.operationSummary),
          ),
          XiangjiLabeledValue(
            label: '什么现实或线索触发了它',
            value: _userLanguage(event.trigger),
          ),
          if (changed) ...[
            XiangjiLabeledValue(
              label: '此前怎样理解',
              value: _stateSummary(event.beforeStateRefs),
            ),
            XiangjiLabeledValue(
              label: '现在怎样理解',
              value: _stateSummary(event.afterStateRefs),
            ),
          ] else
            XiangjiLabeledValue(
              label: '为什么暂时不改',
              value: _userLanguage(event.retainedStateReason),
            ),
          XiangjiLabeledValue(
            label: '怎样改变当前解法',
            value: _userLanguage(event.decisionEffect),
          ),
          XiangjiLabeledValue(
            label: '下一步由什么现实验算',
            value: _userLanguage(event.realityTest),
          ),
          XiangjiLabeledValue(
            label: '下次可以迁移的问题',
            value: event.transferQuestion,
          ),
          Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
            ),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                '知识来源与规范映射（按需展开）',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.philosophySource,
                        style: const TextStyle(
                          color: XiangjiPalette.muted,
                          height: 1.45,
                        ),
                      ),
                      if (event.relatedRuleIds.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '关联内置规则：${event.relatedRuleIds.join(' · ')}',
                          style: const TextStyle(
                            color: XiangjiPalette.muted,
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (footer != null) footer!,
        ],
      ),
    );
  }

  String _stateSummary(Map<String, Object?> state) {
    final parts = <String>[];
    _addPart(parts, '真问题', state['problem_frame'], const <String>[
      'statement',
      'true_problem',
      'summary',
    ]);
    _addPart(parts, '现实状态', state['current_state'], const <String>[
      'summary',
      'facts',
      'experiences',
    ]);
    _addPart(parts, '现实目标', state['goal_state'], const <String>[
      'statement',
      'goal',
      'success_criteria',
    ]);
    _addHypotheses(parts, state['hypotheses']);
    _addPart(parts, '关键差距', state['key_gap'], const <String>[
      'label',
      'description',
    ]);
    _addPart(parts, '当前小步', state['active_subgoal'], const <String>[
      'label',
      'description',
    ]);
    _addPart(parts, '当前行动', state['active_operator'], const <String>[
      'title',
      'name',
      'summary',
    ]);
    _addPart(parts, '事前预测', state['prediction_ledger'], const <String>[
      'prediction',
      'summary',
    ]);
    _addPart(parts, '认识状态', state['epistemic_profile'], const <String>[
      'epistemic_status',
      'status',
    ]);
    return parts.isEmpty ? '本轮状态已留存，可在完整解题纸中追溯' : parts.join('\n');
  }

  void _addPart(
    List<String> target,
    String label,
    Object? raw,
    List<String> preferredKeys,
  ) {
    if (raw is! Map) return;
    for (final key in preferredKeys) {
      final value = _valueText(raw[key]);
      if (value.isEmpty || value == '{}' || value == '[]') continue;
      target.add('$label：${_userLanguage(value)}');
      return;
    }
  }

  void _addHypotheses(List<String> target, Object? raw) {
    if (raw is! List) return;
    final values = raw
        .whereType<Map>()
        .map(
          (item) => _valueText(
            item['statement'] ?? item['claim'] ?? item['label'],
          ),
        )
        .where((item) => item.isNotEmpty)
        .take(3)
        .toList();
    if (values.isNotEmpty) target.add('正在区分的原因：${values.join('；')}');
  }

  String _valueText(Object? raw) {
    if (raw is List) {
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .take(5)
          .join('；');
    }
    return raw?.toString().trim() ?? '';
  }

  String _userLanguage(String value) {
    var result = value;
    const replacements = <String, String>{
      'CurrentState S0': '当前现实状态',
      'Goal G': '现实目标',
      'ConceptRealityMismatch': '概念与现实冲突',
      'PredictionLedger': '事前预测记录',
      'RealityResult': '现实结果',
      'ProblemFrame': '真问题定义',
      'KeyGap': '当前关键差距',
      'SubGoal': '当前小步',
      'Operator': '当前办法',
      'Precondition': '生效前提',
      'Hypothesis': '候选原因',
      'Prediction': '事前预测',
      'Execution': '执行',
      'Concept': '当前概念',
      'Judgment': '判断',
      'Goal': '目标',
      'Fact': '事实',
      'S0': '当前状态',
    };
    for (final entry in replacements.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }
}
