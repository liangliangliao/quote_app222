import 'belief_mentor_models.dart';

/// Versioned, review-aware seed content from the implementation specification.
/// Stories deliberately expose both an evidence grade and a boundary statement;
/// the product never flattens historical examples and experiments into the same
/// claim of "scientific proof".
class BeliefMentorStoryCatalog {
  const BeliefMentorStoryCatalog._();

  static const String version = 'belief-mentor-story-v1.0';

  static const List<BeliefMentorStory> all = <BeliefMentorStory>[
    BeliefMentorStory(
      id: 'ST-001',
      title: 'Roger Bannister：把“不可能”改成可测试',
      targetType: BeliefMentorBeliefType.reality,
      hook: '“过去没人做到”真的等于“你不可能做到”吗？',
      story: '四分钟一英里曾被很多人视为极难跨越的界线。Bannister 在 1954 年跑进四分钟后，其他运动员也陆续做到。这个故事适合打开可能性，但真正改变成绩的仍是训练、条件、策略和时间。',
      mechanism: '可能性信念会改变投入、训练、坚持与试错，而不是直接改写物理现实。',
      boundary: '一个历史突破不能证明任何人、任何目标都能实现，也不能替代能力与条件评估。',
      reflection: '你目前把哪个“尚未发生”误写成了“绝不可能”？可以用什么低风险动作验证？',
      experiment: '在 24 小时内找到一个可靠反例，并完成一次 10 分钟的可能性测试。',
      evidenceGrade: '历史案例',
      sourceLabel: 'Harvard Positive Psychology Lecture 6｜Bannister 历史资料待上线二审',
      reviewStatus: '课程核对；原始史料待二审',
    ),
    BeliefMentorStory(
      id: 'ST-002',
      title: 'Pygmalion / Rosenthal：期待如何进入互动',
      targetType: BeliefMentorBeliefType.relationship,
      hook: '期待不是读心术，但它会不会改变你给予别人什么机会？',
      story: '课堂用 Pygmalion 研究说明：教师对学生的期待可能通过注意、反馈、挑战与耐心进入互动，进而影响表现。关键机制不是“想法远程创造结果”，而是期待改变了行为环境。',
      mechanism: '期待 → 互动方式 → 练习与反馈机会 → 表现差异。',
      boundary: '经典研究的设计、效应大小与可重复性需要结合后续证据审查，不能概括为期待决定一切。',
      reflection: '你对自己或某个人的低期待，具体改变了哪一种互动行为？',
      experiment: '选择一次互动，增加一个具体机会：多问一个问题、给一次清晰反馈或延长一次耐心等待。',
      evidenceGrade: '实验研究（需二审）',
      sourceLabel:
          'Harvard Positive Psychology Lecture 6｜Rosenthal/Jacobson 及后续证据待二审',
      reviewStatus: '课程核对；后续证据待核对',
    ),
    BeliefMentorStory(
      id: 'ST-003',
      title: 'Marva Collins：看见潜力，但不取消要求',
      targetType: BeliefMentorBeliefType.capability,
      hook: '真正的高期待，是夸奖，还是更认真地教、练和反馈？',
      story: '课程以教育者 Marva Collins 的故事说明：把学生视为有发展潜力，不等于降低标准或只说鼓励话，而是给予尊重、清晰要求、练习与持续反馈。',
      mechanism: '“你可以发展”的关系信号，与结构化练习和高质量反馈共同作用。',
      boundary: '个人教育故事不是随机实验，也不能证明同一方法在所有学生和环境中产生相同结果。',
      reflection: '如果你把自己当作“可训练的人”，今天会增加哪一项练习，而不是增加哪一句口号？',
      experiment: '为一个能力安排 15 分钟刻意练习，并只记录过程证据。',
      evidenceGrade: '教育案例',
      sourceLabel:
          'Harvard Positive Psychology Lecture 6｜Marva Collins 传记资料待二审',
      reviewStatus: '课程核对；传记来源待核对',
    ),
    BeliefMentorStory(
      id: 'ST-004',
      title: 'Tal 与 Rena：相信不等于保证结果',
      targetType: BeliefMentorBeliefType.relationship,
      hook: '如果你真诚相信一段关系会成功，它就一定会成功吗？',
      story: '课程用个人关系反例提醒：信念能改变自己的投入和表达，却不能控制另一个人的选择。成熟的信念同时承认希望、边界与不可控因素。',
      mechanism: '信念影响自己的行动；结果仍由多个人、条件与偶然因素共同决定。',
      boundary: '这是个人故事，不是可推广的因果研究，也不应用来解释所有关系结果。',
      reflection: '你的目标中，哪些部分属于你，哪些部分属于别人或现实条件？',
      experiment: '写下“我能控制 / 我能影响 / 我不能控制”三栏，并只承诺第一栏中的一个动作。',
      evidenceGrade: '个人反例',
      sourceLabel: 'Harvard Positive Psychology Lecture 6｜课程个人故事',
      reviewStatus: '课程核对',
    ),
    BeliefMentorStory(
      id: 'ST-005',
      title: 'Stockdale：希望、事实与能动性',
      targetType: BeliefMentorBeliefType.failure,
      hook: '怎样既不放弃最终希望，也不欺骗自己当前很难？',
      story: 'Stockdale 悖论强调两件事同时成立：保留最终能够走出去的信念，同时直面当下最残酷的事实。它反对用乐观日期或口号逃避现实。',
      mechanism: '希望维持方向，事实校准策略，能动性把注意力放到下一项可控行动。',
      boundary: '战俘经历是极端历史情境，不能简单类比所有日常困难，也不能保证坚持必然成功。',
      reflection: '关于当前问题，哪一个事实最不舒服却必须承认？你仍能控制哪一步？',
      experiment: '完成 Faith / Facts / Agency 三栏，并在 24 小时内执行一个 Agency 动作。',
      evidenceGrade: '历史案例 / 管理概念',
      sourceLabel: 'Harvard Positive Psychology Lecture 6｜James Stockdale / Jim Collins 相关资料待二审',
      reviewStatus: '课程核对；历史来源待核对',
    ),
    BeliefMentorStory(
      id: 'ST-006',
      title: '144 分钟害羞实验：身份可以拆成行为',
      targetType: BeliefMentorBeliefType.identity,
      hook: '“我就是害羞的人”，是否掩盖了许多可以单独练习的行为？',
      story:
          '课程介绍以持续行为练习改变自我知觉的研究思路：不是等待先变自信，而是在可承受的范围内多做接近、表达与互动，再让真实经验更新自我描述。',
      mechanism: '具体行为经验 → 自我知觉与效能信息 → 更愿意再次行动。',
      boundary: '课程中的实验细节与效应需要回到原始论文二审；练习不等于治疗社交焦虑障碍。',
      reflection: '把“我就是……”改写成一个可观察、可分级的行为，会是什么？',
      experiment: '完成一次 2–5 分钟微勇气行为，并记录行动前后的情绪，而非要求情绪先消失。',
      evidenceGrade: '实验研究（需二审）',
      sourceLabel: 'Harvard Positive Psychology Lecture 6｜原始实验出处待二审',
      reviewStatus: '课程核对；原始论文待核对',
    ),
    BeliefMentorStory(
      id: 'ST-007',
      title: 'Dweck：反馈努力，也反馈策略',
      targetType: BeliefMentorBeliefType.capability,
      hook: '“你很聪明”和“这个策略有效”会把注意力带向哪里？',
      story: '成长心态研究关注人如何理解能力、努力与失败。产品不把它缩成“只要努力就行”，而是鼓励把能力当作可发展对象，并对策略、练习质量、求助和调整给出具体反馈。',
      mechanism: '可发展解释降低身份防御，使人更可能尝试、求助、换策略并从错误中学习。',
      boundary: '成长心态不是万能干预，效应依情境而异；资源、教学质量与真实约束仍然重要。',
      reflection: '这次卡住，缺的是投入、策略、反馈、技能，还是外部条件？',
      experiment: '选择其中一个可变因素，进行一次 20 分钟策略迭代并记录差异。',
      evidenceGrade: '研究体系（需持续审查）',
      sourceLabel: 'Harvard Positive Psychology Lecture 6｜Dweck 研究与后续元分析待二审',
      reviewStatus: '课程核对；后续证据待核对',
    ),
    BeliefMentorStory(
      id: 'ST-008',
      title: '完美主义：把失败从身份判决改成信息',
      targetType: BeliefMentorBeliefType.failure,
      hook: '一次结果不好，说明“方法需调整”，还是说明“整个人不行”？',
      story: '课程区分健康追求与拒绝失败的完美主义。前者允许现实反馈进入系统；后者把失误变成身份威胁，于是更容易回避、拖延或掩盖问题。',
      mechanism: '事实与身份分离，能保留反馈价值并缩短再次行动的距离。',
      boundary: '失败重构不能否认真实损失、责任或能力差距，也不能替代需要的专业支持。',
      reflection: '这次失败提供了哪条关于方法、技能或条件的信息，而不是关于人格的判决？',
      experiment: '写下一个事实、一个旧解释、一个更窄的新解释，以及下一次 20% 难度动作。',
      evidenceGrade: '课程理论 / 研究集合',
      sourceLabel: 'Harvard Positive Psychology Lectures 7–9｜完美主义相关研究待二审',
      reviewStatus: '课程核对；研究集合待核对',
    ),
  ];

  static BeliefMentorStory forType(
    BeliefMentorBeliefType type, {
    Set<String> seen = const <String>{},
  }) {
    final matching = all.where((story) => story.targetType == type).toList();
    final unseen = matching.where((story) => !seen.contains(story.id)).toList();
    if (unseen.isNotEmpty) return unseen.first;
    if (matching.isNotEmpty) return matching.first;
    return all.first;
  }
}
