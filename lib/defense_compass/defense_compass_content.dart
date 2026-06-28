import 'defense_compass_models.dart';

class DefenseCompassLibraryItem {
  final String group;
  final String name;
  final String oneLine;
  final String signals;
  final String protects;
  final String costs;
  final String practice;
  final String scene;
  final String outputMode;
  final String sampleInput;

  const DefenseCompassLibraryItem({
    required this.group,
    required this.name,
    required this.oneLine,
    required this.signals,
    required this.protects,
    required this.costs,
    required this.practice,
    this.scene = 'defense_identify',
    this.outputMode = 'standard',
    this.sampleInput = '',
  });
}

class DefenseCompassTrainingItem {
  final String title;
  final String subtitle;
  final String actionType;
  final String scene;
  final String outputMode;
  final String promptSeed;
  final String doneStandard;
  final String reviewQuestion;

  const DefenseCompassTrainingItem({
    required this.title,
    required this.subtitle,
    required this.actionType,
    required this.scene,
    required this.outputMode,
    required this.promptSeed,
    required this.doneStandard,
    required this.reviewQuestion,
  });
}

class DefenseCompassContent {
  static const List<DefenseCompassLibraryItem> defenses = <DefenseCompassLibraryItem>[
    DefenseCompassLibraryItem(
      group: '内部冲突类防御',
      name: '压抑',
      oneLine: '把危险愿望、情绪或记忆挡在意识之外。',
      signals: '说不清、想不起来、突然空白、对重要事件“没有感觉”。',
      protects: '避免承认会引发罪疚、羞耻或焦虑的愿望。',
      costs: '自我理解变弱，情绪可能转化为身体不适、关系误解或反复焦虑。',
      practice: '写一句“如果我其实知道一点点，我最不敢承认的是……”。',
      sampleInput: '我想检查自己是否可能存在压抑。最近的具体事件是：',
    ),
    DefenseCompassLibraryItem(
      group: '内部冲突类防御',
      name: '反向形成',
      oneLine: '用相反态度防御真实冲动。',
      signals: '越愤怒越客气、越嫉妒越赞美、越想依赖越表现完全独立。',
      protects: '防止自己承认攻击、嫉妒、依赖或亲密愿望。',
      costs: '真实情感被切断，关系变得过度用力或不真实。',
      practice: '把“我一点也不……”改写成“我可能也有一点……”。',
      sampleInput: '我想检查自己是否可能存在反向形成。最近的具体事件是：',
    ),
    DefenseCompassLibraryItem(
      group: '内部冲突类防御',
      name: '隔离',
      oneLine: '把事实和情绪切开。',
      signals: '能冷静复述痛苦事件，但没有悲伤、愤怒或害怕。',
      protects: '避免被情绪淹没，暂时维持理智和功能。',
      costs: '情绪难以被整合，亲密关系中容易显得冷漠或疏离。',
      practice: '讲完事实后补一句：“这件事如果有情绪，它可能是……”。',
      scene: 'affect_tolerance',
      outputMode: 'emotion',
      sampleInput: '我想检查自己是否可能存在隔离。最近的具体事件是：',
    ),
    DefenseCompassLibraryItem(
      group: '内部冲突类防御',
      name: '抵消',
      oneLine: '用补偿、仪式或过度道歉来取消危险想法。',
      signals: '说了重话后立刻过度补偿，有“坏念头”后必须做点什么才安心。',
      protects: '缓解罪疚和超我惩罚。',
      costs: '容易形成强迫式补偿，真实冲突没有被表达。',
      practice: '区分“我有一个念头”和“我已经造成真实伤害”。',
      sampleInput: '我想检查自己是否可能存在抵消。最近的具体事件是：',
    ),
    DefenseCompassLibraryItem(
      group: '内部冲突类防御',
      name: '转向自身',
      oneLine: '不能攻击外部对象，于是攻击自己。',
      signals: '被别人伤害后反复骂自己、责怪自己、惩罚自己。',
      protects: '避免攻击重要关系对象，保留关系或安全感。',
      costs: '愤怒变成自责，自尊受损，内耗增加。',
      practice: '把“都是我不好”拆成“我负责什么 / 对方负责什么”。',
      sampleInput: '我想检查自己是否可能存在转向自身。最近的具体事件是：',
    ),
    DefenseCompassLibraryItem(
      group: '内部冲突类防御',
      name: '反转',
      oneLine: '把主动变被动，或把想做的事变成让别人对自己做。',
      signals: '想表达却等待别人发现，想控制却让自己被控制。',
      protects: '降低主动欲望带来的风险和罪疚。',
      costs: '行动能力下降，需求难以被现实满足。',
      practice: '把一个被动等待改成一句可说出口的小请求。',
      scene: 'wish_integration',
      outputMode: 'wish',
      sampleInput: '我想检查自己是否可能存在反转。最近的具体事件是：',
    ),
    DefenseCompassLibraryItem(
      group: '内部冲突类防御',
      name: '升华',
      oneLine: '把冲动转化为创造、学习、运动、事业或服务。',
      signals: '强烈情绪后能投入写作、训练、研究、作品或建设性行动。',
      protects: '让冲动获得社会可接受表达。',
      costs: '若完全替代情感表达，也可能变成逃避关系。',
      practice: '在建设性行动之后，仍给真实情绪留一分钟命名。',
      sampleInput: '我想检查自己是否正在用升华处理冲突。最近的具体事件是：',
    ),
    DefenseCompassLibraryItem(
      group: '外部现实不快类防御',
      name: '幻想中的否认',
      oneLine: '在幻想中改写痛苦现实。',
      signals: '沉浸于胜利、复仇、完美关系、被拯救或突然翻盘。',
      protects: '短期恢复自尊、控制感和希望。',
      costs: '现实行动被推迟，现实检验变弱。',
      practice: '把幻想中的愿望提取成一个现实中可做的小动作。',
      scene: 'reality_check',
      outputMode: 'reality',
      sampleInput: '我想检查自己是否在用幻想否认现实。最近的具体事件是：',
    ),
    DefenseCompassLibraryItem(
      group: '外部现实不快类防御',
      name: '言语和行动中的否认',
      oneLine: '用反复声明、表演、物品或仪式维持愿望现实。',
      signals: '反复说“我不在乎”，用身份符号或夸大行为证明自己没受伤。',
      protects: '保护自尊，避免承认失望、羡慕或身体/能力差异带来的痛苦。',
      costs: '现实判断变模糊，真正需要无法被照顾。',
      practice: '问：“如果它确实影响了我，我最难承认的是什么？”',
      scene: 'reality_check',
      outputMode: 'reality',
      sampleInput: '我想检查自己是否在用行动中的否认。最近的具体事件是：',
    ),
    DefenseCompassLibraryItem(
      group: '外部现实不快类防御',
      name: '自我限制',
      oneLine: '为避免失败、比较或羞辱，主动退出能力领域。',
      signals: '说“不感兴趣”“没时间”“不适合我”，但背后有怕丢脸或怕输。',
      protects: '避免羞辱、失败、嫉妒、被攻击或被比较。',
      costs: '能力萎缩，人生选择变窄。',
      practice: '做 5 分钟不公开、不比较、只求恢复接触的练习。',
      scene: 'self_limitation',
      outputMode: 'action',
      sampleInput: '我想检查自己是否存在自我限制。一个我回避的领域是：',
    ),
    DefenseCompassLibraryItem(
      group: '关系防御类',
      name: '投射',
      oneLine: '把自己的敌意、嫉妒、需求或罪疚看成别人拥有。',
      signals: '“他肯定讨厌我”“别人都在看不起我”，但证据不足。',
      protects: '避免承认自己的痛苦愿望或攻击性。',
      costs: '误解别人，关系紧张，现实检验下降。',
      practice: '把“他一定……”改成“我担心……我可以验证……”。',
      scene: 'relationship_defense',
      outputMode: 'reality',
      sampleInput: '我想检查自己是否存在投射。最近的关系事件是：',
    ),
    DefenseCompassLibraryItem(
      group: '关系防御类',
      name: '认同攻击者',
      oneLine: '害怕谁，就变得像谁一样攻击或控制。',
      signals: '因为怕被批评所以先批评别人，因为怕被控制所以先控制别人。',
      protects: '从被动受害变成主动掌控，减少无力感。',
      costs: '复制伤害，关系中制造新的恐惧。',
      practice: '问：“我现在是否正在用曾经伤害我的方式对待别人？”',
      scene: 'relationship_defense',
      outputMode: 'standard',
      sampleInput: '我想检查自己是否存在认同攻击者。最近的关系事件是：',
    ),
    DefenseCompassLibraryItem(
      group: '关系防御类',
      name: '利他性让渡',
      oneLine: '把自己的愿望交给别人，通过帮助别人间接满足。',
      signals: '为别人争取爱情、机会、资源很有力量，为自己开口却内疚。',
      protects: '保留愿望，同时避免为自己争取带来的羞耻或罪疚。',
      costs: '自己的愿望长期贫乏，边界变弱。',
      practice: '今天为自己提出一个很小的偏好。',
      scene: 'altruistic_surrender',
      outputMode: 'wish',
      sampleInput: '我想检查自己是否存在利他性让渡。我常为别人做的是：',
    ),
    DefenseCompassLibraryItem(
      group: '发展阶段类防御',
      name: '理智化',
      oneLine: '把强烈情绪和冲动转化为抽象思考。',
      signals: '一直谈意义、原则、人生、社会，却说不出具体情绪和下一步行动。',
      protects: '让自我感觉可控，避免被本能或情绪淹没。',
      costs: '停留在想明白，无法真正感受和行动。',
      practice: '把一个抽象问题落到一个 10 分钟现实动作。',
      scene: 'transition',
      outputMode: 'action',
      sampleInput: '我想检查自己是否在理智化。最近我反复思考的是：',
    ),
    DefenseCompassLibraryItem(
      group: '发展阶段类防御',
      name: '禁欲主义',
      oneLine: '不是拒绝一个欲望，而是怀疑所有享乐和身体需求。',
      signals: '觉得放松、吃好、睡好、亲密、娱乐都危险或不配。',
      protects: '避免被欲望淹没，维持控制感。',
      costs: '生命力下降，身体和关系需求被过度惩罚。',
      practice: '选择一个安全、低风险的身体照顾动作。',
      scene: 'transition',
      outputMode: 'emotion',
      sampleInput: '我想检查自己是否存在禁欲主义。最近我拒绝的享受或需求是：',
    ),
    DefenseCompassLibraryItem(
      group: '发展阶段类防御',
      name: '频繁认同',
      oneLine: '不断借助崇拜对象或身份风格稳定自己。',
      signals: '短期内频繁更换偶像、价值体系、身份风格或人生方向。',
      protects: '在自我不稳定时借他人暂时获得方向。',
      costs: '自我连续性不足，行动容易反复摇摆。',
      practice: '写下：我认同这个人的哪一部分，如何转成自己的一个行动？',
      scene: 'transition',
      outputMode: 'action',
      sampleInput: '我想检查自己是否存在频繁认同。最近我强烈认同的是：',
    ),
  ];

  static const List<DefenseCompassTrainingItem> trainings = <DefenseCompassTrainingItem>[
    DefenseCompassTrainingItem(
      title: '现实检验训练',
      subtitle: '适合投射、否认、灾难化和幻想化。',
      actionType: 'reality_check',
      scene: 'reality_check',
      outputMode: 'reality',
      promptSeed: '请帮我做现实检验。事件是：\n事实：\n我的解释：\n我害怕的后果：\n我希望的版本：',
      doneStandard: '至少写出 1 条已确认事实、1 条猜测、1 个低风险验证行动。',
      reviewQuestion: '验证后，我对现实的判断是否比之前更具体？',
    ),
    DefenseCompassTrainingItem(
      title: '情绪承受训练',
      subtitle: '适合羞耻、嫉妒、愤怒、悲伤和失望。',
      actionType: 'affect_tolerance',
      scene: 'affect_tolerance',
      outputMode: 'emotion',
      promptSeed: '请帮我承受这个情绪，不要立刻分析太深。此刻我正在感到：\n身体反应：\n我最想做的冲动：',
      doneStandard: '完成 90 秒停留，并写下“情绪不是行动”。',
      reviewQuestion: '我是否能多停留一点，而不是立刻逃避/攻击/讨好？',
    ),
    DefenseCompassTrainingItem(
      title: '欲望整合训练',
      subtitle: '适合压抑、内疚、反向形成和过度道德化。',
      actionType: 'wish_integration',
      scene: 'wish_integration',
      outputMode: 'wish',
      promptSeed: '请帮我把一个不敢承认的愿望转成成熟表达。\n我其实可能想要：\n我害怕这个愿望是因为：',
      doneStandard: '写出一句“我其实想要……”和一句成熟请求。',
      reviewQuestion: '承认愿望后，我是否仍能选择负责任的行动？',
    ),
    DefenseCompassTrainingItem(
      title: '边界行动训练',
      subtitle: '适合过度讨好、利他性让渡和转向自身。',
      actionType: 'boundary',
      scene: 'altruistic_surrender',
      outputMode: 'action',
      promptSeed: '请帮我设计一个小边界行动。\n我总是为别人承担的是：\n我自己真正想要的是：',
      doneStandard: '提出一个很小的偏好、请求或拒绝。',
      reviewQuestion: '我是否为自己保留了一点点位置？',
    ),
    DefenseCompassTrainingItem(
      title: '能力恢复训练',
      subtitle: '适合自我限制、怕比较、怕失败和怕羞辱。',
      actionType: 'capacity_recovery',
      scene: 'self_limitation',
      outputMode: 'action',
      promptSeed: '请帮我突破自我限制。\n我回避的领域是：\n表面理由是：\n我可能真正害怕：',
      doneStandard: '做一个 5 分钟、不公开、不比较的最小恢复行动。',
      reviewQuestion: '这次行动有没有让回避领域重新变得可接近一点？',
    ),
    DefenseCompassTrainingItem(
      title: '关系修复训练',
      subtitle: '适合投射、攻击、冷漠和误解。',
      actionType: 'relationship_repair',
      scene: 'relationship_defense',
      outputMode: 'standard',
      promptSeed: '请帮我生成一句关系沟通话。\n对方实际做了什么：\n我以为对方是什么意思：\n我的真实情绪和需求：',
      doneStandard: '生成一句事实 + 感受 + 需求的话，先检查不攻击、不讨好、不压抑。',
      reviewQuestion: '这句话是否比原来的攻击/沉默更真实？',
    ),
    DefenseCompassTrainingItem(
      title: '转折期稳定训练',
      subtitle: '适合人生阶段变化、理智化、禁欲主义和身份摇摆。',
      actionType: 'transition_experiment',
      scene: 'transition',
      outputMode: 'action',
      promptSeed: '请帮我把转折期混乱落到行动。\n我正在经历的变化：\n我反复想的抽象问题：\n我今天能做的小实验：',
      doneStandard: '完成一个 10 分钟身份小实验或稳定行动。',
      reviewQuestion: '这个小实验是否让我更接近一个真实方向？',
    ),
  ];

  static const List<DefenseCompassCourseCard> courseCards = <DefenseCompassCourseCard>[
    DefenseCompassCourseCard(title: '1. 为什么精神分析要研究自我', subtitle: '从“欲望内容”转向“自我如何防御”。', body: '《自我与防御机制》的关键贡献，是把分析焦点从单纯发现本我内容，推进到观察自我如何阻挡、扭曲、转化和组织这些内容。', practices: <String>['记录一个事件：我想要什么？我怎样阻止自己知道？']),
    DefenseCompassCourseCard(title: '2. 本我、超我、现实与自我', subtitle: '四个力量共同构成冲突地图。', body: '人的痛苦常来自愿望、内在禁令和外部现实同时拉扯。产品中的自我三方地图就是把这种拉扯可视化。', practices: <String>['为一个事件写出本我愿望、超我禁令、外部现实。']),
    DefenseCompassCourseCard(title: '3. 防御机制不是坏东西', subtitle: '它曾经保护你，也可能限制你。', body: '防御不是人格缺陷，而是自我保护。成熟不是消灭防御，而是减少其盲目、僵化和现实代价。', practices: <String>['写下一个防御的保护功能与长期代价。']),
    DefenseCompassCourseCard(title: '4. 压抑与阻抗', subtitle: '沉默、空白和转移话题也是材料。', body: '分析中的阻抗并非障碍，而是自我正在防御的证据。现实生活中的“说不清”也值得温和观察。', practices: <String>['当说不清时，写下“我最不想靠近的是……”。']),
    DefenseCompassCourseCard(title: '5. 投射、内射与认同', subtitle: '关系中的误读和模仿。', body: '投射会把内部敌意或需求看成外部；认同则把外部对象的力量带入自我。它们都可能保护关系中的脆弱自我。', practices: <String>['把“他一定……”改成“我担心……我可以验证……”。']),
    DefenseCompassCourseCard(title: '6. 反向形成、隔离与抵消', subtitle: '过度相反、冷静叙述和补偿仪式。', body: '这些机制常与超我焦虑有关：自我用过度相反、情感切断或补偿行为来降低罪疚。', practices: <String>['找一个“我太用力表现相反”的地方。']),
    DefenseCompassCourseCard(title: '7. 儿童幻想中的否认', subtitle: '幻想能暂时倒转痛苦现实。', body: '儿童会在幻想中把弱小变成强大，把失去变成拥有。成人也可能用幻想保护自尊，但仍需要回到现实行动。', practices: <String>['从一个幻想中提取真实愿望。']),
    DefenseCompassCourseCard(title: '8. 言语和行动中的否认', subtitle: '“我不在乎”可能也是一种保护。', body: '当语言、表演、物品或仪式反复证明某个愿望现实，可能说明自我正在避免承认痛苦事实。', practices: <String>['问：如果它影响了我，最难承认什么？']),
    DefenseCompassCourseCard(title: '9. 自我限制', subtitle: '逃避羞辱会让能力萎缩。', body: '自我限制不同于神经症性抑制，它常常是为了避开外部不快、比较或失败。', practices: <String>['做一个不公开、不比较的 5 分钟恢复行动。']),
    DefenseCompassCourseCard(title: '10. 认同攻击者', subtitle: '从被威胁者变成威胁者。', body: '儿童或成人都可能通过变得像攻击者一样来减少恐惧。这能带来控制感，也可能复制伤害。', practices: <String>['问：我是否在用曾伤害我的方式对别人？']),
    DefenseCompassCourseCard(title: '11. 利他性让渡', subtitle: '把自己的愿望交给别人。', body: '有些利他行为背后，是不敢属于自己的愿望。目标不是否定善良，而是把一点愿望还给自己。', practices: <String>['今天为自己提出一个小偏好。']),
    DefenseCompassCourseCard(title: '12. 青春期禁欲主义', subtitle: '害怕被欲望淹没。', body: '禁欲主义不是拒绝某个欲望，而是怀疑享乐和身体需求本身。转折期也可能出现类似机制。', practices: <String>['做一个安全的身体照顾动作。']),
    DefenseCompassCourseCard(title: '13. 青春期理智化', subtitle: '把情绪转成抽象理论。', body: '理智化让自我获得控制感，但若没有行动，会停留在想明白而活不出来。', practices: <String>['把一个抽象问题转成 10 分钟行动。']),
    DefenseCompassCourseCard(title: '14. 防御动机分类', subtitle: '名称之外，更要看害怕什么。', body: '同样的防御可能来自超我焦虑、客观现实焦虑、本能强度焦虑、情感不快焦虑或自我综合焦虑。', practices: <String>['把“我用了什么防御”改问“我最怕什么”。']),
    DefenseCompassCourseCard(title: '15. 现实检验与行动', subtitle: '成熟自我要能检查现实。', body: '现实检验不是否定情绪，而是在承认情绪的同时，把事实、解释、愿望和恐惧分开。', practices: <String>['写下事实/解释/缺失信息/验证行动。']),
    DefenseCompassCourseCard(title: '16. 形成更灵活的自我', subtitle: '不是无防御，而是有选择。', body: '成长意味着自我更能承受情绪、承认愿望、检验现实、表达边界并恢复行动。', practices: <String>['选择一个旧防御，设计一个更灵活替代反应。']),
  ];
}
