import 'package:flutter/material.dart';

import '../pages/ai_prompt_settings_page.dart';
import 'realistic_positivity_os_ai_service.dart';
import 'realistic_positivity_os_dao.dart';
import 'realistic_positivity_os_models.dart';
import 'realistic_positivity_os_prompt_config.dart';

class RpoGuidedFieldSpec {
  final String id;
  final String label;
  final String hint;
  final int minLines;
  final int maxLines;
  final bool isRequired;

  const RpoGuidedFieldSpec({
    required this.id,
    required this.label,
    required this.hint,
    this.minLines = 1,
    this.maxLines = 4,
    this.isRequired = false,
  });
}

class RpoGuidedModuleSpec {
  final String id;
  final String title;
  final String subtitle;
  final String courseValue;
  final String productGoal;
  final String promptId;
  final List<RpoGuidedFieldSpec> fields;
  final List<String> coverage;
  final List<String> safeguards;

  const RpoGuidedModuleSpec({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.courseValue,
    required this.productGoal,
    required this.promptId,
    required this.fields,
    this.coverage = const <String>[],
    this.safeguards = const <String>[],
  });
}

class RealisticPositivityOsWorkbenchPage extends StatefulWidget {
  final String initialSceneType;
  final RpoProfile profile;

  const RealisticPositivityOsWorkbenchPage({
    super.key,
    this.initialSceneType = 'reality_lens',
    this.profile = const RpoProfile(),
  });

  static const List<RpoGuidedModuleSpec> specs = <RpoGuidedModuleSpec>[
    RpoGuidedModuleSpec(
      id: 'onboarding',
      title: 'Onboarding 人格地图',
      subtitle: '建立当前困扰、感恩资产、旧问题、价值绑定、支持关系和 Stretch 方向。',
      courseValue: '把 Lecture 9–10 的价值系统变成用户长期背景，而不是每次从零开始。',
      productGoal: '形成 AI 可调用的人格地图，支撑个性化分流、行动建议和每周整合。',
      promptId: RealisticPositivityOsPromptConfig.sceneOnboardingId,
      fields: <RpoGuidedFieldSpec>[
        RpoGuidedFieldSpec(id: 'current_trouble', label: '当前最想改变/理解的困扰', hint: '例如：拖延、反刍、完美主义、关系冲突后自责', minLines: 2, isRequired: true),
        RpoGuidedFieldSpec(id: 'common_emotions', label: '常见情绪', hint: '例如：焦虑、羞耻、委屈、疲惫'),
        RpoGuidedFieldSpec(id: 'old_questions', label: '我常困住自己的旧问题', hint: '例如：我为什么这么废？我是不是永远改不了？', minLines: 2),
        RpoGuidedFieldSpec(id: 'bound_values', label: '旧模式可能保护的珍贵价值', hint: '例如：完美主义保护雄心，焦虑保护责任感', minLines: 2),
        RpoGuidedFieldSpec(id: 'support_people', label: '可以感谢或求助的人', hint: '例如：朋友A、家人B、导师C'),
        RpoGuidedFieldSpec(id: 'stretch_area', label: '想进入 Stretch Zone 的领域', hint: '例如：表达、边界、学习启动、运动'),
      ],
      coverage: <String>['当前困扰地图', '情绪模式地图', 'Fault Finder 地图', '价值绑定地图', '支持关系地图', 'Stretch Zone 地图'],
    ),
    RpoGuidedModuleSpec(
      id: 'reality_lens',
      title: 'Reality Lens 真实看见',
      subtitle: '同时看见困难、解释、资源与可控 1%。',
      courseValue: 'Benefit Finder 不是盲目乐观，而是恢复现实完整性。',
      productGoal: '把用户从 fault finder 转向 reality finder。',
      promptId: RealisticPositivityOsPromptConfig.sceneRealityLensId,
      fields: <RpoGuidedFieldSpec>[
        RpoGuidedFieldSpec(id: 'event', label: '发生了什么事实？', hint: '只写可观察事实，先不下结论。', minLines: 2, isRequired: true),
        RpoGuidedFieldSpec(id: 'emotion', label: '我感到了什么？', hint: '例如：失望、害怕、愤怒、羞耻、孤独'),
        RpoGuidedFieldSpec(id: 'interpretation', label: '我正在怎么解释这件事？', hint: '例如：这说明我不够好 / TA 不在乎我', minLines: 2),
        RpoGuidedFieldSpec(id: 'resources', label: '仍然存在的资源/支持/能力', hint: '例如：可求助的人、已经做过的努力、还没失去的东西', minLines: 2),
        RpoGuidedFieldSpec(id: 'control_one_percent', label: '我能影响的 1% 是什么？', hint: '今天 2–10 分钟内可以做的一个动作'),
      ],
      coverage: <String>['事实/解释/情绪分离', '单边现实检测', '完整现实重构', '可控 1% 行动'],
      safeguards: <String>['不直接说“往好处想”', '先承认困难，再看资源'],
    ),
    RpoGuidedModuleSpec(
      id: 'question_reframing',
      title: 'Question Reframing 问题重构',
      subtitle: '识别旧问题，把注意力导向更完整、更可行动的问题。',
      courseValue: '问题创造现实：你问什么，就会活在什么心理现实里。',
      productGoal: '建立个人旧问题库，减少自我攻击和绝望预言。',
      promptId: RealisticPositivityOsPromptConfig.sceneQuestionReframingId,
      fields: <RpoGuidedFieldSpec>[
        RpoGuidedFieldSpec(id: 'old_question', label: '我正在问自己的旧问题', hint: '例如：我为什么这么废？为什么我总失败？', isRequired: true),
        RpoGuidedFieldSpec(id: 'scene', label: '这个问题出现在哪个场景？', hint: '例如：学习开始前、被拒绝后、关系冲突后'),
        RpoGuidedFieldSpec(id: 'cost', label: '这个旧问题带来了什么代价？', hint: '例如：自责、拖延、反刍、逃避'),
        RpoGuidedFieldSpec(id: 'new_direction', label: '我希望这个问题引导我走向什么？', hint: '例如：行动、表达、求助、边界、复盘'),
      ],
      coverage: <String>['坏问题分类', '新问题生成', '个人问题库沉淀', '基于新问题的小行动'],
    ),
    RpoGuidedModuleSpec(
      id: 'gratitude',
      title: 'Gratitude Practice 感恩训练',
      subtitle: '不是机械列清单，而是具体化、感官化、freshness。',
      courseValue: 'Appreciate 既是感谢，也是让被欣赏之物在心理现实中增长。',
      productGoal: '建立感恩资产库，训练用户重新体验日常奇迹。',
      promptId: RealisticPositivityOsPromptConfig.sceneGratitudeId,
      fields: <RpoGuidedFieldSpec>[
        RpoGuidedFieldSpec(id: 'object', label: '今天想珍惜的人/事/资源', hint: '例如：热水澡、朋友一句话、身体还能工作', isRequired: true),
        RpoGuidedFieldSpec(id: 'value', label: '它为什么重要？', hint: '它支持了你什么生活、关系或能力？', minLines: 2),
        RpoGuidedFieldSpec(id: 'sensory', label: '画面/声音/身体感受', hint: '请像 replay 一样具体描述', minLines: 2),
        RpoGuidedFieldSpec(id: 'absence', label: '如果它消失，我会怀念什么？', hint: '帮助对抗习以为常'),
        RpoGuidedFieldSpec(id: 'expression', label: '我可以如何表达珍惜？', hint: '一句话、一个动作、一封信、一次停留'),
      ],
      coverage: <String>['每日三层感恩', 'Freshness 防机械化', '感官化 replay', '感恩资产库'],
    ),
    RpoGuidedModuleSpec(
      id: 'relational_gratitude',
      title: 'Relational Gratitude 关系感恩',
      subtitle: '把内在感恩转成真实表达、感恩信、拜访和 pay it forward。',
      courseValue: '感恩表达能形成 win-win 和 upward spiral。',
      productGoal: '把 AI 引导重新带回真实关系，而不是替代关系。',
      promptId: RealisticPositivityOsPromptConfig.sceneRelationalGratitudeId,
      fields: <RpoGuidedFieldSpec>[
        RpoGuidedFieldSpec(id: 'person', label: '想感谢的人是谁？', hint: '例如：老师、朋友、家人、同事', isRequired: true),
        RpoGuidedFieldSpec(id: 'specific_act', label: 'TA 做过什么具体事情？', hint: '越具体越好', minLines: 2),
        RpoGuidedFieldSpec(id: 'impact_then', label: '当时这件事对我意味着什么？', hint: '例如：让我撑过低谷 / 给了我机会'),
        RpoGuidedFieldSpec(id: 'impact_later', label: '后来它怎样影响了我？', hint: '例如：改变了选择、恢复了信心'),
        RpoGuidedFieldSpec(id: 'tone_boundary', label: '语气与边界', hint: '例如：真诚简短 / 温暖正式 / 有感谢也有边界'),
      ],
      coverage: <String>['感谢对象地图', '感恩信生成', '感恩拜访计划', 'Pay It Forward', '关系修复型感恩'],
      safeguards: <String>['不鼓励讨好', '关系中有伤害时同时保护边界'],
    ),
    RpoGuidedModuleSpec(
      id: 'emotional_processing',
      title: 'Emotional Processing 允许为人',
      subtitle: '先 permission to be human，再 active acceptance。',
      courseValue: '压住痛苦往往也压住快乐；先允许情绪通过，再选择行动。',
      productGoal: '帮助用户从压抑/羞耻/强迫积极转向命名、允许和小行动。',
      promptId: RealisticPositivityOsPromptConfig.sceneEmotionalProcessingId,
      fields: <RpoGuidedFieldSpec>[
        RpoGuidedFieldSpec(id: 'emotion', label: '我现在最明显的情绪', hint: '例如：焦虑、委屈、羞耻、愤怒、孤独', isRequired: true),
        RpoGuidedFieldSpec(id: 'trigger', label: '触发事件', hint: '发生了什么让它被激活？', minLines: 2),
        RpoGuidedFieldSpec(id: 'body', label: '身体哪里有感觉？', hint: '例如：胸口紧、胃沉、肩膀硬'),
        RpoGuidedFieldSpec(id: 'need', label: '这个情绪可能在提醒我什么需要？', hint: '例如：休息、边界、被理解、安全'),
        RpoGuidedFieldSpec(id: 'support', label: '我可以联系谁或做什么稳定自己？', hint: '例如：朋友、散步、写三句话'),
      ],
      coverage: <String>['情绪命名器', 'Permission Card', 'Active Acceptance Card', '情绪压抑检测'],
      safeguards: <String>['不强迫积极', '不立刻要求感恩'],
    ),
    RpoGuidedModuleSpec(
      id: 'meaning_making',
      title: 'Meaning-Making 痛苦整合',
      subtitle: '负面经验要表达、书写、分析和整合，避免封闭反刍。',
      courseValue: '痛苦经验需要 meaning-making；只是反复想会加深痛苦。',
      productGoal: '把痛苦从循环反刍转为叙事、支持和修复行动。',
      promptId: RealisticPositivityOsPromptConfig.sceneMeaningMakingId,
      fields: <RpoGuidedFieldSpec>[
        RpoGuidedFieldSpec(id: 'event', label: '痛苦事件事实', hint: '发生了什么？', minLines: 2, isRequired: true),
        RpoGuidedFieldSpec(id: 'feelings', label: '我感受到什么？', hint: '多写几个情绪词'),
        RpoGuidedFieldSpec(id: 'pain_point', label: '最痛的点', hint: '真正刺痛我的是什么？', minLines: 2),
        RpoGuidedFieldSpec(id: 'rumination', label: '我一直反复想的句子', hint: '例如：为什么是我 / 如果当时怎样就好了'),
        RpoGuidedFieldSpec(id: 'support_repair', label: '可表达、可求助或可修复的行动', hint: '例如：写给自己、找朋友、明确边界', minLines: 2),
      ],
      coverage: <String>['痛苦事件书写', '反刍识别', '分享支持计划', '非强行意义化'],
      safeguards: <String>['不说“这一定是好事”', '先表达和支持，再谈转化'],
    ),
    RpoGuidedModuleSpec(
      id: 'savoring_peak',
      title: 'Savoring & Peak Experience 积极经验',
      subtitle: '积极经验要 replay、describe、write、act，而不是过度分析。',
      courseValue: '高峰体验可以成为 PPEO 的种子：积极经验也能重塑生命秩序。',
      productGoal: '保存高光时刻，并把其生命价值延续到行动。',
      promptId: RealisticPositivityOsPromptConfig.sceneSavoringPeakId,
      fields: <RpoGuidedFieldSpec>[
        RpoGuidedFieldSpec(id: 'moment', label: '积极/高峰体验发生了什么？', hint: '例如：一次勇敢表达、一段深度连接', minLines: 2, isRequired: true),
        RpoGuidedFieldSpec(id: 'sensory', label: '画面、声音、光线、人物', hint: '请具体描述当时场景', minLines: 2),
        RpoGuidedFieldSpec(id: 'body', label: '身体感受', hint: '例如：胸口打开、轻松、有力量'),
        RpoGuidedFieldSpec(id: 'value', label: '这个体验体现了什么生命价值？', hint: '例如：勇气、自由、连接、创造'),
        RpoGuidedFieldSpec(id: 'act', label: '本周如何延续一个小版本？', hint: '把高峰体验行动化'),
      ],
      coverage: <String>['好事重温', '高峰体验卡', 'PPEO 行动化', '积极经验库'],
      safeguards: <String>['不把快乐拆成大道理', '重点是重温和延续'],
    ),
    RpoGuidedModuleSpec(
      id: 'change_lab',
      title: 'Change Lab 改变实验室',
      subtitle: '改变失败时，先找旧模式绑定的珍贵价值。',
      courseValue: '人不是不想改，而是常把痛苦模式和珍贵价值绑在一起。',
      productGoal: '保留价值，放下痛苦形式，生成更健康表达。',
      promptId: RealisticPositivityOsPromptConfig.sceneChangeLabId,
      fields: <RpoGuidedFieldSpec>[
        RpoGuidedFieldSpec(id: 'old_pattern', label: '我想改变的旧模式', hint: '例如：完美主义、焦虑、内疚、讨好、挑错', isRequired: true),
        RpoGuidedFieldSpec(id: 'failed_attempts', label: '过去我怎么尝试改变？为什么失败？', hint: '写出重复失败的地方', minLines: 2),
        RpoGuidedFieldSpec(id: 'protected_value', label: '这个旧模式可能保护了什么珍贵价值？', hint: '例如：雄心、责任、善良、现实感、连接'),
        RpoGuidedFieldSpec(id: 'fear_loss', label: '如果改变成功，我害怕失去什么？', hint: '这是隐藏阻抗的入口'),
        RpoGuidedFieldSpec(id: 'healthy_expression', label: '我想保留价值的新表达', hint: '例如：高标准 + 允许粗糙第一版', minLines: 2),
      ],
      coverage: <String>['改变目标定义', '我真的想改变吗检测', '价值绑定拆解器', '渐进/急性改变入口'],
    ),
    RpoGuidedModuleSpec(
      id: 'abc_change',
      title: 'ABC Change 改变计划',
      subtitle: '从 Affect、Behavior、Cognition 三层设计 7/14 天实验。',
      courseValue: '真正改变不是只想明白，而是情绪、行为、认知同时介入。',
      productGoal: '把抽象目标转成可执行、可复盘的小实验。',
      promptId: RealisticPositivityOsPromptConfig.sceneAbcChangeId,
      fields: <RpoGuidedFieldSpec>[
        RpoGuidedFieldSpec(id: 'goal', label: '具体改变目标', hint: '不要写“变好”，写具体场景中的新行为', isRequired: true),
        RpoGuidedFieldSpec(id: 'affect', label: 'Affect：需要允许/调节/激活的情绪', hint: '例如：允许害怕失败，不把害怕当停止信号'),
        RpoGuidedFieldSpec(id: 'behavior', label: 'Behavior：每天最小行为', hint: '例如：每天启动 5 分钟'),
        RpoGuidedFieldSpec(id: 'cognition', label: 'Cognition：需要替换的解释/信念', hint: '例如：从“必须完美”到“先有粗糙版本”'),
        RpoGuidedFieldSpec(id: 'cycle', label: '实验周期与复盘频率', hint: '例如：7 天，每天晚上一句复盘'),
      ],
      coverage: <String>['Affect', 'Behavior', 'Cognition', '7/14 天小实验', '渐进改变复盘'],
    ),
    RpoGuidedModuleSpec(
      id: 'behavior_first',
      title: 'Behavior First 行为优先',
      subtitle: '不等动力，先做 2–10 分钟行为，让行为反向塑造态度。',
      courseValue: 'We first make our habits, then our habits make us. 行为会改变身份。',
      productGoal: '低动力时避免说教，直接生成启动行为和新身份证据。',
      promptId: RealisticPositivityOsPromptConfig.sceneBehaviorFirstId,
      fields: <RpoGuidedFieldSpec>[
        RpoGuidedFieldSpec(id: 'blocked_task', label: '我卡住的任务', hint: '例如：写论文、运动、整理房间、发消息', isRequired: true),
        RpoGuidedFieldSpec(id: 'feeling', label: '启动前的感觉', hint: '例如：抗拒、害怕、疲惫、麻木'),
        RpoGuidedFieldSpec(id: 'minimum_action', label: '我愿意尝试的 2 分钟动作', hint: '例如：打开文档写一句话 / 穿鞋走到楼下'),
        RpoGuidedFieldSpec(id: 'identity_evidence', label: '完成后希望沉淀成什么新身份证据？', hint: '例如：我是能在低动力时启动的人'),
      ],
      coverage: <String>['2 分钟启动器', '身体反馈练习', '新身份证据', '低动力模式'],
    ),
    RpoGuidedModuleSpec(
      id: 'stretch_zone',
      title: 'Stretch Zone 成长挑战',
      subtitle: '区分 comfort、stretch、panic，设计刚刚好的挑战阶梯。',
      courseValue: '成长通常发生在可承受的不适，而不是舒适或崩溃。',
      productGoal: '帮助用户增加 5% 挑战，并在 panic 时降级和求助。',
      promptId: RealisticPositivityOsPromptConfig.sceneStretchZoneId,
      fields: <RpoGuidedFieldSpec>[
        RpoGuidedFieldSpec(id: 'growth_area', label: '想成长的领域', hint: '例如：会议表达、边界、运动、学习启动', isRequired: true),
        RpoGuidedFieldSpec(id: 'comfort', label: 'Comfort Zone 版本', hint: '现在最熟悉、最安全但不成长的做法'),
        RpoGuidedFieldSpec(id: 'stretch', label: 'Stretch Zone 版本', hint: '有点紧张但可承受的下一步'),
        RpoGuidedFieldSpec(id: 'panic_signs', label: 'Panic Zone 信号', hint: '出现什么就说明挑战过强，需要降级？'),
        RpoGuidedFieldSpec(id: 'support', label: '支持系统', hint: '谁可以陪伴、提醒或保护我？'),
      ],
      coverage: <String>['三圈检测', '挑战阶梯', 'Panic Zone 保护', '支持系统'],
      safeguards: <String>['panic 时不继续挑战', '需要支持时回到真实关系'],
    ),

    RpoGuidedModuleSpec(
      id: 'crisis',
      title: 'Safety Support 安全支持',
      subtitle: '当出现自伤、失控、家暴、严重成瘾或即时危险时，停止普通训练，优先安全和真实支持。',
      courseValue: 'Permission to be human 的安全边界：痛苦需要被承认，但危机时不做积极重构或成长挑战。',
      productGoal: '把用户从孤立承受转向联系真实支持者、专业支持或当地紧急服务。',
      promptId: RealisticPositivityOsPromptConfig.sceneSafetyId,
      fields: <RpoGuidedFieldSpec>[
        RpoGuidedFieldSpec(id: 'danger', label: '当前最危险/最失控的部分', hint: '例如：想伤害自己、被威胁、惊恐失控、无法停止某行为', minLines: 2, isRequired: true),
        RpoGuidedFieldSpec(id: 'immediate_risk', label: '是否有即时危险？', hint: '例如：身边有工具/对方在场/我无法保证安全'),
        RpoGuidedFieldSpec(id: 'safe_person', label: '现在能联系的真实支持者', hint: '例如：朋友、家人、同事、咨询师、紧急联系人'),
        RpoGuidedFieldSpec(id: 'safe_place', label: '可以让自己更安全的地点', hint: '例如：离开危险房间、去公共场所、找人陪伴'),
        RpoGuidedFieldSpec(id: 'next_safety_action', label: '接下来 2 分钟安全行动', hint: '例如：发消息给某人、拨打当地紧急服务、远离危险物'),
      ],
      coverage: <String>['高风险识别', '停止积极重构', '联系真实支持', '即时危险建议紧急服务', '不做 Stretch 挑战'],
      safeguards: <String>['危机时不做感恩练习', '危机时不分析价值绑定', '优先安全与专业支持'],
    ),
    RpoGuidedModuleSpec(
      id: 'weekly_integration',
      title: 'Weekly Integration 每周整合',
      subtitle: '总结人格训练证据，而不是打卡次数。',
      courseValue: '改变是长期人格雕刻，不是单次 insight。',
      productGoal: '把一周记录整合为新身份、趋势和下周一个核心实验。',
      promptId: RealisticPositivityOsPromptConfig.sceneWeeklyIntegrationId,
      fields: <RpoGuidedFieldSpec>[
        RpoGuidedFieldSpec(id: 'reality', label: '本周我更真实看见的一件事', hint: '困难与资源都是什么？', minLines: 2),
        RpoGuidedFieldSpec(id: 'gratitude', label: '本周一次真实感恩', hint: '不是机械清单，而是具体体验'),
        RpoGuidedFieldSpec(id: 'emotion', label: '本周我允许过的一种情绪', hint: '我如何没有压抑或强迫积极？'),
        RpoGuidedFieldSpec(id: 'action', label: '本周一个小行动', hint: '低动力下也做了什么？'),
        RpoGuidedFieldSpec(id: 'relationship', label: '本周一次关系表达/求助', hint: '感谢、求助、修复或边界'),
        RpoGuidedFieldSpec(id: 'binding_stretch_peak', label: '价值绑定 / Stretch / 高峰体验证据', hint: '至少写一个', minLines: 2),
        RpoGuidedFieldSpec(id: 'next_experiment', label: '下周只做一个核心实验', hint: '不要给太多目标', isRequired: true),
      ],
      coverage: <String>['一周价值雷达', '本周人格证据', '下周一个实验', '长期趋势'],
    ),
  ];

  @override
  State<RealisticPositivityOsWorkbenchPage> createState() => _RealisticPositivityOsWorkbenchPageState();
}

class _RealisticPositivityOsWorkbenchPageState extends State<RealisticPositivityOsWorkbenchPage> {
  final RealisticPositivityOsDao _dao = RealisticPositivityOsDao();
  final RealisticPositivityOsAiService _ai = RealisticPositivityOsAiService();
  final Map<String, TextEditingController> _controllers = <String, TextEditingController>{};
  late String _sceneType;
  RpoProfile _profile = const RpoProfile();
  RpoPracticeRecord? _latest;
  bool _loading = true;
  bool _generating = false;

  RpoGuidedModuleSpec get _spec => RealisticPositivityOsWorkbenchPage.specs.firstWhere(
        (e) => e.id == _sceneType,
        orElse: () => RealisticPositivityOsWorkbenchPage.specs[1],
      );

  @override
  void initState() {
    super.initState();
    _sceneType = RealisticPositivityOsWorkbenchPage.specs.any((e) => e.id == widget.initialSceneType) ? widget.initialSceneType : 'reality_lens';
    _profile = widget.profile;
    _ensureControllers();
    _load();
  }

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await _dao.ensureTables();
      final profile = await _dao.loadProfile();
      final records = await _dao.listRecords(limit: 1, sceneType: _sceneType == 'onboarding' ? null : _sceneType);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _latest = records.isNotEmpty ? records.first : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('加载深度训练工作台失败：$e');
    }
  }

  void _ensureControllers() {
    for (final spec in RealisticPositivityOsWorkbenchPage.specs) {
      for (final field in spec.fields) {
        final key = '${spec.id}.${field.id}';
        _controllers.putIfAbsent(key, () => TextEditingController());
      }
    }
  }

  void _switchScene(String scene) {
    setState(() {
      _sceneType = scene;
      _latest = null;
    });
    _load();
  }

  TextEditingController _ctrl(RpoGuidedFieldSpec field) => _controllers['${_spec.id}.${field.id}']!;

  Future<void> _generate() async {
    final missing = _spec.fields.where((f) => f.isRequired && _ctrl(f).text.trim().isEmpty).toList(growable: false);
    if (missing.isNotEmpty) {
      _toast('请先填写：${missing.map((e) => e.label).join('、')}');
      return;
    }
    final input = _composeInput();
    setState(() => _generating = true);
    try {
      final result = await _ai.generate(userInput: input, sceneType: _spec.id == 'onboarding' ? 'onboarding' : _spec.id, profile: _profile);
      await _dao.upsertRecord(result.record);
      await _dao.materializeRecordAssets(result.record);
      await _dao.applyRecordToProfile(result.record);
      await _load();
      _toast(result.usedAi ? 'AI 已生成并沉淀训练结果' : 'AI 未可用，已使用本地价值引擎生成并沉淀');
    } catch (e) {
      _toast('生成失败：$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  String _composeInput() {
    final lines = <String>[
      '【独立模块】真实积极行动系统 Realistic Positivity OS',
      '【课程背景】《哈佛积极心理学》Lecture 9–10',
      '【子模块】${_spec.title}',
      '【对应核心价值】${_spec.courseValue}',
      '【产品目标】${_spec.productGoal}',
      '',
      '【用户填写】',
    ];
    for (final field in _spec.fields) {
      final value = _ctrl(field).text.trim();
      if (value.isEmpty) continue;
      lines.add('${field.label}：$value');
    }
    lines.add('');
    lines.add('【请输出】请根据该子模块场景生成行动卡，必须包含状态诊断、旧问题/更好问题、ABC 或对应练习、最小行动、复盘方式、新身份证据，并沉淀可进入人格地图的资产。');
    return lines.join('\n');
  }

  Future<void> _completeLatestAction() async {
    final item = _latest;
    if (item == null) {
      _toast('暂无行动卡。');
      return;
    }
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('完成本次最小行动'),
        content: TextField(
          controller: ctrl,
          minLines: 4,
          maxLines: 8,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: '行动复盘',
            hintText: item.reflectionQuestion.isEmpty ? '行动后，我看见了什么新的现实或身份证据？' : item.reflectionQuestion,
            alignLabelWithHint: true,
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('保存完成')),
        ],
      ),
    );
    ctrl.dispose();
    if (text == null) return;
    await _dao.addActionEvidence(
      sourceRecordId: item.id,
      actionTitle: item.microAction.title.isEmpty ? '完成一次 ${_spec.title} 行动' : item.microAction.title,
      status: 'done',
      evidenceText: item.identityEvidence.isEmpty ? '完成一次真实积极行动' : item.identityEvidence,
      reflection: text,
    );
    await _dao.applyRecordToProfile(item);
    await _load();
    _toast('已完成行动闭环，并更新人格地图。');
  }

  void _openPrompt() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AiPromptSettingsPage(
        initialModuleId: RealisticPositivityOsPromptConfig.moduleId,
        initialPromptId: _spec.promptId,
      ),
    ));
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('RPO 深度训练工作台', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: <Widget>[
          IconButton(onPressed: _openPrompt, icon: const Icon(Icons.tune_outlined), tooltip: '配置当前子模块 Prompt'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: <Widget>[
          _moduleSelector(),
          const SizedBox(height: 12),
          _moduleValueCard(),
          const SizedBox(height: 12),
          _guidedFormCard(),
          const SizedBox(height: 12),
          _coverageCard(),
          if (_latest != null) ...<Widget>[
            const SizedBox(height: 12),
            _resultCard(_latest!),
          ],
        ],
      ),
    );
  }

  Widget _moduleSelector() {
    return _card(
      title: '选择一个专用子模块',
      subtitle: '每个子模块都有独立表单、独立场景 Prompt、独立课程价值说明，不再只依赖通用输入框。',
      child: DropdownButtonFormField<String>(
        value: _sceneType,
        isExpanded: true,
        decoration: const InputDecoration(labelText: '子模块', border: OutlineInputBorder()),
        items: RealisticPositivityOsWorkbenchPage.specs
            .map((e) => DropdownMenuItem<String>(value: e.id, child: Text(e.title)))
            .toList(growable: false),
        onChanged: (v) => _switchScene(v ?? 'reality_lens'),
      ),
    );
  }

  Widget _moduleValueCard() {
    return _card(
      title: _spec.title,
      subtitle: _spec.subtitle,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        _info('课程价值', _spec.courseValue, Icons.school_outlined),
        _info('产品目标', _spec.productGoal, Icons.flag_outlined),
        if (_spec.safeguards.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          const Text('安全/价值边界', style: TextStyle(fontWeight: FontWeight.w900)),
          for (final s in _spec.safeguards) _bullet(s),
        ],
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
          ActionChip(label: const Text('配置当前 Prompt'), onPressed: _openPrompt),
          ActionChip(label: const Text('填入示例'), onPressed: _fillExample),
          ActionChip(label: const Text('清空表单'), onPressed: _clearCurrentForm),
        ]),
      ]),
    );
  }

  Widget _guidedFormCard() {
    return _card(
      title: '专用训练表单',
      subtitle: '这些字段会被整理成带课程背景的结构化输入，再交给 AI 三层 Prompt 生成行动卡。',
      child: Column(children: <Widget>[
        for (final field in _spec.fields)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: _ctrl(field),
              minLines: field.minLines,
              maxLines: field.maxLines,
              decoration: InputDecoration(
                labelText: field.isRequired ? '${field.label} *' : field.label,
                hintText: field.hint,
                alignLabelWithHint: field.minLines > 1,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _generating ? null : _generate,
            icon: _generating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
            label: Text(_generating ? '正在生成专用行动卡……' : '生成并沉淀专用行动卡'),
          ),
        ),
      ]),
    );
  }

  Widget _coverageCard() {
    return _card(
      title: '本子模块覆盖的设计功能',
      subtitle: '用于校验它不是“一个通用聊天框”，而是真正对应产品设计方案的独立功能单元。',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        for (final item in _spec.coverage) _bullet(item),
      ]),
    );
  }

  Widget _resultCard(RpoPracticeRecord item) {
    return _card(
      title: '最新专用行动卡',
      subtitle: '${item.title} · ${item.riskLevel}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        _info('真实处境', item.realSituation, Icons.visibility_outlined),
        _info('旧问题', item.oldQuestion, Icons.help_outline),
        _info('更好的问题', item.betterQuestion, Icons.lightbulb_outline),
        _info('干预摘要', item.interventionSummary, Icons.psychology_alt_outlined),
        if (item.valueBinding.isNotEmpty) _binding(item.valueBinding),
        if (item.abcPlan.affect.isNotEmpty || item.abcPlan.behavior.isNotEmpty || item.abcPlan.cognition.isNotEmpty) _abc(item.abcPlan),
        _info('最小行动', '${item.microAction.title} · ${item.microAction.durationMinutes} 分钟', Icons.play_circle_outline),
        for (final step in item.microAction.steps) _bullet(step),
        _info('复盘问题', item.reflectionQuestion, Icons.rate_review_outlined),
        _info('新身份证据', item.identityEvidence, Icons.verified_outlined),
        if (item.relationshipAction.isNotEmpty) _info('关系行动', item.relationshipAction, Icons.people_alt_outlined),
        if (item.savoringOrMeaningMaking.isNotEmpty) _info('重温/整合', item.savoringOrMeaningMaking, Icons.auto_stories_outlined),
        if (item.safetyNote.isNotEmpty) _quote('安全提示', item.safetyNote, color: const Color(0xFFFFF1F2)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
          FilledButton.icon(onPressed: _completeLatestAction, icon: const Icon(Icons.check_circle_outline), label: const Text('完成行动并复盘')),
          OutlinedButton.icon(onPressed: () async { await _dao.applyRecordToProfile(item); await _load(); _toast('已沉淀到人格地图。'); }, icon: const Icon(Icons.archive_outlined), label: const Text('再次沉淀到人格地图')),
        ]),
      ]),
    );
  }

  void _fillExample() {
    final examples = <String, Map<String, String>>{
      'reality_lens': <String, String>{'event': '今天会议上我提出的想法没有被采纳。', 'emotion': '失落、羞耻、担心自己不够好', 'interpretation': '我把它解释成自己没有价值。', 'resources': '我仍然准备了材料，也有同事后来私下说其中一点有启发。', 'control_one_percent': '把方案改成一页纸，明天发给一个同事请他反馈。'},
      'question_reframing': <String, String>{'old_question': '我为什么这么废？', 'scene': '开始写作前', 'cost': '越问越羞耻，最后什么都不做。', 'new_direction': '我想转向“我现在卡在哪一步，能不能只写一句话？”'},
      'gratitude': <String, String>{'object': '今天能洗热水澡', 'value': '它让我从疲惫里恢复一点身体感。', 'sensory': '热水落在肩膀上，身体慢慢松下来。', 'absence': '如果没有它，我会更难从压力中恢复。', 'expression': '停留 20 秒认真感受，不急着刷手机。'},
      'relational_gratitude': <String, String>{'person': '大学时的一位老师', 'specific_act': '他在我最低落时认真看了我的文章，还鼓励我继续写。', 'impact_then': '当时让我觉得自己没有完全失败。', 'impact_later': '后来我继续学习和写作。', 'tone_boundary': '真诚、简短、温暖，不夸张。'},
      'emotional_processing': <String, String>{'emotion': '焦虑和疲惫', 'trigger': '任务堆积，我又没有按计划推进。', 'body': '胸口紧，肩膀硬。', 'need': '我需要先降低压迫感，然后启动一个小动作。', 'support': '可以给朋友发一句“我今天有点卡住”。'},
      'meaning_making': <String, String>{'event': '一次关系冲突后，对方说了让我很受伤的话。', 'feelings': '委屈、愤怒、羞耻', 'pain_point': '我觉得自己没有被尊重。', 'rumination': '我一直想“是不是我太差才会被这样对待”。', 'support_repair': '先写下来，再找朋友聊，之后考虑表达边界。'},
      'savoring_peak': <String, String>{'moment': '今天我第一次在会议上清楚表达了自己的观点。', 'sensory': '我听见自己声音有点抖，但大家在听。', 'body': '胸口打开，手有点紧，但很有力量。', 'value': '勇气、真实、参与', 'act': '下周再主动表达一个小观点。'},
      'change_lab': <String, String>{'old_pattern': '完美主义导致拖延', 'failed_attempts': '我一直逼自己更自律，但越逼越害怕开始。', 'protected_value': '它保护了我的雄心和高标准。', 'fear_loss': '我害怕不完美就说明自己平庸。', 'healthy_expression': '保留高标准，但允许粗糙第一版。'},
      'abc_change': <String, String>{'goal': '每天开始写作 5 分钟', 'affect': '允许害怕写不好，不把害怕当停止信号。', 'behavior': '每天只打开文档写 3 句话。', 'cognition': '从“必须写好”改成“先创造可修改版本”。', 'cycle': '7 天，每晚一句复盘。'},
      'behavior_first': <String, String>{'blocked_task': '开始学习英语', 'feeling': '没有动力，觉得很烦。', 'minimum_action': '打开材料，只读第一段。', 'identity_evidence': '我是能在低动力时启动两分钟的人。'},
      'stretch_zone': <String, String>{'growth_area': '会议表达', 'comfort': '完全不发言，只听别人说。', 'stretch': '提前写一句观点，在会议上说出来。', 'panic_signs': '心跳过快、脑子空白、会后无法恢复。', 'support': '会前和一个同事预演。'},
      'weekly_integration': <String, String>{'reality': '我看见自己拖延背后有害怕，但也有能力启动 5 分钟。', 'gratitude': '感谢朋友在我低落时陪我散步。', 'emotion': '我允许自己焦虑，没有马上骂自己。', 'action': '我写了一个粗糙第一版。', 'relationship': '我向朋友表达了感谢。', 'binding_stretch_peak': '我识别到完美主义绑定雄心；也在会议表达上进入了一点 stretch。', 'next_experiment': '下周只练习“粗糙第一版”。'},
      'crisis': <String, String>{'danger': '我现在情绪非常失控，担心自己会做出伤害自己的事。', 'immediate_risk': '我不确定自己能否独自安全待着。', 'safe_person': '可以立刻联系朋友A或家人B。', 'safe_place': '离开房间，去客厅或楼下公共区域。', 'next_safety_action': '现在给朋友A发“我现在很危险，需要你陪我一下”。'},
      'onboarding': <String, String>{'current_trouble': '我经常因为完美主义拖延。', 'common_emotions': '焦虑、羞耻、疲惫', 'old_questions': '我为什么这么废？我是不是永远改不了？', 'bound_values': '完美主义保护雄心，焦虑保护责任感。', 'support_people': '朋友A、导师B', 'stretch_area': '表达、写作启动、边界'},
    };
    final data = examples[_spec.id] ?? examples['reality_lens']!;
    for (final field in _spec.fields) {
      _ctrl(field).text = data[field.id] ?? '';
    }
    setState(() {});
  }

  void _clearCurrentForm() {
    for (final field in _spec.fields) {
      _ctrl(field).clear();
    }
    setState(() {});
  }

  Widget _card({required String title, required String subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        if (subtitle.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), height: 1.35)),
        ],
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  Widget _info(String title, String content, IconData icon) {
    if (content.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Icon(icon, size: 20, color: const Color(0xFF4F46E5)),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(content, style: const TextStyle(height: 1.42)),
        ])),
      ]),
    );
  }

  Widget _quote(String title, String content, {Color color = const Color(0xFFF8FAFC)}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF64748B))),
        const SizedBox(height: 4),
        Text(content, style: const TextStyle(height: 1.42)),
      ]),
    );
  }

  Widget _bullet(String text) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        const Text('•  '),
        Expanded(child: Text(text, style: const TextStyle(height: 1.38))),
      ]),
    );
  }

  Widget _abc(RpoAbcPlan abc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF0FDFA), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        const Text('ABC 改变模型', style: TextStyle(fontWeight: FontWeight.w900)),
        _bullet('Affect 情绪：${abc.affect}'),
        _bullet('Behavior 行为：${abc.behavior}'),
        _bullet('Cognition 认知：${abc.cognition}'),
      ]),
    );
  }

  Widget _binding(RpoValueBinding binding) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        const Text('价值绑定拆解', style: TextStyle(fontWeight: FontWeight.w900)),
        _bullet('你不需要消灭：${binding.oldPattern}'),
        _bullet('你真正想保留：${binding.boundValue}'),
        _bullet('需要放下：${binding.painfulForm}'),
        _bullet('健康表达：${binding.healthyExpression}'),
      ]),
    );
  }
}
