/// EAM-8: experiential guidance derived from the user's "允许为人" example.
/// This is a writing contract for the existing single AI request, not an
/// additional planner, validator or paid model call.
class MeditationExperientialMethod {
  static const version = 'eam8_time_space_imagination_v1';

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

【认知、时间、空间、想象、身体与当下共同参与】
以下练习都要实际写入 segments.text，不能只出现在标题、practice_focus 或 experience_design。它们围绕用户的同一个主题交织展开，不是六段理论介绍，也不新增 phase。
认知：回应用户输入中的具体处境或念头，分清事实、解释与预测；邀请尝试一个有现实依据、更灵活或更友善的理解，再观察它与原来理解的不同。不预设用户想错了，不用“你一定能成功”等积极暗示代替探索。
时间：正常且用户愿意的练习中，明确包含昨天、前天、未来和现在。先以眼下触点为参照，再分别轻触昨天、前天一个与主题有关、普通且可承受的片刻；记不起就留白，不补造发生过的事，不追索被遗忘的记忆。提醒“这是此刻的回想，事情不在现在重演”，尝试用本次更合理的理解看待它；过去的事实不因想象而改变。随后设想明天或未来一个与同一主题有关的小片刻，只预演自己可选择的回应，不保证他人反应或事件结果。每次回想或预演后，先感受真实支撑或声音，再继续；不把未来设想当成预言。
空间：先感知自己此刻在什么位置、身体与支撑面的关系，再注意身边与稍远处的一处声音、物体或光线。想象中也要交代自己在哪里、物件的方位和距离，邀请将画面移远一点、缩小或选择舒服的观察位置；距离由用户决定，不宣称拉远就一定轻松。不只笼统说“给情绪一点空间”。
想象：在头脑中主动构建、停留和调整与主题有关的画面，让用户选择一个小动作或另一种回应；昨天与前天是记忆，未来是可能的情景，象征画面是比喻，三者说清楚。看不见清晰图像时，知道大概位置、用词语描述或听实际声音也可以。沿用同一主题和相近空间关系，避免连跳多个无关场景；不是旁听一段风景故事。
身体：在时间和画面探索之前、之后，分别邀请觉察一处真实触感、温度、重量或用力，再选择让手指、肩颈或下颌少用一点力，或调整姿势。提供身体放松的实际尝试，但自然呼吸、不强迫放松，也不预告身体一定变暖变轻；没有感觉或没有变化仍然有效。身体注意不适时改用外部感官。
当下：走神时，温和辨认“这是回忆／设想／一个念头”，再回到此时此地的呼吸、触点或声音，不责备自己。结束前明确离开回想与未来画面，重新感觉正在支撑自己的地方和周围的真实声音；非睡前可睁眼定向，睡前可保持闭眼、继续休息。

边界先于维度覆盖：用户不想回忆过去时省略过去片刻；不想预演未来时省略未来情景，睡前的未来片刻只轻触休息或被照顾的可能，不布置任务。用户不要想象或选择真实感官时，不要求构图、重演或进入未来情景，时间练习改为简短区分“过去已发生、未来未发生、现在的触感正在发生”，空间练习使用实际环境。medium 或高唤醒优先当下支撑，不回溯困扰或预演；立即危险依原有分流转向现实支持。不为覆盖维度越过这些边界。
时长：1–2分钟也保留认知、时间区分、近远空间、一个简短心中动作（适合时）、身体放松邀请与当下回返，可在同一主题的几句引导中合并；昨天、前天及未来各只轻触一句，不展开完整故事。较长练习分别留出回想、预演、身体观察后的安静，不增加无关情节。没有变化也可完成，完整理解和体验的预算包含朗读与停顿。
experience_design 可简记 time_exploration、space_exploration、imagery_participation、present_return；它们是可选摘要，不是新增拒收条件。输出前在本次请求内检查各维度是否真的进入正文，或是否因用户边界而作了适当替代，不额外调用模型评审或改写。
''';

  // Conservative recognition of direct refusals. Nuanced boundaries still
  // remain in the original input and take priority in the writing rules.
  static bool _declines(String input, String activity) {
    final refusals = RegExp(
      '(?:不想|不要|不愿意|不愿|不需要|不用|不做|避免|拒绝|别|不)'
      '(?:再|去|进行|做|用|使用|采用|让我|带我|要求我|引导我|任何|闭眼或|闭眼和){0,3}'
      '(?:$activity)',
    ).allMatches(input);
    return refusals.any(
      (match) => !RegExp(
        r'(不是|并非|没有|不会|不必|不用|不能|不想|不要|不愿|不需要|无法|不)$',
      ).hasMatch(input.substring(0, match.start)),
    );
  }

  static bool allowsImagery(String userInput) => !_declines(
        userInput,
        r'(?:想象|想像|构图)(?:练习|训练|画面)?(?:了|吧)?(?=$|[，,。；;！？!?、\s]|或闭眼|和闭眼)',
      );

  /// Adds transparent design guidance to the existing request without
  /// pre-deciding a diagnosis or executing an extra model call.
  static Map<String, dynamic> buildBrief({
    required String userInput,
    required int durationMinutes,
    required bool useImagery,
    required bool isSleep,
    bool prioritizeGrounding = false,
  }) {
    final theme = userInput.trim();
    final imagery = useImagery && !prioritizeGrounding && allowsImagery(theme);
    final past = !prioritizeGrounding && !_declines(theme, '回忆|回想|回顾|重温|回到过去');
    final future = !prioritizeGrounding &&
        !_declines(theme, '预演|展望|规划|想象未来|想象明天|设想未来|设想明天|想未来|想明天');
    final isHumanPermission = RegExp(
      r'允许.{0,3}(自己)?(为人|做人)|permission to be human',
      caseSensitive: false,
    ).hasMatch(theme);
    return <String, dynamic>{
      'method': 'EAM-8 / experiential acceptance and meaning exploration',
      'version': version,
      'theme_source': '仅以 primary_practice_input 为准，优先尊重明确的“不想/不要”',
      'dimension_priority': '用户边界与低刺激需要优先；以下计划只在允许范围内展开，六个维度的具体邀请写进播报正文',
      'practice_dimensions': <String, dynamic>{
        'cognition': '从本次原话提取一个核心区分，探索合理、灵活的理解，不灌输积极结果',
        'time': <String, dynamic>{
          'anchors': <String>[
            'present',
            if (past) ...['yesterday', 'day_before_yesterday'],
            if (future) 'future',
            'present',
          ],
          'past_mode': !past
              ? 'omit'
              : (imagery ? 'gentle_recollection' : 'time_orientation'),
          'future_mode': !future
              ? 'omit'
              : (imagery ? 'possible_scene' : 'time_orientation'),
          'guidance': prioritizeGrounding
              ? '只定向此刻与真实环境，不回溯或预演'
              : !imagery
                  ? '仅在 anchors 允许的范围内区分过去已发生、未来未发生与眼下真实触感，不构图、回放或预演'
                  : '仅探索 anchors 中允许的时间；过去不编造记忆、记不起可留白，未来不预测结果，每次探索后回到当下触点',
          'future_focus': !future
              ? '省略未来情景'
              : isSleep
                  ? '只轻触未来休息或被照顾的可能，不引出工作、任务或行动计划'
                  : '与本次主题有关的低强度片刻，只探索可选择的回应，不保证结果',
        },
        'space': imagery
            ? '实际身体位置与近远声音 → 同一主题画面的位置、方位、可调距离 → 实际支撑面'
            : '感知实际支撑、所在位置及近处与稍远处的声音或物体，不要求心中构图',
        'imagination': imagery
            ? '主动构建与主题相关的画面并选择一个小动作；可调整距离和视角，没有清晰图像也可以'
            : '不用想象；以实际触感、声音和位置体验同一认知区分',
        'body': '探索前后观察真实触感或用力，邀请手指、肩颈或下颌少用一点力或换姿势，不要求放松成功',
        'present_return': '辨认回忆、设想或走神，再回到此时此地；每次探索后回返，最后离开画面并定向真实环境',
      },
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
        '怎样用昨天、前天、未来与现在练习同一主题，而不编造经历或越过用户边界？',
        '怎样让位置、近远、可调整的画面和真实身体放松成为可跟随的动作？',
      ],
      'narration_rhythm':
          '邀请 → 适当静默 → 觉察真实反应 → 温和允许 → 呼吸回返；停顿标注到 pause_after_seconds 而非朗读文字',
      'duration_mode': durationMinutes <= 2
          ? '微练习：允许的维度合并在同一主题中，时间锚点各轻触一句；保留身体放松、近远觉察与回返，不展开多段故事'
          : '完整练习：在允许的时间锚点与场景模式内展开同一主题，为身体/情绪体验、空间探索及回返保留安静',
      'scene_mode':
          !imagery ? '只用眼前环境、声音、触感，不要求闭眼想象' : '可选温和日常画面；无法想象时以当前真实感官替代',
      'closing_mode': isSleep
          ? '结束回想和未来画面，感觉当前支撑与声音，可继续休息或入睡，不暗示现在必须行动'
          : '结束回想和未来画面，安静回到实际身体位置与周围，不强迫立刻行动',
      'topic_specific_focus': isHumanPermission
          ? '允许为人：优先直接体验各种情绪的自然存在及变化，暂不评判，不把它擅自缩减为没做完任务或完美主义；接纳感受≠认可所有行为'
          : '从用户主题重新设计独有体验；不得跨主题套用允许为人、完美主义或某一个固定场景',
    };
  }
}
