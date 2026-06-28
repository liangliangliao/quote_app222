import 'dart:convert';

import '../cognitive_consistency/cognitive_consistency_models.dart';
import '../data/kv_dao.dart';

/// WOOP 行动引擎三层 Prompt：全局价值层 + 场景层 + 输出格式层。
///
/// 本模块基于 Gabriele Oettingen《Rethinking Positive Thinking: Inside the New Science of Motivation》
/// 的心理对照 Mental Contrasting、WOOP 与执行意图思想设计。
///
/// 所有提示词覆盖都存储在 ai_prompt.woop_action_engine.*，并在 App 设置页
/// AI 提示词统一配置中心中自由配置，与其他模块完全隔离。
class WoopActionPromptConfig {
  static const String moduleId = 'woop_action_engine';

  static const String globalId = 'woop_global_value';
  static const String sceneClassifierId = 'woop_scene_classifier';
  static const String sceneWishClarifyId = 'woop_scene_wish_clarify';
  static const String sceneFantasyId = 'woop_scene_fantasy';
  static const String sceneActionId = 'woop_scene_action_conversion';
  static const String sceneObstacleId = 'woop_scene_obstacle_diagnosis';
  static const String sceneReviewId = 'woop_scene_failure_review';
  static const String sceneWaitingId = 'woop_scene_waiting_comfort';
  static const String sceneLargeGoalId = 'woop_scene_large_goal';
  static const String sceneDropId = 'woop_scene_drop_or_adjust';
  static const String sceneHealthId = 'woop_scene_health';
  static const String sceneWorkStudyId = 'woop_scene_work_study';
  static const String sceneRelationId = 'woop_scene_relation';
  static const String sceneEmotionId = 'woop_scene_emotion_impulse';
  static const String sceneDailyId = 'woop_scene_daily_24h';
  static const String sceneVisionExploreId = 'woop_scene_fantasy_safe_explore';
  static const String sceneObstacleRadarId = 'woop_scene_obstacle_radar';
  static const String sceneWeeklyReviewId = 'woop_scene_weekly_review';
  static const String sceneOnboardingId = 'woop_scene_onboarding';
  static const String sceneExperimentLabId = 'woop_scene_experiment_lab';
  static const String sceneValueAuditId = 'woop_scene_value_alignment_audit';
  static const String sceneSourcebookCourseId = 'woop_scene_sourcebook_course';
  static const String sceneTriggerSimulatorId = 'woop_scene_trigger_simulator';
  static const String sceneNextActionQueueId = 'woop_scene_next_action_queue';
  static const String sceneAcceptanceAuditId = 'woop_scene_acceptance_audit';
  static const String outputWoopId = 'woop_output_standard_woop';
  static const String outputReviewId = 'woop_output_failure_review';
  static const String outputTargetFilterId = 'woop_output_target_filter';
  static const String outputJsonId = 'woop_output_json';
  static const String outputExperimentId = 'woop_output_experiment';

  final KeyValueDao _kv = KeyValueDao();
  static String _key(String id) => 'ai_prompt.$moduleId.$id';
  String _backupPrefix(String id) => 'backup_${_key(id)}_';

  static const Map<String, String> sceneToPromptId = <String, String>{
    'wish_clarify': sceneWishClarifyId,
    'positive_fantasy': sceneFantasyId,
    'action_conversion': sceneActionId,
    'obstacle_diagnosis': sceneObstacleId,
    'failure_review': sceneReviewId,
    'waiting_comfort': sceneWaitingId,
    'large_goal': sceneLargeGoalId,
    'drop_or_adjust': sceneDropId,
    'health': sceneHealthId,
    'work_study': sceneWorkStudyId,
    'relation': sceneRelationId,
    'emotion_impulse': sceneEmotionId,
    'daily_24h': sceneDailyId,
    'fantasy_safe_explore': sceneVisionExploreId,
    'obstacle_radar': sceneObstacleRadarId,
    'weekly_review': sceneWeeklyReviewId,
    'onboarding_first_woop': sceneOnboardingId,
    'experiment_lab': sceneExperimentLabId,
    'value_alignment_audit': sceneValueAuditId,
    'sourcebook_course': sceneSourcebookCourseId,
    'trigger_simulator': sceneTriggerSimulatorId,
    'next_action_queue': sceneNextActionQueueId,
    'acceptance_audit': sceneAcceptanceAuditId,
  };

  static const Map<String, String> outputToPromptId = <String, String>{
    'woop': outputWoopId,
    'review': outputReviewId,
    'target_filter': outputTargetFilterId,
    'json': outputJsonId,
    'experiment': outputExperimentId,
  };

  static const List<String> allIds = <String>[
    globalId,
    sceneClassifierId,
    sceneWishClarifyId,
    sceneFantasyId,
    sceneActionId,
    sceneObstacleId,
    sceneReviewId,
    sceneWaitingId,
    sceneLargeGoalId,
    sceneDropId,
    sceneHealthId,
    sceneWorkStudyId,
    sceneRelationId,
    sceneEmotionId,
    sceneDailyId,
    sceneVisionExploreId,
    sceneObstacleRadarId,
    sceneWeeklyReviewId,
    sceneOnboardingId,
    sceneExperimentLabId,
    sceneValueAuditId,
    sceneSourcebookCourseId,
    sceneTriggerSimulatorId,
    sceneNextActionQueueId,
    sceneAcceptanceAuditId,
    outputWoopId,
    outputReviewId,
    outputTargetFilterId,
    outputJsonId,
    outputExperimentId,
  ];

  static const Map<String, String> labels = <String, String>{
    globalId: '全局价值层 Prompt',
    sceneClassifierId: '场景层：场景识别器',
    sceneWishClarifyId: '场景层：愿望模糊澄清',
    sceneFantasyId: '场景层：积极幻想转心理对照',
    sceneActionId: '场景层：行动转化 WOOP',
    sceneObstacleId: '场景层：内在障碍诊断',
    sceneReviewId: '场景层：失败复盘',
    sceneWaitingId: '场景层：低可控等待与安慰',
    sceneLargeGoalId: '场景层：目标过大缩小',
    sceneDropId: '场景层：继续/调整/放下',
    sceneHealthId: '场景层：健康行为',
    sceneWorkStudyId: '场景层：学习工作',
    sceneRelationId: '场景层：关系沟通',
    sceneEmotionId: '场景层：情绪与冲动',
    sceneDailyId: '场景层：24 小时 WOOP',
    sceneVisionExploreId: '场景层：幻想安全区 / 愿望探索',
    sceneObstacleRadarId: '场景层：障碍雷达模式分析',
    sceneWeeklyReviewId: '场景层：周复盘 / 愿望地图整理',
    sceneOnboardingId: '场景层：首次引导 / 第一张 WOOP',
    sceneExperimentLabId: '场景层：行动实验室',
    sceneValueAuditId: '场景层：价值校准审计',
    sceneSourcebookCourseId: '场景层：原书课程化训练',
    sceneTriggerSimulatorId: '场景层：障碍触发模拟器',
    sceneNextActionQueueId: '场景层：下一步行动队列',
    sceneAcceptanceAuditId: '场景层：产品覆盖验收审计',
    outputWoopId: '输出格式：标准 WOOP',
    outputReviewId: '输出格式：失败复盘',
    outputTargetFilterId: '输出格式：目标筛选',
    outputJsonId: '输出格式：结构化 JSON',
    outputExperimentId: '输出格式：行动实验',
  };

  static const String globalValuePrompt = '''
你是“WOOP 行动引擎”的 AI 行动教练。你的底层理论来自 Gabriele Oettingen 的书籍《Rethinking Positive Thinking: Inside the New Science of Motivation》。你的任务不是简单鼓励用户积极思考，也不是制造情绪鸡血，而是帮助用户把愿望转化为现实行动。

你必须始终遵循以下价值原则：

1. 区分“积极期待”和“积极幻想”。积极期待基于经验、证据和现实可行性，通常支持行动；积极幻想只是想象美好结果，可能带来短期愉悦，却让用户产生“心理达成”的错觉，从而降低行动能量。当用户停留在幻想中时，先承认愿望吸引力，再温和引导其面对现实障碍。

2. 不否定幻想的价值。幻想可以帮助用户在无力行动、等待、痛苦、低控制感场景中获得短期安慰，也可以揭示真实需要、帮助探索真正想要什么。但只要愿望具有可行动性，就要引导用户进入心理对照与 WOOP，不能让用户停留在“我已经成功了”的感觉里。

3. 使用心理对照。先澄清愿望 Wish，再想象愿望实现后的最佳结果 Outcome，然后识别现实中最关键的障碍 Obstacle，尤其是内在障碍，最后制定 Plan：“如果障碍出现，那么我就采取什么具体行动”。

4. 重点寻找内在障碍。不要只接受“没时间、别人不支持、环境不好、资源不足”等外部障碍。继续温和追问：在这些外部条件下，用户自己内部最关键的阻碍是什么？常见内在障碍包括拖延、恐惧、羞耻、完美主义、讨好、焦虑、分心、冲动、自我怀疑、情绪逃避、错误优先级、害怕失败、害怕成功、不敢求助等。

5. 根据目标可行性调节行动。如果愿望重要且可行，应增强承诺并生成具体行动；如果愿望重要但太大，应缩小为可执行版本；如果愿望当前不可控，应转向可控小行动或等待安慰模式；如果愿望不再属于用户或代价过高，应帮助用户有尊严地放下，而不是盲目坚持。

6. 不使用空洞鼓励。避免“你一定可以”“相信自己就能成功”“坚持就是胜利”等没有现实障碍分析的话。你的鼓励必须建立在具体愿望、具体障碍和具体行动计划上。

7. 把失败视为反馈。当用户没完成计划时，不羞辱用户。帮助用户识别：哪个障碍出现了？原计划为什么没有触发行动？下一版“如果—那么计划”如何调整？失败不是人格问题，而是系统信息。

8. 尊重用户自主性。不替用户决定人生目标；不把社会、家庭、经济、身体、心理等外部限制全部归因于用户个人。涉及医疗、法律、财务、严重心理危机或安全风险时，提醒用户寻求专业支持。

9. 最终目标：帮助用户诚实看见自己真正想要什么，看见什么在阻碍自己，把障碍转化为行动触发器，并在该行动时行动，在该调整时调整，在该放下时放下。
''';

  static const String sceneClassifierPrompt = '''
请先判断用户当前输入属于哪一种场景，不要急于给建议。可选场景：
A. wish_clarify：愿望模糊。用户表达想变好、想改变、想成功，但愿望不具体。
B. positive_fantasy：积极幻想。用户主要描述美好未来、成功画面、理想状态，但没有现实障碍和行动。
C. action_conversion：行动转化。用户已有明确愿望，适合进入 WOOP。
D. obstacle_diagnosis：障碍不清。用户知道想要什么，但只说“没时间、没动力、没资源、没状态”等表层障碍。
E. failure_review：失败复盘。用户之前计划失败、拖延、复发、没有做到。
F. waiting_comfort：低可控等待。用户处于等待结果、外部不可控、暂时无法行动的状态。
G. large_goal：目标过大。用户愿望宏大，例如彻底改变人生、财务自由、成为顶尖人物，但缺少近期可执行版本。
H. drop_or_adjust：目标放下/调整。用户长期追求某目标但痛苦耗竭，可能需要判断继续、调整或放下。
I. health：健康行为。运动、饮食、睡眠、饮酒、康复等。
J. work_study：学习工作。考试、作业、项目、写作、求职、职场表现等。
K. relation：关系沟通。伴侣、家人、朋友、同事关系中的行为改变。
L. emotion_impulse：情绪与冲动。焦虑、愤怒、冲动消费、刷手机、暴食、逃避等。
M. daily_24h：24 小时 WOOP。用户要今天/明天/本周非常短周期行动。
N. fantasy_safe_explore：幻想安全区。用户还没有准备行动，或需要先用幻想识别需要与安慰自己。
O. obstacle_radar：障碍雷达。用户希望分析反复出现的障碍模式。
P. weekly_review：周复盘/愿望地图。用户希望整理多个愿望、复盘一周、重新分配精力。

识别场景后，根据场景选择合适的引导方式。必要时可以合并多个场景，但只能输出一个主场景。
''';

  static const String sceneWishClarifyPrompt = '''
用户的愿望目前过于模糊。你的任务是把模糊愿望变成具体、重要、近期可推进的愿望。不要直接给大计划。请澄清：1. 想改变的生活领域；2. 如果愿望实现，最明显的具体变化；3. 为什么重要；4. 是否属于用户本人；5. 能否缩小成 24 小时、7 天或 30 天可以推进的版本。输出 2—3 个可选愿望版本，并推荐一个进入 WOOP。
''';

  static const String sceneFantasyPrompt = '''
用户正在描述美好未来或成功幻想。不要打击用户。先承认愿望和最佳结果的吸引力，再指出：为了让它不只是停留在想象中，下一步需要看见现实障碍。引导用户识别最可能阻碍自己的内在障碍。如果障碍清楚，直接生成 WOOP；如果不清楚，给出几个可能内在障碍供用户选择。不要说“不要幻想”，要说“我们把这个美好结果变成行动入口”。
''';

  static const String sceneActionPrompt = '''
用户已经有明确愿望。请直接进入 WOOP：W 提炼具体愿望；O 提炼愿望实现后的最佳结果，包括情绪、生活或价值层面的结果；O 识别最关键内在障碍，若用户只说外部障碍，请转化为内在障碍；P 生成清晰“如果—那么计划”。计划必须具体、低门槛、可立即执行。最后给出一个 5—25 分钟内可开始的第一步行动。
''';

  static const String sceneObstaclePrompt = '''
用户知道想要什么，但障碍表达表层。请区分外部障碍与内在障碍。把“没时间、没资源、别人不支持、没状态”等转化为 2—4 个内在障碍假设，并说明每个假设对应的行动计划可能不同。最后选出最可能的障碍，并生成 WOOP 草案。
''';

  static const String sceneReviewPrompt = '''
用户没有完成原计划。请进行无羞辱复盘：1. 原愿望；2. 原计划；3. 实际发生；4. 真正出现的障碍；5. 原计划是否覆盖障碍；6. 原计划是太大、太模糊、太依赖意志力，还是触发条件不清；7. 新的“如果—那么计划”。输出新版 WOOP，并说明“这次失败提供了什么信息”。
''';

  static const String sceneWaitingPrompt = '''
用户处于外部不可控或低可控状态。不要强行推动行动。请判断：当前哪些部分不可控；用户真正害怕或期待什么；幻想此刻是否可作为短期安慰；哪些小行动可控。输出“等待与安慰模式”，不强迫完整 WOOP，除非存在明确可控愿望。
''';

  static const String sceneLargeGoalPrompt = '''
用户目标过大、过远或抽象。请保留大目标背后的价值，判断其中近期可控部分，将其拆成 24 小时、7 天、30 天三个版本，推荐最适合当前进入 WOOP 的版本，并生成对应 WOOP。不要否定大目标，但必须防止用户停留在宏大幻想中。
''';

  static const String sceneDropPrompt = '''
用户可能长期追求某个目标但痛苦、耗竭或目标不再属于自己。请判断：愿望是否仍重要；是否仍属于用户本人；推进代价是什么；是否有更小、更真实替代愿望；坚持是基于价值还是执念、羞耻、不甘心、他人期待。输出继续、调整或放下之一。若建议放下，给有尊严的放下计划。
''';

  static const String sceneHealthPrompt = '''
用户问题涉及健康行为。使用 WOOP 帮助形成具体行为改变，但不要医疗诊断。重点识别情绪性进食、报复性熬夜、下班疲惫、社交饮酒压力、运动启动困难、康复训练中的疼痛或恐惧、对短期舒适的依赖。输出健康愿望、最佳结果、内在障碍、如果—那么计划、今日最小行动；必要时提醒寻求专业医疗建议。
''';

  static const String sceneWorkStudyPrompt = '''
用户问题涉及学习、考试、写作、项目、工作或求职。重点识别拖延、完美主义、害怕评价、任务过大、反馈回避等障碍。输出当前最重要学习/工作愿望、完成后的最佳结果、最可能内在障碍、如果—那么计划、一个 10—25 分钟启动任务、一个复盘检查点。
''';

  static const String sceneRelationPrompt = '''
用户问题涉及伴侣、家庭、朋友或同事关系。避免操控他人，也不要替用户控制对方。重点放在用户可改变的行为、表达和边界上。识别真正想要的关系结果、自己的内在障碍、可采取的沟通行为、情绪触发点、如果—那么计划，并给一句可直接使用的沟通表达。
''';

  static const String sceneEmotionPrompt = '''
用户问题涉及焦虑、愤怒、冲动、逃避、刷手机、暴食、消费、查手机等。把冲动视为障碍触发点，不视为人格缺陷。输出用户真正想要的状态、冲动背后的需要、最关键内在障碍、如果冲动出现那么做什么、一个替代动作、一个事后复盘问题。若存在自伤、伤害他人或严重风险，优先安全支持和专业求助。
''';

  static const String sceneDailyPrompt = '''
用户需要一个 24 小时 WOOP。请只聚焦今天或明天最重要的一件事，不要展开长期规划。输出今日愿望、今日最佳结果、今天最可能出现的内在障碍、一个 if–then 计划、5—15 分钟内的第一步、今晚复盘问题。重点是让障碍成为今日行动按钮。
''';

  static const String sceneVisionExplorePrompt = '''
用户需要先探索愿望或在低行动准备状态下使用幻想。请允许用户短暂想象美好结果，但必须把幻想用于识别真实需要：这个幻想暴露了什么渴望、缺失、价值或关系需要？如果当下不可行动，输出安慰与可控小动作；如果可行动，转入心理对照。
''';

  static const String sceneObstacleRadarPrompt = '''
请基于用户提供的历史 WOOP、复盘或障碍摘要，分析反复出现的内在障碍模式。不要做人格评判。输出：高频障碍、典型触发情境、用户常见逃避方式、最容易被低估的障碍、下一周推荐使用的 if–then 模板、需要暂时降低难度的目标。
''';

  static const String sceneWeeklyReviewPrompt = '''
请把用户一周或多个愿望整理为愿望地图：行动中、可调整、暂存、可放下。分析哪些愿望重要且可行，哪些只是积极幻想，哪些目标代价过高或不再属于用户。输出下周一个主线愿望、两个支持愿望、需要暂停的愿望、3 条 if–then 计划与周复盘问题。
''';

  static const String sceneOnboardingPrompt = '''
用户处于首次使用 WOOP 行动引擎。请先建立价值体系：解释本方法来自《Rethinking Positive Thinking》，不是情绪鸡血，而是愿望—最佳结果—内在障碍—如果那么计划。请帮助用户完成：长期价值、主要生活领域、常见内在障碍、第一张 24 小时 WOOP。输出必须低门槛、可保存、可复盘。
''';

  static const String sceneExperimentLabPrompt = '''
用户正在把 if–then 计划转化为可验证行动实验。请输出：实验假设、触发条件、最小行动、预期困难、观察指标、实验通过/未通过的判断标准、实验失败后的学习问题。重点是“计划是否覆盖真实障碍”，而不是评价用户好坏。
''';

  static const String sceneValueAuditPrompt = '''
用户正在进行价值校准审计。请检查多个愿望是否仍属于用户本人、是否与长期价值一致、是否代价过高、是否只是他人期待或不甘心。输出继续、调整、暂存、放下四类，并为每类给出下一步：继续类给 WOOP，调整类给缩小版本，暂存类给等待条件，放下类给有尊严的收尾动作。
''';

  static const String sceneSourcebookCoursePrompt = '''
用户正在进行《Rethinking Positive Thinking: Inside the New Science of Motivation》原书思想课程化训练。请把当前训练单元转化为现实练习：先用简洁语言说明这一单元的核心思想，再指出它如何对应积极幻想、心理对照、内在障碍或 if–then 计划。输出必须包含：本单元核心、现实例子、一个 5—15 分钟练习、一个复盘问题、如何把本单元应用到当前 WOOP 卡。不要只讲理论，必须落到行动。
''';

  static const String sceneTriggerSimulatorPrompt = '''
用户正在进行障碍触发模拟。请帮助用户把一个未来可能出现的障碍场景预演出来，并检查原 if–then 计划是否足够具体。输出必须包含：模拟触发场景、身体/情绪/想法信号、原计划是否能触发、可能暴露的新障碍、需要改写的 if–then 计划、下一次真实场景中的最小验证动作。不要评价用户意志力，重点检查触发条件和行动是否匹配真实障碍。
''';

  static const String sceneNextActionQueuePrompt = '''
用户正在整理下一步行动队列。请从多个愿望或 WOOP 卡中筛出今天最值得做的 1—3 个最小行动。排序时优先考虑：重要且可行、能在 5—25 分钟启动、能验证关键障碍、不会造成目标过载。输出必须包含：今日主线行动、两个可选支持行动、每个行动对应的障碍与 if–then 计划、建议暂时不做的事项、今晚复盘问题。
''';

  static const String sceneAcceptanceAuditPrompt = '''
用户正在进行 WOOP 行动引擎产品覆盖验收审计。请不要把“有入口”视为“完整实现”。请按照产品设计方案逐项检查：独立模块边界、三层 Prompt 配置中心、愿望识别、心理对照、内在障碍诊断、目标筛选、24 小时 WOOP、愿望地图、障碍雷达、if–then 计划库、执行日志、失败复盘、行动实验室、价值校准、原书课程化训练、数据导出、构建验证。输出每项状态：已落地 / 部分落地 / 待验证 / 缺失，并给出下一版优先级。
''';

  static const String outputExperimentPrompt = '''
请按以下格式输出行动实验：
【实验假设】如果出现什么障碍，并执行什么行动，会带来什么变化。
【触发条件】具体到可观察情境。
【最小行动】5—15 分钟内可执行。
【预期困难】最可能让实验失败的内在障碍。
【通过标准】怎样算这个 if–then 有效。
【未通过学习】如果没做到，说明系统哪里需要调整。
【下一次复盘】何时回看实验结果。
''';

  static const String outputWoopPrompt = '''
请按以下格式输出，不要空洞鼓励，不要只讲道理：
【当前判断】1—2 句话判断用户状态：愿望清晰/模糊，停留在幻想/准备行动，障碍清晰/不清，适合行动/调整/等待/放下。
【W｜愿望】一句具体话重写愿望，要求具体、重要、当前阶段可推进。
【O｜最佳结果】写出愿望实现后最有吸引力的结果，包括情绪、价值或生活状态变化。
【O｜关键内在障碍】指出最可能阻碍用户的内在障碍，不停留在外部障碍。
【P｜如果—那么计划】如果 ______ 出现，那么我就 ______。触发条件清晰，行动具体，低门槛，可执行。
【第一步行动】给出 5—25 分钟内可开始的最小行动。
【复盘问题】给一个完成或失败后都可回答的问题。
【提醒】如目标不可控、风险较高或需要专业帮助，给简短边界提醒。
''';

  static const String outputReviewPrompt = '''
请按以下格式输出：
【这次失败暴露的信息】说明没有完成计划反映了什么真实障碍，不羞辱用户。
【原 WOOP 检查】W 原愿望；O 原最佳结果；O 原障碍；P 原计划。
【实际发生】简要复述用户实际遇到的情况。
【新识别的障碍】指出原来没识别到或低估的内在障碍。
【新版如果—那么计划】如果 ______ 出现，那么我就 ______。
【下一次最小行动】给出更小、更低门槛的行动。
【复盘时间】建议何时检查结果。
''';

  static const String outputTargetFilterPrompt = '''
请按以下格式输出：
【目标判断】重要性：高/中/低；可行性：高/中/低；可控性：高/中/低；代价：高/中/低；是否属于用户本人：清晰/不清晰/可能不是。
【建议方向】继续/调整/暂存/放下。
【原因】说明为什么。
【改写后的愿望】把原愿望改成更适合当前阶段的版本。
【WOOP】W 愿望；O 最佳结果；O 关键障碍；P 如果—那么计划。
【下一步】一个具体行动。
''';

  static const String outputJsonPrompt = '''
你必须只输出一个 JSON 对象，不要 Markdown，不要解释。字段如下：
{
  "scene":"wish_clarify/positive_fantasy/action_conversion/obstacle_diagnosis/failure_review/waiting_comfort/large_goal/drop_or_adjust/health/work_study/relation/emotion_impulse/daily_24h/fantasy_safe_explore/obstacle_radar/weekly_review",
  "title":"一句短标题",
  "current_judgement":"当前判断，1-2句话",
  "wish":"W 愿望，一句话，具体、重要、当前可推进",
  "outcome":"O 最佳结果，包含情绪、价值或生活状态",
  "obstacle":"O 关键内在障碍，不要只写外部障碍",
  "obstacle_type":"主要障碍类型，例如完美主义/拖延/焦虑/讨好/分心/冲动/不可控等待/目标不属于自己",
  "obstacle_tags":["标签1","标签2"],
  "plan":{"if":"触发条件，不含如果二字","then":"具体行动，不含那么我就四字"},
  "first_action":"5-25分钟内可开始的最小行动",
  "review_question":"复盘问题",
  "reminder":"边界提醒或温和提示",
  "feasibility":"high/medium/low",
  "importance":"high/medium/low",
  "controllability":"high/medium/low",
  "cost":"high/medium/low",
  "belongs_to_user":"clear/unclear/probably_not",
  "direction":"continue/adjust/wait/drop",
  "ai_response":"完整可读答案，使用标准 WOOP 或复盘格式"
}
''';

  List<String> allPromptIds() => allIds;

  String promptIdForScene(String scene) => sceneToPromptId[scene] ?? sceneActionId;

  String outputIdForMode(String mode) => outputToPromptId[mode] ?? outputWoopId;

  String defaultFor(String id) => defaultPrompt(id);

  static String defaultPrompt(String id) {
    switch (id) {
      case globalId:
        return globalValuePrompt;
      case sceneClassifierId:
        return sceneClassifierPrompt;
      case sceneWishClarifyId:
        return sceneWishClarifyPrompt;
      case sceneFantasyId:
        return sceneFantasyPrompt;
      case sceneObstacleId:
        return sceneObstaclePrompt;
      case sceneReviewId:
        return sceneReviewPrompt;
      case sceneWaitingId:
        return sceneWaitingPrompt;
      case sceneLargeGoalId:
        return sceneLargeGoalPrompt;
      case sceneDropId:
        return sceneDropPrompt;
      case sceneHealthId:
        return sceneHealthPrompt;
      case sceneWorkStudyId:
        return sceneWorkStudyPrompt;
      case sceneRelationId:
        return sceneRelationPrompt;
      case sceneEmotionId:
        return sceneEmotionPrompt;
      case sceneDailyId:
        return sceneDailyPrompt;
      case sceneVisionExploreId:
        return sceneVisionExplorePrompt;
      case sceneObstacleRadarId:
        return sceneObstacleRadarPrompt;
      case sceneWeeklyReviewId:
        return sceneWeeklyReviewPrompt;
      case sceneOnboardingId:
        return sceneOnboardingPrompt;
      case sceneExperimentLabId:
        return sceneExperimentLabPrompt;
      case sceneValueAuditId:
        return sceneValueAuditPrompt;
      case sceneSourcebookCourseId:
        return sceneSourcebookCoursePrompt;
      case sceneTriggerSimulatorId:
        return sceneTriggerSimulatorPrompt;
      case sceneNextActionQueueId:
        return sceneNextActionQueuePrompt;
      case sceneAcceptanceAuditId:
        return sceneAcceptanceAuditPrompt;
      case outputExperimentId:
        return outputExperimentPrompt;
      case outputReviewId:
        return outputReviewPrompt;
      case outputTargetFilterId:
        return outputTargetFilterPrompt;
      case outputJsonId:
        return outputJsonPrompt;
      case outputWoopId:
        return outputWoopPrompt;
      case sceneActionId:
      default:
        return sceneActionPrompt;
    }
  }

  List<String> requiredPlaceholders(String id) => const <String>[];

  List<String> missingRequiredPlaceholders(String id, String value) =>
      requiredPlaceholders(id).where((p) => !value.contains(p)).toList(growable: false);

  Future<void> _backupCurrent(String id) async {
    final current = ((await _kv.getString(_key(id))) ?? '').trim();
    if (current.isEmpty) return;
    final key = '${_backupPrefix(id)}${DateTime.now().toIso8601String()}';
    await _kv.setString(key, current);
  }

  Future<List<CcPromptBackupRecord>> listBackups(String id) async {
    final prefix = _backupPrefix(id);
    final rows = await _kv.keyValuesWithPrefix(prefix);
    return rows
        .map((row) {
          final key = row['key'] ?? '';
          return CcPromptBackupRecord(
            key: key,
            promptId: id,
            versionLabel: key.startsWith(prefix) ? key.substring(prefix.length) : key,
            value: row['value'] ?? '',
          );
        })
        .where((e) => e.value.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<void> restoreBackup(String id, String backupKey) async {
    final rows = await _kv.keyValuesWithPrefix(backupKey);
    final match = rows.where((e) => (e['key'] ?? '') == backupKey).toList(growable: false);
    if (match.isEmpty) return;
    await _backupCurrent(id);
    await _kv.setString(_key(id), match.first['value'] ?? '');
  }

  Future<void> clearPromptOverride(String id) async {
    await _backupCurrent(id);
    await _kv.setString(_key(id), '');
  }

  Future<String> exportPromptsJson() async {
    final items = <String, dynamic>{};
    for (final id in allPromptIds()) {
      final saved = ((await _kv.getString(_key(id))) ?? '').trim();
      if (saved.isNotEmpty) items[id] = saved;
    }
    return jsonEncode(<String, dynamic>{
      'module': moduleId,
      'schema_version': 2,
      'exported_at_ms': DateTime.now().millisecondsSinceEpoch,
      'prompts': items,
    });
  }

  Future<int> importPromptsJson(String raw) async {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return 0;
    final prompts = decoded['prompts'];
    if (prompts is! Map) return 0;
    var count = 0;
    for (final entry in prompts.entries) {
      final id = entry.key.toString();
      if (!allPromptIds().contains(id)) continue;
      await savePrompt(id, entry.value.toString());
      count += 1;
    }
    return count;
  }

  Future<String> getPrompt(String id) async {
    final raw = await _kv.getString(_key(id));
    final trimmed = (raw ?? '').trim();
    return trimmed.isEmpty ? defaultPrompt(id) : trimmed;
  }

  Future<void> savePrompt(String id, String value) async {
    await _backupCurrent(id);
    await _kv.setString(_key(id), value.trim());
  }

  Future<Map<String, String>> inspectPrompt(String id) async {
    final saved = ((await _kv.getString(_key(id))) ?? '').trim();
    return <String, String>{
      'value': saved.isEmpty ? defaultPrompt(id) : saved,
      'source': saved.isEmpty ? 'default_builtin' : 'local_saved',
      'sourceLabel': saved.isEmpty ? '内置默认 Prompt' : '本地已保存 Prompt',
      'note': saved.isEmpty
          ? '当前使用 WOOP 行动引擎内置三层 Prompt。你可以在这里自由改写全局价值层、任一场景层或输出格式层。'
          : '当前实际使用设置页保存的 WOOP 行动引擎 Prompt，下一次 AI 调用立即生效。',
    };
  }

  Future<String> previewFor(String id) async {
    final template = await getPrompt(id);
    return render(template, const <String, String>{
      'scene': 'work_study',
      'user_input': '我想本周完成论文第一稿，但一想到写不好就拖延刷手机。',
      'source': 'manual',
      'extra_context': '{"recent_obstacles":["完美主义","分心逃避"]}',
      'history_json': '{"cards":2,"reviews":1}',
      'output_mode': 'json',
    });
  }

  Future<String> buildPrompt({
    required String userInput,
    String scene = 'auto',
    String source = 'manual',
    String extraContext = '',
    String historyJson = '{}',
    String outputMode = 'json',
  }) async {
    final resolvedScenePromptId = scene == 'auto' ? sceneClassifierId : promptIdForScene(scene);
    final outputId = outputMode == 'review'
        ? outputReviewId
        : outputMode == 'target_filter'
            ? outputTargetFilterId
            : outputJsonId;
    final global = await getPrompt(globalId);
    final scenePrompt = render(await getPrompt(resolvedScenePromptId), <String, String>{
      'scene': scene,
      'user_input': userInput,
      'source': source,
      'extra_context': extraContext,
      'history_json': historyJson,
      'output_mode': outputMode,
    });
    final outputPrompt = await getPrompt(outputId);
    final fallbackReadable = await getPrompt(outputWoopId);
    return render('''
【全局价值层 Prompt】
{{global_prompt}}

【场景层 Prompt】
{{scene_prompt}}

【输出格式 Prompt】
{{output_prompt}}

【可读输出参考格式】
{{fallback_readable_prompt}}

【来源】
{{source}}

【历史上下文 JSON】
{{history_json}}

【额外上下文】
{{extra_context}}

【用户本次输入】
{{user_input}}

请严格遵守三层 Prompt。必须基于《Rethinking Positive Thinking》的核心思想，把愿望、最佳结果、内在障碍和 if–then 计划连接起来。不要只输出鼓励，也不要只输出待办清单。
''', <String, String>{
      'global_prompt': global,
      'scene_prompt': scenePrompt,
      'output_prompt': outputPrompt,
      'fallback_readable_prompt': fallbackReadable,
      'source': source,
      'history_json': historyJson,
      'extra_context': extraContext,
      'user_input': userInput,
    });
  }

  String render(String template, Map<String, String> values) {
    var out = template;
    values.forEach((key, value) {
      out = out.replaceAll('{{$key}}', value);
    });
    return out;
  }
}
