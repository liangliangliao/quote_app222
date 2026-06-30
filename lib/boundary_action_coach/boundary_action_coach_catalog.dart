import 'boundary_action_coach_models.dart';
import 'boundary_action_coach_prompt_config.dart';

/// One-to-one product specification for Boundary Action Coach.
///
/// This catalog is intentionally literal: every item is taken from the product
/// design and exposed to the UI so implementation coverage can be checked
/// feature-by-feature instead of being summarized or merged into other modules.
class BoundaryActionCoachCatalog {
  static const List<String> actionLoop = <String>[
    '发生事件',
    'AI 识别边界类型：顺从者 / 逃避者 / 控制者 / 不回应者 / 自我边界 / 家庭系统 / 后果错位',
    '区分责任：属于我的 / 不属于我的 / 可共同承担的',
    '判断 burdens 与 loads',
    '设计边界：我可以给什么 / 我不能给什么 / 持续多久 / 越界后怎么做 / 如何尊重对方自由',
    '生成沟通话术',
    '预测阻力：愤怒 / 内疚攻击 / 反击 / 冷暴力 / 哭诉 / 威胁 / 受害者姿态 / 真实痛苦',
    '制定行动计划：24 小时 / 7 天 / 下次复盘 / 支持者 / 安全风险与专业帮助',
    '复盘：真实边界 / 后果归位 / 尊重对方不 / 是否因罪疚撤回 / 下一个小不',
  ];


  static const List<String> homeDashboardItems = <String>[
    '今日怨气指数',
    '今日能量余额',
    '今日被请求次数',
    '今日说“不”练习',
    '今日自由的“是”',
    '今日责任归属提醒',
    '本周边界任务',
    '支持者快捷联系',
    'AI 快速求助入口',
    '复盘入口',
  ];

  static const List<String> releasePlans = <String>[
    'MVP 1.0 必做：边界诊断中心 / 责任归属地图 / 场景 AI 教练 / 沟通话术生成 / 后果设计器 / 每日复盘 / 成长阶段追踪',
    '2.0 加强模块：AI 角色扮演 / 支持系统 / 自我边界管理 / 家庭职场婚姻专题路径 / 案例库 / 语音输入与复盘',
    '3.0 高级模块：长期关系模式图谱 / 多轮边界成长报告 / 个性化课程路径 / 咨询师协作模式 / 安全风险识别 / 家庭系统图谱 / AI 模拟高压对话训练',
  ];

  static const List<String> productDifferentiators = <String>[
    '明确价值体系：来自《Boundaries》',
    '责任归属模型：我的 / 你的 / 共同的',
    'burdens 与 loads 判断',
    '后果设计',
    '沟通话术',
    '阻力应对',
    '成长阶段',
    '支持系统',
    '现实行动闭环',
    '不把边界简化成拒绝别人，而是恢复爱、责任和自由',
  ];

  static const String mission = '帮助每个人在爱与真理中建立边界，把自由、责任和真实带回现实关系。';

  static const List<String> auditCorrections = <String>[
    '已补齐首页仪表盘 10 个入口，避免只显示部分指标。',
    '已补齐 Boundary Case 的“我已经答应了什么”输入并贯通保存与分析。',
    '已补齐沟通话术工坊的 8 种语气调节。',
    '已补齐 MVP 1.0 / 2.0 / 3.0 版本规划展示。',
    '已补齐产品差异化与最终使命展示。',
  ];

  static const List<String> targetUsers = <String>[
    '讨好型/顺从型用户',
    '过度负责型用户',
    '关系混乱型用户',
    '自我失控型用户',
    '信仰/价值观用户',
  ];

  static const List<String> assessmentDimensions = <String>[
    '是否难以说“不”',
    '是否害怕别人失望',
    '是否经常替别人收拾后果',
    '是否不敢表达真实需要',
    '是否把别人的情绪当成自己的责任',
    '是否容易用愤怒、沉默、冷暴力控制别人',
    '是否拒绝接受帮助',
    '是否时间、金钱、饮食、情绪失控',
    '是否把爱等同于无限付出',
    '是否尊重别人的边界',
  ];

  static const List<String> radarDomains = <String>[
    '原生家庭',
    '配偶/伴侣',
    '朋友',
    '孩子',
    '工作',
    '自我管理',
    '金钱',
    '时间',
    '信仰/价值观',
  ];

  static const List<String> radarMetrics = <String>[
    '边界清晰度',
    '后果归位程度',
    '怨气指数',
    '罪疚感指数',
    '真实表达程度',
    '支持系统强度',
  ];

  static const List<String> dataObjectFields = <String>[
    'Boundary Case：场景类型 / 相关人物 / 事件描述 / 我的感受 / 对方要求 / 我已经答应了什么 / 我真正想要什么 / 当前罪疚感 / 当前怨气 / 安全风险 / AI 建议边界 / 实际行动 / 复盘结果',
    'Relationship Profile：关系类型 / 常见互动模式 / 是否常有愧疚操控 / 是否有控制 / 是否有真实需要 / 我的典型反应 / 对方典型反应 / 可用边界 / 禁用策略 / 安全等级',
    'Responsibility Map：我的责任 / 对方责任 / 共同责任 / burdens / loads / 后果当前由谁承担 / 后果应该回到谁身上',
    'Boundary Script：温柔版 / 简短版 / 重复版 / 高冲突版 / 职场版 / 家庭版 / 复盘评价',
    'Growth Stage：当前阶段 / 本周小不 / 本周自由的是 / 罪疚感变化 / 怨气变化 / 尊重别人边界评分 / 支持系统使用情况',
  ];

  static const List<String> growthStages = <String>[
    '1. 我开始注意到怨气',
    '2. 我发现自己被有边界的人吸引',
    '3. 我开始寻找安全支持',
    '4. 我开始重视自己的需要',
    '5. 我练习小的“不”',
    '6. 我能带着罪疚感仍然设限',
    '7. 我开始面对重要关系中的“大不”',
    '8. 我的罪疚感开始下降',
    '9. 我开始尊重别人的边界',
    '10. 我的“是”和“不”都更自由',
    '11. 我开始按照价值和使命安排生活',
  ];

  static const List<String> learningTopics = <String>[
    '什么是边界',
    '什么属于我',
    '什么不属于我',
    'burdens 与 loads',
    '四类边界问题',
    '十条边界律',
    '家庭边界',
    '朋友边界',
    '婚姻边界',
    '育儿边界',
    '工作边界',
    '自我边界',
    '与神/价值观的边界',
    '阻力与罪疚',
    '成熟边界路径',
    '有边界的一天',
  ];

  static const List<String> caseCards = <String>[
    'Sherrie 型：被所有人占据的人',
    'Bill 父母型：替成年孩子承担后果',
    'Rachel 型：能帮助别人却不能接受帮助',
    'Steve 型：控制别人时间的人',
    'Jim 型：对外负责、对家失约的人',
    'Robby 型：没有后果训练的孩子',
    'Susie 型：替同事承担责任的人',
    'Jerry 型：用属灵语言掩盖真实欲望的人',
  ];

  static const List<BoundaryFeatureModule> modules = <BoundaryFeatureModule>[
    BoundaryFeatureModule(
      title: '1. 边界诊断中心',
      problemSolved: '用户不知道自己哪里没边界。',
      coreValue: '真相、责任、成熟',
      promptId: BoundaryActionCoachPromptConfig.diagnosisId,
      releasePhase: 'MVP 1.0 必做',
      landed: true,
      subFeatures: <String>[
        '边界健康测评：10 个测评维度',
        '测评输出：顺从型风险 / 逃避型风险 / 控制型风险 / 不回应型风险 / 自我边界风险 / 家庭纠缠风险 / 工作过载风险 / 婚姻或亲密关系吞没风险',
        '关系边界雷达图：9 个关系维度',
        '雷达指标：边界清晰度 / 后果归位程度 / 怨气指数 / 罪疚感指数 / 真实表达程度 / 支持系统强度',
        '怨气警报器：今天我最怨谁 / 我答应了什么但心里不愿意 / 我有没有说没关系但其实很生气 / 我有没有把别人的责任带回自己身上',
      ],
      aiOutputs: <String>['边界健康画像', '关系雷达', '怨气解释', '风险分型', '下一步练习'],
      dataObjects: <String>['BoundaryCase', 'RelationshipProfile', 'GrowthStage'],
    ),
    BoundaryFeatureModule(
      title: '2. 责任归属地图',
      problemSolved: '区分什么属于我、什么属于别人、什么是共同关系责任、什么可帮助但不能代替。',
      coreValue: '责任、自由、后果',
      promptId: BoundaryActionCoachPromptConfig.responsibilityMapId,
      releasePhase: 'MVP 1.0 必做',
      landed: true,
      subFeatures: <String>[
        '我的院子 / 你的院子分类器：感受、选择、语言、时间、金钱、身体、价值、生活方式等归属分类',
        'burdens 与 loads 判断器：是否暂时无力承担 / 突发危机还是长期模式 / 帮助使其成熟还是依赖 / 不帮是否有安全风险 / 是否需要期限和范围',
        '输出：可帮助的重担 / 对方应承担的日常责任 / 混合型有限帮助 + 明确后果',
        '后果错位检测：父母替成年孩子、配偶替另一半、同事替同事、朋友长期承担情绪、用户承担金钱时间信誉身体代价',
      ],
      aiOutputs: <String>['三栏责任表', 'burdens / loads 判定', '后果错位提示', '有限帮助范围'],
      dataObjects: <String>['ResponsibilityMap'],
    ),
    BoundaryFeatureModule(
      title: '3. 场景 AI 教练',
      problemSolved: '真实关系中不知道怎么做。',
      coreValue: '爱、真相、尊重',
      promptId: BoundaryActionCoachPromptConfig.commonSceneId,
      releasePhase: 'MVP 1.0 必做',
      landed: true,
      subFeatures: <String>[
        '原生家庭：父母愧疚话术 / 不孝情绪勒索 / 成年子女经济边界 / 探访频率 / 电话消息 / 父母介入婚姻 / 兄弟姐妹责任 / 三角关系 / 孝敬与顺从 / 宽恕与和解',
        '朋友：情绪倾倒 / 单方面维系 / 危机型操控 / 借钱 / 临时求助 / 互惠度 / 友情降级 / 有限帮助 / 说不但保留关心 / 是否结束关系',
        '婚姻/亲密：感受归属 / 欲望表达 / 亲密与分离 / I statement / 冷暴力 / 情绪勒索 / 性边界 / 金钱边界 / 家务责任 / 原生家庭边界 / 宽恕信任和解 / 家暴安全提醒',
        '育儿：年龄阶段 / 纪律与惩罚 / 自然后果 / 作业起床手机零花钱 / 孩子说不训练 / 青春期同伴压力 / 过度拯救 / 爆发式管教 / 规则一致性 / 内化责任',
        '职场：岗位职责 / 下班后工作 / 加班 / 同事甩锅 / 上司不合理要求 / 优先级冲突 / 工作家庭边界 / 记录留痕 / 身份过度认同 / 换岗离职分析',
        '自我边界：时间 / 金钱 / 饮食 / 手机社媒 / 情绪表达 / 语言 / 性亲密行为 / 酒精药物成瘾风险 / 拖延任务 / 外部支持问责',
        '信仰/价值观：爱人与讨好 / 顺服与被操控 / 饶恕与和解 / 真实欲望 / 与神或终极价值诚实对话 / 服事边界 / 权威边界 / 罪疚感与真实责任 / 恩典与真理 / 非宗教生命价值反思',
      ],
      aiOutputs: <String>['场景摘要', '边界类型', '责任归属', '核心价值', '建议边界', '话术', '阻力预测', '行动计划', '安全提醒'],
      dataObjects: <String>['BoundaryCase', 'RelationshipProfile', 'ResponsibilityMap', 'BoundaryScript'],
    ),
    BoundaryFeatureModule(
      title: '4. 沟通话术工坊',
      problemSolved: '帮助用户把边界从心里想变成说得出来。',
      coreValue: '真实、尊重、温柔坚定',
      promptId: BoundaryActionCoachPromptConfig.scriptsId,
      releasePhase: 'MVP 1.0 必做',
      landed: true,
      subFeatures: <String>[
        '四类话术生成：温柔拒绝型 / 有限帮助型 / 后果说明型 / 关系保留型',
        '话术语气调节：温柔坚定 / 简短直接 / 适合父母 / 适合老板 / 适合伴侣 / 适合朋友 / 适合孩子 / 适合高冲突对象',
        '话术检查器：解释过度 / 求饶式语气 / 攻击 / 控制对方 / 威胁而非后果 / 罪疚操控 / 模糊边界 / 没有执行方案',
      ],
      aiOutputs: <String>['温柔版', '简短版', '重复版', '高冲突版', '职场版', '家庭版', '复盘评价'],
      dataObjects: <String>['BoundaryScript'],
    ),
    BoundaryFeatureModule(
      title: '5. 后果设计器',
      problemSolved: '让边界不只是口头声明，而有可执行的现实后果。',
      coreValue: '后果、行动、成熟',
      promptId: BoundaryActionCoachPromptConfig.consequencesId,
      releasePhase: 'MVP 1.0 必做',
      landed: true,
      subFeatures: <String>[
        '自然后果设计：孩子不起床 / 同事不交材料 / 朋友半夜电话 / 父母辱骂等场景',
        '后果与惩罚区分：自然后果还是报复 / 保护自己还是控制对方 / 帮助成熟还是让对方痛苦',
        '执行难度评估：对方愤怒 / 用户内疚 / 安全风险 / 支持者 / 提前话术 / 分阶段执行',
      ],
      aiOutputs: <String>['自然后果', '非惩罚检查', '执行难度', '分阶段执行'],
      dataObjects: <String>['BoundaryCase', 'ResponsibilityMap'],
    ),
    BoundaryFeatureModule(
      title: '6. AI 角色扮演训练',
      problemSolved: '帮助用户在安全环境中练习面对阻力。',
      coreValue: '勇气、练习、支持',
      promptId: BoundaryActionCoachPromptConfig.roleplayId,
      releasePhase: '2.0 加强模块',
      landed: true,
      subFeatures: <String>[
        '角色类型：愤怒型父母 / 哭诉型母亲 / 控制型老板 / 情绪倾倒型朋友 / 逃避型伴侣 / 叛逆孩子 / 借钱不还亲戚 / 冷暴力对象 / 罪疚操控型教会组织成员 / 用户自己的内疚声音',
        '训练模式：初级温和回应 / 中级模拟反击 / 高级连续施压',
        '评分维度：清楚表达边界 / 承担自己的责任 / 没有替对方承担情绪 / 尊重对方 / 有后果 / 温柔坚定 / 避免控制对方',
      ],
      aiOutputs: <String>['角色台词', '用户回应评分', '改写建议', '下一轮练习'],
      dataObjects: <String>['BoundaryScript', 'GrowthStage'],
    ),
    BoundaryFeatureModule(
      title: '7. 支持系统模块',
      problemSolved: '用户孤立无援，容易退回旧模式。',
      coreValue: '恩典、连接、群体',
      promptId: BoundaryActionCoachPromptConfig.supportId,
      releasePhase: '2.0 加强模块',
      landed: true,
      subFeatures: <String>[
        '支持者名单',
        '可联系时间',
        '边界行动前提醒支持者',
        '行动后复盘',
        '问责伙伴',
        '咨询师/治疗师记录',
        '支持小组记录',
        '紧急安全联系人',
        '孤立风险提醒',
        '我不需要一个人完成边界成长提醒',
      ],
      aiOutputs: <String>['支持系统提醒', '孤立风险', '行动前支持', '行动后复盘', '安全联系人提示'],
      dataObjects: <String>['RelationshipProfile', 'GrowthStage'],
    ),
    BoundaryFeatureModule(
      title: '8. 自我边界管理',
      problemSolved: '帮助用户把边界原则应用到自己身上。',
      coreValue: '管家意识、自律',
      promptId: BoundaryActionCoachPromptConfig.selfBoundaryId,
      releasePhase: '2.0 加强模块',
      landed: true,
      subFeatures: <String>[
        '时间边界：每日时间预算 / 他人请求占用记录 / 自己拖延记录 / 深度工作保护 / 休息边界',
        '金钱边界：借钱记录 / 替人付出记录 / 冲动消费记录 / 家庭经济边界 / 有限帮助预算',
        '身体边界：睡眠 / 饮食 / 运动 / 医疗 / 过度消耗提醒',
        '语言边界：攻击性话语 / 沉默逃避 / 被动攻击 / 真实表达 / 承诺过度',
        '欲望与成瘾风险：手机 / 酒精 / 色情 / 暴食 / 购物 / 游戏 / 工作成瘾',
      ],
      aiOutputs: <String>['小限制', '外部支持', '环境设计', '复盘问题', '成瘾风险专业帮助提醒'],
      dataObjects: <String>['BoundaryCase', 'GrowthStage'],
    ),
    BoundaryFeatureModule(
      title: '9. 成长路径追踪',
      problemSolved: '把第 15 章 11 个成长阶段产品化。',
      coreValue: '主动、成熟、价值驱动',
      promptId: BoundaryActionCoachPromptConfig.growthId,
      releasePhase: 'MVP 1.0 必做',
      landed: true,
      subFeatures: <String>[
        '成长地图',
        '阶段测评',
        '当前阶段任务',
        '本周“小不”练习',
        '本周“自由的是”练习',
        '复盘报告',
        '价值驱动目标设置',
      ],
      aiOutputs: <String>['当前阶段', '本周小不', '本周自由的是', '罪疚变化', '怨气变化', '尊重别人边界评分', '支持系统使用情况'],
      dataObjects: <String>['GrowthStage'],
    ),
    BoundaryFeatureModule(
      title: '10. 学习与案例库',
      problemSolved: '让用户理解书中思想，但重点是行动化。',
      coreValue: '价值体系内化',
      promptId: BoundaryActionCoachPromptConfig.learningId,
      releasePhase: '2.0 加强模块',
      landed: true,
      subFeatures: <String>[
        '16 个内容主题：什么是边界到有边界的一天',
        '案例卡片：Sherrie / Bill 父母 / Rachel / Steve / Jim / Robby / Susie / Jerry 抽象化原型',
      ],
      aiOutputs: <String>['学习主题', '抽象案例卡', '行动练习', '复盘问题'],
      dataObjects: <String>['BoundaryCase', 'BoundaryScript'],
    ),
  ];
}
