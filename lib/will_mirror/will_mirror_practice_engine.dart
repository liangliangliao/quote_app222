import 'will_mirror_capability_catalog.dart';
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
    final context = _contextFor('$cleanNeed $outcome');
    final barrierType = _barrierFor(barrier);
    final directAction = _directAction(
      context: context,
      need: cleanNeed,
      profile: profile,
    );
    final barrierAction = _barrierAction(
      type: barrierType,
      barrier: barrier,
      need: cleanNeed,
      minutes: minutes,
    );

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
        action: '$directAction 到点就停，不补做。',
        successSignal: _successSignal(context),
        whyItWorks:
            '$directTone。实际选择能检验口头叙述；没有完成只说明还存在能力、资源或情境限制。',
        output: '一个真实产出 + 一条行动证据',
        minutes: minutes,
        theoryIds: const <String>[
          'SCH-B4-055-ACTION-CHARACTER',
          'TAL-L13-SEVEN-DAY-STRENGTH',
        ],
        theoryApplications: _applications(
          const <String>[
            'SCH-B4-055-ACTION-CHARACTER',
            'TAL-L13-SEVEN-DAY-STRENGTH',
          ],
          application: '不凭一句“想要”定性，先让“$cleanNeed”产生一个可观察结果。',
          reason: '现实动作会增加新证据；动作足够小，结果更不容易被体力和压力混淆。',
        ),
      ),
      WillMirrorActionRoute(
        type: WillMirrorRouteType.understandThenAct,
        title: '先看清一个关键阻碍',
        promise: '回答一问，再做一小步',
        action: barrierAction,
        successSignal: '写出一个可核对的阻碍线索，并留下由这个线索产生的一步现实痕迹。',
        whyItWorks:
            '具体 Why 用来识别此时此地的目的和动机；得到新信息后立刻回到行动，避免无限追问。',
        output: '一个动机线索 + 一个现实尝试',
        minutes: minutes,
        theoryIds: const <String>[
          'SCH-B2-029-MOTIVE',
          'SCH-B2-029-MOTIVE-BOUNDARY',
          'TAL-L12-REALLY-WANT',
        ],
        theoryApplications: _applications(
          const <String>[
            'SCH-B2-029-MOTIVE',
            'SCH-B2-029-MOTIVE-BOUNDARY',
            'TAL-L12-REALLY-WANT',
          ],
          application: '把“$barrier”当成待检验条件，只追问能改变下一步的具体原因。',
          reason: '叔本华的动机解释支持追问具体行动，但认识边界要求停止无限追问并回到现实检验。',
        ),
      ),
      WillMirrorActionRoute(
        type: WillMirrorRouteType.sevenDayExperiment,
        title: '用七天让生活回答',
        promise: '每天 $minutes 分钟，不要求连续打卡',
        action:
            '未来七天任选至少三天重复这一步：$directAction 每次做完或没做成都记录真实条件。',
        successSignal: '形成至少三次不同日期的反馈，能说清支持证据、反例或成立条件中的至少一项。',
        whyItWorks:
            '“$outcome”先作为待检验目标。短周期实践用于观察认领程度、持续性与需要满足，一天结果不定性。',
        output: '一组现实反馈 + 下一轮调整依据',
        minutes: minutes,
        theoryIds: const <String>[
          'TAL-L13-SEVEN-DAY-STRENGTH',
          'SHELDON-ELLIOT-1999-SELF-CONCORDANCE',
          'SCH-B4-055-ACTION-CHARACTER',
        ],
        theoryApplications: _applications(
          const <String>[
            'TAL-L13-SEVEN-DAY-STRENGTH',
            'SHELDON-ELLIOT-1999-SELF-CONCORDANCE',
            'SCH-B4-055-ACTION-CHARACTER',
          ],
          application: '把“$outcome”作为七天假说，用重复行动、能量和愿意继续程度共同验证。',
          reason: '一次体验不能代表稳定倾向；跨日期事实与反例才能减少自我想象和偶然状态的干扰。',
        ),
      ),
    ];
  }

  String localSituationSummary({
    required WillMirrorNeedType needType,
    required String need,
    required String desiredOutcome,
    required String obstacle,
  }) {
    final cleanNeed = _clean(need, fallback: '当前这件事');
    final outcome = _clean(desiredOutcome, fallback: '得到一个可观察变化');
    final barrier = _clean(obstacle, fallback: '阻碍还不明确');
    return '${needType.shortLabel}是“$cleanNeed”；本轮不判断你的本质，只验证能否朝“$outcome”前进一步，并区分“$barrier”背后的现实条件。';
  }

  String localBlindSpotQuestion(String obstacle) {
    return switch (_barrierFor(obstacle)) {
      _BarrierType.perfection => '如果今天只允许做一个不会公开的粗糙版本，你还会卡在哪里？',
      _BarrierType.unclear => '下一步究竟缺的是一个决定、一个信息，还是一个可以直接动手的动作？',
      _BarrierType.timeEnergy => '把理想时间拿掉后，今天真实存在的两分钟窗口在哪里？',
      _BarrierType.resources => '缺少的资源中，哪一项是真正前提，哪一项可以先用替代品验证？',
      _BarrierType.relationship => '这一步怎样同时尊重你的需要、对方的同意和现实边界？',
      _BarrierType.unknown => '什么最可能让这一步即使很小也无法开始？',
    };
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

  static _PracticeContext _contextFor(String value) {
    if (_has(value, <String>['作品集', '写作', '文章', '设计', '画', '视频', '创作'])) {
      return _PracticeContext.creation;
    }
    if (_has(value, <String>['学习', '考试', '课程', '读书', '知识', '技能'])) {
      return _PracticeContext.learning;
    }
    if (_has(value, <String>['辞职', '工作', '职业', '求职', '面试', '创业'])) {
      return _PracticeContext.career;
    }
    if (_has(value, <String>['关系', '伴侣', '朋友', '父母', '沟通', '表达'])) {
      return _PracticeContext.relationship;
    }
    if (_has(value, <String>['运动', '睡眠', '早起', '饮食', '健康', '习惯'])) {
      return _PracticeContext.routine;
    }
    return _PracticeContext.general;
  }

  static _BarrierType _barrierFor(String value) {
    if (_has(value, <String>['完美', '做不好', '害怕', '失败', '比较', '评价'])) {
      return _BarrierType.perfection;
    }
    if (_has(value, <String>['不知道', '不清楚', '不会', '没思路', '第一步'])) {
      return _BarrierType.unclear;
    }
    if (_has(value, <String>['没时间', '没精力', '太累', '加班', '忙'])) {
      return _BarrierType.timeEnergy;
    }
    if (_has(value, <String>['工具', '钱', '设备', '材料', '资源'])) {
      return _BarrierType.resources;
    }
    if (_has(value, <String>['拒绝', '冲突', '对方', '关系', '否定'])) {
      return _BarrierType.relationship;
    }
    return _BarrierType.unknown;
  }

  static String _directAction({
    required _PracticeContext context,
    required String need,
    required WillMirrorPracticeProfile profile,
  }) {
    final minutes = profile.energyMinutes;
    return switch (context) {
      _PracticeContext.creation =>
        '打开与“$need”直接相关的文件，用 $minutes 分钟只写一个标题和三条要点。',
      _PracticeContext.learning =>
        '选“$need”中最关键的一个概念，用 $minutes 分钟写一句自己的解释和一个仍不懂的问题。',
      _PracticeContext.career =>
        '打开备忘录，用 $minutes 分钟写下一个可核查的职业条件，并查到一个真实选项或联系人。',
      _PracticeContext.relationship =>
        '用 $minutes 分钟写一句“当……时，我感到……，我希望……”，先不发送，并补上“对方可以不同意”。',
      _PracticeContext.routine =>
        '用 $minutes 分钟完成“$need”的最小启动动作，并在结束时留下可见记录。',
      _PracticeContext.general =>
        '围绕“$need”，用 $minutes 分钟${profile.interest.visibleTrace}。',
    };
  }

  static String _successSignal(_PracticeContext context) {
    return switch (context) {
      _PracticeContext.creation => '文件里出现一个标题和三条可以继续修改的要点。',
      _PracticeContext.learning => '纸面上出现一句自己的解释和一个明确未知点。',
      _PracticeContext.career => '留下一个职业判断条件和一条来自现实的选项信息。',
      _PracticeContext.relationship => '形成一句具体、可被拒绝且尊重双方边界的表达。',
      _PracticeContext.routine => '完成一次最小启动，并留下时间或结果记录。',
      _PracticeContext.general => '留下一个能再次打开、查看或继续的具体痕迹。',
    };
  }

  static String _barrierAction({
    required _BarrierType type,
    required String barrier,
    required String need,
    required int minutes,
  }) {
    return switch (type) {
      _BarrierType.perfection =>
        '先写一句“这只是不会公开的第 0 版”，再用 $minutes 分钟为“$need”做一个故意粗糙、可删除的版本。',
      _BarrierType.unclear =>
        '把“$barrier”拆成“缺决定 / 缺信息 / 缺动作”三类，只选一类；再用 $minutes 分钟补一个信息或写下第一个可见动作。',
      _BarrierType.timeEnergy =>
        '写下今天真正可用的最短时间窗，只用其中 $minutes 分钟准备“$need”的入口，到点停止。',
      _BarrierType.resources =>
        '列出“$need”缺少的唯一前提，并用 $minutes 分钟找到一个可借用、替代或先行验证的资源。',
      _BarrierType.relationship =>
        '先写清自己的需要、对方可拒绝的边界和最小请求，再用 $minutes 分钟形成一句不施压的表达。',
      _BarrierType.unknown =>
        '回答“如果现在必须开始，最先让我停住的具体一秒是什么？”再用 $minutes 分钟只处理答案中的第一处阻力。',
    };
  }

  static List<WillMirrorTheoryApplication> _applications(
    List<String> ids, {
    required String application,
    required String reason,
  }) {
    return ids.map((id) {
      final theory = WillMirrorTheoryCatalog.find(id);
      return WillMirrorTheoryApplication(
        theoryId: id,
        concept: theory?.shortLabel ?? id,
        application: application,
        reason: reason,
      );
    }).toList(growable: false);
  }

  static bool _has(String value, List<String> words) => words.any(value.contains);
}

enum _PracticeContext { creation, learning, career, relationship, routine, general }

enum _BarrierType { perfection, unclear, timeEnergy, resources, relationship, unknown }
