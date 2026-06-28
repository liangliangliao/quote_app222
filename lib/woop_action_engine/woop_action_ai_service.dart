import 'dart:convert';

import '../services/global_ai_settings.dart';
import '../services/unified_ai_service.dart';
import 'woop_action_dao.dart';
import 'woop_action_models.dart';
import 'woop_action_prompt_config.dart';

class WoopActionAiResult {
  final WoopActionCard card;
  final String provider;
  final String modelLabel;
  final bool fromFallback;
  const WoopActionAiResult({required this.card, required this.provider, required this.modelLabel, required this.fromFallback});
}

class WoopActionAiService {
  final GlobalAiSettings _settings = GlobalAiSettings();
  final UnifiedAiService _ai = UnifiedAiService();
  final WoopActionPromptConfig _prompts = WoopActionPromptConfig();
  final WoopActionDao _dao = WoopActionDao();

  Future<Map<String, String>> getGlobalAiState() async {
    try {
      return await _settings.getState();
    } catch (_) {
      return <String, String>{'provider': 'none', 'model': 'none', 'label': '未配置（将使用内置 WOOP 策略）', 'available': '0'};
    }
  }

  Future<WoopActionAiResult> generateCard({
    required String userInput,
    String scene = 'auto',
    String source = 'manual',
    String extraContext = '',
  }) async {
    final state = await getGlobalAiState();
    var mergedExtraContext = extraContext;
    try {
      final profileContext = await _dao.profileContextJson();
      if (profileContext.trim().isNotEmpty) {
        mergedExtraContext = <String>[
          if (extraContext.trim().isNotEmpty) extraContext.trim(),
          '用户个人化 WOOP 配置：',
          profileContext,
        ].join('\n');
      }
    } catch (_) {}
    final available = (state['available'] ?? '0') == '1';
    if (available) {
      final prompt = await _prompts.buildPrompt(
        userInput: userInput,
        scene: scene,
        source: source,
        extraContext: mergedExtraContext,
      );
      try {
        final raw = await _ai.generateText(
          prompt: prompt,
          purpose: 'woop_action_engine.generate_card',
          systemPrompt: await _prompts.getPrompt(WoopActionPromptConfig.globalId),
          maxTokens: 2600,
          expectJson: true,
          temperature: 0.32,
        );
        final parsed = _parseJson(raw);
        if (parsed != null) {
          parsed['raw_input'] = (parsed['raw_input'] ?? userInput).toString();
          parsed['source'] = source;
          parsed['provider'] = state['provider'] ?? 'ai';
          parsed['model_label'] = state['label'] ?? '统一 AI';
          parsed['from_fallback'] = false;
          final card = WoopActionCard.fromJson(parsed);
          if (card.wish.trim().isNotEmpty && (card.obstacle.trim().isNotEmpty || card.direction == 'wait')) {
            return WoopActionAiResult(card: _normalizeCard(card, userInput), provider: card.provider, modelLabel: card.modelLabel, fromFallback: false);
          }
        }
      } catch (_) {}
    }

    final card = _buildLocalCard(
      userInput: userInput,
      source: source,
      requestedScene: scene,
      modelLabel: state['label'] ?? '内置 WOOP 策略',
    );
    return WoopActionAiResult(card: card, provider: 'local', modelLabel: card.modelLabel, fromFallback: true);
  }

  Map<String, dynamic>? _parseJson(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    if (text.startsWith('```')) {
      text = text
          .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
          .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
          .replaceAll('```', '')
          .trim();
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) text = text.substring(start, end + 1);
    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  }

  WoopActionCard _normalizeCard(WoopActionCard card, String input) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final wish = card.wish.trim().isEmpty ? _guessWish(input) : card.wish.trim();
    final outcome = card.outcome.trim().isEmpty ? _guessOutcome(input, wish) : card.outcome.trim();
    final obstacle = card.obstacle.trim().isEmpty ? _guessObstacle(input).item1 : card.obstacle.trim();
    final tags = card.obstacleTags.isEmpty ? <String>[_guessObstacle(input).item2] : card.obstacleTags;
    final planIf = card.planIf.trim().isEmpty ? obstacle : card.planIf.trim();
    final planThen = card.planThen.trim().isEmpty ? _guessPlanThen(input, obstacle) : card.planThen.trim();
    return card.copyWith(
      createdAtMs: card.createdAtMs == 0 ? now : card.createdAtMs,
      updatedAtMs: now,
      title: card.title.trim().isEmpty ? _shortTitle(wish) : card.title.trim(),
      rawInput: card.rawInput.trim().isEmpty ? input : card.rawInput,
      wish: wish,
      outcome: outcome,
      obstacle: obstacle,
      obstacleType: card.obstacleType.trim().isEmpty ? tags.first : card.obstacleType,
      obstacleTags: tags,
      planIf: planIf,
      planThen: planThen,
      firstAction: card.firstAction.trim().isEmpty ? _guessFirstAction(input, wish) : card.firstAction.trim(),
      reviewQuestion: card.reviewQuestion.trim().isEmpty ? '障碍出现时，我是否执行了 if–then 计划？如果没有，计划需要变小还是换触发条件？' : card.reviewQuestion,
      aiResponse: card.aiResponse.trim().isEmpty ? _formatReadable(card.copyWith(wish: wish, outcome: outcome, obstacle: obstacle, obstacleTags: tags, planIf: planIf, planThen: planThen)) : card.aiResponse,
    );
  }

  WoopActionCard _buildLocalCard({
    required String userInput,
    required String source,
    required String requestedScene,
    required String modelLabel,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final input = userInput.trim().isEmpty ? '我想推进一个重要愿望，但还没有写清楚。' : userInput.trim();
    final scene = requestedScene == 'auto' ? _detectScene(input) : requestedScene;
    final wish = _guessWish(input, scene: scene);
    final outcome = _guessOutcome(input, wish);
    final obstacle = _guessObstacle(input, scene: scene);
    final direction = _guessDirection(input, scene);
    final feasibility = _guessFeasibility(input, scene);
    final controllability = scene == 'waiting_comfort' ? 'low' : _guessControllability(input);
    final cost = input.contains('耗尽') || input.contains('很痛苦') || input.contains('太累') ? 'high' : 'medium';
    final belongs = input.contains('父母') || input.contains('别人希望') || input.contains('应该') || input.contains('必须') ? 'unclear' : 'clear';
    final planIf = scene == 'waiting_comfort'
        ? '我又开始反复想象最坏或最好结果'
        : obstacle.item1;
    final planThen = scene == 'waiting_comfort'
        ? '允许自己写下担心，再做一个可控小动作，例如喝水、洗澡或联系可信任的人'
        : _guessPlanThen(input, obstacle.item1, scene: scene);
    final firstAction = _guessFirstAction(input, wish, scene: scene);
    final card = WoopActionCard(
      createdAtMs: now,
      updatedAtMs: now,
      source: source,
      scene: scene,
      title: _shortTitle(wish),
      rawInput: input,
      currentJudgement: _currentJudgement(scene, direction),
      wish: wish,
      outcome: outcome,
      obstacle: obstacle.item1,
      obstacleType: obstacle.item2,
      obstacleTags: <String>[obstacle.item2, ...obstacle.item3],
      planIf: planIf,
      planThen: planThen,
      firstAction: firstAction,
      reviewQuestion: scene == 'failure_review'
          ? '这次失败暴露的真正障碍是什么？新版计划是否比旧计划更具体、更低门槛？'
          : '障碍出现时，我是否执行了 if–then 计划？如果没有，下一版计划要改小、改清楚，还是换障碍？',
      reminder: _reminder(scene),
      feasibility: feasibility,
      importance: 'high',
      controllability: controllability,
      cost: cost,
      belongsToUser: belongs,
      direction: direction,
      status: 'active',
      provider: 'local',
      modelLabel: modelLabel.isEmpty ? '内置 WOOP 策略' : modelLabel,
      fromFallback: true,
    );
    return card.copyWith(aiResponse: _formatReadable(card));
  }

  String _detectScene(String text) {
    if (_containsAny(text, const ['一周', '本周复盘', '周复盘', '多个愿望', '愿望地图'])) return 'weekly_review';
    if (_containsAny(text, const ['24小时', '今天', '明天', '今日'])) return 'daily_24h';
    if (_containsAny(text, const ['障碍雷达', '反复出现', '总是卡在', '模式分析'])) return 'obstacle_radar';
    if (_containsAny(text, const ['没做到', '失败', '又没', '复盘', '坚持不了', '中断', '放弃了'])) return 'failure_review';
    if (_containsAny(text, const ['等待', '等结果', 'offer', '签证', '判决', '检查结果', '录取结果'])) return 'waiting_comfort';
    if (_containsAny(text, const ['先想象', '只是想想', '安慰一下', '暂时不行动'])) return 'fantasy_safe_explore';
    if (_containsAny(text, const ['瘦下来后', '成功以后', '想象自己', '幻想', '以后肯定', '大家都夸'])) return 'positive_fantasy';
    if (_containsAny(text, const ['改变人生', '财务自由', '彻底改变', '成为顶尖', '一年内成为', '逆袭'])) return 'large_goal';
    if (_containsAny(text, const ['还要不要坚持', '该不该放弃', '不属于我', '耗竭', '耗尽', '放下'])) return 'drop_or_adjust';
    if (_containsAny(text, const ['睡觉', '熬夜', '运动', '减肥', '饮食', '喝酒', '康复', '暴食'])) return 'health';
    if (_containsAny(text, const ['考试', '作业', '论文', '项目', '求职', '简历', '学习', '工作', '写作'])) return 'work_study';
    if (_containsAny(text, const ['伴侣', '男朋友', '女朋友', '父母', '孩子', '同事', '朋友', '沟通', '吵架', '关系'])) return 'relation';
    if (_containsAny(text, const ['焦虑', '愤怒', '生气', '冲动', '刷手机', '短视频', '逃避', '查手机'])) return 'emotion_impulse';
    if (_containsAny(text, const ['没时间', '没动力', '没资源', '没状态', '环境不好'])) return 'obstacle_diagnosis';
    if (text.length < 18 || _containsAny(text, const ['想变好', '想改变', '变优秀', '更好的人'])) return 'wish_clarify';
    return 'action_conversion';
  }

  bool _containsAny(String text, List<String> words) => words.any(text.contains);

  String _guessWish(String text, {String scene = 'action_conversion'}) {
    if (scene == 'daily_24h') return '在今天完成一个最重要的可控小行动';
    if (scene == 'weekly_review') return '整理本周愿望地图，并选出下周一个主线愿望';
    if (scene == 'obstacle_radar') return '识别反复出现的内在障碍模式并设计下一版 if–then';
    if (scene == 'fantasy_safe_explore') return '用幻想识别真实需要，并判断是否进入 WOOP 行动';
    if (scene == 'waiting_comfort') return '在等待结果期间稳定自己，并完成一个可控小行动';
    if (scene == 'large_goal') return '把宏大目标缩小成未来 7 天可推进的一个行动实验';
    if (scene == 'drop_or_adjust') return '判断这个目标是否继续、调整或有尊严地放下';
    final cleaned = text.replaceAll('\n', ' ').trim();
    final patterns = <RegExp>[
      RegExp(r'我想([^，。；;]{2,32})'),
      RegExp(r'想要([^，。；;]{2,32})'),
      RegExp(r'希望([^，。；;]{2,32})'),
      RegExp(r'目标是([^，。；;]{2,32})'),
      RegExp(r'准备([^，。；;]{2,32})'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(cleaned);
      if (m != null) {
        final v = (m.group(1) ?? '').trim();
        if (v.isNotEmpty) return v.startsWith('在') ? v : '在近期$v';
      }
    }
    if (cleaned.contains('论文')) return '本周推进论文第一稿的最小可修改版本';
    if (cleaned.contains('睡')) return '今晚按一个更可控的睡前流程上床';
    if (cleaned.contains('运动')) return '本周完成一次低门槛运动启动';
    if (cleaned.contains('学习')) return '今天完成一段 10—25 分钟的学习启动';
    if (cleaned.length <= 26) return cleaned;
    return '${cleaned.substring(0, 26)}…';
  }

  String _guessOutcome(String text, String wish) {
    if (text.contains('焦虑') || text.contains('拖延')) return '我会从反复内耗中出来，看到自己已经在现实中推进了“$wish”。';
    if (text.contains('睡') || text.contains('熬夜')) return '第二天更清醒，也重新建立“我能照顾自己”的信任。';
    if (text.contains('关系') || text.contains('伴侣') || text.contains('沟通')) return '关系里少一些控制、猜疑或压抑，多一点真实表达和安全感。';
    if (text.contains('运动') || text.contains('减肥') || text.contains('饮食')) return '身体更轻，行动感更强，不再只靠想象获得自信。';
    return '我会把愿望从脑内想象推进到现实证据中，减少内耗并建立行动感。';
  }

  _ObstacleGuess _guessObstacle(String text, {String scene = 'action_conversion'}) {
    if (scene == 'daily_24h') return const _ObstacleGuess('今天真正的障碍会在具体时刻出现，我可能临时降低优先级或等待状态变好', '今日启动阻力', <String>['优先级', '启动困难']);
    if (scene == 'weekly_review') return const _ObstacleGuess('我可能把太多愿望同时放在行动中，导致精力分散、没有主线', '目标过载', <String>['精力分散', '优先级混乱']);
    if (scene == 'obstacle_radar') return const _ObstacleGuess('同一种内在障碍反复出现，但我还没有把它设计成稳定的行动触发器', '高频障碍模式', <String>['模式重复', '计划未匹配']);
    if (scene == 'fantasy_safe_explore') return const _ObstacleGuess('我可能用美好想象获得短期安慰，却还没有把它连接到现实障碍', '幻想停留', <String>['心理达成', '需要未识别']);
    if (scene == 'waiting_comfort') return const _ObstacleGuess('我会不断反复想象结果，试图用幻想控制不可控的不确定性', '不可控等待', <String>['焦虑', '控制感不足']);
    if (scene == 'drop_or_adjust') return const _ObstacleGuess('我可能把不甘心、羞耻或他人期待误认为自己真正的愿望', '目标归属不清', <String>['不甘心', '他人期待']);
    if (_containsAny(text, const ['完美', '写不好', '做不好', '不够好'])) return const _ObstacleGuess('我害怕做得不够好，所以迟迟不开始粗糙版本', '完美主义', <String>['害怕评价', '拖延']);
    if (_containsAny(text, const ['怕', '不敢', '担心', '焦虑'])) return const _ObstacleGuess('我一想到可能失败或被评价，就用拖延来暂时降低焦虑', '害怕失败', <String>['焦虑', '回避']);
    if (_containsAny(text, const ['手机', '短视频', '刷'])) return const _ObstacleGuess('压力或无聊出现时，我会用手机快速逃离不舒服的感觉', '分心逃避', <String>['即时满足', '情绪逃避']);
    if (_containsAny(text, const ['熬夜', '睡'])) return const _ObstacleGuess('晚上疲惫时，我会用刷手机或继续娱乐补偿白天的消耗', '报复性熬夜', <String>['即时补偿', '疲惫']);
    if (_containsAny(text, const ['没时间', '太忙'])) return const _ObstacleGuess('我把任务放在较低优先级，也可能不敢拒绝其他占用时间的事情', '优先级混乱', <String>['边界不足', '时间保护']);
    if (_containsAny(text, const ['没动力', '没状态'])) return const _ObstacleGuess('行动门槛太高，我在等待理想状态出现后才开始', '等待状态', <String>['启动门槛高', '依赖情绪']);
    if (_containsAny(text, const ['父母', '别人', '应该', '必须'])) return const _ObstacleGuess('这个愿望可能夹杂他人期待，我还没有确认它是否真正属于自己', '自主性不足', <String>['应该自我', '外部压力']);
    return const _ObstacleGuess('任务一变得具体，我就会感到压力，于是想先继续计划、搜索或拖延', '拖延', <String>['压力回避', '启动困难']);
  }

  String _guessPlanThen(String text, String obstacle, {String scene = 'action_conversion'}) {
    if (scene == 'daily_24h') return '把行动压缩到 5—15 分钟，并在今天固定一个触发时刻执行';
    if (scene == 'weekly_review') return '只保留一个下周主线愿望，把其余愿望设为支持、暂存或放下';
    if (scene == 'obstacle_radar') return '选一个最高频障碍，为它写一条固定 if–then 模板并在下次触发时执行';
    if (scene == 'fantasy_safe_explore') return '写下这个幻想暴露的真实需要，再判断一个可控小动作';
    if (scene == 'large_goal') return '把目标缩小到 7 天版本，只完成一个可验证的小实验';
    if (scene == 'drop_or_adjust') return '写下继续、调整、放下三种选择的代价与价值，再选择一个最小行动';
    if (text.contains('论文') || text.contains('写作')) return '打开文档，只写 10 分钟粗糙版本，不评价质量';
    if (text.contains('学习') || text.contains('考试')) return '打开材料，只做一道题或学习 10 分钟';
    if (text.contains('睡') || text.contains('熬夜')) return '把手机放到房间外充电，并启动 10 分钟睡前流程';
    if (text.contains('运动')) return '先换上鞋，走出门或做 3 分钟轻运动';
    if (text.contains('关系') || text.contains('沟通') || text.contains('伴侣')) return '先离开冲动现场 3 分钟，再用一句话表达真实需要';
    if (text.contains('手机') || text.contains('短视频')) return '把手机放远，先做 2 分钟替代动作，例如喝水、站起或打开任务材料';
    return '把行动缩小到 5 分钟，只完成一个可以留下证据的小版本';
  }

  String _guessFirstAction(String text, String wish, {String scene = 'action_conversion'}) {
    if (scene == 'daily_24h') return '现在写下今天唯一主线行动，并设置一个 5—15 分钟启动时刻。';
    if (scene == 'weekly_review') return '用 10 分钟把愿望分为行动中、支持、暂存、放下四类。';
    if (scene == 'obstacle_radar') return '从最近失败里选一个最高频障碍，写一条新的 if–then。';
    if (scene == 'fantasy_safe_explore') return '用 5 分钟写下：这个幻想让我看见了什么需要？现在有无一个可控小动作？';
    if (scene == 'waiting_comfort') return '用 5 分钟写下：不可控的事、可控的一件小事、我现在需要的安慰。';
    if (scene == 'drop_or_adjust') return '用 10 分钟写下继续、调整、放下各自的代价与收获。';
    if (scene == 'large_goal') return '把大目标改写成一个 7 天可验证的小实验。';
    if (text.contains('论文') || text.contains('写作')) return '打开文档，写下第一个小标题下面的 5 句话。';
    if (text.contains('睡') || text.contains('熬夜')) return '今晚提前 10 分钟把手机充电器放到房间外。';
    if (text.contains('学习') || text.contains('考试')) return '打开学习材料，设置 10 分钟计时器，只完成第一小段。';
    if (text.contains('运动')) return '换上运动鞋，走出门 5 分钟。';
    return '在 5—10 分钟内完成“$wish”的最小可见版本。';
  }

  String _guessDirection(String text, String scene) {
    if (scene == 'waiting_comfort') return 'wait';
    if (scene == 'drop_or_adjust') return text.contains('放下') || text.contains('不属于我') ? 'drop' : 'adjust';
    if (scene == 'large_goal') return 'adjust';
    return 'continue';
  }

  String _guessFeasibility(String text, String scene) {
    if (scene == 'waiting_comfort') return 'low';
    if (scene == 'large_goal' || scene == 'drop_or_adjust') return 'medium';
    if (_containsAny(text, const ['今天', '本周', '10分钟', '一点', '第一步'])) return 'high';
    return 'medium';
  }

  String _guessControllability(String text) {
    if (_containsAny(text, const ['别人', '录取', '结果', '判决', '天气', '市场'])) return 'low';
    if (_containsAny(text, const ['今天', '我可以', '打开', '写', '做', '联系'])) return 'high';
    return 'medium';
  }

  String _currentJudgement(String scene, String direction) {
    switch (scene) {
      case 'wish_clarify':
        return '愿望还需要从“想变好”改写为当前阶段可推进的具体愿望。';
      case 'positive_fantasy':
        return '你已经看见了有吸引力的未来，但还需要把它与现实障碍相连接。';
      case 'failure_review':
        return '这次没有完成计划不是人格失败，而是暴露了原计划没有覆盖的真实障碍。';
      case 'daily_24h':
        return '这是 24 小时 WOOP，适合只保留今天最重要的一件可控行动。';
      case 'weekly_review':
        return '当前适合整理愿望地图，把精力从过多目标重新分配到下周主线。';
      case 'obstacle_radar':
        return '当前重点不是再立新目标，而是识别反复出现的障碍模式并改写计划。';
      case 'fantasy_safe_explore':
        return '当前可先允许幻想发挥安慰和探索作用，再判断是否进入现实行动。';
      case 'waiting_comfort':
        return '当前处于低可控等待场景，适合先稳定情绪，再抓住一件小范围可控行动。';
      case 'large_goal':
        return '目标价值可能重要，但当前版本过大，需要缩小成 7 天行动实验。';
      case 'drop_or_adjust':
        return direction == 'drop' ? '这个目标可能需要有尊严地放下，避免继续消耗。' : '这个目标需要重新判断继续、调整或放下，而不是盲目硬扛。';
      default:
        return '愿望已经可以进入 WOOP：看见最佳结果，识别内在障碍，并制定 if–then 计划。';
    }
  }

  String _reminder(String scene) {
    if (scene == 'health') return '健康相关建议不能替代医生、营养师或心理专业支持；身体异常请优先咨询专业人士。';
    if (scene == 'waiting_comfort') return '低可控场景中，幻想可以短期安慰你，但不要用它替代可控小行动。';
    if (scene == 'drop_or_adjust') return '放下不是失败；有时是把有限生命能量从不再属于你的目标中收回来。';
    return '不要只停留在积极想象里；当障碍出现时，让它成为行动按钮。';
  }

  String _shortTitle(String wish) {
    final w = wish.trim();
    if (w.isEmpty) return 'WOOP 行动卡';
    return w.length <= 18 ? w : '${w.substring(0, 18)}…';
  }

  String _formatReadable(WoopActionCard card) {
    return '''
【当前判断】
${card.currentJudgement}

【W｜愿望】
${card.wish}

【O｜最佳结果】
${card.outcome}

【O｜关键内在障碍】
${card.obstacle}

【P｜如果—那么计划】
如果 ${card.planIf}，那么我就 ${card.planThen}。

【第一步行动】
${card.firstAction}

【复盘问题】
${card.reviewQuestion}

【提醒】
${card.reminder}
'''.trim();
  }
}

class _ObstacleGuess {
  final String item1;
  final String item2;
  final List<String> item3;
  const _ObstacleGuess(this.item1, this.item2, this.item3);
}
