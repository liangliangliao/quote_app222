import 'belief_models.dart';

/// 为“行动类关卡”统一追加：
/// - 计划/非计划模式
/// - 失败/挫折记录（为后续失败模块预留）
/// - 概念一致性评分与结果评分
/// - 学习/改变的挂钩字段（为后续模块预留）
class BeliefActionConsistency {
  static const String kMode = 'ac_mode';
  static const String kGoal = 'ac_goal_link';
  static const String kObstacle = 'ac_obstacles';
  static const String kFail = 'ac_fail';
  static const String kFailDetail = 'ac_fail_detail';
  static const String kMapping = 'ac_mapping';
  static const String kConceptMatch = 'ac_concept_match';
  static const String kResultScore = 'ac_result_score';
  static const String kEvidence = 'ac_evidence';
  static const String kLearnTags = 'ac_learning_tags';
  static const String kChangePath = 'ac_change_path';

  static bool _hasKey(List<BeliefStep> steps, String id) => steps.any((s) => s.id == id);

  static List<BeliefStep> enhanceMissionSteps(List<BeliefStep> steps) {
    // Already enhanced? Keep stable.
    if (_hasKey(steps, kConceptMatch) || _hasKey(steps, kResultScore)) return steps;

    final eval = <BeliefStep>[
      const BeliefStep(
        id: kMode,
        title: '行动模式',
        body: '本次行动属于哪种模式？\n\n计划模式：需要与“目标模块”对齐，按计划执行。\n非计划模式：当下就做的行动试验。',
        type: BeliefStepType.singleChoice,
        required: true,
        choices: [
          BeliefChoice(id: 'planned', text: '计划模式（关联目标）', hint: '用于目标驱动、阶段性推进'),
          BeliefChoice(id: 'quick', text: '非计划模式（当下试验）', hint: '用于即时启动、微行动'),
        ],
      ),
      const BeliefStep(
        id: kGoal,
        title: '关联目标（计划模式）',
        body: '如果你选了“计划模式”，在这里写下要关联的目标：\n- 目标是什么？\n- 期限/衡量标准？\n\n（后续接入目标模块时，可用此字段做关联。）',
        type: BeliefStepType.input,
        required: false,
      ),
      const BeliefStep(
        id: kObstacle,
        title: '困难/挫折记录（为失败模块预留）',
        body: '行动过程中遇到的困难是什么？\n请尽量写：\n- 触发情境（何时何地发生）\n- 你的反应/行为\n- 你希望下次如何调整',
        type: BeliefStepType.input,
        required: true,
      ),
      const BeliefStep(
        id: kFail,
        title: '本次结果：成功还是失败？',
        body: '这里的“失败”不是否定你，而是为了把它接到“失败模块/改变模块”。',
        type: BeliefStepType.singleChoice,
        required: true,
        choices: [
          BeliefChoice(id: 'success', text: '成功/部分成功', hint: '做到了，或有明显推进'),
          BeliefChoice(id: 'fail', text: '失败/中断', hint: '没有做完，或效果很差'),
        ],
      ),
      const BeliefStep(
        id: kFailDetail,
        title: '失败细节（若失败/中断）',
        body: '若你选择了“失败/中断”，请写清楚：\n- 失败发生在哪一步？\n- 最关键的原因（可控/不可控/信息缺失）\n- 下次要怎么改？\n\n（后续失败模块将读取此字段。）',
        type: BeliefStepType.input,
        required: false,
      ),
      const BeliefStep(
        id: kMapping,
        title: '概念 → 行动映射（核心一致性）',
        body: '为了确保“行动 = 概念的直观表达”，请用 3 句话写清：\n\n1) 本次概念的关键句是什么？\n2) 你做的哪一步/哪条清单，具体对应这个概念？\n3) 你用什么证据判断自己做到了？\n\n（后续可用于目标/学习/改变模块做自动生成与校验。）',
        type: BeliefStepType.input,
        required: true,
      ),
      const BeliefStep(
        id: kConceptMatch,
        title: '概念一致性评分',
        body: '本次行动是否真正体现了本概念？\n\n1=几乎不相关（像在瞎忙）\n5=高度一致（行动就是概念的直观表达）',
        type: BeliefStepType.rating,
        required: true,
        minRating: 1,
        maxRating: 5,
      ),
      const BeliefStep(
        id: kResultScore,
        title: '现实结果评分',
        body: '现实结果如何？\n\n1=几乎无效\n5=效果明显/可复用',
        type: BeliefStepType.rating,
        required: true,
        minRating: 1,
        maxRating: 5,
      ),
      const BeliefStep(
        id: kEvidence,
        title: '证据/结果描述',
        body: '请写下你观察到的现实证据（尽量具体）：\n- 发生了什么？\n- 你/他人有什么可见变化？\n- 有没有数字/次数/时长？\n\n（这是“概念在现实中的直观表达”的关键证据。）',
        type: BeliefStepType.input,
        required: true,
      ),
      const BeliefStep(
        id: kLearnTags,
        title: '学习模块挂钩（行为主义视角）',
        body: '从“行为建立/强化/习惯”角度，你希望后续学习模块提供哪类支持？（可多选）',
        type: BeliefStepType.multiChoice,
        required: false,
        choices: [
          BeliefChoice(id: 'stimulus', text: '刺激控制（线索/环境）'),
          BeliefChoice(id: 'reinforce', text: '正强化（奖励/反馈）'),
          BeliefChoice(id: 'punish', text: '弱化不良行为（移除触发/增加摩擦）'),
          BeliefChoice(id: 'shaping', text: '塑造（分级任务）'),
          BeliefChoice(id: 'record', text: '自我记录/监测（让反馈可见）'),
        ],
      ),
      const BeliefStep(
        id: kChangePath,
        title: '改变模块挂钩（问题行为/坏习惯）',
        body: '如果本次行动涉及长期坏习惯/问题行为，请写：\n- 旧行为是什么？\n- 触发是什么？\n- 你要替换成的新行为是什么？\n\n（后续改变模块会读取此字段并生成路径。）',
        type: BeliefStepType.input,
        required: false,
      ),
    ];

    // Keep existing summary at end if present.
    final out = <BeliefStep>[];
    if (steps.isNotEmpty && steps.last.type == BeliefStepType.summary) {
      out.addAll(steps.take(steps.length - 1));
      out.addAll(eval);
      out.add(steps.last);
      return out;
    }

    out.addAll(steps);
    out.addAll(eval);
    out.add(const BeliefStep(
      id: 'ac_summary',
      title: '收尾',
      body: '你已完成行动复盘。点击“完成”保存。',
      type: BeliefStepType.summary,
      required: false,
    ));
    return out;
  }
}

