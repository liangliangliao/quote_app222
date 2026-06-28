import 'dart:convert';

import '../services/unified_ai_service.dart';
import 'action_mind_models.dart';
import 'action_mind_prompt_config.dart';

class ActionMindAiService {
  final UnifiedAiService _ai = UnifiedAiService();
  final ActionMindPromptConfig _prompts = ActionMindPromptConfig();

  Future<ActionMindSession> generate({
    required String scene,
    required String userInput,
    required ActionMindProfile profile,
    required String recentContextJson,
    required String goalsJson,
    String outputMode = 'common',
  }) async {
    final fallback = localAnalyze(scene: scene, userInput: userInput, profile: profile, outputMode: outputMode);
    final prompt = await _prompts.buildPrompt(
      scene: scene,
      userInput: userInput,
      profileJson: profile.encode(),
      recentContextJson: recentContextJson,
      goalsJson: goalsJson,
      outputMode: outputMode == 'json' ? 'json' : outputMode,
    );
    try {
      final raw = await _ai.generateText(
        prompt: prompt,
        purpose: 'action_mind.action_psychology_coach',
        systemPrompt: outputMode == 'json' ? '只输出一个JSON对象，不要解释。' : null,
        maxTokens: outputMode == 'quick' ? 1600 : 4200,
        expectJson: outputMode == 'json',
        temperature: 0.25,
      );
      if (raw.trim().isEmpty) return fallback;
      if (outputMode == 'json') {
        final parsed = _tryParse(raw, scene: scene, userInput: userInput);
        if (parsed != null && parsed.aiResponse.trim().isNotEmpty) return parsed;
      }
      return fallbackFromText(scene: scene, userInput: userInput, raw: raw, outputMode: outputMode);
    } catch (_) {
      return fallback;
    }
  }

  ActionMindSession fallbackFromText({required String scene, required String userInput, required String raw, String outputMode = 'common'}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final base = localAnalyze(scene: scene, userInput: userInput, profile: const ActionMindProfile(), outputMode: outputMode);
    return ActionMindSession(
      createdAtMs: now,
      scene: scene,
      userInput: userInput.trim(),
      aiResponse: raw.trim(),
      targetClarification: base.targetClarification,
      mechanismDiagnosis: base.mechanismDiagnosis,
      rewrittenGoal: base.rewrittenGoal,
      realityObstacle: base.realityObstacle,
      processSimulation: base.processSimulation,
      plan: base.plan,
      emotionHandling: base.emotionHandling,
      socialCorrection: base.socialCorrection,
      feedbackQuestions: base.feedbackQuestions,
      finalAction: base.finalAction,
      riskLevel: base.riskLevel,
    );
  }

  ActionMindSession localAnalyze({
    required String scene,
    required String userInput,
    required ActionMindProfile profile,
    String outputMode = 'common',
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final input = userInput.trim().isEmpty ? '我有一个重要目标，但还没有开始行动。' : userInput.trim();
    final risk = _detectRisk(input);
    if (risk == 'high' || risk == 'crisis') {
      return ActionMindSession(
        createdAtMs: now,
        scene: scene,
        userInput: input,
        aiResponse: '我很在意你现在的安全。此刻已经不适合只做自助行动设计：请立即联系当地紧急服务、危机热线、专业人员，或让身边可信赖的人陪你一起处理；先远离可能伤害自己或他人的工具和环境。',
        targetClarification: '当前最高目标是安全，而不是效率或目标推进。',
        mechanismDiagnosis: '存在高风险表达，需要真实世界支持。',
        finalAction: '现在，请立刻联系一个具体的人或当地紧急服务。',
        riskLevel: risk,
      );
    }

    final value = _detectValue(input, profile);
    final emotion = _detectEmotion(input, scene);
    final obstacle = _detectObstacle(input, scene);
    final source = _detectSource(input);
    final intrinsicExternal = _detectIntrinsicExternal(input);
    final approachAvoidance = _detectApproachAvoidance(input);
    final idealOught = _detectIdealOught(input);
    final title = _shortTitle(input, scene);
    final rewritten = '我想通过${_throughAction(input, scene)}，在接下来 7 天内推进“$title”，因为它服务于我的$value价值。';
    final plan = _buildPlan(input: input, scene: scene, value: value, obstacle: obstacle);
    final target = '表面目标：$title。深层目标：通过一个具体行动系统恢复掌控感、成长感和意义感。目标来源：$source；目标内容：$intrinsicExternal；方向：$approachAvoidance；自我标准：$idealOught。';
    final mechanism = _mechanism(scene: scene, input: input, obstacle: obstacle, emotion: emotion);
    final process = '1. 先把目标从“想清楚/做到完美”降到“开始一个可观察动作”。\n2. 看到最大障碍：$obstacle。\n3. 按 if–then 计划进入最低行动：${plan.minimumAction}。\n4. 完成后只复盘实际障碍，不做人格审判。';
    final emotionHandling = _emotionHandling(emotion, scene, value);
    final social = scene == 'social'
        ? '互动前先区分：我是想准确理解事实，还是想保护自尊、证明自己、控制对方或留下好印象？成熟表达：我现在的目标不是赢，而是把事实、感受和请求说清楚。下一句可说：我想先确认一件事，我理解的是____，你真实想表达的是____吗？'
        : '若涉及他人，先检查自己是否把对方简化为“满足/阻碍我目标的人”，再回到准确理解与清晰表达。';
    final feedback = '1. 我是否完成了最低行动？\n2. 实际障碍是目标、计划、资源、情绪、环境、他人还是无意识习惯？\n3. 这个行动是否更靠近$value？\n4. 下一次 if–then 计划需要怎样缩小或换情境？';
    final finalAction = '现在，请在 5 分钟内，完成：${plan.minimumAction}。';
    final response = _compose(
      target: target,
      mechanism: mechanism,
      rewritten: rewritten,
      obstacle: obstacle,
      process: process,
      plan: plan,
      emotionHandling: emotionHandling,
      social: social,
      feedback: feedback,
      finalAction: finalAction,
      quick: outputMode == 'quick',
    );
    return ActionMindSession(
      createdAtMs: now,
      scene: scene,
      userInput: input,
      aiResponse: response,
      targetClarification: target,
      mechanismDiagnosis: mechanism,
      rewrittenGoal: rewritten,
      realityObstacle: obstacle,
      processSimulation: process,
      plan: plan,
      emotionHandling: emotionHandling,
      socialCorrection: social,
      feedbackQuestions: feedback,
      finalAction: finalAction,
      riskLevel: risk,
    );
  }

  ActionMindSession? _tryParse(String raw, {required String scene, required String userInput}) {
    final text = _extractJsonObject(raw);
    if (text.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return null;
      final map = decoded.cast<String, dynamic>();
      final plan = ActionMindPlan.fromJson(_asMap(map['plan']));
      return ActionMindSession(
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        scene: scene,
        userInput: userInput.trim(),
        aiResponse: (map['ai_response'] ?? '').toString(),
        targetClarification: (map['target_clarification'] ?? '').toString(),
        mechanismDiagnosis: (map['mechanism_diagnosis'] ?? '').toString(),
        rewrittenGoal: (map['rewritten_goal'] ?? '').toString(),
        realityObstacle: (map['reality_obstacle'] ?? '').toString(),
        processSimulation: (map['process_simulation'] ?? '').toString(),
        plan: plan,
        emotionHandling: (map['emotion_handling'] ?? '').toString(),
        socialCorrection: (map['social_correction'] ?? '').toString(),
        feedbackQuestions: (map['feedback_questions'] ?? '').toString(),
        finalAction: (map['final_action'] ?? '').toString(),
        riskLevel: (map['risk_level'] ?? 'none').toString(),
        rawJson: text,
      );
    } catch (_) {
      return null;
    }
  }

  String _extractJsonObject(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text
          .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
          .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
          .replaceAll('```', '')
          .trim();
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) return text.substring(start, end + 1);
    return text;
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.map((key, value) => MapEntry(key.toString(), value));
    return <String, dynamic>{};
  }

  String _detectRisk(String input) {
    final text = input.toLowerCase();
    const crisis = ['自杀', '杀了自己', '不想活', '结束生命', '伤害自己', '伤害别人', 'kill myself', 'suicide'];
    if (crisis.any(text.contains)) return 'crisis';
    const high = ['活不下去', '撑不下去', '报复', '毁掉', '彻底消失'];
    if (high.any(text.contains)) return 'high';
    return 'none';
  }

  String _detectValue(String input, ActionMindProfile profile) {
    for (final v in profile.coreValues) {
      if (v.trim().isNotEmpty && input.contains(v.trim())) return v.trim();
    }
    const values = ['成长', '健康', '关系', '亲密', '自由', '创造', '贡献', '学习', '责任', '真诚', '意义', '专业', '家庭'];
    for (final v in values) {
      if (input.contains(v)) return v;
    }
    return profile.coreValues.isNotEmpty ? profile.coreValues.first : '成长';
  }

  String _detectEmotion(String input, String scene) {
    const emotions = ['焦虑', '害怕', '恐惧', '沮丧', '难过', '愤怒', '生气', '羞耻', '内疚', '空虚', '厌烦', '麻木', '兴奋', '疲惫'];
    for (final e in emotions) {
      if (input.contains(e)) return e;
    }
    if (scene == 'emotion') return '当前强烈情绪';
    if (scene == 'procrastination') return '抗拒/焦虑';
    if (scene == 'failure') return '挫败/自责';
    return '不确定/轻微压力';
  }

  String _detectObstacle(String input, String scene) {
    if (input.contains('手机') || input.contains('短视频') || input.contains('游戏')) return '自动化诱惑线索强，短期奖励盖过长期目标';
    if (input.contains('完美') || input.contains('做不好')) return '完美主义规则和失败恐惧让启动成本过高';
    if (input.contains('没时间') || input.contains('太忙')) return '时间资源不足，需要把目标拆成低维护行动';
    if (input.contains('没意义') || input.contains('迷茫')) return '目标与内在价值连接不清，意义感不足';
    if (scene == 'social') return '互动中可能混合了准确理解、防御自尊和印象管理目标';
    if (scene == 'habit') return '环境线索和即时奖励已经自动化';
    if (scene == 'emotion') return '情绪提示某个重要目标受阻，需要先恢复控制感';
    return '目标还没有绑定到具体情境，行动启动线索不足';
  }

  String _detectSource(String input) {
    if (input.contains('别人') || input.contains('父母') || input.contains('领导') || input.contains('认可')) return '外部期待/社会评价可能参与其中';
    if (input.contains('证明') || input.contains('不是废物') || input.contains('没用')) return '自尊防御和证明自己可能参与其中';
    if (input.contains('必须') || input.contains('应该')) return '责任义务和应该自我较强';
    return '成长需要与自主选择为主，但仍需通过行动验证';
  }

  String _detectIntrinsicExternal(String input) {
    if (input.contains('赚钱') || input.contains('年入') || input.contains('认可') || input.contains('面子') || input.contains('证明')) return '外在指标较明显，需要重新连接到自主价值';
    return '偏内在目标，可继续强化成长、关系、意义和能力感';
  }

  String _detectApproachAvoidance(String input) {
    if (input.contains('不要') || input.contains('不想') || input.contains('逃') || input.contains('避免') || input.contains('害怕')) return '回避型动力较强，建议改写为接近型成长目标';
    return '接近型目标较明显';
  }

  String _detectIdealOught(String input) {
    if (input.contains('必须') || input.contains('应该') || input.contains('不得不')) return '应该自我较强，容易焦虑';
    return '理想自我与成长愿景较明显';
  }

  String _shortTitle(String input, String scene) {
    final oneLine = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (oneLine.length <= 22) return oneLine;
    if (scene == 'procrastination') return '启动一个被拖延的重要任务';
    if (scene == 'emotion') return '把情绪信号转化为下一步行动';
    if (scene == 'habit') return '重构自动化习惯';
    if (scene == 'social') return '完成一次更成熟的沟通';
    return oneLine.substring(0, 22);
  }

  String _throughAction(String input, String scene) {
    if (scene == 'habit') return '重设计环境线索并替换一个即时奖励行为';
    if (scene == 'social') return '先澄清事实与目标，再说出一个具体请求';
    if (scene == 'emotion') return '读懂情绪信号并完成一个 3 分钟恢复动作';
    if (scene == 'procrastination') return '先完成一个 5 分钟最低行动';
    return '把愿望拆成一个具体情境中的小行动';
  }

  ActionMindPlan _buildPlan({required String input, required String scene, required String value, required String obstacle}) {
    String trigger = '我坐到桌前或打开手机准备逃避时';
    String action = '打开最重要任务，只做 5 分钟，不要求做好';
    String min = '打开任务入口，完成 5 分钟或写下第一句话';
    String standard = '专注 25 分钟并留下一个可见进展';
    String challenge = '完成一个可提交/可分享/可复盘的小成果';
    if (scene == 'emotion') {
      trigger = '我发现情绪升高到影响行动时';
      action = '命名情绪，做 6 次慢呼气，再选择一个 3 分钟可控动作';
      min = '写下：这个情绪在提示哪个目标受阻';
      standard = '完成 10 分钟恢复 + 10 分钟目标推进';
      challenge = '完成一次完整复盘并更新明天计划';
    } else if (scene == 'long_goal') {
      trigger = '我准备规划长期目标或感到方向太大时';
      action = '先写四层目标：身份层、价值层、项目层、今日行动层';
      min = '只写一句身份方向和一个今天可做的小动作';
      standard = '形成 3 个月项目目标 + 本周行动 + 今日最低行动';
      challenge = '检查内在/外在比例、目标冲突和阶段性反馈指标';
    } else if (scene == 'fantasy') {
      trigger = '我沉浸在成功画面但没有现实动作时';
      action = '写下最想要的未来，再写一个当前最真实障碍，并把它转为第一步';
      min = '完成一组“未来愿景 × 现实障碍”心理对照';
      standard = '模拟从现在到第一步的 3 个过程动作';
      challenge = '形成障碍应对 if–then 并立刻执行最低行动';
    } else if (scene == 'failure') {
      trigger = '我把一次没做到解释成“我不行”或想放弃时';
      action = '区分事实失败和自我评价失败，并找到一个可学习变量';
      min = '写下：事实发生了什么，不给人格下结论';
      standard = '找出一个失败原因并重建更小下一步';
      challenge = '完成失败复盘并保存下一次 if–then';
    } else if (scene == 'habit') {
      trigger = '我想打开诱惑 App 或进入自动化坏习惯时';
      action = '把手机/诱惑物移出手边，做一个替代行为：喝水、走动或打开阅读/任务入口 2 分钟';
      min = '把诱惑物移开，并做 2 分钟替代行为';
      standard = '完成 10 分钟替代行为并记录触发线索';
      challenge = '重新设计一个环境线索，让好行为更容易启动';
    } else if (scene == 'social') {
      trigger = '我想立刻反击、冷战、讨好或证明自己时';
      action = '先写下事实、我的感受、我的请求，再说一句非攻击表达';
      min = '只写下事实和一个请求，不立刻攻击或冷战';
      standard = '完成一次 10 分钟内的清晰沟通';
      challenge = '沟通后复盘：我的期待是否影响了对方反应';
    } else if (scene == 'goal_conflict' || scene == 'weekly_system') {
      trigger = '我同时被多个目标拉扯或开始新的一周时';
      action = '把目标分为主线目标、支持目标、冲突目标、外部压力目标和暂停目标';
      min = '只选出本周 1 个主线目标和今天 1 个最低行动';
      standard = '确定 1 个主线目标 + 2 个支持目标 + 需要暂停/降级的目标';
      challenge = '生成每周目标系统图并为三个关键情境绑定 if–then';
    } else if (scene == 'review') {
      trigger = '一天结束或行动没有按计划发生时';
      action = '复盘进展、差距、原因、情绪反馈和下一次 if–then';
      min = '回答：我是否完成最低行动？实际障碍是什么？';
      standard = '完成一次五问复盘并更新计划';
      challenge = '把复盘结论写回目标系统和执行意图库';
    } else if (scene == 'daily_cockpit') {
      trigger = '我开始今天第一个行动块时';
      action = '根据主目标、情绪、能量和障碍选择最低行动';
      min = '用 3–5 分钟推进今天主目标的入口动作';
      standard = '完成 25 分钟目标推进并记录一个证据';
      challenge = '完成一个可提交的小成果，并安排晚间复盘';
    }
    return ActionMindPlan(
      trigger: trigger,
      action: action,
      obstaclePlan: '如果出现“$obstacle”，我就把行动缩小到最低版本：$min。',
      temptationPlan: '如果我想逃向即时奖励，我就先延迟 10 分钟，并用替代行为保护$value。',
      minimumAction: min,
      standardAction: standard,
      challengeAction: challenge,
      environmentCue: '把启动材料放到最显眼位置，把诱惑物放远或增加一步阻力。',
      status: 'active',
    );
  }

  String _mechanism({required String scene, required String input, required String obstacle, required String emotion}) {
    final parts = <String>['当前主要卡点：$obstacle。'];
    if (scene == 'procrastination') parts.add('可能机制：拖延正在短期保护你免于失败感、羞耻或不确定，而不是简单懒惰。');
    if (scene == 'failure') parts.add('可能机制：一次事实失败被扩大成自我评价失败，需要从人格审判回到策略学习。');
    if (scene == 'long_goal') parts.add('可能机制：目标层级还没有打通，身份/价值太抽象，行动层太少，导致长期目标无法落地。');
    if (scene == 'fantasy') parts.add('可能机制：积极幻想提前消费成功感，但没有与现实障碍相撞。');
    if (scene == 'habit') parts.add('可能机制：环境线索自动启动即时奖励，单靠“不要做”容易反讽。');
    if (scene == 'social') parts.add('可能机制：互动目标混杂，防御自尊或印象管理可能覆盖准确理解。');
    if (scene == 'goal_conflict') parts.add('可能机制：多个目标争夺时间、情绪、身份和资源，需要主线/支持/暂停分层。');
    if (scene == 'weekly_system') parts.add('可能机制：行动不是单一任务，而是多目标生活系统，需要每周重新排序和降噪。');
    if (scene == 'review') parts.add('可能机制：复盘若变成人格审判会削弱行动；复盘应回到差距原因和计划更新。');
    if (scene == 'daily_cockpit') parts.add('可能机制：今天的行动质量取决于主目标、情绪、能量、障碍和环境线索是否被放进同一张行动卡。');
    parts.add('情绪信号：$emotion。资源判断：先按最低行动启动，再决定是否升级。');
    return parts.join('\n');
  }

  String _emotionHandling(String emotion, String scene, String value) {
    return '这个情绪可能在提示：某个重要目标受阻，或你需要恢复控制感。不要急着压下它，也不要让它替你开车。3 分钟动作：慢呼气 6 次，写下“我现在能控制的一件事”，然后用最低行动靠近$value。';
  }

  String _compose({
    required String target,
    required String mechanism,
    required String rewritten,
    required String obstacle,
    required String process,
    required ActionMindPlan plan,
    required String emotionHandling,
    required String social,
    required String feedback,
    required String finalAction,
    bool quick = false,
  }) {
    if (quick) {
      return '''【真实目标】
$target

【当前卡点】
$mechanism

【目标重写】
$rewritten

【if–then】
${plan.ifThen}

【三档行动】
最低：${plan.minimumAction}
标准：${plan.standardAction}
挑战：${plan.challengeAction}

【现在】
$finalAction''';
    }
    return '''【1. 目标澄清】
$target

【2. 行动机制诊断】
$mechanism

【3. 目标重写】
$rewritten

【4. 现实障碍】
最大现实障碍：$obstacle
障碍类型可能是：资源/能力/情绪/环境/关系/目标冲突/计划不清/自我防御中的一种或多种。

【5. 过程模拟】
$process

【6. if–then 执行意图】
启动计划：${plan.ifThen}
障碍应对：${plan.obstaclePlan}
诱惑替代：${plan.temptationPlan}
环境线索：${plan.environmentCue}

【7. 今日三档行动】
最低行动：${plan.minimumAction}
标准行动：${plan.standardAction}
挑战行动：${plan.challengeAction}

【8. 情绪处理】
$emotionHandling

【9. 社会互动校正】
$social

【10. 反馈问题】
$feedback

【11. 最终一句行动指令】
$finalAction''';
  }
}
