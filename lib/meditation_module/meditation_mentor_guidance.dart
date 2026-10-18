import 'dart:math' as math;

import 'meditation_models.dart';

/// Writing and local playback guidance; it never calls a provider.
class MeditationMentorGuidance {
  static const rules = '''
【以用户主题为中心的生成与播放约定】
用户原话决定主题；推荐、默认状态与历史只调节方法和节奏，不能替换成通用减压、效率训练或睡眠。输入很短也足够。引导风格、锚点和想象偏好贯穿整篇，不只写在开头。感官细节与场景中的关系服务主题，可用温和象征与想象空间；围绕一个主画面展开，参与之后接回真实身体与情绪。

experience_design 简要写 input_anchor（摘自用户原话，或没有补充时的当前状态）、theme、conceptual_understanding、imagery_bridge、sensory_cues、body_invitation、emotional_permission、felt_check。它只是内容摘要；正文才真正讲清含义、机制、方法，并带领体验。understood_need 和 cognitive_shift 概括本次理解与关键区分，不宣告用户已改变。象征画面要明确是可选想象，不能伪装成用户经历。无需长篇设计、评分、证据引用或第二次模型请求。

每段通常一到三句，只承担一个主要邀请。先邀请，留白后再观察；问题和代答不能挤在同一段。pause_after_seconds 是说完后的安静体验秒数，不放进 text。1–2 分钟可用 1–4 秒；较长练习通常 6–20 秒，提问、身体和情绪觉察后比过渡句多留一点时间，不能每句机械停同样久。

总时长包含朗读和留白。参考提供的字数、段数与 duration_budget 分配，短练习可合并环节，不凑八段；较长练习把时间交给同一主题的理解、画面参与、身心觉察与整合，不用旁支分析或无意义重复填满。start_seconds 从 0 递增，并留出结尾停顿。保留必要的认知解释与体验衔接，优先精简重复说明。辅助字段、阶段和写作建议不构成返回内容的拒收条件。
''';

  static int speechSeconds(String text) {
    final chinese = RegExp(r'[\u3400-\u9fff]').allMatches(text).length;
    final words = RegExp(r'[A-Za-z0-9]+').allMatches(text).length;
    final punctuation = RegExp(r'[，。！？；,.!?;]').allMatches(text).length;
    return math.max(
        1, (chinese / 3.2 + words / 2.2 + punctuation * .18).ceil());
  }

  static List<String> qualityIssues(
    Map<String, dynamic> map, {
    required String userInput,
    required int durationSeconds,
    required bool useImagery,
    int? plannedDurationSeconds,
  }) {
    final issues = <String>[];
    final design = map['experience_design'];
    if (design is! Map) return ['缺少 experience_design，需先把用户主题转成感官、身体和情绪体验'];
    for (final key in [
      'input_anchor',
      'theme',
      'body_invitation',
      'emotional_permission',
      'felt_check'
    ]) {
      if (design[key] is! String || (design[key] as String).trim().isEmpty) {
        issues.add('experience_design 缺少 $key');
      }
    }
    final anchor = '${design['input_anchor'] ?? ''}'.trim();
    final input = userInput.trim();
    if (anchor.isEmpty ||
        !input.contains(anchor) ||
        anchor.length < math.min(2, input.length) ||
        anchor.length > 40) {
      issues.add('input_anchor 必须摘自本次输入，不能使用默认推荐或编造用户经历');
    }
    final cues = design['sensory_cues'];
    if (cues is! List ||
        cues
                .whereType<String>()
                .where((s) => s.trim().isNotEmpty)
                .toSet()
                .length <
            2) {
      issues.add('至少设计两个具体感官线索，将主题转成可感的画面或真实环境体验');
    }
    final rawSegments = map['segments'];
    final segments = (rawSegments is List ? rawSegments : const [])
        .whereType<Map>()
        .toList();
    final texts = segments.map((s) => '${s['text'] ?? ''}').toList();
    final joined = texts.join('').replaceAll(RegExp(r'\s+'), ' ');
    final core = segments.where((s) => [
          'allow_experience',
          'embodied_shift',
          'real_life_rehearsal'
        ].contains(s['phase']));
    final coreText = core.map((s) => '${s['text'] ?? ''}').join();
    if (anchor.isNotEmpty &&
        !_echoesTheme(coreText, anchor, '${design['theme'] ?? ''}')) {
      issues.add('核心体验正文未呼应本次主题，不能只在分析字段或标题里写主题');
    }
    final shifted = segments
        .where((s) => s['phase'] == 'embodied_shift')
        .map((s) => '${s['text'] ?? ''}')
        .join();
    // A concrete scene or object is an imagery entry too. Do not require the
    // narrator to literally say "imagine", nor reject "no need to imagine".
    if (!useImagery && _activeImagery(coreText)) {
      issues.add('本次选择真实感官或需要低刺激引导，不应引导进入想象场景');
    }
    final lecture = RegExp(r'意味着|这说明|本质上|我们要明白|从认知|接纳的含义|你要理解|正确认知|在认知层面');
    if (texts.where((text) => lecture.hasMatch(text)).length >
        math.max(1, texts.length ~/ 4)) {
      issues.add('正文仍以概念解释为主，请改成可跟随的邀请、留白和实际觉察');
    }
    final senseFamilies = [
      r'光|颜色|明暗|轮廓|看|视线',
      r'声音|听|安静|声响',
      r'触|温度|温暖|凉|手掌|脚底|座面|重量|支撑'
    ];
    final experienceText = segments
        .where((s) => ['body_emotion', 'allow_experience', 'embodied_shift']
            .contains(s['phase']))
        .map((s) => '${s['text'] ?? ''}')
        .join();
    if (senseFamilies
            .where((pattern) => RegExp(pattern).hasMatch(experienceText))
            .length <
        2) {
      issues.add('核心体验正文至少要有两种感官入口，不能只在设计字段里列出');
    }
    if (!RegExp(r'留意|注意|觉察|观察|感受|有没有|是否|怎样').hasMatch(shifted) ||
        !RegExp(r'身体|手掌|肩|胸口|脚底|腹|接触|支撑|触感').hasMatch(shifted)) {
      issues.add('画面或感官邀请后，需要回到身体并观察实际反应');
    }
    if (!RegExp(
            r'没有.{0,10}(感觉|变化|画面)|没.{0,8}(感觉|变化)|不.{0,8}(明显|变化)|保持原样|看不见|想象不出')
        .hasMatch(joined)) {
      issues.add('明确允许没有画面、没有感觉或没有变化，并给真实感官替代入口');
    }
    final resultClaims = RegExp(
        r'你(?:现在|已经|会|一定).{0,8}(放松了|平静了|安全了|释怀了|感到温暖)|必然|必须感受|保证.{0,8}(放松|平静)');
    if (resultClaims.allMatches(joined).any((match) =>
        !_negatedBefore(joined, match.start) &&
        !RegExp(r'不一定|未必|不会|不必|不需要|无需').hasMatch(match.group(0)!))) {
      issues.add('不能替用户宣布身体或情绪结果，也不能要求出现某种感觉');
    }
    var minimumSeconds = 0;
    for (var i = 0; i < segments.length; i++) {
      final s = segments[i];
      final text = '${s['text'] ?? ''}';
      final limit = durationSeconds <= 120 ? 55 : 85;
      if (text.replaceAll(RegExp(r'\s'), '').length > limit) {
        issues.add('第 ${i + 1} 段过长，请拆成“邀请—留白—观察”的短段');
      }
      final pause = s['pause_after_seconds'];
      if (pause is! int ||
          pause < (durationSeconds <= 120 ? 1 : 4) ||
          pause > 30) {
        issues.add('第 ${i + 1} 段需要有效的 pause_after_seconds，给体验留下安静时间');
      }
      minimumSeconds +=
          speechSeconds(text) + (pause is int ? math.max(0, pause) : 0);
    }
    if (minimumSeconds > (plannedDurationSeconds ?? durationSeconds)) {
      issues.add(
          '播报与停顿至少需 $minimumSeconds 秒，超过目标 $durationSeconds 秒；缩短文字，保留体验留白');
    }
    return issues.toSet().toList();
  }

  static bool _echoesTheme(String text, String anchor, String theme) {
    if (text.contains(anchor)) return true;
    // Allow the design's concrete restatement to carry the theme into the
    // narration, e.g. "认知转变" -> "念头与行动之间的一点空间".
    final terms = <String>{};
    for (final part
        in RegExp(r'[\u3400-\u9fff]+|[A-Za-z]+').allMatches('$anchor $theme')) {
      final word = part.group(0)!;
      if (word.length == 1) terms.add(word);
      for (var i = 0; i + 1 < word.length; i++)
        terms.add(word.substring(i, i + 2));
    }
    terms.removeAll(['本次', '一个', '一点', '可以', '身体', '感受', '情绪', '练习']);
    return terms.isNotEmpty &&
        terms.where(text.contains).length >= math.min(2, terms.length);
  }

  static bool _negatedBefore(String text, int start) => RegExp(
          r'(不|(?:不能|不会|不用|不必|不需要|无需|无法|不是|并非|没有|难以|避免)[^，,。；;!?！？]{0,6})\s*$')
      .hasMatch(text.substring(math.max(0, start - 12), start));

  static bool _activeImagery(String text) =>
      RegExp(r'想象|设想|心中浮现').allMatches(text).any((match) =>
          !_negatedBefore(text, match.start) &&
          !RegExp(r'^不出|^不到|^不起来').hasMatch(text.substring(match.end)));

  /// Retain a viable model timeline. Repair overlaps using speech + explicit
  /// silence, giving additional time to the embodied part of the practice.
  static List<MeditationStep> schedule(
      List<MeditationStep> steps, int durationSeconds) {
    if (steps.isEmpty) return steps;
    final minimum =
        steps.map((s) => speechSeconds(s.text) + s.pauseAfterSeconds).toList();
    final required = minimum.fold<int>(0, (a, b) => a + b);
    if (required > durationSeconds)
      throw const FormatException('引导和体验停顿超出目标时长');
    final fits = steps.first.startSecond == 0 &&
        List.generate(steps.length, (i) {
          final end =
              i + 1 < steps.length ? steps[i + 1].startSecond : durationSeconds;
          return end - steps[i].startSecond >= minimum[i];
        }).every((fit) => fit);
    if (fits) return steps;
    final weights = steps
        .map((s) =>
            RegExp(r'body_emotion|allow_experience|embodied_shift|real_life_rehearsal')
                    .hasMatch(s.intent ?? '')
                ? 2
                : 1)
        .toList();
    final totalWeight = weights.fold<int>(0, (a, b) => a + b);
    final spare = durationSeconds - required;
    var cursor = 0;
    var allocated = 0;
    return List.generate(steps.length, (i) {
      final step = steps[i];
      final result = MeditationStep(
          startSecond: cursor,
          text: step.text,
          pauseAfterSeconds: step.pauseAfterSeconds,
          intent: step.intent);
      final extra = i == steps.length - 1
          ? spare - allocated
          : spare * weights[i] ~/ totalWeight;
      allocated += extra;
      cursor += minimum[i] + extra;
      return result;
    });
  }
}

/// The planned clock must not cut off slow narration or its experience pause.
class MeditationVoicePacing {
  bool speaking = false;
  int silenceSeconds = 0;
  int _pause = 0;
  int _generation = 0;

  int begin(int pause) {
    speaking = true;
    silenceSeconds = 0;
    _pause = pause;
    return ++_generation;
  }

  bool complete([int? generation]) {
    if (generation != null && generation != _generation) return false;
    if (!speaking) return false;
    speaking = false;
    silenceSeconds = _pause;
    return true;
  }

  bool holdAtBoundary(int nextSecond, int boundary) =>
      nextSecond >= boundary && (speaking || silenceSeconds > 0);

  void tick() {
    if (!speaking && silenceSeconds > 0) silenceSeconds--;
  }

  void cancel([int? generation]) {
    if (generation != null && generation != _generation) return;
    _generation++;
    speaking = false;
    silenceSeconds = 0;
  }
}
