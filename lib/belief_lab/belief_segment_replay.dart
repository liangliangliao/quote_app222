import 'belief_models.dart';

/// 逐段“案例重演”辅助：
/// - 每个概念的每个关联段落，都生成一个可复盘的重演关卡
/// - 关卡内容直接引用资料库段落（简化原文），并要求用户做现实映射与一致性评分

String makeSegmentReplayEpisodeId({required String conceptId, required String segmentKey}) {
  final safe = segmentKey.replaceAll('#', '_').replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  return 'seg_${conceptId}_$safe';
}

List<BeliefStep> buildSegmentReplaySteps({required BeliefConcept concept, required BeliefSegment segment}) {
  return [
    BeliefStep(
      id: 'info_segment',
      type: BeliefStepType.info,
      title: '段落还原：${segment.key} · ${segment.title}',
      body: segment.body,
    ),
    BeliefStep(
      id: 'operational',
      type: BeliefStepType.input,
      title: '把概念翻译成“可执行规则”',
      body: '用一句话写出：当我遇到 X 情境时，我要做 Y 行为，以得到 Z 结果。\n\n提示：这句话要能被观察/计数/验证。',
    ),
    BeliefStep(
      id: 'case_replay',
      type: BeliefStepType.input,
      title: '现实直接还原：写一个你的“同构案例”',
      body: '写下最近一次你/身边人经历过与这段内容高度一致的真实场景。\n\n要求：\n- 只写事实与行为（不写评价）\n- 标出关键触发线索（时间/地点/人物/情绪/目标）',
    ),
    BeliefStep(
      id: 'experiment',
      type: BeliefStepType.checklist,
      title: '行动实验（24–72小时）',
      body: '让“概念”在现实中出现一次：做一个最小实验，把证据拉出来。',
      checklist: [
        '我选定了一个可复现的触发情境（X）',
        '我定义了一个最小可行动作（Y，≤10分钟）',
        '我写了一个可验证的成功判据（Z，可观察/计数）',
        '我安排了执行时间与地点（什么时候/在哪里）',
        '我完成后会写1句：证据是什么？学到什么？',
      ],
    ),
    BeliefStep(
      id: 'alignment_rating',
      type: BeliefStepType.rating,
      title: '一致性评分（0–5）',
      body: '你这次的现实结果与该段落/概念的描述匹配程度：\n0=完全不一致；5=高度一致（几乎是直观呈现）。',
      minRating: 0,
      maxRating: 5,
    ),
    BeliefStep(
      id: 'failure_note',
      type: BeliefStepType.input,
      title: '如果不一致：哪一个变量导致偏差？',
      body: '从“失败学习”的角度写 1–3 条：\n- 情境变量（环境/人/时间/资源）\n- 行为变量（动作太大/太模糊/不连续）\n- 信念变量（我仍在坚持哪个旧解释？）\n\n并写一个下一轮的微调。',
    ),
    BeliefStep(
      id: 'summary',
      type: BeliefStepType.summary,
      title: '完成',
      body: '你完成了一次“段落→现实”的直观还原。下一步：把这次实验沉淀为你的行动模板（可复制、可迭代）。',
    ),
  ];
}
