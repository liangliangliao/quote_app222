class AdaptationSceneSpec {
  final String id;
  final String title;
  final String subtitle;
  final String template;
  final String promptId;
  const AdaptationSceneSpec(this.id, this.title, this.subtitle, this.template, this.promptId);
}

class AdaptationModuleSpec {
  final String title;
  final String subtitle;
  final List<String> functions;
  const AdaptationModuleSpec(this.title, this.subtitle, this.functions);
}

class AdaptationDefenseCard {
  final String name;
  final String layer;
  final String description;
  final String protects;
  final String cost;
  final String upgrade;
  const AdaptationDefenseCard({
    required this.name,
    required this.layer,
    required this.description,
    required this.protects,
    required this.cost,
    required this.upgrade,
  });
}

class AdaptationCourseWeek {
  final int week;
  final String title;
  final String focus;
  final String practice;
  const AdaptationCourseWeek(this.week, this.title, this.focus, this.practice);
}

class AdaptationStageSpec {
  final String title;
  final String question;
  final String defenses;
  final String action;
  const AdaptationStageSpec(this.title, this.question, this.defenses, this.action);
}

class AdaptationCompassContent {
  static const String moduleTitle = '成熟适应力罗盘 · Adaptation Compass';
  static const String bookName = 'George E. Vaillant《Adaptation to Life》';
  static const String courseName = '课程《成熟适应力：从防御机制到现实行动》';

  static const List<AdaptationSceneSpec> scenes = <AdaptationSceneSpec>[
    AdaptationSceneSpec('daily_stress', '日常压力事件', '事件 → 情绪/身体 → 可能防御 → 成熟行动', '今天发生了什么：\n我最强烈的情绪是：\n身体反应是：\n我最想做但没有做/实际做了什么：\n我希望最后得到一个现实行动：', 'ac_scene_daily_stress'),
    AdaptationSceneSpec('defense_identify', '防御机制识别', '温和识别保护功能与长期代价', '请帮我理解这个反复出现的反应：\n具体情境：\n我的反应：\n我担心/害怕的是：\n它可能保护了我什么：', 'ac_scene_defense_identify'),
    AdaptationSceneSpec('reality_check', '现实检查室', '事实、解释、投射、恐惧、未知信息分离', '我现在的判断是：\n已确认事实：\n我的解释/猜测：\n最害怕的版本：\n还没验证的信息：', 'ac_scene_reality_check'),
    AdaptationSceneSpec('anger_transform', '愤怒与攻击性转化', '攻击性 → 边界、运动、创造、问题解决', '让我愤怒的是：\n我最想立刻做的是：\n我真正想保护的是：\n我担心如果表达会发生什么：', 'ac_scene_anger_transform'),
    AdaptationSceneSpec('shame_failure', '羞耻与失败修复', '失败事实 ≠ 人格结论；转向责任与修复', '让我羞耻/失败的是：\n事实是什么：\n我对自己的攻击是：\n我可能需要修复的是：', 'ac_scene_shame_failure'),
    AdaptationSceneSpec('anxiety_fear', '焦虑与恐惧预期', '恐惧 → 最坏/最可能/可准备/可求助', '我正在担心的是：\n最坏情况是：\n最可能情况是：\n我可以准备什么：\n我可以联系谁：', 'ac_scene_anxiety_fear'),
    AdaptationSceneSpec('relationship_conflict', '关系冲突修复', '投射、回避、冷处理、讨好、边界与修复', '关系中的冲突：\n对方做了什么：\n我理解成了什么：\n我真实需要：\n我想保护的边界：', 'ac_scene_relationship_conflict'),
    AdaptationSceneSpec('intimacy_avoidance', '亲密回避/依赖恐惧', '靠近别人而不失去自己', '我在亲密关系中反复出现的模式：\n我想靠近/想逃的时刻：\n我害怕暴露什么需要：', 'ac_scene_intimacy_avoidance'),
    AdaptationSceneSpec('work_consolidation', '工作压力与职业巩固', '野心/竞争/攻击性 → 建设性能力', '我的工作压力：\n现实任务：\n被触发的自尊/权威问题：\n我想把能量转化成什么成果：', 'ac_scene_work_consolidation'),
    AdaptationSceneSpec('balance_four', '工作-爱-游戏-身体失衡', '四维平衡：不把健康等同于成功', '最近四维状态：\n工作：\n爱/关系：\n游戏/快乐：\n身体/睡眠/饮酒/运动：', 'ac_scene_balance_four'),
    AdaptationSceneSpec('high_functioning', '高功能但不鲜活', '理智化、压抑、反向形成与生命力恢复', '别人眼中的我：\n我内在的空洞/麻木：\n我多久没有玩/表达需要/真实连接：', 'ac_scene_high_functioning'),
    AdaptationSceneSpec('childhood_climate', '童年关系气候整合', '童年重要，但不是机械命运', '早年关系气候：\n它如何影响我现在：\n我已经拥有的成人资源：\n我想发展的新适应：', 'ac_scene_childhood_climate'),
    AdaptationSceneSpec('body_health', '身体、睡眠、酒精与压力', '不把身体问题简单心理化，也不忽略压力信号', '身体/睡眠/饮酒/疲劳问题：\n最近压力：\n是否已医学评估：\n我想先做的身体照顾：', 'ac_scene_body_health'),
    AdaptationSceneSpec('acting_out', '成瘾/行动化冲动', '先降低风险，再看冲动保护了什么', '我现在的冲动：\n强度 0-10：\n可能后果：\n我能联系谁：\n我愿意先延迟多久：', 'ac_scene_acting_out'),
    AdaptationSceneSpec('generativity', '生成性与贡献', '从自我保护/自我成功走向帮助他人成长', '我经历过的痛苦/经验：\n它让我理解了什么：\n我可能帮助谁：\n我不想继续传递什么伤害：', 'ac_scene_generativity'),
    AdaptationSceneSpec('life_stage_review', '生命阶段复盘', '身份、亲密、职业巩固、生成性、意义守护、整合', '我当前的人生阶段：\n过去主要适应方式：\n现在最重要的发展任务：\n未来 30 天我想练习：', 'ac_scene_life_stage_review'),
    AdaptationSceneSpec('understand_other', '理解他人但保持边界', '慈悲不等于纵容伤害', '我想理解的人/行为：\n他/她做了什么：\n造成的影响：\n我需要保护的边界：', 'ac_scene_understand_other'),
    AdaptationSceneSpec('safety_support', '危机与安全支持', '自伤/伤人/暴力/严重失控时优先安全', '我现在是否安全：\n是否有伤害自己/他人的冲动：\n身边可联系的人：\n我需要的立即支持：', 'ac_scene_safety_support'),
  ];

  static const List<AdaptationModuleSpec> modules = <AdaptationModuleSpec>[
    AdaptationModuleSpec('适应力首页', '每天回答：今天最需要成熟回应的现实是什么？', ['今日现实', '可能旧防御', '成熟练习', '关系动作', '生成性动作', '纵向提醒']),
    AdaptationModuleSpec('今日适应记录', '把日常事件转化为适应材料', ['事件输入', '情绪/身体记录', 'AI 适应分析', '今日一小步', '晚间复盘']),
    AdaptationModuleSpec('防御机制地图', '看见保护方式，不羞辱自己', ['四层防御模型', '防御卡片', '触发地图', '防御保护伦理提示']),
    AdaptationModuleSpec('现实检查室', '区分事实、解释、恐惧、投射与行动', ['事实-解释分离', '现实证据表', '边界现实检查', '极端解释降温']),
    AdaptationModuleSpec('冲突转化实验室', '把愤怒、羞耻、恐惧、嫉妒、孤独转化为成熟行动', ['愤怒转边界', '羞耻转修复', '恐惧转预期', '嫉妒转欲望识别', '孤独转连接', '行动化中断']),
    AdaptationModuleSpec('关系与亲密系统', '关系是成熟适应的试金石', ['关系地图', '关系质量指标', '关系防御识别', '修复对话生成器', '亲密能力训练', '朋友恢复计划']),
    AdaptationModuleSpec('工作-爱-游戏-身体平衡盘', '完整健康不等于单一成功', ['四维评分', '失衡识别', '平衡处方', '酒精与身体健康追踪']),
    AdaptationModuleSpec('神经症性高功能工作坊', '服务外表成功但不鲜活的人', ['理智化识别', '压抑识别', '反向形成识别', '情感恢复练习', '鲜活感评分']),
    AdaptationModuleSpec('童年关系气候整合', '童年重要，但不是命运', ['童年气候地图', '早年防御识别', '非决定论重写', '内化安全关系练习']),
    AdaptationModuleSpec('成人发展地图', '用阶段任务理解人生', ['身份', '亲密', '职业巩固', '生成性', '意义守护', '生命整合']),
    AdaptationModuleSpec('生成性与贡献计划', '最高成熟不是自我成功，而是让别人也更好', ['痛苦转贡献', '贡献类型', '生成性边界', '贡献档案']),
    AdaptationModuleSpec('案例课程馆', '把书中案例思想转化为适应路径原型', ['痛苦转公共关怀', '投射孤立', '攻击性升华', '压抑贫乏', '高功能理智化', '行动化后修复', '疑病转照顾', '非主流但真实健康']),
    AdaptationModuleSpec('生命时间线', '不以单点判断人生', ['生命章节', '适应方式演化', '人生证据墙', '年度适应报告']),
    AdaptationModuleSpec('AI 深度复盘', '7 天、30 天、90 天、年度纵向观察', ['重复触发器', '成熟防御趋势', '关系修复趋势', '四维平衡', '生成性行动']),
    AdaptationModuleSpec('危机与安全支持', '高风险时停止普通成长分析', ['风险筛查', '10 分钟安全动作', '可信任的人', '专业/紧急资源提醒']),
    AdaptationModuleSpec('个人价值与隐私中心', '保护自主性与数据边界', ['价值档案', 'AI 边界设置', '隐私控制', '治疗师导出包']),
  ];

  static const List<AdaptationDefenseCard> defenses = <AdaptationDefenseCard>[
    AdaptationDefenseCard(name: '投射', layer: '不成熟防御', description: '把自己难以承认的愤怒、嫉妒、依赖或敌意体验成别人对自己的敌意。', protects: '保护自尊，避免承认脆弱或攻击性。', cost: '容易破坏信任，让关系越来越孤立。', upgrade: '现实检查 + 直接表达 + 边界沟通。'),
    AdaptationDefenseCard(name: '行动化', layer: '不成熟防御', description: '不先感受和思考，而是用冲动行为释放痛苦。', protects: '快速降低内在张力。', cost: '可能伤害关系、身体、工作和安全。', upgrade: '10 分钟延迟 + 身体稳定 + 求助 + 替代行动。'),
    AdaptationDefenseCard(name: '疑病/身体化', layer: '不成熟或神经症性防御', description: '心理压力通过身体担忧或症状被表达。', protects: '让痛苦变得可被照顾、可被命名。', cost: '可能忽略真实情绪，也可能延误医学评估。', upgrade: '医学评估 + 情绪命名 + 身体照顾。'),
    AdaptationDefenseCard(name: '理智化', layer: '神经症性防御', description: '用分析、概念和解释切断情绪。', protects: '保持秩序、责任和控制感。', cost: '让人高功能但不鲜活，亲密关系变浅。', upgrade: '情绪命名 + 身体扫描 + 小剂量真实表达。'),
    AdaptationDefenseCard(name: '压抑', layer: '神经症性防御', description: '把难以承受的愿望、情绪或记忆排除在意识之外。', protects: '帮助人继续运转，不被痛苦淹没。', cost: '可能牺牲快乐、游戏和亲密。', upgrade: '安全关系中逐步表达，不粗暴拆除。'),
    AdaptationDefenseCard(name: '反向形成', layer: '神经症性防御', description: '用过度相反的态度掩盖真实冲动，如过度善良掩盖愤怒。', protects: '避免罪疚和关系危险。', cost: '容易过度牺牲或僵硬。', upgrade: '承认混合情感 + 有边界的善意。'),
    AdaptationDefenseCard(name: '升华', layer: '成熟防御', description: '把攻击性、性、悲伤、羞耻或竞争心转化为作品、事业、运动、研究和服务。', protects: '既承认能量，又减少破坏。', cost: '若过度工作化，仍可能逃避亲密和身体。', upgrade: '保持工作、爱、游戏、身体平衡。'),
    AdaptationDefenseCard(name: '利他', layer: '成熟防御', description: '把自己的痛苦转化为对他人的帮助。', protects: '让痛苦进入关系和意义。', cost: '若缺少边界，可能变成讨好或过度牺牲。', upgrade: '有边界的贡献，确认自己也被滋养。'),
    AdaptationDefenseCard(name: '幽默', layer: '成熟防御', description: '承认痛苦，同时保留弹性和人味。', protects: '降低羞耻和僵硬。', cost: '若用来躲避严肃沟通，会变成回避。', upgrade: '幽默之后仍回到真实请求。'),
    AdaptationDefenseCard(name: '预期', layer: '成熟防御', description: '提前想象困难并准备情绪、资源和行动。', protects: '减少被未来击垮的可能。', cost: '若失控会滑向焦虑。', upgrade: '准备可控事项，放下不可控事项。'),
    AdaptationDefenseCard(name: '抑制', layer: '成熟防御', description: '知道自己有情绪，但选择暂时不让情绪驾驶行为。', protects: '保护现实行动和关系。', cost: '若长期不回来处理，会变成压抑。', upgrade: '延迟行动后安排复盘和表达。'),
  ];

  static const List<AdaptationCourseWeek> course = <AdaptationCourseWeek>[
    AdaptationCourseWeek(1, '心理健康不是无痛，而是适应', '健康、正常、症状与适应的区别', '记录 3 个压力事件，写下“它保护了我什么”。'),
    AdaptationCourseWeek(2, '看见自己的防御机制', '四层防御与保护功能', '完成一次防御触发地图。'),
    AdaptationCourseWeek(3, '现实检查', '事实、解释、投射、恐惧分离', '每天做一次事实-解释分离。'),
    AdaptationCourseWeek(4, '愤怒与攻击性升华', '攻击性变成边界和创造', '把一次愤怒转化为沟通、运动或作品。'),
    AdaptationCourseWeek(5, '羞耻与失败修复', '失败不是人格结论', '完成一个修复行动。'),
    AdaptationCourseWeek(6, '神经症性防御与鲜活感', '理智化、压抑、反向形成的代价', '表达一个真实需要。'),
    AdaptationCourseWeek(7, '关系与亲密', '亲密是成人发展任务', '完成一次修复对话。'),
    AdaptationCourseWeek(8, '工作、爱、游戏、身体', '完整健康的四维平衡', '制定一周四维平衡计划。'),
    AdaptationCourseWeek(9, '童年重要，但不是命运', '早年关系气候与成人资源', '写一封“旧防御感谢信与告别信”。'),
    AdaptationCourseWeek(10, '职业巩固', '职业身份、导师、野心升华', '制定 30 天职业巩固行动。'),
    AdaptationCourseWeek(11, '生成性', '从自我成功走向贡献', '完成一个帮助他人的小行动。'),
    AdaptationCourseWeek(12, '生命时间线', '纵向理解人生', '生成个人年度适应报告。'),
  ];

  static const List<AdaptationStageSpec> stages = <AdaptationStageSpec>[
    AdaptationStageSpec('身份', '我是谁？我能否拥有自己的欲望和方向？', '幻想、讨好、反叛、身份混乱、理想化/贬低。', '价值澄清、小规模选择、现实试错、承担后果。'),
    AdaptationStageSpec('亲密', '我能否靠近别人而不失去自己？', '回避、控制、投射、讨好、突然切断。', '表达需要、边界、修复对话、真实暴露。'),
    AdaptationStageSpec('职业巩固', '我是否形成稳定能力和职业身份？', '过度工作、理智化、竞争性投射、失败后逃避。', '技能建设、导师关系、长期项目、工作边界。'),
    AdaptationStageSpec('生成性', '我如何帮助下一代或他人成长？', '控制后辈、救世主情结、过度牺牲、僵化说教。', '指导、陪伴、创造资源、有边界的照顾。'),
    AdaptationStageSpec('意义守护', '我如何面对角色变化、失去和有限性？', '僵化、犬儒、退缩、只怀旧。', '传承、写作、教学、社区参与、幽默面对有限性。'),
    AdaptationStageSpec('生命整合', '我能否承认遗憾，同时看见意义？', '否认衰老、绝望、怨恨、回避告别。', '生命回顾、和解、遗产整理、传承谈话。'),
  ];

  static const List<String> caseArchetypes = <String>[
    '痛苦转公共关怀型：创伤不必变成毁灭，也可转化为利他和社会服务。',
    '投射孤立型：未被整合的痛苦被放到外部敌人身上，长期破坏关系。',
    '攻击性升华型：攻击性不是病，成熟表达后成为事业、正义感和创造力。',
    '压抑贫乏型：没有外显冲突不等于健康，过度压抑会牺牲生命力。',
    '高功能理智化型：理智能维持责任，也可能切断情感和亲密。',
    '行动化退行后修复型：成瘾、冲动和混乱不是终点，可经关系、互助和责任成熟。',
    '疑病转照顾型：身体化痛苦有时可在被照顾和照顾他人的循环中转化。',
    '非主流但真实健康型：健康不能等同于社会顺从、传统婚姻或主流成功。',
  ];
}
