import 'meditation_narration_guide.dart';

/// EAM-8: experiential guidance derived from the user's "允许为人" example.
/// This is a writing contract for the existing single AI request, not an
/// additional planner, validator or paid model call.
class MeditationExperientialMethod {
  static const version = MeditationNarrationGuide.version;

  static const String systemRules = MeditationNarrationGuide.systemPrompt;

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
      'uses_imagery': imagery,
      'narration_blueprint': MeditationNarrationGuide.buildBlueprint(
        minutes: durationMinutes,
        imagery: imagery,
        past: past,
        future: future,
        isSleep: isSleep,
      ),
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
