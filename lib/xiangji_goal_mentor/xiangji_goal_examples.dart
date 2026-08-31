import 'xiangji_goal_intelligence_service.dart';

class XiangjiGoalExample {
  const XiangjiGoalExample({
    required this.id,
    required this.title,
    required this.need,
    required this.desiredOutcome,
    required this.obstacle,
    required this.interest,
    required this.tone,
    required this.minutes,
    required this.selectedRoute,
    required this.expectedOutput,
    required this.sevenDayTrace,
    required this.review,
  });

  final String id;
  final String title;
  final String need;
  final String desiredOutcome;
  final String obstacle;
  final XiangjiGoalInterest interest;
  final XiangjiSupportTone tone;
  final int minutes;
  final String selectedRoute;
  final String expectedOutput;
  final List<String> sevenDayTrace;
  final String review;
}

/// Built-in, inspectable examples used by onboarding, the guide and tests.
/// They are deliberately ordinary rather than idealized: each includes at
/// least one blocked day so a user can see how reality changes the next step.
const List<XiangjiGoalExample> xiangjiGoalExamples = <XiangjiGoalExample>[
  XiangjiGoalExample(
    id: 'writing_restart',
    title: '恢复晨间写作',
    need: '我想恢复晨间写作，但一想到要写好就不想打开文档。',
    desiredOutcome: '七天内留下三次真实写作痕迹，而不是写出完美文章。',
    obstacle: '早晨时间不稳定，而且担心写得差。',
    interest: XiangjiGoalInterest.create,
    tone: XiangjiSupportTone.gentle,
    minutes: 5,
    selectedRoute: '先做出一个成果',
    expectedOutput: '一个标题、三条要点，以及三次日期记录。',
    sevenDayTrace: <String>[
      '第1天：5分钟写出标题和三条要点。',
      '第2天：没开始；事实是起床后先处理工作消息。',
      '第3天：把触发点改为午饭后，写了82字。',
      '第4天：只修改一个段落，没有扩写。',
      '第5天：受阻；文件不在手机上，补做了同步。',
      '第6天：写了6分钟，留下一个待回答问题。',
      '第7天：选择继续午饭后窗口，不再绑定“晨间”。',
    ],
    review: '改变的是触发条件，不是否定目标。完美压力被转成可修改的草稿证据。',
  ),
  XiangjiGoalExample(
    id: 'career_transition',
    title: '验证职业转型',
    need: '我考虑转向产品经理，但不知道是真喜欢还是只想逃离现在的工作。',
    desiredOutcome: '拿到三个真实岗位样本和一次从业者反馈，再决定是否投入学习。',
    obstacle: '信息很多、害怕选错，容易一直比较课程。',
    interest: XiangjiGoalInterest.career,
    tone: XiangjiSupportTone.curious,
    minutes: 15,
    selectedRoute: '先看清再行动',
    expectedOutput: '岗位样本表、一个具体询问和一次真实回复。',
    sevenDayTrace: <String>[
      '第1天：收集三个岗位描述，标出共同任务。',
      '第2天：写下“我想逃离什么”和“我愿意承担什么”。',
      '第3天：向一位从业者发出15分钟访谈请求。',
      '第4天：未获回复；事实是请求过于宽泛。',
      '第5天：把请求改成三个具体问题并发给另一人。',
      '第6天：得到回复，发现最不喜欢的工作内容仍会存在。',
      '第7天：决定先做一个小项目，而不是立刻报课。',
    ],
    review: '目标从“马上转行”改为“用现实样本验证匹配度”，降低了不可逆决策压力。',
  ),
  XiangjiGoalExample(
    id: 'relationship_request',
    title: '说出一个有边界的请求',
    need: '我希望伴侣能多分担家务，但每次说到这件事就吵架。',
    desiredOutcome: '完成一次不指责、可被讨论的具体请求，并记录对方真实回应。',
    obstacle: '我担心被拒绝，也会一次把以前的不满全部说出来。',
    interest: XiangjiGoalInterest.connect,
    tone: XiangjiSupportTone.practical,
    minutes: 10,
    selectedRoute: '用七天让现实回答',
    expectedOutput: '一句具体请求、一次回应记录和下一轮边界决定。',
    sevenDayTrace: <String>[
      '第1天：把“你从不帮忙”改成周三洗碗的具体请求。',
      '第2天：检查请求是否允许对方拒绝或协商。',
      '第3天：没有开口；事实是双方都在赶时间。',
      '第4天：先约定十分钟谈话窗口。',
      '第5天：提出请求，对方愿意尝试但希望换到周四。',
      '第6天：周四未完成；记录原因是临时加班。',
      '第7天：双方改为周末共同列分工，不扩大到人格评价。',
    ],
    review: '思想方法改变了表达结构，但不承诺控制他人；现实回应决定协商、暂停或设置边界。',
  ),
];
