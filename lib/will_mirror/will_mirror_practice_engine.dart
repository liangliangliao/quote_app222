import 'will_mirror_practice_models.dart';

class WillMirrorPracticeEngine {
  const WillMirrorPracticeEngine();

  static const List<String> requiredRouteTypes = <String>[
    'act_now',
    'understand_then_act',
    'seven_day_experiment',
  ];

  List<WillMirrorActionRoute> buildRoutes({
    required WillMirrorNeedType needType,
    required String need,
    required String desiredOutcome,
    required String obstacle,
    required WillMirrorPracticeProfile profile,
  }) {
    final cleanNeed = _clean(need, fallback: '这件事');
    final outcome = _clean(
      desiredOutcome,
      fallback: needType == WillMirrorNeedType.goal
          ? '出现一个能看见的推进痕迹'
          : '问题比现在减轻一点，并知道下一步',
    );
    final barrier = _clean(obstacle, fallback: '还不知道真正的阻碍');
    final minutes = profile.energyMinutes;
    final trace = profile.interest.visibleTrace;

    final directTone = switch (profile.style) {
      WillMirrorSupportStyle.practical => '不再分析，先留下一个结果',
      WillMirrorSupportStyle.curious => '把第一步当作侦察，用结果换取新线索',
      WillMirrorSupportStyle.gentle => '只做小到没有压力的一步，随时可以停止',
    };

    return <WillMirrorActionRoute>[
      WillMirrorActionRoute(
        type: WillMirrorRouteType.actNow,
        title: '现在做出一个痕迹',
        promise: '$minutes 分钟内得到可见产出',
        action: '围绕“$cleanNeed”，用 $minutes 分钟$trace。到点就停。',
        successSignal: '结束时留下一个能再次打开、查看或继续的具体痕迹。',
        whyItWorks:
            '$directTone。实际选择能检验口头叙述；没有完成只说明还存在能力、资源或情境限制。',
        output: '一个真实产出 + 一条行动证据',
        minutes: minutes,
        theoryIds: const <String>[
          'SCH-B4-055-ACTION-CHARACTER',
          'TAL-L13-SEVEN-DAY-STRENGTH',
        ],
      ),
      WillMirrorActionRoute(
        type: WillMirrorRouteType.understandThenAct,
        title: '先看清一个关键阻碍',
        promise: '回答一问，再做一小步',
        action:
            '先写一句：“如果没有‘$barrier’，我最先会做什么？”然后从答案中选最小动作，用 $minutes 分钟完成。',
        successSignal: '得到一个更具体的阻碍说明，并完成或尝试了由答案产生的一步。',
        whyItWorks:
            '具体 Why 用来识别此时此地的目的和动机；得到新信息后立刻回到行动，避免无限追问。',
        output: '一个动机线索 + 一个现实尝试',
        minutes: minutes,
        theoryIds: const <String>[
          'SCH-B2-029-MOTIVE',
          'SCH-B2-029-MOTIVE-BOUNDARY',
          'TAL-L12-REALLY-WANT',
        ],
      ),
      WillMirrorActionRoute(
        type: WillMirrorRouteType.sevenDayExperiment,
        title: '用七天让生活回答',
        promise: '每天 $minutes 分钟，不要求连续打卡',
        action:
            '未来七天，每次用 $minutes 分钟为“$cleanNeed”留下一个小痕迹；每次只记录能量、最像自己程度和“还想不想继续”。',
        successSignal: '至少获得三次真实反馈，能判断怎样调整行动，而不是证明自己行或不行。',
        whyItWorks:
            '“$outcome”先作为待检验目标。短周期实践用于观察认领程度、持续性与需要满足，一天结果不定性。',
        output: '一组现实反馈 + 下一轮调整依据',
        minutes: minutes,
        theoryIds: const <String>[
          'TAL-L13-SEVEN-DAY-STRENGTH',
          'SHELDON-ELLIOT-1999-SELF-CONCORDANCE',
          'SCH-B4-055-ACTION-CHARACTER',
        ],
      ),
    ];
  }

  String candidateLabel({
    required WillMirrorNeedType needType,
    required String need,
  }) {
    final clean = _short(_clean(need, fallback: '当前需要'), 24);
    return needType == WillMirrorNeedType.goal
        ? '我是否愿意持续推进：$clean'
        : '解决它是否会让我更愿意行动：$clean';
  }

  static String _clean(String value, {required String fallback}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.isEmpty ? fallback : normalized;
  }

  static String _short(String value, int max) {
    if (value.length <= max) return value;
    return '${value.substring(0, max)}…';
  }
}
