import 'dart:convert';

import '../services/global_ai_settings.dart';
import '../services/unified_ai_service.dart';
import 'realistic_optimism_training_models.dart';
import 'realistic_optimism_training_prompt_config.dart';

class RealisticOptimismTrainingAiResult {
  final RealisticOptimismTrainingRecord record;
  final bool fromFallback;
  const RealisticOptimismTrainingAiResult({required this.record, required this.fromFallback});
}



class RealisticOptimismTrainingOutputValidator {
  static const Set<String> _actionPrimaryScenes = <String>{
    'event_reframe',
    'process_action',
    'process_simulation_check',
    'same_reality_interpretations',
    'loss_resource_retention',
    'failure_immunity',
    'controlled_failure_challenge',
    'psychological_immunity_experiment',
    'todo_goal_bridge',
    'daily_review',
    'core_business_session',
  };

  static const Set<String> _primePrimaryScenes = <String>{
    'prime_design',
    'anti_prime_cleanup',
    'proactive_reminder',
    'priming_diagnostic',
    'identity_script_activation',
    'daily_review',
    'event_reframe',
  };

  static const Set<String> _identityPrimaryScenes = <String>{
    'identity_evidence',
    'event_reframe',
    'failure_immunity',
    'controlled_failure_challenge',
    'gratitude_savoring',
    'reality_record',
    'complete_reality',
    'appreciation_scan',
    'gratitude_time_in',
    'daily_review',
    'process_action',
    'todo_goal_bridge',
  };

  static const Set<String> _gratitudePrimaryScenes = <String>{
    'gratitude_savoring',
    'complete_reality',
    'appreciation_scan',
    'gratitude_time_in',
    'daily_review',
  };

  static const Set<String> _p2Scenes = <String>{
    'todo_goal_bridge',
    'daily_review',
    'course_card',
    'role_model_case',
    'proactive_reminder',
    'monthly_report',
    'complete_reality',
    'appreciation_scan',
    'same_reality_interpretations',
    'loss_resource_retention',
    'priming_diagnostic',
    'identity_script_activation',
    'gratitude_time_in',
    'process_simulation_check',
    'psychological_immunity_experiment',
  };

  bool _hasNonEmptyList(Map<String, dynamic> payload, String mapKey, String listKey) {
    final raw = payload[mapKey];
    if (raw is! Map) return false;
    final list = raw[listKey];
    return list is List && list.any((e) => e.toString().trim().isNotEmpty);
  }

  bool _hasText(Map<String, dynamic> payload, String mapKey, String fieldKey, {int min = 1}) {
    final raw = payload[mapKey];
    if (raw is! Map) return false;
    return (raw[fieldKey] ?? '').toString().trim().length >= min;
  }

  RealisticOptimismTrainingValidationReport validate(RealisticOptimismTrainingRecord record, {required String scene}) {
    final issues = <String>[];
    final payload = record.payload;
    final coreRef = payload['core_value_reference'];
    if (coreRef is! Map || (coreRef['source_anchor'] ?? '').toString().trim().isEmpty) {
      issues.add('缺少 core_value_reference.source_anchor，无法追溯到核心价值/研究锚点。');
    }
    if (!<String>{'L1', 'L2', 'L3', 'L4'}.contains(record.intensityLevel)) {
      issues.add('强度分级必须为 L1/L2/L3/L4。');
    }
    final isSafetyRouted = record.intensityLevel == 'L3' || record.intensityLevel == 'L4';
    if (record.validationText.trim().length < 16) {
      issues.add('情绪允许说明太短，容易变成机械安慰。');
    }

    if (isSafetyRouted) {
      if (record.balancedInterpretation.contains('好事') || record.finalUserMessage.contains('一切都会好')) {
        issues.add('L3/L4 不应强行资源发现、意义化或积极化。');
      }
      if (record.allowedInterventions.isEmpty || record.blockedInterventions.isEmpty) {
        issues.add('L3/L4 需要明确适合/不适合的干预。');
      }
      return RealisticOptimismTrainingValidationReport(
        ok: issues.isEmpty,
        issues: issues,
        repairNote: issues.isEmpty ? '' : issues.join('；'),
      );
    }

    final needsFacts = scene == 'event_reframe' || scene == 'explanation_radar' || scene == 'dual_lens' || scene == 'failure_immunity' || scene == 'todo_goal_bridge' || scene == 'same_reality_interpretations' || scene == 'loss_resource_retention' || scene == 'psychological_immunity_experiment';
    if (needsFacts && record.objectiveFacts.isEmpty) {
      issues.add('本场景缺少事实层，无法体现事实/解释分离。');
    }
    if ((scene == 'event_reframe' || scene == 'explanation_radar' || scene == 'dual_lens') && record.automaticInterpretation.trim().isEmpty) {
      issues.add('本场景缺少自动解释，无法分析解释风格。');
    }
    if ((scene == 'event_reframe' || scene == 'dual_lens') && record.balancedInterpretation.trim().length < 24) {
      issues.add('资源发现视角 重构太短，未充分承认痛苦并找回可控点。');
    }
    if (_actionPrimaryScenes.contains(scene) && record.fiveMinuteAction.trim().length < 8) {
      issues.add('本场景需要一个具体的 5 分钟行动。');
    }
    if ((scene == 'process_action' || scene == 'todo_goal_bridge' || scene == 'process_simulation_check') && record.ifThenPlan.isEmpty) {
      issues.add('过程行动/待办事项联动场景需要 如果-那么 过程预演。');
    }
    if ((scene == 'failure_immunity' || scene == 'controlled_failure_challenge' || scene == 'psychological_immunity_experiment') && record.psychologicalAntibody.trim().isEmpty) {
      issues.add('失败免疫场景需要提炼心理抗体。');
    }
    if (_gratitudePrimaryScenes.contains(scene) && record.whatStillMatters.isEmpty && record.savoringPrompt.trim().isEmpty) {
      issues.add('感恩/晚间复盘场景需要具体感恩或品味提示。');
    }
    if (_primePrimaryScenes.contains(scene) && record.lockScreenSentence.trim().isEmpty && record.antiPrimeCleanupAction.trim().isEmpty) {
      issues.add('环境场景需要 注意力启动线索 或 消极启动源 的可执行线索。');
    }
    if (_identityPrimaryScenes.contains(scene) && record.identitySentence.trim().isEmpty) {
      issues.add('本场景需要基于证据的身份沉淀。');
    }
    if (_p2Scenes.contains(scene)) {
      final hasP2Summary = _hasText(payload, 'p2_delivery', 'summary', min: 8) || _hasText(payload, 'p2_delivery', 'next_action', min: 4) || _hasNonEmptyList(payload, 'p2_delivery', 'sections');
      if (!hasP2Summary) issues.add('日常实践场景需要摘要、区块或下一步动作，并且要服务解释、行动、注意或感恩主线。');
    }
    return RealisticOptimismTrainingValidationReport(
      ok: issues.isEmpty,
      issues: issues,
      repairNote: issues.isEmpty ? '' : issues.join('；'),
    );
  }
}

class RealisticOptimismTrainingAiService {
  final GlobalAiSettings _settings = GlobalAiSettings();
  final UnifiedAiService _ai = UnifiedAiService();
  final RealisticOptimismTrainingPromptConfig _prompts = RealisticOptimismTrainingPromptConfig();
  final RealisticOptimismTrainingOutputValidator _validator = RealisticOptimismTrainingOutputValidator();

  Future<Map<String, String>> aiState() async {
    try {
      return await _settings.getState();
    } catch (_) {
      return <String, String>{'provider': 'none', 'model': 'none', 'label': '未配置（将使用内置策略）', 'available': '0'};
    }
  }



  bool _minimalRecordOk(RealisticOptimismTrainingRecord record, String scene) {
    if (record.validationText.trim().isEmpty) return false;
    if (record.intensityLevel == 'L3' || record.intensityLevel == 'L4') return true;
    switch (scene) {
      case 'reality_record':
        return record.rawInput.trim().isNotEmpty && record.fiveMinuteAction.trim().isNotEmpty;
      case 'intensity_check':
      case 'emotion_container':
        return record.intensityLevel.isNotEmpty;
      case 'prime_design':
      case 'anti_prime_cleanup':
      case 'proactive_reminder':
        return record.lockScreenSentence.trim().isNotEmpty || record.antiPrimeCleanupAction.trim().isNotEmpty;
      case 'gratitude_savoring':
      case 'complete_reality':
      case 'appreciation_scan':
      case 'gratitude_time_in':
      case 'daily_review':
        return record.whatStillMatters.isNotEmpty || record.savoringPrompt.trim().isNotEmpty || record.fiveMinuteAction.trim().isNotEmpty;
      case 'failure_immunity':
      case 'controlled_failure_challenge':
      case 'psychological_immunity_experiment':
        return record.psychologicalAntibody.trim().isNotEmpty || record.fiveMinuteAction.trim().isNotEmpty;
      case 'todo_goal_bridge':
      case 'process_action':
      case 'process_simulation_check':
      case 'same_reality_interpretations':
      case 'loss_resource_retention':
        return record.fiveMinuteAction.trim().isNotEmpty || record.ifThenPlan.isNotEmpty;
      case 'course_card':
      case 'role_model_case':
      case 'priming_diagnostic':
      case 'identity_script_activation':
      case 'monthly_report':
        final p2 = record.payload['p2_delivery'];
        if (p2 is Map && ((p2['summary'] ?? '').toString().trim().isNotEmpty || (p2['next_action'] ?? '').toString().trim().isNotEmpty)) return true;
        return record.finalUserMessage.trim().isNotEmpty;
      case 'event_reframe':
      case 'dual_lens':
      case 'explanation_radar':
      default:
        return record.fiveMinuteAction.trim().isNotEmpty || record.balancedInterpretation.trim().isNotEmpty;
    }
  }
  Future<RealisticOptimismTrainingAiResult> generate({
    required String userInput,
    String scene = 'event_reframe',
    String extraContext = '',
  }) async {
    final state = await aiState();
    final available = (state['available'] ?? '0') == '1';
    if (available) {
      final scenePrompt = await _prompts.buildScenePrompt(userInput: userInput, scene: scene, extraContext: extraContext);
      final outputPrompt = await _prompts.getRuntimeOutputPrompt();
      final systemPrompt = await _prompts.getRuntimeGlobalPrompt();
      final prompt = '【全局价值层背景：必须遵守】\n$systemPrompt\n\n【当前场景任务】\n$scenePrompt\n\n【输出格式与详细度要求】\n$outputPrompt';
      try {
        final raw = await _ai.generateText(
          prompt: prompt,
          purpose: 'realistic_optimism_training.$scene',
          systemPrompt: systemPrompt,
          maxTokens: 5200,
          expectJson: true,
          temperature: 0.3,
        );
        final parsed = _parseJson(raw);
        if (parsed != null) {
          final now = DateTime.now().millisecondsSinceEpoch;
          parsed['raw_input'] = userInput;
          parsed['scene'] = parsed['scene'] ?? scene;
          parsed['provider'] = state['provider'] ?? 'ai';
          parsed['model_label'] = state['label'] ?? '统一 AI';
          parsed['created_at_ms'] = parsed['created_at_ms'] ?? now;
          parsed['updated_at_ms'] = now;
          _applySafetyRouting(parsed, userInput: userInput);
          final record = RealisticOptimismTrainingRecord.fromJson(parsed);
          final report = _validator.validate(record, scene: scene);
          final minimalOk = _minimalRecordOk(record, scene);
          if (minimalOk && report.issues.length <= 2) {
            if (!report.ok) {
              parsed['validation_repair_note'] = report.repairNote;
              return RealisticOptimismTrainingAiResult(record: RealisticOptimismTrainingRecord.fromJson(parsed), fromFallback: false);
            }
            return RealisticOptimismTrainingAiResult(record: record, fromFallback: false);
          }
        }
      } catch (_) {}
    }
    return RealisticOptimismTrainingAiResult(
      record: _fallback(userInput: userInput, scene: scene, modelLabel: state['label'] ?? '内置策略'),
      fromFallback: true,
    );
  }

  Map<String, dynamic>? _parseJson(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    if (text.startsWith('```')) {
      text = text.replaceAll(RegExp(r'^```json\s*', multiLine: true), '').replaceAll(RegExp(r'^```\s*', multiLine: true), '').replaceAll('```', '').trim();
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) text = text.substring(start, end + 1);
    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  }

  RealisticOptimismTrainingRecord _fallback({required String userInput, required String scene, required String modelLabel}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final text = userInput.trim().isEmpty ? '今天发生了一件让我不舒服的事，我想重新看清它。' : userInput.trim();
    final level = _guessLevel(text);
    final emotion = _guessEmotion(text);
    final hasFailure = text.contains('失败') || text.contains('没') || text.contains('拖延') || text.contains('坚持不了') || text.contains('又');
    final hasForever = text.contains('永远') || text.contains('一直') || text.contains('彻底') || text.contains('完了') || text.contains('废');
    final hasSelfAttack = text.contains('我不行') || text.contains('很差') || text.contains('废') || text.contains('没用');
    final action = _guessAction(text);
    final payload = <String, dynamic>{
      'module': 'realistic_optimism_training',
      'scene': scene,
      'id': 'rot_${now}_${text.hashCode.abs()}',
      'raw_input': text,
      'core_value_reference': <String, dynamic>{
        'source_anchor': hasFailure ? 'Lecture 7 心理免疫系统 + Tal 失败故事' : hasForever ? 'Lecture 7 同一现实，不同解释' : 'Bandura 自我效能 + 行动证据',
        'how_it_applies': hasFailure
            ? '本次重点不是美化失败，而是把失败变成复盘、恢复和下一步行动的材料。'
            : hasForever
                ? '本次重点是把永久化、普遍化解释拉回暂时、特定、可调整的现实比例。'
                : '本次重点是先看清事实与解释，再用一个小行动创造新证据。',
      },
      'intensity_check': <String, dynamic>{
        'level': level,
        'reason': level == 'L4'
            ? '输入中可能包含强烈危险信号，当前应优先安全支持。'
            : level == 'L3'
                ? '事件可能处于高强度痛苦或创伤状态，不适合强行积极化。'
                : level == 'L2'
                    ? '事件带有明显自责、失败或关系压力，适合先承认情绪再温和重构。'
                    : '当前更像轻度挫折或日常阻碍，可以进入完整训练闭环。',
        'allowed_intervention': level == 'L3' || level == 'L4'
            ? <String>['情绪稳定', '现实支持', '事实澄清', '小范围安全行动']
            : <String>['情绪允许', '事实-解释分离', '资源发现视角 重构', '5分钟微行动', '行动证据记录'],
        'blocked_intervention': level == 'L3' || level == 'L4'
            ? <String>['强行感恩', '强行寻找好处', '把痛苦解释成必然有意义']
            : <String>['空泛鸡汤', '否认痛苦', '用宏大计划替代第一步'],
      },
      'user_event_summary': text,
      'emotion_validation': <String, dynamic>{
        'primary_emotion': emotion,
        'validation_text': '你现在的$emotion是可以理解的。它不是人格失败，而是说明这件事对你有影响。我们不急着把它说成好事，先看清事实、解释和一个可控点。',
      },
      'fact_layer': <String, dynamic>{
        'objective_facts': <String>['你描述了一个让自己受到影响的事件或目标阻碍。', if (hasFailure) '其中包含失败、没完成、拖延或坚持中断的经验。'],
        'unknowns_or_assumptions': <String>['这件事是否真的代表长期趋势仍需更多证据。', '他人评价、未来结果和长期能力不能只由一次事件推出。'],
      },
      'interpretation_style': <String, dynamic>{
        'automatic_interpretation': _guessInterpretation(text),
        'permanence_score': hasForever ? 8 : 4,
        'pervasiveness_score': hasForever ? 7 : 4,
        'personalization_score': hasSelfAttack ? 8 : 5,
        'catastrophizing_score': text.contains('完') || text.contains('肯定') ? 8 : 4,
        'helplessness_score': text.contains('没办法') || text.contains('无法') ? 8 : 4,
        'filtering_score': hasFailure ? 7 : 4,
        'main_pattern': hasSelfAttack ? '人格化 + 永久化' : hasForever ? '永久化 + 普遍化' : '过滤化 + 无力化',
      },
      'fault_finder_layer': <String, dynamic>{
        'fault_finder_story': '问题放大视角 会把这件事讲成：这次不顺利说明我整个人不行，未来也很难改变，所以现在行动也没有意义。',
        'likely_emotional_effect': '更强的羞耻、自责、焦虑或无力感。',
        'likely_behavioral_effect': '更容易拖延、逃避、放弃复盘，或者用自我攻击代替调整系统。',
      },
      'benefit_finder_layer': <String, dynamic>{
        'balanced_interpretation': '这件事确实不舒服，也可能暴露了现实问题；但它不是全部现实。更现实的看法是：它提供了一个反馈，说明当前方法、环境、行动门槛或恢复方式需要调整。',
        'not_denied_pain': '痛苦、失望和自责都被承认，不需要假装没事。',
        'possible_learning': <String>['识别这次卡住的具体条件。', '把“我不行”改成“这个方法需要调整”。', '用小行动制造新证据。'],
        'remaining_resources': <String>['现在仍然可以做一个很小动作。', '你已经愿意把问题写出来。', '可以记录、复盘和调整。'],
        'possible_meaning': <String>['这次事件可以训练你：痛苦存在时仍然找一个可控点。'],
      },
      'agency_layer': <String, dynamic>{
        'uncontrollable_parts': <String>['过去已经发生的部分。', '短期内无法保证结果。', '他人的全部评价。'],
        'influenceable_parts': <String>['准备方式', '行动环境', '复盘方式', '下一次尝试的门槛'],
        'controllable_actions': <String>[action, '写下一个事实和一个解释。', '移除一个最强干扰。'],
      },
      'process_action_plan': <String, dynamic>{
        'five_minute_action': action,
        'next_three_steps': <String>['打开相关材料或记录页。', '只完成最小一步，不评价结果。', '完成后写一句“我用行动证明了什么”。'],
        'if_then_plan': <String>['如果想逃避，就把行动缩小到1分钟。', '如果开始自责，就先写一句事实，不写评价。', '如果被手机干扰，就把它放到2米外。'],
      },
      'failure_immunity': <String, dynamic>{
        'predicted_pain': null,
        'actual_pain': null,
        'predicted_recovery': '行动前可以预测：如果失败，我会痛苦多久？',
        'actual_recovery': '行动后再记录：实际多久开始恢复？',
        'worst_case_prediction': '我担心最坏会发生什么？它的概率和可恢复性分别是多少？',
        'actual_result': '行动后再记录真实发生的结果，而不是只记录脑中的灾难预测。',
        'psychological_antibody': '失败会痛，但它不必定义我；我可以从一次小复盘中恢复一点主动性。',
      },
      'controlled_failure_challenge': <String, dynamic>{
        'challenge_name': '低风险不完美挑战',
        'risk_level': 'low',
        'safety_boundary': '不危险、不造成重大现实损失、可恢复、可复盘。',
        'execution_steps': <String>['选择一个低风险场景。', '只暴露一个很小的不完美。', '完成后记录预测与实际差异。'],
        'pre_failure_questions': <String>['我预测痛苦几分？', '我预测多久恢复？', '我最担心别人怎么看？'],
        'post_failure_questions': <String>['实际痛苦几分？', '实际多久恢复？', '最坏结果真的发生了吗？'],
        'possible_antibody': '我可以在低风险练习里训练承受不完美。',
      },
      'gratitude_or_savoring': <String, dynamic>{
        'what_still_matters': <String>['我仍然有重新开始的一个小入口。', '我愿意面对而不是完全逃开。', '今天仍然有某个值得停留的具体时刻。'],
        'savoring_prompt': '停留30秒，回忆今天一个没有那么糟的小画面：光线、声音、身体感受或一个具体动作。',
        'small_appreciation_action': '写下一件今天仍值得珍惜的小事，不要抽象，具体到画面或动作。',
      },
      'relationship_gratitude': <String, dynamic>{
        'person': '',
        'context': '',
        'light_text': '',
        'concrete_text': '',
        'deep_text': '',
        'chosen_action': '',
      },
      'reality_record': <String, dynamic>{
        'what_happened': text,
        'what_is_truly_bad': hasFailure ? '这件事里确实有没完成、失败、拖延或受挫的部分，不需要被美化。' : '这件事确实让人不舒服，不需要被立刻说成好事。',
        'not_to_be_beautified': '不要把它说成“一切都是最好的安排”。坏的部分先被承认。',
        'allowed_emotion': emotion,
        'body_signal': '身体紧绷、想逃避或低能量都可以先被允许存在。',
        'pain_interpretation': _guessInterpretation(text),
        'what_still_exists': <String>['这件事不是全部现实。', '现在仍然可以做一个很小动作。', '记录本身已经说明用户没有完全放弃。'],
        'controllable_point': action,
        'courage_action': action,
        'complete_reality_sentence': '这件事确实让我痛，也有不好的部分；但它不是我全部的现实。我仍然能带着难受，先做一个小行动。',
      },
      'complete_reality': <String, dynamic>{},
      'appreciation_scan': <String, dynamic>{},
      'same_reality_interpretations': <String, dynamic>{},
      'loss_resource_retention': <String, dynamic>{},
      'priming_diagnostic': <String, dynamic>{},
      'identity_script_activation': <String, dynamic>{},
      'gratitude_time_in': <String, dynamic>{},
      'process_simulation_check': <String, dynamic>{},
      'psychological_immunity_experiment': <String, dynamic>{},
      'prime': <String, dynamic>{
        'daily_value_word': '行动证据',
        'lock_screen_sentence': '我可以痛苦，也可以先做一个小动作。',
        'benefit_finder_question': '这件事里，我还剩下哪一个可控点？',
        'anti_prime_cleanup_action': '把最容易让我拖延或比较的入口从手机首页移走。',
      },
      'p2_delivery': <String, dynamic>{
        'artifact_type': scene,
        'title': '',
        'trigger_condition': '',
        'summary': '',
        'sections': <String>[],
        'next_action': '',
        'reuse_surface': '',
      },
      'identity_evidence': <String, dynamic>{
        'specific_action': action,
        'proved_capacity': '在状态并不完美时，仍然愿意用小行动收集新证据。',
        'identity_type': '行动证据积累者',
        'identity_sentence': '我正在成为一个不靠幻想，而靠小行动重新建立信心的人。',
      },
      'final_user_message': '今天不需要证明你彻底改变，只需要完成一个小到可以开始的行动证据。',
      'provider': 'local',
      'model_label': modelLabel.isEmpty ? '内置策略' : modelLabel,
      'created_at_ms': now,
      'updated_at_ms': now,
    };
    _applySceneFallback(payload, scene, text, action);
    _applySafetyRouting(payload, userInput: text);
    return RealisticOptimismTrainingRecord.fromJson(payload);
  }

  void _applySceneFallback(Map<String, dynamic> payload, String scene, String text, String action) {
    Map<String, dynamic> map(String key) => payload[key] as Map<String, dynamic>;
    switch (scene) {
      case 'reality_record':
        map('core_value_reference')['source_anchor'] = 'Lecture 7–9：先真实，再乐观 + Bandura 自我效能 + 祖母故事';
        map('core_value_reference')['how_it_applies'] = '本次先记录现实和坏的部分，再承认情绪、识别痛苦解释、补全现实，并把乐观落到一个勇气出马动作。';
        map('benefit_finder_layer')['not_denied_pain'] = map('reality_record')['what_is_truly_bad'];
        map('benefit_finder_layer')['balanced_interpretation'] = map('reality_record')['complete_reality_sentence'];
        map('process_action_plan')['five_minute_action'] = map('reality_record')['courage_action'];
        map('identity_evidence')['identity_type'] = '现实主义出马者';
        map('identity_evidence')['identity_sentence'] = '我正在成为一个能承认现实中的坏，也不因此放弃行动的人。';
        payload['final_user_message'] = map('reality_record')['complete_reality_sentence'];
        break;
      case 'intensity_check':
        payload['final_user_message'] = '当前先完成强度分级：只做当前等级适合做的事，不把所有痛苦强行积极化。';
        break;
      case 'emotion_container':
        map('benefit_finder_layer')['balanced_interpretation'] = '现在最重要的不是立刻积极，而是先允许情绪存在。痛苦说明这件事对你有影响，不说明你这个人失败。';
        map('process_action_plan')['five_minute_action'] = '先暂停30秒，命名一个情绪和一个身体感受，再写下一个客观事实。';
        map('identity_evidence')['identity_type'] = '允许自己为人的练习者';
        map('identity_evidence')['identity_sentence'] = '我正在成为一个能承认痛苦，而不被痛苦完全定义的人。';
        payload['final_user_message'] = '先不急着找好处；允许自己为人，就是这一步的训练。';
        break;
      case 'explanation_radar':
        payload['final_user_message'] = '这次重点不是马上解决全部问题，而是看清自动解释中的永久化、普遍化、人格化、灾难化、无力化和过滤化。';
        break;
      case 'dual_lens':
        payload['final_user_message'] = '同一现实可以有两种镜头：问题放大视角 让你失去行动力，资源发现视角 帮你承认痛苦后找回一个可控点。';
        break;
      case 'process_action':
        map('core_value_reference')['source_anchor'] = 'Lecture 7 过程模拟优于结果幻想 + Bandura 自我效能';
        map('core_value_reference')['how_it_applies'] = '本次遵循过程模拟研究：不只想象结果，而是把目标拆成时间、地点、工具、第一步、障碍预演、如果-那么 和 5 分钟启动。';
        map('benefit_finder_layer')['balanced_interpretation'] = '这个目标现在不需要靠结果幻想来推进。更现实的方式是把成功画面压缩成一个今天能开始的过程动作，让自信来自行动证据。';
        map('agency_layer')['uncontrollable_parts'] = <String>['今天是否马上有动力。', '最终结果是否一次就完美。', '过去已经拖延的时间。'];
        map('agency_layer')['influenceable_parts'] = <String>['开始时间', '手机距离', '任务大小', '完成标准'];
        map('agency_layer')['controllable_actions'] = <String>['把目标缩小到 5 分钟。', '先打开工具或材料。', '写下一个 如果-那么 应对。'];
        map('process_action_plan')['five_minute_action'] = action.isEmpty ? '现在打开目标相关的文件/材料，只做 5 分钟，完成标准是留下一个可见痕迹。' : action;
        map('process_action_plan')['next_three_steps'] = <String>['确定具体时间和地点。', '打开工具/材料，只做第一步。', '完成后记录一句行动证据。'];
        map('process_action_plan')['if_then_plan'] = <String>['如果想等状态变好，那么先把计时器设为 5 分钟。', '如果怕做不好，那么只产出草稿，不要求质量。', '如果想刷手机，那么把手机放到看不见的位置再开始。'];
        map('failure_immunity')['psychological_antibody'] = '';
        map('gratitude_or_savoring')['savoring_prompt'] = '';
        map('prime')['anti_prime_cleanup_action'] = '把最强干扰源从启动环境中移开 5 分钟。';
        map('identity_evidence')['identity_type'] = '行动证据积累者';
        map('identity_evidence')['identity_sentence'] = '我正在成为一个不等动力变好，也能用小过程开始的人。';
        payload['final_user_message'] = '本次重点是过程模拟：不要先追求完成全部，先用 5 分钟动作制造一条行动证据。';
        break;
      case 'failure_immunity':
        map('core_value_reference')['source_anchor'] = 'Lecture 7 心理免疫系统 + Tal 失败故事';
        map('core_value_reference')['how_it_applies'] = '本次不美化失败，而是把失败或害怕失败拆成预测痛苦、实际结果、恢复时间、承受住的部分和下次更小行动。';
        map('benefit_finder_layer')['balanced_interpretation'] = '失败确实会痛，也可能暴露准备、方法或环境问题；但失败不是人格判决。像心理免疫系统一样，它可以成为下一次调整方法、承受失败并重新行动的复盘材料。';
        map('failure_immunity')['predicted_pain'] = 8;
        map('failure_immunity')['actual_pain'] = null;
        map('failure_immunity')['predicted_recovery'] = '先记录预测：如果失败，我以为自己会难受多久、会被谁怎样看、最坏结果是什么。';
        map('failure_immunity')['actual_recovery'] = '如果实际结果已经发生，再补录：实际痛苦几分、多久恢复、最坏结果是否真的发生。';
        map('failure_immunity')['worst_case_prediction'] = text;
        map('failure_immunity')['actual_result'] = '等待用户在失败后复盘中补录真实结果。';
        map('failure_immunity')['psychological_antibody'] = '一次失败不会自动等于人格失败；我可以用复盘、恢复和下次更小行动训练心理抗体。';
        map('process_action_plan')['five_minute_action'] = '写下这次失败的一个具体环节、一个可调整点、一个下次 5 分钟行动。';
        map('process_action_plan')['next_three_steps'] = <String>['记录失败前最坏预测。', '补录实际发生和恢复时间。', '为下次设计一个更小行动。'];
        map('identity_evidence')['identity_type'] = '失败后恢复者';
        map('identity_evidence')['identity_sentence'] = '我正在成为一个失败后不急着否定自己，而会复盘、恢复、再行动的人。';
        payload['final_user_message'] = '本次重点是失败免疫：失败先被承认，再被复盘，最后转成下次更小、更稳的行动。';
        break;
      case 'controlled_failure_challenge':
        map('process_action_plan')['five_minute_action'] = '设计并写下一个低风险挑战：它可能被拒绝或不完美，但不会造成重大损失。';
        map('failure_immunity')['predicted_recovery'] = '挑战前预测：如果不完美或被拒绝，我预计多久恢复？';
        map('failure_immunity')['psychological_antibody'] = '我可以在低风险暴露中练习承受不完美，而不是等重大失败发生。';
        map('identity_evidence')['identity_type'] = '失败后恢复者';
        map('identity_evidence')['identity_sentence'] = '我正在成为一个能主动训练心理免疫，而不是只逃避失败的人。';
        payload['final_user_message'] = '安全边界：挑战必须低风险、可恢复、不伤害自己或他人，不造成重大现实损失。';
        break;
      case 'prime_design':
        map('prime')['daily_value_word'] = '行动证据';
        map('prime')['lock_screen_sentence'] = '注意会塑造现实；今天先把注意力放回一个可控点。';
        map('prime')['benefit_finder_question'] = '今天我要主动寻找哪一个仍然存在的资源？';
        payload['final_user_message'] = '今天的目标不是靠意志硬撑，而是用环境线索提醒自己：注意力会塑造现实，先回到一个可控行动。';
        break;
      case 'anti_prime_cleanup':
        map('prime')['anti_prime_cleanup_action'] = '从首页移走一个最容易触发拖延、比较或无力感的入口，并用一句现实提醒替换。';
        payload['final_user_message'] = '不是一次性改变全部环境，只清理一个最强 消极启动源。';
        break;
      case 'gratitude_savoring':
        map('gratitude_or_savoring')['savoring_prompt'] = '选择今天一个微小的好体验，停留30秒：画面是什么、身体哪里放松、它为什么值得被记住？';
        map('gratitude_or_savoring')['small_appreciation_action'] = '写一句具体感谢，或对一个人表达“那件事对我很重要”。';
        map('relationship_gratitude')['person'] = '一个值得感谢的人';
        map('relationship_gratitude')['context'] = text;
        map('relationship_gratitude')['light_text'] = '今天想到你之前帮我的那件事，还是想说谢谢。';
        map('relationship_gratitude')['concrete_text'] = '那次你愿意支持我，这对我很重要。谢谢你。';
        map('relationship_gratitude')['deep_text'] = '我以前可能没有认真表达过，但你的支持让我感到被看见。我想让你知道，我没有忘记。';
        map('relationship_gratitude')['chosen_action'] = '可以发送、保存不发，或设为稍后表达。';
        map('identity_evidence')['identity_type'] = '感恩与珍惜者';
        map('identity_evidence')['identity_sentence'] = '我正在成为一个不让好的东西被习惯性忽略的人。';
        break;
      case 'complete_reality':
        map('core_value_reference')['source_anchor'] = 'Lecture 9 祖母故事 + 感恩是完整现实感';
        map('core_value_reference')['how_it_applies'] = '本次不是写积极日记，而是把“不否认的痛苦”和“仍然存在的美/善/关系”放在同一个现实里。';
        map('complete_reality')
          ..['pain_not_denied'] = text
          ..['not_beautified'] = '这件事不需要被轻飘飘地美化；痛苦、失去或不公平都可以被如实承认。'
          ..['still_here'] = <String>['我仍然有一个可以呼吸和停顿的当下。', '仍然可能存在一个人、一件小事或一个资源没有被这件事带走。', '我仍可以选择一个很小的珍惜动作。']
          ..['if_lost_tomorrow'] = '如果明天失去其中一个仍然存在的东西，我可能会后悔今天完全没有看见它。'
          ..['appreciation_action'] = '今天具体珍惜一次：停留 30 秒看见它，或对相关的人说一句具体感谢。'
          ..['complete_reality_sentence'] = '这件事真的很痛，但它不是我全部的现实；今天我仍然看见一个还在的好。';
        map('benefit_finder_layer')['not_denied_pain'] = '痛苦没有被否认，也没有被包装成好事。';
        map('gratitude_or_savoring')['what_still_matters'] = <String>['一个仍然在的人/关系/身体能力/时间窗口。', '一个还可以重新开始的小入口。', '一个今天没有被夺走的具体画面。'];
        map('gratitude_or_savoring')['savoring_prompt'] = '停留 30 秒：看见这个仍然存在的好，记录画面、声音或身体感受。';
        map('gratitude_or_savoring')['small_appreciation_action'] = '写下或表达一句：我没有把这件具体的好当成理所当然。';
        payload['final_user_message'] = '完整现实不是强行开心，而是：痛是真的，仍然存在的好也是真的。';
        break;
      case 'appreciation_scan':
        map('core_value_reference')['source_anchor'] = 'Lecture 9 不被珍惜的东西，会在心理上贬值';
        map('appreciation_scan')
          ..['currently_taken_for_granted'] = <String>['一个一直在但很少被认真看见的人。', '一个身体能力或生活条件。', '一个每天出现的小方便或小善意。']
          ..['if_lost_tomorrow'] = '如果明天失去它，我可能会发现自己以前把它看得太轻。'
          ..['why_depreciating'] = '习惯会让好东西在心理上贬值；不珍惜不代表它不重要，只代表注意力没有停留。'
          ..['today_appreciation_action'] = '今天对其中一个对象做一次具体珍惜：说谢谢、拍照保存、认真使用、或停留 30 秒。'
          ..['reminder_sentence'] = '不等到失去，我现在就练习看见。';
        map('gratitude_or_savoring')['what_still_matters'] = <String>['我正在习以为常但其实重要的东西。', '如果失去会后悔没有珍惜的关系或条件。', '今天可以用一个小动作表达珍惜的对象。'];
        map('gratitude_or_savoring')['small_appreciation_action'] = '选择一个正在被习惯化的好，今天做一次具体珍惜动作。';
        payload['final_user_message'] = '这一步训练的不是礼貌，而是防止重要的东西在注意力里贬值。';
        break;
      case 'same_reality_interpretations':
        map('core_value_reference')['source_anchor'] = 'Lecture 7 Tal 失败故事：same reality, different interpretations';
        map('same_reality_interpretations')
          ..['facts'] = <String>['事实：$text', '这件事带来了情绪反应。', '一次事件还不足以证明整个人生结论。']
          ..['current_interpretation'] = _guessInterpretation(text)
          ..['action_if_believed'] = '如果完全相信这个痛苦解释，我可能会逃避、放弃或继续自我攻击。'
          ..['tal_alternative_questions'] = <String>['这件事是否可能让我多出某种时间或空间？', '它是否可能迫使我补一块基础？', '它是否可能让我更谦卑、更稳、更能帮助未来的自己？']
          ..['more_complete_interpretation'] = '同一现实不变，但解释可以更完整：这件事很痛，也可能暴露了一个可训练环节，而不是证明我整个人失败。'
          ..['first_action'] = action;
        map('benefit_finder_layer')['balanced_interpretation'] = '同一现实可以有不同解释。现在不要求相信最好版本，只先从“终局判决”退回“具体反馈”。';
        map('process_action_plan')['five_minute_action'] = action;
        payload['final_user_message'] = '事实不一定改变，但解释改变后，下一步行动会改变。';
        break;
      case 'loss_resource_retention':
        map('core_value_reference')['source_anchor'] = 'Lecture 8 Suzanne Thompson 火灾研究';
        map('loss_resource_retention')
          ..['lost_part'] = text
          ..['painful_part'] = '这里确实有失去、失望或被迫改变的部分，不能轻飘飘说成好事。'
          ..['not_lost'] = <String>['仍然保留的能力或经验。', '仍然在的人或关系。', '仍然可以重新开始的一小块空间。']
          ..['people_still_here'] = <String>['一个现实中仍可联系的人。', '一个曾经支持过我的人。']
          ..['value_clarified'] = '这次失去可能让我更清楚：什么关系、能力、家、时间或自由值得珍惜。'
          ..['restart_piece'] = '只重新开始一小块：整理一个文件、发一条消息、做一个 5 分钟动作。'
          ..['not_beautifying_sentence'] = '我不说这件损失是好事；我只是练习看见没有一起失去的资源。';
        map('benefit_finder_layer')['remaining_resources'] = <String>['没有一起失去的人、能力或时间窗口。', '变得更清楚的价值。', '可重新开始的一小块。'];
        map('process_action_plan')['five_minute_action'] = '写下“失去了什么 / 没有失去什么 / 现在能重新开始的一小块”。';
        payload['final_user_message'] = '资源保留练习不是美化损失，而是在损失之外找回仍可行动的部分。';
        break;
      case 'priming_diagnostic':
        map('core_value_reference')['source_anchor'] = 'Lecture 8 Bargh 启动实验';
        map('priming_diagnostic')
          ..['negative_cues'] = <String>['一个最容易启动拖延、比较或自责的应用/词语/画面/场景。', '一个让我进入无力脚本的环境入口。']
          ..['triggered_state'] = '它可能把我启动成逃避者、比较者或自责者。'
          ..['desired_state'] = '我想被启动成行动者、学习者或恢复者。'
          ..['placed_prime'] = '放置一个现实注意力启动线索：锁屏句、桌面便签、照片或打开任务材料的快捷入口。'
          ..['cleanup_action'] = '今天只清理一个消极启动源：移出首页、关闭提醒、放远手机或替换入口。';
        map('prime')['daily_value_word'] = '启动';
        map('prime')['lock_screen_sentence'] = '环境会启动我；今天让一个线索把我带回行动。';
        map('prime')['anti_prime_cleanup_action'] = '移走一个最强消极启动源，并放上一个支持行动的线索。';
        payload['final_user_message'] = '这不是靠意志硬扛，而是让环境少启动逃避，多启动行动。';
        break;
      case 'identity_script_activation':
        map('core_value_reference')['source_anchor'] = 'Lecture 8 professor / hooligan 身份脚本启动实验';
        map('identity_script_activation')
          ..['triggered_script'] = '我今天可能被启动成了逃避者/比较者/无力者。'
          ..['source'] = text
          ..['effect'] = '这个身份脚本会让我更少行动、更容易自责或更快放弃。'
          ..['desired_script'] = '明天我想更容易被启动成行动者、学习者或恢复者。'
          ..['environment_script'] = '在环境中放一个能启动目标身份的线索：书桌材料、榜样案例、行动证据截图或一句价值词。'
          ..['micro_action'] = action;
        map('prime')['daily_value_word'] = '身份脚本';
        map('prime')['lock_screen_sentence'] = '我选择被启动成行动者，而不是被旧脚本拖走。';
        map('identity_evidence')['identity_type'] = '身份脚本设计者';
        map('identity_evidence')['identity_sentence'] = '我正在成为一个会主动设计环境，让自己更容易进入行动身份的人。';
        payload['final_user_message'] = '身份不是口号，它也会被环境启动；今天只设计一个更支持行动的身份脚本。';
        break;
      case 'gratitude_time_in':
        map('core_value_reference')['source_anchor'] = 'Lecture 9 感恩静心分享';
        map('gratitude_time_in')
          ..['quiet_prompt'] = '先安静 30 秒，只写一个具体感恩，不要写大道理。'
          ..['gratitude_items'] = <String>['一个具体的人或动作。', '一个今天出现的小善意。', '一个身体或环境里的小便利。']
          ..['sensory_detail'] = '记录画面、声音、颜色、触感或动作。'
          ..['body_feeling'] = '记录身体哪里有一点放松、温暖、展开或安定。'
          ..['share_person'] = '选择一个可以分享或表达感谢的人。'
          ..['expression_text'] = '今天想到你做过的那件具体小事，我想认真说一句谢谢。'
          ..['after_sharing_record'] = '表达后记录：关系有什么变化，我有没有更具体地看见好的部分？';
        map('gratitude_or_savoring')['what_still_matters'] = <String>['一个具体感恩对象。', '一个可以停留 30 秒的好画面。', '一个可以分享给人的感谢。'];
        map('gratitude_or_savoring')['savoring_prompt'] = '安静 30 秒，记录感官细节和身体感受。';
        map('gratitude_or_savoring')['small_appreciation_action'] = '把一条具体感谢分享给一个人，或先保存为草稿。';
        map('relationship_gratitude')['person'] = '一个值得感谢的人';
        map('relationship_gratitude')['context'] = text;
        map('relationship_gratitude')['light_text'] = '今天想到你之前那件具体的支持，想说谢谢。';
        map('relationship_gratitude')['concrete_text'] = '你当时做的那件事对我很重要，我没有忘记。谢谢你。';
        map('relationship_gratitude')['deep_text'] = '这件事让我感到被支持，也提醒我生命里仍有值得珍惜的人。谢谢你。';
        map('relationship_gratitude')['chosen_action'] = '发送、当面表达，或先保存不发。';
        payload['final_user_message'] = '感恩静心分享 不是写漂亮句子，而是停下来、具体看见、并把感谢带回关系。';
        break;
      case 'process_simulation_check':
        map('core_value_reference')['source_anchor'] = 'Lecture 7 过程模拟 vs 结果模拟';
        map('process_simulation_check')
          ..['time'] = '今天一个明确时间，例如现在或晚饭后 10 分钟。'
          ..['place'] = '一个具体地点，例如书桌、图书馆、安静角落。'
          ..['tool'] = '要打开的具体工具或材料。'
          ..['first_move'] = '第一动作必须小到可以立刻做：打开文件、写标题、读第一页。'
          ..['distraction'] = '最可能干扰的是手机、音乐、消息或怕做不好。'
          ..['de_distraction_action'] = '开始前把干扰源移开 2 米或关闭一个通知。'
          ..['completion_standard'] = '5 分钟后留下一个可见痕迹，不要求完成全部。'
          ..['quality_check'] = '有时间、地点、工具、第一步、去干扰和完成标准，才算过程模拟。';
        map('process_action_plan')['five_minute_action'] = action;
        map('process_action_plan')['next_three_steps'] = <String>['确定时间地点。', '打开工具材料。', '只完成第一个可见痕迹。'];
        map('process_action_plan')['if_then_plan'] = <String>['如果想等状态变好，那么先做 5 分钟。', '如果怕做不好，那么只做草稿。', '如果被手机吸走，那么先把手机放远。'];
        payload['final_user_message'] = '这一步专门把结果幻想变成过程路径：具体到哪里、何时、用什么、先做什么。';
        break;
      case 'psychological_immunity_experiment':
        map('core_value_reference')['source_anchor'] = 'Lecture 7 心理免疫系统';
        map('psychological_immunity_experiment')
          ..['before_prediction'] = '失败前预测：我以为会有多痛、多久恢复、别人会怎么看。'
          ..['after_result'] = '失败后记录真实发生了什么，而不是只保留脑中灾难画面。'
          ..['pain_gap'] = '比较预测痛苦和实际痛苦。'
          ..['recovery_gap'] = '比较预测恢复时间和实际恢复时间。'
          ..['worst_case_happened'] = '检查最坏预测是否真的发生，若发生是否仍可恢复。'
          ..['antibody_sentence'] = '我能承受一次不完美，并从中设计下次更小行动。'
          ..['next_smaller_attempt'] = '下次只尝试一个更小、更可恢复的动作。';
        map('failure_immunity')['predicted_pain'] = 8;
        map('failure_immunity')['predicted_recovery'] = '先写下我预测自己会痛多久。';
        map('failure_immunity')['actual_recovery'] = '执行后补录实际恢复时间。';
        map('failure_immunity')['psychological_antibody'] = '失败不是人格判决；它可以成为心理免疫系统的一次训练。';
        map('process_action_plan')['five_minute_action'] = '写下失败前预测表：预测痛苦、预测恢复、最坏结果、一个恢复动作。';
        payload['final_user_message'] = '心理免疫不是失败后安慰自己，而是用预测和实际的差距训练可恢复感。';
        break;
      case 'weekly_baseline':
        payload['final_user_message'] = '本周不只看你是否开心，而看幸福基线、恢复能力、解释风格、行动证据、感恩敏感度和注意力环境是否在变强。';
        break;
      case 'todo_goal_bridge':
        map('p2_delivery')
          ..['artifact_type'] = 'todo_goal_bridge'
          ..['title'] = '待办事项未完成转训练'
          ..['trigger_condition'] = '待办事项逾期、未完成或目标拖延'
          ..['summary'] = '把未完成从失败标签转为情绪允许、解释重构和明日最小行动。'
          ..['sections'] = <String>['未完成事件', '情绪允许', '解释风格', '问题视角/资源视角', '明日最小行动', '行动证据问题']
          ..['next_action'] = '明天先做一个 5 分钟启动动作。'
          ..['reuse_surface'] = '待办事项';
        map('process_action_plan')['five_minute_action'] = '把未完成的待办事项缩小为今天 5 分钟内能开始的第一步，并写下一个 如果-那么 应对。';
        map('identity_evidence')['identity_type'] = '行动证据积累者';
        map('identity_evidence')['identity_sentence'] = '我正在成为一个能把未完成转成下一次更小行动的人。';
        payload['final_user_message'] = '待办事项未完成不是人格判决；它会进入情绪允许、解释重构和今日最小行动。';
        break;
      case 'daily_review':
        map('p2_delivery')
          ..['artifact_type'] = 'daily_review'
          ..['title'] = '每日自动复盘'
          ..['trigger_condition'] = '晚上或结束一天时'
          ..['summary'] = '汇总事件、行动证据、感恩品味、身份提醒和明日注意力启动线索。'
          ..['sections'] = <String>['今日事件', '解释风格', '行动证据', '三件具体感恩', '30 秒品味', '明日注意力启动线索']
          ..['next_action'] = '保存一条明日注意力启动线索。'
          ..['reuse_surface'] = '首页/每日复盘';
        map('gratitude_or_savoring')['savoring_prompt'] = '选择今天一个具体好体验停留 30 秒，然后为明天设置一个 注意力启动线索。';
        map('prime')['daily_value_word'] = '复盘';
        map('prime')['lock_screen_sentence'] = '今天不必完美，但我要保存一个行动证据。';
        payload['final_user_message'] = '今日复盘重点：看见解释风格、保存行动证据、具体感恩，并设置明日注意力启动线索。';
        break;
      case 'course_card':
        map('p2_delivery')
          ..['artifact_type'] = 'course_card'
          ..['title'] = '现实主义乐观课程知识卡'
          ..['trigger_condition'] = '用户学习课程概念或需要复习时'
          ..['summary'] = '把概念变成现实例子、练习问题和 5 分钟行动。'
          ..['sections'] = <String>['核心概念', '现实例子', '练习问题', '5 分钟行动']
          ..['next_action'] = '用一个真实事件练习事实-解释分离。'
          ..['reuse_surface'] = '课程知识卡';
        map('process_action_plan')['five_minute_action'] = '读完这张知识卡后，立刻把一个真实事件改写成“事实 + 解释 + 可控点”。';
        payload['final_user_message'] = '课程知识卡必须落到一个练习问题和一个 5 分钟行动，而不是停留在概念。';
        break;
      case 'role_model_case':
        map('p2_delivery')
          ..['artifact_type'] = 'role_model_case'
          ..['title'] = '榜样失败恢复案例'
          ..['trigger_condition'] = '用户需要“有人也做到过”的替代证据时'
          ..['summary'] = '拆解榜样如何失败、解释、恢复、行动和可模仿行为。'
          ..['sections'] = <String>['失败处境', '解释方式', '恢复动作', '可模仿的一步']
          ..['next_action'] = '只模仿榜样的一个最小动作。'
          ..['reuse_surface'] = '榜样案例库';
        map('benefit_finder_layer')['remaining_resources'] = <String>['Tal 也曾把失败解释为训练、谦卑和未来能力来源。', '课程案例可以提供“同一现实，不同解释”的替代证据。', '今天只模仿一个最小动作。'];
        payload['final_user_message'] = '案例不是用来比较，而是提醒：同一现实可以有更完整解释，失败后恢复并继续行动有现实路径。';
        break;
      case 'proactive_reminder':
        map('p2_delivery')
          ..['artifact_type'] = 'proactive_reminder'
          ..['title'] = '主动提醒文案'
          ..['trigger_condition'] = '自责、拖延、睡前刷信息流或待办事项逾期时'
          ..['summary'] = '生成推送、锁屏、小组件可复用的短提醒和行动线索。'
          ..['sections'] = <String>['触发条件', '提醒短句', '资源发现问题', '5 分钟行动线索']
          ..['next_action'] = '把提醒短句设为小组件或锁屏文案。'
          ..['reuse_surface'] = '锁屏/小组件/推送';
        map('prime')['daily_value_word'] = '提醒';
        map('prime')['lock_screen_sentence'] = '如果开始自责，就只做一个 5 分钟证据。';
        map('prime')['benefit_finder_question'] = '这件事里还有哪个可控点？';
        payload['final_user_message'] = '主动提醒应包含触发条件、短句和一个小行动线索。';
        break;
      case 'monthly_report':
        map('p2_delivery')
          ..['artifact_type'] = 'monthly_report'
          ..['title'] = '周/月报图表摘要'
          ..['trigger_condition'] = '每周或每月回顾时'
          ..['summary'] = '汇总解释风格、行动证据、失败恢复、注意力环境、感恩和身份成长趋势。'
          ..['sections'] = <String>['解释风格趋势', '行动证据', '失败恢复', '注意力启动线索与消极启动源', '感恩敏感度', '身份成长']
          ..['next_action'] = '下周期只选择一个训练重点。'
          ..['reuse_surface'] = '周报/月报';
        payload['final_user_message'] = '本周期报告应同时看解释风格、行动证据、失败恢复、注意力启动线索与消极启动源、感恩敏感度和身份成长。';
        break;
      default:
        break;
    }
    final p2 = map('p2_delivery');
    if ((p2['title'] ?? '').toString().trim().isEmpty) {
      const mechanismTitles = <String, String>{
        'reality_record': '真实现实记录',
        'complete_reality': '完整现实感练习',
        'appreciation_scan': '防贬值珍惜扫描',
        'same_reality_interpretations': '同一现实，多种解释练习',
        'loss_resource_retention': '损失后的资源保留练习',
        'priming_diagnostic': '启动源诊断器',
        'identity_script_activation': '身份脚本启动练习',
        'gratitude_time_in': '感恩静心分享闭环',
        'process_simulation_check': '过程模拟校验器',
        'psychological_immunity_experiment': '心理免疫实验',
      };
      if (mechanismTitles.containsKey(scene)) {
        p2
          ..['artifact_type'] = scene
          ..['title'] = mechanismTitles[scene]
          ..['trigger_condition'] = '用户选择课程机制练习时'
          ..['summary'] = payload['final_user_message'] ?? ''
          ..['sections'] = <String>['课程锚点', '用户当前现实', '专属练习步骤', '下一步行动']
          ..['next_action'] = (map('process_action_plan')['five_minute_action'] ?? map('gratitude_or_savoring')['small_appreciation_action'] ?? payload['final_user_message'] ?? '').toString()
          ..['reuse_surface'] = '课程机制练习库 / 训练记录';
      }
    }
  }

  void _applySafetyRouting(Map<String, dynamic> payload, {String userInput = ''}) {
    Map<String, dynamic> map(String key) {
      final value = payload[key];
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        final converted = Map<String, dynamic>.from(value);
        payload[key] = converted;
        return converted;
      }
      final created = <String, dynamic>{};
      payload[key] = created;
      return created;
    }

    final intensity = map('intensity_check');
    final rawLevel = intensity['level']?.toString().trim();
    final modelLevel = (rawLevel == null || rawLevel.isEmpty ? 'L1' : rawLevel).toUpperCase();
    final inputLevel = userInput.trim().isEmpty ? 'L1' : _guessLevel(userInput);
    final level = _moreSevereLevel(modelLevel, inputLevel);
    if (level != 'L3' && level != 'L4') return;

    intensity['level'] = level;
    intensity['allowed_intervention'] = level == 'L4'
        ? <String>['安全支持', '联系现实中的可信任人员', '联系当地紧急服务或危机热线', '移除近处危险物']
        : <String>['情绪稳定', '身体落地', '现实支持', '只做非常小的照顾性行动'];
    intensity['blocked_intervention'] = <String>['强行感恩', '强行寻找意义', '资源发现视角 重构', '失败复盘逼问', '宏大行动计划'];

    final emotion = map('emotion_validation');
    emotion['validation_text'] = level == 'L4'
        ? '你现在的痛苦需要被认真对待。当前最重要的不是训练乐观，而是先保证安全：请立刻联系身边可信任的人，或拨打当地紧急服务/危机热线；如果你在美国，可拨打或短信 988。'
        : '这类痛苦可能已经很强，不适合马上要求自己积极、感恩或寻找意义。现在先承认它很重，并把目标缩小到稳定身体、减少刺激、联系现实支持。';

    map('benefit_finder_layer')
      ..['balanced_interpretation'] = level == 'L4'
          ? '当前不做积极重构。安全风险出现时，第一优先级是让你不要独自承受，并尽快获得现实支持。'
          : '当前先不把痛苦转成好处，也不急着找意义。更现实的回应是：这件事很重，先稳定和求助，等强度下降后再考虑事实-解释分离。'
      ..['not_denied_pain'] = '系统已保留痛苦本身，不把它包装成好事。'
      ..['possible_learning'] = <String>[]
      ..['possible_meaning'] = <String>[];

    map('process_action_plan')
      ..['five_minute_action'] = level == 'L4'
          ? '现在立刻离开危险物，联系一个可信任的人待在一起；如无法保证安全，请拨打当地紧急服务/危机热线。'
          : '做 60 秒落地练习：双脚踩地，慢慢呼气 5 次，然后给一个可信任的人发一句“我现在很难受，能陪我一下吗”。'
      ..['next_three_steps'] = level == 'L4'
          ? <String>['把自己和危险物分开。', '联系可信任的人或紧急服务。', '在有人陪伴或专业支持前，不继续普通训练。']
          : <String>['喝水或换到更安全安静的位置。', '写下“我现在只是先撑过这一段”。', '联系一个现实支持者或预约专业支持。']
      ..['if_then_plan'] = level == 'L4'
          ? <String>['如果我无法保证安全，那么立刻拨打当地紧急服务或危机热线。', '如果我不想打电话，那么先发短信给可信任的人说“请现在联系我”。']
          : <String>['如果痛苦继续升高，那么暂停重构并联系现实支持。', '如果开始逼自己积极，那么提醒自己：现在只需要稳定，不需要解释。'];

    map('gratitude_or_savoring')
      ..['what_still_matters'] = <String>[]
      ..['savoring_prompt'] = '当前先不做感恩或品味练习，等强度下降后再进行。'
      ..['small_appreciation_action'] = '';

    map('failure_immunity')
      ..['predicted_pain'] = null
      ..['actual_pain'] = null
      ..['predicted_recovery'] = ''
      ..['actual_recovery'] = ''
      ..['worst_case_prediction'] = ''
      ..['actual_result'] = ''
      ..['psychological_antibody'] = '';

    map('controlled_failure_challenge')
      ..['challenge_name'] = ''
      ..['risk_level'] = ''
      ..['safety_boundary'] = ''
      ..['execution_steps'] = <String>[]
      ..['pre_failure_questions'] = <String>[]
      ..['post_failure_questions'] = <String>[]
      ..['possible_antibody'] = '';

    map('prime')
      ..['daily_value_word'] = ''
      ..['lock_screen_sentence'] = ''
      ..['benefit_finder_question'] = ''
      ..['anti_prime_cleanup_action'] = '';

    map('p2_delivery')
      ..['artifact_type'] = ''
      ..['title'] = ''
      ..['trigger_condition'] = ''
      ..['summary'] = ''
      ..['sections'] = <String>[]
      ..['next_action'] = ''
      ..['reuse_surface'] = '';

    map('identity_evidence')
      ..['specific_action'] = ''
      ..['proved_capacity'] = ''
      ..['identity_type'] = ''
      ..['identity_sentence'] = '';

    payload['final_user_message'] = level == 'L4'
        ? '这一步不做普通训练：请优先保证安全，并立刻联系现实中的人或危机支持。'
        : '现在先稳定，不急着积极；等强度下降后，再回到事实-解释分离和微行动。';
  }

  String _moreSevereLevel(String first, String second) {
    int rank(String level) {
      switch (level.toUpperCase()) {
        case 'L4':
          return 4;
        case 'L3':
          return 3;
        case 'L2':
          return 2;
        case 'L1':
        default:
          return 1;
      }
    }

    return rank(second) > rank(first) ? second.toUpperCase() : first.toUpperCase();
  }

  String _guessLevel(String text) {
    final danger = <String>['不想活', '想死', '自杀', '轻生', '结束生命', '伤害自己', '伤害别人', '伤人', '杀人', '杀了', '割腕', '跳楼', '死了算了', '活着没意思', '不想存在'];
    if (danger.any(text.contains)) return 'L4';
    final severe = <String>['创伤', '崩溃', '绝望', '活不下去', '撑不住', '重大失去', '亲密关系破裂', '分手', '亲人去世', '被侵犯', '长期痛苦'];
    if (severe.any(text.contains)) return 'L3';
    final medium = <String>['失败', '羞耻', '面试', '被否定', '争吵', '自责', '拖延', '坚持不了'];
    if (medium.any(text.contains)) return 'L2';
    return 'L1';
  }

  String _guessEmotion(String text) {
    if (text.contains('羞') || text.contains('丢脸')) return '羞耻';
    if (text.contains('怕') || text.contains('担心') || text.contains('焦虑')) return '焦虑';
    if (text.contains('气') || text.contains('愤怒')) return '愤怒';
    if (text.contains('失败') || text.contains('没做到') || text.contains('失望')) return '失望';
    if (text.contains('拖延') || text.contains('又')) return '自责';
    return '难受';
  }

  String _guessInterpretation(String text) {
    if (text.contains('永远')) return '这件事说明我永远都改变不了。';
    if (text.contains('废') || text.contains('不行') || text.contains('没用')) return '这次不顺利说明我整个人不行。';
    if (text.contains('肯定')) return '未来肯定会继续变糟。';
    return '这件事可能被我解释成能力不足、未来无望或行动没有意义。';
  }

  String _guessAction(String text) {
    if (text.contains('学习') || text.contains('英语')) return '打开学习材料，只读第一段并圈出3个关键词。';
    if (text.contains('简历') || text.contains('工作') || text.contains('面试')) return '打开简历或面试记录，只修改/补充一个具体句子。';
    if (text.contains('运动')) return '穿上鞋或站起来活动1分钟，不要求完成完整运动。';
    if (text.contains('写') || text.contains('文章')) return '打开文档，只写3行，不评价质量。';
    return '写下一个客观事实、一个自动解释，再完成一个1-5分钟的小动作。';
  }
}
