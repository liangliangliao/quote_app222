import 'package:flutter/material.dart';

import '../services/global_ai_settings.dart';
import '../shame_transform/shame_transform_prompt_config.dart';
import '../consistency_action_prompt_config.dart';

class AiPromptSettingsPage extends StatefulWidget {
  final String? initialModuleId;
  final String? initialPromptId;

  const AiPromptSettingsPage({
    super.key,
    this.initialModuleId,
    this.initialPromptId,
  });

  @override
  State<AiPromptSettingsPage> createState() => _AiPromptSettingsPageState();
}

class _AiPromptSettingsPageState extends State<AiPromptSettingsPage> {
  final GlobalAiSettings _settings = GlobalAiSettings();
  final ShameTransformPromptConfig _shamePrompts =
      ShameTransformPromptConfig();
  final ConsistencyActionPromptConfig _consistencyPrompts =
      ConsistencyActionPromptConfig();
  final TextEditingController _templateCtrl = TextEditingController();

  late String _moduleId;
  late String _promptId;
  bool _loading = true;
  bool _saving = false;
  String _sourceLabel = '';
  String _sourceNote = '';
  String _effectiveTemplate = '';

  @override
  void initState() {
    super.initState();
    _moduleId = widget.initialModuleId ?? 'goal_setting';
    _promptId = widget.initialPromptId ?? 'goal_understanding';
    final moduleExists = _modules.any((m) => m.id == _moduleId);
    if (!moduleExists) {
      _moduleId = 'goal_setting';
      _promptId = 'goal_understanding';
    } else {
      final module = _modules.firstWhere((m) => m.id == _moduleId);
      if (!module.items.any((p) => p.id == _promptId)) {
        _promptId = module.items.first.id;
      }
    }
    _loadPrompt();
  }

  @override
  void dispose() {
    _templateCtrl.dispose();
    super.dispose();
  }

  List<_PromptModule> get _modules => <_PromptModule>[
        const _PromptModule(
          id: 'shame_transform',
          name: '足下真实自我 · 羞耻转化',
          description: '统一配置三价值体系（毒性羞耻转化 × 羞耻罗盘/真实骄傲 × Kaufman 关怀之桥）、23 个场景引导及输出格式。修改后下一次 AI 转化立即生效。',
          items: <_PromptItem>[
            _PromptItem(id: 'shame_global', name: '全局价值层 Prompt'),
            _PromptItem(id: 'shame_scene_firstAid', name: '场景：羞耻急救'),
            _PromptItem(id: 'shame_scene_eventRecord', name: '场景：羞耻事件记录'),
            _PromptItem(id: 'shame_scene_healthyTransformation', name: '场景：健康羞耻转化'),
            _PromptItem(id: 'shame_scene_innerChild', name: '场景：内在小孩修复'),
            _PromptItem(id: 'shame_scene_innerCritic', name: '场景：内在批判声音外化'),
            _PromptItem(id: 'shame_scene_deniedPart', name: '场景：被否认自我部分整合'),
            _PromptItem(id: 'shame_scene_relationshipBoundary', name: '场景：关系边界与修复'),
            _PromptItem(id: 'shame_scene_healthyResponsibility', name: '场景：健康责任训练'),
            _PromptItem(id: 'shame_scene_todoGoal', name: '场景：Todo 目标羞耻转化'),
            _PromptItem(id: 'shame_scene_dailyReview', name: '场景：每日复盘'),
            _PromptItem(id: 'shame_scene_shameIdentification', name: '场景：羞耻识别评估'),
            _PromptItem(id: 'shame_scene_shameNaming', name: '场景：识别并命名羞耻'),
            _PromptItem(id: 'shame_scene_shameBinding', name: '场景：羞耻绑定解码'),
            _PromptItem(id: 'shame_scene_bridgeRepair', name: '场景：关系桥梁修复'),
            _PromptItem(id: 'shame_scene_culturalShame', name: '场景：文化/社会羞耻识别'),
            _PromptItem(id: 'shame_scene_avoidanceCycle', name: '场景：逃避/拖延羞耻循环'),
            _PromptItem(id: 'shame_scene_identityRebuild', name: '场景：身份重建卡'),
            _PromptItem(id: 'shame_scene_shameDictionary', name: '场景：羞耻语言词典'),
            _PromptItem(id: 'shame_scene_shameCompass', name: '场景：羞耻罗盘识别'),
            _PromptItem(id: 'shame_scene_affectRecovery', name: '场景：积极情感恢复'),
            _PromptItem(id: 'shame_scene_beingSeenTraining', name: '场景：被看见训练'),
            _PromptItem(id: 'shame_scene_truePrideReview', name: '场景：真实骄傲复盘'),
            _PromptItem(id: 'shame_scene_shameScript', name: '场景：羞耻脚本地图'),
            _PromptItem(id: 'shame_output_common', name: '输出格式：通用结构'),
            _PromptItem(id: 'shame_output_first_aid', name: '输出格式：羞耻急救卡'),
            _PromptItem(id: 'shame_output_action_tree', name: '输出格式：Todo 行动树'),
            _PromptItem(id: 'shame_json_repair', name: '异常恢复：JSON 格式修复'),
          ],
        ),
        const _PromptModule(
          id: 'consistency_action',
          name: '足下一致行动系统',
          description: '统一配置认知失调、最小充分理由、1美元行动、行动解释、奖励降噪与合理化警报等 AI 提示词。修改后下一次 AI 引导立即生效。',
          items: <_PromptItem>[
            _PromptItem(id: 'consistency_global', name: '全局价值层 Prompt'),
            _PromptItem(id: 'consistency_scene_goal_to_one_dollar_action', name: '场景：目标转化为 1 美元行动'),
            _PromptItem(id: 'consistency_scene_dissonance_analysis', name: '场景：认知失调分析'),
            _PromptItem(id: 'consistency_scene_anti_hesitation', name: '场景：行动前抗犹豫'),
            _PromptItem(id: 'consistency_scene_post_action_explanation', name: '场景：行动后自我解释'),
            _PromptItem(id: 'consistency_scene_reward_denoise', name: '场景：外部奖励降噪'),
            _PromptItem(id: 'consistency_scene_rationalization_warning', name: '场景：自我欺骗与合理化识别'),
            _PromptItem(id: 'consistency_output_format', name: '输出格式 Prompt'),
          ],
        ),
        const _PromptModule(
          id: 'voice_alarm',
          name: '发现之旅 / 语音闹钟',
          description: '早上起床与晚上睡觉闹钟的 AI 朗读文案生成提示词。',
          items: <_PromptItem>[
            _PromptItem(id: 'voice_alarm_content', name: '语音闹钟朗读内容生成'),
          ],
        ),
        const _PromptModule(
          id: 'goal_setting',
          name: '目标训练模块',
          description: '目标训练课程理解、行动生成、行动闭环总结等 AI 子功能提示词。',
          items: <_PromptItem>[
            _PromptItem(id: 'goal_understanding', name: '理解页 AI 提示词'),
            _PromptItem(id: 'goal_action', name: '行动页 AI 提示词'),
            _PromptItem(id: 'goal_loop', name: '行动闭环 AI 提示词'),
          ],
        ),
        const _PromptModule(
          id: 'movie_role_lab',
          name: '电影角色实验室',
          description: '电影角色进入仪式、沉浸式对戏与导演反馈等 AI 子功能提示词。',
          items: <_PromptItem>[
            _PromptItem(id: 'movie_episode', name: '字幕配角色与分集提示词'),
            _PromptItem(id: 'movie_entry', name: '角色进入仪式提示词'),
            _PromptItem(id: 'movie_turn', name: '角色对戏提示词'),
          ],
        ),
        const _PromptModule(
          id: 'life_note',
          name: '人生注解',
          description: '用户输入生活体验、感受或人生经历后，AI 进行深度理解、归纳总结、思想匹配与治愈书籍推荐。',
          items: <_PromptItem>[
            _PromptItem(id: 'life_note_analysis', name: '经历深度注解与疗愈书单提示词'),
          ],
        ),
        const _PromptModule(
          id: 'behavior_tracking',
          name: '行为观察模块',
          description: '每日预设行为复盘时，调用统一 AI 做人类行为坐标、概率、风险、难度、罕见价值案例等结构化分析。',
          items: <_PromptItem>[
            _PromptItem(id: 'behavior_preset_daily_review_ai', name: '每日预设行为 AI 人类行为坐标分析'),
          ],
        ),
        const _PromptModule(
          id: 'app_shell',
          name: 'App 外壳 / 首页侧栏',
          description: '左侧菜单展开时，通过 AI 随机生成侧栏标题与简介的轻量提示词。',
          items: <_PromptItem>[
            _PromptItem(id: 'drawer_header', name: '侧栏标题与简介生成提示词'),
          ],
        ),
        const _PromptModule(
          id: 'movie_watch',
          name: '发现之旅 / 看电影',
          description: '电影榜、搜索结果与收藏页中“电影分析”按钮使用的 AI 深度分析提示词。',
          items: <_PromptItem>[
            _PromptItem(id: 'movie_analysis', name: '电影深度分析提示词'),
          ],
        ),
        const _PromptModule(
          id: 'meditation',
          name: '静心实验室',
          description: '冥想模块的今日脚本生成、练习后反馈、每周总结与推荐理由提示词。',
          items: <_PromptItem>[
            _PromptItem(id: 'meditation_daily_script', name: '今日冥想脚本生成'),
            _PromptItem(id: 'meditation_feedback', name: '练习后 AI 反馈'),
            _PromptItem(id: 'meditation_weekly_summary', name: '每周静心总结'),
            _PromptItem(id: 'meditation_recommendation', name: '推荐理由生成'),
            _PromptItem(id: 'meditation_upload_pause', name: '上传脚本停顿标注'),
          ],
        ),
      ];

  _PromptModule get _currentModule => _modules.firstWhere(
        (m) => m.id == _moduleId,
        orElse: () => _modules.first,
      );

  _PromptItem get _currentPrompt => _currentModule.items.firstWhere(
        (p) => p.id == _promptId,
        orElse: () => _currentModule.items.first,
      );

  Future<void> _loadPrompt() async {
    setState(() => _loading = true);
    try {
      final inspected = await _inspectPrompt(_promptId);
      final value = inspected['value'] ?? _defaultPrompt(_promptId);
      _templateCtrl.text = value;
      _effectiveTemplate = value;
      _sourceLabel = inspected['sourceLabel'] ?? '当前模板';
      _sourceNote = inspected['note'] ?? '';
    } catch (e) {
      final fallback = _defaultPrompt(_promptId);
      _templateCtrl.text = fallback;
      _effectiveTemplate = fallback;
      _sourceLabel = '加载失败，显示源码默认模板';
      _sourceNote = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _savePrompt() async {
    setState(() => _saving = true);
    try {
      await _savePromptById(_promptId, _templateCtrl.text);
      await _loadPrompt();
      _toast('提示词已保存，下一次 AI 调用生效');
    } catch (e) {
      _toast('保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _restoreDefault() async {
    final def = _defaultPrompt(_promptId);
    setState(() => _templateCtrl.text = def);
    await _savePromptById(_promptId, def);
    await _loadPrompt();
    _toast('已恢复源码默认模板');
  }

  void _onModuleChanged(String? id) {
    if (id == null || id == _moduleId) return;
    final next = _modules.firstWhere((m) => m.id == id);
    setState(() {
      _moduleId = next.id;
      _promptId = next.items.first.id;
    });
    _loadPrompt();
  }

  void _onPromptChanged(String? id) {
    if (id == null || id == _promptId) return;
    setState(() => _promptId = id);
    _loadPrompt();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  String _defaultPrompt(String id) {
    if (id.startsWith('shame_')) {
      return _shamePrompts.defaultFor(id);
    }
    if (id.startsWith('consistency_')) {
      return _consistencyPrompts.defaultFor(id);
    }
    switch (id) {
      case 'goal_action':
        return _settings.defaultGoalSettingActionPrompt;
      case 'goal_loop':
        return _settings.defaultGoalSettingLoopPrompt;
      case 'movie_episode':
        return _settings.defaultMovieRoleLabEpisodePrompt;
      case 'movie_entry':
        return _settings.defaultMovieRoleLabEntryPrompt;
      case 'movie_turn':
        return _settings.defaultMovieRoleLabTurnPrompt;
      case 'movie_analysis':
        return _settings.defaultMovieAnalysisPrompt;
      case 'behavior_preset_daily_review_ai':
        return _settings.defaultBehaviorPresetDailyReviewAiPrompt;
      case 'voice_alarm_content':
        return _settings.defaultVoiceAlarmContentPrompt;
      case 'drawer_header':
        return _settings.defaultDrawerHeaderPrompt;
      case 'life_note_analysis':
        return _settings.defaultLifeNoteAnalysisPrompt;
      case 'meditation_daily_script':
        return _settings.defaultMeditationDailyScriptPrompt;
      case 'meditation_feedback':
        return _settings.defaultMeditationFeedbackPrompt;
      case 'meditation_weekly_summary':
        return _settings.defaultMeditationWeeklySummaryPrompt;
      case 'meditation_recommendation':
        return _settings.defaultMeditationRecommendationPrompt;
      case 'meditation_upload_pause':
        return _settings.defaultMeditationUploadPausePrompt;
      case 'goal_understanding':
      default:
        return _settings.defaultGoalSettingUnderstandingPrompt;
    }
  }

  Future<Map<String, String>> _inspectPrompt(String id) {
    if (id.startsWith('shame_')) {
      return _shamePrompts.inspectPrompt(id);
    }
    if (id.startsWith('consistency_')) {
      return _consistencyPrompts.inspectPrompt(id);
    }
    switch (id) {
      case 'goal_action':
        return _settings.inspectGoalSettingActionPromptState();
      case 'goal_loop':
        return _settings.inspectGoalSettingLoopPromptState();
      case 'movie_episode':
        return _settings.inspectMovieRoleLabEpisodePromptState();
      case 'movie_entry':
        return _settings.inspectMovieRoleLabEntryPromptState();
      case 'movie_turn':
        return _settings.inspectMovieRoleLabTurnPromptState();
      case 'movie_analysis':
        return _settings.inspectMovieAnalysisPromptState();
      case 'behavior_preset_daily_review_ai':
        return _settings.inspectBehaviorPresetDailyReviewAiPromptState();
      case 'voice_alarm_content':
        return _settings.inspectVoiceAlarmContentPromptState();
      case 'drawer_header':
        return _settings.inspectDrawerHeaderPromptState();
      case 'life_note_analysis':
        return _settings.inspectLifeNoteAnalysisPromptState();
      case 'meditation_daily_script':
        return _settings.inspectMeditationDailyScriptPromptState();
      case 'meditation_feedback':
        return _settings.inspectMeditationFeedbackPromptState();
      case 'meditation_weekly_summary':
        return _settings.inspectMeditationWeeklySummaryPromptState();
      case 'meditation_recommendation':
        return _settings.inspectMeditationRecommendationPromptState();
      case 'meditation_upload_pause':
        return _settings.inspectMeditationUploadPausePromptState();
      case 'goal_understanding':
      default:
        return _settings.inspectGoalSettingUnderstandingPromptState();
    }
  }

  Future<void> _savePromptById(String id, String value) {
    if (id.startsWith('shame_')) {
      return _shamePrompts.savePrompt(id, value);
    }
    if (id.startsWith('consistency_')) {
      return _consistencyPrompts.savePrompt(id, value);
    }
    switch (id) {
      case 'goal_action':
        return _settings.saveGoalSettingActionPrompt(value);
      case 'goal_loop':
        return _settings.saveGoalSettingLoopPrompt(value);
      case 'movie_episode':
        return _settings.saveMovieRoleLabEpisodePrompt(value);
      case 'movie_entry':
        return _settings.saveMovieRoleLabEntryPrompt(value);
      case 'movie_turn':
        return _settings.saveMovieRoleLabTurnPrompt(value);
      case 'movie_analysis':
        return _settings.saveMovieAnalysisPrompt(value);
      case 'behavior_preset_daily_review_ai':
        return _settings.saveBehaviorPresetDailyReviewAiPrompt(value);
      case 'voice_alarm_content':
        return _settings.saveVoiceAlarmContentPrompt(value);
      case 'drawer_header':
        return _settings.saveDrawerHeaderPrompt(value);
      case 'life_note_analysis':
        return _settings.saveLifeNoteAnalysisPrompt(value);
      case 'meditation_daily_script':
        return _settings.saveMeditationDailyScriptPrompt(value);
      case 'meditation_feedback':
        return _settings.saveMeditationFeedbackPrompt(value);
      case 'meditation_weekly_summary':
        return _settings.saveMeditationWeeklySummaryPrompt(value);
      case 'meditation_recommendation':
        return _settings.saveMeditationRecommendationPrompt(value);
      case 'meditation_upload_pause':
        return _settings.saveMeditationUploadPausePrompt(value);
      case 'goal_understanding':
      default:
        return _settings.saveGoalSettingUnderstandingPrompt(value);
    }
  }

  List<MapEntry<String, String>> _params(String id) {
    if (id.startsWith('shame_')) {
      return const <MapEntry<String, String>>[
        MapEntry('{{scene}}', '当前羞耻转化场景名称。'),
        MapEntry('{{scene_key}}', '场景稳定标识。'),
        MapEntry('{{intensity}}', '用户选择的羞耻强度，0-10。'),
        MapEntry('{{user_input}}', '用户输入的原始事件、目标或批判语言。'),
        MapEntry('{{emotions}}', '用户选择的情绪标签。'),
        MapEntry('{{body_reactions}}', '用户选择的身体反应。'),
        MapEntry('{{relationship_mode}}', '关系场景分支。'),
        MapEntry('{{denied_part}}', '用户选择的被否认自我部分。'),
        MapEntry('{{raw_response}}', '首次 AI 调用返回但尚未成功解析的原始文本。'),
      ];
    }
    if (id.startsWith('consistency_')) {
      return const <MapEntry<String, String>>[
        MapEntry('{{scene}}', '当前 AI 引导场景：目标转行动、失调分析、抗犹豫、行动后解释、奖励降噪或合理化警报。'),
        MapEntry('{{user_goal}}', '用户输入的目标、愿望、任务或困扰。'),
        MapEntry('{{user_values}}', '用户输入或勾选的核心价值。'),
        MapEntry('{{actual_behavior}}', '用户描述的实际行为或逃避模式。'),
        MapEntry('{{self_explanation}}', '用户当前对自己的解释。'),
        MapEntry('{{one_dollar_action}}', '当前候选 1 美元行动。'),
        MapEntry('{{external_rewards}}', '用户正在依赖的提醒、积分、打卡、排名、监督或惩罚等外部理由。'),
      ];
    }
    switch (id) {
      case 'goal_action':
        return const <MapEntry<String, String>>[
          MapEntry('{{segment_title}}', '当前课程段落标题。'),
          MapEntry('{{original_text}}', '该段完整课程原文。'),
          MapEntry('{{core_concepts}}', '系统提取的本段核心概念。'),
          MapEntry('{{default_action_title}}', '当前默认行动标题。'),
          MapEntry('{{default_action_body}}', '当前默认行动说明。'),
          MapEntry('{{how_steps}}', '系统整理的课程建议步骤。'),
          MapEntry('{{user_concern}}', '用户在行动页输入的当前真实困扰。'),
        ];
      case 'goal_loop':
        return const <MapEntry<String, String>>[
          MapEntry('{{analysis_input_json}}', '完整结构化输入 JSON。包含课程、行动、本轮记录、历史闭环、人物偏好等上下文。'),
          MapEntry('{{segment_title}}', '当前课程段落标题。'),
          MapEntry('{{original_text}}', '该段完整课程原文。'),
          MapEntry('{{action_title}}', '当前行动标题。'),
          MapEntry('{{action_body}}', '当前行动说明。'),
          MapEntry('{{action_steps}}', '当前行动链 / 行动步骤。'),
          MapEntry('{{behavior_chain}}', '行为链提示。'),
          MapEntry('{{success_criteria}}', '完成标准。'),
          MapEntry('{{fallback_action}}', '降级方案。'),
          MapEntry('{{action_status}}', '当前行动状态。'),
          MapEntry('{{latest_fact}}', '最新一次已保存事实。'),
          MapEntry('{{latest_feedback}}', '最新一次已保存反馈。'),
          MapEntry('{{latest_result}}', '最新一次已保存结果。'),
          MapEntry('{{current_records}}', '当前行动下已保存的事实记录、反馈与结果。'),
          MapEntry('{{historical_closed_loops}}', '同课程同行动且已成功生成 AI 闭环总结的历史闭环记录。'),
          MapEntry('{{fact_records}}', '历史事实记录与反馈 JSON。'),
        ];
      case 'movie_episode':
        return const <MapEntry<String, String>>[
          MapEntry('{{movie_id}}', 'TMDb 电影 ID。'),
          MapEntry('{{movie_title}}', '电影标题。'),
          MapEntry('{{movie_overview}}', '电影简介 / 背景。'),
          MapEntry('{{movie_release_date}}', '电影上映日期。'),
          MapEntry('{{main_character_name}}', '要求每集包含的主角名称。'),
          MapEntry('{{ensemble_json}}', '真实角色 / 演员表 JSON。'),
          MapEntry('{{full_subtitle_text}}', '已导入本地数据库的完整字幕文本。'),
          MapEntry('{{movie_episode_input_json}}', '字幕配角色与分集的完整输入 JSON。'),
        ];
      case 'movie_entry':
        return const <MapEntry<String, String>>[
          MapEntry('{{movie_id}}', 'TMDb 电影 ID。'),
          MapEntry('{{movie_title}}', '电影标题。'),
          MapEntry('{{movie_overview}}', '电影简介。'),
          MapEntry('{{movie_release_date}}', '电影上映日期。'),
          MapEntry('{{character_id}}', '角色 ID。'),
          MapEntry('{{character_name}}', '用户选择的角色名。'),
          MapEntry('{{actor_name}}', '饰演该角色的演员名。'),
          MapEntry('{{character_department}}', '演员/角色所属部门信息。'),
          MapEntry('{{ensemble_json}}', '主要角色列表 JSON，最多取前 8 位。'),
          MapEntry('{{subtitle_evidence_json}}', '真实字幕依据 JSON，包含 available/status/source/language/cues 等字段。'),
          MapEntry('{{episode_json}}', '当前剧情片段/集的结构化剧本 JSON。'),
          MapEntry('{{episode_script_text}}', '当前剧情片段/集的完整剧本文本。'),
          MapEntry('{{movie_role_input_json}}', '本次角色进入仪式完整输入 JSON。'),
        ];
      case 'movie_turn':
        return const <MapEntry<String, String>>[
          MapEntry('{{movie_id}}', 'TMDb 电影 ID。'),
          MapEntry('{{movie_title}}', '电影标题。'),
          MapEntry('{{movie_overview}}', '电影简介。'),
          MapEntry('{{character_name}}', '用户正在扮演的角色名。'),
          MapEntry('{{actor_name}}', '饰演该角色的演员名。'),
          MapEntry('{{ensemble_json}}', '主要角色列表 JSON，最多取前 8 位。'),
          MapEntry('{{history_json}}', '本场对戏历史 JSON。'),
          MapEntry('{{latest_user_input}}', '用户本轮最新输入。'),
          MapEntry('{{subtitle_evidence_json}}', '真实字幕依据 JSON，包含真实字幕片段与不确定性说明。'),
          MapEntry('{{episode_json}}', '当前剧情片段/集的结构化剧本 JSON。'),
          MapEntry('{{episode_script_text}}', '当前剧情片段/集的完整剧本文本。'),
          MapEntry('{{dialogue_mode}}', '当前对话模式：exact_script / semantic_script / free_creative。'),
          MapEntry('{{expected_user_line_json}}', '当前顺序下期望用户说出的剧本台词 JSON。'),
          MapEntry('{{movie_role_input_json}}', '本次对戏完整输入 JSON。'),
        ];
      case 'movie_analysis':
        return const <MapEntry<String, String>>[
          MapEntry('{{movie_id}}', 'TMDb 电影 ID。'),
          MapEntry('{{movie_title}}', '电影标题。'),
          MapEntry('{{movie_original_title}}', '电影原始标题。'),
          MapEntry('{{movie_overview}}', 'TMDb 简介。'),
          MapEntry('{{movie_release_date}}', '上映日期。'),
          MapEntry('{{movie_vote_average}}', '评分。'),
          MapEntry('{{movie_vote_count}}', '评分人数。'),
          MapEntry('{{movie_original_language}}', '原始语言。'),
          MapEntry('{{movie_json}}', '完整电影信息 JSON。'),
        ];
      case 'life_note_analysis':
        return const <MapEntry<String, String>>[
          MapEntry('{{user_experience}}', '用户在“人生注解”页面输入的原始生活体验、感受或人生经历。'),
          MapEntry('{{selected_emotions}}', '用户手动勾选的当前情绪标签。'),
          MapEntry('{{scene_tags}}', '用户手动勾选的相关生活场景或人生主题标签。'),
          MapEntry('{{life_note_input_json}}', '完整结构化输入 JSON，包含用户原文、情绪标签、场景标签与客户端时间。'),
        ];
      case 'behavior_preset_daily_review_ai':
        return const <MapEntry<String, String>>[
          MapEntry('{{review_input_json}}', '每日预设行为复盘输入 JSON，包含日期、总数、完成数、未完成数、完成率、每项预设行为名称、类别、状态、未完成原因、转入明天状态、目标值与实际值。'),
        ];
      case 'drawer_header':
        return const <MapEntry<String, String>>[
          MapEntry('{{modules_theme_text}}', '系统把左侧菜单全部模块名称与主题简介汇总后填入。'),
          MapEntry('{{random_seed}}', '每次打开侧栏都会变化的随机种子，用来推动标题与简介随机变化。'),
        ];
      case 'meditation_upload_pause':
        return const <MapEntry<String, String>>[
          MapEntry('{{raw_script}}', '用户上传的原始冥想脚本。'),
          MapEntry('{{target_duration_minutes}}', '用户设置的目标冥想时长。'),
          MapEntry('{{meditation_type}}', '用户选择的冥想类型。'),
          MapEntry('{{pause_style}}', '用户选择的停顿风格。'),
          MapEntry('{{process_mode}}', '处理方式：保留原文 / 轻微优化 / 专业改写。'),
        ];
      case 'meditation_daily_script':
        return const <MapEntry<String, String>>[
          MapEntry('{{current_state}}', '用户开始冥想前选择的当前状态。'),
          MapEntry('{{practice_type}}', '系统根据状态推荐的冥想类型。'),
          MapEntry('{{duration_minutes}}', '本次建议练习时长，单位分钟。'),
          MapEntry('{{recent_records_json}}', '用户最近若干次冥想记录 JSON。'),
        ];
      case 'meditation_feedback':
        return const <MapEntry<String, String>>[
          MapEntry('{{session_title}}', '本次冥想练习标题。'),
          MapEntry('{{session_type}}', '本次冥想练习类型。'),
          MapEntry('{{duration_seconds}}', '本次实际练习秒数。'),
          MapEntry('{{before_mood}}', '练习前紧张/烦乱评分。'),
          MapEntry('{{after_mood}}', '练习后紧张/烦乱评分。'),
          MapEntry('{{distraction_level}}', '练习中的分心程度。'),
          MapEntry('{{body_relax_level}}', '练习后的身体放松程度。'),
          MapEntry('{{user_note}}', '用户的一句觉察记录。'),
        ];
      case 'meditation_weekly_summary':
        return const <MapEntry<String, String>>[
          MapEntry('{{weekly_records_json}}', '最近7天冥想练习记录 JSON。'),
          MapEntry('{{weekly_stats_json}}', '最近7天统计数据 JSON。'),
        ];
      case 'meditation_recommendation':
        return const <MapEntry<String, String>>[
          MapEntry('{{current_state}}', '用户当前状态。'),
          MapEntry('{{practice_type}}', '系统推荐的冥想类型。'),
        ];
      case 'goal_understanding':
      default:
        return const <MapEntry<String, String>>[
          MapEntry('{{segment_title}}', '当前课程段落标题，由系统从课程原文库同步。'),
          MapEntry('{{original_text}}', '该段完整课程原文，由系统从课程原文库同步。'),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final params = _params(_promptId);
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 提示词配置中心'),
        actions: [
          IconButton(
            tooltip: '重新加载',
            onPressed: _loading ? null : _loadPrompt,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionTitle('选择模块'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _moduleId,
                  isExpanded: true,
                  items: _modules
                      .map((m) => DropdownMenuItem<String>(
                            value: m.id,
                            child: Text(m.name),
                          ))
                      .toList(),
                  onChanged: _onModuleChanged,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                Text(_currentModule.description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                _sectionTitle('选择 AI 子功能'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _currentModule.items.any((e) => e.id == _promptId) ? _promptId : _currentModule.items.first.id,
                  isExpanded: true,
                  items: _currentModule.items
                      .map((p) => DropdownMenuItem<String>(
                            value: p.id,
                            child: Text(p.name),
                          ))
                      .toList(),
                  onChanged: _onPromptChanged,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                _statusCard(),
                const SizedBox(height: 16),
                _sectionTitle('当前提示词模板（可修改）'),
                const SizedBox(height: 6),
                const Text(
                  '修改后点击“保存当前模板”。下一次该子功能发起 AI 请求时会自动读取这里的模板。',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _templateCtrl,
                  minLines: 10,
                  maxLines: 22,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '请输入提示词模板；可保留或调整下方占位符。',
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _saving ? null : _savePrompt,
                      icon: _saving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save),
                      label: const Text('保存当前模板'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _restoreDefault,
                      icon: const Icon(Icons.restore),
                      label: const Text('恢复源码默认模板'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _sectionTitle('系统自动填充参数（占位符）'),
                const SizedBox(height: 6),
                const Text(
                  '这些参数由系统在实际 AI 请求时自动填入。建议保留关键占位符；即使模板没有使用全部占位符，模块仍会把必要上下文作为结构化 user payload 发送。',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                ...params.map(_paramRow),
                const SizedBox(height: 18),
                _sectionTitle('当前实际模板（只读）'),
                const SizedBox(height: 6),
                _readOnlyBlock(_effectiveTemplate),
                const SizedBox(height: 18),
                _sectionTitle('源码中的默认完整提示词（只读）'),
                const SizedBox(height: 6),
                _readOnlyBlock(_defaultPrompt(_promptId)),
              ],
            ),
    );
  }

  Widget _sectionTitle(String text) => Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16));

  Widget _statusCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_sourceLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(_sourceNote.isEmpty ? '当前模板会在下一次 AI 调用时生效。' : _sourceNote, style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
          const SizedBox(height: 8),
          Text('当前模块：${_currentModule.name}', style: const TextStyle(fontSize: 12)),
          Text('当前子功能：${_currentPrompt.name}', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _paramRow(MapEntry<String, String> entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: SelectableText(entry.key, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(entry.value, style: const TextStyle(fontSize: 13, height: 1.4))),
        ],
      ),
    );
  }

  Widget _readOnlyBlock(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: SelectableText(text, style: const TextStyle(fontSize: 12.5, height: 1.45)),
    );
  }
}

class _PromptModule {
  final String id;
  final String name;
  final String description;
  final List<_PromptItem> items;

  const _PromptModule({
    required this.id,
    required this.name,
    required this.description,
    required this.items,
  });
}

class _PromptItem {
  final String id;
  final String name;

  const _PromptItem({
    required this.id,
    required this.name,
  });
}
