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
    final text = userInput.trim().isEmpty ? '我想重新解释一个事件，但还没有写清楚。' : userInput.trim();
    final goal = _guessGoal(text);
    final oldBelief = _guessOldBelief(text);
    final level = _guessIntensityLevel(text);
    final isSafety = level == 'L4';
    final isHigh = level == 'L3';
    final minAction = isSafety
        ? '先把自己移动到更安全的位置，并联系当地紧急支持或可信任的人。'
        : isHigh
            ? '把手机放在手边，给一个可信任的人发一句“我现在很难受，能陪我一下吗？”'
            : _guessMinimumAction(goal, text);
    final json = <String, dynamic>{
      'module': 'realistic_optimism',
      'scene': '事件重构与行动闭环',
      'source': source,
      'id': 'ro_${now}_${text.hashCode.abs()}',
      'title': '现实主义乐观训练：${goal.isEmpty ? '今日事件' : goal}',
      'original_input': text,
      'intensity_check': <String, dynamic>{
        'level': level,
        'reason': _intensityReason(level),
        'allowed_intervention': isSafety
            ? <String>['安全支持', '联系现实支持', '降低当下风险']
            : isHigh
                ? <String>['情绪稳定', '承认痛苦', '现实支持', '非常小的稳定动作']
                : <String>['情绪允许', '事实-解释分离', 'Benefit Finder 重构', '5 分钟微行动'],
        'blocked_intervention': isSafety || isHigh
            ? <String>['强行积极', '强行感恩', '要求立刻寻找意义', '高压力行动挑战']
            : <String>['否认痛苦', '空泛口号', '一次性解决全部问题'],
      },
      'user_event_summary': text,
      'emotion_validation': <String, dynamic>{
        'primary_emotion': _guessEmotion(text),
        'validation_text': '你现在的感受可以被理解。它不是软弱或失败的证据，而是说明这件事对你有分量。我们不急着把它说成好事，先把事实、解释和一个很小的可控点分开。',
      },
      'fact_layer': <String, dynamic>{
        'objective_facts': <String>['你记录了一个让自己受影响的事件或目标：$text', if (text.contains('没') || text.contains('失败') || text.contains('拖延')) '当前确实出现了未完成、失败或阻碍。'],
        'unknowns_or_assumptions': <String>['这件事是否代表未来还没有证据。', '这件事是否等于人格失败还需要分离事实与解释。'],
      },
      'interpretation_style': <String, dynamic>{
        'automatic_interpretation': oldBelief,
        'permanence_score': text.contains('永远') || text.contains('总是') || text.contains('一直') ? 8 : 4,
        'pervasiveness_score': text.contains('全部') || text.contains('什么都') || text.contains('所有') ? 8 : 4,
        'personalization_score': text.contains('废') || text.contains('我不行') || text.contains('没价值') ? 8 : 5,
        'catastrophizing_score': text.contains('完了') || text.contains('没救') || text.contains('彻底') ? 8 : 4,
        'helplessness_score': text.contains('不能') || text.contains('无法') || text.contains('没办法') ? 7 : 4,
        'filtering_score': 6,
        'main_pattern': _mainPattern(text),
      },
      'fault_finder_layer': <String, dynamic>{
        'fault_finder_story': '$text = $oldBelief = 现在做也没有意义。',
        'likely_emotional_effect': '更羞耻、更紧绷、更容易把痛苦理解成全部现实。',
        'likely_behavioral_effect': '更容易逃避、拖延或放弃记录新的行动证据。',
      },
      'benefit_finder_layer': <String, dynamic>{
        'balanced_interpretation': isSafety || isHigh ? '这件事很重，当前重点不是证明乐观，而是先保证安全、获得支持、让情绪从最高点降下来。' : '这件事确实不舒服，也暴露了当前计划、环境或方法上的阻力；但它不是对你整个人或全部未来的最终判决。现在仍然可以用一个 5 分钟动作制造新证据。',
        'not_denied_pain': '痛苦、羞耻、自责或失望不需要被否认。',
        'possible_learning': <String>['目标可能需要缩小到可启动版本。', '解释方式会影响下一步行动。', '环境线索可能正在放大回避。'],
        'remaining_resources': <String>['你还能记录事实。', '你还能选择一个很小的行动。', '你还能请求支持或调整环境。'],
        'possible_meaning': isSafety || isHigh ? <String>[] : <String>['这次经历可以成为一次事实-解释分离训练。'],
      },
      'agency_layer': <String, dynamic>{
        'uncontrollable_parts': <String>['已经发生的部分', '他人的即时评价', '短期内无法保证的结果'],
        'influenceable_parts': <String>['行动门槛', '复盘方式', '环境干扰', '下一次开始的位置'],
        'controllable_actions': <String>[minAction, '记录一条事实而不是人格评价', '移除一个最强 Anti-Prime'],
      },
      'process_action_plan': <String, dynamic>{
        'five_minute_action': minAction,
        'next_three_steps': <String>['打开相关材料或支持渠道', '只完成第一小步', '记录“我在什么状态下仍然开始了”'],
        'if_then_plan': <String>['如果出现“我不行”的念头，那么先把它写成“我现在遇到阻力”。', '如果 5 分钟也太难，那么缩小到 1 分钟。'],
      },
      'failure_immunity': <String, dynamic>{
        'predicted_pain': null,
        'actual_pain': null,
        'predicted_recovery': '可能会预测自己很久都恢复不了。',
        'actual_recovery': '',
        'psychological_antibody': isSafety || isHigh ? '我可以先寻求支持，而不是逼自己立刻积极。' : '我发现自己可以在不完美和自责中仍然做一个小动作。',
      },
      'gratitude_or_savoring': <String, dynamic>{
        'what_still_matters': isSafety || isHigh ? <String>[] : <String>['今天仍然值得保留的一个小资源', '愿意重新开始的这 5 分钟'],
        'savoring_prompt': isSafety || isHigh ? '先不用感恩；只需要找到一个能让身体稍微稳定的现实支持。' : '今天有没有一个微小的好体验，值得停留 30 秒？',
        'small_appreciation_action': isSafety || isHigh ? '联系一个现实支持。' : '向帮助过你的人或今天的自己说一句具体感谢。',
      },
      'prime': <String, dynamic>{
        'daily_value_word': isSafety || isHigh ? '稳定' : '行动',
        'lock_screen_sentence': isSafety || isHigh ? '先安全，先支持，先降一点强度。' : '我可以痛苦，也可以做一个 5 分钟行动证据。',
        'benefit_finder_question': '这件事里还有哪一个部分是我能影响的？',
        'anti_prime_cleanup_action': '把最容易拖延或自我否定的入口从首页移走 24 小时。',
      },
      'identity_evidence': <String, dynamic>{
        'specific_action': minAction,
        'proved_capacity': isSafety || isHigh ? '在高强度痛苦中优先照顾安全和支持' : '在状态不完美时仍然开始',
        'identity_type': isSafety || isHigh ? '失败后恢复者' : '行动证据积累者',
        'identity_sentence': isSafety || isHigh ? '我正在成为一个痛苦时也会优先保护自己的人。' : '我正在成为一个不靠幻想，而靠行动建立信心的人。',
      },
      'final_user_message': isSafety ? '现在先不做普通训练。请优先确保你处在安全位置，并立刻联系当地紧急服务或可信任的人。' : '我们不把痛苦说成好事，也不让它成为全部现实。今天只需要先做一个很小的行动证据。',
      'provider': 'local',
      'model_label': modelLabel.isEmpty ? '内置策略' : modelLabel,
      'created_at_ms': now,
      'updated_at_ms': now,
    };
    return RealisticOptimismCase.fromJson(json);
  }

  String _guessIntensityLevel(String text) {
    if (text.contains('自杀') || text.contains('不想活') || text.contains('伤害自己') || text.contains('伤害别人') || text.contains('杀')) return 'L4';
    if (text.contains('创伤') || text.contains('绝望') || text.contains('重大失去') || text.contains('分手') || text.contains('离婚')) return 'L3';
    if (text.contains('面试') || text.contains('争吵') || text.contains('被否定') || text.contains('自责') || text.contains('羞辱')) return 'L2';
    return 'L1';
  }

  String _intensityReason(String level) {
    switch (level) {
      case 'L4':
        return '输入中可能包含安全风险信号，需要优先安全支持。';
      case 'L3':
        return '事件可能涉及高强度痛苦、重大失去或疑似创伤，暂不适合强行积极重构。';
      case 'L2':
        return '事件包含明显痛苦、自责、冲突或失败感，适合先情绪允许，再温和重构。';
      default:
        return '事件更接近轻度挫折或拖延阻碍，可以进入事实-解释分离和微行动。';
    }
  }

  String _guessEmotion(String text) {
    if (text.contains('羞') || text.contains('丢脸')) return '羞耻';
    if (text.contains('怕') || text.contains('担心')) return '害怕';
    if (text.contains('气') || text.contains('愤怒')) return '愤怒';
    if (text.contains('自责') || text.contains('废')) return '自责';
    if (text.contains('失望') || text.contains('失败')) return '失望';
    return '压力';
  }

  String _mainPattern(String text) {
    if (text.contains('永远') || text.contains('一直') || text.contains('总是')) return '永久化';
    if (text.contains('全部') || text.contains('什么都') || text.contains('所有')) return '普遍化';
    if (text.contains('废') || text.contains('我不行') || text.contains('没价值')) return '人格化';
    if (text.contains('完了') || text.contains('没救') || text.contains('彻底')) return '灾难化';
    if (text.contains('没办法') || text.contains('无能为力')) return '无力化';
    return '过滤化';
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
