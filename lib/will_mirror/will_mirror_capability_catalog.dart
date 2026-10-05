class WillMirrorTheoryRef {
  const WillMirrorTheoryRef({
    required this.id,
    required this.thinker,
    required this.concept,
    required this.plainMeaning,
  });

  final String id;
  final String thinker;
  final String concept;
  final String plainMeaning;

  String get shortLabel => '$thinker · $concept';
}

class WillMirrorTheoryCatalog {
  static const Map<String, WillMirrorTheoryRef> byId =
      <String, WillMirrorTheoryRef>{
    'SCH-B2-018-INNER-NATURE': WillMirrorTheoryRef(
      id: 'SCH-B2-018-INNER-NATURE',
      thinker: '叔本华',
      concept: '《作为意志和表象的世界》§18',
      plainMeaning: '目标表面说了“要什么”，还要继续看它在行动和生活中承担什么功能。',
    ),
    'SCH-B2-022-METAPHYSICAL-BOUNDARY': WillMirrorTheoryRef(
      id: 'SCH-B2-022-METAPHYSICAL-BOUNDARY',
      thinker: '叔本华',
      concept: '§22 · 认识边界',
      plainMeaning: '产品只能形成可修订的生活假说，不能宣称看穿了人的本质。',
    ),
    'SCH-B2-029-MOTIVE': WillMirrorTheoryRef(
      id: 'SCH-B2-029-MOTIVE',
      thinker: '叔本华',
      concept: '§29 · 具体动机',
      plainMeaning: '围绕一个具体行动追问此时此地的动机，直到仍能产生新信息。',
    ),
    'SCH-B2-029-MOTIVE-BOUNDARY': WillMirrorTheoryRef(
      id: 'SCH-B2-029-MOTIVE-BOUNDARY',
      thinker: '叔本华',
      concept: '§29 · Why 的边界',
      plainMeaning: '追问开始循环时就停止，转向人生中的重复事实和反例。',
    ),
    'SCH-B3-034-OBSERVATION': WillMirrorTheoryRef(
      id: 'SCH-B3-034-OBSERVATION',
      thinker: '叔本华',
      concept: '§34 · 先观察',
      plainMeaning: '暂时不急着解释或满足欲望，先看清它怎样出现、变化和影响行动。',
    ),
    'SCH-B3-038-WANT-RESIDUE': WillMirrorTheoryRef(
      id: 'SCH-B3-038-WANT-RESIDUE',
      thinker: '叔本华',
      concept: '§38 · 满足残差',
      plainMeaning: '想象目标已经实现，观察仍然缺少什么，用来发现并行需要。',
    ),
    'SCH-B4-053-DESCRIPTION-NORM': WillMirrorTheoryRef(
      id: 'SCH-B4-053-DESCRIPTION-NORM',
      thinker: '叔本华',
      concept: '§53 · 事实不等于应当',
      plainMeaning: '一个欲望很真实，也仍需经过安全、伦理、责任和现实条件审查。',
    ),
    'SCH-B4-054-LIFE-SEQUENCE': WillMirrorTheoryRef(
      id: 'SCH-B4-054-LIFE-SEQUENCE',
      thinker: '叔本华',
      concept: '§54 · 跨人生序列',
      plainMeaning: '不要凭一次回答定性，要看不同阶段和情境中反复出现的行动。',
    ),
    'SCH-B4-055-ACTION-CHARACTER': WillMirrorTheoryRef(
      id: 'SCH-B4-055-ACTION-CHARACTER',
      thinker: '叔本华',
      concept: '§55 · 行动镜',
      plainMeaning: '用真实选择、持续行动和付出的代价检验口头叙述，同时记录外部限制。',
    ),
    'SCH-B4-055-ACQUIRED-CHARACTER': WillMirrorTheoryRef(
      id: 'SCH-B4-055-ACQUIRED-CHARACTER',
      thinker: '叔本华',
      concept: '§55 · 获得性格',
      plainMeaning: '通过长期生活证据逐渐认识自己，并保留修订空间。',
    ),
    'TAL-L12-SELF-CONCORDANCE': WillMirrorTheoryRef(
      id: 'TAL-L12-SELF-CONCORDANCE',
      thinker: 'Tal Ben-Shahar',
      concept: 'L12 · 自我一致目标',
      plainMeaning: '区分“我愿意”与“我不得不”，兼顾意义、兴趣、热情和现实责任。',
    ),
    'TAL-L12-REALLY-WANT': WillMirrorTheoryRef(
      id: 'TAL-L12-REALLY-WANT',
      thinker: 'Tal Ben-Shahar',
      concept: 'L12 · 真正认领程度',
      plainMeaning: '逐层区分能力、一般愿望和真正愿意投入的目标。',
    ),
    'TAL-L12-SOCIAL-PRESSURE': WillMirrorTheoryRef(
      id: 'TAL-L12-SOCIAL-PRESSURE',
      thinker: 'Tal Ben-Shahar',
      concept: 'L12 · 社会压力',
      plainMeaning: '观察认可、比较和他人期待如何影响目标，但不把社会性简单判成虚假。',
    ),
    'TAL-L13-REAL-ME': WillMirrorTheoryRef(
      id: 'TAL-L13-REAL-ME',
      thinker: 'Tal Ben-Shahar',
      concept: 'L13 · Real-Me',
      plainMeaning: '记录最像自己的时刻，生成兴趣和优势候选，再用行动验证。',
    ),
    'TAL-L13-SEVEN-DAY-STRENGTH': WillMirrorTheoryRef(
      id: 'TAL-L13-SEVEN-DAY-STRENGTH',
      thinker: 'Tal Ben-Shahar',
      concept: 'L13 · 七日优势实践',
      plainMeaning: '用短周期、低风险的现实应用，看能量、持续性和自我一致感是否发生变化。',
    ),
    'TAL-L22-NO-AUDIENCE': WillMirrorTheoryRef(
      id: 'TAL-L22-NO-AUDIENCE',
      thinker: 'Tal Ben-Shahar',
      concept: 'L22 · 无人知晓探针',
      plainMeaning: '暂时拿掉社会可见性，观察欲望怎样变化，而不是做真假判决。',
    ),
    'TAL-L22-OPPOSITION-REMOVAL': WillMirrorTheoryRef(
      id: 'TAL-L22-OPPOSITION-REMOVAL',
      thinker: 'Tal Ben-Shahar',
      concept: 'L22 · 反对与反对消失',
      plainMeaning: '成对观察阻力出现和消失，区分目标本身与反控制、证明自己的新增动机。',
    ),
    'TAL-L22-MPS': WillMirrorTheoryRef(
      id: 'TAL-L22-MPS',
      thinker: 'Tal Ben-Shahar',
      concept: 'L22 · 意义、愉悦、优势',
      plainMeaning: '把意义、愉悦、优势和最像自己的体验汇聚成待验证的活动候选。',
    ),
    'SHELDON-ELLIOT-1999-SELF-CONCORDANCE': WillMirrorTheoryRef(
      id: 'SHELDON-ELLIOT-1999-SELF-CONCORDANCE',
      thinker: 'Sheldon & Elliot',
      concept: '1999 · 自我一致性研究',
      plainMeaning: '把目标认领程度当作可由持续努力与需要满足检验的变量，不当作真实性认证。',
    ),
    'VIA-CHARACTER-STRENGTHS-BOUNDARY': WillMirrorTheoryRef(
      id: 'VIA-CHARACTER-STRENGTHS-BOUNDARY',
      thinker: 'VIA / 宾大积极心理学中心',
      concept: '优势自评边界',
      plainMeaning: '优势标签只能帮助生成候选，不能直接等同于本质或经验性格。',
    ),
    'WM-V4-COUNTER-GATE': WillMirrorTheoryRef(
      id: 'WM-V4-COUNTER-GATE',
      thinker: '意志之镜 V4 产品规则',
      concept: '反证门',
      plainMeaning: '没有主动寻找反例，就不能发布经验性格级结论。',
    ),
    'WM-V4-NO-FAKE-PRECISION': WillMirrorTheoryRef(
      id: 'WM-V4-NO-FAKE-PRECISION',
      thinker: '意志之镜 V4 产品规则',
      concept: '拒绝伪精确',
      plainMeaning: '内部启发式不能显示成看似科学的人格百分比。',
    ),
  };

  static WillMirrorTheoryRef? find(String id) => byId[id];
}

class WillMirrorCapability {
  const WillMirrorCapability({
    required this.id,
    required this.title,
    required this.whatItIs,
    required this.problemSolved,
    required this.input,
    required this.howTo,
    required this.output,
    required this.why,
    required this.theoryIds,
    required this.keywords,
  });

  final String id;
  final String title;
  final String whatItIs;
  final String problemSolved;
  final String input;
  final List<String> howTo;
  final String output;
  final String why;
  final List<String> theoryIds;
  final List<String> keywords;
}

class WillMirrorCapabilityCatalog {
  static const List<WillMirrorCapability> all = <WillMirrorCapability>[
    WillMirrorCapability(
      id: 'practice_loop',
      title: '今日实践闭环',
      whatItIs: '从一个目标或问题直接生成今天能做的小行动，并把结果变成下一步依据。',
      problemSolved: '不知道从哪里开始，理解了很多道理却没有产出。',
      input: '一句目标或问题、七天后想看到的变化、当前障碍，以及可投入的 2/5/15 分钟。',
      howTo: <String>[
        '说出今天最想解决的一件事',
        '选择更适合自己的兴趣、节奏和可用精力',
        '从三个有依据的方案中选一个',
        '完成今天的一小步，记录现实反馈',
      ],
      output: '一个明确的当日动作、完成信号、依据和可继续修订的七日实践记录。',
      why: '行动与短周期实验能把口头想法变成可观察证据；没做成也只用于发现限制，不用于否定欲望。',
      theoryIds: <String>[
        'SCH-B4-055-ACTION-CHARACTER',
        'TAL-L13-SEVEN-DAY-STRENGTH',
        'SHELDON-ELLIOT-1999-SELF-CONCORDANCE',
      ],
      keywords: <String>['开始', '怎么做', '目标', '问题', '行动', '产出'],
    ),
    WillMirrorCapability(
      id: 'preference_profile',
      title: '兴趣与低压力偏好',
      whatItIs: '三次选择完成的轻量偏好设置，不是人格测试。',
      problemSolved: '统一的任务形式不合兴趣，导致压力大、难坚持。',
      input: '喜欢的活动类型、希望被怎样引导、今天真实可用的精力。',
      howTo: <String>['选最有感觉的一项', '只按今天状态选择', '以后随时更改'],
      output: '更贴合兴趣的动作措辞、时间预算和引导方式。',
      why: '兴趣与优势只能生成候选，最终仍由现实行动与持续性校验。',
      theoryIds: <String>[
        'TAL-L13-REAL-ME',
        'TAL-L22-MPS',
        'VIA-CHARACTER-STRENGTHS-BOUNDARY',
      ],
      keywords: <String>['兴趣', '个性', '偏好', '量表', '压力', '适合'],
    ),
    WillMirrorCapability(
      id: 'deep_why',
      title: 'Deep Why',
      whatItIs: '沿具体目标追问其目的、手段和功能，允许出现多个并行原因。',
      problemSolved: '把一个手段误当成最终目的，或反复问为什么却越来越空泛。',
      input: '当前目标，以及“实现后最具体的变化是什么”的回答。',
      howTo: <String>['先写具体变化', '每次只追一个新信息', '发现两个原因就分叉', '循环时停止并转向人生证据'],
      output: '一棵可检查的动机树和若干待验证候选，不是本质结论。',
      why: '具体行为可以追问动机，但动机解释有边界；到边界后应改问“还在哪里发生过”。',
      theoryIds: <String>[
        'SCH-B2-029-MOTIVE',
        'SCH-B2-029-MOTIVE-BOUNDARY',
        'TAL-L12-REALLY-WANT',
      ],
      keywords: <String>['why', '为什么', '动机', '追问', '分支'],
    ),
    WillMirrorCapability(
      id: 'variable_probes',
      title: '变量探针',
      whatItIs: '用“无人知道、去掉赞美、反对消失、功能替代”等假设观察欲望怎样变化。',
      problemSolved: '把认可、比较、反抗或工具功能误当成目标的全部解释。',
      input: '探针前后的欲望变化，以及用户自己的解释。',
      howTo: <String>['每次只改变一个条件', '记录变化而不判真假', '反对与反对消失必须成对', '把新发现变成待验证候选'],
      output: '参与目标的变量、需要补做的探针和明确误用边界。',
      why: '社会影响并不自动使目标虚假；探针只负责分离变量。',
      theoryIds: <String>[
        'TAL-L12-SOCIAL-PRESSURE',
        'TAL-L22-NO-AUDIENCE',
        'TAL-L22-OPPOSITION-REMOVAL',
      ],
      keywords: <String>['探针', '别人', '认可', '反对', '比较', '真假'],
    ),
    WillMirrorCapability(
      id: 'real_me',
      title: 'Real-Me',
      whatItIs: '记录一个具体的“最像自己”时刻，并标明当时的主动性、能量、观众和奖励。',
      problemSolved: '只凭抽象自我评价判断兴趣和优势。',
      input: '发生了什么、在哪个阶段、是否自发、做完后的能量与是否想再做。',
      howTo: <String>['写事实而不是标签', '保留外部条件', '与其他阶段比较', '主动寻找不像自己的反例'],
      output: '一条可用于生成兴趣和优势候选的人生证据。',
      why: '高能量体验可以提出候选，但一次体验不能证明本质。',
      theoryIds: <String>['TAL-L13-REAL-ME', 'TAL-L22-MPS'],
      keywords: <String>['real-me', '像自己', '优势', '兴趣', '能量'],
    ),
    WillMirrorCapability(
      id: 'action_mirror',
      title: '行动镜',
      whatItIs: '记录真正做过的选择、持续时间和真实代价，同时写下资源与环境限制。',
      problemSolved: '口头叙述和现实行为互相矛盾，却没有可检查的事实。',
      input: '具体行动、情境、持续性、代价和阻碍。',
      howTo: <String>['记录可观察动作', '写清持续多久', '写下付出的代价', '同时记录没行动的外部限制'],
      output: '比态度陈述更强、但仍受情境限制的生活证据。',
      why: '行动能检验叙述，但没行动不能自动证明没有欲望。',
      theoryIds: <String>[
        'SCH-B4-055-ACTION-CHARACTER',
        'SCH-B4-053-DESCRIPTION-NORM',
      ],
      keywords: <String>['行动镜', '做过', '证据', '选择', '代价'],
    ),
    WillMirrorCapability(
      id: 'evidence_matrix',
      title: '支持—反证—限制矩阵',
      whatItIs: '把支持候选的事实、真正反驳它的事实和它只在何种条件成立分开。',
      problemSolved: '只挑支持自己的材料，过早给自己贴上固定标签。',
      input: '跨人生行动、最像自己时刻、真实代价、反例和情境限制。',
      howTo: <String>['先连接支持证据', '主动搜索一个能推翻候选的反例', '补写成立条件', '证据不足时继续实验'],
      output: '可修订的候选和置信带；没有反证时明确阻止性格结论。',
      why: '稳定认识需要跨情境序列与反例，不能依赖一次回答。',
      theoryIds: <String>[
        'SCH-B4-054-LIFE-SEQUENCE',
        'SCH-B4-055-ACQUIRED-CHARACTER',
        'WM-V4-COUNTER-GATE',
        'WM-V4-NO-FAKE-PRECISION',
      ],
      keywords: <String>['矩阵', '反证', '限制', '性格', '置信', '结论'],
    ),
    WillMirrorCapability(
      id: 'seven_day_experiment',
      title: '七日现实实验',
      whatItIs: '用低风险、可停止的小行动连续收集现实反馈。',
      problemSolved: '在脑中争论目标是真是假，却没有任何新事实。',
      input: '一个候选、每日小动作、完成信号和可记录的能量/持续性/满足感。',
      howTo: <String>['选择低风险动作', '每天只做可承受的一小步', '做成与没做成都记录', '七天后修正而非证明自己'],
      output: '七天真实记录、发现的阻碍、候选是否要保留及下一轮调整。',
      why: '短周期实践能检验兴趣、优势与目标认领程度；一天结果不定性。',
      theoryIds: <String>[
        'TAL-L13-SEVEN-DAY-STRENGTH',
        'SHELDON-ELLIOT-1999-SELF-CONCORDANCE',
        'SCH-B4-055-ACTION-CHARACTER',
      ],
      keywords: <String>['七日', '实验', '每天', '坚持', '复盘'],
    ),
    WillMirrorCapability(
      id: 'examples',
      title: '完整案例',
      whatItIs: '三套已经跑完七天的默认业务数据，用来照着填写和理解做成/没做成以后怎样调整。',
      problemSolved: '只看说明仍不知道实际应该写成什么样，或不确定完整闭环最后会产出什么。',
      input: '无需输入；从作品集拖延、职业选择和关系表达三个案例中选择。',
      howTo: <String>['在首页点“看完整案例”', '展开一个与你接近的案例', '查看七天做成/没做成记录', '在新建实践时点“照着完整案例开始”'],
      output: '可直接参照的字段、行动、七天证据、结果和下一轮修订。',
      why: '案例保留反例、情境限制和没做成的日子，避免只展示理想路径。',
      theoryIds: <String>[
        'SCH-B4-055-ACTION-CHARACTER',
        'TAL-L13-SEVEN-DAY-STRENGTH',
        'WM-V4-COUNTER-GATE',
      ],
      keywords: <String>['案例', '示例', '参考', '照着填'],
    ),
    WillMirrorCapability(
      id: 'grounded_ai_planner',
      title: 'AI 思想转译器',
      whatItIs: '在用户单次授权后，让已配置 AI 只依据匹配知识和当前需求生成三套现实行动，并留下可核验凭证。',
      problemSolved: '固定模板只重复概念，不能理解当前情境，也看不出 AI 是否真正参与。',
      input: '本次目标/问题、可选结果和障碍、兴趣、引导方式、时间预算，以及匹配的 KB 摘要。',
      howTo: <String>[
        '在第二步保持“本次让 AI 结合知识库生成”',
        '点击仅本次授权按钮',
        '查看 AI 模型、暂定理解和知识记录数',
        '展开每个方案核对概念怎样推出当前动作',
      ],
      output: '三个情境化行动、完成信号、现实产出、概念应用说明和永久保存的 AI/降级凭证。',
      why: 'AI 负责情境推理，知识白名单和结构校验负责约束；校验失败时明确显示本地接管，绝不把模板伪装成 AI。',
      theoryIds: <String>[
        'SCH-B2-022-METAPHYSICAL-BOUNDARY',
        'SCH-B2-029-MOTIVE',
        'SCH-B4-055-ACTION-CHARACTER',
        'WM-V4-COUNTER-GATE',
      ],
      keywords: <String>['ai', '智能', '模型', '生成', '凭证', '转译', '降级'],
    ),
    WillMirrorCapability(
      id: 'assistant',
      title: '随身助手',
      whatItIs: '理解全部模块、流程、字段和理论依据的操作向导。',
      problemSolved: '不知道该用哪个功能、怎么填、为什么要填或下一步去哪。',
      input: '任何关于目标、问题、卡点、字段、流程、依据或案例的自然语言问题。',
      howTo: <String>['直接说你卡在哪里', '先获得本地答案', '需要时逐次授权 AI 深入回答', '按回答给出的下一步继续'],
      output: '通俗解释、具体填写示例、最多四步操作和可核对的理论来源。',
      why: '助手只使用能力目录、当前流程状态和 KB 证据回答，不凭模型记忆编造产品功能。',
      theoryIds: <String>[
        'SCH-B2-022-METAPHYSICAL-BOUNDARY',
        'WM-V4-COUNTER-GATE',
      ],
      keywords: <String>['助手', '不会用', '怎么填', '帮助', '说明', '为什么'],
    ),
    WillMirrorCapability(
      id: 'privacy',
      title: '数据与隐私',
      whatItIs: '独立加密 Vault、本地优先、明文导出警告和密码学删除。',
      problemSolved: '人生目标、关系和反思内容进入普通数据库或在不知情时上传。',
      input: '只有用户主动写入的内容；云端 AI 每次单独授权。',
      howTo: <String>['默认留在本机', '需要 AI 时查看本次发送范围', '导出前确认明文风险', '可删除数据库并销毁密钥'],
      output: '可检查、可导出、可彻底删除的私密数据边界。',
      why: '隐私是开展诚实自我反思的前提，而不是附加设置。',
      theoryIds: <String>['SCH-B2-022-METAPHYSICAL-BOUNDARY'],
      keywords: <String>['隐私', '加密', '上传', 'ai', '删除', '导出'],
    ),
  ];

  static WillMirrorCapability? byId(String id) {
    for (final item in all) {
      if (item.id == id) return item;
    }
    return null;
  }

  static List<WillMirrorCapability> search(String query) {
    final normalized = query.toLowerCase();
    final matches = all.where((item) {
      return item.keywords.any(
            (keyword) => normalized.contains(keyword.toLowerCase()),
          ) ||
          normalized.contains(item.title.toLowerCase());
    }).toList(growable: false);
    return matches.isEmpty
        ? <WillMirrorCapability>[all.first, byId('assistant')!]
        : matches;
  }
}
