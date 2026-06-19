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
    final risk = (text.contains('永远') || text.contains('彻底') || text.contains('完了')) ? 'high' : 'medium';
    final newBelief = '我不能保证结果立刻改变，但可以把“$oldBelief”当作一个可检验的假设，通过一个很小的行动实验收集新证据。';
    final minAction = _guessMinimumAction(goal, text);
    final cards = <Map<String, dynamic>>[
      <String, dynamic>{'title': '我的四分钟墙', 'content': oldBelief, 'type': 'belief'},
      <String, dynamic>{'title': '现实乐观信念', 'content': newBelief, 'type': 'reality'},
      <String, dynamic>{'title': '今日行动实验', 'content': minAction, 'type': 'action'},
      <String, dynamic>{'title': '失败不是结论', 'content': '如果没做到，先记录具体条件，再把它当作系统反馈。', 'type': 'failure'},
    ];
    final json = <String, dynamic>{
      'module': 'realistic_optimism_lab',
      'scene': '完整信念行动实验',
      'source': source,
      'id': 'ro_${now}_${text.hashCode.abs()}',
      'title': goal.isEmpty ? '现实乐观行动实验' : goal,
      'original_input': text,
      'summary': <String, dynamic>{
        'user_goal': goal,
        'core_problem': '限制性信念、旧失败记忆或环境阻力正在削弱开始行动的概率。',
        'main_belief': oldBelief,
        'risk_level': risk,
        'ai_position': '现实乐观，不承诺结果，强调行动实验',
      },
      'belief_chain': <String, dynamic>{
        'old_belief': oldBelief,
        'facts': <String>['你已经清楚表达了想改变或推进的主题。', if (isFailure) '过去或今天确实出现过失败/中断/没做到的经验。'],
        'interpretations': <String>['把过去或当前的困难解释成未来也会如此。', '把一次具体阻碍扩大成对能力或身份的判断。'],
        'hidden_assumptions': <String>['必须有足够信心才可以开始。', '如果开始后失败，就证明自己不行。', '行动必须做得很完整才有意义。'],
        'behavior_effects': <String>['开始前压力升高。', '更容易回避或拖延。', '失败后更容易自责而不是修正系统。'],
        'new_realistic_belief': newBelief,
      },
      'reality_check': <String, dynamic>{
        'controllable_factors': <String>['行动门槛', '开始时间', '手机/环境干扰', '复盘方式', '下一步大小'],
        'uncontrollable_factors': <String>['过去已经发生的失败', '短期内不能保证结果', '他人的评价和外部机会'],
        'resources': <String>['今天可用的几分钟时间', '已有的目标意识', '可以记录和复盘的工具'],
        'risks': <String>['目标过大', '完美主义', '失败后自我攻击', '环境线索继续诱发回避'],
        'reality_constraints': <String>['不能期待一次行动就彻底改变长期模式。', '需要通过多次小实验累计证据。'],
        'probability_improvers': <String>['降低最小行动标准', '提前布置环境', '失败后只改系统不骂自己', '用 if-then 计划处理阻碍'],
      },
      'priming_design': <String, dynamic>{
        'needed_state': '低压力、可开始、愿意复盘',
        'positive_cues': <String>['桌面放一张写有最小行动的纸条', '手机提醒语：先做5分钟，不评价结果', '开始前深呼吸一次并打开对应材料'],
        'phone_prompt': '不是证明我行不行，而是收集一个新证据。',
        'environment_changes': <String>['把行动材料提前放到可见位置', '把最容易分心的入口移出第一屏', '开始前只保留一个任务窗口'],
        'anti_priming_cleanup': <String>['不要在床上启动任务', '不要一开始就打开高刺激 App', '不要用宏大计划替代第一步'],
      },
      'action_experiment': <String, dynamic>{
        'today_minimum_action': minAction,
        'time': '今天最早一个可用的 5 分钟',
        'place': '能坐稳且干扰较少的地方',
        'minimum_success_standard': '只要启动并留下 1 条记录就算成功',
        'if_then_plan': '如果想逃避，就把行动缩小到 1 分钟，并先完成第一步。',
        'possible_obstacle': isAvoid ? '害怕失败或想先逃避' : '觉得行动太小、没有意义',
        'fallback_action': '只打开材料/写下一句话/完成 1 分钟，也算保留系统。',
      },
      'failure_learning': <String, dynamic>{
        'possible_failure': '今天没有启动或中途停止。',
        'non_helpful_explanation': '我果然不行/我永远坚持不了。',
        'realistic_explanation': '这说明当前行动门槛、时间或环境还不合适，不足以证明你整个人不行。',
        'feedback_value': '失败暴露了系统阻力：任务大小、时间点、环境线索或情绪负荷。',
        'next_adjustment': '下一轮把行动再缩小，并提前移除一个最强干扰。',
      },
      'cope_design': <String, dynamic>{
        'avoid_pattern': isAvoid ? '用拖延/转移注意来短期减轻压力。' : '停留在思考和计划中，迟迟不进入现实反馈。',
        'comfort_zone_action': '继续想一想、继续做完整计划。',
        'stretch_zone_action': minAction,
        'panic_zone_action': '一次性要求自己彻底改变或完成全部任务。',
        'recommended_action': minAction,
        'self_perception_after_action': '我正在成为一个能用小行动训练信念的人。',
      },
      'user_choice': <String, dynamic>{
        'options': <String>[minAction, '只整理材料 1 分钟', '只写下失败后要复盘的一个问题'],
        'recommended_but_not_forced': minAction,
        'reflection_question': '如果这只是一次实验，而不是证明你行不行，你愿意先完成哪一步？',
      },
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
