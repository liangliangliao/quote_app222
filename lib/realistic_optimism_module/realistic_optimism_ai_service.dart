import 'dart:convert';

import '../services/global_ai_settings.dart';
import '../services/unified_ai_service.dart';
import 'realistic_optimism_models.dart';
import 'realistic_optimism_prompt_config.dart';

class RealisticOptimismAiResult {
  final RealisticOptimismCase item;
  final String provider;
  final String modelLabel;
  final bool fromFallback;
  const RealisticOptimismAiResult({required this.item, required this.provider, required this.modelLabel, required this.fromFallback});
}

class RealisticOptimismAiService {
  final GlobalAiSettings _settings = GlobalAiSettings();
  final UnifiedAiService _ai = UnifiedAiService();

  Future<Map<String, String>> getGlobalAiState() async {
    try {
      return await _settings.getState();
    } catch (_) {
      return <String, String>{'provider': 'none', 'model': 'none', 'label': '未配置（将使用内置策略）', 'available': '0'};
    }
  }

  Future<RealisticOptimismAiResult> generateCase({
    required String userInput,
    String source = 'manual',
    String extraContext = '',
  }) async {
    final state = await getGlobalAiState();
    final available = (state['available'] ?? '0') == '1';
    if (available) {
      final prompt = '${RealisticOptimismPromptConfig.scenePrompt(userInput: userInput, source: source, extraContext: extraContext)}\n\n${RealisticOptimismPromptConfig.outputFormatPrompt}';
      try {
        final raw = await _ai.generateText(
          prompt: prompt,
          purpose: 'realistic_optimism.generate_case',
          systemPrompt: RealisticOptimismPromptConfig.globalValuePrompt,
          maxTokens: 2200,
          expectJson: true,
          temperature: 0.35,
        );
        final parsed = _parseJson(raw);
        if (parsed != null) {
          parsed['original_input'] = (parsed['original_input'] ?? userInput).toString();
          parsed['source'] = source;
          final item = RealisticOptimismCase.fromJson(parsed).copyWith(
            provider: state['provider'] ?? 'ai',
            modelLabel: state['label'] ?? '统一 AI',
          );
          if (item.todayMinimumAction.trim().isNotEmpty || item.newRealisticBelief.trim().isNotEmpty) {
            return RealisticOptimismAiResult(item: item, provider: item.provider, modelLabel: item.modelLabel, fromFallback: false);
          }
        }
      } catch (_) {}
    }
    final item = _buildLocalCase(userInput: userInput, source: source, modelLabel: state['label'] ?? '内置策略');
    return RealisticOptimismAiResult(item: item, provider: 'local', modelLabel: item.modelLabel, fromFallback: true);
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

  RealisticOptimismCase _buildLocalCase({required String userInput, required String source, required String modelLabel}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final text = userInput.trim().isEmpty ? '我想改变一个目标，但还没有写清楚。' : userInput.trim();
    final goal = _guessGoal(text);
    final oldBelief = _guessOldBelief(text);
    final isAvoid = text.contains('拖延') || text.contains('逃避') || text.contains('不敢') || text.contains('怕');
    final isFailure = text.contains('失败') || text.contains('没做到') || text.contains('又') || text.contains('坚持不了');
    final hasSafetyRisk = text.contains('自杀') || text.contains('自伤') || text.contains('伤害别人') || text.contains('活不下去');
    final level = hasSafetyRisk
        ? 'L4'
        : (text.contains('创伤') || text.contains('绝望') || text.contains('重大') || text.contains('分手') ? 'L3' : ((text.contains('面试') || text.contains('争吵') || text.contains('被否定') || text.contains('羞辱')) ? 'L2' : 'L1'));
    final newBelief = level == 'L4'
        ? '现在最重要的不是训练乐观，而是先保证现实安全，并联系可信任的人或当地紧急支持。'
        : '这件事确实带来了压力，但它不是全部现实；我可以先把事实和解释分开，再用一个 5 分钟行动收集新证据。';
    final minAction = _guessMinimumAction(goal, text);
    final cards = <Map<String, dynamic>>[
      <String, dynamic>{'title': '强度分级', 'content': level, 'type': 'safety'},
      <String, dynamic>{'title': '允许自己为人', 'content': '你现在的感受可以被理解，它不是人格失败。', 'type': 'emotion'},
      <String, dynamic>{'title': 'Benefit Finder', 'content': newBelief, 'type': 'benefit'},
      <String, dynamic>{'title': '5分钟行动', 'content': minAction, 'type': 'action'},
    ];
    final json = <String, dynamic>{
      'module': 'realistic_optimism',
      'scene': '事件重构',
      'source': source,
      'id': 'ro_${now}_${text.hashCode.abs()}',
      'original_input': text,
      'user_event_summary': goal.isEmpty ? text : goal,
      'intensity_check': <String, dynamic>{
        'level': level,
        'reason': hasSafetyRisk ? '输入包含安全风险表达。' : '基于事件痛苦程度、是否涉及创伤/安全风险和自责强度的本地分级。',
        'allowed_intervention': level == 'L4' ? <String>['安全支持', '联系现实支持'] : <String>['情绪允许', '事实-解释分离', '微行动'],
        'blocked_intervention': level == 'L4' ? <String>['普通积极心理训练', '强行感恩', '失败挑战'] : <String>['强行正能量', '否定感受'],
      },
      'emotion_validation': <String, dynamic>{
        'primary_emotion': isFailure ? '自责/失望' : (isAvoid ? '担心/回避' : '压力'),
        'validation_text': '你现在的感受是可以理解的。我们不急着把它说成好事，也不把情绪等同于失败，先把事实和解释分开。',
      },
      'fact_layer': <String, dynamic>{
        'objective_facts': <String>['用户描述了一个需要处理的事件/目标。', if (isFailure) '出现了失败、中断或未完成经验。'],
        'unknowns_or_assumptions': <String>['这是否代表永远如此仍未被证明。', '失败原因可能包含任务大小、环境、方法和情绪负荷。'],
      },
      'interpretation_style': <String, dynamic>{
        'automatic_interpretation': oldBelief,
        'permanence_score': text.contains('永远') || text.contains('总是') ? 8 : 5,
        'pervasiveness_score': text.contains('什么都') || text.contains('全部') ? 8 : 4,
        'personalization_score': text.contains('废') || text.contains('我不行') ? 8 : 5,
        'catastrophizing_score': text.contains('完了') || text.contains('没救') ? 8 : 4,
        'helplessness_score': isAvoid ? 7 : 5,
        'filtering_score': isFailure ? 7 : 5,
        'main_pattern': isFailure ? '人格化/永久化' : '无力化/过滤化',
      },
      'fault_finder_layer': <String, dynamic>{
        'fault_finder_story': '$oldBelief 所以现在做也没有意义。',
        'likely_emotional_effect': '更羞耻、更无力。',
        'likely_behavioral_effect': '更容易拖延、逃避或自我攻击。',
      },
      'benefit_finder_layer': <String, dynamic>{
        'balanced_interpretation': newBelief,
        'not_denied_pain': '这件事带来的难受是真实的，不需要被否认。',
        'possible_learning': <String>['目标可能需要缩小启动动作。', '环境线索可能需要调整。'],
        'remaining_resources': <String>['仍然可以使用今天的 5 分钟。', '已经有觉察和复盘入口。'],
        'possible_meaning': <String>['把这次经历变成下一次更早开始的提醒。'],
      },
      'agency_layer': <String, dynamic>{
        'uncontrollable_parts': <String>['已经发生的过去事件', '他人的即时评价', '短期结果是否立刻改变'],
        'influenceable_parts': <String>['准备方式', '环境干扰', '任务大小', '复盘语言'],
        'controllable_actions': <String>[minAction, '记录完成后的一个事实证据'],
      },
      'process_action_plan': <String, dynamic>{
        'five_minute_action': minAction,
        'next_three_steps': <String>['打开相关材料/页面', '只完成最小一段', '保存或记录一条行动证据'],
        'if_then_plan': <String>['如果想逃避，就把行动缩小到 1 分钟。', '如果开始自责，就先写一句事实而不是评价。'],
      },
      'failure_immunity': <String, dynamic>{'predicted_recovery': '如果今天做不到，可能会想放弃。', 'psychological_antibody': '我可以在失望中重新开始一个更小动作。'},
      'gratitude_or_savoring': <String, dynamic>{'what_still_matters': <String>['我仍然在尝试理解自己。'], 'savoring_prompt': '今天有什么微小的好东西值得停留 30 秒？', 'small_appreciation_action': '记录一个没有被痛苦完全遮蔽的具体事物。'},
      'prime': <String, dynamic>{'daily_value_word': '行动', 'lock_screen_sentence': '我可以痛苦，也可以做一个小行动。', 'benefit_finder_question': '这件事里还有什么我能控制？', 'anti_prime_cleanup_action': '把最容易拖延的 App 从首页移走 24 小时。'},
      'identity_evidence': <String, dynamic>{'specific_action': minAction, 'proved_capacity': '在不完美状态下开始', 'identity_type': '行动证据积累者', 'identity_sentence': '我正在成为一个不等状态完美，也能用小行动重新开始的人。'},
      'final_user_message': newBelief,
      'display_cards': cards,
      'provider': 'local',
      'model_label': modelLabel.isEmpty ? '内置策略' : modelLabel,
      'created_at_ms': now,
      'updated_at_ms': now,
    };
    return RealisticOptimismCase.fromJson(json);
  }

  String _guessGoal(String text) {
    final cleaned = text.replaceAll('\n', ' ').trim();
    final patterns = <RegExp>[
      RegExp(r'想([^，。；;]{2,24})'),
      RegExp(r'希望([^，。；;]{2,24})'),
      RegExp(r'目标是([^，。；;]{2,24})'),
      RegExp(r'准备([^，。；;]{2,24})'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(cleaned);
      if (m != null) return (m.group(1) ?? '').trim();
    }
    if (cleaned.length <= 18) return cleaned;
    return cleaned.substring(0, 18);
  }

  String _guessOldBelief(String text) {
    if (text.contains('坚持不了')) return '我坚持不了。';
    if (text.contains('不敢')) return '我不敢面对这件事。';
    if (text.contains('失败')) return '失败说明我不行。';
    if (text.contains('没有能力') || text.contains('能力不够')) return '我能力不够。';
    if (text.contains('太晚')) return '现在已经太晚了。';
    if (text.contains('拖延')) return '我总会拖延。';
    if (text.contains('不可能')) return '这件事不可能做到。';
    return '我可能做不到或无法持续。';
  }

  String _guessMinimumAction(String goal, String text) {
    if (goal.contains('英语') || text.contains('英语')) return '读 5 个英语句子，并记录一个完成证据。';
    if (goal.contains('工作') || goal.contains('简历') || text.contains('找工作')) return '打开简历或招聘页，只修改/查看 1 个小部分。';
    if (goal.contains('学习') || text.contains('学习')) return '打开学习材料，只学习 5 分钟。';
    if (goal.contains('运动') || text.contains('运动')) return '穿上鞋或做 3 分钟轻运动。';
    if (text.contains('发消息') || text.contains('联系')) return '先写 3 行草稿，不必立刻发送。';
    return '做 5 分钟最小版本，并留下 1 条事实记录。';
  }
}
