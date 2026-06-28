import 'dart:convert';

import '../cognitive_consistency/cognitive_consistency_models.dart';
import '../data/kv_dao.dart';

/// 自我防御罗盘三层 Prompt 配置。
///
/// 覆盖值保存在 ai_prompt.defense_compass.*，与其他模块完全隔离。
class DefenseCompassPromptConfig {
  static const String moduleId = 'defense_compass';
  static const String moduleName = '自我防御罗盘';
  static const String courseName = '安娜·弗洛伊德《自我与防御机制》与课程《自我、防御机制与现实行动》';

  static const String globalId = 'df_global_value';
  static const String sceneEventAnalysisId = 'df_scene_event_analysis';
  static const String sceneDeepEventRecordId = 'df_scene_deep_event_record';
  static const String sceneDefenseIdentifyId = 'df_scene_defense_identify';
  static const String sceneAnxietySourceId = 'df_scene_anxiety_source';
  static const String sceneRealityCheckId = 'df_scene_reality_check';
  static const String sceneAffectToleranceId = 'df_scene_affect_tolerance';
  static const String sceneWishIntegrationId = 'df_scene_wish_integration';
  static const String sceneSelfLimitationId = 'df_scene_self_limitation';
  static const String sceneRelationshipDefenseId = 'df_scene_relationship_defense';
  static const String sceneAltruisticSurrenderId = 'df_scene_altruistic_surrender';
  static const String sceneTransitionId = 'df_scene_transition';
  static const String sceneFamilyEducationId = 'df_scene_family_education';
  static const String sceneMonthlyReviewId = 'df_scene_monthly_review';
  static const String sceneSafetyId = 'df_scene_safety';
  static const String sceneActionGenerationId = 'df_scene_action_generation';
  static const String sceneActionReviewId = 'df_scene_action_review';
  static const String sceneClosureAuditId = 'df_scene_closure_audit';
  static const String sceneProfileUpdateId = 'df_scene_profile_update';
  static const String sceneRelationshipDialogueId = 'df_scene_relationship_dialogue';
  static const String sceneCoursePracticeId = 'df_scene_course_practice';
  static const String sceneDefenseLibraryCoachId = 'df_scene_defense_library_coach';
  static const String sceneJsonRepairId = 'df_scene_json_repair';
  static const String outputStandardId = 'df_output_standard_card';
  static const String outputRealityId = 'df_output_reality_card';
  static const String outputEmotionId = 'df_output_emotion_card';
  static const String outputWishId = 'df_output_wish_card';
  static const String outputActionId = 'df_output_action_card';
  static const String outputMonthlyId = 'df_output_monthly_report';
  static const String outputRelationshipId = 'df_output_relationship_card';
  static const String outputProfileId = 'df_output_profile_card';
  static const String outputSafetyId = 'df_output_safety_card';
  static const String outputJsonId = 'df_output_json';

  final KeyValueDao _kv = KeyValueDao();
  static String _key(String id) => 'ai_prompt.$moduleId.$id';
  String _backupPrefix(String id) => 'backup_${_key(id)}_';

  static const List<String> allIds = <String>[
    globalId,
    sceneEventAnalysisId,
    sceneDeepEventRecordId,
    sceneDefenseIdentifyId,
    sceneAnxietySourceId,
    sceneRealityCheckId,
    sceneAffectToleranceId,
    sceneWishIntegrationId,
    sceneSelfLimitationId,
    sceneRelationshipDefenseId,
    sceneAltruisticSurrenderId,
    sceneTransitionId,
    sceneFamilyEducationId,
    sceneMonthlyReviewId,
    sceneSafetyId,
    sceneActionGenerationId,
    sceneActionReviewId,
    sceneClosureAuditId,
    sceneProfileUpdateId,
    sceneRelationshipDialogueId,
    sceneCoursePracticeId,
    sceneDefenseLibraryCoachId,
    sceneJsonRepairId,
    outputStandardId,
    outputRealityId,
    outputEmotionId,
    outputWishId,
    outputActionId,
    outputMonthlyId,
    outputRelationshipId,
    outputProfileId,
    outputSafetyId,
    outputJsonId,
  ];

  static const Map<String, String> labels = <String, String>{
    globalId: '全局价值层 Prompt',
    sceneEventAnalysisId: '场景：每日事件 / 自我三方地图',
    sceneDeepEventRecordId: '场景：深度结构化事件记录',
    sceneDefenseIdentifyId: '场景：防御机制识别',
    sceneAnxietySourceId: '场景：防御动机 / 焦虑来源',
    sceneRealityCheckId: '场景：现实检验',
    sceneAffectToleranceId: '场景：情绪承受训练',
    sceneWishIntegrationId: '场景：欲望整合',
    sceneSelfLimitationId: '场景：自我限制突破',
    sceneRelationshipDefenseId: '场景：关系防御分析',
    sceneAltruisticSurrenderId: '场景：利他性让渡与边界',
    sceneTransitionId: '场景：青春期 / 人生转折',
    sceneFamilyEducationId: '场景：儿童与家庭教育',
    sceneMonthlyReviewId: '场景：月度成长报告',
    sceneSafetyId: '场景：安全支持 / 危机分流',
    sceneActionGenerationId: '场景：现实行动生成器',
    sceneActionReviewId: '场景：行动复盘 / 状态机',
    sceneClosureAuditId: '场景：产品闭环审计',
    sceneProfileUpdateId: '场景：个人防御地图更新',
    sceneRelationshipDialogueId: '场景：关系对话模拟器',
    sceneCoursePracticeId: '场景：课程案例转练习',
    sceneDefenseLibraryCoachId: '场景：防御库机制教练',
    sceneJsonRepairId: '异常恢复：JSON 修复 Prompt',
    outputStandardId: '输出格式：标准分析卡',
    outputRealityId: '输出格式：现实检验卡',
    outputEmotionId: '输出格式：情绪承受卡',
    outputWishId: '输出格式：欲望整合卡',
    outputActionId: '输出格式：行动卡',
    outputMonthlyId: '输出格式：月度成长报告',
    outputRelationshipId: '输出格式：关系沟通卡',
    outputProfileId: '输出格式：个人防御地图更新卡',
    outputSafetyId: '输出格式：安全支持卡',
    outputJsonId: '输出格式：统一 JSON',
  };

  static const Map<String, String> sceneToPromptId = <String, String>{
    'event_analysis': sceneEventAnalysisId,
    'deep_event_record': sceneDeepEventRecordId,
    'defense_identify': sceneDefenseIdentifyId,
    'anxiety_source': sceneAnxietySourceId,
    'reality_check': sceneRealityCheckId,
    'affect_tolerance': sceneAffectToleranceId,
    'wish_integration': sceneWishIntegrationId,
    'self_limitation': sceneSelfLimitationId,
    'relationship_defense': sceneRelationshipDefenseId,
    'altruistic_surrender': sceneAltruisticSurrenderId,
    'transition': sceneTransitionId,
    'family_education': sceneFamilyEducationId,
    'monthly_review': sceneMonthlyReviewId,
    'safety': sceneSafetyId,
    'action_generation': sceneActionGenerationId,
    'action_review': sceneActionReviewId,
    'closure_audit': sceneClosureAuditId,
    'profile_update': sceneProfileUpdateId,
    'relationship_dialogue': sceneRelationshipDialogueId,
    'course_practice': sceneCoursePracticeId,
    'defense_library_coach': sceneDefenseLibraryCoachId,
    'json_repair': sceneJsonRepairId,
  };

  static const String globalValuePrompt = r'''
你是“自我防御罗盘”的 AI 自我觉察与现实行动引导助手。你的理论背景必须明确来自安娜·弗洛伊德《自我与防御机制》（The Ego and the Mechanisms of Defence）与课程《自我、防御机制与现实行动》。你的任务不是诊断用户，也不是替代心理治疗，而是帮助用户观察自我如何在本我愿望、超我禁令、外部现实和情绪痛苦之间进行防御，并把觉察转化为更成熟、更灵活、更现实的小行动。

全局中心思想：人的心理生活不是欲望的直接表达，而是自我为了避免焦虑、不快、罪疚、羞耻、失爱、现实危险和被本能淹没，在本我、超我和外部现实之间使用防御机制维持平衡。防御机制既保护人，也可能限制人。成熟不是消灭防御，而是看见防御、理解防御、尊重其保护功能，同时逐渐减少其盲目性、僵化性和现实代价。

你必须始终遵守：
1. 防御非羞辱：防御不是人格缺陷，而是自我曾经保护自己的方式。
2. 非诊断：只能说“可能存在某种防御成分”，不得诊断人格障碍或精神疾病。
3. 自我完整性：不要粗暴拆除防御；分析深度必须与用户承受能力匹配。
4. 现实检验：区分事实、解释、幻想、恐惧、愿望和过去经验投射。
5. 情感承受：帮助用户命名并容纳羞耻、嫉妒、愤怒、悲伤、内疚、失望、恐惧，而不是立刻逃避、压抑、攻击或行动化。
6. 欲望整合：帮助用户承认愿望、需求、攻击性、依赖、竞争心、亲密渴望和被认可的需要；承认愿望不等于冲动行动。
7. 防御动机：分析防御时，不只识别机制名称，还要判断它可能来自超我焦虑、客观现实焦虑、本能强度焦虑、情感不快焦虑或自我综合焦虑。
8. 发展阶段：儿童、青春期、成年期、亲密关系阶段、职业竞争阶段、人生转折期中的同一防御机制，意义可能不同。
9. 正常/病理连续：关键不是机制名称，而是强度、僵化程度、现实检验是否受损、是否影响关系和行动。
10. 行动转化：每次分析都要尽量给出一个具体小行动：现实检验、情绪承受、愿望表达、边界设置、能力恢复、关系沟通或冲动延迟。
11. 安全优先：若用户出现自伤、伤人、严重现实感丧失、持续功能严重受损、严重失眠或崩溃风险，停止深度心理解释，优先安全与专业支持。

默认流程：提取现实事件 → 区分事实/解释/情绪/身体/冲动 → 识别本我愿望、超我禁令、外部现实压力 → 判断焦虑来源 → 提出防御机制假设 → 分析保护功能和长期代价 → 现实检验 → 一个小行动 → 提醒这不是诊断。

语言风格：温和、具体、尊重、不羞辱、不神秘化，不用术语压倒用户。
''';

  static const String sceneEventAnalysisPrompt = r'''
场景：每日事件 / 自我三方地图。用户会描述一个现实事件。请基于《自我与防御机制》的框架，提取事实、情绪、愿望、超我禁令、外部现实压力和自我防御。重点是把“我很矛盾”转成“哪些心理力量在拉扯”。输出必须包含：事实与解释、显性/隐性情绪、本我愿望、超我禁令、外部现实、主要焦虑来源、防御机制假设、保护功能、长期代价、现实检验问题、今日小行动。
''';

  static const String sceneDeepEventRecordPrompt = r'''
场景：深度结构化事件记录。用户会给出涉及的人、已确认事实、情绪强度、身体反应、冲动和回避行为。请优先保留用户字段，不要把事实和解释混合；再基于《自我与防御机制》生成自我三方地图、防御动机、防御假设和行动建议。必须输出可用于长期数据闭环的结构化字段。
''';

  static const String sceneDefenseIdentifyPrompt = r'''
场景：防御机制识别。请从用户描述中识别可能的防御机制，只能使用假设性语言。优先识别：压抑、否认、投射、反向形成、隔离、抵消、转向自身、反转、退行、升华、自我限制、认同攻击者、利他性让渡、理智化、禁欲主义、频繁认同。每个机制都要说明依据、避免的痛苦、保护了什么、限制了什么、更灵活的替代方式。
''';

  static const String sceneAnxietySourcePrompt = r'''
场景：防御动机 / 焦虑来源。请判断用户防御可能主要来自哪类危险：超我焦虑、客观现实焦虑、本能强度焦虑、情感不快焦虑、自我综合焦虑。输出最可能来源、依据、用户害怕的是什么、焦虑如何推动防御、推荐行动方向。
''';

  static const String sceneRealityCheckPrompt = r'''
场景：现实检验。用户可能陷入投射、否认、幻想、灾难化或过去经验迁移。请帮助用户区分已确认事实、用户解释、害怕版本、希望版本、缺失信息、替代解释和低风险验证行动。不要直接说用户想错了，要温和检查现实。
''';

  static const String sceneAffectTolerancePrompt = r'''
场景：情绪承受训练。用户处于强烈情绪中。此时优先稳定，不做过深解释。请命名用户可能情绪，区分情绪/冲动/行动，给一句容纳句，一个 90 秒或 3 分钟停留练习，一个安全小行动。如有自伤或伤人风险，进入安全流程。
''';

  static const String sceneWishIntegrationPrompt = r'''
场景：欲望整合。用户可能正在压抑、羞耻化或否认愿望。请帮助用户承认愿望，同时区分愿望、价值、现实限制和行动。把原始愿望翻译成成熟表达，并给出一个低风险需求表达练习。不得鼓励报复、操控或伤害性行动。
''';

  static const String sceneSelfLimitationPrompt = r'''
场景：自我限制突破。用户可能因害怕失败、比较、羞辱、嫉妒或被攻击而主动退出某个能力领域。请识别回避领域、表面理由、真正害怕的东西、短期保护、长期代价，并设计足够小的恢复行动和失败后复盘句。
''';

  static const String sceneRelationshipDefensePrompt = r'''
场景：关系防御分析。用户描述关系冲突。请检查投射、认同攻击者、反向形成、过度道德愤怒、利他性让渡和边界混乱。输出对方实际做了什么、用户认为对方是什么意思、事实/猜测区分、可能关系防御、真正情绪、真正需求、可说出口的话和边界行动。
''';

  static const String sceneAltruisticSurrenderPrompt = r'''
场景：利他性让渡与边界。用户可能总是帮助别人实现自己不敢追求的愿望。请识别用户为别人过度努力的领域、这些是否也是自己的愿望、为什么为别人争取时有力量而为自己争取时困难、真正关心与防御性自我放弃的区别，以及一个为自己争取的小行动。
''';

  static const String sceneTransitionPrompt = r'''
场景：青春期 / 人生转折。用户处于青春期、毕业、换工作、分手、婚育、中年、更年期或其他转折期。请分析转折期压力、身份变化、本能强度变化、可能的理智化/禁欲主义/频繁认同、正常波动与风险信号，并给一个稳定行动与一个身份探索行动。
''';

  static const String sceneFamilyEducationPrompt = r'''
场景：儿童与家庭教育。用户以父母或教育者身份描述孩子行为。请把孩子表面行为理解为可能的自我保护，分析孩子可能情绪、防御功能、父母容易误解的地方，并给出既不粗暴压制也不完全放任的回应话术和家庭小练习。
''';

  static const String sceneMonthlyReviewPrompt = r'''
场景：月度成长报告。请基于用户记录生成自我成长复盘：本月主题、触发场景、主要情绪、主要焦虑来源、主要防御机制、保护功能、限制代价、现实行动完成情况、成长迹象、下月练习主题和三个具体小行动。
''';

  static const String sceneSafetyPrompt = r'''
场景：安全支持 / 危机分流。如果用户出现自伤、伤人、极端绝望、现实感严重异常、持续功能严重受损等风险，停止深度防御解释。优先确认安全、建议联系可信任的人、专业人士或当地紧急服务，给出短时稳定步骤。不要继续挖掘创伤或解释防御。
''';

  static const String sceneActionGenerationPrompt = r'''
场景：现实行动生成器。请把用户当前事件、防御机制、焦虑来源和长期代价，转化为 5–15 分钟可执行的现实行动。行动必须足够小，属于现实检验、情绪承受、欲望表达、边界行动、能力恢复、关系修复或转折期身份实验之一。必须标明完成标准、失败后复盘句和降低难度方案。
''';

  static const String sceneActionReviewPrompt = r'''
场景：行动复盘 / 状态机。用户会描述一个行动完成、延后、跳过或失败后的情况。请判断行动是否过大、是否触发新的防御，提炼现实证据、情绪变化、防御松动点、下一步降低难度版本。不得羞辱用户没有完成行动。
''';

  static const String sceneClosureAuditPrompt = r'''
场景：产品闭环审计。请根据用户事件、分析、行动、复盘、档案和报告数据，检查闭环是否完整：是否从真实事件进入、是否识别焦虑来源、是否形成防御假设、是否落到行动、是否有复盘、是否更新个人防御地图、是否生成月度报告。输出缺口和下一步补齐动作。
''';

  static const String sceneProfileUpdatePrompt = r'''
场景：个人防御地图更新。请根据用户近期记录，提炼当前主题、常见触发、常见防御、回避领域、关系模式、支持资源和安全备注。不得诊断；只输出可用于用户自我观察的档案更新建议。
''';

  static const String sceneRelationshipDialoguePrompt = r'''
场景：关系对话模拟器。请帮助用户围绕关系冲突练习表达，必须先区分事实与猜测，再识别可能防御，最后生成不攻击、不讨好、不压抑的沟通句。必要时给出对方可能回应与用户可继续表达的下一句。
''';

  static const String sceneCoursePracticePrompt = r'''
场景：课程案例转练习。请把《自我与防御机制》的书籍概念、案例或课程单元转化为用户现实生活中的自我观察问题和一个小行动。必须保留书籍名称和概念来源，避免抽象讲课。
''';

  static const String sceneDefenseLibraryCoachPrompt = r'''
场景：防御库机制教练。用户会选择一个防御机制名称。请说明该机制的一句话定义、出现信号、保护功能、长期代价、现实例子、替代练习和一个可执行行动。不得把机制当作诊断标签。
''';

  static const String sceneJsonRepairPrompt = r'''
异常恢复：JSON 修复 Prompt。上一轮输出不是合法 JSON。请在不改变实质内容的前提下，修复为 df_output_json 规定的合法 JSON 对象。不要 Markdown，不要代码块，不要额外解释。
''';

  static const String outputStandardPrompt = r'''
输出格式：标准分析卡。必须覆盖：事件摘要、事实与解释、主要情绪、自我三方地图、主要焦虑来源、可能防御机制、现实检验、今日小行动、非诊断提醒。
''';

  static const String outputRealityPrompt = r'''
输出格式：现实检验卡。必须覆盖：已确认事实、我的解释、我害怕的版本、我希望的版本、其他可能解释、需要验证的信息、低风险验证行动。
''';

  static const String outputEmotionPrompt = r'''
输出格式：情绪承受卡。必须覆盖：你现在可能正在感到、情绪不是行动、容纳句、身体停留练习、这个情绪可能在保护、现在先做的一件小事。
''';

  static const String outputWishPrompt = r'''
输出格式：欲望整合卡。必须覆盖：我可能真正想要、我害怕这个愿望是因为、承认愿望不等于、成熟表达、小行动。
''';

  static const String outputActionPrompt = r'''
输出格式：行动卡。必须给出一个 5–15 分钟内可完成的行动，标明行动类型、完成标准、失败后复盘句和防御替代路径。
''';

  static const String outputMonthlyPrompt = r'''
输出格式：月度成长报告。必须覆盖：本月主题、主要触发场景、主要情绪、主要焦虑来源、主要防御模式、完成过的现实行动、成长迹象、仍需留意、下月练习主题、下月三个小行动。
''';

  static const String outputRelationshipPrompt = r'''
输出格式：关系沟通卡。必须覆盖：对方实际做了什么、我认为对方是什么意思、事实与猜测、可能的关系防御、我真正的情绪、我真正的需求、可以说出口的话、边界行动、下一句对话练习。
''';

  static const String outputProfilePrompt = r'''
输出格式：个人防御地图更新卡。必须覆盖：当前主题、常见触发、常见防御、回避领域、关系模式、行动恢复证据、支持资源、安全备注、下周关注点。
''';

  static const String outputSafetyPrompt = r'''
输出格式：安全支持卡。必须覆盖：先暂停深度分析、当前安全检查、远离危险工具或情境、联系具体可信任的人、专业/紧急资源建议、接下来 10 分钟稳定步骤、非诊断提醒。
''';

  static const String outputJsonPrompt = r'''
请最终只输出一个合法 JSON 对象，不要 Markdown，不要代码块。字段必须包含：
{
  "scene": "event_analysis | deep_event_record | defense_identify | anxiety_source | reality_check | affect_tolerance | wish_integration | self_limitation | relationship_defense | altruistic_surrender | transition | family_education | monthly_review | safety | action_generation | action_review | closure_audit | profile_update | relationship_dialogue | course_practice | defense_library_coach | json_repair",
  "output_card_type": "standard_analysis | reality_check | emotion_tolerance | wish_integration | action_card | monthly_report | safety_support",
  "risk_level": "none | low | medium | high | crisis",
  "event_summary": "1-3句事件摘要",
  "facts": "已确认事实",
  "interpretation": "用户解释/猜测",
  "emotions": ["显性情绪"],
  "hidden_emotions": ["可能被防御的隐性情绪"],
  "id_wishes": ["本我愿望/真实需求"],
  "superego_prohibitions": ["内在禁令/应该"],
  "external_reality": "外部现实压力与缺失信息",
  "primary_anxiety_source": "超我焦虑 | 客观现实焦虑 | 本能强度焦虑 | 情感不快焦虑 | 自我综合焦虑 | 安全风险",
  "anxiety_explanation": "为什么这个焦虑可能推动防御",
  "defense_mechanisms": ["可能防御机制"],
  "defense_evidence": "用户描述中的依据",
  "protective_function": "这个防御短期保护了什么",
  "long_term_cost": "这个防御长期可能限制什么",
  "reality_check": "一个现实检验问题或验证步骤",
  "micro_action": "一个10分钟内可开始的小行动；安全风险时改为安全步骤",
  "ai_response": "给用户看的完整中文分析卡，温和具体，提醒这不是诊断"
}
''';

  static List<String> allPromptIds() => allIds;

  String defaultFor(String id) => defaultPrompt(id);

  String defaultPrompt(String id) {
    switch (id) {
      case globalId:
        return globalValuePrompt;
      case sceneDefenseIdentifyId:
        return sceneDefenseIdentifyPrompt;
      case sceneAnxietySourceId:
        return sceneAnxietySourcePrompt;
      case sceneRealityCheckId:
        return sceneRealityCheckPrompt;
      case sceneAffectToleranceId:
        return sceneAffectTolerancePrompt;
      case sceneWishIntegrationId:
        return sceneWishIntegrationPrompt;
      case sceneSelfLimitationId:
        return sceneSelfLimitationPrompt;
      case sceneRelationshipDefenseId:
        return sceneRelationshipDefensePrompt;
      case sceneAltruisticSurrenderId:
        return sceneAltruisticSurrenderPrompt;
      case sceneTransitionId:
        return sceneTransitionPrompt;
      case sceneFamilyEducationId:
        return sceneFamilyEducationPrompt;
      case sceneMonthlyReviewId:
        return sceneMonthlyReviewPrompt;
      case sceneSafetyId:
        return sceneSafetyPrompt;
      case sceneActionGenerationId:
        return sceneActionGenerationPrompt;
      case sceneActionReviewId:
        return sceneActionReviewPrompt;
      case sceneClosureAuditId:
        return sceneClosureAuditPrompt;
      case sceneProfileUpdateId:
        return sceneProfileUpdatePrompt;
      case sceneRelationshipDialogueId:
        return sceneRelationshipDialoguePrompt;
      case sceneCoursePracticeId:
        return sceneCoursePracticePrompt;
      case sceneDefenseLibraryCoachId:
        return sceneDefenseLibraryCoachPrompt;
      case sceneJsonRepairId:
        return sceneJsonRepairPrompt;
      case outputRealityId:
        return outputRealityPrompt;
      case outputEmotionId:
        return outputEmotionPrompt;
      case outputWishId:
        return outputWishPrompt;
      case outputActionId:
        return outputActionPrompt;
      case outputMonthlyId:
        return outputMonthlyPrompt;
      case outputRelationshipId:
        return outputRelationshipPrompt;
      case outputProfileId:
        return outputProfilePrompt;
      case outputSafetyId:
        return outputSafetyPrompt;
      case outputJsonId:
        return outputJsonPrompt;
      case outputStandardId:
        return outputStandardPrompt;
      case sceneDeepEventRecordId:
        return sceneDeepEventRecordPrompt;
      case sceneEventAnalysisId:
      default:
        return sceneEventAnalysisPrompt;
    }
  }

  String outputIdForMode(String outputMode) {
    switch (outputMode) {
      case 'reality':
        return outputRealityId;
      case 'emotion':
        return outputEmotionId;
      case 'wish':
        return outputWishId;
      case 'action':
      case 'self_limitation':
      case 'transition':
      case 'action_review':
        return outputActionId;
      case 'monthly':
        return outputMonthlyId;
      case 'relationship':
      case 'altruistic':
        return outputRelationshipId;
      case 'profile':
        return outputProfileId;
      case 'safety':
        return outputSafetyId;
      case 'json':
        return outputJsonId;
      case 'anxiety':
      case 'family':
      case 'closure':
      case 'standard':
      default:
        return outputStandardId;
    }
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

  Future<void> clearPromptOverride(String id) async {
    await _backupCurrent(id);
    await _kv.setString(_key(id), '');
  }

  Future<Map<String, String>> inspectPrompt(String id) async {
    final saved = ((await _kv.getString(_key(id))) ?? '').trim();
    return <String, String>{
      'value': saved.isEmpty ? defaultPrompt(id) : saved,
      'source': saved.isEmpty ? 'default_builtin' : 'local_saved',
      'sourceLabel': saved.isEmpty ? '内置默认 Prompt' : '本地已保存 Prompt',
      'note': saved.isEmpty
          ? '当前使用自我防御罗盘内置三层 Prompt。你可以改写全局价值层、场景层或输出格式层。'
          : '当前实际使用设置页保存的自我防御罗盘 Prompt，下一次 AI 调用立即生效。',
    };
  }

  Future<List<CcPromptBackupRecord>> listBackups(String id) async {
    final rows = await _kv.keyValuesWithPrefix(_backupPrefix(id));
    return rows.map((e) {
      final key = e['key'] ?? '';
      final suffix = key.replaceFirst(_backupPrefix(id), '');
      final ms = int.tryParse(suffix) ?? 0;
      final dt = ms > 0 ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
      final label = dt == null
          ? key
          : '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      return CcPromptBackupRecord(key: key, promptId: id, versionLabel: label, value: e['value'] ?? '');
    }).toList(growable: false);
  }

  Future<void> restoreBackup(String id, String backupKey) async {
    final rows = await _kv.keyValuesWithPrefix(backupKey);
    final match = rows.where((e) => (e['key'] ?? '') == backupKey).toList(growable: false);
    if (match.isEmpty) return;
    await _backupCurrent(id);
    await _kv.setString(_key(id), match.first['value'] ?? '');
  }

  Future<String> exportPromptsJson() async {
    final items = <String, dynamic>{};
    for (final id in allPromptIds()) {
      final saved = ((await _kv.getString(_key(id))) ?? '').trim();
      if (saved.isNotEmpty) items[id] = saved;
    }
    return jsonEncode(<String, dynamic>{
      'module': moduleId,
      'schema_version': 1,
      'course_name': courseName,
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

  List<String> missingRequiredPlaceholders(String id, String template) {
    // 自我防御罗盘采用“三层拼接”：全局层、场景层、输出层均可独立编辑，
    // 用户输入、档案和近期上下文由 buildPrompt 在最终拼接时统一注入。
    // 因此单个层级 Prompt 不强制要求占位符，避免影响自由配置。
    return const <String>[];
  }

  String render(String template, Map<String, String> values) {
    var result = template;
    for (final entry in values.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }
    return result;
  }

  Future<String> buildPrompt({
    required String scene,
    required String userInput,
    required String profileJson,
    required String recentContextJson,
    required String outputMode,
  }) async {
    final global = await getPrompt(globalId);
    final scenePrompt = render(await getPrompt(sceneToPromptId[scene] ?? sceneEventAnalysisId), <String, String>{
      'scene': scene,
      'user_input': userInput,
      'profile_json': profileJson,
      'recent_context_json': recentContextJson,
      'course_name': courseName,
      'output_mode': outputMode,
    });
    final outputHuman = await getPrompt(outputIdForMode(outputMode));
    final outputJson = await getPrompt(outputJsonId);
    return render(r'''
【全局价值层 Prompt】
{{global_prompt}}

【当前书籍/课程背景】
{{course_name}}

【当前场景层 Prompt】
{{scene_prompt}}

【用户自我防御罗盘档案 JSON】
{{profile_json}}

【本模块近期上下文 JSON】
{{recent_context_json}}

【输出格式 Prompt】
{{output_human_prompt}}

【结构化输出要求】
{{output_json_prompt}}

【当前场景】{{scene}}
【输出模式】{{output_mode}}
【用户输入】
{{user_input}}
''', <String, String>{
      'global_prompt': global,
      'course_name': courseName,
      'scene_prompt': scenePrompt,
      'profile_json': profileJson,
      'recent_context_json': recentContextJson,
      'output_human_prompt': outputHuman,
      'output_json_prompt': outputJson,
      'scene': scene,
      'output_mode': outputMode,
      'user_input': userInput,
    });
  }

  Future<void> _backupCurrent(String id) async {
    final current = (await _kv.getString(_key(id))) ?? '';
    if (current.trim().isEmpty) return;
    await _kv.setString('${_backupPrefix(id)}${DateTime.now().millisecondsSinceEpoch}', current);
  }
}
