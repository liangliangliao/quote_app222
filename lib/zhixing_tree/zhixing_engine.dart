import 'dart:math' as math;

import 'zhixing_models.dart';

class ZhixingEngine {
  static const int dailyXpCap = 100;
  static const int dailyCoinCap = 80;

  ZhixingRiskLevel detectRisk(String input, {String discomfort = ''}) {
    final text = input.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    const crisisTerms = <String>[
      '自杀',
      '不想活',
      '结束生命',
      '伤害自己',
      '杀了自己',
      '伤害别人',
      '杀人',
      'suicide',
      'killmyself',
    ];
    if (crisisTerms.any(text.contains)) return ZhixingRiskLevel.crisis;

    const highTerms = <String>[
      '被跟踪',
      '人身威胁',
      '家庭暴力',
      '正在被打',
      '报复',
      '毁掉他',
      '精神失常',
      '幻听',
      '活不下去',
      '严重绝望',
      '惊恐发作',
      '创伤闪回',
    ];
    if (highTerms.any(text.contains)) return ZhixingRiskLevel.high;

    const elevatedTerms = <String>[
      '医疗',
      '手术',
      '处方药',
      '法律',
      '诉讼',
      '巨额投资',
      '借高利贷',
      '失去住所',
      '没有饭吃',
      '现实危险',
    ];
    if (elevatedTerms.any(text.contains)) return ZhixingRiskLevel.elevated;
    if (discomfort == 'unbearable') return ZhixingRiskLevel.high;
    return ZhixingRiskLevel.none;
  }

  ZhixingPrescription generateLocal({
    required ZhixingDiagnosis diagnosis,
    required ZhixingActionProfile profile,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final risk = diagnosis.risk == ZhixingRiskLevel.none
        ? detectRisk(diagnosis.problem, discomfort: diagnosis.discomfort)
        : diagnosis.risk;
    if (risk == ZhixingRiskLevel.high || risk == ZhixingRiskLevel.crisis) {
      return _safetyPrescription(diagnosis, risk, now);
    }

    final type = selectChallenge(diagnosis);
    final difficulty = selectDifficulty(diagnosis, profile, risk);
    final match = matchThoughts(diagnosis, type, profile);
    final action = _actionFor(diagnosis, type, difficulty);
    final reward = _rewardFor(type, difficulty);
    final value = diagnosis.values.isEmpty ? _inferValue(diagnosis.problem) : diagnosis.values.first;

    return ZhixingPrescription(
      id: 'zx_${now}_${diagnosis.problem.hashCode.abs()}',
      diagnosisId: diagnosis.id,
      createdAtMs: now,
      updatedAtMs: now,
      problem: diagnosis.problem.trim(),
      challengeType: type,
      difficulty: difficulty,
      title: _titleFor(type, diagnosis.problem),
      value: value,
      action: action.action,
      trigger: action.trigger,
      firstPhysicalAction: action.firstPhysicalAction,
      successEvidence: action.successEvidence,
      stuckShrink: action.stuckShrink,
      stuckAdapt: action.stuckAdapt,
      stuckCarry: action.stuckCarry,
      stuckReconsider: action.stuckReconsider,
      thoughtMatch: match,
      rewardXp: reward.xp,
      rewardCoins: reward.coins,
      rewardWater: reward.water,
      rewardSunlight: reward.sunlight,
      rewardFertilizer: reward.fertilizer,
      risk: risk,
      safetyMessage: risk == ZhixingRiskLevel.elevated
          ? '这个问题可能包含医疗、法律、重大财务或现实资源风险。请把本卡当作整理下一步的辅助，不替代相应专业判断。'
          : '',
    );
  }

  ZhixingChallengeType selectChallenge(ZhixingDiagnosis diagnosis) {
    final text = diagnosis.problem;
    if (_containsAny(
      text,
      const <String>[
        '停止',
        '止损',
        '沉没成本',
        '边界',
        '说不',
        '拒绝继续',
        '拒绝不合理',
        '明确拒绝',
        '伤害性',
      ],
    )) {
      return ZhixingChallengeType.stopLoss;
    }
    if (_containsAny(text, const <String>['团队', '协作', '合作', '同事', '伴侣', '请求帮助', '一个人无法'])) {
      return ZhixingChallengeType.collaborate;
    }
    if (_containsAny(text, const <String>['创造', '作品', '成为怎样的人', '身份', '人生方式'])) {
      return ZhixingChallengeType.generate;
    }
    if (diagnosis.autonomy == 'no' || diagnosis.barrier == 'meaning') {
      return ZhixingChallengeType.direction;
    }
    if (diagnosis.barrier == 'energy') return ZhixingChallengeType.recovery;
    if (diagnosis.phase == 'return') return ZhixingChallengeType.sustain;
    if (diagnosis.barrier == 'ability') return ZhixingChallengeType.strengthen;
    if (diagnosis.barrier == 'environment') return ZhixingChallengeType.calibrate;
    if (diagnosis.barrier == 'emotion' &&
        (diagnosis.discomfort == 'strong' || diagnosis.discomfort == 'moderate')) {
      return ZhixingChallengeType.breakthrough;
    }
    if (diagnosis.barrier == 'thought' &&
        _containsAny(text, const <String>['失败', '完美', '永远', '一定', '不可能', '证明'])) {
      return ZhixingChallengeType.calibrate;
    }
    if (diagnosis.phase == 'sustain') return ZhixingChallengeType.sustain;
    if (diagnosis.clarity == 'none') return ZhixingChallengeType.direction;
    return ZhixingChallengeType.start;
  }

  ZhixingDifficulty selectDifficulty(
    ZhixingDiagnosis diagnosis,
    ZhixingActionProfile profile,
    ZhixingRiskLevel risk,
  ) {
    if (risk != ZhixingRiskLevel.none) return ZhixingDifficulty.l1;
    if (diagnosis.discomfort == 'strong' ||
        diagnosis.experience == 'never' ||
        diagnosis.availableMinutes <= 5 ||
        profile.selfEfficacy < .35 ||
        profile.energy < .3) {
      return ZhixingDifficulty.l1;
    }
    if (diagnosis.discomfort == 'mild' &&
        diagnosis.experience == 'success' &&
        diagnosis.availableMinutes >= 30 &&
        profile.selfEfficacy >= .65) {
      return ZhixingDifficulty.l3;
    }
    return ZhixingDifficulty.l2;
  }

  ZhixingThoughtMatch matchThoughts(
    ZhixingDiagnosis diagnosis,
    ZhixingChallengeType type,
    ZhixingActionProfile profile,
  ) {
    final confidence = _matchConfidence(diagnosis, profile);
    switch (type) {
      case ZhixingChallengeType.recovery:
        return ZhixingThoughtMatch(
          dominant: 'Tal Ben-Shahar：压力—恢复',
          executionTool: '老子：知止、做减法、降低摩擦',
          assistants: const <String>['COM-B：先检查身体资源与现实能力'],
          balancing: 'ACT：恢复服务于价值行动，避免把休息变成无限回避',
          rationale: '当前断点主要是能量与恢复资源不足，继续加压会进一步降低行动能力。',
          boundary: '持续或严重的身体、睡眠和心理症状需要专业评估，不能只靠恢复任务处理。',
          confidence: confidence,
          sources: const <String>['Tal Ben-Shahar 幸福课：压力与恢复', '《道德经》', 'COM-B 行为模型'],
        );
      case ZhixingChallengeType.direction:
        return ZhixingThoughtMatch(
          dominant: '自我决定理论：自主、胜任、关系',
          executionTool: 'ACT：把价值翻译成一个可选择的方向',
          assistants: const <String>['尼采：这是创造自己，还是向别人证明？', '弗兰克尔：愿意承担什么责任？'],
          balancing: '杜威：价值判断仍需通过低成本现实实验修正',
          rationale: '当前目标的自主性或意义连接不清，先优化执行可能只是更高效地走向错误方向。',
          boundary: '自主不等于只做舒服的事，也不等于忽略真实责任与共同条件。',
          confidence: confidence,
          sources: const <String>['Self-Determination Theory', 'ACT', '《道德的谱系》', '《活出意义来》'],
        );
      case ZhixingChallengeType.start:
        return ZhixingThoughtMatch(
          dominant: '威廉·詹姆斯：意志、动作观念与习惯',
          executionTool: '第一身体动作 + 如果—那么实施意图',
          assistants: const <String>['王阳明：在具体事情上把认识发动出来', '行为激活：动力也可以是行动的结果'],
          balancing: 'COM-B：若仍无法启动，检查能力、机会和环境，不把原因都归给意志',
          rationale: '目标大体明确，最核心的断点是第一动作尚未进入现实。',
          boundary: '第一动作不能解决深层价值冲突，也不能替代所需技能、资源和安全条件。',
          confidence: confidence,
          sources: const <String>['《心理学原理》意志与习惯章节', '《传习录》', 'Implementation Intentions'],
        );
      case ZhixingChallengeType.breakthrough:
        return ZhixingThoughtMatch(
          dominant: 'ACT：不必先消灭不适才行动',
          executionTool: '班杜拉：分级掌握经验',
          assistants: const <String>['Tal Ben-Shahar：允许自己为人'],
          balancing: '老子：柔、渐进、不过度硬冲',
          rationale: '用户把恐惧、羞耻或焦虑的消失当成了行动资格，需要在可承受范围内恢复选择。',
          boundary: '这不是要求忍受现实伤害；创伤、高风险暴露或无法承受的不适应转向专业支持。',
          confidence: confidence,
          sources: const <String>['Acceptance and Commitment Therapy', 'Self-Efficacy', '《道德经》'],
        );
      case ZhixingChallengeType.strengthen:
        return ZhixingThoughtMatch(
          dominant: '班杜拉：自我效能来自真实掌握经验',
          executionTool: '略高于当前能力的一阶训练 + 可见反馈',
          assistants: const <String>['德韦克：奖励策略调整与再投入', '杜威：行动是可修正的实验'],
          balancing: 'Tal Ben-Shahar：允许失败并安排恢复',
          rationale: '方向和意愿并非主要问题，当前更需要技能、资源与真实完成证据。',
          boundary: '空洞鼓励不能替代训练；任务必须与现实能力、时间和资源匹配。',
          confidence: confidence,
          sources: const <String>['Self-Efficacy: The Exercise of Control', 'Mindset', '《我们怎样思维》'],
        );
      case ZhixingChallengeType.sustain:
        return ZhixingThoughtMatch(
          dominant: 'Tal Ben-Shahar：仪式、最优主义与恢复',
          executionTool: '固定触发 + 如果—那么复归计划',
          assistants: const <String>['威廉·詹姆斯：把有益动作交给习惯'],
          balancing: '老子：知止，避免连续打卡转化为自我压迫',
          rationale: '当前问题不只是开始，而是稳定重复或中断后的复归。',
          boundary: '复归比不断签更重要；中断不等于人格失败，也不应要求双倍补偿。',
          confidence: confidence,
          sources: const <String>['Tal Ben-Shahar 幸福课', '《心理学原理》习惯章节', 'Implementation Intentions'],
        );
      case ZhixingChallengeType.calibrate:
        return ZhixingThoughtMatch(
          dominant: '杜威：思想是假设，行动是实验',
          executionTool: 'CBT：事实—解释—证据—小实验',
          assistants: const <String>['塞利格曼：不把失败永久化、普遍化、人格化'],
          balancing: 'ACT：避免无限认知争辩，用行动产生新证据',
          rationale: '现有解释、计划或环境条件需要现实反馈，而不是继续在头脑里求绝对确定。',
          boundary: '认知重评不能否认真实伤害、结构限制或明确风险。',
          confidence: confidence,
          sources: const <String>['《我们怎样思维》', '《认知疗法与情绪障碍》', 'Learned Optimism'],
        );
      case ZhixingChallengeType.stopLoss:
        return ZhixingThoughtMatch(
          dominant: '老子：知止、去甚、去奢、去泰',
          executionTool: '明确一条边界、退出条件或暂停决定',
          assistants: const <String>['自我决定理论：保护自主性', '实践智慧：按具体情境判断'],
          balancing: 'ACT：知止不是逃避，仍要承担与价值一致的必要责任',
          rationale: '继续投入可能源于沉没成本、边界侵犯或错误目标，停止也是一种现实行动。',
          boundary: '涉及安全、劳动、法律或重要关系时，应先取得专业或可信支持再执行退出。',
          confidence: confidence,
          sources: const <String>['《道德经》', 'Self-Determination Theory', 'Nicomachean Ethics'],
        );
      case ZhixingChallengeType.collaborate:
        return ZhixingThoughtMatch(
          dominant: '杜威：问题在共同经验中被检验和修正',
          executionTool: '提出一个明确请求，确认责任、资源与下一次检查点',
          assistants: const <String>['罗杰斯：真实表达与准确理解', '阿伦特：在共同世界中开始'],
          balancing: 'COM-B：承认权限、资源与组织结构，不把系统问题个人化',
          rationale: '当前行动无法只靠个人意志完成，需要关系、分工或共同条件。',
          boundary: '协同不等于讨好或替他人负责；权力不对等和现实危险需要额外保护。',
          confidence: confidence,
          sources: const <String>['《经验与教育》', 'On Becoming a Person', 'The Human Condition'],
        );
      case ZhixingChallengeType.generate:
        return ZhixingThoughtMatch(
          dominant: '尼采：从反应他人转向创造自己的价值',
          executionTool: '王阳明：在具体作品和事情上实现知行合一',
          assistants: const <String>['弗兰克尔：通过责任与自我超越生成意义'],
          balancing: '老子：不以自我迫害证明强大，给创造保留柔与空',
          rationale: '当前目标指向长期身份、作品或生活方式，需要用连续创造而非口号生成自己。',
          boundary: '自我克服不是透支、冒险或蔑视他人；创造仍受事实、安全和共同生活约束。',
          confidence: confidence,
          sources: const <String>['《查拉图斯特拉如是说》', '《传习录》', '《活出意义来》', '《道德经》'],
        );
    }
  }

  ZhixingActionProfile profileAfterDiagnosis(
    ZhixingActionProfile current,
    ZhixingDiagnosis diagnosis,
  ) {
    double signal(String dimension) {
      switch (dimension) {
        case 'autonomy':
          return diagnosis.autonomy == 'yes' ? .85 : (diagnosis.autonomy == 'partly' ? .55 : .2);
        case 'clarity':
          return diagnosis.clarity == 'clear' ? .85 : (diagnosis.clarity == 'vague' ? .5 : .2);
        case 'cognitive':
          return diagnosis.barrier == 'thought' ? .3 : .65;
        case 'willingness':
          return diagnosis.barrier == 'emotion'
              ? (diagnosis.discomfort == 'strong' ? .3 : .5)
              : .65;
        case 'efficacy':
          return diagnosis.experience == 'success'
              ? .8
              : (diagnosis.experience == 'sometimes' ? .55 : .25);
        case 'optimalism':
          return _containsAny(diagnosis.problem, const <String>['完美', '不能失败', '必须做到'])
              ? .25
              : .65;
        case 'habit':
          return diagnosis.phase == 'sustain' || diagnosis.phase == 'return' ? .35 : .55;
        case 'energy':
          return diagnosis.barrier == 'energy' ? .2 : .65;
        case 'opportunity':
          return diagnosis.barrier == 'environment' ? .25 : .65;
        case 'safety':
          return diagnosis.risk == ZhixingRiskLevel.none ? 1 : .25;
      }
      return .5;
    }

    double blend(double old, double next) => (old * .7 + next * .3).clamp(0, 1).toDouble();
    return ZhixingActionProfile(
      autonomy: blend(current.autonomy, signal('autonomy')),
      clarity: blend(current.clarity, signal('clarity')),
      cognitiveFlexibility: blend(current.cognitiveFlexibility, signal('cognitive')),
      willingness: blend(current.willingness, signal('willingness')),
      selfEfficacy: blend(current.selfEfficacy, signal('efficacy')),
      optimalism: blend(current.optimalism, signal('optimalism')),
      habitStructure: blend(current.habitStructure, signal('habit')),
      energy: blend(current.energy, signal('energy')),
      opportunity: blend(current.opportunity, signal('opportunity')),
      safety: blend(current.safety, signal('safety')),
      completedCount: current.completedCount,
      recalibrationCount: current.recalibrationCount,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  ZhixingActionProfile profileAfterEvidence(
    ZhixingActionProfile current,
    ZhixingPrescription prescription,
    ZhixingEvidence evidence,
  ) {
    final completedSignal = evidence.completed ? .8 : .35;
    final fitSignal = evidence.fit == '准确' ? .8 : (evidence.fit == '部分准确' ? .55 : .3);
    final scaleSignal = evidence.scale == '合适' ? .75 : .45;
    double blend(double old, double next) => (old * .8 + next * .2).clamp(0, 1).toDouble();
    return ZhixingActionProfile(
      autonomy: blend(current.autonomy, fitSignal),
      clarity: blend(current.clarity, scaleSignal),
      cognitiveFlexibility: blend(
        current.cognitiveFlexibility,
        evidence.learning.trim().isEmpty ? .5 : .75,
      ),
      willingness: blend(
        current.willingness,
        evidence.actualDiscomfort <= evidence.predictedDiscomfort ? .75 : .5,
      ),
      selfEfficacy: blend(current.selfEfficacy, completedSignal),
      optimalism: blend(current.optimalism, evidence.completed ? .7 : .55),
      habitStructure: blend(
        current.habitStructure,
        prescription.challengeType == ZhixingChallengeType.sustain ? completedSignal : .55,
      ),
      energy: blend(
        current.energy,
        prescription.challengeType == ZhixingChallengeType.recovery && evidence.completed ? .75 : .55,
      ),
      opportunity: blend(current.opportunity, evidence.completed ? .7 : .45),
      safety: current.safety,
      completedCount: current.completedCount + (evidence.completed ? 1 : 0),
      recalibrationCount: current.recalibrationCount + (evidence.completed ? 0 : 1),
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  static List<ZhixingThoughtModule> get thoughtCatalog => const <ZhixingThoughtModule>[
        ZhixingThoughtModule(
          name: '王阳明',
          coreValue: '良知、诚意、事上磨炼',
          mechanism: '真知必须在现实事情中发动。',
          suitableFor: '抽象理解很多，但实践很少。',
          actionRule: '把认识翻译成一个可观察动作和完成证据。',
          boundary: '避免把“知而未行”道德化为人格自责。',
          source: '《传习录》《大学问》',
          evidenceLevel: '哲学原典 + 产品行动转译',
        ),
        ZhixingThoughtModule(
          name: '威廉·詹姆斯',
          coreValue: '注意、意志、习惯',
          mechanism: '清晰的动作观念与身体启动有助于跨过犹豫。',
          suitableFor: '目标清楚，却迟迟没有开始。',
          actionRule: '确定第一身体动作并立即执行。',
          boundary: '不能替代价值判断、技能、资源与安全条件。',
          source: '《心理学原理》习惯、注意、运动与意志章节',
          evidenceLevel: '经典心理学 + 现代行为机制相容',
        ),
        ZhixingThoughtModule(
          name: '贝克 / 埃利斯',
          coreValue: '证据、理性、认知弹性',
          mechanism: '解释与信念会影响情绪和行为。',
          suitableFor: '灾难化、绝对化、过度概括。',
          actionRule: '区分事实与解释，用低成本实验收集证据。',
          boundary: '不能否认真实伤害、结构限制和现实危险。',
          source: '《认知疗法与情绪障碍》《理性与情绪心理学》',
          evidenceLevel: '循证心理治疗理论',
        ),
        ZhixingThoughtModule(
          name: '老子',
          coreValue: '无为、柔、知止、简',
          mechanism: '减少多余控制，有时比增加强迫更有效。',
          suitableFor: '越逼越僵、过载、沉没成本与边界问题。',
          actionRule: '删除不必要条件，降低摩擦，必要时停止。',
          boundary: '无为不是逃避，接纳也不是忍受伤害。',
          source: '《道德经》',
          evidenceLevel: '哲学原典 + 行为设计转译',
        ),
        ZhixingThoughtModule(
          name: 'ACT',
          coreValue: '接纳、解离、价值行动',
          mechanism: '不必先消灭不适，仍可选择价值方向。',
          suitableFor: '经验回避、恐惧、羞耻、焦虑。',
          actionRule: '在可承受、安全的范围内，带着不适走一步。',
          boundary: '不适与现实伤害必须区分；高风险情境需专业支持。',
          source: 'Acceptance and Commitment Therapy',
          evidenceLevel: '循证心理治疗理论',
        ),
        ZhixingThoughtModule(
          name: '尼采',
          coreValue: '主体性、自我克服、价值创造',
          mechanism: '从反应、证明和报复转向创造自己的生活。',
          suitableFor: '目标受外部评价控制，长期身份与作品生成。',
          actionRule: '审查目标来源，用具体创造替代反应。',
          boundary: '不能把自我克服误作自我迫害或否认有限性。',
          source: '《道德的谱系》《快乐的科学》《查拉图斯特拉如是说》',
          evidenceLevel: '哲学原典 + 产品行动转译',
        ),
        ZhixingThoughtModule(
          name: '弗兰克尔',
          coreValue: '意义、责任、自我超越',
          mechanism: '人在限制中仍能选择一个有意义的回应。',
          suitableFor: '失控、长期困难、意义缺失。',
          actionRule: '选择当下可承担的一项责任行动。',
          boundary: '不浪漫化苦难，也不忽略现实保护和资源。',
          source: '《活出意义来》《意义意志》',
          evidenceLevel: '存在主义心理治疗传统',
        ),
        ZhixingThoughtModule(
          name: '自我决定理论',
          coreValue: '自主、胜任、关系',
          mechanism: '动机质量影响长期持续。',
          suitableFor: '目标不自主、内在抵触、外部评价控制。',
          actionRule: '重建自主理由、胜任阶梯和必要支持。',
          boundary: '自主不等于只做舒服的事。',
          source: 'Self-Determination Theory',
          evidenceLevel: '现代动机研究',
        ),
        ZhixingThoughtModule(
          name: '班杜拉',
          coreValue: '能动性、自我效能、掌握经验',
          mechanism: '真实完成是“我做得到”的主要证据。',
          suitableFor: '低效能、害怕挑战、技能信心不足。',
          actionRule: '设计略高于当前能力的一阶任务。',
          boundary: '不能忽略真实技能、资源和机会。',
          source: 'Self-Efficacy: The Exercise of Control',
          evidenceLevel: '现代社会认知研究',
        ),
        ZhixingThoughtModule(
          name: '杜威',
          coreValue: '经验、探究、可修正',
          mechanism: '思想是假设，行动是实验。',
          suitableFor: '复杂不确定、信息不足、反复无效。',
          actionRule: '低成本试验—反馈—修正。',
          boundary: '简单任务不宜过度分析。',
          source: '《我们怎样思维》《经验与教育》',
          evidenceLevel: '实用主义原典 + 探究学习',
        ),
        ZhixingThoughtModule(
          name: '塞利格曼',
          coreValue: '现实乐观、韧性',
          mechanism: '失败不必永久化、普遍化和人格化。',
          suitableFor: '一次失败后全面放弃。',
          actionRule: '限定失败范围，寻找可变因素。',
          boundary: '不能否认结构困难或强行积极。',
          source: 'Learned Optimism',
          evidenceLevel: '积极心理与解释风格研究',
        ),
        ZhixingThoughtModule(
          name: '德韦克',
          coreValue: '成长、策略、可塑性',
          mechanism: '失败提供学习信息，而不是身份判决。',
          suitableFor: '固定能力观、害怕错误。',
          actionRule: '奖励策略调整、训练与再投入。',
          boundary: '成长观念不能替代真实训练和资源。',
          source: 'Mindset',
          evidenceLevel: '教育与动机研究',
        ),
        ZhixingThoughtModule(
          name: 'Tal Ben-Shahar',
          coreValue: '转化、自洽目标、仪式、恢复',
          mechanism: '持续改变依赖行为、仪式、最优主义和恢复。',
          suitableFor: '三分钟热度、完美主义、过劳。',
          actionRule: '稳定仪式 + 允许失败 + 安排恢复。',
          boundary: '积极心理不能替代医疗或心理治疗。',
          source: '哈佛积极心理学课程',
          evidenceLevel: '积极心理学综合转译',
        ),
        ZhixingThoughtModule(
          name: 'COM-B',
          coreValue: '能力、机会、动机',
          mechanism: '行为依赖能力、机会和动机共同存在。',
          suitableFor: '原因不明的反复失败。',
          actionRule: '分别检查并修复技能、环境和动机。',
          boundary: '诊断框架不能解决终极价值。',
          source: 'COM-B Behaviour Change Wheel',
          evidenceLevel: '现代行为科学框架',
        ),
        ZhixingThoughtModule(
          name: '实施意图 / 行为激活',
          coreValue: '情境触发、行动先行',
          mechanism: '“如果 X，就做 Y”可减少临场决策；动力也可能是行动结果。',
          suitableFor: '忘记、犹豫、低动力、生活收缩。',
          actionRule: '绑定明确触发，并安排有自然回报的可完成活动。',
          boundary: '深层冲突或严重状态需要更高层级处理。',
          source: 'Implementation Intentions / Behavioral Activation',
          evidenceLevel: '现代行为干预研究',
        ),
      ];

  double _matchConfidence(ZhixingDiagnosis diagnosis, ZhixingActionProfile profile) {
    var score = .55;
    if (diagnosis.problem.trim().length >= 8) score += .08;
    if (diagnosis.barrier.isNotEmpty) score += .08;
    if (diagnosis.values.isNotEmpty) score += .05;
    if (diagnosis.clarity != 'vague') score += .04;
    if (profile.completedCount >= 3) score += .04;
    return score.clamp(.45, .86).toDouble();
  }

  _ActionTemplate _actionFor(
    ZhixingDiagnosis diagnosis,
    ZhixingChallengeType type,
    ZhixingDifficulty difficulty,
  ) {
    final minutes = math.max(1, math.min(diagnosis.availableMinutes, difficulty == ZhixingDifficulty.l1 ? 5 : 30));
    final target = _targetAction(diagnosis.problem, minutes, type);
    final first = _firstPhysicalAction(diagnosis.problem, type);
    final evidence = _evidenceFor(diagnosis.problem, type);
    final trigger = type == ZhixingChallengeType.recovery
        ? '今天到达你设定的停止时间时'
        : '今天第一个不被打断的 $minutes 分钟开始时';
    return _ActionTemplate(
      action: target,
      trigger: trigger,
      firstPhysicalAction: first,
      successEvidence: evidence,
      stuckShrink: '把任务缩到 30 秒：只做“$first”，做完即可停下并记录。',
      stuckAdapt: '移除眼前最大的一个阻力，或向一个具体的人请求一种具体支持，然后再做第一动作。',
      stuckCarry: '先说“我注意到不适正在出现，但它不替我决定”，随后只完成“$first”。',
      stuckReconsider: '暂停执行，检查这个目标是否自主、安全、具备资源，或是否更需要恢复、止损与专业支持。',
    );
  }

  String _targetAction(String text, int minutes, ZhixingChallengeType type) {
    switch (type) {
      case ZhixingChallengeType.recovery:
        return '取消或延后今晚一项非必要事务，关闭通知，完成 20 分钟无屏幕恢复。';
      case ZhixingChallengeType.direction:
        return '用 ${math.max(10, minutes)} 分钟写下这个目标与三个真实人生方向的关系，并作出“继续、修改或暂停”中的一个明确选择。';
      case ZhixingChallengeType.stopLoss:
        return '写下一条明确的停止条件或边界，并完成一个安全、可控的落实动作。';
      case ZhixingChallengeType.collaborate:
        return '向一个相关的人提出一个具体请求，确认责任、所需资源和下一次检查时间。';
      case ZhixingChallengeType.generate:
        return '完成一个可见、可保存的最小作品版本，并记录它正在塑造怎样的自己。';
      case ZhixingChallengeType.calibrate:
        return '把最强解释写成一个可检验假设，并用一个 $minutes 分钟的小实验收集一条事实证据。';
      case ZhixingChallengeType.breakthrough:
        if (_containsAny(text, const <String>['投递', '求职', '简历', '找工作'])) {
          return '打开招聘页面，选择一个基本符合条件的岗位并完成一次投递。';
        }
        if (_containsAny(text, const <String>['表达', '发言', '联系', '消息'])) {
          return '向一个安全、合适的对象发送一条不求完美但意思清楚的信息。';
        }
        return '在可承受范围内，带着当前不适完成一个 $minutes 分钟的最低行动，并留下证据。';
      case ZhixingChallengeType.strengthen:
        return '完成一项只比当前水平高一阶、能在 $minutes 分钟内得到反馈的训练。';
      case ZhixingChallengeType.sustain:
        return '在固定触发出现时完成 $minutes 分钟最低版本；若已中断，就只执行一次复归，不补偿过去。';
      case ZhixingChallengeType.start:
        break;
    }
    if (_containsAny(text, const <String>['投递', '求职', '简历', '找工作'])) {
      return '打开招聘页面或简历，完成一个 $minutes 分钟的小部分并留下可见进展。';
    }
    if (_containsAny(text, const <String>['写作', '文章', '报告', '论文', '文档'])) {
      return '打开文档，写下标题和第一段粗糙草稿，持续 $minutes 分钟后即可停止。';
    }
    if (_containsAny(text, const <String>['学习', '英语', '数学', '读书', '课程'])) {
      return '打开对应材料，只学习 $minutes 分钟，并写下一条学到的内容。';
    }
    if (_containsAny(text, const <String>['运动', '锻炼', '跑步', '健身'])) {
      return '穿好运动装备，完成 $minutes 分钟轻量运动。';
    }
    if (_containsAny(text, const <String>['联系', '沟通', '回复', '消息'])) {
      return '写出并发送一条意思清楚、边界合适的信息。';
    }
    return '打开完成这件事所需的唯一入口，只做 $minutes 分钟最低版本，并留下一个事实记录。';
  }

  String _firstPhysicalAction(String text, ZhixingChallengeType type) {
    if (type == ZhixingChallengeType.recovery) return '把手机调为勿扰并放到手够不到的位置';
    if (type == ZhixingChallengeType.direction) return '拿出纸或打开空白笔记，写下目标名称';
    if (type == ZhixingChallengeType.stopLoss) return '打开空白笔记，写下“我将在何种条件下停止”';
    if (type == ZhixingChallengeType.collaborate) return '打开与相关人的对话窗口或约会安排';
    if (type == ZhixingChallengeType.generate) return '打开作品文件，建立一个最小版本';
    if (_containsAny(text, const <String>['投递', '求职', '找工作'])) return '解锁手机并打开招聘软件';
    if (_containsAny(text, const <String>['写作', '文章', '报告', '论文'])) return '打开目标文档并把光标放在第一行';
    if (_containsAny(text, const <String>['学习', '英语', '数学', '读书'])) return '把学习材料放到眼前并打开目标页';
    if (_containsAny(text, const <String>['运动', '锻炼', '跑步'])) return '站起来并穿上运动鞋';
    if (_containsAny(text, const <String>['联系', '沟通', '消息'])) return '打开对话窗口并写下称呼';
    return '打开完成任务所需的材料或入口';
  }

  String _evidenceFor(String text, ZhixingChallengeType type) {
    if (type == ZhixingChallengeType.recovery) return '在设定时间停止工作，并留下 20 分钟恢复完成记录';
    if (type == ZhixingChallengeType.direction) return '保存一条“继续、修改或暂停”的决定及其自主理由';
    if (type == ZhixingChallengeType.stopLoss) return '保存边界或停止条件，并记录已落实的动作';
    if (type == ZhixingChallengeType.collaborate) return '对话或日程中出现明确请求、责任和检查时间';
    if (type == ZhixingChallengeType.generate) return '保存一个可以再次打开的作品版本';
    if (_containsAny(text, const <String>['投递', '求职'])) return '页面显示“已投递”或保存本次简历修改';
    if (_containsAny(text, const <String>['写作', '报告', '论文'])) return '文档中出现标题与第一段，且已保存';
    if (_containsAny(text, const <String>['联系', '消息', '沟通'])) return '消息显示已发送，或保存一份明确草稿';
    return '保存一条带时间的完成事实、截图、文件变化或简短记录';
  }

  _Reward _rewardFor(ZhixingChallengeType type, ZhixingDifficulty difficulty) {
    if (type == ZhixingChallengeType.recovery) {
      return const _Reward(xp: 5, coins: 6, water: 2);
    }
    var base = 5;
    switch (difficulty) {
      case ZhixingDifficulty.l1:
        base = 5;
        break;
      case ZhixingDifficulty.l2:
        base = 10;
        break;
      case ZhixingDifficulty.l3:
        base = 20;
        break;
      case ZhixingDifficulty.l4:
        base = 30;
        break;
    }
    return _Reward(
      xp: base,
      coins: base,
      water: type == ZhixingChallengeType.sustain ? 1 : 0,
      sunlight: <ZhixingChallengeType>{
        ZhixingChallengeType.direction,
        ZhixingChallengeType.start,
        ZhixingChallengeType.generate,
      }.contains(type)
          ? 1
          : 0,
      fertilizer: <ZhixingChallengeType>{
        ZhixingChallengeType.breakthrough,
        ZhixingChallengeType.strengthen,
        ZhixingChallengeType.calibrate,
      }.contains(type)
          ? 1
          : 0,
    );
  }

  ZhixingPrescription _safetyPrescription(
    ZhixingDiagnosis diagnosis,
    ZhixingRiskLevel risk,
    int now,
  ) {
    final crisis = risk == ZhixingRiskLevel.crisis;
    final message = crisis
        ? '你现在的安全比任何效率、坚持或自我克服都重要。请立刻联系当地紧急服务、危机支持、专业人员，或请一位可信赖的人来到你身边；同时远离可能造成伤害的工具和环境。'
        : '这里出现了需要现实保护或专业评估的高风险信号。先不要继续普通行动挑战；请联系合适的专业人员，或请一位可信赖的人陪同你处理当前安全与资源问题。';
    return ZhixingPrescription(
      id: 'zx_safe_${now}_${diagnosis.problem.hashCode.abs()}',
      diagnosisId: diagnosis.id,
      createdAtMs: now,
      updatedAtMs: now,
      problem: diagnosis.problem,
      challengeType: ZhixingChallengeType.recovery,
      difficulty: ZhixingDifficulty.l1,
      title: crisis ? '先保护生命与当下安全' : '先获得现实保护与专业支持',
      value: '安全',
      action: crisis
          ? '现在联系当地紧急服务、危机支持或一位能到场陪伴的可信赖者。'
          : '现在联系一位合适的专业人员或可信赖者，明确说出你需要陪同与现实支持。',
      trigger: '现在',
      firstPhysicalAction: '拿起手机，打开紧急服务、专业人员或可信赖者的联系方式',
      successEvidence: '已经与一个真实的人或服务建立联系，并说明当前风险与需要',
      stuckShrink: '只完成第一步：把“我现在需要你陪我处理安全问题”发送给可信赖者。',
      stuckAdapt: '如果无法独自联系，请走到有人的安全地点，请现场人员协助联系。',
      stuckCarry: '允许害怕或羞耻存在，但不要独自承担风险；仍然完成求助动作。',
      stuckReconsider: '不要把求助改写成普通效率任务；安全优先级不变。',
      thoughtMatch: const ZhixingThoughtMatch(
        dominant: '现实安全与专业支持优先',
        executionTool: '联系真实的人、服务与保护资源',
        balancing: '任何哲学或自助方法都不能替代紧急保护和专业评估',
        rationale: '当前信号已超出普通行动力训练的安全范围。',
        boundary: '本系统不进行临床诊断，也不在危机情境下推动暴露、硬撑或自我克服。',
        confidence: 1,
        sources: <String>['产品安全边界'],
      ),
      rewardXp: 0,
      rewardCoins: 0,
      risk: risk,
      safetyMessage: message,
    );
  }

  String _titleFor(ZhixingChallengeType type, String problem) {
    final core = problem.replaceAll(RegExp(r'\s+'), ' ').trim();
    final short = core.length <= 18 ? core : '${core.substring(0, 18)}…';
    switch (type) {
      case ZhixingChallengeType.recovery:
        return '先恢复，再前进';
      case ZhixingChallengeType.direction:
        return '确认这是不是你的方向';
      case ZhixingChallengeType.start:
        return short.isEmpty ? '让第一动作发生' : '启动：$short';
      case ZhixingChallengeType.breakthrough:
        return '带着不适走一小步';
      case ZhixingChallengeType.strengthen:
        return '用掌握经验增强能力';
      case ZhixingChallengeType.sustain:
        return '今天只做一次稳定复归';
      case ZhixingChallengeType.calibrate:
        return '把判断交给现实实验';
      case ZhixingChallengeType.stopLoss:
        return '停止也可以是清醒行动';
      case ZhixingChallengeType.collaborate:
        return '把个人难题变成共同动作';
      case ZhixingChallengeType.generate:
        return '用作品生成新的自己';
    }
  }

  String _inferValue(String input) {
    const values = <String>['健康', '成长', '学习', '创造', '关系', '家庭', '自由', '责任', '真诚', '贡献', '意义', '专业'];
    for (final value in values) {
      if (input.contains(value)) return value;
    }
    return '成长';
  }

  bool _containsAny(String text, List<String> terms) => terms.any(text.contains);
}

class _ActionTemplate {
  final String action;
  final String trigger;
  final String firstPhysicalAction;
  final String successEvidence;
  final String stuckShrink;
  final String stuckAdapt;
  final String stuckCarry;
  final String stuckReconsider;

  const _ActionTemplate({
    required this.action,
    required this.trigger,
    required this.firstPhysicalAction,
    required this.successEvidence,
    required this.stuckShrink,
    required this.stuckAdapt,
    required this.stuckCarry,
    required this.stuckReconsider,
  });
}

class _Reward {
  final int xp;
  final int coins;
  final int water;
  final int sunlight;
  final int fertilizer;

  const _Reward({
    required this.xp,
    required this.coins,
    this.water = 0,
    this.sunlight = 0,
    this.fertilizer = 0,
  });
}
