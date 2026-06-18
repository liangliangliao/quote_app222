import 'dart:convert';

import '../services/global_ai_settings.dart';
import '../services/unified_ai_service.dart';
import 'cognitive_consistency_dao.dart';
import 'cognitive_consistency_models.dart';
import 'cognitive_consistency_prompt_config.dart';

class CognitiveConsistencyAiService {
  final GlobalAiSettings _settings = GlobalAiSettings();
  final UnifiedAiService _ai = UnifiedAiService();
  final CognitiveConsistencyPromptConfig _promptConfig = CognitiveConsistencyPromptConfig();
  final CognitiveConsistencyDao _dao = CognitiveConsistencyDao();

  Future<Map<String, String>> getGlobalAiState() => _settings.getState();

  Future<CcPlanResult> generateTargetToAction({
    required String userGoal,
    required String userContext,
    required String userValues,
    String sourceType = '',
    String sourceId = '',
    String rewardSource = '',
    String originScene = '',
  }) async {
    final state = await getGlobalAiState();
    final fallback = _fallback(userGoal, userContext, userValues, state);
    final evidence = await _recentEvidenceText();
    final templates = await _promptConfig.load();
    final prompt = _promptConfig.render(
      '${templates.targetToAction}\n\n${templates.outputFormat}',
      <String, String>{
        'user_goal': _nonEmpty(userGoal, '未填写'),
        'user_context': _nonEmpty(userContext, '未填写'),
        'user_values': _nonEmpty(userValues, '未填写'),
        'recent_evidence': evidence,
        'today': _today(),
      },
    );
    return _runPlanScene(
      sceneType: 'target_to_action',
      purpose: 'cognitive_consistency.target_to_action',
      systemPrompt: templates.global,
      prompt: prompt,
      fallback: fallback,
      userGoal: userGoal,
      userContext: userContext,
      userValues: userValues,
      state: state,
      sourceType: sourceType,
      sourceId: sourceId,
      rewardSource: rewardSource,
      originScene: originScene.trim().isEmpty ? 'target_to_action' : originScene,
    );
  }

  Future<CcPlanResult> generateDissonanceAnalysis({
    required String userEvent,
    required String userValues,
    String sourceType = '',
    String sourceId = '',
    String originScene = '',
  }) async {
    final state = await getGlobalAiState();
    final fallback = _fallback(userEvent, '', userValues, state, scene: 'dissonance');
    final evidence = await _recentEvidenceText();
    final templates = await _promptConfig.load();
    final prompt = _promptConfig.render(
      '${templates.dissonanceAnalysis}\n\n${templates.outputFormat}',
      <String, String>{
        'user_event': _nonEmpty(userEvent, '未填写'),
        'user_values': _nonEmpty(userValues, '未填写'),
        'recent_evidence': evidence,
        'today': _today(),
      },
    );
    return _runPlanScene(
      sceneType: 'dissonance_analysis',
      purpose: 'cognitive_consistency.dissonance_analysis',
      systemPrompt: templates.global,
      prompt: prompt,
      fallback: fallback,
      userGoal: userEvent,
      userContext: userEvent,
      userValues: userValues,
      state: state,
      sourceType: sourceType,
      sourceId: sourceId,
      originScene: originScene.trim().isEmpty ? 'dissonance_analysis' : originScene,
    );
  }

  Future<CcPlanResult> generateSpecialSceneAnalysis({
    required String sceneKey,
    required String userInput,
    required String userValues,
    String sourceType = '',
    String sourceId = '',
  }) async {
    final cleanScene = sceneKey.trim().isEmpty ? 'choice_recheck' : sceneKey.trim();
    final state = await getGlobalAiState();
    final fallback = _fallback(userInput, '', userValues, state, scene: cleanScene).copyWith(
      coreConflict: _localSpecialCoreConflict(cleanScene, userInput),
      rationalizationTypes: _localSpecialRationalization(cleanScene),
      evidenceCategory: cleanScene == 'group_culture' || cleanScene == 'vicarious_dissonance' ? 'responsibility' : 'review',
      recommendedShameScene: '不需要',
      shameSignal: '',
      toxicShameLanguage: '',
      healthyShameReframe: '',
      truePrideSentence: '',
      shouldSyncTrueSelf: false,
      trueSelfBridgeReason: '',
    );
    final evidence = await _recentEvidenceText();
    final templates = await _promptConfig.load();
    final sceneInstruction = await _configuredSpecialSceneInstruction(cleanScene);
    final prompt = '''$sceneInstruction

用户输入：${_nonEmpty(userInput, '未填写')}
用户价值/目标：${_nonEmpty(userValues, '未填写')}
最近行动证据：$evidence
今天日期：${_today()}

${templates.outputFormat}
''';
    return _runPlanScene(
      sceneType: cleanScene,
      purpose: 'cognitive_consistency.$cleanScene',
      systemPrompt: templates.global,
      prompt: prompt,
      fallback: fallback,
      userGoal: userInput,
      userContext: userInput,
      userValues: userValues,
      state: state,
      sourceType: sourceType,
      sourceId: sourceId,
      originScene: cleanScene,
    );
  }


  Future<String> _configuredSpecialSceneInstruction(String sceneKey) async {
    final id = sceneKey == 'information_avoidance'
        ? 'cc_scene_information_avoidance'
        : sceneKey == 'identity_conflict'
            ? 'cc_scene_identity_conflict'
            : '';
    if (id.isEmpty) return _specialSceneInstruction(sceneKey);
    try {
      final inspected = await _promptConfig.inspectPrompt(id);
      final value = (inspected['value'] ?? '').trim();
      return value.isEmpty ? _specialSceneInstruction(sceneKey) : value;
    } catch (_) {
      return _specialSceneInstruction(sceneKey);
    }
  }

  String _specialSceneInstruction(String sceneKey) {
    switch (sceneKey) {
      case 'choice_recheck':
        return '''当前场景：选择后合理化检查。用户已经做出某个选择，可能正在反复证明“我当初选得对”。请重点识别：是否夸大已选择项、贬低未选择项、只寻找支持性证据、害怕承认选择有问题会威胁自我形象。请给出继续、调整、暂停、退出四种路径的判断标准，并落到一个低成本验证行动。不能直接替用户决定。''';
      case 'sunk_cost':
        return '''当前场景：沉没成本与努力合理化检查。用户可能已经投入时间、金钱、情感、身份承诺或痛苦，因此不愿重新评估方向。请区分现实价值与“证明过去没有白费”的合理化，判断继续投入是创造新价值还是扩大旧损失。必须提供继续但调整、暂停验证、承认沉没成本转向、保留成果迁移四条路径，并给一个低成本验证行动。''';
      case 'hypocrisy_change':
        return '''当前场景：虚伪诱导与价值—行为距离训练。用户认同某个价值，但现实中没有做到。请温和引导：明确价值、说明为什么重要、回忆最近一次未做到、识别价值与行为距离、避免羞辱，把不舒服转化为一个今天能做的小行动。核心不是证明用户糟糕，而是用行动缩小距离。''';
      case 'group_culture':
        return '''当前场景：群体、关系与文化失调。用户问题涉及家庭、朋友、团队、社会评价、文化角色、关系和谐或“大家都这样”。请识别个人价值、群体/家庭/文化标准、冲突点、害怕失去什么、从众合理化、责任扩散，并给出既不盲从也不粗暴切断关系的边界/表达行动。''';
      case 'vicarious_dissonance':
        return '''当前场景：替代性认知失调。用户可能因为“我们的人”“我支持的人”“我所属群体”做出违背价值的行为而不舒服。请识别群体认同程度、行为是否代表群体、用户是否在为内群体合理化、用户需要承担什么与不需要承担什么，并给出保持价值而不过度背责的现实行动。''';
      case 'responsibility_radar':
        return '''当前场景：责任—后果雷达专项。用户可能涉及内疚、后悔、伤害他人、承诺失败、过度自责或逃避责任。请重点分析自由选择、负面后果、可预见性、真实责任、非本人责任、过度背责、逃避责任、可修复部分，并给一个修复性小行动。''';
      case 'self_standard_map':
        return '''当前场景：自我标准地图专项。用户正在用某种标准审判自己。请区分个人标准、家庭标准、社会/道德标准、群体/文化标准、理想自我标准、现实能力标准，判断哪些标准值得保留、调整或放下，并给出一个符合新标准的小行动。''';
      case 'information_avoidance':
        return '''当前场景：信息回避挑战。用户正在回避账单、结果、体检、成绩、关系反馈、目标进展、反对证据或其他现实信息。请识别回避的信息、威胁的自我形象、最害怕的结果、信息回避方式，并把反对信息降级为今天能接触的最小事实行动。核心不是审判用户，而是恢复现实接触和行动能力。''';
      case 'identity_conflict':
        return '''当前场景：身份冲突重构。用户处在旧身份与新身份之间，例如逃避者/行动者、受害者/负责者、讨好者/有边界的人。请识别旧身份保护什么、新身份召唤什么、用户害怕失去什么，并给出一个不粗暴否定旧身份、但能支持新身份的小行动。''';
      default:
        return '''当前场景：现代认知失调专项分析。请围绕自由选择、负面后果、可预见性、责任边界、自我标准、合理化识别和行动修复输出结构化分析。''';
    }
  }

  String _localSpecialCoreConflict(String sceneKey, String input) {
    switch (sceneKey) {
      case 'choice_recheck':
        return '当前核心不是证明过去选择绝对正确，而是重新看见：这个选择今天是否仍然有现实价值，以及我是否正在为过去选择辩护。';
      case 'sunk_cost':
        return '当前核心是区分“有价值的坚持”和“因为投入太多而不敢重新评估”。过去投入不能自动证明继续投入正确。';
      case 'hypocrisy_change':
        return '当前核心是用户认同的价值与实际行为之间存在距离。这个距离不是人格失败，而是可以用一个小行动开始缩小的改变入口。';
      case 'group_culture':
        return '当前核心是个人价值与家庭、群体、文化或关系标准之间的冲突，需要既保留关系感，也保留自我边界。';
      case 'vicarious_dissonance':
        return '当前核心是用户把群体成员或支持对象的行为体验成“我们”的不一致，需要区分群体认同、个人责任和价值表达。';
      case 'responsibility_radar':
        return '当前核心是把后悔、内疚或责任压力拆成：事实后果、可预见性、真实责任、过度背责和可修复行动。';
      case 'self_standard_map':
        return '当前核心是看清用户正在用哪把尺子评价自己，并把过度僵硬的标准调整成可行动、可复盘、不过度羞辱的标准。';
      case 'information_avoidance':
        return '当前核心是用户可能正在通过不看结果、不听反馈、不查数据来减少短期不适，但长期会削弱现实接触和行动修正。';
      case 'identity_conflict':
        return '当前核心是旧身份在保护安全感，新身份在召唤价值行动；现在需要用小证据支持新身份，而不是强迫推翻旧自己。';
      default:
        return '当前存在价值、行为、选择或后果之间的不一致，需要转化为一个现实行动。';
    }
  }

  String _localSpecialRationalization(String sceneKey) {
    switch (sceneKey) {
      case 'choice_recheck':
        return '选择后合理化、夸大已选项、贬低未选项、只寻找支持性证据';
      case 'sunk_cost':
        return '沉没成本、努力合理化、痛苦神圣化、身份防御';
      case 'hypocrisy_change':
        return '价值—行为距离、后果淡化、拖延合理化、身份防御';
      case 'group_culture':
        return '从众合理化、责任扩散、关系压力、文化标准内化';
      case 'vicarious_dissonance':
        return '替代性失调、内群体合理化、群体身份防御、过度背责';
      case 'responsibility_radar':
        return '过度自责、逃避责任、后果淡化、责任外推';
      case 'self_standard_map':
        return '理想自我标准过严、家庭/社会标准内化、身份防御、完美主义';
      case 'information_avoidance':
        return '信息回避、只看支持证据、拖延查看结果、攻击反对证据、转移注意';
      case 'identity_conflict':
        return '旧身份保护、身份防御、害怕失败、害怕失去认同、未来幻想';
      default:
        return '认知失调、合理化、行动修复';
    }
  }

  Future<String> generatePreActionGuidance({
    required String oneDollarAction,
    required String hesitation,
    required String valueLink,
  }) async {
    final state = await getGlobalAiState();
    final fallback = '现在不需要解决整个人生，也不需要证明你很自律。先做30秒：${_nonEmpty(oneDollarAction, '打开相关工具并留下一个可见动作')}。完成后再评价意义。';
    final templates = await _promptConfig.load();
    if (state['available'] != '1') return fallback;
    final prompt = _promptConfig.render(templates.preAction, <String, String>{
      'one_dollar_action': oneDollarAction,
      'hesitation': _nonEmpty(hesitation, '用户没有填写犹豫内容，但需要行动前短促提醒'),
      'value_link': _nonEmpty(valueLink, '未填写'),
    });
    try {
      final raw = await _ai.generateText(
        prompt: prompt,
        purpose: 'cognitive_consistency.pre_action',
        systemPrompt: templates.global,
        maxTokens: 700,
        expectJson: false,
        temperature: 0.2,
      );
      return raw.trim().isEmpty ? fallback : raw.trim();
    } catch (_) {
      return fallback;
    }
  }

  Future<CcPlanResult> generateExternalRewardAnalysis({
    required String rewardContext,
    required String userGoal,
    required String userValues,
    String sourceType = '',
    String sourceId = '',
    String originScene = '',
  }) async {
    final state = await getGlobalAiState();
    final fallback = _fallback(userGoal, rewardContext, userValues, state, scene: 'reward').copyWith(
      rewardRisk: '如果行动主要靠积分、惩罚、排名或他人监督维持，长期可能让你把行动解释为“我只是为了外部理由才做”，从而削弱内在认同。',
      evidenceCategory: 'responsibility',
    );
    final templates = await _promptConfig.load();
    final prompt = _promptConfig.render(
      '${templates.externalReward}\n\n${templates.outputFormat}',
      <String, String>{
        'reward_context': _nonEmpty(rewardContext, '未填写'),
        'user_goal': _nonEmpty(userGoal, '未填写'),
        'user_values': _nonEmpty(userValues, '未填写'),
      },
    );
    return _runPlanScene(
      sceneType: 'external_reward_detox',
      purpose: 'cognitive_consistency.external_reward',
      systemPrompt: templates.global,
      prompt: prompt,
      fallback: fallback,
      userGoal: userGoal,
      userContext: rewardContext,
      userValues: userValues,
      state: state,
      sourceType: sourceType,
      sourceId: sourceId,
      rewardSource: rewardContext,
      originScene: originScene.trim().isEmpty ? 'external_reward_detox' : originScene,
    );
  }

  Future<CcPlanResult> generateSelfDeceptionCheck({
    required String userExplanation,
    required String knownFacts,
    required String userValues,
    String sourceType = '',
    String sourceId = '',
    String originScene = '',
  }) async {
    final state = await getGlobalAiState();
    final fallback = _fallback(userExplanation, knownFacts, userValues, state, scene: 'self_deception').copyWith(
      coreConflict: '你现在的解释可能一部分是在保护自己，避免羞耻和压力；也可能有一部分正在把你带离事实、责任或真实价值。关键不是审判自己，而是找到一个更诚实但不羞辱的解释。',
      evidenceCategory: 'review',
    );
    final templates = await _promptConfig.load();
    final prompt = _promptConfig.render(
      '${templates.selfDeception}\n\n${templates.outputFormat}',
      <String, String>{
        'user_explanation': _nonEmpty(userExplanation, '未填写'),
        'known_facts': _nonEmpty(knownFacts, '未填写'),
        'user_values': _nonEmpty(userValues, '未填写'),
      },
    );
    return _runPlanScene(
      sceneType: 'self_deception_check',
      purpose: 'cognitive_consistency.self_deception',
      systemPrompt: templates.global,
      prompt: prompt,
      fallback: fallback,
      userGoal: userExplanation,
      userContext: knownFacts,
      userValues: userValues,
      state: state,
      sourceType: sourceType,
      sourceId: sourceId,
      originScene: originScene.trim().isEmpty ? 'self_deception_check' : originScene,
    );
  }


  Future<String> generateValueRelationInsight({
    required String selectedValues,
    required String userGoal,
    required String userContext,
    required String recentEvidence,
  }) async {
    final templates = await _promptConfig.load();
    final state = await getGlobalAiState();
    final fallback = _localValueRelationInsight(selectedValues, userGoal, recentEvidence);
    if (state['available'] != '1') return fallback;
    final prompt = _promptConfig.render(templates.valueRelation, <String, String>{
      'selected_values': _nonEmpty(selectedValues, '未填写'),
      'user_goal': _nonEmpty(userGoal, '未填写'),
      'user_context': _nonEmpty(userContext, '未填写'),
      'recent_evidence': _nonEmpty(recentEvidence, '暂无'),
      'today': _today(),
    });
    try {
      final raw = await _ai.generateText(
        prompt: prompt,
        purpose: 'cognitive_consistency.value_relation',
        systemPrompt: templates.global,
        maxTokens: 1600,
        expectJson: false,
        temperature: 0.25,
      );
      return raw.trim().isEmpty ? fallback : raw.trim();
    } catch (_) {
      return fallback;
    }
  }

  Future<String> generateWeeklyReport(
    String userValues, {
    String periodLabel = '最近30天',
    int? sinceAtMs,
  }) async {
    final state = await getGlobalAiState();
    final records = await _dao.recentEvidence(limit: 300, sinceAtMs: sinceAtMs);
    if (records.isEmpty) return '当前范围“$periodLabel”还没有足够的行动证据。先完成一个 1 美元行动，再生成价值一致性报告。';
    final templates = await _promptConfig.load();
    final modernProfile = await _dao.modernPatternProfile();
    final dailyReviews = await _dao.recentDailyConsistencyReviews(limit: 7);
    final temperatureReviews = await _dao.recentTemperatureReviews(limit: 40);
    final informationResults = await _dao.recentInformationContactResults(limit: 40);
    final identityTransitions = await _dao.recentIdentityTransitions(limit: 40);
    final selfIntegrityStats = await _dao.selfIntegrityStats();
    final verificationTasks = await _dao.recentVerificationTasks(limit: 40);
    final fallback = _localWeeklyReport(records, periodLabel: periodLabel, modernProfile: modernProfile, dailyReviews: dailyReviews);
    String text;
    if (state['available'] != '1') {
      text = fallback;
    } else {
      final prompt = _promptConfig.render(templates.weeklyReport, <String, String>{
        'recent_records_json': jsonEncode(records.map((e) => <String, dynamic>{
              'goal': e.userGoal,
              'plannedAction': e.plannedAction,
              'completedAction': e.completedAction,
              'evidenceLabel': e.evidenceLabel,
              'valueLink': e.valueLink,
              'oldStory': e.oldStory,
              'newStory': e.newStory,
              'evidenceCategory': e.evidenceCategory,
              'identityDirection': e.identityDirection,
              'rewardSource': e.rewardSource,
              'sourceType': e.sourceType,
              'sourceId': e.sourceId,
              'effortMinutes': e.effortMinutes,
              'difficultyScore': e.difficultyScore,
              'createdAtMs': e.createdAtMs,
            }).toList()),
        'user_values': _nonEmpty(userValues, '未填写'),
        'report_range': periodLabel,
        'modern_profile_json': jsonEncode(modernProfile),
        'daily_reviews_json': jsonEncode(dailyReviews.map((e) => <String, dynamic>{
              'date': e.dateLabel,
              'closestValueAction': e.closestValueAction,
              'mainDissonance': e.mainDissonance,
              'rationalizationUsed': e.rationalizationUsed,
              'growthReframe': e.growthReframe,
              'repairActionDone': e.repairActionDone,
              'tomorrowAction': e.tomorrowAction,
            }).toList()),
        'temperature_reviews_json': jsonEncode(temperatureReviews.map((e) => <String, dynamic>{
              'sessionId': e.sessionId,
              'evidenceId': e.evidenceId,
              'repairMode': e.repairMode,
              'reviewText': e.reviewText,
              'nextCoolingAction': e.nextCoolingAction,
              'createdAtMs': e.createdAtMs,
            }).toList()),
        'information_contact_results_json': jsonEncode(informationResults.map((e) => <String, dynamic>{
              'sessionId': e.sessionId,
              'evidenceId': e.evidenceId,
              'avoidedInformation': e.avoidedInformation,
              'fearedResult': e.fearedResult,
              'actualResult': e.actualResult,
              'resultType': e.resultType,
              'repairAction': e.repairAction,
              'createdAtMs': e.createdAtMs,
            }).toList()),
        'identity_transitions_json': jsonEncode(identityTransitions.map((e) => <String, dynamic>{
              'sessionId': e.sessionId,
              'evidenceId': e.evidenceId,
              'oldIdentity': e.oldIdentity,
              'newIdentity': e.newIdentity,
              'oldProtection': e.oldProtection,
              'fearOfLoss': e.fearOfLoss,
              'newIdentityAction': e.newIdentityAction,
              'postActionIdentitySentence': e.postActionIdentitySentence,
              'nextIdentityAction': e.nextIdentityAction,
              'createdAtMs': e.createdAtMs,
            }).toList()),
        'self_integrity_stats_json': jsonEncode(selfIntegrityStats),
        'verification_tasks_json': jsonEncode(verificationTasks.map((e) => <String, dynamic>{
              'taskId': e.taskId,
              'sessionId': e.sessionId,
              'status': e.status,
              'question': e.question,
              'successSignal': e.successSignal,
              'resultNote': e.resultNote,
              'dueAtMs': e.dueAtMs,
            }).toList()),
      });
      try {
        final raw = await _ai.generateText(
          prompt: prompt,
          purpose: 'cognitive_consistency.period_report',
          systemPrompt: templates.global,
          maxTokens: 2600,
          expectJson: false,
          temperature: 0.25,
        );
        text = raw.trim().isEmpty ? fallback : raw.trim();
      } catch (_) {
        text = fallback;
      }
    }
    await _dao.saveReport(periodLabel: periodLabel, userValues: userValues, reportText: text);
    return text;
  }

  Future<String> generatePostActionExplanation({
    required String userGoal,
    required String plannedAction,
    required String completedAction,
    required String userReflection,
    required String valueLink,
    required String oldStory,
    String v18Context = '',
  }) async {
    final state = await getGlobalAiState();
    final fallback = '这次行动虽然很小，但它说明你不是只能停留在旧模式里。它打破了“${oldStory.trim().isEmpty ? '必须有动力才开始' : oldStory}”。它支持你成为一个能用小行动靠近价值的人。';
    final templates = await _promptConfig.load();
    if (state['available'] != '1') return fallback;
    final prompt = _promptConfig.render(templates.postAction, <String, String>{
      'user_goal': userGoal,
      'one_dollar_action': plannedAction,
      'completed_action': completedAction,
      'user_reflection': userReflection,
      'value_link': valueLink,
      'old_story': oldStory,
      'v18_context': _nonEmpty(v18Context, '暂无结构化 V18 上下文。'),
    });
    try {
      final raw = await _ai.generateText(
        prompt: prompt,
        purpose: 'cognitive_consistency.post_action',
        systemPrompt: templates.global,
        maxTokens: 900,
        expectJson: false,
        temperature: 0.25,
      );
      return raw.trim().isEmpty ? fallback : raw.trim();
    } catch (_) {
      return fallback;
    }
  }


  Future<String> generateTemperatureReview({
    required String plannedAction,
    required String completedAction,
    required CcDissonanceTemperatureLog? before,
    required CcDissonanceTemperatureLog? after,
    String dissonanceTypes = '',
    String growthExplanation = '',
  }) async {
    String tempText(CcDissonanceTemperatureLog? l) {
      if (l == null) return '未记录';
      return '不适${l.discomfortScore}/10，内疚${l.guiltScore}/10，焦虑${l.anxietyScore}/10，羞耻${l.shameScore}/10，防御${l.defensivenessScore}/10，逃避${l.avoidanceUrgeScore}/10，清醒${l.clarityScore}/10，责任${l.responsibilityScore}/10，意愿${l.actionWillingnessScore}/10';
    }
    final discomfortDrop = (before?.discomfortScore ?? 0) - (after?.discomfortScore ?? 0);
    final avoidanceDrop = (before?.avoidanceUrgeScore ?? 0) - (after?.avoidanceUrgeScore ?? 0);
    final clarityRise = (after?.clarityScore ?? 0) - (before?.clarityScore ?? 0);
    final fallbackMode = discomfortDrop > 0 || avoidanceDrop > 0 || clarityRise > 0 ? '行动型修复' : '仍需验证';
    final fallback = '温度变化：不适${discomfortDrop >= 0 ? '下降' : '上升'}${discomfortDrop.abs()}，逃避${avoidanceDrop >= 0 ? '下降' : '上升'}${avoidanceDrop.abs()}，清醒${clarityRise >= 0 ? '上升' : '下降'}${clarityRise.abs()}。这次暂判为“$fallbackMode”。下一步继续做一个更小、更具体的现实行动，并观察不适和逃避是否继续下降。';
    final state = await getGlobalAiState();
    if (state['available'] != '1') return fallback;
    final templates = await _promptConfig.load();
    final prompt = _promptConfig.render(templates.temperatureReview, <String, String>{
      'planned_action': plannedAction,
      'completed_action': completedAction,
      'before_temperature': tempText(before),
      'after_temperature': tempText(after),
      'dissonance_types': _nonEmpty(dissonanceTypes, '未明确'),
      'growth_explanation': _nonEmpty(growthExplanation, '暂无'),
    });
    try {
      final raw = await _ai.generateText(
        prompt: prompt,
        purpose: 'cognitive_consistency.temperature_review',
        systemPrompt: templates.global,
        maxTokens: 900,
        expectJson: false,
        temperature: 0.25,
      );
      return raw.trim().isEmpty ? fallback : raw.trim();
    } catch (_) {
      return fallback;
    }
  }

  Future<CcDailyConsistencyReview> generateDailyReviewDraft({
    required String userValues,
    required String todayEvidence,
    required String todayDissonance,
    String recentEvidence = '',
  }) async {
    final templates = await _promptConfig.load();
    final state = await getGlobalAiState();
    final today = _today();
    CcDailyConsistencyReview localDraft() => CcDailyConsistencyReview(
          reviewId: 'draft_${DateTime.now().millisecondsSinceEpoch}',
          dateLabel: today,
          closestValueAction: todayEvidence.trim().isEmpty ? '今天至少保留一个小行动证据。' : todayEvidence.trim(),
          mainDissonance: todayDissonance.trim().isEmpty ? '今天主要检查价值与行动是否断开。' : todayDissonance.trim(),
          rationalizationUsed: '可能存在等待状态、淡化问题或用解释替代行动。',
          growthReframe: '不需要证明彻底改变，只需要用一个真实行动恢复一点一致性。',
          repairActionDone: todayEvidence.trim(),
          tomorrowAction: '明天重复一个 3 分钟最小行动，并记录行动前后感受。',
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
        );
    if (state['available'] != '1') return localDraft();
    final prompt = _promptConfig.render(templates.dailyReview, <String, String>{
      'today_evidence': _nonEmpty(todayEvidence, '暂无今日证据'),
      'today_dissonance': _nonEmpty(todayDissonance, '暂无明确失调'),
      'user_values': _nonEmpty(userValues, '未填写'),
      'recent_evidence': _nonEmpty(recentEvidence, '暂无'),
      'today': today,
    });
    try {
      final raw = await _ai.generateText(
        prompt: prompt,
        purpose: 'cognitive_consistency.daily_review_draft',
        systemPrompt: templates.global,
        maxTokens: 1400,
        expectJson: true,
        temperature: 0.25,
      );
      final parsed = _extractJsonObject(raw);
      if (parsed.isEmpty) return localDraft();
      return CcDailyConsistencyReview(
        reviewId: 'draft_${DateTime.now().millisecondsSinceEpoch}',
        dateLabel: today,
        closestValueAction: _read(parsed, 'closestValueAction', _read(parsed, 'closest_value_action', localDraft().closestValueAction)),
        mainDissonance: _read(parsed, 'mainDissonance', _read(parsed, 'main_dissonance', localDraft().mainDissonance)),
        rationalizationUsed: _read(parsed, 'rationalizationUsed', _read(parsed, 'rationalization_used', localDraft().rationalizationUsed)),
        growthReframe: _read(parsed, 'growthReframe', _read(parsed, 'growth_reframe', localDraft().growthReframe)),
        repairActionDone: _read(parsed, 'repairActionDone', _read(parsed, 'repair_action_done', localDraft().repairActionDone)),
        tomorrowAction: _read(parsed, 'tomorrowAction', _read(parsed, 'tomorrow_action', localDraft().tomorrowAction)),
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      return localDraft();
    }
  }

  Future<CcPlanResult> _runPlanScene({
    required String sceneType,
    required String purpose,
    required String systemPrompt,
    required String prompt,
    required CcPlanResult fallback,
    required String userGoal,
    required String userContext,
    required String userValues,
    required Map<String, String> state,
    String sourceType = '',
    String sourceId = '',
    String rewardSource = '',
    String originScene = '',
  }) async {
    CcPlanResult result = fallback;
    if (state['available'] == '1') {
      try {
        final raw = await _ai.generateText(
          prompt: prompt,
          purpose: purpose,
          systemPrompt: systemPrompt,
          maxTokens: 2400,
          expectJson: true,
          temperature: 0.25,
        );
        final parsed = _extractJsonObject(raw);
        if (parsed.isNotEmpty) {
          result = _planFromParsed(parsed, fallback, raw, state);
        }
      } catch (_) {
        result = fallback;
      }
    }
    final sessionId = await _dao.saveSession(
      sceneType: sceneType,
      userGoal: userGoal,
      userContext: userContext,
      userValues: userValues,
      result: result,
      sourceType: sourceType,
      sourceId: sourceId,
      rewardSource: rewardSource,
      originScene: originScene.trim().isEmpty ? sceneType : originScene,
    );
    return result.copyWith(sessionId: sessionId);
  }

  CcPlanResult _planFromParsed(Map<String, dynamic> parsed, CcPlanResult fallback, String raw, Map<String, String> state) {
    final structure = _asMap(parsed['dissonanceStructure']);
    final trigger = _asMap(parsed['triggerConditions']);
    final boundary = _asMap(parsed['responsibilityBoundary']);
    final standards = _asMap(parsed['selfStandards']);
    final rationalization = _asMap(parsed['rationalization']);
    final trueSelf = _asMap(parsed['trueSelfBridge']);
    final choicePaths = _asMap(parsed['choicePaths']);
    final sunkCostCheck = _asMap(parsed['sunkCostCheck']);
    final hypocrisyInduction = _asMap(parsed['hypocrisyInduction']);
    final groupConflict = _asMap(parsed['groupConflict']);
    final vicariousDissonance = _asMap(parsed['vicariousDissonance']);
    final verificationTask = _asMap(parsed['verificationTask']);
    final dissonanceIntensity = _asMap(parsed['dissonanceIntensity']);
    final dissonanceTemperature = _asMap(parsed['dissonanceTemperature']);
    final simultaneousAccessibility = _asMap(parsed['simultaneousAccessibility']);
    final growthConsistency = _asMap(parsed['defensiveVsGrowthConsistency']);
    final selfIntegrityCard = _asMap(parsed['selfIntegrityCard']);
    final actionSet = _asMap(parsed['actionSet']);
    final informationAvoidanceMap = _asMap(parsed['informationAvoidance']);
    final informationBranchesMap = _asMap(parsed['informationAvoidanceBranches']);
    final identityConflictMap = _asMap(parsed['identityConflict']);
    final identityDialogueMap = _asMap(parsed['identityDialogue']);
    final dailyReviewSeed = _asMap(parsed['dailyReviewSeed']);

    final minimumActionVariant = _actionVariantFromMap(
      _asMap(actionSet['minimumAction']),
      actionType: 'minimum',
      label: '最小行动',
      fallback: fallback.minimumActionVariant,
      fallbackText: fallback.minimumAction,
    );
    final correctiveActionVariant = _actionVariantFromMap(
      _asMap(actionSet['correctiveAction']),
      actionType: 'corrective',
      label: '修正行动',
      fallback: fallback.correctiveActionVariant,
      fallbackText: fallback.correctiveAction,
    );
    final evidenceActionVariant = _actionVariantFromMap(
      _asMap(actionSet['evidenceAction']),
      actionType: 'evidence',
      label: '证据行动',
      fallback: fallback.evidenceActionVariant,
      fallbackText: fallback.evidenceAction,
    );
    final informationAvoidanceBranches = _informationBranchesFromMap(
      informationBranchesMap.isEmpty ? informationAvoidanceMap : informationBranchesMap,
      fallback: fallback.informationAvoidanceBranches,
      fallbackText: fallback.informationAvoidance,
    );
    final identityDialogue = _identityDialogueFromMap(
      identityDialogueMap.isEmpty ? identityConflictMap : identityDialogueMap,
      fallback: fallback.identityDialogue,
      fallbackText: fallback.identityConflict,
    );
    final intensityTotal = _resolveIntensityTotal(dissonanceIntensity, fallback.dissonanceIntensityScore);
    final intensityLevel = _normalizeIntensityLevel(
      _read(dissonanceIntensity, 'level', fallback.dissonanceIntensityLevel),
      intensityTotal,
    );
    return CcPlanResult(
      coreConflict: _read(parsed, 'coreConflict', _read(structure, 'coreConflict', fallback.coreConflict)),
      changeEntry: _read(parsed, 'changeEntry', fallback.changeEntry),
      oneDollarAction: _read(parsed, 'oneDollarAction', fallback.oneDollarAction),
      preCommitment: _read(parsed, 'preCommitment', fallback.preCommitment),
      inActionReminder: _read(parsed, 'inActionReminder', fallback.inActionReminder),
      postActionExplanation: _read(parsed, 'postActionExplanation', fallback.postActionExplanation),
      nextStep: _read(parsed, 'nextStep', fallback.nextStep),
      riskReminder: _read(parsed, 'riskReminder', fallback.riskReminder),
      valueLink: _read(parsed, 'valueLink', fallback.valueLink),
      oldStory: _read(parsed, 'oldStory', fallback.oldStory),
      evidenceLabel: _read(parsed, 'evidenceLabel', fallback.evidenceLabel),
      believedValue: _read(parsed, 'believedValue', _read(structure, 'believedValue', fallback.believedValue)),
      actualBehavior: _read(parsed, 'actualBehavior', _read(structure, 'actualBehavior', fallback.actualBehavior)),
      selfExplanation: _read(parsed, 'selfExplanation', _read(structure, 'selfExplanation', fallback.selfExplanation)),
      dissonancePoint: _read(parsed, 'dissonancePoint', fallback.dissonancePoint),
      protectiveExplanation: _read(parsed, 'protectiveExplanation', fallback.protectiveExplanation),
      avoidanceExplanation: _read(parsed, 'avoidanceExplanation', fallback.avoidanceExplanation),
      repairAction: _read(parsed, 'repairAction', fallback.repairAction),
      rewardRisk: _read(parsed, 'rewardRisk', fallback.rewardRisk),
      identityDirection: _read(parsed, 'identityDirection', fallback.identityDirection),
      evidenceCategory: _normalizeCategory(_read(parsed, 'evidenceCategory', fallback.evidenceCategory)),
      eventSummary: _read(parsed, 'eventSummary', fallback.eventSummary),
      freedomOfChoice: _read(trigger, 'freedomOfChoice', fallback.freedomOfChoice),
      negativeConsequence: _read(trigger, 'negativeConsequence', fallback.negativeConsequence),
      foreseeability: _read(trigger, 'foreseeability', fallback.foreseeability),
      responsibilityFeeling: _read(trigger, 'responsibilityFeeling', fallback.responsibilityFeeling),
      repairability: _read(trigger, 'repairability', fallback.repairability),
      notUserResponsibility: _read(boundary, 'notUserResponsibility', fallback.notUserResponsibility),
      userResponsibility: _read(boundary, 'userResponsibility', fallback.userResponsibility),
      overBlameRisk: _read(boundary, 'overBlameRisk', fallback.overBlameRisk),
      avoidanceRisk: _read(boundary, 'avoidanceRisk', fallback.avoidanceRisk),
      repairablePart: _read(boundary, 'repairablePart', fallback.repairablePart),
      personalStandard: _read(standards, 'personalStandard', fallback.personalStandard),
      normativeStandard: _read(standards, 'normativeStandard', fallback.normativeStandard),
      familyOrGroupStandard: _read(standards, 'familyOrGroupStandard', fallback.familyOrGroupStandard),
      idealSelfStandard: _read(standards, 'idealSelfStandard', fallback.idealSelfStandard),
      adjustedStandard: _read(standards, 'adjustedStandard', fallback.adjustedStandard),
      rationalizationTypes: _readList(rationalization, 'possibleTypes', fallback.rationalizationTypes),
      protectiveFunction: _read(rationalization, 'protectiveFunction', fallback.protectiveFunction),
      longTermCost: _read(rationalization, 'longTermCost', fallback.longTermCost),
      honestReframe: _read(rationalization, 'honestReframe', fallback.honestReframe),
      shameSignal: _read(trueSelf, 'shameSignal', fallback.shameSignal),
      toxicShameLanguage: _read(trueSelf, 'toxicShameLanguage', fallback.toxicShameLanguage),
      healthyShameReframe: _read(trueSelf, 'healthyShameReframe', fallback.healthyShameReframe),
      recommendedShameScene: _read(trueSelf, 'recommendedShameScene', fallback.recommendedShameScene),
      truePrideSentence: _read(parsed, 'truePrideSentence', fallback.truePrideSentence),
      shouldSyncTrueSelf: _readBool(trueSelf, 'shouldSyncTrueSelf', fallback.shouldSyncTrueSelf),
      trueSelfBridgeReason: _read(trueSelf, 'trueSelfBridgeReason', fallback.trueSelfBridgeReason),
      choicePaths: _stringifySection(choicePaths, fallback.choicePaths),
      sunkCostCheck: _stringifySection(sunkCostCheck, fallback.sunkCostCheck),
      hypocrisyInduction: _stringifySection(hypocrisyInduction, fallback.hypocrisyInduction),
      groupConflict: _stringifySection(groupConflict, fallback.groupConflict),
      vicariousDissonance: _stringifySection(vicariousDissonance, fallback.vicariousDissonance),
      todoWriteBackInsight: _read(parsed, 'todoWriteBackInsight', fallback.todoWriteBackInsight),
      dissonanceReductionMode: _normalizeReductionMode(_read(parsed, 'dissonanceReductionMode', fallback.dissonanceReductionMode)),
      verificationQuestion: _read(verificationTask, 'question', fallback.verificationQuestion),
      verificationSuccessSignal: _read(verificationTask, 'successSignal', fallback.verificationSuccessSignal),
      verificationDueDays: int.tryParse(_read(verificationTask, 'dueDays', fallback.verificationDueDays.toString()))?.clamp(1, 30).toInt() ?? fallback.verificationDueDays,
      dissonanceTypes: _readDissonanceTypes(parsed['dissonanceTypes'], fallback.dissonanceTypes),
      dissonanceIntensityScore: intensityTotal,
      dissonanceIntensityLevel: intensityLevel,
      dissonanceIntensityMainSources: _readList(dissonanceIntensity, 'mainSources', fallback.dissonanceIntensityMainSources),
      dissonanceTemperature: _stringifySection(dissonanceTemperature, fallback.dissonanceTemperature),
      simultaneousAccessibility: _stringifySection(simultaneousAccessibility, fallback.simultaneousAccessibility),
      defensiveExplanation: _read(growthConsistency, 'defensiveExplanation', fallback.defensiveExplanation),
      shortTermProtection: _read(growthConsistency, 'shortTermProtection', fallback.shortTermProtection),
      growthExplanation: _read(growthConsistency, 'growthExplanation', fallback.growthExplanation),
      selfIntegrityCard: _stringifySection(selfIntegrityCard, fallback.selfIntegrityCard),
      minimumAction: minimumActionVariant.displayText.isNotEmpty ? minimumActionVariant.displayText : fallback.minimumAction,
      correctiveAction: correctiveActionVariant.displayText.isNotEmpty ? correctiveActionVariant.displayText : fallback.correctiveAction,
      evidenceAction: evidenceActionVariant.displayText.isNotEmpty ? evidenceActionVariant.displayText : fallback.evidenceAction,
      minimumActionVariant: minimumActionVariant,
      correctiveActionVariant: correctiveActionVariant,
      evidenceActionVariant: evidenceActionVariant,
      informationAvoidance: informationAvoidanceBranches.displayText.isNotEmpty ? informationAvoidanceBranches.displayText : _stringifySection(informationAvoidanceMap, fallback.informationAvoidance),
      identityConflict: identityDialogue.displayText.isNotEmpty ? identityDialogue.displayText : _stringifySection(identityConflictMap, fallback.identityConflict),
      informationAvoidanceBranches: informationAvoidanceBranches,
      identityDialogue: identityDialogue,
      dailyReviewSeed: _stringifySection(dailyReviewSeed, fallback.dailyReviewSeed),
      provider: state['provider'] ?? 'ai',
      modelLabel: state['label'] ?? 'AI',
      rawResponse: raw,
      usedFallback: false,
    );
  }

  Future<String> _recentEvidenceText() async {
    final rows = await _dao.recentEvidence(limit: 8);
    if (rows.isEmpty) return '暂无。';
    return rows.map((e) => '- ${e.evidenceLabel}｜行动：${e.completedAction}｜价值：${e.valueLink}｜分类：${e.evidenceCategory}').join('\n');
  }

  String _localValueRelationInsight(String selectedValues, String userGoal, String recentEvidence) {
    final values = selectedValues.trim().isEmpty ? '当前多价值组合' : selectedValues.trim();
    final goal = userGoal.trim().isEmpty ? '当前目标' : userGoal.trim();
    final evidence = recentEvidence.trim().isEmpty ? '暂无。' : recentEvidence.trim();
    return '''【多价值协同 / 冲突扫描】
多价值组合：$values

【共同身份方向】
把价值从口号变成一个今天可见的动作：不是同时满足所有价值，而是找一个不伤害核心价值的小交汇点。

【可能协同】
如果多个价值都指向长期成长、健康、责任或自由，优先设计一个低成本但真实的行动，让它同时留下证据。

【可能冲突与护栏】
如果一个价值要求推进，另一个价值要求休息或边界，不要用强迫压倒自己；给行动加上时间上限、最低标准和停止条件。

【可组合的1美元行动】
围绕“$goal”，先做 3 分钟，并写下一句：这一步同时服务了哪些价值、没有牺牲哪些价值。

【已有证据参考】
$evidence''';
  }

  String _localWeeklyReport(
    List<CcEvidenceRecord> records, {
    String periodLabel = '最近行动证据',
    Map<String, dynamic> modernProfile = const <String, dynamic>{},
    List<CcDailyConsistencyReview> dailyReviews = const <CcDailyConsistencyReview>[],
  }) {
    final total = records.length;
    final minutes = records.fold<int>(0, (sum, e) => sum + e.effortMinutes);
    final recovery = records.where((e) => e.evidenceCategory == 'recovery').length;
    final values = records.map((e) => e.valueLink.trim()).where((e) => e.isNotEmpty).toSet().take(5).join('、');
    final latest = records.first;
    String topMap(dynamic raw) {
      if (raw is Map && raw.isNotEmpty) {
        final entries = raw.entries.toList()..sort((a, b) => (b.value is num ? (b.value as num).toInt() : 0).compareTo(a.value is num ? (a.value as num).toInt() : 0));
        return entries.take(5).map((e) => '${e.key}×${e.value}').join('、');
      }
      return '暂无';
    }
    final typeSummary = topMap(modernProfile['dissonanceTypeCounts']);
    final intensitySummary = topMap(modernProfile['intensityLevelCounts']);
    final tempDelta = modernProfile['temperatureDelta'];
    final tempSummary = tempDelta is Map && tempDelta.isNotEmpty
        ? tempDelta.entries.map((e) => '${e.key}${e.value}').join('、')
        : '暂无成对温度变化';
    final verificationSummary = topMap(modernProfile['verificationCounts']);
    final informationSummary = topMap(modernProfile['informationResultCounts']);
    final identityOldSummary = topMap(modernProfile['topOldIdentityCounts']);
    final identityNewSummary = topMap(modernProfile['topNewIdentityCounts']);
    final tempModeSummary = topMap(modernProfile['temperatureRepairModeCounts']);
    final dailySummary = dailyReviews.isEmpty
        ? '暂无每日一致性复盘。'
        : dailyReviews.take(3).map((r) => '${r.dateLabel}：${r.mainDissonance.isEmpty ? r.closestValueAction : r.mainDissonance}；明天：${r.tomorrowAction}').join('\n');
    return '【价值一致性报告｜$periodLabel】\n当前范围已沉淀 $total 条行动证据，累计约 $minutes 分钟，其中“中断后回来/分心后回来”的证据 $recovery 条。最值得保留的事实不是“你已经彻底改变”，而是：你已经多次用小行动打断完全不行动的旧模式。\n\n【主要价值方向】\n${values.isEmpty ? '暂未明确，可在下一次行动前补充价值。' : values}\n\n【V18 失调画像】\n高频失调类型：$typeSummary\n失调强度分布：$intensitySummary\n温度变化：$tempSummary\n温度复盘模式：$tempModeSummary\n信息接触结果：$informationSummary\n身份变化：旧身份 $identityOldSummary；新身份 $identityNewSummary\n验证任务：$verificationSummary\n每日复盘：\n$dailySummary\n\n【最有效的1美元行动】\n${latest.completedAction}\n\n【最常见的旧解释线索】\n${latest.oldStory.isEmpty ? '暂未记录。下一次行动后请写一句“它打破了什么旧解释”。' : latest.oldStory}\n\n【下一个最小充分行动】\n重复最近一次有效动作，或把它轻微升级 1 分钟。重点不是连续完美，而是再次制造真实证据。\n\n【风险提醒】\n不要因为行动很小就否定它；也不要把一次完成夸大成彻底改变。把它当成真实证据，继续积累。';
  }

  CcPlanResult _fallback(String userGoal, String userContext, String userValues, Map<String, String> state, {String scene = 'target'}) {
    final goal = userGoal.trim().isEmpty ? '这个目标' : userGoal.trim();
    final values = userValues.trim().isEmpty ? '成长、自由或责任' : userValues.trim();
    final context = userContext.trim().isEmpty ? '目标可能过大或启动入口不清晰' : userContext.trim();
    final isReward = scene == 'reward';
    return CcPlanResult(
      coreConflict: isReward
          ? '你可能正在用外部奖励、打卡、监督或惩罚来启动“$goal”。这些工具短期能帮你开始，但如果外部理由太强，行动容易被解释成“我只是为了奖励/避免惩罚才做”。'
          : '你可能重视“$values”，但当前在“$goal”上还没有稳定行动证据。真正的冲突不一定是你不想改变，而是价值、行为和自我解释暂时没有接上：$context。',
      changeEntry: '这不是人格失败，而是旧模式与新方向之间的摩擦点。先不要求自己彻底相信，只需要完成一个小到可以开始的动作，让系统出现第一条新证据。',
      oneDollarAction: '现在打开与“$goal”直接相关的一个页面、一本书或一个工具，只做 3 分钟，并留下一个可见产出：一句话记录“我刚才具体做了什么”。',
      preCommitment: '我现在不是为了证明自己彻底改变，而是为了给自己一个新的证据：我可以在动力不足时开始 3 分钟。',
      inActionReminder: '先完成动作，完成后再评价意义。',
      postActionExplanation: '这次行动虽然很小，但它说明我不是只能停在原地。它打破了“必须有动力才开始”。它支持我成为一个能用小行动靠近价值的人。',
      nextStep: '明天重复同一个 3 分钟动作，或只增加 1 分钟。',
      riskReminder: '不要用完美主义否定小行动，也不要把小行动夸大成彻底改变。它只是一个小证据，但它是真实的。',
      valueLink: values,
      oldStory: '我必须有足够动力或状态很好才能开始',
      evidenceLabel: '我在动力不足时完成了一个最小行动',
      believedValue: values,
      actualBehavior: context,
      selfExplanation: '也许我需要先有动力、状态或完整方案才能开始',
      dissonancePoint: '价值想前进，但行为还缺少足够小、足够真实的入口。',
      protectiveExplanation: '承认困难和阻力是在保护自己，能降低羞耻。',
      avoidanceExplanation: '如果一直用“没状态/没动力/太难了”解释，就可能变成逃避行动的合理化。',
      repairAction: '完成一个 3 分钟动作，并记录事实证据。',
      rewardRisk: isReward ? '外部理由过强会削弱行动与自我价值之间的连接。' : '',
      identityDirection: '能用小行动靠近价值的人',
      evidenceCategory: scene == 'self_deception' ? 'review' : (scene == 'dissonance' ? 'start' : 'start'),
      eventSummary: goal,
      freedomOfChoice: '需要进一步区分：哪些确实受环境限制，哪些仍有一个很小的自主入口。',
      negativeConsequence: '当前负面后果主要是价值与行为长期断开，行动证据不足，内耗持续。',
      foreseeability: '如果继续等待完整动力，拖延和自我否定大概率会重复。',
      responsibilityFeeling: '用户只需要对下一步可执行行动负责，不需要把整个旧模式解释成人格失败。',
      repairability: '可从一个 3 分钟行动开始修复。',
      notUserResponsibility: '过去形成的环境、情绪波动和阻力本身不等于用户的人格失败。',
      userResponsibility: '现在可以为一个足够小、可完成、可复盘的行动负责。',
      overBlameRisk: '如果把一次拖延等同于整个人失败，会加重羞耻和回避。',
      avoidanceRisk: '如果一直等待动力或状态，可能继续用解释替代行动。',
      repairablePart: '完成一个最小行动，并把它写成真实证据。',
      personalStandard: values,
      normativeStandard: '不以完美连续打卡评价自己，而以真实行动和回来能力评价自己。',
      familyOrGroupStandard: '',
      idealSelfStandard: '成为能在阻力中仍然开始一点的人。',
      adjustedStandard: '今天不证明彻底改变，只证明我可以开始一个小动作。',
      rationalizationTypes: scene == 'self_deception' ? '拖延合理化、身份防御' : '等待动力、完美主义否定小行动',
      protectiveFunction: '这些解释短期能减少压力和羞耻。',
      longTermCost: '长期可能让价值与行为继续断开，证据账本没有新增事实。',
      honestReframe: '我确实有阻力，但我仍然可以选择一个小到可执行的入口。',
      // Fallback must not auto-trigger True Self evidence sync.
      // True Self bridge is reserved for explicit AI/user shame signals.
      shameSignal: '',
      toxicShameLanguage: '',
      healthyShameReframe: '',
      recommendedShameScene: '不需要',
      truePrideSentence: '',
      choicePaths: scene == 'choice_recheck' ? '继续：仍有现实价值且有新证据；调整：方向仍重要但方式要变；暂停：证据不足需要低成本验证；退出：继续只是在维护过去选择。' : '',
      sunkCostCheck: scene == 'sunk_cost' ? '已投入不等于继续正确；请区分可迁移成果、继续成本、退出成本和下一次验证。' : '',
      hypocrisyInduction: scene == 'hypocrisy_change' ? '先明确认同价值，再承认最近一次没做到，最后用一个小行动缩短价值—行为距离。' : '',
      groupConflict: scene == 'group_culture' ? '区分个人价值、家庭/群体/文化标准、关系风险和边界表达。' : '',
      vicariousDissonance: scene == 'vicarious_dissonance' ? '区分我与群体的认同、群体行为是否代表我、我需要表达什么、不需要背负什么。' : '',
      todoWriteBackInsight: '回写 Todo 时应保留责任边界、自我标准、合理化类型与下一步修复行动，避免只写“完成了什么”。',
      dissonanceReductionMode: scene == 'dissonance' ? 'explanation_only' : 'action_repair',
      verificationQuestion: scene == 'choice_recheck' || scene == 'sunk_cost' || scene == 'group_culture' || scene == 'vicarious_dissonance' || scene == 'hypocrisy_change' || scene == 'responsibility_radar' || scene == 'self_standard_map' || scene == 'information_avoidance' || scene == 'identity_conflict' || scene == 'dissonance' ? '现实验证：这次分析后的最小行动是否真的降低了失调、增强了清醒感，并让行为更接近价值？' : '',
      verificationSuccessSignal: '出现一个可观察变化，或发现原判断需要修正。',
      verificationDueDays: 3,
      dissonanceTypes: scene == 'information_avoidance' ? '信息回避失调' : (scene == 'identity_conflict' ? '身份冲突失调' : '行为—价值失调、自我形象威胁型失调'),
      dissonanceIntensityScore: 10,
      dissonanceIntensityLevel: '中等失调',
      dissonanceIntensityMainSources: '核心价值相关、行动证据不足、情绪不适',
      dissonanceTemperature: '不适=5；逃避冲动=5；清醒感=3；行动意愿=4',
      simultaneousAccessibility: '''认知A：我重视“$values”
认知B：当前在“$goal”上还缺少稳定行动证据
成长窗口：现在用一个3分钟行动让两个认知重新接上''',
      defensiveExplanation: '我必须有足够动力、状态或完整方案才能开始。',
      shortTermProtection: '短期减少压力和羞耻，避免面对行动入口。',
      growthExplanation: '我确实有阻力，但可以先做一个小到不会压垮自己的真实动作。',
      selfIntegrityCard: '''我承认：这里存在价值与行为的不一致。
我不等于：这一次拖延或停滞。
我仍然重视：$values。
我下一步证明：先完成一个3分钟行动。''',
      minimumAction: '''行动名称：3分钟回到目标
步骤：打开相关页面/工具；计时3分钟；写一句完成事实
完成标准：留下一个可见记录
对应价值：$values''',
      correctiveAction: '''行动名称：修复价值—行为断裂
步骤：把目标降级成今天能做的一步
完成标准：完成后写入证据账本
对应价值：$values''',
      evidenceAction: '''行动名称：接触现实证据
步骤：查看一个最小事实或反馈，不再只靠想象判断
完成标准：写下看到的一个事实
对应价值：真实、责任''',
      minimumActionVariant: CcActionVariant(actionType: 'minimum', label: '最小行动', title: '3分钟回到目标', steps: const ['打开相关页面/工具', '计时3分钟', '写一句完成事实'], completionCriteria: '留下一个可见记录', linkedValue: values),
      correctiveActionVariant: CcActionVariant(actionType: 'corrective', label: '修正行动', title: '修复价值—行为断裂', steps: const ['把目标降级成今天能做的一步'], completionCriteria: '完成后写入证据账本', linkedValue: values),
      evidenceActionVariant: const CcActionVariant(actionType: 'evidence', label: '证据行动', title: '接触现实证据', steps: ['查看一个最小事实或反馈，不再只靠想象判断'], completionCriteria: '写下看到的一个事实', linkedValue: '真实、责任'),
      informationAvoidance: scene == 'information_avoidance' ? '最小接触行动：今天只查看一个数据、一个反馈或一个结果。' : '',
      identityConflict: scene == 'identity_conflict' ? '旧身份在保护安全感，新身份在召唤行动。今天只需要一个新身份小证据，不需要彻底推翻旧自己。' : '',
      informationAvoidanceBranches: scene == 'information_avoidance' ? const CcInformationAvoidanceBranches(avoidedInformation: '尚未结构化说明', fearedResult: '担心看到刺痛结果', smallestContactAction: '今天只查看一个数据、一个反馈或一个结果', betterThanExpected: '保留事实，不继续灾难化，把它写成现实证据。', worseThanExpected: '只处理一个最小修复动作，不把结果等同于整个人失败。', ambiguous: '补充一个低成本信息源，而不是回到逃避。', nextInformationAction: '写下看到的一个事实') : const CcInformationAvoidanceBranches(),
      identityDialogue: scene == 'identity_conflict' ? const CcIdentityDialogue(oldIdentity: '旧身份', oldIdentityVoice: '我先躲开，至少不会立刻失败。', oldIdentityProtection: '保护安全感、避免失败或羞耻', newIdentity: '新身份', newIdentityVoice: '我不需要彻底变强，只需要留下一个新证据。', fearOfLoss: '害怕失去安全感或旧解释', newIdentityAction: '今天做一个新身份小证据', postActionIdentitySentence: '我不是彻底变强了，但我已经给新身份留下一条真实证据。') : const CcIdentityDialogue(),
      dailyReviewSeed: '今天最接近价值的行动是什么？今天最明显的不一致是什么？明天重复一个最小行动。',
      provider: state['provider'] ?? 'local',
      modelLabel: state['label'] ?? '本地策略',
      rawResponse: '',
      usedFallback: true,
    );
  }

  Map<String, dynamic> _extractJsonObject(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return <String, dynamic>{};
    text = text.replaceAll(RegExp(r'^```json\s*', multiLine: true), '').replaceAll(RegExp(r'^```\s*', multiLine: true), '').replaceAll('```', '').trim();
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return <String, dynamic>{};
    try {
      return Map<String, dynamic>.from(jsonDecode(text.substring(start, end + 1)) as Map);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String _read(Map<String, dynamic> json, String key, String fallback) {
    final v = json[key];
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }



  int _readInt(Map<String, dynamic> json, String key, int fallback) {
    final v = json[key];
    if (v == null) return fallback;
    if (v is num) return v.round();
    return int.tryParse(v.toString().trim()) ?? fallback;
  }

  String _readDissonanceTypes(dynamic value, String fallback) {
    if (value is List) {
      final labels = <String>[];
      for (final item in value) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final label = (map['typeLabel'] ?? map['label'] ?? map['typeKey'] ?? map['type'] ?? '').toString().trim();
          if (label.isNotEmpty) labels.add(label);
        } else {
          final label = item.toString().trim();
          if (label.isNotEmpty) labels.add(label);
        }
      }
      return labels.isEmpty ? fallback : labels.join('、');
    }
    final s = (value ?? '').toString().trim();
    return s.isEmpty ? fallback : s;
  }

  bool _readBool(Map<String, dynamic> json, String key, bool fallback) {
    final v = json[key];
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().trim().toLowerCase();
    if (s == 'true' || s == 'yes' || s == '1' || s == '需要' || s == '是') return true;
    if (s == 'false' || s == 'no' || s == '0' || s == '不需要' || s == '否') return false;
    return fallback;
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _readList(Map<String, dynamic> json, String key, String fallback) {
    final v = json[key];
    if (v is List) {
      final items = v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList(growable: false);
      return items.isEmpty ? fallback : items.join('、');
    }
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }


  CcActionVariant _actionVariantFromMap(
    Map<String, dynamic> map, {
    required String actionType,
    required String label,
    required CcActionVariant fallback,
    required String fallbackText,
  }) {
    if (map.isEmpty) {
      return fallback.hasContent ? fallback : CcActionVariant(actionType: actionType, label: label, rawText: fallbackText);
    }
    final rawSteps = map['steps'];
    final steps = rawSteps is List
        ? rawSteps.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];
    final variant = CcActionVariant(
      actionType: actionType,
      label: label,
      title: _read(map, 'title', _read(map, 'name', '')),
      steps: steps,
      completionCriteria: _read(map, 'completionCriteria', _read(map, 'criteria', '')),
      linkedValue: _read(map, 'linkedValue', _read(map, 'value', '')),
      rawText: _stringifySection(map, ''),
    );
    return variant.hasContent ? variant : fallback;
  }

  CcInformationAvoidanceBranches _informationBranchesFromMap(
    Map<String, dynamic> map, {
    required CcInformationAvoidanceBranches fallback,
    required String fallbackText,
  }) {
    if (map.isEmpty) return fallback.hasContent ? fallback : CcInformationAvoidanceBranches(smallestContactAction: fallbackText);
    final branches = _asMap(map['branches']);
    final result = CcInformationAvoidanceBranches(
      avoidedInformation: _read(map, 'avoidedInformation', _read(map, 'avoidedInfo', fallback.avoidedInformation)),
      fearedResult: _read(map, 'fearedResult', fallback.fearedResult),
      smallestContactAction: _read(map, 'smallestContactAction', _read(map, 'smallestAction', fallback.smallestContactAction)),
      betterThanExpected: _read(map, 'betterThanExpected', _read(branches, 'betterThanExpected', fallback.betterThanExpected)),
      worseThanExpected: _read(map, 'worseThanExpected', _read(branches, 'worseThanExpected', fallback.worseThanExpected)),
      ambiguous: _read(map, 'ambiguous', _read(branches, 'ambiguous', fallback.ambiguous)),
      nextInformationAction: _read(map, 'nextInformationAction', fallback.nextInformationAction),
    );
    return result.hasContent ? result : fallback;
  }

  CcIdentityDialogue _identityDialogueFromMap(
    Map<String, dynamic> map, {
    required CcIdentityDialogue fallback,
    required String fallbackText,
  }) {
    if (map.isEmpty) return fallback.hasContent ? fallback : CcIdentityDialogue(newIdentityVoice: fallbackText);
    final result = CcIdentityDialogue(
      oldIdentity: _read(map, 'oldIdentity', fallback.oldIdentity),
      oldIdentityVoice: _read(map, 'oldIdentityVoice', fallback.oldIdentityVoice),
      oldIdentityProtection: _read(map, 'oldIdentityProtection', fallback.oldIdentityProtection),
      newIdentity: _read(map, 'newIdentity', fallback.newIdentity),
      newIdentityVoice: _read(map, 'newIdentityVoice', fallback.newIdentityVoice),
      fearOfLoss: _read(map, 'fearOfLoss', fallback.fearOfLoss),
      newIdentityAction: _read(map, 'newIdentityAction', fallback.newIdentityAction),
      postActionIdentitySentence: _read(map, 'postActionIdentitySentence', fallback.postActionIdentitySentence),
    );
    return result.hasContent ? result : fallback;
  }

  int _asDimensionScore(dynamic value) {
    if (value is num) return value.toInt().clamp(0, 3);
    final parsed = int.tryParse((value ?? '').toString().trim());
    return (parsed ?? 0).clamp(0, 3);
  }

  int _resolveIntensityTotal(Map<String, dynamic> intensity, int fallback) {
    final explicit = _readInt(intensity, 'totalScore', 0).clamp(0, 24).toInt();
    if (explicit > 0) return explicit;
    final summed = _asDimensionScore(intensity['freedomScore']) +
        _asDimensionScore(intensity['consequenceScore']) +
        _asDimensionScore(intensity['valueScore']) +
        _asDimensionScore(intensity['selfImageScore']) +
        _asDimensionScore(intensity['publicCommitmentScore']) +
        _asDimensionScore(intensity['investmentScore']) +
        _asDimensionScore(intensity['informationAvoidanceScore']) +
        _asDimensionScore(intensity['emotionScore']);
    if (summed > 0) return summed.clamp(0, 24).toInt();
    return fallback.clamp(0, 24).toInt();
  }

  String _normalizeIntensityLevel(String raw, int total) {
    final v = raw.trim();
    if (v.contains('深')) return '深层身份型';
    if (v.contains('高')) return '高';
    if (v.contains('中')) return '中';
    if (v.contains('低')) return '低';
    if (total >= 18) return '深层身份型';
    if (total >= 12) return '高';
    if (total >= 6) return '中';
    return total > 0 ? '低' : '';
  }

  String _stringifySection(Map<String, dynamic> section, String fallback) {
    if (section.isEmpty) return fallback;
    final lines = <String>[];
    section.forEach((key, value) {
      if (value == null) return;
      if (value is List) {
        final joined = value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).join('；');
        if (joined.isNotEmpty) lines.add('$key：$joined');
      } else if (value is Map) {
        final joined = value.entries.map((e) => '${e.key}=${e.value}').join('；');
        if (joined.trim().isNotEmpty) lines.add('$key：$joined');
      } else {
        final text = value.toString().trim();
        if (text.isNotEmpty) lines.add('$key：$text');
      }
    });
    return lines.isEmpty ? fallback : lines.join('\n');
  }

  String _normalizeReductionMode(String raw) {
    final v = raw.trim();
    const allowed = <String>{'explanation_only', 'action_repair', 'responsibility_repair', 'relationship_repair', 'value_alignment', 'avoidance_risk'};
    if (allowed.contains(v)) return v;
    if (v.contains('行动')) return 'action_repair';
    if (v.contains('责任')) return 'responsibility_repair';
    if (v.contains('关系')) return 'relationship_repair';
    if (v.contains('价值')) return 'value_alignment';
    if (v.contains('逃避')) return 'avoidance_risk';
    return 'explanation_only';
  }

  String _normalizeCategory(String raw) {
    const allowed = <String>{'start', 'courage', 'learning', 'responsibility', 'recovery', 'discomfort', 'review', 'information', 'identity'};
    final v = raw.trim().toLowerCase();
    return allowed.contains(v) ? v : 'start';
  }

  String _nonEmpty(String value, String fallback) => value.trim().isEmpty ? fallback : value.trim();

  String _today() => DateTime.now().toIso8601String().substring(0, 10);
}
