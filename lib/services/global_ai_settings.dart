import '../data/dao.dart';
import '../data/kv_dao.dart';
import '../goal_setting_module/goal_setting_remote_sync.dart';

class GlobalAiSettings {
  static const String providerKey = 'global_ai_provider';
  static const String openAiModelKey = 'global_ai_model_openai';
  static const String deepSeekModelKey = 'global_ai_model_deepseek';
  static const String openRouterModelKey = 'global_ai_model_openrouter';
  static const String edenAiModelKey = 'global_ai_model_edenai';
  static const String edenAiKeyKey = 'global_ai_edenai_key';
  static const String edenAiDefaultModel = 'openai/gpt-4o-mini';
  static const String goalSettingUnderstandingPromptKey = 'goal_setting_understanding_prompt';
  static const String goalSettingActionPromptKey = 'goal_setting_action_prompt';
  static const String goalSettingLoopPromptKey = 'goal_setting_loop_prompt';
  static const String movieRoleLabEntryPromptKey = 'movie_role_lab_entry_prompt';
  static const String movieRoleLabTurnPromptKey = 'movie_role_lab_turn_prompt';
  static const String movieRoleLabEpisodePromptKey = 'movie_role_lab_episode_prompt';
  static const String movieAnalysisPromptKey = 'movie_analysis_prompt';
  static const String drawerHeaderPromptKey = 'drawer_header_prompt';
  static const String lifeNoteAnalysisPromptKey = 'life_note_analysis_prompt';
  static const String meditationDailyScriptPromptKey = 'meditation_daily_script_prompt';
  static const String meditationFeedbackPromptKey = 'meditation_feedback_prompt';
  static const String meditationWeeklySummaryPromptKey = 'meditation_weekly_summary_prompt';
  static const String meditationRecommendationPromptKey = 'meditation_recommendation_prompt';
  static const String meditationUploadPausePromptKey = 'meditation_upload_pause_prompt';
  static const String behaviorPresetDailyReviewAiPromptKey = 'behavior_preset_daily_review_ai_prompt';
  static const String voiceAlarmContentPromptKey = 'voice_alarm.ai_prompt';
  static const String voiceAlarmMorningAssistantPromptKey = 'voice_alarm.morning_assistant_prompt';
  static const String voiceAlarmNightAssistantPromptKey = 'voice_alarm.night_assistant_prompt';

  final ConfigDao _configDao = ConfigDao();
  final KeyValueDao _kvDao = KeyValueDao();
  final GoalSettingRemoteSync _remoteSync = GoalSettingRemoteSync();

  String get defaultVoiceAlarmContentPrompt =>
      '请为{{mode}}语音闹钟写一段自然、温暖、适合中文朗读的内容。只输出朗读正文，50到100字，不要标题。早安内容应积极但不过度兴奋；晚安内容应舒缓、接纳且不制造压力。';

  String get defaultVoiceAlarmMorningAssistantPrompt =>
      '你是起床闹钟全屏界面里的中文语音 AI。目标是温和但坚定地帮助用户醒来、坐起、开始一天。回答必须适合语音播报，简短、具体、支持行动，不批评用户。用户可以说关闭闹钟或延迟五分钟；如果用户表达不想起床，请先共情，再给一个 10 秒内可执行的小动作。';

  String get defaultVoiceAlarmNightAssistantPrompt =>
      '你是睡眠闹钟全屏界面里的中文语音 AI。目标是帮助用户放下事务、降低唤醒度、进入睡前节奏。回答必须适合语音播报，简短、舒缓、低刺激，不制造压力。用户可以说关闭闹钟或延迟五分钟；如果用户焦虑或舍不得睡，请先接住感受，再给一个很小的放松动作。';

  Future<String> getVoiceAlarmContentPrompt() => _getLocalPrompt(
        key: voiceAlarmContentPromptKey,
        fallback: defaultVoiceAlarmContentPrompt,
      );

  Future<void> saveVoiceAlarmContentPrompt(String prompt) => _saveLocalPrompt(
        key: voiceAlarmContentPromptKey,
        fallback: defaultVoiceAlarmContentPrompt,
        value: prompt,
      );

  Future<Map<String, String>> inspectVoiceAlarmContentPromptState() => _inspectLocalPrompt(
        key: voiceAlarmContentPromptKey,
        fallback: defaultVoiceAlarmContentPrompt,
      );

  Future<String> getVoiceAlarmMorningAssistantPrompt() => _getLocalPrompt(
        key: voiceAlarmMorningAssistantPromptKey,
        fallback: defaultVoiceAlarmMorningAssistantPrompt,
      );

  Future<void> saveVoiceAlarmMorningAssistantPrompt(String prompt) => _saveLocalPrompt(
        key: voiceAlarmMorningAssistantPromptKey,
        fallback: defaultVoiceAlarmMorningAssistantPrompt,
        value: prompt,
      );

  Future<Map<String, String>> inspectVoiceAlarmMorningAssistantPromptState() => _inspectLocalPrompt(
        key: voiceAlarmMorningAssistantPromptKey,
        fallback: defaultVoiceAlarmMorningAssistantPrompt,
      );

  Future<String> getVoiceAlarmNightAssistantPrompt() => _getLocalPrompt(
        key: voiceAlarmNightAssistantPromptKey,
        fallback: defaultVoiceAlarmNightAssistantPrompt,
      );

  Future<void> saveVoiceAlarmNightAssistantPrompt(String prompt) => _saveLocalPrompt(
        key: voiceAlarmNightAssistantPromptKey,
        fallback: defaultVoiceAlarmNightAssistantPrompt,
        value: prompt,
      );

  Future<Map<String, String>> inspectVoiceAlarmNightAssistantPromptState() => _inspectLocalPrompt(
        key: voiceAlarmNightAssistantPromptKey,
        fallback: defaultVoiceAlarmNightAssistantPrompt,
      );

  Future<Map<String, String>> getState() async {
    final global = await _configDao.getOne();
    final deepseekKey = (await _configDao.getDeepseekKey()).trim();
    final openaiKey = (global['api_key'] ?? '').toString().trim();
    final openrouterKey = (await _configDao.getOpenRouterKey()).trim();
    final edenAiKey = await getEdenAiKey();
    final provider = (((await _kvDao.getString(providerKey)) ?? '').trim().toLowerCase());
    final resolvedProvider = provider == 'openai'
        ? 'openai'
        : provider == 'openrouter'
            ? 'openrouter'
            : provider == 'edenai'
                ? 'edenai'
                : provider == 'deepseek'
                    ? 'deepseek'
                    : (deepseekKey.isNotEmpty
                        ? 'deepseek'
                        : (openrouterKey.isNotEmpty
                            ? 'openrouter'
                            : (edenAiKey.isNotEmpty ? 'edenai' : 'openai')));
    final deepseekModel = ((await _kvDao.getString(deepSeekModelKey)) ?? await _configDao.getDeepseekModel()).trim();
    final openaiModel = ((await _kvDao.getString(openAiModelKey)) ?? (global['model'] ?? 'gpt-5').toString()).trim();
    final openrouterModel = ((await _kvDao.getString(openRouterModelKey)) ?? 'openai/gpt-4.1-mini').trim();
    final edenAiModel = ((await _kvDao.getString(edenAiModelKey)) ?? edenAiDefaultModel).trim();
    final model = resolvedProvider == 'openai'
        ? (openaiModel.isEmpty ? 'gpt-5' : openaiModel)
        : resolvedProvider == 'openrouter'
            ? (openrouterModel.isEmpty ? 'openai/gpt-4.1-mini' : openrouterModel)
            : resolvedProvider == 'edenai'
                ? (edenAiModel.isEmpty ? edenAiDefaultModel : edenAiModel)
                : (deepseekModel.isEmpty ? 'deepseek-reasoner' : deepseekModel);
    final available = resolvedProvider == 'openai'
        ? openaiKey.isNotEmpty
        : resolvedProvider == 'openrouter'
            ? openrouterKey.isNotEmpty
            : resolvedProvider == 'edenai'
                ? edenAiKey.isNotEmpty
                : deepseekKey.isNotEmpty;
    final label = resolvedProvider == 'openai'
        ? 'OpenAI · $model'
        : resolvedProvider == 'openrouter'
            ? 'OpenRouter · $model'
            : resolvedProvider == 'edenai'
                ? 'Eden AI · $model'
                : 'DeepSeek · $model';
    final displayModel = resolvedProvider == 'openrouter' ? 'openrouter / $model' : model;
    return <String, String>{
      'provider': resolvedProvider,
      'model': model,
      'display_model': displayModel,
      'openai_model': openaiModel.isEmpty ? 'gpt-5' : openaiModel,
      'deepseek_model': deepseekModel.isEmpty ? 'deepseek-reasoner' : deepseekModel,
      'openrouter_model': openrouterModel.isEmpty ? 'openai/gpt-4.1-mini' : openrouterModel,
      'edenai_model': edenAiModel.isEmpty ? edenAiDefaultModel : edenAiModel,
      'label': label,
      'available': available ? '1' : '0',
      'note': '该配置由设置页统一管理，模块内只读。',
    };
  }

  String get defaultGoalSettingUnderstandingPrompt =>
      '你是“目标训练”模块的课程理解教练。请严格根据下面这段课程原文进行分析，不要脱离原文乱发挥。\n\n课程标题：{{segment_title}}\n课程原文（必须完整阅读并紧扣分析）：\n{{original_text}}\n\n请完成以下任务：\n1. 深度分析这段在讲什么；\n2. 解释为什么作者要这样讲、为什么这段重要；\n3. 按照原文思想给出“该如何做”；\n4. 给出一个现实中的具体案例，要求有人物、场景、动作、结果。\n\n请严格输出一个 JSON 对象，不要输出 markdown，不要输出代码块：\n{\n  "what_text": "用通俗中文解释这段讲的是什么",\n  "why_text": "用通俗中文解释为什么这样讲、为什么重要",\n  "how_to_do": "按照原文思想，给出可执行的做法，尽量写得具体",\n  "real_case": "结合现实中的具体案例分析，写出人物、场景、动作、结果"\n}\n\n额外要求：\n- 完全基于原文思想；\n- 语言清楚、具体、可理解；\n- “如何做”不要空话；\n- “现实具体案例”必须具体。';

  String get defaultGoalSettingActionPrompt =>
      '你是“目标训练”模块的行动教练。请严格根据下面这段课程原文来生成行动，不要生成与课程主题脱节的泛化建议。行动必须首先体现这段课程的核心思想，再结合用户当前困扰做落地设计。\n\n课程标题：{{segment_title}}\n课程原文（必须完整阅读并紧扣行动设计）：\n{{original_text}}\n核心概念：{{core_concepts}}\n默认动作标题：{{default_action_title}}\n默认动作说明：{{default_action_body}}\n课程建议步骤：{{how_steps}}\n用户当前困扰：{{user_concern}}\n\n行动设计要求：\n1. 三档行动都必须与该段课程主题高度一致；\n2. 不能只给通用拖延建议，必须体现该段课程的关键机制；\n3. 行动必须具体、可执行、可视化，尽量写清时间、地点、对象、动作、顺序、因果；\n4. 要给出完成标准和做不到时的降级方案；\n5. 用户看完就可以直接照做。\n\n请严格输出一个 JSON 对象，不要输出 markdown，不要输出代码块：\n{\n  "minimal_action": {\n    "title": "最小动作标题",\n    "body": "一个低阻力但高度贴合课程主题的具体行动画面",\n    "steps": ["步骤1", "步骤2"],\n    "success_criteria": "完成标准",\n    "fallback_action": "降级方案"\n  },\n  "standard_action": {\n    "title": "标准动作标题",\n    "body": "一个今天可完成的具体练习",\n    "steps": ["步骤1", "步骤2", "步骤3"],\n    "success_criteria": "完成标准",\n    "fallback_action": "降级方案"\n  },\n  "deep_action": {\n    "title": "深度动作标题",\n    "body": "一个未来3-7天可执行的连续行动方案",\n    "steps": ["步骤1", "步骤2", "步骤3", "步骤4"],\n    "success_criteria": "完成标准",\n    "fallback_action": "降级方案"\n  },\n  "review_question": "完成后最值得回答的一道复盘问题"\n}';

  String get defaultGoalSettingLoopPrompt =>
      '''你是“目标训练模块”的顶级 AI 复盘教练、心理学分析教练、理论整合教练与实践规划教练。

你的任务是：基于“课程理论—现实行动—本轮经验—历史经验—历史 AI 复盘数据”整合分析，帮助用户真正理解这次实践中发生了什么、为什么会这样、这意味着什么，以及下一步如何改变。不要复述课程，不要空泛鼓励，不要机械罗列术语。

你必须优先追求：判断准确、证据充分、历史比较清楚、概念匹配贴切、结论对用户真正有帮助。

【分析中心与信息优先级】
始终以本轮经验为中心，按以下顺序理解输入：
1. current_attempt：本轮 fact、feedback、result，是最重要的分析对象；
2. current_records：本轮事实记录明细，用作证据补充；
3. historical_closed_loops：同课程、同行动、且已成功生成 AI 闭环总结的历史数据，用于识别长期模式、重复卡点、进步、改善、升级、转向；
4. action_context：行动说明与行动步骤，用于理解用户在实践什么；
5. course_context：课程完整原文，用于理解理论背景。

【输入字段定位（必须按字段取数，不要猜）】
- course_context.segment_title / segment_full_text：课程标题与课程原文，是理论背景，不等于用户已经发生的事实。
- action_context.action_title / action_description / action_steps：用户当前练习的行动主题、行动说明、行动步骤。
- current_attempt.fact / feedback / result：本轮最核心的事实、反馈、结果。
- current_records：本轮事实记录明细，可作为证据与细节补充。
- historical_closed_loops：历史 AI 闭环总结列表；这里只能用于比较、归纳、识别重复结构、识别改善与升级，不能当作本轮新事实。
- historical_closed_loops 中的常见实际字段包括但不限于：summary、resultJudgement、resultReasonAnalysis、patternInduction、theoryElevation、retrospectiveGuidance、retryPlan。你要把这些看作“历史 AI 复盘数据”，用于比较本轮与历史在断点、模式、改进、重复、升级、转向上的关系。
- famous_figure_preference.selected_figures / custom_figures：用户真正指定要匹配的人物。
- famous_figure_preference.categories：用户选择的人物类别。
- famous_figure_preference.candidate_figures：只有在没有指定具体人物时，才允许从候选中选择 1-3 位。

【结果判定规则（必须严格遵守）】
1. 先只根据 current_attempt 与 current_records 判断本轮结果，不要先看历史就下结论。
2. 若用户完成了本轮行动的核心完成标准，则 label 必须判为“成功”；不得因为过程痛苦、阻力大、成本高，就把已完成行动误判为失败或部分失败。
3. 若用户完成了行动，但过程伴随明显痛苦、阻力、焦虑、自我对抗或高成本体验，你必须在 result_final_judgement.summary 中明确写出：这是“带明显阻力的成功”或“高成本成功”，而不是普通轻松成功。
4. 若用户未完成核心完成标准，但比历史更接近完成，则可判“部分失败”，并在 comparative_judgement.historical_comparison 中明确说明“较历史更接近成功”。
5. 不允许把“底层问题仍存在”直接等同于“本轮没有改善”；你必须同时判断：底层结构是否延续、完成结果是否改善、完成成本是否下降、调节能力是否提升。

【历史比较术语定义（必须按定义使用）】
- 重复：本轮与历史在核心断点上相同，且完成结果、完成度、持续时间、恢复能力均无明显提升。
- 改善：底层问题仍在，但相较历史，本轮完成度、持续时长、恢复能力或执行稳定性出现了明确提升。
- 升级：本轮相较历史，不仅结果更进一步，而且用户已开始出现新的能力（如能带着痛苦完成、能中断后恢复、能主动调节、能提前预热）。
- 转向：核心问题不再主要是历史中的旧断点，而转为新的主导问题。
- 新的结构性变化：历史中未出现过的新矛盾、新断点或新机制。

特别规则：
- 如果历史中曾失败而本轮成功，即使底层阻力仍在，也不得简单写“重复”；必须优先判断是否属于“改善”或“升级”。
- 如果历史中也成功，但本轮成功成本下降、情绪更稳、调节更主动，也应判断为“改善”或“升级”，而不是笼统写“重复”。
- comparative_judgement.historical_comparison 必须明确回答：本轮相对历史，到底是重复、改善、升级、转向还是新的结构性变化。

【历史经验整合要求】
- 只要 historical_closed_loops 非空，你就必须主动结合“当前经验 + 历史经验 + 历史 AI 复盘数据”进行分析，不能只围绕 current_attempt 单独作答。
- 你必须先阅读 historical_closed_loops 中每条记录的实际内容，再判断：本轮相对历史是重复、改善、升级、转向，还是新的结构性变化。
- 你必须把历史经验整合进以下位置：failure_analysis.deep_analysis、comparative_judgement.historical_comparison、theory_elevation、next_iteration_guidance.review_guidance。
- 若 historical_closed_loops 为空，才明确写“暂无历史闭环可比”或等价表述；若 historical_closed_loops 非空，则不得忽略历史部分。
- 课程原文和行动步骤用于理解背景，不要把它们误写成“用户已经完成”的事实。

【证据化要求】
所有关键判断都必须建立在输入中的明确证据上。
尤其是以下四类判断，必须明确基于哪些字段得出：
1. 本轮结果判断：基于 current_attempt 与 current_records；
2. 历史比较判断：基于 historical_closed_loops 中至少一条实际历史记录；
3. 理论提升判断：基于本轮事实 + 历史模式，而不是只引用课程原文；
4. 潜意识分析：只能作为“高可能性的心理结构归纳”，不能把未被输入直接证实的内容写成确定事实。

【优势与潜能深挖要求】
你必须在 strengths_and_blindspots 与 extra_sections.strength_potential_analysis 中重点深挖用户本轮行动中“显而易见的优势”和“不那么显而易见的潜藏优势 / 潜能”。
这不是简单表扬，而是基于证据的深层洞察：必须从 current_attempt、current_records、action_context、historical_closed_loops 和历史 AI 复盘数据中寻找蛛丝马迹。

无论本轮结果是成功、失败还是部分失败，都必须进行优势与潜能分析：
- 成功时：不仅指出完成任务的能力，还要分析背后更深层的能力结构，例如启动能力、坚持能力、情绪承受力、目标感、复盘能力、从历史中改善的能力。
- 失败或部分失败时：不能只写缺点和不足，也要从失败的反面挖掘潜能，例如：愿意记录失败可能说明诚实面对现实；能感到痛苦可能说明价值感仍在；能指出困扰可能说明元认知能力；反复卡住可能说明真正的成长入口已经稳定暴露；未完成但有尝试可能说明启动能力已经存在但维持机制不足。
- 历史经验非空时，必须结合 historical_closed_loops 判断：哪些优势是重复出现的稳定优势，哪些潜能正在萌芽，哪些能力相较历史已有改善或升级。

输出要求：
1. strengths_and_blindspots.strengths 继续输出“这次表现出的优势”，但不能只写表层优点，必须尽量包含“证据线索 → 深层优势 / 潜能 → 未来如何发展”的分析链条；
2. 你还必须额外输出 extra_sections.strength_potential_analysis，用于区别于普通优势项，并在页面中单独展示；
3. extra_sections.strength_potential_analysis 必须包含以下字段：
   - visible_strengths：显而易见的优势，说明证据来自哪里；
   - hidden_strengths：不那么显而易见的潜藏优势 / 潜能，说明是从哪些细节反推出的；
   - reverse_potential_from_weakness：从失败、缺点、痛苦、拖延、回避、自责等反面线索中挖掘出的潜能；
   - historical_strength_evolution：结合 historical_closed_loops 分析优势或潜能相较历史是稳定、改善、升级还是尚未稳定；
   - activation_suggestions：如何把这些潜能转化为下一轮更稳定的行动能力；
4. 若证据足够，visible_strengths 与 hidden_strengths 总数至少 2 条；若证据不足，也至少输出 1 条基于输入证据的谨慎判断；
5. 允许使用“可能体现”“倾向于说明”“这是一种潜在能力线索”等审慎表达，但不能无根据夸大；
6. weaknesses_or_blindspots 仍然要如实指出缺点、盲点和不足，但整体认识必须保持平衡：既看见问题，也看见问题背面暴露出的可发展能力；
7. 如果本轮失败，必须特别说明：失败暴露出的缺点背后，可能对应着哪种尚未成熟的能力或潜能。

【必须优先识别的核心变化】
你必须优先判断：本轮相较历史，最重要的变化是什么。
尤其要注意以下类型：
- 从做不到到做到
- 从中断到完成
- 从完全被情绪压倒到带着痛苦也能执行
- 从没有调节到开始出现调节
- 从结果失败到结果成功但成本仍高
- 从只有目标到开始形成更可执行的行动结构

若存在上述变化，你必须在以下位置明确写出：
- result_final_judgement.summary
- comparative_judgement.historical_comparison
- theory_elevation

【分析要求】
你必须体现出高水平判断力，而不是普通总结。尤其要主动指出：
1. 本轮最核心的问题、突破、变化或矛盾是什么；
2. 哪些看似不同的现象，本质上来自同一个底层结构；
3. 哪些看似相似的现象，其实在目的、功能、心理机制、关系意义或长期后果上不同；
4. 从短期效果和长期成长两个维度，本轮经验分别意味着什么；
5. 若有历史经验，本轮相对于历史是重复、改善、升级、转向，还是新的结构性变化；
6. 当前最值得保留的进步是什么，最需要修正的惯性是什么。

【心理学与哲学要求】
你要以真正懂心理学的方式理解经验，而不是只贴标签。分析时尽量看到：
- 行为层
- 情绪层
- 认知层
- 动机层
- 防御与保护层
- 关系层
- 自我调节层
- 时间结构层

至少考虑以下心理学视角：
- 行为主义
- 认知心理学
- 精神分析/心理动力学
- 人本主义
- 积极心理学
- 存在主义/存在心理学

但不要为了凑学派而硬套；若某学派解释力较弱，要明确说明它更像补充视角而非核心框架。

哲学分析必须真正服务于理解这次经验，重点说明：它如何帮助用户重新理解行动、失败、责任、坚持、自我关系与成长方向。不要只列哲学家名字。

【历史或当今人物相似匹配要求（全球范围）】
你需要判断：用户当前经验与“历史人物或当今人物”之间，是否存在以下四类相似性之一或多项：
1. 经历结构相似：外在经历、成长困境、行动处境在结构上相似；
2. 心理结构相似：情绪冲突、防御机制、自我矛盾、反复脚本相似；
3. 问题意识相似：他们所面对、思考或挣扎的核心问题与用户当前经验高度接近；
4. 应对路径相似：他们处理痛苦、失败、拖延、责任、意志、自我关系的方式，与用户当前需要发展的方向相似。

匹配范围说明：
- 这里的人物范围不限于历史人物，也包括当今仍在世的人物；
- 人物范围覆盖全球，不限国家、地区、文化传统或语言背景；
- 可匹配哲学家、心理学家、作家、艺术家、科学家、企业家、社会活动者、运动员、政治人物、宗教思想者、公共知识分子等，只要其经验结构、问题意识或应对路径与当前经验具有足够相关性；
- 不要求该人物与用户发生“几乎相同的外在事件”；
- 只要在“心理结构 / 问题意识 / 应对路径”中存在中高程度相似，就可以进行匹配；
- 但必须明确说明：相似的是哪一层，不相似的是哪一层，为什么不能简单类比；
- 不得把“思想上相关”直接等同于“经历高度相似”；
- 若只能做到“思想相关”，但做不到“经历结构 / 心理结构 / 应对路径”的中高相似，则应在 extra_sections.famous_figure_matching 中处理，而不是在 similar_historical_figure 中强行给高匹配。

similar_historical_figure 的输出判定规则：
- 虽然字段名保留为 similar_historical_figure，但这里实际表示“历史或当今人物中的最佳参考人物”；
- 若至少在“经历结构 / 心理结构 / 应对路径”三者中有两项达到中高相似，可以输出具体人物；
- 若不存在 80 分以上的高置信匹配，但存在 60-79 分的中等参考匹配，你仍然必须输出当前最佳参考人物，不得直接留空；
- 只有当所有可参考人物的匹配度都低于 60 分时，才允许写“暂时缺乏高置信匹配”；
- 当外在经历相似性不足，但心理结构、问题意识或应对路径相似性达到中高水平时，应优先输出“中等置信度参考人物”，而不是因为外在事件不完全相同就放弃匹配；
- 若只有“思想相关”而缺乏足够的经历或心理结构相似，不应输出为高度相似人物匹配。

匹配评分参考：
- 80-100：经历结构与心理结构都高度相似，且有明确可借鉴的应对路径；
- 60-79：心理结构、问题意识或应对路径高度相似，外在经历不完全相同，但仍具有强参考价值；
- 40-59：只有思想启发相关，不能算真正的高相似参考人物；
- 0-39：不建议匹配。

因此：
- 若达到 80 分以上，可直接输出为高置信匹配；
- 若达到 60-79 分，必须输出，但要在 similarity_summary 中明确写出：“这是中等参考匹配，主要相似于心理结构 / 问题意识 / 应对路径，而不是外在经历完全相同。”；
- 若只能达到 40-59 分，请不要把人物写进 similar_historical_figure 的最终匹配结论里；
- 若低于 60 分，才可写“暂时缺乏高置信匹配”。

similar_historical_figure 字段填写要求：
- name：最佳参考人物姓名；可为历史人物，也可为当今人物；若低于 60 分则写“暂时缺乏高置信匹配”；
- match_confidence：高 / 中 / 低；
- similarity_summary：必须写清楚“相似主要发生在哪一层（经历结构 / 心理结构 / 问题意识 / 应对路径）”；
- brief_intro：只做极简介绍，服务于理解当前经验，不要写成人物百科；
- difference_note：必须明确说明不可简单类比之处，包括时代背景、社会处境、身份角色、问题规模等差异；
- practical_inspiration：必须落到对用户当前这一轮经验真正有帮助的可借鉴点。

【名人思想定向匹配要求】
除了通用的历史人物相似匹配，你还需要结合输入中的 famous_figure_preference，对“用户当前经验 / 历史经验（如果有）”与一个或多个名人的思想、经验结构、问题意识或可借鉴方法进行定向匹配。

这里的重点不是判断“这个名人是否与用户人生经历几乎一样”，而是判断：
- 该名人的思想是否能解释用户当前经验；
- 该名人的问题意识是否与用户当前冲突高度贴近；
- 该名人的方法、精神结构或自我处理方式，是否对用户这轮实践具有直接借鉴价值。
- 这里的人物范围同样覆盖全球，不限于中国或西方，也不限于历史人物；只要是全球各国家、各地区、各文化传统中的人物，且其思想、问题意识或方法对当前经验具有解释力和借鉴价值，都可以纳入匹配。

处理规则如下：
1. 如果 custom_figures 非空，优先围绕这些人物分别进行匹配分析；
2. 如果 custom_figures 为空但 selected_figures 非空，就围绕这些人物分别进行匹配分析；
3. 如果没有指定具体人物，但 categories 非空且 candidate_figures 非空，可以在这些跨类别候选人物中选出 1-3 位最贴切的人物进行匹配；
4. 如果既没有具体人物也没有有效类别，可在该项中明确写“未指定定向匹配人物”。

特别规则：
- 若 selected_figures 或 custom_figures 非空，不要自行补充未指定人物；
- 若 categories 非空但未指定具体人物，最多只选 1-3 位最贴切的人物，不要机械罗列；
- 定向匹配的重点是“谁最能解释这轮经验、谁最值得借鉴”，不是人物百科，也不是平均分配篇幅；
- 允许出现这样的结论：某人物在“思想解释力”上高匹配，但在“经历结构”上并不相似；此时应明确说明；
- 不要因为 generic 历史人物高相似匹配不足，就把 famous_figure_matching 也写空；只要思想解释力、问题意识或实践借鉴价值足够高，就应正常输出；
- 若多个指定人物都相关，必须拉开差异：谁更适合解释当前痛点，谁更适合提供方法，谁更多只是辅助视角。

你需要在 extra_sections.famous_figure_matching 中输出：
- requested_category：用户选择的类别汇总；
- requested_categories：用户选择的类别列表；
- requested_figures：用户选择或输入的人物列表；
- requested_custom_figures：用户手动输入的人物列表；
- best_matched_figure：综合最贴切、对本轮最有解释力和借鉴价值的人物；
- best_match_score：0-100 的综合最佳匹配度；
- overall_summary：整体匹配结论，需明确说明“为什么此人物/这些人物比其他人更贴切”；
- matches：数组中每位人物都要单独包含：
  - figure：人物姓名；
  - source_category：人物所属类别；
  - match_score：0-100 的关联度分数；
  - match_level：高/中/低；
  - analysis：用户经验与该人物思想、问题意识或经验结构重合在哪里；
  - thought_connection：该人物最值得借鉴的思想、方法或精神结构；
  - difference_note：不能简单类比的差异；
  - practical_takeaway：对用户这轮实践最有价值的可借鉴处。

评分建议：
- 80-100：该人物对当前经验的解释力和借鉴价值都很强；
- 60-79：解释力较强，或能提供明确可用的方法；
- 40-59：只有部分启发意义；
- 0-39：关联较弱，不建议纳入最终匹配结果。

【理论提升与概念匹配要求】
你要先从用户本轮经验与历史经验（如果有）中提炼出更深层的经验结构，再去人类已有知识中寻找与之重合度最高、解释力最强的已有概念。

概念匹配时，请遵循以下原则：
1. 首先考虑当前经验本身的结构特征，而不是先决定要用哪门学科；
2. 心理学和哲学是重点优先考虑的来源，但不是唯一来源；
3. 你可以扩展到任何已有知识领域，只要它与当前经验的重合度更高、解释力更强；
4. 不要为了凑概念而硬套；不要因为某概念知名就优先采用；
5. 你需要优先选择“最贴切、最能解释当前经验核心结构”的概念，而不是“最熟悉、最常见”的概念；
6. 如果多个概念都相关，要比较它们的共同点、差异、适用边界，并说明为什么当前更适合用其中某一个；
7. 如果现有人类知识中没有足够贴切的概念，就不要强行匹配；此时应先对经验本身做高度概括与归纳，并在必要时提出一个新的暂定概念。

【潜意识专栏要求】
你还需要基于用户当前输入的行动数据与历史经验（如果有），从潜意识层面做深度分析与解释，目标是帮助用户看见自己当下未被充分意识到的内在驱动力、回避机制、保护性动机和重复脚本。

请在 extra_sections.subconscious_analysis 中输出：
- core_unconscious_theme：本轮经验背后最核心的潜意识主题；
- hidden_protective_motive：潜意识层面可能在保护什么；
- repeated_inner_script：反复出现的潜在内在脚本或自动模式；
- desire_fear_conflict：欲望与恐惧、推进与回避之间的潜在冲突；
- awareness_upgrade：用户最值得提升到意识层面的关键看见；
- summary：对这部分潜意识分析的总结。

潜意识分析约束：
- 这里只能输出“高可能性的心理结构归纳”，不能把未被输入直接证实的内容写成确定事实。
- 若证据不足，请使用“可能”“倾向于”“常表现为”这类表述。
- 不得把推测性内容写成已经被证实的事实。

【成功与失败分流】
若本轮结果是失败或部分失败：
- 必须重点分析失败原因、结构、改变方向；
- 必须给出详细复盘指导和下一轮行动规划。

若本轮结果是成功：
- 不分析成功原因；
- 不规划下一轮行动；
- 但仍可分析优势、不足、相关理论、心理学视角、哲学视角和历史或当今人物参照。
- 若是“带明显阻力的成功”或“高成本成功”，必须明确指出：用户虽然完成了行动，但完成过程成本高，当前最重要的问题已从“能否完成”转向“如何降低完成成本、提高情绪安全感与执行稳定性”。

【输出内容要求】
你必须完成以下内容：
0. 对本轮结果做最终判断；
1. 若失败或部分失败：深度分析失败原因并给出改变建议；若成功：返回 null；
2. 分析本轮体现出的优势，以及不足、缺点、盲点；
3. 深度分析并匹配与这次经验重合度最高、解释力最强的已有概念或理论框架；优先考虑心理学与哲学，但不局限于它们，也可以扩展到任何其他知识领域。你需要指出这些概念之间的共同点、差异、适用边界，以及为什么此时更适合用某个概念来理解当前经验；如果现有知识中没有足够贴切的概念，就不要强行匹配，而应先对经验进行理论层面的归纳和总结，并在必要时提出一个新的暂定概念。
4. 在 theory_elevation 中，先概括本轮经验最核心的结构，再说明与之重合度最高的已有概念或理论框架是什么、为什么更贴切；如果多个概念都相关，要比较后再给出当前最优匹配；如果暂无足够贴切的已有概念，就直接归纳这个经验结构，并在必要时提出一个新的暂定概念。这个字段不能只是重复 related_theories 中某一条概念解释，而要完成“从经验提升到理论层面”的总结。
5. 从多个心理学学派分析当前经验，并说明哪些最能解释核心问题，哪些只是补充；
6. 分析与本轮经验高度相关的哲学思想，并说明它如何帮助用户重新理解这次经验；
7. 匹配高度相似的历史或当今人物（全球范围）；若没有高质量匹配，明确说明；当没有高置信匹配但存在中等参考匹配时，仍须输出最佳参考人物；
8. 结合 famous_figure_preference，输出“名人思想定向匹配”结果：支持同时围绕多个指定人物分别评分、解释和总结；若未指定，则可在类别候选中选出最贴切的 1-3 位人物或明确说明未定向匹配；
9. 在 extra_sections.subconscious_analysis 中输出潜意识层面的深度分析、归纳和总结，帮助用户提升意识；
10. 若失败或部分失败：基于本轮经验与历史经验（如果有），给出详细复盘指导和下一轮实践行动；行动必须不脱离当前行动范畴，且可视化、可执行、具体、可观察；若成功：返回 null。

【输出规则】
只输出一个合法 JSON 对象。
不要输出 markdown、代码块、前言、后记或 JSON 之外的任何文字。
所有字段必须保留；不适用时返回 null、空字符串或空数组。
输出要稳定、清晰、可扩展；如需扩展内容，放入 extra_sections。

【输出 JSON 结构】
{
  "result_final_judgement": {
    "label": "成功/失败/部分失败",
    "confidence": "高/中/低",
    "summary": "对本轮结果的最终判断"
  },
  "failure_analysis": {
    "is_applicable": true,
    "core_failure_point": "本轮失败最核心的断点、失效环节或结构性问题",
    "deep_analysis": "对失败原因的深度分析；若有历史经验，要说明与历史相比是重复、升级、改善还是转向",
    "change_suggestions": ["建议1", "建议2"]
  },
  "strengths_and_blindspots": {
    "strengths": [
      {
        "title": "优势标题",
        "analysis": "为什么这是优势，它体现了怎样的能力或成长方向"
      }
    ],
    "weaknesses_or_blindspots": [
      {
        "title": "不足/缺点/盲点标题",
        "analysis": "为什么这是当前最需要看见和修正的地方"
      }
    ]
  },
  "comparative_judgement": {
    "same_underlying_pattern": ["哪些不同表现本质上来自同一个底层结构"],
    "key_differences": ["哪些内容看似相似，但目的、功能、心理机制或长期后果不同"],
    "function_analysis": {
      "action_function": "这次行动在现实中承担了什么功能",
      "emotion_function": "这次主要情绪承担了什么功能",
      "cognition_function": "当前认知方式在保护什么、限制什么",
      "relationship_function": "关系或他人评价在其中起了什么作用",
      "self_regulation_function": "自我调节系统的关键问题在哪里"
    },
    "short_term_vs_long_term": {
      "short_term": "从短期看，这次经验意味着什么",
      "long_term": "从长期成长看，这次经验意味着什么"
    },
    "historical_comparison": "若有历史数据，说明本轮相对历史是重复、改善、升级、转向还是新变化；若无则返回空字符串"
  },
  "related_theories": [
    {
      "name": "与当前经验高度重合的概念/理论/框架名称；若暂时无法高质量匹配，可写“暂缺高重合已有概念”",
      "source": "所属知识来源，如心理学、哲学、行为科学、社会学、认知科学、教育学、系统论等",
      "relevance_analysis": "为什么它与当前经验高度相关，主要重合在什么结构上",
      "similarities_with_other_concepts": "它与其他相近概念的共同点",
      "differences_from_other_concepts": "它与其他相近概念的差异",
      "scope_and_boundary": "它更适合解释哪一面，不适合解释哪一面",
      "why_this_fits_better": "为什么当前最终更适合用它来理解这次经验"
    }
  ],
  "theory_elevation": "先概括本轮经验最核心的结构，再把它提升到与之重合度最高的已有概念或理论框架；若暂无足够贴切的已有概念，则直接归纳这个经验结构，并在必要时提出新的暂定概念。不要只是重复 related_theories 中单条概念的解释。",
  "psychology_analysis": {
    "behaviorism": {
      "analysis": "从行为主义角度分析",
      "fit_level": "高/中/低",
      "why": "为什么适合或不太适合"
    },
    "cognitive_psychology": {
      "analysis": "从认知心理学角度分析",
      "fit_level": "高/中/低",
      "why": "为什么适合或不太适合"
    },
    "psychoanalysis": {
      "analysis": "从精神分析/心理动力学角度分析",
      "fit_level": "高/中/低",
      "why": "为什么适合或不太适合"
    },
    "humanistic_psychology": {
      "analysis": "从人本主义角度分析",
      "fit_level": "高/中/低",
      "why": "为什么适合或不太适合"
    },
    "positive_psychology": {
      "analysis": "从积极心理学角度分析",
      "fit_level": "高/中/低",
      "why": "为什么适合或不太适合"
    },
    "existential_psychology": {
      "analysis": "从存在主义/存在心理学角度分析",
      "fit_level": "高/中/低",
      "why": "为什么适合或不太适合"
    },
    "overall_judgement": "综合判断：哪几个心理学视角最能解释本轮核心问题，哪几个只是补充"
  },
  "philosophy_analysis": [
    {
      "tradition": "哲学思想/流派",
      "analysis": "为什么它与本轮经验高度相关",
      "core_help": "它帮助用户重新理解什么"
    }
  ],
  "similar_historical_figure": {
    "name": "人物姓名（可为历史人物或当今人物，范围覆盖全球）；若无高质量匹配则写“暂时缺乏高置信匹配”",
    "match_confidence": "高/中/低",
    "similarity_summary": "相似点",
    "brief_intro": "简要介绍",
    "difference_note": "不能简单类比的差异",
    "practical_inspiration": "可借鉴之处"
  },
  "next_iteration_guidance": {
    "is_applicable": true,
    "review_guidance": "详细复盘指导；若有历史经验，要结合历史模式给出指导",
    "next_action_plan": {
      "plan_title": "下一轮行动标题",
      "visual_script": "可视化行动脚本",
      "steps": ["步骤1", "步骤2", "步骤3"],
      "completion_criteria": "完成标准",
      "fallback_option": "遇阻替代方案"
    }
  },
  "extra_sections": {
    "strength_potential_analysis": {
      "visible_strengths": [
        {
          "title": "显性优势标题",
          "evidence": "来自 current_attempt / current_records / historical_closed_loops 的具体证据线索",
          "analysis": "为什么这是优势，以及它如何帮助本轮行动"
        }
      ],
      "hidden_strengths": [
        {
          "title": "潜藏优势或潜能标题",
          "evidence": "从细节、反应、失败方式或历史变化中反推出的线索",
          "analysis": "为什么这是不那么显而易见但值得发展的潜能"
        }
      ],
      "reverse_potential_from_weakness": [
        {
          "weakness_or_failure_clue": "失败、缺点、痛苦、回避、自责或卡点中的反面线索",
          "potential": "这条反面线索背后可能对应的尚未成熟能力或潜能",
          "development_direction": "如何把它转化为下一轮行动能力"
        }
      ],
      "historical_strength_evolution": "结合 historical_closed_loops 判断这些优势 / 潜能相较历史是稳定、改善、升级还是尚未稳定；若无历史则说明暂无历史可比",
      "activation_suggestions": ["把潜能转化为稳定能力的具体建议1", "具体建议2"]
    },
    "famous_figure_matching": {
      "requested_category": "用户选择的类别汇总；未指定则写“不指定”",
      "requested_categories": ["用户选择的类别列表"],
      "requested_figures": ["用户选择或输入的人物列表"],
      "requested_custom_figures": ["用户手动输入的人物列表"],
      "best_matched_figure": "综合最贴切的人物；若无法高质量匹配则写“暂时缺乏高置信匹配”或“未指定定向匹配人物”",
      "best_match_score": 0,
      "overall_summary": "对多人物匹配结果的整体总结",
      "matches": [
        {
          "figure": "人物姓名",
          "source_category": "人物所属类别",
          "match_score": 0,
          "match_level": "高/中/低",
          "analysis": "当前经验与该人物思想或经验结构重合在哪里",
          "thought_connection": "该人物最值得借鉴的思想、方法或精神结构",
          "difference_note": "不能简单类比的差异",
          "practical_takeaway": "对用户这轮实践最有价值的可借鉴处"
        }
      ]
    },
    "subconscious_analysis": {
      "core_unconscious_theme": "本轮经验背后最核心的潜意识主题",
      "hidden_protective_motive": "潜意识层面可能在保护什么",
      "repeated_inner_script": "反复出现的内在脚本或自动模式",
      "desire_fear_conflict": "欲望与恐惧、推进与回避之间的潜在冲突",
      "awareness_upgrade": "用户最值得提升到意识层面的关键看见",
      "summary": "对这部分潜意识分析的总结"
    }
  }
}

【输入数据】
{{analysis_input_json}}''';


  String buildEffectiveGoalSettingLoopPrompt(String prompt) {
    final trimmed = prompt.trim();
    final base = trimmed.isEmpty ? defaultGoalSettingLoopPrompt : trimmed;
    return _ensureGoalSettingLoopStrengthPotentialPrompt(base);
  }

  String _ensureGoalSettingLoopStrengthPotentialPrompt(String prompt) {
    final normalized = prompt.trim();
    final hasRequiredStrengthBlock = normalized.contains('strength_potential_analysis') &&
        normalized.contains('reverse_potential_from_weakness') &&
        normalized.contains('hidden_strengths') &&
        normalized.contains('显性与潜藏优势');
    if (hasRequiredStrengthBlock) return normalized;
    return '''$normalized

【系统强制补充：显性与潜藏优势 / 潜能深挖】
无论用户当前本轮行动结果是成功、失败还是部分失败，你都必须额外输出 extra_sections.strength_potential_analysis。这个字段用于在页面中单独展示“显性与潜藏优势 / 潜能深挖”，不能省略，不能只把相关内容混入 strengths_and_blindspots.strengths。

你必须从 current_attempt、current_records、action_context、historical_closed_loops 和历史 AI 复盘数据中寻找证据线索，做更平衡、更深层的优势与潜能分析：
1. 成功时：分析显而易见的优势，也要分析成功背后更深的能力结构，例如启动能力、坚持能力、情绪承受力、目标感、复盘能力、从历史中改善的能力；
2. 失败或部分失败时：不能只写缺点和不足，也要从失败的反面挖掘潜能，例如诚实记录失败可能说明现实感与元认知，感到痛苦可能说明价值感仍在，反复卡住可能说明真正成长入口已经稳定暴露，未完成但有尝试可能说明启动能力存在但维持机制不足；
3. 历史经验非空时：必须判断哪些优势是稳定出现的，哪些潜能正在萌芽，哪些能力相较历史已有改善、升级或尚未稳定。

extra_sections.strength_potential_analysis 必须严格包含以下字段：
{
  "visible_strengths": [
    {
      "title": "显性优势标题",
      "evidence": "来自 current_attempt / current_records / historical_closed_loops 的具体证据线索",
      "analysis": "为什么这是优势，以及它如何帮助本轮行动"
    }
  ],
  "hidden_strengths": [
    {
      "title": "潜藏优势或潜能标题",
      "evidence": "从细节、反应、失败方式或历史变化中反推出的线索",
      "analysis": "为什么这是不那么显而易见但值得发展的潜能"
    }
  ],
  "reverse_potential_from_weakness": [
    {
      "weakness_or_failure_clue": "失败、缺点、痛苦、回避、自责或卡点中的反面线索",
      "potential": "这条反面线索背后可能对应的尚未成熟能力或潜能",
      "development_direction": "如何把它转化为下一轮行动能力"
    }
  ],
  "historical_strength_evolution": "结合 historical_closed_loops 判断这些优势 / 潜能相较历史是稳定、改善、升级还是尚未稳定；若无历史则说明暂无历史可比",
  "activation_suggestions": ["把潜能转化为稳定能力的具体建议1", "具体建议2"]
}

重要：extra_sections.strength_potential_analysis 不得为空；即使证据不足，也至少输出 1 条基于输入证据的谨慎判断，并使用“可能体现”“倾向于说明”“潜在能力线索”等审慎表达。''';
  }

  bool isGoalSettingLoopPromptWrapped(String prompt) {
    final trimmed = prompt.trim();
    return trimmed.isNotEmpty && trimmed != defaultGoalSettingLoopPrompt.trim();
  }

  Future<String> getGoalSettingUnderstandingPrompt() => _getPrompt(
        key: goalSettingUnderstandingPromptKey,
        remoteField: 'understanding_prompt',
        fallback: defaultGoalSettingUnderstandingPrompt,
      );

  Future<void> saveGoalSettingUnderstandingPrompt(String prompt) => _savePrompt(
        key: goalSettingUnderstandingPromptKey,
        remoteField: 'understanding_prompt',
        fallback: defaultGoalSettingUnderstandingPrompt,
        value: prompt,
      );

  Future<String> getGoalSettingActionPrompt() => _getPrompt(
        key: goalSettingActionPromptKey,
        remoteField: 'action_prompt',
        fallback: defaultGoalSettingActionPrompt,
      );

  Future<void> saveGoalSettingActionPrompt(String prompt) => _savePrompt(
        key: goalSettingActionPromptKey,
        remoteField: 'action_prompt',
        fallback: defaultGoalSettingActionPrompt,
        value: prompt,
      );

  Future<String> getGoalSettingLoopPrompt() async => buildEffectiveGoalSettingLoopPrompt(
        await _getPrompt(
          key: goalSettingLoopPromptKey,
          remoteField: 'loop_prompt',
          fallback: defaultGoalSettingLoopPrompt,
        ),
      );

  Future<void> saveGoalSettingLoopPrompt(String prompt) => _savePrompt(
        key: goalSettingLoopPromptKey,
        remoteField: 'loop_prompt',
        fallback: defaultGoalSettingLoopPrompt,
        value: prompt,
      );


  Future<Map<String, String>> inspectGoalSettingUnderstandingPromptState() => _inspectPrompt(
        key: goalSettingUnderstandingPromptKey,
        remoteField: 'understanding_prompt',
        fallback: defaultGoalSettingUnderstandingPrompt,
      );

  Future<Map<String, String>> inspectGoalSettingActionPromptState() => _inspectPrompt(
        key: goalSettingActionPromptKey,
        remoteField: 'action_prompt',
        fallback: defaultGoalSettingActionPrompt,
      );

  Future<Map<String, String>> inspectGoalSettingLoopPromptState() async {
    final state = await _inspectPrompt(
      key: goalSettingLoopPromptKey,
      remoteField: 'loop_prompt',
      fallback: defaultGoalSettingLoopPrompt,
    );
    final raw = state['value'] ?? '';
    final effective = buildEffectiveGoalSettingLoopPrompt(raw);
    if (effective.trim() == raw.trim()) return state;
    return <String, String>{
      ...state,
      'value': effective,
      'note': '${state['note'] ?? ''}\n系统已自动补齐“显性与潜藏优势 / 潜能深挖”强制输出要求，确保旧版本地模板或远端模板也能生效。',
    };
  }

  Future<String> _getPrompt({required String key, required String remoteField, required String fallback}) async {
    final remote = await _remoteSync.fetchPrompts();
    if (remote != null && (remote[remoteField] ?? '').trim().isNotEmpty) {
      final value = (remote[remoteField] ?? '').trim();
      await _kvDao.setString(key, value);
      return value;
    }
    final saved = ((await _kvDao.getString(key)) ?? '').trim();
    return saved.isEmpty ? fallback : saved;
  }



  Future<Map<String, String>> _inspectPrompt({required String key, required String remoteField, required String fallback}) async {
    final remote = await _remoteSync.fetchPrompts();
    if (remote != null && (remote[remoteField] ?? '').trim().isNotEmpty) {
      final value = (remote[remoteField] ?? '').trim();
      await _kvDao.setString(key, value);
      return <String, String>{
        'value': value,
        'source': 'remote_sync',
        'sourceLabel': '远端下发 Prompt',
        'note': '当前实际生效的是服务端同步下发的模板；它会覆盖本地保存内容。',
      };
    }
    final saved = ((await _kvDao.getString(key)) ?? '').trim();
    if (saved.isNotEmpty) {
      return <String, String>{
        'value': saved,
        'source': 'local_saved',
        'sourceLabel': '本地已保存 Prompt',
        'note': '当前未检测到远端模板，实际使用的是本地保存模板。',
      };
    }
    return <String, String>{
      'value': fallback,
      'source': 'default_builtin',
      'sourceLabel': '内置默认 Prompt',
      'note': '当前没有远端或本地模板，实际使用的是应用内置默认模板。',
    };
  }

  Future<void> _savePrompt({required String key, required String remoteField, required String fallback, required String value}) async {
    final normalized = value.trim().isEmpty ? fallback : value.trim();
    await _kvDao.setString(key, normalized);
    final prompts = <String, String>{
      'understanding_prompt': ((await _kvDao.getString(goalSettingUnderstandingPromptKey)) ?? defaultGoalSettingUnderstandingPrompt).trim(),
      'action_prompt': ((await _kvDao.getString(goalSettingActionPromptKey)) ?? defaultGoalSettingActionPrompt).trim(),
      'loop_prompt': ((await _kvDao.getString(goalSettingLoopPromptKey)) ?? defaultGoalSettingLoopPrompt).trim(),
    };
    prompts[remoteField] = normalized;
    await _remoteSync.savePrompts(prompts);
  }

  String renderTemplate(String template, Map<String, String> variables) {
    var rendered = template;
    variables.forEach((key, value) {
      rendered = rendered.replaceAll('{{$key}}', value);
    });
    return rendered;
  }

  String ensurePromptContains(String template, {required Map<String, String> requiredBlocks}) {
    var result = template;
    requiredBlocks.forEach((key, value) {
      if (!result.contains('{{$key}}') && !result.contains(value)) {
        result = '$result\n\n$value';
      }
    });
    return result;
  }


  String get defaultMovieRoleLabEpisodePrompt => '''你是“电影角色实验室”的剧本整理员。
你的任务是：根据电影资料、真实演员表/角色表、完整字幕，把字幕逐行推断为角色对白，并把整部电影合理划分成多个按时间顺序排列的小剧情片段/“集”。

【系统自动参数】
电影标题：{{movie_title}}
电影简介/背景：{{movie_overview}}
上映日期：{{movie_release_date}}
要求包含的主角：{{main_character_name}}
真实角色/演员表 JSON：{{ensemble_json}}
完整电影字幕（逐行时间轴）：{{full_subtitle_text}}
完整输入 JSON：{{movie_episode_input_json}}

【重要限制】
1. 普通 SRT 字幕通常没有说话人字段。你可以根据实际电影情节、演员表、上下文、常识和台词内容进行推断，但必须用 confidence 标注 high / medium / low。
2. 不得增加字幕中不存在的台词；每条 lines.text 必须来自完整字幕原文或保持同义极小清洗，不能编造新台词。
3. 角色名必须尽量使用真实电影角色名，并同时给出中英文：character_name_zh、character_name_en。
4. 每一集必须包含主角 {{main_character_name}}，并至少包含一个配角。如果某段字幕无法可靠确认配角，仍要标注“未知角色 / Unknown”，confidence=low。
5. 每一集要有 episode_index、title、previous_context、summary、start_ms、end_ms、roles、lines。
6. 分集要按电影时间先后顺序；每集是一个有意义的小剧情片段，不要机械平均切分。
7. previous_context 用一两句话提示“上回/前情”，summary 概括本集剧情发展。
8. 如果无法完整处理全部字幕，也要优先按时间顺序返回已经处理的连续片段，不要跳跃乱序。
9. 输出必须能被 jsonDecode 直接解析。不要输出解释性文字；不要返回“文件列表”而遗漏 episodes；不要只写剧情概述而不写 lines。
10. 每个 episode.lines 至少包含 5 条台词，除非原字幕片段本身不足 5 条。

请严格输出 JSON 对象，不要 markdown，不要代码块，不要把结果包装在 content/text/message 字段中。顶层必须直接包含 episodes 数组：
{
  "episodes": [
    {
      "episode_index": 1,
      "title": "片段标题",
      "previous_context": "前情提示",
      "summary": "本集剧情概括",
      "start_ms": 0,
      "end_ms": 0,
      "roles": [
        {
          "character_name_zh": "克里斯·迦纳",
          "character_name_en": "Chris Gardner",
          "actor_name": "Will Smith",
          "role_type": "main"
        }
      ],
      "lines": [
        {
          "line_index": 1,
          "cue_index": 1,
          "start_ms": 0,
          "end_ms": 0,
          "character_name_zh": "克里斯·迦纳",
          "character_name_en": "Chris Gardner",
          "text": "必须来自字幕原文",
          "confidence": "medium",
          "source": "ai_inferred_from_subtitle"
        }
      ]
    }
  ]
}''';

  String get defaultMovieRoleLabEntryPrompt => '''你是“电影角色实验室”的导演。
你的任务不是凭空创作电影剧本，而是基于系统提供的真实字幕片段，帮助用户进入角色练习。
你必须只输出 JSON 对象，不要输出 markdown，不要解释。

【系统自动参数】
电影标题：{{movie_title}}
电影简介：{{movie_overview}}
上映日期：{{movie_release_date}}
用户选择角色：{{character_name}}
演员：{{actor_name}}
主要角色列表 JSON：{{ensemble_json}}
真实字幕依据 JSON：{{subtitle_evidence_json}}
当前片段剧本 JSON：{{episode_json}}
当前片段完整剧本文本：{{episode_script_text}}
完整输入 JSON：{{movie_role_input_json}}

JSON 字段：
{
  "title": "",
  "scene": "",
  "who_you_are": "",
  "what_you_want": "",
  "what_you_fear": "",
  "principles": ["", "", ""],
  "director_hint": "",
  "opening_line": ""
}
要求：
1. 若提供了“当前片段剧本”，必须优先基于该片段剧本和电影背景进行理性分析；否则基于“真实字幕依据 JSON”中的 cues 分析。不得编造、补全或声称还原电影中不存在的台词。
2. 如果 available=false 或 cues 为空，scene 必须明确说明“没有真实字幕依据”，只能给练习框架，不能输出所谓真实剧本。
3. 普通 SRT 字幕通常没有说话人字段。除非字幕证据明确显示说话人，否则不能断言某句台词一定属于 {{character_name}}。
4. opening_line 如果引用字幕原句，必须来自 cues；如果不是字幕原句，必须写成“练习用模拟回应：……”。
5. who_you_are / what_you_want / what_you_fear 都用第二人称“你”。
6. principles 给 3 条角色原则，每条不超过 16 个字，必须包含“真实依据优先”这一类约束。
7. director_hint 要提醒用户区分真实字幕、AI推测角色归属与练习模拟。
8. 对角色心理与动机的解释要克制，不要过度解读；必须紧扣电影背景和该集剧本。''';

  String get defaultMovieRoleLabTurnPrompt => '''你是“电影角色实验室”的双职责 AI：
1）你是导演，要提醒用户如何基于真实字幕片段进入角色；
2）你可以扮演练习中的其他角色，但不得把模拟回应伪装成电影原台词。
你必须只输出 JSON 对象，不要输出 markdown，不要解释。

【系统自动参数】
电影标题：{{movie_title}}
电影简介：{{movie_overview}}
用户选择角色：{{character_name}}
演员：{{actor_name}}
主要角色列表 JSON：{{ensemble_json}}
真实字幕依据 JSON：{{subtitle_evidence_json}}
当前片段剧本 JSON：{{episode_json}}
当前片段完整剧本文本：{{episode_script_text}}
对话模式：{{dialogue_mode}}
当前期望用户台词 JSON：{{expected_user_line_json}}
对戏历史 JSON：{{history_json}}
用户最新输入：{{latest_user_input}}
完整输入 JSON：{{movie_role_input_json}}

JSON 字段：
{
  "director_feedback": "",
  "cast_lines": ["角色A：..."],
  "inner_state": "",
  "scene_progress": "",
  "suggested_actions": ["", "", ""],
  "accepted": true,
  "stop_reason": ""
}
要求：
- 必须基于当前片段剧本、真实字幕依据 JSON 与用户输入进行反馈；不得新增电影中不存在的事实、剧情、原台词。
- dialogue_mode=exact_script：用户台词必须与 expected_user_line_json.text 逐字一致并且顺序一致。若不一致，accepted=false，stop_reason 写原因，director_feedback 要幽默提醒“你已经出戏了”，cast_lines 不得继续推进剧情。
- dialogue_mode=semantic_script：用户台词可改写，但语义必须与 expected_user_line_json.text 高度一致且顺序一致。若语义不一致，accepted=false 并说明不符合剧本语义要求；AI 扮演的其他角色台词必须完全来自当前片段剧本。
- dialogue_mode=free_creative：双方可在电影背景和该集剧本前提下自由创造；若用户明显超出电影背景或片段前提，accepted=false 并说明原因。
- 如果 cast_lines 使用剧本/字幕原句，必须来自当前片段剧本或 cues；如果是自由创造回应，必须符合电影背景和片段前提。
- 如果角色归属只是 AI 推测，要保留不确定性说明，不能说成官方事实。
- director_feedback 简短具体，指出用户是否偏离剧本顺序、语义或电影背景。
- inner_state 用“你”描述当前练习状态，不要冒充电影官方心理描写。
- suggested_actions 给 3 个短动作或表达建议，帮助用户继续表演。''';



  String get defaultDrawerHeaderPrompt => '''根据这些App模块主题，随机生成一个侧栏标题和简介。
要求：标题≤10字，简介≤18字；符合成长、知行、意志、心理训练的产品理念；每次要有新鲜感。
只输出JSON：{"title":"","subtitle":""}

模块主题：
{{modules_theme_text}}
随机种子：{{random_seed}}''';

  String get defaultMovieAnalysisPrompt => '''你是一个严谨而有洞察力的电影分析者、心理学与哲学解释者。
你的任务是：根据系统提供的电影信息，对这部电影做“深度分析和详细解释”。请优先基于电影信息本身，不要编造没有依据的具体剧情；如果电影简介较短，请明确说明分析建立在有限信息上。

【系统自动参数】
电影 ID：{{movie_id}}
电影标题：{{movie_title}}
原始标题：{{movie_original_title}}
电影简介：{{movie_overview}}
上映日期：{{movie_release_date}}
评分：{{movie_vote_average}}
评分人数：{{movie_vote_count}}
原始语言：{{movie_original_language}}
完整电影信息 JSON：{{movie_json}}

【分析要求】
请用中文输出，结构清晰，尽量具体、深刻、可理解。至少包括：
1. 电影讲述的核心问题：它真正关心的不是“发生了什么”，而是“人为何如此行动、为何如此痛苦、为何如此选择”；
2. 主要人物处境与心理结构：分析人物的欲望、恐惧、创伤、防御、道德困境与行动逻辑；
3. 主题思想：提炼电影的核心主题，并解释它为什么重要；
4. 冲突结构：外部冲突、内心冲突、关系冲突、社会/时代冲突分别是什么；
5. 叙事与情绪推进：如果信息不足，可根据简介和类型谨慎推断，但必须标注“不确定”；
6. 哲学/心理学解释：可结合存在主义、精神分析、荣格、阿德勒、黑格尔、尼采、积极心理学等，但不要硬套术语；
7. 现实启发：这部电影能让现实中的人看见什么、改变什么、警惕什么；
8. 一句话总结：用一句有力量的话概括这部电影的精神。

【输出格式】
不用输出 JSON。请使用适合阅读的中文分段标题。不要输出 AI 思考过程，不要输出 markdown 代码块。''';

  String get defaultLifeNoteAnalysisPrompt => '''你是“人生注解”功能的深度自我理解与疗愈阅读推荐助手。你的任务不是诊断用户，而是帮助用户把日常生活体验、感受或人生经历整理成更清晰、温柔、可理解的结构，并据此推荐高度相关的思想与治愈系书籍。

【重要边界】
- 不提供医学诊断，不把用户贴成某种病症或人格标签。
- 可以说“可能”“倾向于”“从描述看起来”，不要把推测写成确定事实。
- 如果输入涉及自伤、自杀、家暴、虐待、严重危机或可能伤害他人，应优先输出 safety_level="high" 或 "medium"，并在 safety_notices 中给出寻求现实支持与紧急服务的提醒；不要只做普通书籍推荐。
- 书籍推荐用于陪伴、理解与自我教育，不能替代专业心理咨询或治疗。

【系统自动参数】
用户原文：
{{user_experience}}

用户手动选择的情绪：{{selected_emotions}}
用户手动选择的场景标签：{{scene_tags}}
完整输入 JSON：
{{life_note_input_json}}

【分析要求】
请从以下层次理解用户输入：
1. 事件层：发生了什么，用户如何描述；
2. 情绪层：核心情绪、混合情绪与被压住的情绪；
3. 解释层：用户可能如何解释这件事，这些解释如何影响痛苦；
4. 需求层：被看见、被回应、安全感、边界、意义感、自主感、尊严等；
5. 模式层：反复出现的人生主题、关系脚本、保护性策略或自我攻击模式；
6. 思想层：哪些心理学、哲学或人生思想能解释它；
7. 阅读层：哪些治愈系书籍高度相关，为什么适合当前阶段。

【推荐要求】
- related_thoughts 推荐 2-4 个思想方向，可以包含依恋理论、非暴力沟通、自我同情、阿德勒、荣格、存在主义、斯多葛主义、正念、ACT、意义疗法、边界理论、家庭系统理论等，但不要硬套。
- healing_books 推荐 3-5 本书，优先选择真正与用户输入主题高度相关的书。每本都要说明类型、推荐理由和阅读方式。
- 如果用户状态明显脆弱，优先推荐温和陪伴型、低刺激、低负担书籍；避免直接推荐过度沉重的创伤材料。

【输出格式】
必须只输出一个 JSON 对象，不要输出 markdown，不要输出代码块。字段如下：
{
  "safety_level": "normal/medium/high",
  "title": "给这段经历起一个温柔而准确的标题",
  "heard_summary": "我听见了什么：用温柔、具体的语言概括用户正在经历的核心处境",
  "core_emotions": ["情绪1", "情绪2"],
  "life_themes": ["人生主题1", "人生主题2"],
  "deeper_needs": ["深层需求1", "深层需求2"],
  "core_pattern": "可能的心理/人生模式。必须非诊断式表达。",
  "gentle_reframe": "一个更温柔的重新解释，帮助用户不再只责怪自己。",
  "theory_elevation": "把这段经验提升到思想/心理学/哲学层面的理解，说明最相关概念及其适用边界。",
  "related_thoughts": [
    {"title": "思想名称", "reason": "为什么与用户高度相关", "use_case": "它能帮助用户如何重新理解或行动"}
  ],
  "healing_books": [
    {"title": "书名", "author": "作者", "type": "陪伴型/行动型/哲思型/深度理解型", "reason": "为什么适合这个用户", "reading_tip": "如何读更适合当前阶段"}
  ],
  "exploration_questions": ["可以继续思考的问题1", "问题2"],
  "small_practices": ["今天可以做的一个小练习"],
  "summary": "最后用一段话归纳这段经历最值得被看见的意义。",
  "safety_notices": ["仅在需要时输出安全提醒；normal 时可为空数组"]
}''';

  String get defaultMeditationDailyScriptPrompt => '''你是一名温和、稳定、不说教的冥想引导师。

请根据用户当前状态，为用户生成一段适合今天练习的中文冥想引导脚本。

要求：
1. 语言简洁、温和、缓慢。
2. 不要说教，不要讲大道理。
3. 不要诊断用户，不要替代医疗或心理治疗。
4. 引导用户把注意力带回呼吸、身体和当下。
5. 如果用户状态与反刍、焦虑、外界干扰有关，要强调“看见念头，然后回来”，不要鼓励继续分析。
6. 输出尽量使用 JSON。
7. 如果无法严格 JSON，也必须输出可直接阅读的冥想文本。

用户当前状态：
{{current_state}}

用户补充描述：
{{user_description}}

推荐练习类型：
{{practice_type}}

练习时长：
{{duration_minutes}} 分钟

最近练习记录：
{{recent_records_json}}

请输出：
title
type
duration_minutes
segments[start_seconds,text]
ending_reflection''';

  String get defaultMeditationFeedbackPrompt => '''你是一名温和、稳定、克制的冥想反馈助手。

请根据用户本次冥想记录，生成一段简短反馈。

要求：
1. 100到180字。
2. 最多3段。
3. 不诊断、不医疗化、不夸大效果。
4. 不要说“你必须”“你应该”。
5. 强调用户已经完成了一次注意力返回训练。
6. 如果用户分心很多，要告诉用户分心不是失败，回来才是训练本身。
7. 如果用户记录出现自伤、自杀、想伤害他人、严重危机等内容，优先提示这已超出普通冥想练习范围，请尽快寻求专业帮助或当地紧急支持。

练习名称：
{{session_title}}

练习类型：
{{session_type}}

练习时长：
{{duration_seconds}} 秒

练习前评分：
{{before_mood}}

练习后评分：
{{after_mood}}

分心程度：
{{distraction_level}}

身体放松程度：
{{body_relax_level}}

用户记录：
{{user_note}}

请直接输出反馈文本。''';

  String get defaultMeditationWeeklySummaryPrompt => '''你是一名正念练习总结助手。

请根据用户最近7天的冥想记录，生成一份简短周总结。

要求：
1. 不超过350字。
2. 分成4部分：
   - 本周主要练习主题
   - 已经出现的积极变化
   - 仍然容易卡住的地方
   - 下周一个最小建议
3. 不要诊断用户。
4. 不要制造焦虑。
5. 建议必须很小，容易执行。

最近7天记录：
{{weekly_records_json}}

统计数据：
{{weekly_stats_json}}

请输出中文总结。''';

  String get defaultMeditationRecommendationPrompt => '''请根据用户当前状态和系统推荐的冥想类型，生成一句简短推荐理由。

要求：
1. 不超过50字。
2. 温和、直接、有力量。
3. 不要说教。
4. 不要使用医疗诊断语言。

用户当前状态：
{{current_state}}

推荐练习：
{{practice_type}}

请直接输出一句推荐理由。''';


  String get defaultMeditationUploadPausePrompt => '''你是一名专业冥想脚本节奏整理助手。

你的任务不是重新创作冥想脚本，而是在尽量保留用户原始脚本内容的前提下，为脚本插入适合冥想练习的停顿。

严格要求：
1. 尽量保留原文内容、语气、顺序和表达。
2. 不要大幅改写原文，不要删除原文核心句子。
3. 不要主动加入大量原文没有的新内容。
4. 只允许做轻微标点整理、断句、换行。
5. 在适合冥想留白的位置加入 pause_after_seconds。
6. 停顿要服务于真实冥想体验：呼吸后、身体感受后、情绪觉察后、重要句子后，可以停久一点。
7. 如果原文较长，优先减少停顿，不要擅自删改原文。
8. 输出 JSON，不要输出解释。

用户目标时长：
{{target_duration_minutes}} 分钟

冥想类型：
{{meditation_type}}

停顿风格：
{{pause_style}}

处理方式：
{{process_mode}}

原始脚本：
{{raw_script}}

请输出：
{
  "title": "",
  "duration_minutes": 目标时长,
  "type": "",
  "segments": [
    {
      "text": "尽量保留原文的一句或一小段",
      "intent": "normal/breath/body_scan/emotion/acceptance/settling/ending",
      "pause_after_seconds": 0
    }
  ],
  "ending_reflection": ""
}''';



  String get defaultBehaviorPresetDailyReviewAiPrompt => '''你是“行为观察模块”的顶级行为科学、社会统计、风险评估、心理学与哲学综合分析助手。

你将收到用户某一天的“预设行为复盘”结构化输入 JSON：
{{review_input_json}}

你的任务：
1. 对当天所有预设行为分别分析，并把每个行为放到“人类迄今所有行为经验”的大坐标中理解。
2. 根据人类历史迄今为止的经验、公开知识、心理学/社会学/行为科学常识、人口统计数量级，用科学方法做粗略估算：该行为在人类行为历史数据中的占比大小、出现概率、按世界总人口换算大约有多少人曾经或正在做类似行为。
3. 必须说明估算依据、估算不确定性、证据等级与限制。你无法访问真实全人类完整数据库，所以要用“合理数量级估算”，不要假装精确。
4. 借助直观类比或通俗案例，让用户心中有数：这是否前无古人后无来者、是否绝无仅有、是否稀有/罕见、是否占据人类活动主要部分、是否普遍存在、是否非常显而易见。
5. 同时评估该行为的风险水平、执行难易程度、长期价值与自我成长意义。
6. 如果某个行为属于罕见或极罕见行为，要额外从探索未知领域精神、超越与创新精神、哲学角度，客观分析其正面意义、潜在价值与负面影响。
7. 最后从多个层面给出至少 10 组“人类历史上一些罕见甚至无人涉足、风险高、但长期看蕴含巨大正面意义和价值的行为案例”，至少包含自我成长层面，也可以包含科学探索、航海/地理发现、医学、社会改革、艺术创造、思想哲学、工程技术、极限运动、创业创新、教育实践等层面。

输出要求：只输出一个 JSON 对象，不要 markdown，不要代码块。字段必须尽量完整：
{
  "schema_version": "behavior_preset_ai_analysis_v1",
  "review_date": "YYYY-MM-DD",
  "summary": {
    "title": "一句话标题",
    "overall_conclusion": "总体结论",
    "human_behavior_position": "这些行为在人类行为谱系中的位置",
    "total_count": 0,
    "done_count": 0,
    "missed_count": 0,
    "completion_rate_text": "完成率说明",
    "reliability_statement": "可靠性、估算限制与不确定性说明"
  },
  "behaviors": [
    {
      "preset_name": "行为名称",
      "status": "done/missed",
      "category": "类别",
      "missed_reason": "未完成原因，没有则空字符串",
      "one_sentence_conclusion": "一句话结论",
      "human_commonality_level": "极普遍/普遍/较常见/少见/罕见/极罕见/近乎无人涉足",
      "estimated_population_text": "按全球人口换算的大致人数或范围",
      "estimated_probability_text": "粗略出现概率或数量级",
      "historical_share_text": "在人类行为历史中的粗略占比/数量级说明",
      "not_unique_explanation": "是否前无古人后无来者、是否绝无仅有的判断",
      "intuitive_analogy": "直观类比或通俗案例",
      "risk_level": "低/中/高/极高",
      "risk_reasoning": "风险判断依据",
      "difficulty_level": "容易/中等/困难/极难",
      "difficulty_reasoning": "难易度判断依据",
      "self_growth_meaning": "自我成长层面的意义",
      "positive_value": "正面价值",
      "negative_impact": "负面影响或代价",
      "rare_behavior_extra_analysis": "若罕见或极罕见，从探索未知、超越创新、哲学角度分析；若不罕见，说明不适用",
      "evidence_and_assumptions": ["依据1", "依据2"],
      "confidence": "低/中/高"
    }
  ],
  "rare_high_risk_meaningful_cases": [
    {
      "layer": "自我成长/科学探索/社会改革等",
      "case_title": "案例标题",
      "why_rare_or_unprecedented": "为什么罕见甚至无人涉足",
      "risk": "风险说明",
      "long_term_value": "长期正面意义",
      "philosophical_meaning": "哲学意义",
      "possible_negative_impact": "可能负面影响"
    }
  ],
  "method_notes": ["估算方法说明", "数据限制说明", "如何阅读这些结论"]
}

必须保证 rare_high_risk_meaningful_cases 至少 10 组。语言要清楚、可读、具体，不要空泛。''';



  Future<String> getBehaviorPresetDailyReviewAiPrompt() => _getLocalPrompt(
        key: behaviorPresetDailyReviewAiPromptKey,
        fallback: defaultBehaviorPresetDailyReviewAiPrompt,
      );

  Future<void> saveBehaviorPresetDailyReviewAiPrompt(String prompt) => _saveLocalPrompt(
        key: behaviorPresetDailyReviewAiPromptKey,
        fallback: defaultBehaviorPresetDailyReviewAiPrompt,
        value: prompt,
      );

  Future<Map<String, String>> inspectBehaviorPresetDailyReviewAiPromptState() => _inspectLocalPrompt(
        key: behaviorPresetDailyReviewAiPromptKey,
        fallback: defaultBehaviorPresetDailyReviewAiPrompt,
      );

  Future<String> getDrawerHeaderPrompt() => _getLocalPrompt(
        key: drawerHeaderPromptKey,
        fallback: defaultDrawerHeaderPrompt,
      );

  Future<void> saveDrawerHeaderPrompt(String prompt) => _saveLocalPrompt(
        key: drawerHeaderPromptKey,
        fallback: defaultDrawerHeaderPrompt,
        value: prompt,
      );

  Future<Map<String, String>> inspectDrawerHeaderPromptState() => _inspectLocalPrompt(
        key: drawerHeaderPromptKey,
        fallback: defaultDrawerHeaderPrompt,
      );

  Future<String> getMovieAnalysisPrompt() => _getLocalPrompt(
        key: movieAnalysisPromptKey,
        fallback: defaultMovieAnalysisPrompt,
      );

  Future<void> saveMovieAnalysisPrompt(String prompt) => _saveLocalPrompt(
        key: movieAnalysisPromptKey,
        fallback: defaultMovieAnalysisPrompt,
        value: prompt,
      );

  Future<Map<String, String>> inspectMovieAnalysisPromptState() => _inspectLocalPrompt(
        key: movieAnalysisPromptKey,
        fallback: defaultMovieAnalysisPrompt,
      );

  Future<String> getLifeNoteAnalysisPrompt() => _getLocalPrompt(
        key: lifeNoteAnalysisPromptKey,
        fallback: defaultLifeNoteAnalysisPrompt,
      );

  Future<void> saveLifeNoteAnalysisPrompt(String prompt) => _saveLocalPrompt(
        key: lifeNoteAnalysisPromptKey,
        fallback: defaultLifeNoteAnalysisPrompt,
        value: prompt,
      );

  Future<Map<String, String>> inspectLifeNoteAnalysisPromptState() => _inspectLocalPrompt(
        key: lifeNoteAnalysisPromptKey,
        fallback: defaultLifeNoteAnalysisPrompt,
      );

  Future<String> getMovieRoleLabEpisodePrompt() => _getLocalPrompt(
        key: movieRoleLabEpisodePromptKey,
        fallback: defaultMovieRoleLabEpisodePrompt,
      );

  Future<void> saveMovieRoleLabEpisodePrompt(String prompt) => _saveLocalPrompt(
        key: movieRoleLabEpisodePromptKey,
        fallback: defaultMovieRoleLabEpisodePrompt,
        value: prompt,
      );

  Future<Map<String, String>> inspectMovieRoleLabEpisodePromptState() => _inspectLocalPrompt(
        key: movieRoleLabEpisodePromptKey,
        fallback: defaultMovieRoleLabEpisodePrompt,
      );

  Future<String> getMovieRoleLabEntryPrompt() => _getLocalPrompt(
        key: movieRoleLabEntryPromptKey,
        fallback: defaultMovieRoleLabEntryPrompt,
      );

  Future<void> saveMovieRoleLabEntryPrompt(String prompt) => _saveLocalPrompt(
        key: movieRoleLabEntryPromptKey,
        fallback: defaultMovieRoleLabEntryPrompt,
        value: prompt,
      );

  Future<Map<String, String>> inspectMovieRoleLabEntryPromptState() => _inspectLocalPrompt(
        key: movieRoleLabEntryPromptKey,
        fallback: defaultMovieRoleLabEntryPrompt,
      );

  Future<String> getMovieRoleLabTurnPrompt() => _getLocalPrompt(
        key: movieRoleLabTurnPromptKey,
        fallback: defaultMovieRoleLabTurnPrompt,
      );

  Future<void> saveMovieRoleLabTurnPrompt(String prompt) => _saveLocalPrompt(
        key: movieRoleLabTurnPromptKey,
        fallback: defaultMovieRoleLabTurnPrompt,
        value: prompt,
      );

  Future<Map<String, String>> inspectMovieRoleLabTurnPromptState() => _inspectLocalPrompt(
        key: movieRoleLabTurnPromptKey,
        fallback: defaultMovieRoleLabTurnPrompt,
      );

  Future<String> getMeditationDailyScriptPrompt() => _getLocalPrompt(
        key: meditationDailyScriptPromptKey,
        fallback: defaultMeditationDailyScriptPrompt,
      );

  Future<void> saveMeditationDailyScriptPrompt(String prompt) => _saveLocalPrompt(
        key: meditationDailyScriptPromptKey,
        fallback: defaultMeditationDailyScriptPrompt,
        value: prompt,
      );

  Future<Map<String, String>> inspectMeditationDailyScriptPromptState() => _inspectLocalPrompt(
        key: meditationDailyScriptPromptKey,
        fallback: defaultMeditationDailyScriptPrompt,
      );

  Future<String> getMeditationFeedbackPrompt() => _getLocalPrompt(
        key: meditationFeedbackPromptKey,
        fallback: defaultMeditationFeedbackPrompt,
      );

  Future<void> saveMeditationFeedbackPrompt(String prompt) => _saveLocalPrompt(
        key: meditationFeedbackPromptKey,
        fallback: defaultMeditationFeedbackPrompt,
        value: prompt,
      );

  Future<Map<String, String>> inspectMeditationFeedbackPromptState() => _inspectLocalPrompt(
        key: meditationFeedbackPromptKey,
        fallback: defaultMeditationFeedbackPrompt,
      );

  Future<String> getMeditationWeeklySummaryPrompt() => _getLocalPrompt(
        key: meditationWeeklySummaryPromptKey,
        fallback: defaultMeditationWeeklySummaryPrompt,
      );

  Future<void> saveMeditationWeeklySummaryPrompt(String prompt) => _saveLocalPrompt(
        key: meditationWeeklySummaryPromptKey,
        fallback: defaultMeditationWeeklySummaryPrompt,
        value: prompt,
      );

  Future<Map<String, String>> inspectMeditationWeeklySummaryPromptState() => _inspectLocalPrompt(
        key: meditationWeeklySummaryPromptKey,
        fallback: defaultMeditationWeeklySummaryPrompt,
      );

  Future<String> getMeditationRecommendationPrompt() => _getLocalPrompt(
        key: meditationRecommendationPromptKey,
        fallback: defaultMeditationRecommendationPrompt,
      );

  Future<void> saveMeditationRecommendationPrompt(String prompt) => _saveLocalPrompt(
        key: meditationRecommendationPromptKey,
        fallback: defaultMeditationRecommendationPrompt,
        value: prompt,
      );

  Future<Map<String, String>> inspectMeditationRecommendationPromptState() => _inspectLocalPrompt(
        key: meditationRecommendationPromptKey,
        fallback: defaultMeditationRecommendationPrompt,
      );


  Future<String> getMeditationUploadPausePrompt() => _getLocalPrompt(
        key: meditationUploadPausePromptKey,
        fallback: defaultMeditationUploadPausePrompt,
      );

  Future<void> saveMeditationUploadPausePrompt(String prompt) => _saveLocalPrompt(
        key: meditationUploadPausePromptKey,
        fallback: defaultMeditationUploadPausePrompt,
        value: prompt,
      );

  Future<Map<String, String>> inspectMeditationUploadPausePromptState() => _inspectLocalPrompt(
        key: meditationUploadPausePromptKey,
        fallback: defaultMeditationUploadPausePrompt,
      );

  Future<String> _getLocalPrompt({required String key, required String fallback}) async {
    final saved = ((await _kvDao.getString(key)) ?? '').trim();
    return saved.isEmpty ? fallback : saved;
  }

  Future<void> _saveLocalPrompt({required String key, required String fallback, required String value}) async {
    final normalized = value.trim().isEmpty ? fallback : value.trim();
    await _kvDao.setString(key, normalized);
  }

  Future<Map<String, String>> _inspectLocalPrompt({required String key, required String fallback}) async {
    final saved = ((await _kvDao.getString(key)) ?? '').trim();
    if (saved.isNotEmpty) {
      return <String, String>{
        'value': saved,
        'source': 'local_saved',
        'sourceLabel': '本地已保存 Prompt',
        'note': '当前实际使用的是设置页保存的本地模板。',
      };
    }
    return <String, String>{
      'value': fallback,
      'source': 'default_builtin',
      'sourceLabel': '内置默认 Prompt',
      'note': '当前没有本地模板，实际使用的是应用内置默认模板。',
    };
  }
  Future<String> getEdenAiKey() async {
    return ((await _kvDao.getString(edenAiKeyKey)) ?? '').trim();
  }

  Future<void> setEdenAiKey(String key) async {
    await _kvDao.setString(edenAiKeyKey, key.trim());
  }

  Future<void> save({required String provider, required String model}) async {
    final raw = provider.trim().toLowerCase();
    final normalizedProvider = raw == 'openai'
        ? 'openai'
        : raw == 'openrouter'
            ? 'openrouter'
            : raw == 'edenai'
                ? 'edenai'
                : 'deepseek';
    await _kvDao.setString(providerKey, normalizedProvider);
    if (normalizedProvider == 'openai') {
      await _kvDao.setString(openAiModelKey, model.trim().isEmpty ? 'gpt-5' : model.trim());
    } else if (normalizedProvider == 'openrouter') {
      await _kvDao.setString(openRouterModelKey, model.trim().isEmpty ? 'openai/gpt-4.1-mini' : model.trim());
    } else if (normalizedProvider == 'edenai') {
      await _kvDao.setString(edenAiModelKey, model.trim().isEmpty ? edenAiDefaultModel : model.trim());
    } else {
      await _kvDao.setString(deepSeekModelKey, model.trim().isEmpty ? 'deepseek-reasoner' : model.trim());
    }
  }

  Future<String> getModelForProvider(String provider) async {
    final raw = provider.trim().toLowerCase();
    final normalizedProvider = raw == 'openai'
        ? 'openai'
        : raw == 'openrouter'
            ? 'openrouter'
            : raw == 'edenai'
                ? 'edenai'
                : 'deepseek';
    if (normalizedProvider == 'openai') {
      final global = await _configDao.getOne();
      final model = ((await _kvDao.getString(openAiModelKey)) ?? (global['model'] ?? 'gpt-5').toString()).trim();
      return model.isEmpty ? 'gpt-5' : model;
    }
    if (normalizedProvider == 'openrouter') {
      final model = ((await _kvDao.getString(openRouterModelKey)) ?? 'openai/gpt-4.1-mini').trim();
      return model.isEmpty ? 'openai/gpt-4.1-mini' : model;
    }
    if (normalizedProvider == 'edenai') {
      final model = ((await _kvDao.getString(edenAiModelKey)) ?? edenAiDefaultModel).trim();
      return model.isEmpty ? edenAiDefaultModel : model;
    }
    final model = ((await _kvDao.getString(deepSeekModelKey)) ?? await _configDao.getDeepseekModel()).trim();
    return model.isEmpty ? 'deepseek-reasoner' : model;
  }
}
