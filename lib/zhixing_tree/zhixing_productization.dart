import 'dart:math' as math;

import 'zhixing_models.dart';

/// The four deliberately different ways a user can experience the same
/// knowledge-to-action loop. They change load, language and feedback, never
/// the safety boundary or the reviewed knowledge package.
enum ZxExperienceMode { gentle, direct, challenge, experiment }

extension ZxExperienceModeX on ZxExperienceMode {
  String get key => name;

  String get label => switch (this) {
        ZxExperienceMode.gentle => '温和启动',
        ZxExperienceMode.direct => '直接执行',
        ZxExperienceMode.challenge => '挑战突破',
        ZxExperienceMode.experiment => '好奇实验',
      };

  String get description => switch (this) {
        ZxExperienceMode.gentle => '低能量也能开始，允许30秒降级动作。',
        ZxExperienceMode.direct => '只给一个清楚动作和完成标准。',
        ZxExperienceMode.challenge => '容量足够时提高反馈强度，不用羞耻施压。',
        ZxExperienceMode.experiment => '把行动当作求证，不把成败等同于自我价值。',
      };

  static ZxExperienceMode parse(Object? raw) =>
      ZxExperienceMode.values.firstWhere(
        (item) => item.name == raw.toString(),
        orElse: () => ZxExperienceMode.direct,
      );
}

/// One-tap description of the user's present obstacle. This is not a mental
/// health diagnosis; it only supplies enough situational evidence to choose a
/// useful, testable first action.
enum ZxStarterBlock { unclear, inertia, fear, lowEnergy, environment }

extension ZxStarterBlockX on ZxStarterBlock {
  String get label => switch (this) {
        ZxStarterBlock.unclear => '不知道第一步',
        ZxStarterBlock.inertia => '知道但没启动',
        ZxStarterBlock.fear => '担心失败或做不好',
        ZxStarterBlock.lowEnergy => '现在精力很低',
        ZxStarterBlock.environment => '时间/工具/环境卡住',
      };

  String get shortLabel => switch (this) {
        ZxStarterBlock.unclear => '不清楚',
        ZxStarterBlock.inertia => '没启动',
        ZxStarterBlock.fear => '怕失败',
        ZxStarterBlock.lowEnergy => '低能量',
        ZxStarterBlock.environment => '环境卡住',
      };
}

enum ZxMotivationAnchor { meaning, progress, curiosity, achievement, connection }

extension ZxMotivationAnchorX on ZxMotivationAnchor {
  String get label => switch (this) {
        ZxMotivationAnchor.meaning => '意义与价值',
        ZxMotivationAnchor.progress => '看见进度',
        ZxMotivationAnchor.curiosity => '好奇与发现',
        ZxMotivationAnchor.achievement => '挑战与成就',
        ZxMotivationAnchor.connection => '陪伴与责任',
      };

  String get reason => switch (this) {
        ZxMotivationAnchor.meaning => '这一步服务我真正认领的价值。',
        ZxMotivationAnchor.progress => '完成一个可见进度，比继续想象更有用。',
        ZxMotivationAnchor.curiosity => '我想用行动发现事实，而不是提前给自己定论。',
        ZxMotivationAnchor.achievement => '我愿意完成一个可控挑战并获得真实反馈。',
        ZxMotivationAnchor.connection => '这一步回应我对自己或重要他人的责任。',
      };

  static ZxMotivationAnchor parse(Object? raw) =>
      ZxMotivationAnchor.values.firstWhere(
        (item) => item.name == raw.toString(),
        orElse: () => ZxMotivationAnchor.progress,
      );
}

enum ZxMentorTone { warm, concise, challenger }

extension ZxMentorToneX on ZxMentorTone {
  String get label => switch (this) {
        ZxMentorTone.warm => '温和陪伴',
        ZxMentorTone.concise => '简短直接',
        ZxMentorTone.challenger => '坚定挑战',
      };

  String get nudge => switch (this) {
        ZxMentorTone.warm => '不用一次解决全部，只保护眼前这一小步。',
        ZxMentorTone.concise => '别继续准备：现在只完成屏幕上的一个动作。',
        ZxMentorTone.challenger => '把力量用在可控动作上，用现实结果回答怀疑。',
      };

  static ZxMentorTone parse(Object? raw) => ZxMentorTone.values.firstWhere(
        (item) => item.name == raw.toString(),
        orElse: () => ZxMentorTone.concise,
      );
}

enum ZxStrengthPreference { planning, curiosity, persistence, creativity, connection }

extension ZxStrengthPreferenceX on ZxStrengthPreference {
  String get label => switch (this) {
        ZxStrengthPreference.planning => '梳理与计划',
        ZxStrengthPreference.curiosity => '观察与学习',
        ZxStrengthPreference.persistence => '坚持与完成',
        ZxStrengthPreference.creativity => '创造与变通',
        ZxStrengthPreference.connection => '协作与连接',
      };

  static ZxStrengthPreference parse(Object? raw) =>
      ZxStrengthPreference.values.firstWhere(
        (item) => item.name == raw.toString(),
        orElse: () => ZxStrengthPreference.planning,
      );
}

class ZxActionPreference {
  const ZxActionPreference({
    this.mode = ZxExperienceMode.direct,
    this.anchor = ZxMotivationAnchor.progress,
    this.tone = ZxMentorTone.concise,
    this.strength = ZxStrengthPreference.planning,
    this.completed = false,
    this.updatedAtMs = 0,
  });

  final ZxExperienceMode mode;
  final ZxMotivationAnchor anchor;
  final ZxMentorTone tone;
  final ZxStrengthPreference strength;
  final bool completed;
  final int updatedAtMs;

  String get summary => mode.label + ' · ' + anchor.label + ' · ' + tone.label;

  Map<String, Object?> toJson() => <String, Object?>{
        'mode': mode.name,
        'anchor': anchor.name,
        'tone': tone.name,
        'strength': strength.name,
        'completed': completed,
        'updated_at_ms': updatedAtMs,
      };

  factory ZxActionPreference.fromJson(Map<String, dynamic> map) =>
      ZxActionPreference(
        mode: ZxExperienceModeX.parse(map['mode']),
        anchor: ZxMotivationAnchorX.parse(map['anchor']),
        tone: ZxMentorToneX.parse(map['tone']),
        strength: ZxStrengthPreferenceX.parse(map['strength']),
        completed: map['completed'] == true || map['completed'] == 1,
        updatedAtMs: _asInt(map['updated_at_ms']),
      );

  ZxActionPreference copyWith({
    ZxExperienceMode? mode,
    ZxMotivationAnchor? anchor,
    ZxMentorTone? tone,
    ZxStrengthPreference? strength,
    bool? completed,
    int? updatedAtMs,
  }) =>
      ZxActionPreference(
        mode: mode ?? this.mode,
        anchor: anchor ?? this.anchor,
        tone: tone ?? this.tone,
        strength: strength ?? this.strength,
        completed: completed ?? this.completed,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      );
}

class ZxStarterCase {
  const ZxStarterCase({
    required this.id,
    required this.title,
    required this.goal,
    required this.nextStep,
    required this.valueReason,
    required this.block,
    required this.mode,
    required this.minutes,
    required this.expectedOutput,
  });

  final String id;
  final String title;
  final String goal;
  final String nextStep;
  final String valueReason;
  final ZxStarterBlock block;
  final ZxExperienceMode mode;
  final int minutes;
  final String expectedOutput;
}

const List<ZxStarterCase> zxStarterCases = <ZxStarterCase>[
  ZxStarterCase(
    id: 'job_first_application',
    title: '求职：投递第一份',
    goal: '完成今天第一份求职投递',
    nextStep: '打开一条匹配岗位，核对三项要求并投递',
    valueReason: '恢复工作与收入，让生活重新向上推进。',
    block: ZxStarterBlock.inertia,
    mode: ZxExperienceMode.direct,
    minutes: 10,
    expectedOutput: '一个可在10分钟内开始、以“已提交或形成明确差距”为证据的动作。',
  ),
  ZxStarterCase(
    id: 'walk_outside',
    title: '运动：出门走一小段',
    goal: '出去走一走',
    nextStep: '穿鞋、拿钥匙并走到楼下',
    valueReason: '先恢复身体与注意力，不要求一次完成高强度运动。',
    block: ZxStarterBlock.lowEnergy,
    mode: ZxExperienceMode.gentle,
    minutes: 5,
    expectedOutput: '低能量可执行，并提供“只穿鞋站到门口”的降级动作。',
  ),
  ZxStarterCase(
    id: 'write_first_sentence',
    title: '写作：写出第一句',
    goal: '开始写一篇文章',
    nextStep: '打开文档并写一句暂时不必完美的主题句',
    valueReason: '用真实文字发现自己到底想表达什么。',
    block: ZxStarterBlock.fear,
    mode: ZxExperienceMode.experiment,
    minutes: 5,
    expectedOutput: '把完美压力改成可撤销的小实验，以文档中出现一句话为完成证据。',
  ),
  ZxStarterCase(
    id: 'prepare_workspace',
    title: '整理：准备一个入口',
    goal: '让桌面可以开始工作',
    nextStep: '只清出电脑前一块可以放手的空间',
    valueReason: '降低下一次启动的环境阻力。',
    block: ZxStarterBlock.environment,
    mode: ZxExperienceMode.direct,
    minutes: 5,
    expectedOutput: '不要求整理完整房间，只产出一个下一次能直接工作的入口。',
  ),
];

class ZxProductizationEngine {
  const ZxProductizationEngine();

  ZxSituationInput buildInput({
    required String goal,
    String nextStep = '',
    String valueReason = '',
    int availableMinutes = 5,
    ZxStarterBlock block = ZxStarterBlock.inertia,
    ZxActionPreference preference = const ZxActionPreference(),
    String cue = '',
    bool thirdPartyImpact = false,
    bool irreversibleImpact = false,
    bool professionalDecision = false,
    bool acuteDanger = false,
    bool severeFunctionLoss = false,
  }) {
    final cleanGoal = goal.trim();
    if (cleanGoal.isEmpty) {
      throw ArgumentError.value(goal, 'goal', 'Goal must not be empty.');
    }
    final minutes = _effectiveMinutes(availableMinutes, preference.mode);
    final target = nextStep.trim().isNotEmpty
        ? nextStep.trim()
        : _defaultTarget(cleanGoal, block);
    final lowEnergy = block == ZxStarterBlock.lowEnergy;
    final fear = block == ZxStarterBlock.fear;
    final unclear = block == ZxStarterBlock.unclear;
    final environment = block == ZxStarterBlock.environment;
    final inertia = block == ZxStarterBlock.inertia;
    final reason = valueReason.trim().isEmpty
        ? preference.anchor.reason
        : valueReason.trim();
    return ZxSituationInput(
      goalTitle: cleanGoal,
      recentEvent: '我现在想推进“' + cleanGoal + '”，当前最接近的卡点是“' + block.label + '”。',
      targetBehavior: target,
      valueReason: reason,
      thought: fear
          ? '我担心失败、做不好或再次证明自己不行。'
          : unclear
              ? '我不知道真正的第一步是什么。'
              : '',
      emotion: fear ? '担心或焦虑' : lowEnergy ? '疲惫或低能量' : '',
      urge: inertia ? '想等状态更好、先做别的或继续准备' : '',
      actualAction: inertia ? '尚未开始，可能正在拖延或回避入口' : '',
      cue: cue.trim(),
      availableMinutes: minutes,
      bodyCapacity: lowEnergy ? 0.3 : 0.65,
      attentionCapacity: lowEnergy ? 0.35 : 0.62,
      sleepCapacity: lowEnergy ? 0.35 : 0.65,
      autonomy: preference.anchor == ZxMotivationAnchor.meaning ? 0.82 : 0.68,
      importance: preference.anchor == ZxMotivationAnchor.achievement ? 0.82 : 0.72,
      selfEfficacy: fear
          ? 0.34
          : unclear
              ? 0.42
              : preference.mode == ZxExperienceMode.challenge
                  ? 0.68
                  : 0.54,
      knowsHow: !unclear,
      hasTime: !environment,
      hasTools: !environment,
      hasSupport: true,
      waitingForMood: inertia,
      positiveFantasy: false,
      thirdPartyImpact: thirdPartyImpact,
      irreversibleImpact: irreversibleImpact,
      professionalDecision: professionalDecision,
      acuteDanger: acuteDanger,
      severeFunctionLoss: severeFunctionLoss,
      previousAttempts: block.label,
    );
  }

  String motivationLine(ZxActionPreference preference) {
    final strength = switch (preference.strength) {
      ZxStrengthPreference.planning => '你擅长梳理；今天只梳理到能开始为止。',
      ZxStrengthPreference.curiosity => '用好奇代替自我审判，让现实给出答案。',
      ZxStrengthPreference.persistence => '把坚持缩成眼前这一轮，而不是要求永远不退。',
      ZxStrengthPreference.creativity => '如果正面硬推无效，就允许自己换一个入口。',
      ZxStrengthPreference.connection => '把需要的支持变成一个具体、可回答的请求。',
    };
    return preference.tone.nudge + ' ' + strength;
  }

  int _effectiveMinutes(int requested, ZxExperienceMode mode) {
    final value = requested.clamp(2, 30).toInt();
    return switch (mode) {
      ZxExperienceMode.gentle => math.min(5, value),
      ZxExperienceMode.direct => value,
      ZxExperienceMode.challenge => math.max(10, value),
      ZxExperienceMode.experiment => math.min(15, value),
    };
  }

  String _defaultTarget(String goal, ZxStarterBlock block) => switch (block) {
        ZxStarterBlock.unclear => '找出“' + goal + '”的第一个可执行步骤',
        ZxStarterBlock.inertia => '打开“' + goal + '”的第一个可见入口',
        ZxStarterBlock.fear => '完成“' + goal + '”的一次可撤销小尝试',
        ZxStarterBlock.lowEnergy => '为“' + goal + '”做一个低负荷准备',
        ZxStarterBlock.environment => '把“' + goal + '”的一个必要入口准备好',
      };
}

enum ZxProductArea { action, thought, growth, mentor, more }

extension ZxProductAreaX on ZxProductArea {
  int get tabIndex => switch (this) {
        ZxProductArea.action => 0,
        ZxProductArea.thought => 1,
        ZxProductArea.growth => 2,
        ZxProductArea.mentor => 3,
        ZxProductArea.more => 4,
      };

  String get label => switch (this) {
        ZxProductArea.action => '现在做',
        ZxProductArea.thought => '思想工具',
        ZxProductArea.growth => '成长',
        ZxProductArea.mentor => '导师',
        ZxProductArea.more => '更多',
      };
}

class ZxAssistantAnswer {
  const ZxAssistantAnswer({
    required this.title,
    required this.body,
    required this.area,
    this.actionLabel = '带我去做',
  });

  final String title;
  final String body;
  final ZxProductArea area;
  final String actionLabel;
}

class ZxFeatureGuide {
  const ZxFeatureGuide({
    required this.id,
    required this.title,
    required this.summary,
    required this.what,
    required this.input,
    required this.output,
    required this.why,
    required this.theory,
    required this.example,
    required this.area,
  });

  final String id;
  final String title;
  final String summary;
  final String what;
  final String input;
  final String output;
  final String why;
  final String theory;
  final String example;
  final ZxProductArea area;
}

const List<ZxFeatureGuide> zxFeatureGuides = <ZxFeatureGuide>[
  ZxFeatureGuide(
    id: 'action_cockpit',
    title: '现在做 · 行动驾驶舱',
    summary: '用户只说一个目标或问题，系统负责把它变成唯一主动作。',
    what: '统一承接目标、现实卡点、生成方案、开始记录和行动复盘。',
    input: '必填一个目标/问题；卡点与体验方式各点一次。下一步和价值理由均可留空。',
    output: '一个可观察主动作、完成标准、30秒降级动作、启动线索和停止边界。',
    why: '消除跨页面拼流程的负担，让用户先获得现实产出。',
    theory: '王阳明“事上磨”主线；COM-B障碍匹配；Gollwitzer如果—那么启动；行为激活分级行动。',
    example: '“明天找工作”被转成“现在打开一条匹配岗位，核对三项要求并投递”。',
    area: ZxProductArea.action,
  ),
  ZxFeatureGuide(
    id: 'goal_import',
    title: '三路目标导入',
    summary: '不用重复录入，直接读取当前系统、Todo目标价值系统或 Microsoft To Do。',
    what: '只读选择已有目标及最近未完成步骤，复制到本轮行动表单。',
    input: '选择来源，再点一个目标；原系统仍拥有源数据。',
    output: '预填目标、价值理由、下一步和截止信息。',
    why: '让思想与行动落到用户已经承诺的真实目标。',
    theory: '自我决定理论的自主认领；杜威从真实问题情境开始。',
    example: '从 Microsoft To Do 取出“更新简历”，直接生成本轮动作。',
    area: ZxProductArea.action,
  ),
  ZxFeatureGuide(
    id: 'review_loop',
    title: '现实反馈与自动复盘',
    summary: '只反馈发生了什么和难度，系统自动判断继续、切换或融合思想。',
    what: '把完成、未完成、安全降级或主动退出都变成下一轮证据。',
    input: '结果与难度必答；关键发现和手动思想调整可选。',
    output: '简短报告、障碍发现、思想建议和下一小步。',
    why: '未完成也要产生学习，不用靠羞耻伪装成功。',
    theory: '杜威反思探究；贝克经验检验；班杜拉掌握经验；王阳明省察克治。',
    example: '“没开始且过高”会降级动作，并融合行为激活/Gollwitzer，而非责备毅力。',
    area: ZxProductArea.action,
  ),
  ZxFeatureGuide(
    id: 'thought_tools',
    title: '思想工具箱',
    summary: '完整知识保留，但不再挡在行动之前。',
    what: '查看17套体系、22部来源、关系、差异、证据、边界并自主选择最多3套。',
    input: '可搜索现实问题，也可比较、选择、禁用或评价思想。',
    output: '透明的本轮指导依据和可供匹配器使用的思想组合。',
    why: '用户知道自己在学什么，又不必先读完整本书才能行动。',
    theory: '全部审核知识包；王阳明为主线，其他体系分别补足心理、行动、意义与环境。',
    example: '“害怕失败”可查看 ACT 与贝克的共同点、差异和适用边界。',
    area: ZxProductArea.thought,
  ),
  ZxFeatureGuide(
    id: 'style_profile',
    title: '行动偏好小测',
    summary: '用4个一键选择确定体验、动力、语气和优势，不做长问卷。',
    what: '让同一个知识动作以用户更愿意接受的方式呈现。',
    input: '选择温和/直接/挑战/实验，动力锚点、导师语气和优势。',
    output: '默认负荷、文案语气、反馈焦点和行动入口。',
    why: '提高接受度，但绝不以成瘾、羞辱或操纵替代真实价值。',
    theory: '自我决定理论的自主、胜任、联结；优势取向；分级任务。',
    example: '低能量用户选择“温和启动”，系统把动作限制在5分钟并保留30秒降级。',
    area: ZxProductArea.action,
  ),
  ZxFeatureGuide(
    id: 'growth',
    title: '成长树与挑战',
    summary: '行动、学习和游戏奖励分账，成长可恢复。',
    what: '展示能力XP、树的资源与10维分级挑战。',
    input: '只需完成真实行动和复盘；挑战完全自选。',
    output: '能力证据、成长阶段和可审计奖励记录。',
    why: '让进步可见，同时避免连续签到惩罚和虚假升级。',
    theory: '班杜拉自我效能与掌握经验；行为塑造；容量优先。',
    example: '未完成但发现真实障碍，可以获得学习XP，不能冒充完成金币。',
    area: ZxProductArea.growth,
  ),
  ZxFeatureGuide(
    id: 'assistant',
    title: '模块智能助手',
    summary: '随时解释下一步、功能、流程和出错后的处理。',
    what: '先用本地功能地图回答；AI可用时再结合当前状态给个性化解释。',
    input: '直接问“我该从哪里开始”“这一步太难怎么办”等问题。',
    output: '简短答案和可直达的功能入口。',
    why: '用户不必记住产品结构，也不需要翻阅整本说明。',
    theory: '脚手架式教学；从复杂概念到可执行例子；AI不替用户伪造现实反馈。',
    example: '问“如何换思想”，助手解释自动复盘与手动改选两条路径并跳到思想工具。',
    area: ZxProductArea.mentor,
  ),
  ZxFeatureGuide(
    id: 'agent',
    title: '行动导师提醒',
    summary: '按当前状态提醒目标、执行或反馈，而不是每天发送同一句鸡汤。',
    what: '状态机判断当前真正缺的是目标、行动、进度、反馈还是下一轮。',
    input: '用户选择提醒时间并授权通知。',
    output: '可直达正确页面的阶段化提醒。',
    why: '把知识带回现实现场，减少“想起来时已经错过”的断裂。',
    theory: 'Gollwitzer实施意图；行为提示；王阳明日用工夫。',
    example: '已有行动4小时未反馈时，提醒直接进入复盘而非要求重设目标。',
    area: ZxProductArea.mentor,
  ),
  ZxFeatureGuide(
    id: 'ai_library',
    title: 'AI著作与远端书库',
    summary: 'AI派生知识与审核本地知识物理隔离，文件生命周期透明。',
    what: '上传著作、保存本机、同步真实支持文件ID的服务商、生成派生体系并问书。',
    input: '选择文件、作者、服务商配置；上传前明确确认。',
    output: '远端文件/索引ID、AI派生思想、AI行动或复盘补充。',
    why: '扩展细节而不让未经审核内容覆盖核心知识与安全规则。',
    theory: '证据分层、来源可追溯和本地核心库不可覆盖原则。',
    example: 'OpenAI/Azure保存文件与向量库ID；Eden AI明确显示7天到期而不冒充永久。',
    area: ZxProductArea.mentor,
  ),
  ZxFeatureGuide(
    id: 'privacy',
    title: '证据、隐私与数据控制',
    summary: '用户可以查看知识依据、导出数据、删除记录并关闭个性化。',
    what: '管理证据定位、候选知识、提示词、个性化、远端副本和全部用户数据。',
    input: '按需查看或执行明确确认的管理操作。',
    output: '可审计快照、清楚状态和可撤销/不可撤销边界。',
    why: '信任来自透明与控制，不来自制造依赖。',
    theory: '知行合一中的诚意与责任；现代隐私、可逆性和证据治理。',
    example: '删除远端书籍只删除对应服务商副本，不会误删本地审核知识包。',
    area: ZxProductArea.more,
  ),
];

class ZxModuleAssistantEngine {
  const ZxModuleAssistantEngine();

  ZxAssistantAnswer answer(
    String question, {
    bool hasActiveAction = false,
    bool hasRecentReport = false,
    bool aiConfigured = false,
  }) {
    final q = question.trim().toLowerCase();
    if (q.isEmpty || RegExp(r'开始|从哪|不会用|无从下手').hasMatch(q)) {
      return ZxAssistantAnswer(
        title: hasActiveAction ? '先完成当前唯一动作' : '从一个真实目标开始',
        body: hasActiveAction
            ? '回到“现在做”，只看主动作和完成标准。完成、没完成或改做更小一步后都可以立即复盘。'
            : '进入“现在做”，写下一个目标或问题，再点选当前卡点。思想、动作和难度由系统先推荐，你不需要先读完知识库。',
        area: ZxProductArea.action,
      );
    }
    if (RegExp(r'太难|压力|累|没动力|不想动|拖延').hasMatch(q)) {
      return const ZxAssistantAnswer(
        title: '把行动降到能开始，不先审判动力',
        body: '选择“温和启动”或“现在精力很低”。生成后先做30秒降级动作；复盘选择“过高”，系统会自动缩小下一步并改用容量/反回避思想。',
        area: ZxProductArea.action,
      );
    }
    if (RegExp(r'目标|todo|微软|导入').hasMatch(q)) {
      return const ZxAssistantAnswer(
        title: '目标可以从三处进入',
        body: '在“现在做”点“从已有目标导入”，选择知行树、Todo目标价值系统或 Microsoft To Do。这里只复制公开目标与最近步骤，不修改源模块。',
        area: ZxProductArea.action,
      );
    }
    if (RegExp(r'思想|王阳明|哲学|选择|更换|融合').hasMatch(q)) {
      return const ZxAssistantAnswer(
        title: '思想由系统先推荐，你保留决定权',
        body: '系统按现实障碍匹配17套体系，并在行动卡上显示依据。复盘会自动建议继续、切换或融合；你也可以在“思想工具”中比较后手动选择最多3套。',
        area: ZxProductArea.thought,
      );
    }
    if (RegExp(r'复盘|反馈|报告|没完成|失败').hasMatch(q)) {
      return ZxAssistantAnswer(
        title: hasRecentReport ? '最近报告已经形成下一步' : '现实结果不会被浪费',
        body: '点当前行动的“反馈结果”，只回答实际结果和难度。未完成也会生成障碍发现、思想调整建议和下一小步，不会被记成完成。',
        area: ZxProductArea.action,
      );
    }
    if (RegExp(r'提醒|通知|导师|agent').hasMatch(q)) {
      return const ZxAssistantAnswer(
        title: '提醒会跟随当前进度',
        body: '在“导师”设置启动与复盘时间。提醒会判断你现在缺目标、行动还是反馈，并直接打开相应场景。',
        area: ZxProductArea.mentor,
      );
    }
    if (RegExp(r'ai|书|文件|上传|openai|grok|claude|gemini|azure|openrouter|eden').hasMatch(q)) {
      return ZxAssistantAnswer(
        title: '审核知识与AI派生知识永远分开',
        body: '在“导师”上传著作并配置真实支持文件库的服务商。保存的文件/索引ID、保留期限和删除能力会逐项显示。' +
            (aiConfigured ? '当前全局AI已配置，可继续生成派生思想。' : '当前全局AI未配置，但本地行动闭环仍可完整使用。'),
        area: ZxProductArea.mentor,
      );
    }
    if (RegExp(r'金币|xp|树|成长|挑战').hasMatch(q)) {
      return const ZxAssistantAnswer(
        title: '成长奖励不会伪造成能力',
        body: '“成长”把完成金币、学习金币和能力XP分开。挑战自选、树可恢复；连续中断不会清空成长。',
        area: ZxProductArea.growth,
      );
    }
    if (RegExp(r'隐私|删除|导出|证据|提示词').hasMatch(q)) {
      return const ZxAssistantAnswer(
        title: '在更多中检查与控制数据',
        body: '“更多”可以查看证据定位、提示词、候选知识，关闭个性化，导出完整快照或删除用户数据。审核知识包不会被AI内容覆盖。',
        area: ZxProductArea.more,
      );
    }
    if (RegExp(r'报错|错误|失败|打不开').hasMatch(q)) {
      return const ZxAssistantAnswer(
        title: '先保留现场，再决定修复路径',
        body: '请保留报错全文、发生页面和刚才点击的按钮。可先刷新本地状态；不要反复删除数据。远端服务失败时，本地行动与审核知识仍可使用。',
        area: ZxProductArea.more,
      );
    }
    return const ZxAssistantAnswer(
      title: '先把问题落到一个可处理场景',
      body: '如果你想推进现实目标，去“现在做”；想理解或更换理论，去“思想工具”；想问AI书库或提醒，去“导师”。你也可以把问题写得更具体，例如“我知道要做什么但还是没启动”。',
      area: ZxProductArea.action,
    );
  }

  String groundingText() => zxFeatureGuides
      .map((item) => item.title + '：' + item.summary + ' 输入：' + item.input + ' 输出：' + item.output)
      .join('\n');
}

int _asInt(Object? raw, [int fallback = 0]) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '') ?? fallback;
}
