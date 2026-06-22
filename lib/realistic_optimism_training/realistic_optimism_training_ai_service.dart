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

class RealisticOptimismTrainingAiService {
  final GlobalAiSettings _settings = GlobalAiSettings();
  final UnifiedAiService _ai = UnifiedAiService();
  final RealisticOptimismTrainingPromptConfig _prompts = RealisticOptimismTrainingPromptConfig();

  Future<Map<String, String>> aiState() async {
    try {
      return await _settings.getState();
    } catch (_) {
      return <String, String>{'provider': 'none', 'model': 'none', 'label': '未配置（将使用内置策略）', 'available': '0'};
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
          _applySafetyRouting(parsed);
          final record = RealisticOptimismTrainingRecord.fromJson(parsed);
          if (record.fiveMinuteAction.isNotEmpty || record.balancedInterpretation.isNotEmpty || record.validationText.isNotEmpty) {
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
        'source_anchor': hasFailure ? '失败免疫：Edison / Simonton / Babe Ruth' : hasForever ? 'Seligman 解释风格 + Biondi 案例' : '事实-解释分离 + 行动证据',
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
            : <String>['情绪允许', '事实-解释分离', 'Benefit Finder 重构', '5分钟微行动', '行动证据记录'],
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
        'fault_finder_story': 'Fault Finder 会把这件事讲成：这次不顺利说明我整个人不行，未来也很难改变，所以现在行动也没有意义。',
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
        'psychological_antibody': '失败会痛，但它不必定义我；我可以从一次小复盘中恢复一点主动性。',
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
      'prime': <String, dynamic>{
        'daily_value_word': '行动证据',
        'lock_screen_sentence': '我可以痛苦，也可以先做一个小动作。',
        'benefit_finder_question': '这件事里，我还剩下哪一个可控点？',
        'anti_prime_cleanup_action': '把最容易让我拖延或比较的入口从手机首页移走。',
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
    _applySafetyRouting(payload);
    return RealisticOptimismTrainingRecord.fromJson(payload);
  }

  void _applySceneFallback(Map<String, dynamic> payload, String scene, String text, String action) {
    Map<String, dynamic> map(String key) => payload[key] as Map<String, dynamic>;
    switch (scene) {
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
        payload['final_user_message'] = '同一现实可以有两种镜头：Fault Finder 让你失去行动力，Benefit Finder 帮你承认痛苦后找回一个可控点。';
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
        map('prime')['lock_screen_sentence'] = '我关注什么，就更容易看见什么；今天先关注一个可控点。';
        map('prime')['benefit_finder_question'] = '今天我要主动寻找哪一个仍然存在的资源？';
        payload['final_user_message'] = '今天的目标不是靠意志硬撑，而是让环境反复提醒你回到价值与行动。';
        break;
      case 'anti_prime_cleanup':
        map('prime')['anti_prime_cleanup_action'] = '从首页移走一个最容易触发拖延、比较或无力感的入口，并用一句现实提醒替换。';
        payload['final_user_message'] = '不是一次性改变全部环境，只清理一个最强 Anti-Prime。';
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
      case 'weekly_baseline':
        payload['final_user_message'] = '本周不只看你是否开心，而看恢复能力、解释风格、行动证据、感恩敏感度和注意力环境是否在变强。';
        break;
      default:
        break;
    }
  }

  void _applySafetyRouting(Map<String, dynamic> payload) {
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
    final level = (rawLevel == null || rawLevel.isEmpty ? 'L1' : rawLevel).toUpperCase();
    if (level != 'L3' && level != 'L4') return;

    intensity['level'] = level;
    intensity['allowed_intervention'] = level == 'L4'
        ? <String>['安全支持', '联系现实中的可信任人员', '联系当地紧急服务或危机热线', '移除近处危险物']
        : <String>['情绪稳定', '身体落地', '现实支持', '只做非常小的照顾性行动'];
    intensity['blocked_intervention'] = <String>['强行感恩', '强行寻找意义', 'Benefit Finder 重构', '失败复盘逼问', '宏大行动计划'];

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

    payload['final_user_message'] = level == 'L4'
        ? '这一步不做普通训练：请优先保证安全，并立刻联系现实中的人或危机支持。'
        : '现在先稳定，不急着积极；等强度下降后，再回到事实-解释分离和微行动。';
  }

  String _guessLevel(String text) {
    final danger = <String>['不想活', '自杀', '伤害自己', '伤害别人', '杀了', '死了算了'];
    if (danger.any(text.contains)) return 'L4';
    final severe = <String>['创伤', '崩溃', '绝望', '活不下去', '重大失去', '分手', '亲人去世'];
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
