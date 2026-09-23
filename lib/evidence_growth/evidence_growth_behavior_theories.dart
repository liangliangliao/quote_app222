/// Theory and questionnaire metadata for action prediction.
///
/// These are theory-grounded standardized program options, not validated
/// psychometric scales. They are designed for transparent user input and
/// model-assisted prefill while preserving the constructs of each framework.
class EvidenceBehaviorTheoryCatalog {
  static const defaultTheoryIds = <String>['IBM', 'TPB', 'COM_B'];

  static const theories = <String, Map<String, Object?>>{
    'TPB': {
      'id': 'TPB',
      'name': '计划行为理论（TPB）',
      'short_name': 'TPB',
      'author': 'Ajzen',
      'scope': '通用意向型行为',
      'description': '态度、主观规范与知觉行为控制影响意向；意向是行为的直接前因。',
      'factor_ids': <String>[
        'intention',
        'attitude_toward_behavior',
        'subjective_norm',
        'perceived_behavioral_control',
      ],
    },
    'IBM': {
      'id': 'IBM',
      'name': '整合行为模型（IBM）',
      'short_name': 'IBM',
      'author': 'Fishbein / Montaño 等',
      'scope': '通用行为发生预测',
      'description': '在意向之外加入知识技能、显著性、环境约束与习惯，并细分态度、规范与个人能动性。',
      'factor_ids': <String>[
        'intention',
        'experiential_attitude',
        'instrumental_attitude',
        'injunctive_norm',
        'descriptive_norm',
        'self_efficacy',
        'perceived_control',
        'knowledge_skills',
        'salience',
        'environmental_constraints',
        'habit',
      ],
    },
    'COM_B': {
      'id': 'COM_B',
      'name': 'COM-B 行为系统',
      'short_name': 'COM-B',
      'author': 'Michie / van Stralen / West',
      'scope': '几乎所有行为的条件诊断',
      'description': '行为取决于能力、机会与动机的共同作用，并区分身体/心理、物理/社会、反思/自动过程。',
      'factor_ids': <String>[
        'physical_capability',
        'psychological_capability',
        'physical_opportunity',
        'social_opportunity',
        'reflective_motivation',
        'automatic_motivation',
      ],
    },
    'SCT': {
      'id': 'SCT',
      'name': '社会认知理论（SCT）',
      'short_name': 'SCT',
      'author': 'Bandura',
      'scope': '自我调节、学习与坚持',
      'description': '强调自我效能、结果预期、目标、自我调节，以及环境促进/阻碍对行为的共同影响。',
      'factor_ids': <String>[
        'self_efficacy',
        'outcome_expectations',
        'goal_commitment',
        'self_regulation',
        'environmental_facilitators',
      ],
    },
    'HAPA': {
      'id': 'HAPA',
      'name': '健康行动过程模型（HAPA）',
      'short_name': 'HAPA',
      'author': 'Schwarzer',
      'scope': '启动、维持、复发后恢复；尤其适合习惯与健康行为',
      'description': '区分动机阶段与意志阶段，用风险、结果预期、自我效能、行动计划、应对计划和行动控制解释意向到行为。',
      'factor_ids': <String>[
        'risk_perception',
        'outcome_expectations',
        'self_efficacy',
        'intention',
        'action_planning',
        'coping_planning',
        'maintenance_self_efficacy',
        'recovery_self_efficacy',
        'action_control',
      ],
    },
    'IMPLEMENTATION_INTENTION': {
      'id': 'IMPLEMENTATION_INTENTION',
      'name': '执行意图（If-Then）扩展',
      'short_name': '执行意图',
      'author': 'Gollwitzer',
      'scope': '解决“已经想做但没有行动”',
      'description': '把明确情境线索与明确行动绑定，形成“如果X发生，我就立即做Y”的触发连接。',
      'factor_ids': <String>[
        'implementation_intention',
        'cue_clarity',
        'response_specificity',
      ],
      'is_extension': true,
    },
  };

  static const intentionOptions = <Map<String, String>>[
    {'id': 'none', 'label': '完全没有打算去做'},
    {'id': 'weak', 'label': '有一点想法，但随时可以不做'},
    {'id': 'ambivalent', 'label': '想做，但仍明显犹豫'},
    {'id': 'clear', 'label': '已经明确决定要做'},
    {'id': 'firm', 'label': '决定非常坚定，不准备重新讨论是否做'},
    {'id': 'unknown', 'label': '不清楚／无法判断'},
  ];

  static const valenceOptions = <Map<String, String>>[
    {'id': 'very_negative', 'label': '非常负面／明显不愿意'},
    {'id': 'negative', 'label': '偏负面／有抵触'},
    {'id': 'mixed', 'label': '好坏参半／中性'},
    {'id': 'positive', 'label': '偏正面／愿意去做'},
    {'id': 'very_positive', 'label': '非常正面／强烈愿意'},
    {'id': 'unknown', 'label': '不清楚／无法判断'},
  ];

  static const supportOptions = <Map<String, String>>[
    {'id': 'strong_against', 'label': '明显反对／阻碍'},
    {'id': 'against', 'label': '有些反对／阻碍'},
    {'id': 'neutral', 'label': '基本中性'},
    {'id': 'support', 'label': '比较支持'},
    {'id': 'strong_support', 'label': '强烈支持／期待'},
    {'id': 'unknown', 'label': '不清楚／无法判断'},
  ];

  static const controlOptions = <Map<String, String>>[
    {'id': 'almost_none', 'label': '几乎不受我控制'},
    {'id': 'low', 'label': '我能控制的部分较少'},
    {'id': 'mixed', 'label': '一半受我控制，一半受条件影响'},
    {'id': 'high', 'label': '大部分在我控制之内'},
    {'id': 'almost_full', 'label': '基本由我决定和控制'},
    {'id': 'unknown', 'label': '不清楚／无法判断'},
  ];

  static const capabilityOptions = <Map<String, String>>[
    {'id': 'insufficient', 'label': '明显不具备'},
    {'id': 'weak', 'label': '有较大欠缺'},
    {'id': 'partial', 'label': '基本有，但仍有关键欠缺'},
    {'id': 'adequate', 'label': '基本具备'},
    {'id': 'strong', 'label': '完全具备且熟练'},
    {'id': 'unknown', 'label': '不清楚／无法判断'},
  ];

  static const opportunityOptions = <Map<String, String>>[
    {'id': 'blocked', 'label': '现实条件基本阻断'},
    {'id': 'difficult', 'label': '条件明显不利'},
    {'id': 'mixed', 'label': '有利和不利条件并存'},
    {'id': 'available', 'label': '条件基本允许'},
    {'id': 'strong', 'label': '条件非常有利／几乎没有现实阻碍'},
    {'id': 'unknown', 'label': '不清楚／无法判断'},
  ];

  static const efficacyOptions = <Map<String, String>>[
    {'id': 'very_low', 'label': '几乎不相信自己能做到'},
    {'id': 'low', 'label': '把握较低'},
    {'id': 'medium', 'label': '有一定把握，但不稳定'},
    {'id': 'high', 'label': '比较有把握'},
    {'id': 'very_high', 'label': '非常有把握，即使有困难也能做'},
    {'id': 'unknown', 'label': '不清楚／无法判断'},
  ];

  static const planOptions = <Map<String, String>>[
    {'id': 'none', 'label': '没有具体计划'},
    {'id': 'vague', 'label': '只有大概想法'},
    {'id': 'partial', 'label': '部分明确，但关键步骤仍不清楚'},
    {'id': 'clear', 'label': '时间／地点／第一步基本明确'},
    {'id': 'if_then', 'label': '已经形成明确的“如果X，就立即做Y”'},
    {'id': 'unknown', 'label': '不清楚／无法判断'},
  ];

  static const habitOptions = <Map<String, String>>[
    {'id': 'strong_against', 'label': '过去习惯强烈把我拉向相反行为'},
    {'id': 'against', 'label': '过去通常会拖延／回避这个行为'},
    {'id': 'mixed', 'label': '过去有时做、有时不做'},
    {'id': 'support', 'label': '过去通常能做到'},
    {'id': 'automatic_support', 'label': '已经比较自动化／几乎不用重新决定'},
    {'id': 'unknown', 'label': '没有同类历史／不清楚'},
  ];

  static const riskOptions = <Map<String, String>>[
    {'id': 'none', 'label': '几乎感觉不到不行动的风险／损失'},
    {'id': 'low', 'label': '风险／损失感觉较低'},
    {'id': 'medium', 'label': '有一定风险／损失'},
    {'id': 'high', 'label': '风险／损失明显'},
    {'id': 'very_high', 'label': '风险／损失非常直接且迫近'},
    {'id': 'unknown', 'label': '不清楚／无法判断'},
  ];

  static const regulationOptions = <Map<String, String>>[
    {'id': 'none', 'label': '没有监控或调节机制'},
    {'id': 'weak', 'label': '偶尔提醒自己，但很容易偏离'},
    {'id': 'partial', 'label': '会检查进度，但不稳定'},
    {'id': 'good', 'label': '会持续监控并及时纠偏'},
    {'id': 'strong', 'label': '有明确反馈、记录和纠偏机制'},
    {'id': 'unknown', 'label': '不清楚／无法判断'},
  ];

  static const factorDefinitions = <String, Map<String, Object?>>{
    'intention': {
      'id': 'intention',
      'label': '行动意向／决定',
      'question': '你现在到底有多明确地决定要执行这个行动？',
      'theories': <String>['TPB', 'IBM', 'HAPA'],
      'options': intentionOptions,
      'covers': <String>['commitment', 'decision_stability', 'intention'],
    },
    'attitude_toward_behavior': {
      'id': 'attitude_toward_behavior',
      'label': '对行为的总体态度',
      'question': '总体来说，你认为“做这件事”是好还是不好、愿意还是不愿意？',
      'theories': <String>['TPB'],
      'options': valenceOptions,
      'covers': <String>['emotion', 'value_salience', 'experiential_attitude', 'instrumental_attitude'],
    },
    'subjective_norm': {
      'id': 'subjective_norm',
      'label': '主观规范',
      'question': '你在意的重要他人总体上希望你做这件事，还是希望你不要做？',
      'theories': <String>['TPB'],
      'options': supportOptions,
      'covers': <String>['injunctive_norm'],
    },
    'perceived_behavioral_control': {
      'id': 'perceived_behavioral_control',
      'label': '知觉行为控制',
      'question': '你觉得这个行动在多大程度上真正受你自己控制？',
      'theories': <String>['TPB'],
      'options': controlOptions,
      'covers': <String>['perceived_control'],
    },
    'experiential_attitude': {
      'id': 'experiential_attitude',
      'label': '体验性态度（直接感受）',
      'question': '一想到要真正去做，你的直接感受更接近哪一种？',
      'theories': <String>['IBM'],
      'options': valenceOptions,
      'covers': <String>['emotion', 'experiential_attitude'],
    },
    'instrumental_attitude': {
      'id': 'instrumental_attitude',
      'label': '工具性态度（结果判断）',
      'question': '从结果、收益和代价来看，你觉得做这件事值得吗？',
      'theories': <String>['IBM'],
      'options': valenceOptions,
      'covers': <String>['value_salience', 'instrumental_attitude'],
    },
    'injunctive_norm': {
      'id': 'injunctive_norm',
      'label': '命令性规范（重要他人期望）',
      'question': '重要他人认为你应该做这件事吗？',
      'theories': <String>['IBM'],
      'options': supportOptions,
      'covers': <String>['external_commitment', 'injunctive_norm'],
    },
    'descriptive_norm': {
      'id': 'descriptive_norm',
      'label': '描述性规范（他人实际行为）',
      'question': '与你有关或你在意的人，实际上通常会不会做这种行为？',
      'theories': <String>['IBM'],
      'options': supportOptions,
      'covers': <String>['descriptive_norm'],
    },
    'self_efficacy': {
      'id': 'self_efficacy',
      'label': '自我效能',
      'question': '你相信自己能够完成这个行动或下一关键步骤吗？',
      'theories': <String>['IBM', 'SCT', 'HAPA'],
      'options': efficacyOptions,
      'covers': <String>['self_efficacy'],
    },
    'perceived_control': {
      'id': 'perceived_control',
      'label': '知觉控制',
      'question': '即使出现阻碍，你觉得自己仍能控制行为是否发生吗？',
      'theories': <String>['IBM'],
      'options': controlOptions,
      'covers': <String>['perceived_control'],
    },
    'knowledge_skills': {
      'id': 'knowledge_skills',
      'label': '知识与技能',
      'question': '完成这个行动所需的知识、方法和技能，你具备到什么程度？',
      'theories': <String>['IBM'],
      'options': capabilityOptions,
      'covers': <String>['knowledge_skills'],
    },
    'salience': {
      'id': 'salience',
      'label': '关键时刻的行动显著性',
      'question': '到了真正需要行动的时刻，这件事会不会仍然在你的注意中心？',
      'theories': <String>['IBM'],
      'options': <Map<String, String>>[
        {'id': 'forgotten', 'label': '很容易被忘掉／被别的事盖过去'},
        {'id': 'low', 'label': '经常到点也想不起来'},
        {'id': 'mixed', 'label': '有时会想起，有时会忽略'},
        {'id': 'salient', 'label': '关键时刻通常会清楚想起'},
        {'id': 'very_salient', 'label': '非常显著，有强提醒或直接后果'},
        {'id': 'unknown', 'label': '不清楚／无法判断'},
      ],
      'covers': <String>['value_salience', 'salience'],
    },
    'environmental_constraints': {
      'id': 'environmental_constraints',
      'label': '环境／现实约束',
      'question': '时间、资源、地点、权限、交通、第三方等现实条件会不会阻挡这个行动？',
      'theories': <String>['IBM'],
      'options': opportunityOptions,
      'covers': <String>[
        'feasibility',
        'time_capacity',
        'prerequisite_readiness',
        'preparation',
        'friction',
        'environmental_constraints'
      ],
    },
    'habit': {
      'id': 'habit',
      'label': '习惯／过去行为',
      'question': '在真正相似的情境里，你过去通常会自动做出什么？',
      'theories': <String>['IBM'],
      'options': habitOptions,
      'covers': <String>['history_habit', 'alternatives', 'habit'],
    },
    'physical_capability': {
      'id': 'physical_capability',
      'label': '身体能力',
      'question': '你的体力、精力、身体状态是否足以完成这个行动？',
      'theories': <String>['COM_B'],
      'options': capabilityOptions,
      'covers': <String>['physical_capacity'],
    },
    'psychological_capability': {
      'id': 'psychological_capability',
      'label': '心理／认知能力',
      'question': '你是否具备完成它所需的知识、理解、注意和认知能力？',
      'theories': <String>['COM_B'],
      'options': capabilityOptions,
      'covers': <String>['knowledge_skills'],
    },
    'physical_opportunity': {
      'id': 'physical_opportunity',
      'label': '物理机会',
      'question': '现实环境是否给你足够的时间、资源、地点和可进入条件去做？',
      'theories': <String>['COM_B'],
      'options': opportunityOptions,
      'covers': <String>[
        'feasibility',
        'time_capacity',
        'prerequisite_readiness',
        'preparation',
        'friction',
        'environmental_constraints'
      ],
    },
    'social_opportunity': {
      'id': 'social_opportunity',
      'label': '社会机会',
      'question': '周围的人际、规则、文化和社会环境总体上支持还是阻碍你做？',
      'theories': <String>['COM_B'],
      'options': supportOptions,
      'covers': <String>['external_commitment', 'injunctive_norm', 'descriptive_norm'],
    },
    'reflective_motivation': {
      'id': 'reflective_motivation',
      'label': '反思性动机',
      'question': '经过思考后，你的目标、计划和价值判断有多支持你去做？',
      'theories': <String>['COM_B'],
      'options': intentionOptions,
      'covers': <String>['commitment', 'decision_stability', 'value_salience', 'intention'],
    },
    'automatic_motivation': {
      'id': 'automatic_motivation',
      'label': '自动性动机',
      'question': '你的情绪、冲动和习惯总体上会自动把你推向行动，还是拉离行动？',
      'theories': <String>['COM_B'],
      'options': valenceOptions,
      'covers': <String>['emotion', 'alternatives', 'history_habit', 'habit'],
    },
    'outcome_expectations': {
      'id': 'outcome_expectations',
      'label': '结果预期',
      'question': '你预期做这件事会带来怎样的结果？这些结果是否值得？',
      'theories': <String>['SCT', 'HAPA'],
      'options': valenceOptions,
      'covers': <String>['value_salience', 'instrumental_attitude'],
    },
    'goal_commitment': {
      'id': 'goal_commitment',
      'label': '目标承诺',
      'question': '你对这个目标的承诺有多稳定，遇到不舒服时还会继续吗？',
      'theories': <String>['SCT'],
      'options': intentionOptions,
      'covers': <String>['commitment', 'decision_stability'],
    },
    'self_regulation': {
      'id': 'self_regulation',
      'label': '自我调节',
      'question': '你是否会监控自己的行动进度，并在偏离时主动纠正？',
      'theories': <String>['SCT'],
      'options': regulationOptions,
      'covers': <String>['specificity', 'trigger', 'preparation'],
    },
    'environmental_facilitators': {
      'id': 'environmental_facilitators',
      'label': '环境促进／阻碍',
      'question': '现实环境里，促进因素与阻碍因素总体是什么关系？',
      'theories': <String>['SCT'],
      'options': opportunityOptions,
      'covers': <String>[
        'feasibility',
        'time_capacity',
        'prerequisite_readiness',
        'preparation',
        'friction'
      ],
    },
    'risk_perception': {
      'id': 'risk_perception',
      'label': '不行动的风险感知',
      'question': '如果不做这件事，你感受到的现实风险、损失或后果有多强？',
      'theories': <String>['HAPA'],
      'options': riskOptions,
      'covers': <String>['value_salience'],
    },
    'action_planning': {
      'id': 'action_planning',
      'label': '行动计划',
      'question': '什么时候、在哪里、用什么方式开始做，已经明确到什么程度？',
      'theories': <String>['HAPA'],
      'options': planOptions,
      'covers': <String>['specificity', 'trigger', 'preparation'],
    },
    'coping_planning': {
      'id': 'coping_planning',
      'label': '应对计划',
      'question': '你是否已经预想最可能出现的阻碍，并准备了具体应对办法？',
      'theories': <String>['HAPA'],
      'options': planOptions,
      'covers': <String>['friction', 'alternatives'],
    },
    'maintenance_self_efficacy': {
      'id': 'maintenance_self_efficacy',
      'label': '维持自我效能',
      'question': '如果行动需要持续一段时间，你相信自己能在困难和诱惑下坚持吗？',
      'theories': <String>['HAPA'],
      'options': efficacyOptions,
      'covers': <String>['self_efficacy'],
    },
    'recovery_self_efficacy': {
      'id': 'recovery_self_efficacy',
      'label': '恢复自我效能',
      'question': '如果中途失败一次或中断，你相信自己能重新开始吗？',
      'theories': <String>['HAPA'],
      'options': efficacyOptions,
      'covers': <String>['self_efficacy'],
    },
    'action_control': {
      'id': 'action_control',
      'label': '行动控制／自我监控',
      'question': '执行过程中，你会不会持续对照目标、监控偏差并及时纠正？',
      'theories': <String>['HAPA'],
      'options': regulationOptions,
      'covers': <String>['decision_stability', 'alternatives', 'salience'],
    },
    'implementation_intention': {
      'id': 'implementation_intention',
      'label': '执行意图（If-Then）',
      'question': '你是否已经形成明确的“如果X发生，我就立即做Y”的触发计划？',
      'theories': <String>['IMPLEMENTATION_INTENTION'],
      'options': planOptions,
      'covers': <String>['specificity', 'trigger'],
    },
    'cue_clarity': {
      'id': 'cue_clarity',
      'label': '触发线索清晰度',
      'question': '启动行动的具体时间、地点或情境线索清楚吗？',
      'theories': <String>['IMPLEMENTATION_INTENTION'],
      'options': <Map<String, String>>[
        {'id': 'none', 'label': '没有明确触发线索'},
        {'id': 'vague', 'label': '只有大概时间／情境'},
        {'id': 'partial', 'label': '有线索，但仍可能错过'},
        {'id': 'clear', 'label': '线索具体且容易识别'},
        {'id': 'automatic', 'label': '线索一出现就很容易直接进入行动'},
        {'id': 'unknown', 'label': '不清楚／无法判断'},
      ],
      'covers': <String>['trigger'],
    },
    'response_specificity': {
      'id': 'response_specificity',
      'label': '启动动作具体度',
      'question': '触发出现后，你要立即做的第一步是否具体到可以直接执行？',
      'theories': <String>['IMPLEMENTATION_INTENTION'],
      'options': planOptions,
      'covers': <String>['specificity', 'preparation'],
    },
  };

  static List<Map<String, Object?>> theoryRows(Iterable<String> ids) => [
        for (final id in ids)
          if (theories[id] != null) Map<String, Object?>.from(theories[id]!)
      ];

  static List<Map<String, Object?>> activeFactors(Iterable<String> theoryIds) {
    final selected = theoryIds.toSet();
    final ids = <String>{};
    for (final theoryId in selected) {
      final theory = theories[theoryId];
      if (theory == null) continue;
      final factorIds = (theory['factor_ids'] as List).cast<String>();
      ids.addAll(factorIds);
    }
    return [
      for (final id in ids)
        if (factorDefinitions[id] != null)
          Map<String, Object?>.from(factorDefinitions[id]!)
    ];
  }

  static Set<String> coverageKeys(Iterable<String> theoryIds) {
    final out = <String>{};
    for (final factor in activeFactors(theoryIds)) {
      final covers = factor['covers'];
      if (covers is List) {
        out.addAll(covers.whereType<String>());
      }
    }
    return out;
  }

  static Map<String, Object?>? factor(String id) {
    final value = factorDefinitions[id];
    return value == null ? null : Map<String, Object?>.from(value);
  }

  static const factorToCanonicalConstruct = <String, String>{
    'intention': 'intention',
    'goal_commitment': 'intention',
    'reflective_motivation': 'intention',
    'attitude_toward_behavior': 'instrumental_attitude',
    'experiential_attitude': 'experiential_attitude',
    'instrumental_attitude': 'instrumental_attitude',
    'subjective_norm': 'injunctive_norm',
    'injunctive_norm': 'injunctive_norm',
    'descriptive_norm': 'descriptive_norm',
    'self_efficacy': 'self_efficacy',
    'maintenance_self_efficacy': 'self_efficacy',
    'recovery_self_efficacy': 'self_efficacy',
    'perceived_behavioral_control': 'perceived_control',
    'perceived_control': 'perceived_control',
    'knowledge_skills': 'knowledge_skills',
    'psychological_capability': 'knowledge_skills',
    'salience': 'salience',
    'environmental_constraints': 'environmental_constraints',
    'physical_opportunity': 'environmental_constraints',
    'environmental_facilitators': 'environmental_constraints',
    'habit': 'habit',
    'automatic_motivation': 'habit',
    'implementation_intention': 'implementation_intention',
    'action_planning': 'implementation_intention',
    'cue_clarity': 'implementation_intention',
    'response_specificity': 'implementation_intention',
  };

  static String canonicalConstruct(String factorId) =>
      factorToCanonicalConstruct[factorId] ?? factorId;

  static List<String> factorIdsForConstruct(String construct) => [
        for (final entry in factorToCanonicalConstruct.entries)
          if (entry.value == construct) entry.key
      ];

  /// Standard program option -> support score used only for transparent
  /// display/ranking after the user confirms an option.
  ///
  /// Every factor's non-unknown options are intentionally ordered from
  /// strongest blocker (0) to strongest support (4). This is not a fitted
  /// psychological coefficient and must not be treated as behavior
  /// probability.
  static double? supportScore(String factorId, String optionId) {
    if (optionId == 'unknown') return null;
    final factor = factorDefinitions[factorId];
    final options = factor?['options'];
    if (options is! List) return null;
    final ordered = <Map>[];
    for (final item in options) {
      if (item is Map && '${item['id']}' != 'unknown') ordered.add(item);
    }
    if (ordered.isEmpty) return null;
    final index = ordered.indexWhere((item) => '${item['id']}' == optionId);
    if (index < 0) return null;
    if (ordered.length == 1) return 2;
    return index * 4 / (ordered.length - 1);
  }

  static Map<String, String>? option(String factorId, String optionId) {
    final factor = factorDefinitions[factorId];
    final options = factor?['options'];
    if (options is! List) return null;
    for (final item in options) {
      if (item is Map && item['id'] == optionId) {
        return item.map((k, v) => MapEntry('$k', '$v'));
      }
    }
    return null;
  }
}
