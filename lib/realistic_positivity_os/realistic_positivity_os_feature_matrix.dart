import 'package:flutter/material.dart';

import 'realistic_positivity_os_prompt_config.dart';

class RpoFeatureSpec {
  final String id;
  final String title;
  final String description;
  final String evidenceHint;

  const RpoFeatureSpec({
    required this.id,
    required this.title,
    required this.description,
    required this.evidenceHint,
  });
}

class RpoModuleFeatureSpec {
  final String sceneType;
  final String title;
  final String shortTitle;
  final String courseValue;
  final String productGoal;
  final IconData icon;
  final Color color;
  final String promptId;
  final String assetType;
  final List<RpoFeatureSpec> features;
  final List<String> designBoundaries;
  final List<String> nextBuildChecks;

  const RpoModuleFeatureSpec({
    required this.sceneType,
    required this.title,
    required this.shortTitle,
    required this.courseValue,
    required this.productGoal,
    required this.icon,
    required this.color,
    required this.promptId,
    required this.assetType,
    required this.features,
    this.designBoundaries = const <String>[],
    this.nextBuildChecks = const <String>[],
  });
}

class RpoFeatureMatrix {
  static const List<RpoModuleFeatureSpec> modules = <RpoModuleFeatureSpec>[
    RpoModuleFeatureSpec(
      sceneType: 'onboarding',
      title: 'Onboarding 人格地图',
      shortTitle: '人格地图',
      icon: Icons.account_tree_outlined,
      color: Color(0xFF4F46E5),
      promptId: RealisticPositivityOsPromptConfig.sceneOnboardingId,
      assetType: 'profile_map',
      courseValue: '把《哈佛积极心理学》Lecture 9–10 的价值体系变成长期 AI 背景，而不是每次从零开始。',
      productGoal: '建立当前困扰、感恩资产、情绪模式、旧问题、价值绑定、支持关系和 Stretch 方向。',
      features: <RpoFeatureSpec>[
        RpoFeatureSpec(id: 'current_trouble_map', title: '当前困扰地图', description: '记录用户最想理解或改变的核心困扰。', evidenceHint: '人格地图 currentTroubles 非空，或 onboarding 记录存在。'),
        RpoFeatureSpec(id: 'emotion_pattern_map', title: '情绪模式地图', description: '识别用户常见情绪与处理方式。', evidenceHint: 'commonEmotions 非空。'),
        RpoFeatureSpec(id: 'old_question_map', title: 'Fault Finder 旧问题库', description: '沉淀自责、灾难化、完美主义等旧问题。', evidenceHint: 'commonOldQuestions 非空。'),
        RpoFeatureSpec(id: 'value_binding_map', title: '价值绑定地图', description: '记录旧模式与珍贵价值的绑定。', evidenceHint: 'valueBindings 或 value_binding 资产非空。'),
        RpoFeatureSpec(id: 'support_relation_map', title: '支持关系地图', description: '记录可感谢、可求助、可陪伴的人。', evidenceHint: 'supportPeople / relationshipMap 非空。'),
        RpoFeatureSpec(id: 'stretch_map', title: 'Stretch Zone 地图', description: '记录用户想成长的领域。', evidenceHint: 'stretchAreas 非空。'),
      ],
      nextBuildChecks: <String>['是否能从任何行动卡一键沉淀到人格地图', '是否能在 AI 生成时自动调用人格地图上下文'],
    ),
    RpoModuleFeatureSpec(
      sceneType: 'reality_lens',
      title: 'Reality Lens 真实看见',
      shortTitle: '真实看见',
      icon: Icons.visibility_outlined,
      color: Color(0xFF2563EB),
      promptId: RealisticPositivityOsPromptConfig.sceneRealityLensId,
      assetType: 'reality_lens',
      courseValue: 'Benefit Finder 不是盲目乐观，而是在承认困难的同时恢复现实完整性。',
      productGoal: '帮助用户从 fault finder 转向 reality finder。',
      features: <RpoFeatureSpec>[
        RpoFeatureSpec(id: 'fact_emotion_interpretation', title: '事实/情绪/解释分离', description: '拆分事实、情绪和自动解释。', evidenceHint: 'reality_lens 训练卡包含 real_situation / old_question。'),
        RpoFeatureSpec(id: 'single_lens_detection', title: '单边现实检测', description: '识别只看负面、只自责或过早积极。', evidenceHint: '旧问题与更好问题均被生成。'),
        RpoFeatureSpec(id: 'resource_recovery', title: '资源恢复', description: '找出仍存在的资源、支持和能力。', evidenceHint: '行动卡 interventionSummary 或 displayCards 中出现资源视角。'),
        RpoFeatureSpec(id: 'one_percent_action', title: '可控 1% 行动', description: '生成今日 2–10 分钟现实行动。', evidenceHint: 'microAction 存在并进入行动证据库。'),
      ],
      designBoundaries: <String>['不说“往好处想”', '先承认困难，再看资源。'],
    ),
    RpoModuleFeatureSpec(
      sceneType: 'question_reframing',
      title: 'Question Reframing 问题重构',
      shortTitle: '问题重构',
      icon: Icons.question_answer_outlined,
      color: Color(0xFF7C3AED),
      promptId: RealisticPositivityOsPromptConfig.sceneQuestionReframingId,
      assetType: 'old_question',
      courseValue: '问题创造现实：用户问什么，就会把注意力放到什么心理现实上。',
      productGoal: '将自我攻击、绝望预言、过度概括转为真实且可行动的问题。',
      features: <RpoFeatureSpec>[
        RpoFeatureSpec(id: 'bad_question_classifier', title: '坏问题分类器', description: '识别自我攻击、灾难化、读心、完美主义等问题类型。', evidenceHint: 'question_reframing 记录存在。'),
        RpoFeatureSpec(id: 'better_question_generator', title: '更好问题生成器', description: '将旧问题转为更完整的问题。', evidenceHint: 'betterQuestion 非空。'),
        RpoFeatureSpec(id: 'personal_question_library', title: '个人旧问题库', description: '长期沉淀反复出现的旧问题。', evidenceHint: 'profile.commonOldQuestions 非空。'),
        RpoFeatureSpec(id: 'question_action', title: '基于新问题的小行动', description: '把新问题转为现实行动。', evidenceHint: 'microAction 和行动证据存在。'),
      ],
    ),
    RpoModuleFeatureSpec(
      sceneType: 'gratitude',
      title: 'Gratitude Practice 感恩训练',
      shortTitle: '感恩训练',
      icon: Icons.volunteer_activism_outlined,
      color: Color(0xFFDB2777),
      promptId: RealisticPositivityOsPromptConfig.sceneGratitudeId,
      assetType: 'gratitude_asset',
      courseValue: 'Appreciate 既是感谢，也是让被欣赏之物在心理现实中增长。',
      productGoal: '通过 freshness、具体化、视觉化、感官化和表达建立感恩资产库。',
      features: <RpoFeatureSpec>[
        RpoFeatureSpec(id: 'three_layer_gratitude', title: '三层感恩记录', description: '对象、价值、体验三层记录。', evidenceHint: 'gratitude 记录存在。'),
        RpoFeatureSpec(id: 'freshness_engine', title: 'Freshness 防机械化', description: '避免重复机械列清单。', evidenceHint: '不同感恩资产数量增长。'),
        RpoFeatureSpec(id: 'sensory_replay', title: '感官化 replay', description: '画面、声音、身体感受具体化。', evidenceHint: 'savoring_or_meaning_making / displayCards 有重温内容。'),
        RpoFeatureSpec(id: 'gratitude_asset_library', title: '感恩资产库', description: '将感恩沉淀为低落时可调用的资产。', evidenceHint: 'gratitude_asset 资产存在。'),
      ],
    ),
    RpoModuleFeatureSpec(
      sceneType: 'relational_gratitude',
      title: 'Relational Gratitude 关系感恩',
      shortTitle: '关系感恩',
      icon: Icons.people_alt_outlined,
      color: Color(0xFF0891B2),
      promptId: RealisticPositivityOsPromptConfig.sceneRelationalGratitudeId,
      assetType: 'relationship_action',
      courseValue: '感恩表达能形成 win-win、upward spiral 与 pay it forward。',
      productGoal: '把内在感恩转化为感恩信、感恩电话、感恩拜访和真实关系行动。',
      features: <RpoFeatureSpec>[
        RpoFeatureSpec(id: 'gratitude_person_map', title: '感谢对象地图', description: '推荐值得感谢的人。', evidenceHint: 'relationshipMap 非空。'),
        RpoFeatureSpec(id: 'gratitude_letter', title: '感恩信/短消息生成', description: '生成具体、真诚的表达。', evidenceHint: 'relationshipAction 非空。'),
        RpoFeatureSpec(id: 'gratitude_visit', title: '感恩拜访计划', description: '把表达落到时间、方式和复盘。', evidenceHint: 'microAction 是关系表达行动。'),
        RpoFeatureSpec(id: 'pay_it_forward', title: 'Pay It Forward', description: '表达后把善意传递给另一个人。', evidenceHint: 'relationshipAction 包含后续行动。'),
      ],
      designBoundaries: <String>['不鼓励讨好', '关系有伤害时必须保留边界。'],
    ),
    RpoModuleFeatureSpec(
      sceneType: 'emotional_processing',
      title: 'Emotional Processing 允许为人',
      shortTitle: '允许为人',
      icon: Icons.favorite_border,
      color: Color(0xFFDC2626),
      promptId: RealisticPositivityOsPromptConfig.sceneEmotionalProcessingId,
      assetType: 'emotion_processing',
      courseValue: 'Permission to be human：先允许情绪存在，再 active acceptance。',
      productGoal: '从压抑/羞耻/强迫积极转向情绪命名、允许和有效行动。',
      features: <RpoFeatureSpec>[
        RpoFeatureSpec(id: 'emotion_naming', title: '情绪命名器', description: '把“烦”拆成具体情绪。', evidenceHint: 'emotional_processing 记录存在。'),
        RpoFeatureSpec(id: 'permission_card', title: 'Permission Card', description: '生成允许情绪的卡片。', evidenceHint: 'interventionSummary 或 displayCards 有允许情绪。'),
        RpoFeatureSpec(id: 'active_acceptance_card', title: 'Active Acceptance Card', description: '接纳后给出一个有效行动。', evidenceHint: 'microAction 存在。'),
        RpoFeatureSpec(id: 'suppression_detection', title: '情绪压抑检测', description: '识别“我不该难过”等压抑句式。', evidenceHint: 'oldQuestion / betterQuestion 有情绪允许。'),
      ],
      designBoundaries: <String>['不强迫积极', '不提前要求感恩。'],
    ),
    RpoModuleFeatureSpec(
      sceneType: 'meaning_making',
      title: 'Meaning-Making 痛苦整合',
      shortTitle: '痛苦整合',
      icon: Icons.edit_note_outlined,
      color: Color(0xFFEA580C),
      promptId: RealisticPositivityOsPromptConfig.sceneMeaningMakingId,
      assetType: 'meaning_making',
      courseValue: '负面经验需要表达、书写、分析、叙事和整合，而不是封闭反刍。',
      productGoal: '把痛苦从循环反刍转为叙事、支持和修复行动。',
      features: <RpoFeatureSpec>[
        RpoFeatureSpec(id: 'pain_writing', title: '痛苦事件书写', description: '事实、情绪、痛点、解释、行动。', evidenceHint: 'meaning_making 记录存在。'),
        RpoFeatureSpec(id: 'rumination_interrupt', title: '反刍识别/中断', description: '从继续想转向表达和行动。', evidenceHint: 'oldQuestion 和 betterQuestion 有反刍转化。'),
        RpoFeatureSpec(id: 'support_plan', title: '分享支持计划', description: '选择写给自己、朋友、家人、咨询师等。', evidenceHint: 'relationshipAction 非空。'),
        RpoFeatureSpec(id: 'non_forced_meaning', title: '非强行意义化', description: '不说“这一定是好事”。', evidenceHint: 'safety/value boundary 保持。'),
      ],
    ),
    RpoModuleFeatureSpec(
      sceneType: 'savoring_peak',
      title: 'Savoring & Peak Experience 积极经验',
      shortTitle: '积极经验',
      icon: Icons.auto_awesome_outlined,
      color: Color(0xFFF59E0B),
      promptId: RealisticPositivityOsPromptConfig.sceneSavoringPeakId,
      assetType: 'peak_experience',
      courseValue: '积极经验需要 replay、describe、write、act，可成为 PPEO 的种子。',
      productGoal: '保存高光时刻，并把其生命价值延续到行动。',
      features: <RpoFeatureSpec>[
        RpoFeatureSpec(id: 'positive_replay', title: '好事重温', description: '回到画面、声音、身体感受。', evidenceHint: 'savoring_peak 记录存在。'),
        RpoFeatureSpec(id: 'peak_card', title: '高峰体验卡', description: '命名体验、提取价值和身体记忆。', evidenceHint: 'peak_experience 资产存在。'),
        RpoFeatureSpec(id: 'ppeo_action', title: 'PPEO 行动化', description: '把高峰体验延续到本周行动。', evidenceHint: 'microAction 存在。'),
        RpoFeatureSpec(id: 'positive_experience_library', title: '积极经验库', description: '长期保存温暖/勇敢/连接/创造时刻。', evidenceHint: 'profile.peakExperiences 非空。'),
      ],
      designBoundaries: <String>['不把快乐拆成大道理', '重点是重温、保存、延续。'],
    ),
    RpoModuleFeatureSpec(
      sceneType: 'change_lab',
      title: 'Change Lab 改变实验室',
      shortTitle: '改变实验',
      icon: Icons.psychology_alt_outlined,
      color: Color(0xFF9333EA),
      promptId: RealisticPositivityOsPromptConfig.sceneChangeLabId,
      assetType: 'value_binding',
      courseValue: '改变失败常因旧模式绑定珍贵价值；改变不是消灭自己，而是拆解并重组。',
      productGoal: '保留珍贵价值，放下痛苦形式，生成更健康表达。',
      features: <RpoFeatureSpec>[
        RpoFeatureSpec(id: 'change_goal_definition', title: '改变目标定义', description: '把模糊目标转成场景化新行为。', evidenceHint: 'change_lab 记录存在。'),
        RpoFeatureSpec(id: 'do_i_really_want_change', title: '“我真的想改变吗？”检测', description: '探索隐藏收益和害怕失去。', evidenceHint: 'oldQuestion / betterQuestion 有隐藏阻抗。'),
        RpoFeatureSpec(id: 'value_binding_splitter', title: '价值绑定拆解器', description: '你不需要消灭旧模式，保留价值，放下痛苦形式。', evidenceHint: 'valueBinding 非空。'),
        RpoFeatureSpec(id: 'gradual_acute_change_entry', title: '渐进/急性改变入口', description: '区分渐进训练与需要支持的急性改变。', evidenceHint: 'microAction/abcPlan 生成。'),
      ],
    ),
    RpoModuleFeatureSpec(
      sceneType: 'abc_change',
      title: 'ABC Change 改变计划',
      shortTitle: 'ABC 改变',
      icon: Icons.account_tree_outlined,
      color: Color(0xFF0D9488),
      promptId: RealisticPositivityOsPromptConfig.sceneAbcChangeId,
      assetType: 'abc_change',
      courseValue: '真正改变不是只想明白，而是 Affect、Behavior、Cognition 三层同时介入。',
      productGoal: '把目标转成 7/14 天可执行、可复盘的小实验。',
      features: <RpoFeatureSpec>[
        RpoFeatureSpec(id: 'affect_path', title: 'Affect 情绪路径', description: '允许、调节或激活情绪。', evidenceHint: 'abcPlan.affect 非空。'),
        RpoFeatureSpec(id: 'behavior_path', title: 'Behavior 行为路径', description: '每天最小行为。', evidenceHint: 'abcPlan.behavior 非空。'),
        RpoFeatureSpec(id: 'cognition_path', title: 'Cognition 认知路径', description: '替换旧解释或信念。', evidenceHint: 'abcPlan.cognition 非空。'),
        RpoFeatureSpec(id: 'experiment_cycle', title: '7/14 天实验周期', description: '把单次卡片变成连续训练。', evidenceHint: '长期实验计划存在。'),
      ],
    ),
    RpoModuleFeatureSpec(
      sceneType: 'behavior_first',
      title: 'Behavior First 行为优先',
      shortTitle: '行为优先',
      icon: Icons.play_circle_outline,
      color: Color(0xFF16A34A),
      promptId: RealisticPositivityOsPromptConfig.sceneBehaviorFirstId,
      assetType: 'identity_evidence',
      courseValue: '行为会反向塑造态度和身份；不要等动力出现才行动。',
      productGoal: '低动力时生成 2–10 分钟启动行为，并沉淀新身份证据。',
      features: <RpoFeatureSpec>[
        RpoFeatureSpec(id: 'two_min_start', title: '2 分钟启动器', description: '把门槛降到可开始。', evidenceHint: 'behavior_first 记录或 action evidence 存在。'),
        RpoFeatureSpec(id: 'body_feedback', title: '身体反馈练习', description: '姿态、呼吸、走路等身体行为。', evidenceHint: 'microAction 包含身体/启动步骤。'),
        RpoFeatureSpec(id: 'identity_evidence', title: '新身份证据', description: '行动完成后生成身份叙事。', evidenceHint: 'identityEvidence 或 evidence 非空。'),
        RpoFeatureSpec(id: 'low_motivation_mode', title: '低动力模式', description: '允许没有动力，不羞辱用户。', evidenceHint: 'behavior_first 记录存在。'),
      ],
    ),
    RpoModuleFeatureSpec(
      sceneType: 'stretch_zone',
      title: 'Stretch Zone 成长挑战',
      shortTitle: 'Stretch',
      icon: Icons.trending_up,
      color: Color(0xFF059669),
      promptId: RealisticPositivityOsPromptConfig.sceneStretchZoneId,
      assetType: 'stretch_zone',
      courseValue: '成长通常发生在可承受的不适中，而不是舒适或崩溃。',
      productGoal: '区分 comfort/stretch/panic，并生成 3–5 级挑战阶梯。',
      features: <RpoFeatureSpec>[
        RpoFeatureSpec(id: 'three_zone_check', title: '三圈检测', description: '识别 comfort、stretch、panic。', evidenceHint: 'stretchZone.currentZone 非空。'),
        RpoFeatureSpec(id: 'challenge_ladder', title: '挑战阶梯', description: '3–5 级可执行挑战。', evidenceHint: 'displayCards 或 microAction 含挑战。'),
        RpoFeatureSpec(id: 'panic_protection', title: 'Panic 保护', description: '崩溃时降级并联系支持。', evidenceHint: 'riskLevel high/crisis 或 safetyNote。'),
        RpoFeatureSpec(id: 'support_for_challenge', title: '挑战支持系统', description: '为高难度行动加入真实支持者。', evidenceHint: 'relationshipAction / supportPeople 非空。'),
      ],
      designBoundaries: <String>['panic 时不继续挑战', '必要时回到安全支持。'],
    ),
    RpoModuleFeatureSpec(
      sceneType: 'weekly_integration',
      title: 'Weekly Integration 每周整合',
      shortTitle: '周整合',
      icon: Icons.calendar_month_outlined,
      color: Color(0xFF334155),
      promptId: RealisticPositivityOsPromptConfig.sceneWeeklyIntegrationId,
      assetType: 'weekly_integration',
      courseValue: '改变是长期人格雕刻，不是单次 insight 或连续打卡崇拜。',
      productGoal: '总结一周人格证据，只给下周一个核心实验。',
      features: <RpoFeatureSpec>[
        RpoFeatureSpec(id: 'weekly_value_radar', title: '一周价值雷达', description: '真实、感恩、接纳、行动、关系、Stretch、积极经验。', evidenceHint: 'weekly_integration 记录存在。'),
        RpoFeatureSpec(id: 'identity_report', title: '新身份报告', description: '总结本周人格证据。', evidenceHint: 'identityEvidence 多条。'),
        RpoFeatureSpec(id: 'one_next_experiment', title: '下周一个实验', description: '不堆目标，只给核心实验。', evidenceHint: 'experiment 计划或 microAction。'),
        RpoFeatureSpec(id: 'trend_not_streak', title: '趋势而非打卡', description: '关注长期价值内化。', evidenceHint: '覆盖审计和长期实验趋势。'),
      ],
    ),
    RpoModuleFeatureSpec(
      sceneType: 'crisis',
      title: 'Safety Support 安全支持',
      shortTitle: '安全支持',
      icon: Icons.health_and_safety_outlined,
      color: Color(0xFFE11D48),
      promptId: RealisticPositivityOsPromptConfig.sceneSafetyId,
      assetType: 'safety_support',
      courseValue: '痛苦需要被承认，但高风险时不做积极重构或成长挑战。',
      productGoal: '将用户从孤立承受转向真实支持、专业支持或当地紧急服务。',
      features: <RpoFeatureSpec>[
        RpoFeatureSpec(id: 'risk_detection', title: '高风险识别', description: '自伤、失控、家暴、严重成瘾等优先分流。', evidenceHint: 'crisis/high 风险记录存在。'),
        RpoFeatureSpec(id: 'stop_regular_training', title: '停止普通训练', description: '不做感恩、价值绑定或 Stretch。', evidenceHint: 'safetyNote 非空。'),
        RpoFeatureSpec(id: 'real_support', title: '联系真实支持', description: '联系可信任的人或专业支持。', evidenceHint: 'relationshipAction/safetyNote。'),
        RpoFeatureSpec(id: 'emergency_guidance', title: '即时危险紧急服务', description: '有即时风险时建议当地紧急服务。', evidenceHint: 'safetyNote 非空。'),
      ],
      designBoundaries: <String>['危机时不做积极重构', '优先安全和专业支持。'],
    ),
  ];

  static RpoModuleFeatureSpec byScene(String sceneType) => modules.firstWhere(
        (m) => m.sceneType == sceneType,
        orElse: () => modules[1],
      );

  static List<String> get allSceneTypes => modules.map((e) => e.sceneType).toList(growable: false);
}
