/// One writing contract and a duration-aware itinerary for the existing call.
/// The local review checks visible invitations, never therapeutic effectiveness.
class MeditationNarrationGuide {
  static const version = 'multidimensional_narration_v2';

  static const systemPrompt = '''
【EAM-8 多维体验导师】
你是一名用中文现场带领一个人练习的冥想导师。以用户主题为中心，在本次生成中完成主题理解与正文写作。用户明确的愿望、边界和否定表达优先。按结构化输入中的 narration_blueprint 分配体验时间；每个环节的要求必须变成听者可以跟随的 segments.text。

【整篇体验】
基础冥想、用户主题的认知练习、时间旅行、空间探索、主动想象、身体感受与放松同等重要，互相连接。正常画面模式中，昨天、前天和未来都有具体过程，占据核心体验的主要篇幅；不要把它们压在结尾一句带过。用“邀请一个动作 → 停留 → 观察 → 尝试另一种理解或回应 → 回到真实触点”的节奏带领。可以进入几个不同时刻、不同地点的情景，它们由用户的同一个主题连接，不必始终停在同一张桌子或一个象征物上。不同阶段之间自然过渡，不朗读阶段名和清单。

认知：主题是什么 → 为什么重要或让人卡住 → 可以怎样尝试。准确回应用户原话中的具体想法、情绪或愿望，区分事实、解释与预测，提出一个贴近现实的积极或灵活的新理解。随后在过去与未来情景中亲自试用，比较它与原来回应的不同；不要只解释概念或反复劝接纳。“允许为人”先让情绪自然存在、不评判，包含喜悦、焦虑、无聊或没有情绪，不能擅自改成完美主义、没完成任务或必须变积极。其他主题重新设计，不套此主题。
时间：分别带用户回想昨天、前天与主题有关的一个可承受片刻，再想象明天或未来的可能情景。每个完整片刻都包含进入地点、感官线索、用户参与、与主题有关的认知尝试、身体观察和回返。昨天可以观察原有回应，前天可以寻找不同反应或曾有支持的片刻，未来亲自排练新回应。让用户自己选择记忆；记不起可用明确标为假设的普通情景或跳过，不替用户编造经历，不追索遗忘记忆。提醒回忆发生在此刻，过去的事实没有改写，未来也不是预测。
空间：先感觉此刻身体在哪里、与支撑面怎样接触，主动觉察近处和稍远处。进入情景时带出所在位置、前后左右、物件距离与一两处感官细节；邀请改变观察位置、把画面移远或拉近、缩小或放大，再观察心理与身体反应。空间练习包含位置与视角的实际操作，不只说“给自己空间”。
想象：让用户在头脑中进入情景并亲自做一件事，例如转身、伸手、移动物件、说一句回应，或试用第二种选择；留下体验时间。不只说“想象美好的未来”。清晰图像不是必需，知道大概位置或用词语体验也可以。记忆、假设情景、象征比喻说清楚。
身体：开场、每次情景后和结尾都接回真实身体。邀请注意接触、重量、温度、呼吸或用力，再从下颌、肩颈、手指等两处逐一尝试少用一点力，感受前后区别；短练习可只选一处。呼吸舒适自然，不强制深吸、屏息、绷紧或放松成功。没有感觉、没有变化也可以；走神时温柔带回，不责备。
收束：离开过去和未来的画面，感受当下支撑、真实声音和所在位置；留白后再用一至两个开放问题整合主题，不代答。非睡前可按自己的节奏睁眼、活动；睡前可继续休息。

【足够具体的带领示例，仅学习展开密度，不跨主题复制】
“回想昨天一个你愿意接近的普通片刻。知道自己当时在哪里，面前有什么，声音从哪边传来。”[停留]
“在心里站到那个位置，留意当时的情绪。试着把‘不该有这种感受’换成‘感受可以在这里，我仍能选择回应’，再停一会儿。”[停留]
“可以把画面移远一点，看见事件之外的空间。随后让画面离开，感觉现在的手掌，看看是否还想抓紧；愿意的话少用一点力。”[停留]
未来情景还要让用户亲自排练主题对应的新回应，不能只问“明天会怎样”。每个片刻重新编写自己的细节，不能把范文的情绪或经历强加给用户。

【边界与节奏】
使用 blueprint 中允许的环节。用户拒绝回忆或未来情景，省略对应环节；选择真实感官或不要想象时，用时间区分、实际位置和触感替代构图，不要求回放或预演。medium 或高唤醒以当前支撑和外部感官为主，不回溯或预演。睡前未来情景聚焦休息，不布置工作任务。明确立即危险先转向现实支持。不诊断、不宣布用户已经安全/平静，不保证结果；不需要每段重复免责声明。调整与退出选择在开场说明，必要时再提醒，核心篇幅用于实际带领。
1–2分钟合并环节，时间、空间和想象也有具体小邀请；3分钟起按分配充分展开。每段一到三句、一个主要动作，提问后先等待。pause_after_seconds 是说完后的安静时间，不朗读；短练习1–4秒，长练习通常6–20秒，按任务变化。

【输出】
只输出合法 JSON。先写 segments，再写简短摘要；总朗读与留白服从 duration_budget。每段写 text、phase、pause_after_seconds，可写 unit 对应 blueprint.id；start_seconds 和 intent 可省略，由本地安排。phase 可用 arrival、breath、body_emotion、allow_experience、embodied_shift、real_life_rehearsal、integration、closing，可复现。
辅助字段使用 title、type、duration_minutes、understood_need、cognitive_shift、embodied_goal、real_life_scene、practice_focus、ending_reflection，合计尽量不超过120个中文字。experience_design 可选、简短；无需输出 depth_evidence 或评分。不能用辅助摘要替代正文。在输出前对照行程，补足真正缺少的参与动作和体验留白。仍是一次生成，不得额外触发模型请求或阻断可播放正文。
''';

  static const defaultPrompt =
      '''请直接带我完成本次冥想。以我的主题为主线，按结构化输入中的 narration_blueprint 展开认知、昨天、前天、未来、空间、想象、身体放松与当下回返。每个允许的核心片刻需要进入、参与、尝试与观察，不要只有一句“想象一下”。
主题：{{user_description}}
当前状态：{{current_state}}
时长：{{duration_minutes}}分钟
风格：{{guidance_style}}；锚点：{{anchor_preference}}
参考正文篇幅：{{target_character_range}}个中文字；约{{target_segment_count}}个短段。实际体验和留白优先。
偏好与安全边界、历史调整见结构化输入。认知理解写入正文，随时间与空间练习反复试用。
输出 JSON，例如：
{"segments":[{"unit":"arrival","phase":"arrival","text":"可直接跟随的具体邀请","pause_after_seconds":8}],"title":"标题","type":"类型","duration_minutes":{{duration_minutes}},"understood_need":"主题理解","cognitive_shift":"新理解","embodied_goal":"身体体验邀请","real_life_scene":"情景摘要","practice_focus":["练习重点"],"ending_reflection":"收束"}
''';

  static List<Map<String, dynamic>> buildBlueprint({
    required int minutes,
    required bool imagery,
    required bool past,
    required bool future,
    required bool isSleep,
  }) {
    final compact = minutes <= 2;
    final units = <Map<String, dynamic>>[];
    void add(String id, String phase, int weight, String invitation,
        {bool episode = false}) {
      units.add({
        'id': id,
        'phase': phase,
        'weight': weight,
        'episode': episode,
        'invitation': invitation,
      });
    }

    add('arrival', 'arrival', 10, '安顿姿势与自然呼吸，感受身体接触支撑，给出锚点和选择。');
    add('cognition', 'allow_experience', 10,
        '把用户原话转成一个值得亲身尝试的认知区分，回应真实需要，用简短口语讲清并邀请试用。');
    add(
        'space',
        'embodied_shift',
        10,
        imagery
            ? '感受当前身体的位置，听近处与远处；建立一个与主题有关的心中位置，调整远近或观察视角，再观察身体。'
            : '以真实支撑、所在位置、近处和远处声音进行空间觉察，不要求心中构图。');
    if (past) {
      add(
          'yesterday',
          'real_life_rehearsal',
          17,
          imagery
              ? '昨天：邀请自选与主题有关的普通片刻 → 所在位置与两处感官细节 → 留意原有念头/情绪 → 亲自试用新的理解或回应 → 停留观察真实身体；不能一句回想后立即跳走。'
              : '区分昨天的事情与现在对它的想法，感受眼下触点，不要求回放记忆。',
          episode: true);
      if (!compact)
        add('return_yesterday', 'body_emotion', 3,
            '离开昨天的画面，感觉真实支撑，观察一处身体与情绪反应。');
      add(
          'day_before_yesterday',
          'real_life_rehearsal',
          13,
          imagery
              ? '前天：自选另一个与主题有关的片刻，可有不同情绪或曾有支持 → 地点与位置 → 以新视角参与，寻找对原先笼统判断的另一条现实信息 → 留白与身体观察。'
              : '区分前天、昨天与此刻，留意现在的触感和声音，不回放过去。',
          episode: true);
      if (!compact)
        add('return_day_before', 'body_emotion', 3, '从前天回到真实身体，感受一处触点或当前声音。');
    }
    if (future) {
      add(
          'future',
          'real_life_rehearsal',
          20,
          !imagery
              ? '区分未来尚未发生与眼下正在发生的触感，不要求预演。'
              : isSleep
                  ? '未来一个休息或被照顾的可能片刻：构建地点、位置和感觉，亲自尝试与主题相符的新回应，再回到当前支撑；不列任务或工作安排。'
                  : '明天或未来：构建与主题相关的可能场景 → 看见位置、方位与距离 → 在心中亲自做一个动作或说一句新回应 → 保留不顺利的可能并选择如何照顾自己 → 观察身体，再离开画面。',
          episode: true);
    }
    add('body_release', 'embodied_shift', 9,
        '离开情景，逐一感觉真实下颌、肩颈或手指；选择少用一点力，观察前后区别，不预设放松。短时长选一处。');
    if (!compact)
      add('integration', 'integration', 3,
          '在体验之后，用一个与用户主题有关的问题连接新理解和真实感受；留白，不代答。');
    add(
        'closing',
        'closing',
        5,
        isSleep
            ? '离开所有画面，感觉此刻的身体位置与真实声音，允许继续闭眼休息。'
            : '离开所有画面，重新确认此时此地、身体支撑和周围，按自己节奏活动或睁眼。');

    final totalWeight = units.fold<int>(0, (n, u) => n + (u['weight'] as int));
    final totalSeconds = minutes * 60;
    var allocated = 0;
    return List.generate(units.length, (i) {
      final unit = Map<String, dynamic>.from(units[i]);
      final seconds = i == units.length - 1
          ? totalSeconds - allocated
          : totalSeconds * (unit['weight'] as int) ~/ totalWeight;
      allocated += seconds;
      final expandedEpisode = !compact && imagery && unit['episode'] == true;
      unit.remove('weight');
      unit.remove('episode');
      unit['budget_seconds_including_silence'] = seconds;
      unit['suggested_segments'] = compact
          ? 1
          : expandedEpisode
              ? (minutes >= 5 ? 3 : 2)
              : (seconds ~/ 22).clamp(1, 6);
      if (compact)
        unit['compact_instruction'] = '只保留一个具体小邀请，可与相邻环节合并，核心片刻后接回真实触点。';
      return unit;
    });
  }

  /// Editorial hints from narration only. No scores or rejection of prose.
  static List<String> missingInvitations(Map<String, dynamic> script,
      {required Map<String, dynamic> brief, required int minutes}) {
    final raw = script['segments'];
    final texts = raw is List
        ? raw.whereType<Map>().map((s) => '${s['text'] ?? ''}').toList()
        : <String>[];
    final text = texts.join('');
    final missing = <String>[];
    final dimensions = brief['practice_dimensions'] as Map;
    final time = dimensions['time'] as Map;
    final imagery = brief['uses_imagery'] == true;
    bool has(String pattern, [String? value]) =>
        RegExp(pattern).hasMatch(value ?? text);
    if (!has(
        r'不等于|未必|不必.{0,12}(评判|评价|责备|消失|赶走)|区分|区别|换.{0,6}(理解|回应)|不.{0,5}定义|可以.{0,8}(存在|选择|留下)|不.{0,6}判.{0,4}(好坏|错误)')) {
      missing.add('与主题有关的新理解或认知尝试');
    }
    bool episode(String anchor) {
      for (var i = 0; i < texts.length; i++) {
        if (!RegExp(anchor).hasMatch(texts[i])) continue;
        final span = texts.skip(i).take(minutes <= 2 ? 1 : 3).join('');
        if (!has(r'回想|回忆|想起|设想|想象|心里|心中|轻触', texts[i])) continue;
        if (minutes <= 2) return has(r'感受|感觉|留意|观察|尝试|选择|位置|声音|触', span);
        if (span.length >= 70 &&
            has(r'位置|地点|哪里|面前|身边|声音|光|距离|触|看见', span) &&
            has(r'试着|尝试|选择|回应|移动|伸手|放下|转身|放在|停.{0,3}下|少.{0,6}用力|留意|观察', span))
          return true;
      }
      return false;
    }

    if (imagery) {
      if (time['past_mode'] != 'omit') {
        if (!episode('昨天')) missing.add('昨天片刻的进入、参与与观察');
        if (!episode('前天')) missing.add('前天片刻的进入、参与与观察');
      }
      if (time['future_mode'] != 'omit' && !episode('明天|未来|稍后')) {
        missing.add('未来情景中的具体回应预演');
      }
      if (!has(r'想象|设想|心中|心里') ||
          !has(r'移远|拉近|缩小|放大|移动|伸手|转身|换.{0,4}(位置|视角)|放在|排练|试.{0,8}回应')) {
        missing.add('主动调整画面或参与情景');
      }
    }
    if (!has(r'近处|身边|附近|眼前') ||
        !has(r'远处|稍远|远一点|近远|远近') ||
        !has(r'听|看|觉察|感受|感觉')) missing.add('近远与位置的空间觉察');
    if (!has(r'下颌|肩|颈|手指|手掌|脚|身体') ||
        !has(r'少.{0,8}(力|抓紧)|松.{0,6}(一点|开)|放松|调整姿势|换.{0,2}姿势')) {
      missing.add('真实身体感受与放松尝试');
    }
    final ending = texts.skip(texts.length > 3 ? texts.length - 3 : 0).join('');
    if (!has(r'回到|现在|此刻|当下|此时此地|离开|结束', ending) ||
        !has(r'声音|支撑|触|脚|手掌|身体|呼吸|周围', ending)) {
      missing.add('结束画面并回到当下');
    }
    return missing;
  }
}
