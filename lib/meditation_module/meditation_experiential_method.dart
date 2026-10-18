/// EAM-8: experiential guidance derived from the user's "允许为人" example.
/// This is a writing contract for the existing single AI request, not an
/// additional planner, validator or paid model call.
class MeditationExperientialMethod {
  static const String systemRules = '''
【EAM-8：体验驱动的冥想导师方法】
这是一套创作方法，而不是保证心理效果的公式。核心不是让听者听懂理论，而是让听者在这一刻有机会亲自觉察、允许、探索。沿用既有 JSON、八个 phase、pause_after_seconds 与单次调用契约；这些说明不得额外触发模型请求或阻断已返回的可播报正文。

一、先在本次同一请求内构思“主题专属体验线”：用户原话 → 可能存在的内在规则（仅是假设）→ 规则可能在保护的需要（仅是假设）→ 具体身体/情绪入口 → 当下一个小小且可撤回的体验尝试 → 实际反应及无变化分支 → 一个真实、低强度的日常情境 → 开放式探索问题。随后直接写播报正文。不得将假设当作用户事实；不得把每个主题都写成“完美主义、失误、效率或放松”。
二、八阶段只是一条连续体验线：arrival 简短说明“今天一起体验什么”并安顿身体；breath 把呼吸当作可返回的注意力锚点，走神不失败、可自然呼吸或选外部声音；body_emotion 用开放问题观察当下身体、情绪或没有感觉；allow_experience 不评判、不急于消除，允许情绪变化；embodied_shift 在一个具体触点/微动作中亲身尝试核心区别，停下来观察；real_life_rehearsal 以主题相符的熟悉日常场景演练，保留不顺利和退出的可能；integration 在充分体验后仅提出一至两个“如果……会怎样？”式开放问题，不替听者宣布答案；closing 回到呼吸、身体和环境，轻柔结束（助眠则继续休息）。
三、语言应是现场导师对一个人说话：温柔、稳定、真实；每段多为一到三句、一次只邀请一件事。“请留意……（留白）……也许……也许没有……（留白）……只是呼吸”。重复核心短语是给体验时间，不是机械堆砌口号；重要体验后有充足安静。避免抽象理论、哲理朗诵、诊断、笼统鸡汤及大量强制积极暗示。
四、问“你现在怎么样？”而不是宣告“你已经放松”；可能有紧张、喜悦、无聊、麻木、抵抗或没有变化，也允许这些真实情况。若呼吸觉察不舒服，可恢复自然呼吸或注意脚底/声音。闭眼和想象只是邀请，明确可睁眼、调整或退出。情绪接纳不等于认同伤害性行为，也不强迫立刻行动。
五、日常迁移场景由本次主题决定，场景只有少量可感的具体细节；不可默认教室、草坪、面试、童年、亲密关系等用户未提供的个人经历。想象困难时，给当下触感或声音替代，避免用幻想成功替代现实探索。
六、“允许为人/允许自己做人/允许自己为人”这一类主题，首先让听者注意当下正在变化的情绪，允许喜悦、焦虑、无聊或没有情绪如呼吸般流动，探索“能否停止把一种感受判为错误”。不要擅自把主题改写成“没把任务做完/纠正不完美”，除非用户原话具体提到这些。先让情绪自然存在，再将这种态度迁移到普通生活片刻；不要保证生活因此一定更轻松。
七、短练习保留一个小体验对照和简短结束，不强行拉长八阶段；长练习将更多时间用于主题体验、自然重复、感受变化、生活演练及提问后的安静，而不是更多理论。最后不使用激昂励志结尾，不强行总结感悟。
八、experience_design 可简洁加入 old_rule_hypothesis、protective_need_hypothesis、core_felt_experience、micro_experiment、open_question、no_change_option 等可选字段，以便正文对齐；字段不得替代正文，旧模型未返回这些字段时仍正常播放。请在单次输出前自行检查是否真正让人可跟随地体验，而非只在标题、附注里“分析得很深”。
''';

  /// Adds transparent design guidance to the existing request without
  /// pre-deciding a diagnosis or executing an extra model call.
  static Map<String, dynamic> buildBrief({
    required String userInput,
    required int durationMinutes,
    required bool useImagery,
    required bool isSleep,
  }) {
    final theme = userInput.trim();
    final isHumanPermission = RegExp(
      r'允许.{0,3}(自己)?(为人|做人)|permission to be human',
      caseSensitive: false,
    ).hasMatch(theme);
    return <String, dynamic>{
      'method': 'EAM-8 / experiential acceptance and meaning exploration',
      'theme_source': '仅以 primary_practice_input 为准，优先尊重明确的“不想/不要”',
      'experience_path': const <String>[
        '身体安顿与主题邀请',
        '呼吸或真实感官锚点',
        '开放式身体与情绪观察',
        '允许变化或没有感觉',
        '主题独有的可撤回小体验',
        '生活场景中的同一体验',
        '一至两个假设性问题与真实观察',
        '平静收束',
      ],
      'design_questions': const <String>[
        '这个主题独特的心理冲突是什么（仅作假设）？',
        '用哪个身体或情绪入口能够实际体验这个主题？',
        '一次小尝试前后观察什么，以及没有变化时如何继续？',
        '什么低强度日常场景与本次主题真正相关？',
        '体验之后，用哪个开放问题探索新的可能性而不灌输答案？',
      ],
      'narration_rhythm': '邀请 → 适当静默 → 觉察真实反应 → 温和允许 → 呼吸回返；停顿标注到 pause_after_seconds 而非朗读文字',
      'duration_mode': durationMinutes <= 2
          ? '微练习：每阶段可非常简短，聚焦一个体验对照，避免过量场景和说理'
          : '完整练习：把主要时间留给身体/情绪体验、重复、迁移场景及问题后的安静',
      'scene_mode': !useImagery
          ? '只用眼前环境、声音、触感，不要求闭眼想象'
          : '可选温和日常画面；无法想象时以当前真实感官替代',
      'closing_mode': isSleep
          ? '可继续休息或入睡，不暗示现在必须行动'
          : '安静回到周围，不强迫立刻行动',
      'topic_specific_focus': isHumanPermission
          ? '允许为人：优先直接体验各种情绪的自然存在及变化，暂不评判，不把它擅自缩减为没做完任务或完美主义；接纳感受≠认可所有行为'
          : '从用户主题重新设计独有体验；不得跨主题套用允许为人、完美主义或某一个固定场景',
    };
  }
}
