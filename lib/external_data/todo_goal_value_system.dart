class TodoGoalValuePrinciple {
  const TodoGoalValuePrinciple({required this.title, required this.description, required this.actionQuestion});
  final String title;
  final String description;
  final String actionQuestion;
}

class TodoGoalOriginalQuote {
  const TodoGoalOriginalQuote({required this.key, required this.title, required this.translation, required this.productUse});
  final String key;
  final String title;
  final String translation;
  final String productUse;
}

const String todoGoalCentralTheme = '真实面对旧模式，保留内在价值，进入适度不适，用持续行动创造新的自我证据。';

const String todoGoalSubTheme = 'ChangePath 不承诺速成，也不让理解停留在 App 内。每个同步任务、目标、日记与复盘都要进入同一条改变闭环：觉察旧模式、澄清具体行为、识别阻力、设计拉伸区行动、回到现实、复盘并沉淀自我证据。';

const List<TodoGoalValuePrinciple> todoGoalCoreValues = <TodoGoalValuePrinciple>[
  TodoGoalValuePrinciple(
    title: '反 Quick Fix',
    description: '改变是训练，不是刺激；系统不承诺短期逆袭，而是帮助用户完成今天一个可验证的真实行动。',
    actionQuestion: '今天哪个小行动能成为新路径的一次重复？',
  ),
  TodoGoalValuePrinciple(
    title: 'ABC 一起更新',
    description: '情绪、行为与认知互相影响。既看见感受和身体信号，也记录实际行为，并用行动后的现实反馈更新解释。',
    actionQuestion: '我感受到什么、如何解释、实际做了什么，行动后又看见了什么？',
  ),
  TodoGoalValuePrinciple(
    title: '保留价值，改变极端模式',
    description: '旧模式常在保护责任、关系、安全或卓越。改变不是消灭旧的自己，而是保留价值、降低僵化和代价。',
    actionQuestion: '这个旧模式在保护什么？我怎样保留价值但换一种行为？',
  ),
  TodoGoalValuePrinciple(
    title: '行动成为自我证据',
    description: '任务完成不是终点。每次行动都要回答它削弱了哪个旧信念、正在形成怎样的新身份叙事。',
    actionQuestion: '这个行动证明了我是怎样的人？',
  ),
  TodoGoalValuePrinciple(
    title: '目标解放当下',
    description: '目标的作用不是把幸福推迟到未来，而是提供方向感，让今天不再迷茫，让人更能看见此刻过程中的价值。',
    actionQuestion: '这个任务如何帮助我更清楚地投入今天，而不是焦虑地等待未来？',
  ),
  TodoGoalValuePrinciple(
    title: '过程重于抵达',
    description: '达成目标只会带来短暂峰值，更稳定的幸福来自朝重要方向努力、体验沿途、在行动中感到自己正在生活。',
    actionQuestion: '今天这一小步里，哪一部分本身值得体验？',
  ),
  TodoGoalValuePrinciple(
    title: '自我和谐优先',
    description: '好目标应尽量与个人真正关心的价值、兴趣、热情一致，而不是只来自攀比、义务、社会期待或恐惧。',
    actionQuestion: '这是我真正想要、深切在乎的事，还是我只是觉得“不得不做”？',
  ),
  TodoGoalValuePrinciple(
    title: '承诺创造行动',
    description: '目标必须落到现实行为中。写下目标、公开承诺、确定日期、拆成下一步，才能从想法进入生活。',
    actionQuestion: '我现在5分钟内能做的最小真实行动是什么？',
  ),
  TodoGoalValuePrinciple(
    title: '拉伸而非恐慌',
    description: '改变发生在舒适区之外、恐慌区之前。任务应足够小，可以开始；也要足够有挑战，能带来成长。',
    actionQuestion: '这个行动是在拉伸我，还是已经大到让我想逃？',
  ),
  TodoGoalValuePrinciple(
    title: '复盘强化意义',
    description: '复盘不是审判完成率，而是把经历转化为自我理解：我做了什么、为什么做、过程如何、明天怎样继续。',
    actionQuestion: '今天的行动让我更接近什么样的自己？',
  ),
];


class TodoGoalValuePractice {
  const TodoGoalValuePractice({required this.title, required this.trigger, required this.userAction, required this.aiAction});
  final String title;
  final String trigger;
  final String userAction;
  final String aiAction;
}

const List<TodoGoalValuePractice> todoGoalPracticeMap = <TodoGoalValuePractice>[
  TodoGoalValuePractice(
    title: '看见方向',
    trigger: '当用户打开一个 To Do 任务时',
    userAction: '先回答：这件事通向我想要的哪种生活？',
    aiAction: '把任务标题改写成方向语言，而不是直接拆步骤。',
  ),
  TodoGoalValuePractice(
    title: '校准自我和谐',
    trigger: '当用户准备把任务转成目标时',
    userAction: '选择它更像：真正想要、价值重要、现实必要、外部压力，还是焦虑驱动。',
    aiAction: '给出自我和谐评分，并说明怎样把外部压力转化成个人价值。',
  ),
  TodoGoalValuePractice(
    title: '设计沿途体验',
    trigger: '当目标已经确定但用户还没行动时',
    userAction: '写下一句：今天这一小步里，我要体验或练习什么？',
    aiAction: '把“完成任务”改写成可体验的过程，例如练习表达、整理思路、恢复掌控感。',
  ),
  TodoGoalValuePractice(
    title: '压缩到可开始',
    trigger: '当行动太大、太虚或让用户想逃时',
    userAction: '把行动降到 2-5 分钟能开始的最低标准。',
    aiAction: '自动生成最低标准、推荐标准和拉伸挑战，避免直接进入恐慌区。',
  ),
  TodoGoalValuePractice(
    title: '开始而不是等待',
    trigger: '当用户进入今日旅程时',
    userAction: '点击“开始 5 分钟”，先进入现实，再评价状态。',
    aiAction: '不催促完成整件事，只提醒现在能做的一个可观察动作。',
  ),
  TodoGoalValuePractice(
    title: '复盘生成下一步',
    trigger: '当用户完成、部分完成或没有完成时',
    userAction: '记录事实、过程体验和阻力，并让明日行动更小一步。',
    aiAction: '把完成/未完成都转化为下一步设计，而不是道德评价。',
  ),
];

const List<String> todoGoalTodayPracticeQuestions = <String>[
  '方向：这件事今天让我更靠近哪一种生活？',
  '过程：做这一步时，我可以体验或练习什么？',
  '行动：现在 5 分钟内，我能开始哪个可观察动作？',
  '难度：它是在拉伸区，还是已经让我想逃？',
  '复盘：做完后，我能留下什么事实记录？',
];

const String todoGoalPracticeFirstPrompt = '不要把核心价值写成理论说明；每一次出现都必须绑定一个用户动作：澄清方向、选择来源、开始5分钟、记录过程、缩小一步、生成明日行动。';

const List<TodoGoalOriginalQuote> todoGoalTranslatedQuotes = <TodoGoalOriginalQuote>[
  TodoGoalOriginalQuote(
    key: 'present',
    title: '目标的作用，是解放我们去享受现在',
    translation: '正确理解目标时，目标的作用是解放我们，让我们能够享受当下。目标给我们方向感；当我们知道自己要去哪里，就更可能享受过程，也能看见路边的花。',
    productUse: '用于首页和今日旅程页，提醒用户：目标不是为了制造压力，而是为了让今天更清楚、更可投入。',
  ),
  TodoGoalOriginalQuote(
    key: 'journey',
    title: '幸福是朝山顶攀登的体验',
    translation: '幸福不是到达山顶，也不是漫无目的地在山上闲逛；幸福是朝着山顶攀登的体验。关键是有目标、有目的地，然后放下对结果的执着，享受过程。',
    productUse: '用于行动卡和复盘页，强化“今天这一小步本身就是生活”的产品氛围。',
  ),
  TodoGoalOriginalQuote(
    key: 'along',
    title: '为沿途而活',
    translation: '不要为已经赢得的战斗而活，不要为一首歌的结尾而活；要为沿途而活。',
    productUse: '用于过程体验记录，鼓励用户记录当下行动中的生命感，而不是只打勾。',
  ),
  TodoGoalOriginalQuote(
    key: 'self_concordance',
    title: '自我和谐目标来自真正关心的东西',
    translation: '自我和谐目标，本质上是与你个人兴趣和价值相一致的目标，是你关心的事情，是对你重要的事情。它们不是外界强加的，不是出于义务或责任感而做，而是你从内心深处想要做的事。',
    productUse: '用于 AI 转化任务时判断目标来源，区分“真正想要”和“外部压力”。',
  ),
  TodoGoalOriginalQuote(
    key: 'self_journey',
    title: '自我和谐目标让人更享受旅程',
    translation: '设定自我和谐目标可能让我们更幸福，因为我们正在追求自己关心的东西，它更可能强化我们对旅程的享受。',
    productUse: '用于目标详情页和自我和谐评分说明，让评分服务于幸福和过程，而不是评价用户。',
  ),
  TodoGoalOriginalQuote(
    key: 'clarity',
    title: '目标帮助化解内在冲突',
    translation: '拥有目标，尤其是自我和谐目标，常常能帮助我们处理焦虑、不确定以及“我是谁、我在做什么、我为什么在这里”这样的存在性问题。当我们知道自己的道路时，它会帮助我们化解内在冲突。',
    productUse: '用于目标澄清与阻力诊断：当用户迷茫时，AI 要帮助他回到方向，而不是只催促完成任务。',
  ),
  TodoGoalOriginalQuote(
    key: 'joy',
    title: '带着愉悦做得更好',
    translation: '当我们追求自己热爱的事情时，我们会更有动力、更愿意努力、更可能投入全部。与其说“不痛苦就没有收获”，不如说：带着愉悦做得更好。',
    productUse: '用于今日行动和写回 To Do 的说明，提醒用户把任务设计得既真实又可持续。',
  ),
];


TodoGoalOriginalQuote todoGoalQuoteFor(String key) {
  return todoGoalTranslatedQuotes.firstWhere(
    (q) => q.key == key,
    orElse: () => todoGoalTranslatedQuotes.first,
  );
}


const Map<String, List<String>> todoGoalQuoteMomentKeys = <String, List<String>>{
  'entry': <String>['present', 'journey', 'clarity', 'joy', 'along'],
  'transform': <String>['self_concordance', 'clarity', 'self_journey', 'joy'],
  'today': <String>['journey', 'present', 'joy', 'along'],
  'detail': <String>['self_journey', 'self_concordance', 'clarity', 'journey'],
  'review': <String>['along', 'journey', 'clarity', 'present'],
  'write_back': <String>['joy', 'journey', 'along', 'present'],
};

int todoGoalDailyQuoteSeed({int extra = 0}) {
  final now = DateTime.now();
  return now.year * 10000 + now.month * 100 + now.day + extra;
}

TodoGoalOriginalQuote todoGoalQuoteForMoment(String moment, {int seedOffset = 0}) {
  final keys = todoGoalQuoteMomentKeys[moment] ?? todoGoalQuoteMomentKeys['entry']!;
  final idx = todoGoalDailyQuoteSeed(extra: seedOffset).abs() % keys.length;
  return todoGoalQuoteFor(keys[idx]);
}

String todoGoalQuoteActionForMoment(String moment) {
  switch (moment) {
    case 'transform':
      return '转化时不要只解释任务：说清为什么重要、判断是否真正关心、生成今天能开始的一小步。';
    case 'today':
      return '不要先问能不能完成全部，只问现在能不能先开始最低标准。';
    case 'detail':
      return '进入详情页后，立刻检查这个目标是否有今天可做、可体验、可复盘的一步。';
    case 'review':
      return '复盘至少留下一个事实、一个过程体验、一个明日更小行动。';
    case 'write_back':
      return '写回 To Do 时只保留一条行动提示，让提醒服务于开始，而不是堆满理论。';
    case 'entry':
    default:
      return '现在不要阅读更多理论，去选择一个行动：转化任务，或开始今日最小行动。';
  }
}

const List<String> todoGoalRealityLoop = <String>[
  '看见任务：这件 To Do 背后可能隐藏着一个人生方向线索。',
  '澄清意义：它通向我想要的哪种生活、哪种身份、哪种能力？',
  '校准自我和谐：这是我真正关心的事，还是外部压力和焦虑？',
  '设计过程：今天这一小步本身有什么值得体验的地方？',
  '落地行动：把目标拆成5分钟内可开始的最小真实行为。',
  '复盘强化：记录做了什么、过程如何、明天如何更小一步继续。',
];

String todoGoalValueSystemPromptBlock() => '''
【积极心理学目标价值体系】
中心主题：$todoGoalCentralTheme
展开主题：$todoGoalSubTheme

必须遵守的产品价值：
1. 目标解放当下：目标不是把幸福推迟到未来，而是让用户今天更有方向地投入现实。
2. 过程重于抵达：不要只强调完成、结果、打勾；必须指出行动过程本身的意义和可体验之处。
3. 自我和谐优先：判断目标是否与用户个人价值、兴趣、热情和真实需要一致，区分内在愿望、价值驱动、现实必要、外部压力、焦虑驱动。
4. 承诺创造行动：每个目标必须转成今天能开始的最小真实行为。
5. 拉伸而非恐慌：行动要落在拉伸区；如果太大，要拆小；如果太空，要具体化。
6. 复盘强化意义：复盘不是评价用户好坏，而是帮助用户理解行动、过程、阻力和下一步。

课程原文中文价值氛围：
- “正确理解目标时，目标的作用是解放我们，让我们能够享受当下。”
- “幸福不是到达山顶，也不是漫无目的地在山上闲逛；幸福是朝着山顶攀登的体验。”
- “不要为已经赢得的战斗而活，不要为一首歌的结尾而活；要为沿途而活。”
- “自我和谐目标是与你个人兴趣和价值相一致的目标，是你关心的事情，是对你重要的事情。”
- “带着愉悦做得更好。”

回答必须把任务转化为：方向感、深层意义、自我和谐判断、过程价值、5分钟内可开始的今日最小行动、拉伸区难度、温和但具体的现实行动引导。不要输出纯理论或长篇价值解释；每个字段都必须让用户知道下一步怎么做、何时做、做到什么程度算完成。
''';
