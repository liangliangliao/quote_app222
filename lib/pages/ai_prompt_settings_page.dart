import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/global_ai_settings.dart';
import '../shame_transform/shame_transform_prompt_config.dart';
import '../cognitive_consistency/cognitive_consistency_prompt_config.dart';
import '../cognitive_consistency/cognitive_consistency_models.dart';
import '../sustainable_excellence/sustainable_excellence_prompt_config.dart';
import '../realistic_optimism_training/realistic_optimism_training_prompt_config.dart';
import '../mi_growth/mi_growth_prompt_config.dart';
import '../second_thought/second_thought_prompt_config.dart';
import '../act_compass/act_compass_prompt_config.dart';
import '../action_mind/action_mind_prompt_config.dart';
import '../woop_action_engine/woop_action_prompt_config.dart';
import '../realistic_positivity_os/realistic_positivity_os_prompt_config.dart';
import '../defense_compass/defense_compass_prompt_config.dart';
import '../adaptation_compass/adaptation_compass_prompt_config.dart';
import '../new_tablets/new_tablets_prompt_config.dart';
import '../self_worth_ai/self_worth_ai_prompt_config.dart';
import '../boundary_practice/boundary_practice_prompt_config.dart';
import '../boundary_action_coach/boundary_action_coach_prompt_config.dart';

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
  final CognitiveConsistencyPromptConfig _ccPrompts =
      CognitiveConsistencyPromptConfig();
  final SustainableExcellencePromptConfig _sePrompts = SustainableExcellencePromptConfig();
  final RealisticOptimismTrainingPromptConfig _rotPrompts = RealisticOptimismTrainingPromptConfig();
  final MiGrowthPromptConfig _miPrompts = MiGrowthPromptConfig();
  final SecondThoughtPromptConfig _stPrompts = SecondThoughtPromptConfig();
  final ActCompassPromptConfig _actPrompts = ActCompassPromptConfig();
  final ActionMindPromptConfig _amPrompts = ActionMindPromptConfig();
  final WoopActionPromptConfig _woopPrompts = WoopActionPromptConfig();
  final RealisticPositivityOsPromptConfig _rpoPrompts = RealisticPositivityOsPromptConfig();
  final DefenseCompassPromptConfig _dfPrompts = DefenseCompassPromptConfig();
  final AdaptationCompassPromptConfig _acPrompts = AdaptationCompassPromptConfig();
  final SelfWorthAiPromptConfig _swPrompts = SelfWorthAiPromptConfig();
  final NewTabletsPromptConfig _ntPrompts = NewTabletsPromptConfig();
  final BoundaryPracticePromptConfig _bpPrompts = BoundaryPracticePromptConfig();
  final BoundaryActionCoachPromptConfig _bacPrompts = BoundaryActionCoachPromptConfig();
  final TextEditingController _templateCtrl = TextEditingController();

  late String _moduleId;
  late String _promptId;
  bool _loading = true;
  bool _saving = false;
  String _sourceLabel = '';
  String _sourceNote = '';
  String _effectiveTemplate = '';
  List<CcPromptBackupRecord> _ccBackups = <CcPromptBackupRecord>[];
  bool _backupLoading = false;

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
        _PromptModule(
          id: BoundaryActionCoachPromptConfig.moduleId,
          name: BoundaryActionCoachPromptConfig.moduleName,
          description: '统一配置边界行动教练的全局价值层、输出格式层、八大场景层、十个产品功能层、安全伦理与异常修复 Prompt。覆盖值保存在 ai_prompt.boundary_action_coach.*，与 Boundary Practice 等模块隔离。',
          items: BoundaryActionCoachPromptConfig.allIds.map((id) => _PromptItem(id: id, name: BoundaryActionCoachPromptConfig.labels[id] ?? id)).toList(growable: false),
        ),
        _PromptModule(
          id: BoundaryPracticePromptConfig.moduleId,
          name: BoundaryPracticePromptConfig.moduleName,
          description: '统一配置边界练习场的全局价值层、八大场景层、边界雷达、话术生成、行动后果、复盘成长、输出结构与安全伦理 Prompt。修改后下一次本模块 AI 调用立即生效。',
          items: BoundaryPracticePromptConfig.allIds.map((id) => _PromptItem(id: id, name: BoundaryPracticePromptConfig.labels[id] ?? id)).toList(growable: false),
        ),

        _PromptModule(
          id: SelfWorthAiPromptConfig.moduleId,
          name: '自我价值 Self Worth',
          description: '统一配置自我价值修复、比较松绑、失败后价值稳定等 Prompt。',
          items: SelfWorthAiPromptConfig.allIds.map((id) => _PromptItem(id: id, name: SelfWorthAiPromptConfig.labels[id] ?? id)).toList(growable: false),
        ),

        _PromptModule(
          id: NewTabletsPromptConfig.moduleId,
          name: '新榜 New Tablets',
          description: '统一配置尼采式自我超克、价值重估、主权承诺、坏良心转化与创造输出的全局价值层、场景层和输出格式 Prompt。修改后下一次本模块 AI 生成立即生效。',
          items: NewTabletsPromptConfig.allIds.map((id) => _PromptItem(id: id, name: NewTabletsPromptConfig.labels[id] ?? id)).toList(growable: false),
        ),

        const _PromptModule(
          id: 'shame_transform',
          name: '足下真实自我 · 羞耻转化',
          description: '统一配置双价值体系（毒性羞耻转化 × 羞耻罗盘/真实骄傲）、15 个场景引导及输出格式。修改后下一次 AI 转化立即生效。',
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
          id: 'cognitive_consistency',
          name: '足下一致行动 · 认知失调',
          description: '统一配置认知失调/最小充分理由/1美元行动/行动后自我解释/身份证据账本/价值一致性报告的三层 AI 提示词。',
          items: <_PromptItem>[
            _PromptItem(id: 'cc_global', name: '全局价值层 Prompt'),
            _PromptItem(id: 'cc_scene_target_to_action', name: '场景：目标转化为 1 美元行动'),
            _PromptItem(id: 'cc_scene_dissonance_analysis', name: '场景：认知失调分析'),
            _PromptItem(id: 'cc_scene_pre_action', name: '场景：行动前抗犹豫引导'),
            _PromptItem(id: 'cc_scene_post_action', name: '场景：行动后自我解释'),
            _PromptItem(id: 'cc_scene_external_reward', name: '场景：外部奖励降噪'),
            _PromptItem(id: 'cc_scene_self_deception', name: '场景：自我欺骗与合理化识别'),
            _PromptItem(id: 'cc_scene_weekly_report', name: '场景：价值一致性报告'),
            _PromptItem(id: 'cc_scene_value_relation', name: '场景：多价值协同 / 冲突分析'),
            _PromptItem(id: 'cc_scene_information_avoidance', name: '场景：信息回避挑战'),
            _PromptItem(id: 'cc_scene_identity_conflict', name: '场景：身份冲突重构'),
            _PromptItem(id: 'cc_scene_cognitive_structure_map', name: '源书场景：认知结构地图'),
            _PromptItem(id: 'cc_scene_conflict_type_router', name: '源书场景：矛盾类型分流器'),
            _PromptItem(id: 'cc_scene_psychological_function', name: '源书场景：心理功能分析器'),
            _PromptItem(id: 'cc_scene_value_layering', name: '源书场景：核心/外围分层'),
            _PromptItem(id: 'cc_scene_interpersonal_balance', name: '源书场景：人际平衡分析'),
            _PromptItem(id: 'cc_scene_counter_attitudinal_experiment', name: '源书场景：反态度行为实验'),
            _PromptItem(id: 'cc_scene_daily_review', name: '场景：每日一致性复盘'),
            _PromptItem(id: 'cc_scene_temperature_review', name: '场景：失调温度计复盘'),
            _PromptItem(id: 'cc_output_common', name: '输出格式：通用 JSON 结构'),
            _PromptItem(id: 'cc_output_cognitive_structure_map', name: '源书输出：认知结构地图 JSON'),
            _PromptItem(id: 'cc_output_conflict_type_router', name: '源书输出：矛盾类型分流 JSON'),
            _PromptItem(id: 'cc_output_psychological_function', name: '源书输出：心理功能分析 JSON'),
            _PromptItem(id: 'cc_output_value_layering', name: '源书输出：核心/外围分层 JSON'),
            _PromptItem(id: 'cc_output_interpersonal_balance', name: '源书输出：人际平衡 JSON'),
            _PromptItem(id: 'cc_output_counter_attitudinal_experiment', name: '源书输出：反态度实验 JSON'),
          ],
        ),
        const _PromptModule(
          id: 'sustainable_excellence',
          name: '可持续卓越实验室',
          description: '统一配置哈佛积极心理 Lecture 14–16 产品化模块的全局价值层、目标转实验、完美主义扫描、压力恢复、失败复盘、过程享受、每日/周度复盘与输出格式 Prompt。',
          items: <_PromptItem>[
            _PromptItem(id: 'se_global', name: '全局价值层 Prompt'),
            _PromptItem(id: 'se_scene_goal_to_experiment', name: '场景：目标/Todo 转卓越实验'),
            _PromptItem(id: 'se_scene_perfectionism_scan', name: '场景：完美主义动态扫描'),
            _PromptItem(id: 'se_scene_pressure_recovery', name: '场景：压力—恢复规划'),
            _PromptItem(id: 'se_scene_failure_review', name: '场景：失败学习复盘'),
            _PromptItem(id: 'se_scene_process_enjoyment', name: '场景：过程享受重构'),
            _PromptItem(id: 'se_scene_daily_review', name: '场景：每日/周度卓越复盘'),
            _PromptItem(id: 'se_output_common', name: '输出格式：可持续卓越 JSON'),
          ],
        ),
        const _PromptModule(
          id: 'realistic_optimism_training',
          name: '现实主义乐观训练系统',
          description: '统一配置 Lecture 7–9 独立模块的全局价值层、强度分级、事件重构、失败免疫、可控失败挑战、过程行动、Prime/Anti-Prime、感恩品味、身份沉淀、幸福基线周报与输出格式 Prompt。',
          items: <_PromptItem>[
            _PromptItem(id: 'rot_global', name: '全局价值层 Prompt'),
            _PromptItem(id: 'rot_scene_intensity_check', name: '场景：事件强度分级'),
            _PromptItem(id: 'rot_scene_event_reframe', name: '场景：今日事件重构'),
            _PromptItem(id: 'rot_scene_emotion_container', name: '场景：Permission to Be Human 情绪容器'),
            _PromptItem(id: 'rot_scene_explanation_radar', name: '场景：解释风格雷达'),
            _PromptItem(id: 'rot_scene_dual_lens', name: '场景：Fault/Benefit 双镜头'),
            _PromptItem(id: 'rot_scene_failure_immunity', name: '场景：失败免疫复盘'),
            _PromptItem(id: 'rot_scene_controlled_failure_challenge', name: '场景：可控失败挑战'),
            _PromptItem(id: 'rot_scene_process_action', name: '场景：过程模拟行动'),
            _PromptItem(id: 'rot_scene_prime_design', name: '场景：注意力 Prime 设计'),
            _PromptItem(id: 'rot_scene_anti_prime_cleanup', name: '场景：Anti-Prime 环境清理'),
            _PromptItem(id: 'rot_scene_gratitude_savoring', name: '场景：感恩、品味与关系表达'),
            _PromptItem(id: 'rot_scene_identity_evidence', name: '场景：身份沉淀'),
            _PromptItem(id: 'rot_scene_weekly_baseline', name: '场景：幸福基线周报'),
            _PromptItem(id: 'rot_output_common', name: '输出格式：现实主义乐观 JSON'),
          ],
        ),
        _PromptModule(
          id: RealisticPositivityOsPromptConfig.moduleId,
          name: '真实积极行动系统 · RPO',
          description: '统一配置基于《哈佛积极心理学》Lecture 9–10 的全局价值层、AI 状态诊断、12 个场景层、成长档案、安全分流与输出 JSON Prompt。修改后下一次本模块 AI 调用立即生效。',
          items: RealisticPositivityOsPromptConfig.allIds
              .map((id) => _PromptItem(id: id, name: RealisticPositivityOsPromptConfig.labels[id] ?? id))
              .toList(growable: false),
        ),
        _PromptModule(
          id: SelfWorthAiPromptConfig.moduleId,
          name: '真实自尊 SelfWorth AI',
          description: '统一配置基于《哈佛大学公开课：幸福课》第21集后半与第22集的全局价值层、八大模块层、场景层、输出格式层 Prompt。修改后下一次本模块 AI 调用立即生效。',
          items: SelfWorthAiPromptConfig.allIds.map((id) => _PromptItem(id: id, name: SelfWorthAiPromptConfig.labels[id] ?? id)).toList(growable: false),
        ),
        _PromptModule(
          id: NewTabletsPromptConfig.moduleId,
          name: NewTabletsPromptConfig.moduleName,
          description: '统一配置 NewTablets 模块的全局层、场景层与输出格式 Prompt。修改后下一次本模块 AI 调用立即生效。',
          items: NewTabletsPromptConfig.allIds.map((id) => _PromptItem(id: id, name: NewTabletsPromptConfig.labels[id] ?? id)).toList(growable: false),
        ),
        _PromptModule(
          id: DefenseCompassPromptConfig.moduleId,
          name: '自我防御罗盘 · Ego Defense Compass',
          description: '统一配置基于安娜·弗洛伊德《自我与防御机制》的全局价值层、完整场景层、输出格式层、结构化 JSON、行动生成、档案更新、关系对话和异常修复 Prompt。修改后下一次本模块 AI 调用立即生效。',
          items: DefenseCompassPromptConfig.allIds.map((id) => _PromptItem(id: id, name: DefenseCompassPromptConfig.labels[id] ?? id)).toList(growable: false),
        ),
        const _PromptModule(
          id: 'mi_growth',
          name: '向内生长 · MI 成长向导',
          description: '统一配置动机式访谈 AI 成长向导的全局价值层、场景层、输出 JSON、行动卡与复盘卡 Prompt。修改后下一次 MI AI 调用立即生效。',
          items: <_PromptItem>[
            _PromptItem(id: 'mi_global', name: '全局价值层 Prompt'),
            _PromptItem(id: 'mi_scene_daily_growth', name: '场景：日常成长向导'),
            _PromptItem(id: 'mi_scene_habit_change', name: '场景：习惯改变 / 反复失败'),
            _PromptItem(id: 'mi_scene_confusion_focus', name: '场景：混乱聚焦'),
            _PromptItem(id: 'mi_scene_low_motivation', name: '场景：暂时没动力'),
            _PromptItem(id: 'mi_scene_action_failure', name: '场景：行动失败 / 复发修复'),
            _PromptItem(id: 'mi_scene_life_transition', name: '场景：人生转变 / 身份成长'),
            _PromptItem(id: 'mi_scene_help_others', name: '场景：帮助别人改变'),
            _PromptItem(id: 'mi_scene_review', name: '场景：复盘与维持'),
            _PromptItem(id: 'mi_scene_repairing_discord', name: '场景：关系失调修复'),
            _PromptItem(id: 'mi_scene_safety', name: '场景：风险与危机安全边界'),
            _PromptItem(id: 'mi_output_json', name: '输出格式：统一 JSON'),
            _PromptItem(id: 'mi_output_action_card', name: '输出格式：行动卡'),
            _PromptItem(id: 'mi_output_review_card', name: '输出格式：复盘卡'),
          ],
        ),

        const _PromptModule(
          id: 'action_mind',
          name: 'ActionMind · 行动心理学引擎',
          description: '统一配置行动心理学 AI App 的全局价值层、12 个场景层与 4 个输出格式 Prompt。修改后下一次 ActionMind AI 调用立即生效。',
          items: <_PromptItem>[
            _PromptItem(id: 'am_global_value', name: '全局价值层 Prompt'),
            _PromptItem(id: 'am_scene_wish_start', name: '场景：愿望启动 / 目标澄清器'),
            _PromptItem(id: 'am_scene_procrastination', name: '场景：拖延诊断'),
            _PromptItem(id: 'am_scene_failure', name: '场景：失败复盘 / 想放弃'),
            _PromptItem(id: 'am_scene_emotion', name: '场景：情绪信号雷达'),
            _PromptItem(id: 'am_scene_long_goal', name: '场景：长期目标系统'),
            _PromptItem(id: 'am_scene_fantasy', name: '场景：愿景-现实心理对照'),
            _PromptItem(id: 'am_scene_habit', name: '场景：习惯/诱惑环境线索重构'),
            _PromptItem(id: 'am_scene_social', name: '场景：社会互动行动教练'),
            _PromptItem(id: 'am_scene_goal_conflict', name: '场景：多目标冲突与生活任务地图'),
            _PromptItem(id: 'am_scene_review', name: '场景：日/周/项目复盘'),
            _PromptItem(id: 'am_scene_daily_cockpit', name: '场景：今日行动驾驶舱'),
            _PromptItem(id: 'am_scene_weekly_system', name: '场景：每周目标系统整合'),
            _PromptItem(id: 'am_output_common', name: '输出格式：通用结构'),
            _PromptItem(id: 'am_output_quick', name: '输出格式：快速模式'),
            _PromptItem(id: 'am_output_deep', name: '输出格式：深度模式'),
            _PromptItem(id: 'am_output_json', name: '输出格式：结构化 JSON'),
          ],
        ),
        const _PromptModule(
          id: 'woop_action_engine',
          name: 'WOOP 行动引擎 · 愿望转行动',
          description: '统一配置基于《Rethinking Positive Thinking》的全局价值层、场景层和输出格式 Prompt。修改后下一次 WOOP AI 行动卡生成立即生效。',
          items: <_PromptItem>[
            _PromptItem(id: 'woop_global_value', name: '全局价值层 Prompt'),
            _PromptItem(id: 'woop_scene_classifier', name: '场景：自动识别器'),
            _PromptItem(id: 'woop_scene_wish_clarify', name: '场景：愿望模糊澄清'),
            _PromptItem(id: 'woop_scene_fantasy', name: '场景：积极幻想转心理对照'),
            _PromptItem(id: 'woop_scene_action_conversion', name: '场景：行动转化 WOOP'),
            _PromptItem(id: 'woop_scene_obstacle_diagnosis', name: '场景：内在障碍诊断'),
            _PromptItem(id: 'woop_scene_failure_review', name: '场景：失败复盘'),
            _PromptItem(id: 'woop_scene_waiting_comfort', name: '场景：低可控等待与安慰'),
            _PromptItem(id: 'woop_scene_large_goal', name: '场景：目标过大缩小'),
            _PromptItem(id: 'woop_scene_drop_or_adjust', name: '场景：继续/调整/放下'),
            _PromptItem(id: 'woop_scene_health', name: '场景：健康行为'),
            _PromptItem(id: 'woop_scene_work_study', name: '场景：学习工作'),
            _PromptItem(id: 'woop_scene_relation', name: '场景：关系沟通'),
            _PromptItem(id: 'woop_scene_emotion_impulse', name: '场景：情绪与冲动'),
            _PromptItem(id: 'woop_scene_daily_24h', name: '场景：24 小时 WOOP'),
            _PromptItem(id: 'woop_scene_fantasy_safe_explore', name: '场景：幻想安全区 / 愿望探索'),
            _PromptItem(id: 'woop_scene_obstacle_radar', name: '场景：障碍雷达模式分析'),
            _PromptItem(id: 'woop_scene_weekly_review', name: '场景：周复盘 / 愿望地图'),
            _PromptItem(id: 'woop_scene_onboarding', name: '场景：首次引导 / 第一张 WOOP'),
            _PromptItem(id: 'woop_scene_experiment_lab', name: '场景：行动实验室'),
            _PromptItem(id: 'woop_scene_value_alignment_audit', name: '场景：价值校准审计'),
            _PromptItem(id: 'woop_scene_sourcebook_course', name: '场景：原书课程化训练'),
            _PromptItem(id: 'woop_scene_trigger_simulator', name: '场景：障碍触发模拟器'),
            _PromptItem(id: 'woop_scene_next_action_queue', name: '场景：下一步行动队列'),
            _PromptItem(id: 'woop_scene_acceptance_audit', name: '场景：产品覆盖验收审计'),
            _PromptItem(id: 'woop_output_standard_woop', name: '输出格式：标准 WOOP'),
            _PromptItem(id: 'woop_output_failure_review', name: '输出格式：失败复盘'),
            _PromptItem(id: 'woop_output_target_filter', name: '输出格式：目标筛选'),
            _PromptItem(id: 'woop_output_json', name: '输出格式：结构化 JSON'),
            _PromptItem(id: 'woop_output_experiment', name: '输出格式：行动实验'),
          ],
        ),
        const _PromptModule(
          id: 'act_compass',
          name: '行愿 Compass · ACT 心理灵活性',
          description: '统一配置 ACT 心理灵活性与价值行动 App 的全局价值层、场景层、输出格式层 Prompt。修改后下一次行愿 Compass AI 调用立即生效。',
          items: <_PromptItem>[
            _PromptItem(id: 'act_global_value', name: '全局价值层 Prompt'),
            _PromptItem(id: 'act_scene_daily_checkin', name: '场景：每日三问 Check-in'),
            _PromptItem(id: 'act_scene_anxiety', name: '场景：焦虑 / 恐惧'),
            _PromptItem(id: 'act_scene_procrastination', name: '场景：拖延 / 行动困难'),
            _PromptItem(id: 'act_scene_self_criticism', name: '场景：自我批评 / 羞耻'),
            _PromptItem(id: 'act_scene_relationship', name: '场景：关系冲突'),
            _PromptItem(id: 'act_scene_values_confusion', name: '场景：价值迷茫'),
            _PromptItem(id: 'act_scene_action_failure', name: '场景：行动失败 / 复发'),
            _PromptItem(id: 'act_scene_bedtime_rumination', name: '场景：睡前反刍'),
            _PromptItem(id: 'act_scene_impulse', name: '场景：冲动行为'),
            _PromptItem(id: 'act_scene_thought_defusion', name: '训练：头脑故事识别器'),
            _PromptItem(id: 'act_scene_acceptance_training', name: '训练：接纳训练室'),
            _PromptItem(id: 'act_scene_values_compass', name: '训练：价值罗盘'),
            _PromptItem(id: 'act_scene_committed_action', name: '训练：承诺行动卡'),
            _PromptItem(id: 'act_scene_review', name: '训练：行动后复盘'),
            _PromptItem(id: 'act_scene_safety', name: '场景：危机与安全'),
            _PromptItem(id: 'act_scene_present_moment', name: '训练：当下觉察'),
            _PromptItem(id: 'act_scene_self_as_context', name: '训练：观察者自我'),
            _PromptItem(id: 'act_scene_clean_dirty_pain', name: '训练：干净痛苦 / 二次痛苦'),
            _PromptItem(id: 'act_scene_value_experiment', name: '训练：7天价值实验'),
            _PromptItem(id: 'act_scene_weekly_report', name: '输出：每周心理灵活性报告'),
            _PromptItem(id: 'act_scene_profile_update', name: '输出：个性化地图更新'),
            _PromptItem(id: 'act_output_common', name: '输出格式：通用结构'),
            _PromptItem(id: 'act_output_quick', name: '输出格式：快速模式'),
            _PromptItem(id: 'act_output_deep', name: '输出格式：深度模式'),
            _PromptItem(id: 'act_output_action_card', name: '输出格式：价值行动卡'),
            _PromptItem(id: 'act_output_json', name: '输出格式：结构化 JSON'),
          ],
        ),
        const _PromptModule(
          id: 'second_thought',
          name: '第二念 · 矛盾心理价值行动引擎',
          description: '统一配置第二念独立模块的全局价值层、10 个场景层与输出格式 Prompt。修改后下一次第二念 AI 调用立即生效。',
          items: <_PromptItem>[
            _PromptItem(id: 'st_global_value', name: '全局价值层 Prompt'),
            _PromptItem(id: 'st_scene_capture', name: '场景：矛盾捕捉'),
            _PromptItem(id: 'st_scene_type_diagnosis', name: '场景：四型矛盾诊断'),
            _PromptItem(id: 'st_scene_inner_committee', name: '场景：内在委员会'),
            _PromptItem(id: 'st_scene_values', name: '场景：价值澄清'),
            _PromptItem(id: 'st_scene_big_picture', name: '场景：全局图景'),
            _PromptItem(id: 'st_scene_change_talk', name: '场景：改变语言'),
            _PromptItem(id: 'st_scene_action_experiment', name: '场景：行动实验'),
            _PromptItem(id: 'st_scene_review', name: '场景：复盘与整合'),
            _PromptItem(id: 'st_scene_integration', name: '场景：与矛盾共处'),
            _PromptItem(id: 'st_scene_social_influence', name: '场景：社会影响分析'),
            _PromptItem(id: 'st_output_json', name: '输出格式：统一 JSON'),
          ],
        ),
        const _PromptModule(
          id: 'adaptation_compass',
          name: '成熟适应力罗盘 · Adaptation Compass',
          description: '统一配置基于 George E. Vaillant《Adaptation to Life》的成熟适应力 App：全局价值层、24 个场景层与输出格式层 Prompt。修改后下一次成熟适应力 AI 调用立即生效。',
          items: <_PromptItem>[
            _PromptItem(id: 'ac_global_value', name: '全局价值层 Prompt'),
            _PromptItem(id: 'ac_scene_daily_stress', name: '场景：日常压力事件'),
            _PromptItem(id: 'ac_scene_defense_identify', name: '场景：防御机制识别'),
            _PromptItem(id: 'ac_scene_reality_check', name: '场景：现实检查室'),
            _PromptItem(id: 'ac_scene_anger_transform', name: '场景：愤怒与攻击性转化'),
            _PromptItem(id: 'ac_scene_shame_failure', name: '场景：羞耻、失败与自我攻击'),
            _PromptItem(id: 'ac_scene_anxiety_fear', name: '场景：焦虑与恐惧'),
            _PromptItem(id: 'ac_scene_relationship_conflict', name: '场景：关系冲突修复'),
            _PromptItem(id: 'ac_scene_intimacy_avoidance', name: '场景：亲密回避 / 依赖恐惧'),
            _PromptItem(id: 'ac_scene_work_consolidation', name: '场景：工作压力与职业巩固'),
            _PromptItem(id: 'ac_scene_balance_four', name: '场景：工作-爱-游戏-身体失衡'),
            _PromptItem(id: 'ac_scene_high_functioning', name: '场景：高功能但情感贫乏'),
            _PromptItem(id: 'ac_scene_childhood_climate', name: '场景：童年关系气候整合'),
            _PromptItem(id: 'ac_scene_body_health', name: '场景：身体、睡眠、饮酒与压力'),
            _PromptItem(id: 'ac_scene_acting_out', name: '场景：酒精/成瘾/行动化冲动'),
            _PromptItem(id: 'ac_scene_generativity', name: '场景：生成性与贡献'),
            _PromptItem(id: 'ac_scene_life_stage_review', name: '场景：生命阶段复盘'),
            _PromptItem(id: 'ac_scene_understand_other', name: '场景：理解他人但保持边界'),
            _PromptItem(id: 'ac_scene_safety_support', name: '场景：危机与安全支持'),
            _PromptItem(id: 'ac_scene_weekly_review', name: '场景：7 天复盘'),
            _PromptItem(id: 'ac_scene_monthly_review', name: '场景：30/90 天深度复盘'),
            _PromptItem(id: 'ac_scene_profile_update', name: '场景：个人适应地图更新'),
            _PromptItem(id: 'ac_scene_therapist_export', name: '场景：治疗师导出包'),
            _PromptItem(id: 'ac_scene_prompt_audit', name: '场景：产品覆盖 / Prompt 审计'),
            _PromptItem(id: 'ac_scene_json_repair', name: '异常恢复：JSON 修复'),
            _PromptItem(id: 'ac_output_common_json_markdown', name: '输出格式层 Prompt：JSON + Markdown 分析卡'),
          ],
        ),
        const _PromptModule(
          id: 'voice_alarm',
          name: '发现之旅 / 语音闹钟',
          description: '早上起床与晚上睡觉闹钟的 AI 朗读文案生成提示词。',
          items: <_PromptItem>[
            _PromptItem(id: 'voice_alarm_content', name: '语音闹钟朗读内容生成'),
            _PromptItem(id: 'voice_alarm_morning_assistant', name: '起床闹钟 AI 对话方案'),
            _PromptItem(id: 'voice_alarm_night_assistant', name: '睡眠闹钟 AI 对话方案'),
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
      if (_promptId.startsWith('cc_')) {
        _ccBackups = await _ccPrompts.listBackups(_promptId);
      } else if (_promptId.startsWith('se_')) {
        _ccBackups = await _sePrompts.listBackups(_promptId);
      } else if (_promptId.startsWith('rot_')) {
        _ccBackups = await _rotPrompts.listBackups(_promptId);
      } else if (_promptId.startsWith('mi_')) {
        _ccBackups = await _miPrompts.listBackups(_promptId);
      } else if (_promptId.startsWith('st_')) {
        _ccBackups = await _stPrompts.listBackups(_promptId);
      } else if (_promptId.startsWith('act_')) {
        _ccBackups = await _actPrompts.listBackups(_promptId);
      } else if (_promptId.startsWith('am_')) {
        _ccBackups = await _amPrompts.listBackups(_promptId);
      } else if (_promptId.startsWith('woop_')) {
        _ccBackups = await _woopPrompts.listBackups(_promptId);
      } else if (_promptId.startsWith('rpo_')) {
        _ccBackups = await _rpoPrompts.listBackups(_promptId);
      } else if (_promptId.startsWith('df_')) {
        _ccBackups = await _dfPrompts.listBackups(_promptId);
      } else if (_promptId.startsWith('ac_')) {
        _ccBackups = await _acPrompts.listBackups(_promptId);
      } else if (_promptId.startsWith('sw_')) {
        _ccBackups = await _swPrompts.listBackups(_promptId);
      } else if (_promptId.startsWith('nt_')) {
        _ccBackups = await _ntPrompts.listBackups(_promptId);
      } else if (_promptId.startsWith('bac_')) {
        _ccBackups = await _bacPrompts.listBackups(_promptId);
      } else if (_promptId.startsWith('bp_')) {
        _ccBackups = await _bpPrompts.listBackups(_promptId);
      } else {
        _ccBackups = <CcPromptBackupRecord>[];
      }
    } catch (e) {
      final fallback = _defaultPrompt(_promptId);
      _templateCtrl.text = fallback;
      _effectiveTemplate = fallback;
      _sourceLabel = '加载失败，显示源码默认模板';
      _sourceNote = e.toString();
      _ccBackups = <CcPromptBackupRecord>[];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _savePrompt() async {
    if (_promptId.startsWith('se_')) {
      final missing = _sePrompts.missingRequiredPlaceholders(_promptId, _templateCtrl.text);
      if (missing.isNotEmpty) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('关键占位符缺失'),
            content: Text("当前模板缺少：${missing.join('、')}。保存后 AI 仍可调用，但上下文可能不完整。是否仍然保存？"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('返回修改')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('仍然保存')),
            ],
          ),
        );
        if (ok != true) return;
      }
    }
    if (_promptId.startsWith('rot_')) {
      final missing = _rotPrompts.missingRequiredPlaceholders(_promptId, _templateCtrl.text);
      if (missing.isNotEmpty) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('关键占位符缺失'),
            content: Text("当前模板缺少：${missing.join('、')}。保存后 AI 仍可调用，但上下文可能不完整。是否仍然保存？"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('返回修改')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('仍然保存')),
            ],
          ),
        );
        if (ok != true) return;
      }
    }
    if (_promptId.startsWith('mi_')) {
      final missing = _miPrompts.missingRequiredPlaceholders(_promptId, _templateCtrl.text);
      if (missing.isNotEmpty) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('关键占位符缺失'),
            content: Text("当前模板缺少：${missing.join('、')}。保存后 AI 仍可调用，但上下文可能不完整。是否仍然保存？"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('返回修改')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('仍然保存')),
            ],
          ),
        );
        if (ok != true) return;
      }
    }
    if (_promptId.startsWith('st_')) {
      final missing = _stPrompts.missingRequiredPlaceholders(_promptId, _templateCtrl.text);
      if (missing.isNotEmpty) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('关键占位符缺失'),
            content: Text("当前模板缺少：${missing.join('、')}。保存后 AI 仍可调用，但上下文可能不完整。是否仍然保存？"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('返回修改')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('仍然保存')),
            ],
          ),
        );
        if (ok != true) return;
      }
    }
    if (_promptId.startsWith('act_')) {
      final missing = _actPrompts.missingRequiredPlaceholders(_promptId, _templateCtrl.text);
      if (missing.isNotEmpty) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('关键占位符缺失'),
            content: Text("当前模板缺少：${missing.join('、')}。保存后 AI 仍可调用，但上下文可能不完整。是否仍然保存？"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('返回修改')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('仍然保存')),
            ],
          ),
        );
        if (ok != true) return;
      }
    }
    if (_promptId.startsWith('am_')) {
      final missing = _amPrompts.missingRequiredPlaceholders(_promptId, _templateCtrl.text);
      if (missing.isNotEmpty) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('关键占位符缺失'),
            content: Text("当前模板缺少：${missing.join('、')}。保存后 AI 仍可调用，但上下文可能不完整。是否仍然保存？"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('返回修改')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('仍然保存')),
            ],
          ),
        );
        if (ok != true) return;
      }
    }
    if (_promptId.startsWith('woop_')) {
      final missing = _woopPrompts.missingRequiredPlaceholders(_promptId, _templateCtrl.text);
      if (missing.isNotEmpty) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('关键占位符缺失'),
            content: Text("当前模板缺少：${missing.join('、')}。保存后 AI 仍可调用，但上下文可能不完整。是否仍然保存？"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('返回修改')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('仍然保存')),
            ],
          ),
        );
        if (ok != true) return;
      }
    }
    if (_promptId.startsWith('nt_')) {
      final missing = _ntPrompts.missingRequiredPlaceholders(_promptId, _templateCtrl.text);
      if (missing.isNotEmpty) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('关键占位符缺失'),
            content: Text("当前模板缺少：${missing.join('、')}。保存后 AI 仍可调用，但上下文可能不完整。是否仍然保存？"),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('返回修改')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('仍然保存'))],
          ),
        );
        if (ok != true) return;
      }
    }
    if (_promptId.startsWith('sw_')) {
      final missing = _swPrompts.missingRequiredPlaceholders(_promptId, _templateCtrl.text);
      if (missing.isNotEmpty) {
        final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('关键占位符缺失'), content: Text("当前模板缺少：${missing.join('、')}。是否仍然保存？"), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('返回修改')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('仍然保存'))]));
        if (ok != true) return;
      }
    }
    if (_promptId.startsWith('bac_')) {
      final missing = _bacPrompts.missingRequiredPlaceholders(_promptId, _templateCtrl.text);
      if (missing.isNotEmpty) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('关键占位符缺失'),
            content: Text("当前模板缺少：${missing.join('、')}。保存后 AI 仍可调用，但上下文可能不完整。是否仍然保存？"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('返回修改')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('仍然保存')),
            ],
          ),
        );
        if (ok != true) return;
      }
    }
    if (_promptId.startsWith('bp_')) {
      final missing = _bpPrompts.missingRequiredPlaceholders(_promptId, _templateCtrl.text);
      if (missing.isNotEmpty) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('关键占位符缺失'),
            content: Text("当前模板缺少：${missing.join('、')}。保存后 AI 仍可调用，但上下文可能不完整。是否仍然保存？"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('返回修改')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('仍然保存')),
            ],
          ),
        );
        if (ok != true) return;
      }
    }
    if (_promptId.startsWith('df_')) {
      final missing = _dfPrompts.missingRequiredPlaceholders(_promptId, _templateCtrl.text);
      if (missing.isNotEmpty) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('关键占位符缺失'),
            content: Text("当前模板缺少：${missing.join('、')}。保存后 AI 仍可调用，但上下文可能不完整。是否仍然保存？"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('返回修改')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('仍然保存')),
            ],
          ),
        );
        if (ok != true) return;
      }
    }
    if (_promptId.startsWith('rpo_')) {
      final missing = _rpoPrompts.missingRequiredPlaceholders(_promptId, _templateCtrl.text);
      if (missing.isNotEmpty) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('关键占位符缺失'),
            content: Text("当前模板缺少：${missing.join('、')}。保存后 AI 仍可调用，但上下文可能不完整。是否仍然保存？"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('返回修改')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('仍然保存')),
            ],
          ),
        );
        if (ok != true) return;
      }
    }
    if (_promptId.startsWith('sw_')) {
      final missing = _swPrompts.missingRequiredPlaceholders(_promptId, _templateCtrl.text);
      if (missing.isNotEmpty) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('关键占位符缺失'),
            content: Text("当前模板缺少：${missing.join('、')}。保存后 AI 仍可调用，但上下文可能不完整。是否仍然保存？"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('返回修改')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('仍然保存')),
            ],
          ),
        );
        if (ok != true) return;
      }
    }
    if (_promptId.startsWith('nt_')) {
      final missing = _ntPrompts.missingRequiredPlaceholders(_promptId, _templateCtrl.text);
      if (missing.isNotEmpty) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('关键占位符缺失'),
            content: Text("当前模板缺少：${missing.join('、')}。保存后 AI 仍可调用，但上下文可能不完整。是否仍然保存？"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('返回修改')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('仍然保存')),
            ],
          ),
        );
        if (ok != true) return;
      }
    }
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
    if (_promptId.startsWith('se_')) {
      await _sePrompts.clearPromptOverride(_promptId);
    } else if (_promptId.startsWith('rot_')) {
      await _rotPrompts.clearPromptOverride(_promptId);
    } else if (_promptId.startsWith('mi_')) {
      await _miPrompts.clearPromptOverride(_promptId);
    } else if (_promptId.startsWith('st_')) {
      await _stPrompts.clearPromptOverride(_promptId);
    } else if (_promptId.startsWith('act_')) {
      await _actPrompts.clearPromptOverride(_promptId);
    } else if (_promptId.startsWith('am_')) {
      await _amPrompts.clearPromptOverride(_promptId);
    } else if (_promptId.startsWith('woop_')) {
      await _woopPrompts.clearPromptOverride(_promptId);
    } else if (_promptId.startsWith('rpo_')) {
      await _rpoPrompts.clearPromptOverride(_promptId);
    } else if (_promptId.startsWith('df_')) {
      await _dfPrompts.clearPromptOverride(_promptId);
    } else if (_promptId.startsWith('ac_')) {
      await _acPrompts.clearPromptOverride(_promptId);
    } else if (_promptId.startsWith('sw_')) {
      await _swPrompts.clearPromptOverride(_promptId);
    } else if (_promptId.startsWith('nt_')) {
      await _ntPrompts.clearPromptOverride(_promptId);
    } else if (_promptId.startsWith('bac_')) {
      await _bacPrompts.clearPromptOverride(_promptId);
    } else if (_promptId.startsWith('bp_')) {
      await _bpPrompts.clearPromptOverride(_promptId);
    } else {
      await _savePromptById(_promptId, def);
    }
    await _loadPrompt();
    _toast((_promptId.startsWith('se_') || _promptId.startsWith('rot_') || _promptId.startsWith('mi_') || _promptId.startsWith('st_') || _promptId.startsWith('act_') || _promptId.startsWith('am_') || _promptId.startsWith('woop_') || _promptId.startsWith('rpo_') || _promptId.startsWith('df_') || _promptId.startsWith('ac_') || _promptId.startsWith('sw_') || _promptId.startsWith('nt_') || _promptId.startsWith('bac_') || _promptId.startsWith('bp_')) ? '已删除本地覆盖，恢复源码默认模板' : '已恢复源码默认模板');
  }

  Future<void> _restoreCcBackup(CcPromptBackupRecord backup) async {
    if (!_promptId.startsWith('cc_') && !_promptId.startsWith('se_') && !_promptId.startsWith('rot_') && !_promptId.startsWith('mi_') && !_promptId.startsWith('st_') && !_promptId.startsWith('act_') && !_promptId.startsWith('am_') && !_promptId.startsWith('woop_') && !_promptId.startsWith('rpo_') && !_promptId.startsWith('df_') && !_promptId.startsWith('ac_') && !_promptId.startsWith('sw_') && !_promptId.startsWith('nt_') && !_promptId.startsWith('bac_') && !_promptId.startsWith('bp_')) return;
    setState(() => _backupLoading = true);
    try {
      if (_promptId.startsWith('cc_')) {
        await _ccPrompts.restoreBackup(_promptId, backup.key);
      } else if (_promptId.startsWith('se_')) {
        await _sePrompts.restoreBackup(_promptId, backup.key);
      } else if (_promptId.startsWith('rot_')) {
        await _rotPrompts.restoreBackup(_promptId, backup.key);
      } else if (_promptId.startsWith('mi_')) {
        await _miPrompts.restoreBackup(_promptId, backup.key);
      } else if (_promptId.startsWith('st_')) {
        await _stPrompts.restoreBackup(_promptId, backup.key);
      } else if (_promptId.startsWith('act_')) {
        await _actPrompts.restoreBackup(_promptId, backup.key);
      } else if (_promptId.startsWith('am_')) {
        await _amPrompts.restoreBackup(_promptId, backup.key);
      } else if (_promptId.startsWith('woop_')) {
        await _woopPrompts.restoreBackup(_promptId, backup.key);
      } else if (_promptId.startsWith('rpo_')) {
        await _rpoPrompts.restoreBackup(_promptId, backup.key);
      } else if (_promptId.startsWith('df_')) {
        await _dfPrompts.restoreBackup(_promptId, backup.key);
      } else if (_promptId.startsWith('ac_')) {
        await _acPrompts.restoreBackup(_promptId, backup.key);
      } else if (_promptId.startsWith('sw_')) {
        await _swPrompts.restoreBackup(_promptId, backup.key);
      } else if (_promptId.startsWith('nt_')) {
        await _ntPrompts.restoreBackup(_promptId, backup.key);
      } else if (_promptId.startsWith('bac_')) {
        await _bacPrompts.restoreBackup(_promptId, backup.key);
      } else {
        await _bpPrompts.restoreBackup(_promptId, backup.key);
      }
      await _loadPrompt();
      _toast('已恢复历史备份：${backup.displayTime}');
    } catch (e) {
      _toast('恢复备份失败：$e');
    } finally {
      if (mounted) setState(() => _backupLoading = false);
    }
  }

  Future<void> _previewPrompt() async {
    final template = _templateCtrl.text;
    final preview = _promptId.startsWith('sw_')
        ? _swPrompts.render(template, <String, String>{
            'scene': 'external_validation',
            'user_input': '我发完朋友圈后一直看点赞，没人回应时就觉得自己不重要。',
            'profile_json': '{"dominant_pattern":"认可依赖","triggers":["沉默","比较"]}',
            'recent_context_json': '{"actions":["24小时不查点赞"],"evidence":["完成一次真实表达"]}',
            'course_name': SelfWorthAiPromptConfig.courseName,
          })
        : _promptId.startsWith('ac_')
        ? _acPrompts.render(template, <String, String>{
            'scene': 'daily_stress',
            'user_input': '今天老板否定了我的方案，我很生气但没有说，回来后想辞职，也担心他故意针对我。',
            'profile_json': '{"values":"现实、关系、成长","repeated_defenses":"理智化、回避","development_task":"职业巩固与亲密"}',
            'recent_context_json': '{"sessions":[],"actions":[],"balance":[]}',
            'course_name': AdaptationCompassPromptConfig.courseName,
            'book_name': AdaptationCompassPromptConfig.bookName,
          })
        : _promptId.startsWith('df_')
        ? _dfPrompts.render(template, <String, String>{
            'scene': 'event_analysis',
            'user_input': '今天同事没有回复我，我表面说无所谓，但心里很焦虑，也担心他讨厌我。',
            'profile_json': '{"current_themes":["投射","自我限制"],"common_triggers":"被忽视、被比较"}',
            'recent_context_json': '{"recent_sessions":[]}',
            'course_name': DefenseCompassPromptConfig.courseName,
            'output_mode': 'standard',
          })
        : _promptId.startsWith('rpo_')
        ? _rpoPrompts.render(template, <String, String>{
            'scene': 'change_lab',
            'user_input': '我总是完美主义，必须准备到很好才敢开始，所以很多事情拖着不做。',
            'profile_json': '{"common_patterns":["完美主义","拖延"],"support_people":["朋友A"]}',
            'recent_context_json': '{"identity_evidence":["我曾经完成过2分钟启动"]}',
            'course_name': '《哈佛积极心理学》Lecture 9–10',
          })
        : _promptId.startsWith('woop_')
        ? _woopPrompts.render(template, <String, String>{
            'scene': 'work_study',
            'user_input': '我想本周完成论文第一稿，但一想到写不好就拖延刷手机。',
            'source': 'manual',
            'extra_context': '{"recent_obstacles":["完美主义","分心逃避"]}',
            'history_json': '{"cards":2,"reviews":1}',
            'output_mode': 'json',
          })
        : _promptId.startsWith('am_')
        ? _amPrompts.render(template, <String, String>{
            'scene': 'procrastination',
            'user_input': '我想写论文，但一坐下就刷手机。我怕写不好，也怕证明自己不行。',
            'profile_json': '{"core_values":["成长","自由","创造"],"identity_direction":"成为能把重要目标落实为行动的人"}',
            'goals_json': '{"active_goals":1,"plans":1}',
            'recent_context_json': '{"last_emotion":"焦虑","last_plan":"如果晚饭后坐到书桌前，就写5分钟"}',
            'output_mode': 'common',
          })
        : _promptId.startsWith('act_')
        ? _actPrompts.render(template, <String, String>{
            'scene': 'procrastination',
            'user_input': '我明天要汇报，但一想到讲不好就很焦虑，所以一直刷手机。',
            'profile_json': '{"core_values":["成长","责任","表达"]}',
            'radar_json': '{"present_moment":4,"defusion":3,"acceptance":4,"self_as_context":5,"values":7,"committed_action":3}',
            'recent_context_json': '{"last_action":"打开文档写3个标题"}',
            'output_mode': 'common',
          })
        : _promptId.startsWith('mi_')
        ? _miPrompts.render(template, <String, String>{
            'scene': 'habit_change',
            'user_input': '我想早睡，但总是刷手机到很晚，第二天又很自责。',
            'profile_json': '{"values":["健康","家庭"],"identityDirection":"成为更能照顾自己的人"}',
            'recent_context_json': '{"recent_actions":"昨天完成了3分钟散步"}',
          })
        : _promptId.startsWith('rot_')
        ? _rotPrompts.render(template, <String, String>{
            'user_input': '今天我又没有学习，我感觉自己特别废，永远坚持不了。',
            'scene': 'event_reframe',
            'extra_context': '{"recent_actions":"昨天完成了5分钟行动","baseline":"恢复能力5/10"}',
          })
        : _promptId.startsWith('se_')
        ? _sePrompts.render(template, <String, String>{
            'user_goal': '完成一个重要但容易拖延的任务',
            'user_state': '压力偏高，担心做不好，迟迟没有开始。',
            'source': 'manual',
            'extra_context': '{"source":"preview"}',
            'user_input': '我反复修改，不敢提交。',
            'context': '当前实验处在行动前准备阶段。',
            'tasks': '写作、学习、恢复',
            'state': '疲惫但想推进一点',
            'goal': '完成一个版本',
            'experiment': '提交一个不完美版本',
            'actual_result': '只打开了材料，没有继续',
            'emotion': '焦虑、怕失败',
            'history': 'action: 已开始；failure_learning: 任务过大',
            'task': '完成报告',
            'feeling': '枯燥、压力大',
            'cases_summary': '实验 A / 阶段: 行动中 / 证据: 3',
            'logs_summary': 'action: 做了 5 分钟；recovery: 休息 3 分钟',
            'review_type': 'daily',
          })
        : _promptId.startsWith('st_')
        ? _stPrompts.render(template, <String, String>{
            'scene': 'capture',
            'user_input': '我想学习，但又总是刷手机。靠近学习时害怕失败，远离学习时又自责。',
            'profile_json': '{"core_values":["成长","自尊","自由"]}',
            'recent_context_json': '{"last_action":"10分钟启动实验"}',
          })
        : _promptId.startsWith('bp_')
        ? _bpPrompts.render(template, <String, String>{
            'scene': 'family',
            'user_input': '我妈每天追问我的婚姻细节，我不说她就说我不孝。',
            'profile_json': '{"boundary_type":"loose","main_pattern":"people_pleasing"}',
            'context_json': '{"action_target":"今晚通话"}',
            'recent_context_json': '{"reviews":1}',
            'output_mode': 'standard',
            'raw_text': '{malformed}',
          })
        : _promptId.startsWith('nt_')
        ? _ntPrompts.render(template, <String, String>{
            'scene': 'general',
            'user_input': '我需要把今天的想法整理成一个可执行计划。',
            'context_json': '{"source":"prompt_preview"}',
          })
        : template;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Prompt 拼接预览'),
        content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: SelectableText(preview))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭'))],
      ),
    );
  }

  bool _isConfigurablePromptModule(String id) =>
      id.startsWith('se_') ||
      id.startsWith('rot_') ||
      id.startsWith('mi_') ||
      id.startsWith('st_') ||
      id.startsWith('act_') ||
      id.startsWith('am_') ||
      id.startsWith('woop_') ||
      id.startsWith('rpo_') ||
      id.startsWith('df_') ||
      id.startsWith('ac_') ||
      id.startsWith('sw_') ||
      id.startsWith('nt_') ||
      id.startsWith('bp_');

  String _moduleExportLabel(String id) {
    if (id.startsWith('bp_')) return BoundaryPracticePromptConfig.moduleName;
    if (id.startsWith('sw_')) return '真实自尊 SelfWorth AI';
    if (id.startsWith('nt_')) return NewTabletsPromptConfig.moduleName;
    if (id.startsWith('rpo_')) return '真实积极行动系统';
    if (id.startsWith('df_')) return '自我防御罗盘';
    if (id.startsWith('ac_')) return '成熟适应力罗盘';
    if (id.startsWith('nt_')) return '新榜 New Tablets';
    if (id.startsWith('sw_')) return '自我价值 Self Worth';
    if (id.startsWith('woop_')) return 'WOOP 行动引擎';
    if (id.startsWith('am_')) return 'ActionMind';
    if (id.startsWith('act_')) return '行愿 Compass';
    if (id.startsWith('st_')) return '第二念';
    if (id.startsWith('mi_')) return 'MI 成长向导';
    if (id.startsWith('rot_')) return '现实主义乐观训练';
    return '可持续卓越';
  }

  Future<String> _exportCurrentPromptModuleJson() {
    if (_promptId.startsWith('bp_')) return _bpPrompts.exportPromptsJson();
    if (_promptId.startsWith('sw_')) return _swPrompts.exportPromptsJson();
    if (_promptId.startsWith('nt_')) return _ntPrompts.exportPromptsJson();
    if (_promptId.startsWith('rpo_')) return _rpoPrompts.exportPromptsJson();
    if (_promptId.startsWith('df_')) return _dfPrompts.exportPromptsJson();
    if (_promptId.startsWith('ac_')) return _acPrompts.exportPromptsJson();
    if (_promptId.startsWith('nt_')) return _ntPrompts.exportPromptsJson();
    if (_promptId.startsWith('sw_')) return _swPrompts.exportPromptsJson();
    if (_promptId.startsWith('woop_')) return _woopPrompts.exportPromptsJson();
    if (_promptId.startsWith('am_')) return _amPrompts.exportPromptsJson();
    if (_promptId.startsWith('act_')) return _actPrompts.exportPromptsJson();
    if (_promptId.startsWith('st_')) return _stPrompts.exportPromptsJson();
    if (_promptId.startsWith('mi_')) return _miPrompts.exportPromptsJson();
    if (_promptId.startsWith('rot_')) return _rotPrompts.exportPromptsJson();
    return _sePrompts.exportPromptsJson();
  }

  Future<int> _importCurrentPromptModuleJson(String raw) {
    if (_promptId.startsWith('bp_')) return _bpPrompts.importPromptsJson(raw);
    if (_promptId.startsWith('sw_')) return _swPrompts.importPromptsJson(raw);
    if (_promptId.startsWith('nt_')) return _ntPrompts.importPromptsJson(raw);
    if (_promptId.startsWith('rpo_')) return _rpoPrompts.importPromptsJson(raw);
    if (_promptId.startsWith('df_')) return _dfPrompts.importPromptsJson(raw);
    if (_promptId.startsWith('ac_')) return _acPrompts.importPromptsJson(raw);
    if (_promptId.startsWith('nt_')) return _ntPrompts.importPromptsJson(raw);
    if (_promptId.startsWith('sw_')) return _swPrompts.importPromptsJson(raw);
    if (_promptId.startsWith('woop_')) return _woopPrompts.importPromptsJson(raw);
    if (_promptId.startsWith('am_')) return _amPrompts.importPromptsJson(raw);
    if (_promptId.startsWith('act_')) return _actPrompts.importPromptsJson(raw);
    if (_promptId.startsWith('st_')) return _stPrompts.importPromptsJson(raw);
    if (_promptId.startsWith('mi_')) return _miPrompts.importPromptsJson(raw);
    if (_promptId.startsWith('rot_')) return _rotPrompts.importPromptsJson(raw);
    return _sePrompts.importPromptsJson(raw);
  }

  Future<void> _exportModulePrompts() async {
    if (!_isConfigurablePromptModule(_promptId)) return;
    final raw = await _exportCurrentPromptModuleJson();
    await Clipboard.setData(ClipboardData(text: raw));
    _toast('已复制${_moduleExportLabel(_promptId)} Prompt 配置 JSON。');
  }

  Future<void> _importModulePrompts() async {
    if (!_isConfigurablePromptModule(_promptId)) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = (data?.text ?? '').trim();
    if (raw.isEmpty) {
      _toast('剪贴板为空。');
      return;
    }
    try {
      final count = await _importCurrentPromptModuleJson(raw);
      await _loadPrompt();
      _toast('已导入 $count 个${_moduleExportLabel(_promptId)} Prompt。');
    } catch (e) {
      _toast('导入失败：$e');
    }
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
    if (id.startsWith('bp_')) {
      return _bpPrompts.defaultFor(id);
    }
    if (id.startsWith('shame_')) {
      return _shamePrompts.defaultFor(id);
    }
    if (id.startsWith('cc_')) {
      return _ccPrompts.defaultFor(id);
    }
    if (id.startsWith('se_')) {
      return _sePrompts.defaultFor(id);
    }
    if (id.startsWith('rot_')) {
      return _rotPrompts.defaultFor(id);
    }
    if (id.startsWith('mi_')) {
      return _miPrompts.defaultFor(id);
    }
    if (id.startsWith('st_')) {
      return _stPrompts.defaultFor(id);
    }
    if (id.startsWith('act_')) {
      return _actPrompts.defaultFor(id);
    }
    if (id.startsWith('am_')) {
      return _amPrompts.defaultFor(id);
    }
    if (id.startsWith('woop_')) {
      return _woopPrompts.defaultFor(id);
    }
    if (id.startsWith('sw_')) {
      return _swPrompts.defaultFor(id);
    }
    if (id.startsWith('nt_')) {
      return _ntPrompts.defaultFor(id);
    }
    if (id.startsWith('rpo_')) {
      return _rpoPrompts.defaultFor(id);
    }
    if (id.startsWith('df_')) {
      return _dfPrompts.defaultFor(id);
    }
    if (id.startsWith('ac_')) {
      return _acPrompts.defaultFor(id);
    }
    if (id.startsWith('nt_')) {
      return _ntPrompts.defaultFor(id);
    }
    if (id.startsWith('sw_')) {
      return _swPrompts.defaultFor(id);
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
      case 'voice_alarm_morning_assistant':
        return _settings.defaultVoiceAlarmMorningAssistantPrompt;
      case 'voice_alarm_night_assistant':
        return _settings.defaultVoiceAlarmNightAssistantPrompt;
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
    if (id.startsWith('bac_')) {
      return _bacPrompts.inspectPrompt(id);
    }
    if (id.startsWith('bp_')) {
      return _bpPrompts.inspectPrompt(id);
    }
    if (id.startsWith('shame_')) {
      return _shamePrompts.inspectPrompt(id);
    }
    if (id.startsWith('cc_')) {
      return _ccPrompts.inspectPrompt(id);
    }
    if (id.startsWith('se_')) {
      return _sePrompts.inspectPrompt(id);
    }
    if (id.startsWith('rot_')) {
      return _rotPrompts.inspectPrompt(id);
    }
    if (id.startsWith('mi_')) {
      return _miPrompts.inspectPrompt(id);
    }
    if (id.startsWith('st_')) {
      return _stPrompts.inspectPrompt(id);
    }
    if (id.startsWith('act_')) {
      return _actPrompts.inspectPrompt(id);
    }
    if (id.startsWith('am_')) {
      return _amPrompts.inspectPrompt(id);
    }
    if (id.startsWith('woop_')) {
      return _woopPrompts.inspectPrompt(id);
    }
    if (id.startsWith('sw_')) {
      return _swPrompts.inspectPrompt(id);
    }
    if (id.startsWith('nt_')) {
      return _ntPrompts.inspectPrompt(id);
    }
    if (id.startsWith('rpo_')) {
      return _rpoPrompts.inspectPrompt(id);
    }
    if (id.startsWith('df_')) {
      return _dfPrompts.inspectPrompt(id);
    }
    if (id.startsWith('ac_')) {
      return _acPrompts.inspectPrompt(id);
    }
    if (id.startsWith('nt_')) {
      return _ntPrompts.inspectPrompt(id);
    }
    if (id.startsWith('sw_')) {
      return _swPrompts.inspectPrompt(id);
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
      case 'voice_alarm_morning_assistant':
        return _settings.inspectVoiceAlarmMorningAssistantPromptState();
      case 'voice_alarm_night_assistant':
        return _settings.inspectVoiceAlarmNightAssistantPromptState();
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
    if (id.startsWith('bac_')) {
      return _bacPrompts.savePrompt(id, value);
    }
    if (id.startsWith('bp_')) {
      return _bpPrompts.savePrompt(id, value);
    }
    if (id.startsWith('shame_')) {
      return _shamePrompts.savePrompt(id, value);
    }
    if (id.startsWith('cc_')) {
      return _ccPrompts.savePrompt(id, value);
    }
    if (id.startsWith('se_')) {
      return _sePrompts.savePrompt(id, value);
    }
    if (id.startsWith('rot_')) {
      return _rotPrompts.savePrompt(id, value);
    }
    if (id.startsWith('mi_')) {
      return _miPrompts.savePrompt(id, value);
    }
    if (id.startsWith('st_')) {
      return _stPrompts.savePrompt(id, value);
    }
    if (id.startsWith('act_')) {
      return _actPrompts.savePrompt(id, value);
    }
    if (id.startsWith('am_')) {
      return _amPrompts.savePrompt(id, value);
    }
    if (id.startsWith('woop_')) {
      return _woopPrompts.savePrompt(id, value);
    }
    if (id.startsWith('sw_')) {
      return _swPrompts.savePrompt(id, value);
    }
    if (id.startsWith('nt_')) {
      return _ntPrompts.savePrompt(id, value);
    }
    if (id.startsWith('rpo_')) {
      return _rpoPrompts.savePrompt(id, value);
    }
    if (id.startsWith('df_')) {
      return _dfPrompts.savePrompt(id, value);
    }
    if (id.startsWith('ac_')) {
      return _acPrompts.savePrompt(id, value);
    }
    if (id.startsWith('nt_')) {
      return _ntPrompts.savePrompt(id, value);
    }
    if (id.startsWith('sw_')) {
      return _swPrompts.savePrompt(id, value);
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
      case 'voice_alarm_morning_assistant':
        return _settings.saveVoiceAlarmMorningAssistantPrompt(value);
      case 'voice_alarm_night_assistant':
        return _settings.saveVoiceAlarmNightAssistantPrompt(value);
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
    if (id.startsWith('bp_')) {
      return const <MapEntry<String, String>>[
        MapEntry('{{scene}}', '边界练习场场景：family / intimacy / friendship / work / technology / self / guilt / relationship。'),
        MapEntry('{{user_input}}', '用户本轮输入的现实关系、情绪信号、边界冲突或自我边界问题。'),
        MapEntry('{{profile_json}}', '本模块独立边界档案：边界类型、六类边界评分、关系领域、主要模式。'),
        MapEntry('{{context_json}}', '本轮行动计划上下文：对象、时间、预期话术、后果和提醒。'),
        MapEntry('{{recent_context_json}}', '近期边界复盘、关系档案、执行记录、内疚变化和成长证据摘要。'),
        MapEntry('{{output_mode}}', '输出模式：standard / json / script_only / review。'),
        MapEntry('{{raw_text}}', '仅 JSON 修复 Prompt 使用：上一次格式异常的原始文本。'),
      ];
    }
    if (id.startsWith('nt_')) {
      return const <MapEntry<String, String>>[
        MapEntry('{{scene}}', 'NewTablets 当前场景标识。'),
        MapEntry('{{user_input}}', '用户本轮输入内容。'),
        MapEntry('{{context_json}}', '模块上下文 JSON。'),
      ];
    }
    if (id.startsWith('sw_')) {
      return const <MapEntry<String, String>>[
        MapEntry('{{scene}}', '真实自尊场景：external_validation / failure / relationship_conflict / comparison / body_shame / boundary / goal_delay / self_acceptance / active_constructive / integrity / criticism / responsibility_review / weekly_report / safety。'),
        MapEntry('{{user_input}}', '用户本轮输入的现实事件、情绪、关系冲突、比较、外貌焦虑、批评、拖延、边界或真实表达内容。'),
        MapEntry('{{profile_json}}', '本模块独立自尊档案：自尊来源、依赖触发器、内在标准、关系模式、身体羞耻触发、责任行动和稳定自尊证据。'),
        MapEntry('{{recent_context_json}}', '近期行动卡、复盘、指标变化、过程胜利日志、认可戒断和关系修复记录摘要。'),
        MapEntry('{{course_name}}', '课程名称：《哈佛大学公开课：幸福课》第21集后半与第22集。'),
      ];
    }
    if (id.startsWith('ac_')) {
      return const <MapEntry<String, String>>[
        MapEntry('{{scene}}', '成熟适应力罗盘场景：daily_stress / defense_identify / reality_check / anger_transform / shame_failure / anxiety_fear / relationship_conflict / intimacy_avoidance / work_consolidation / balance_four / high_functioning / childhood_climate / body_health / acting_out / generativity / life_stage_review / understand_other / safety_support / weekly_review / monthly_review / profile_update / therapist_export / prompt_audit / json_repair。'),
        MapEntry('{{user_input}}', '用户本轮输入的真实事件、关系冲突、身体压力、职业挑战、童年回顾、生命阶段复盘或贡献计划。'),
        MapEntry('{{profile_json}}', '本模块独立成熟适应力档案：价值、常见防御、关系模式、童年气候、成人发展任务、安全资源。'),
        MapEntry('{{recent_context_json}}', '成熟适应力罗盘近期分析卡、行动闭环、四维平衡、关系、时间线和贡献记录摘要。'),
        MapEntry('{{course_name}}', '课程名称：《成熟适应力：从防御机制到现实行动》。'),
        MapEntry('{{book_name}}', '书籍名称：George E. Vaillant《Adaptation to Life》。'),
      ];
    }
    if (id.startsWith('df_')) {
      return const <MapEntry<String, String>>[
        MapEntry('{{scene}}', '自我防御罗盘场景：event_analysis / defense_identify / anxiety_source / reality_check / affect_tolerance / wish_integration / self_limitation / relationship_defense / altruistic_surrender / transition / family_education / monthly_review / safety / action_generation / profile_update / relationship_dialogue / course_practice / defense_library_coach / json_repair。'),
        MapEntry('{{user_input}}', '用户本轮输入的现实事件、情绪、关系冲突、防御观察、行动回避、家庭教育或月度复盘内容。'),
        MapEntry('{{profile_json}}', '本模块独立个人防御地图：当前主题、常见防御、触发点、回避领域、关系模式、支持资源和安全备注。'),
        MapEntry('{{recent_context_json}}', '自我防御罗盘近期事件分析、焦虑来源、防御机制、小行动和行动复盘摘要。'),
        MapEntry('{{course_name}}', '书籍/课程名称：安娜·弗洛伊德《自我与防御机制》与《自我、防御机制与现实行动》。'),
        MapEntry('{{output_mode}}', '输出模式：standard / reality / emotion / wish / action / monthly / relationship / profile / safety / json。'),
      ];
    }
    if (id.startsWith('rpo_')) {
      return const <MapEntry<String, String>>[
        MapEntry('{{scene}}', '真实积极行动系统场景：reality_lens / question_reframing / gratitude / relational_gratitude / emotional_processing / meaning_making / savoring_peak / change_lab / abc_change / behavior_first / stretch_zone / weekly_integration / crisis。'),
        MapEntry('{{user_input}}', '用户本轮输入的真实处境、情绪、感恩对象、旧模式、积极经验、成长挑战或周复盘内容。'),
        MapEntry('{{profile_json}}', '本模块独立人格地图上下文：常见情绪、旧问题、旧模式、支持关系、感恩资产、高峰体验、新身份证据、价值绑定等。'),
        MapEntry('{{recent_context_json}}', '近期训练记录、行动证据、成长资产或系统调度摘要。'),
        MapEntry('{{course_name}}', '课程/书籍名称：哈佛积极心理学 Lecture 9–10。'),
      ];
    }
    if (id.startsWith('woop_')) {
      return const <MapEntry<String, String>>[
        MapEntry('{{scene}}', 'WOOP 场景：auto / wish_clarify / positive_fantasy / action_conversion / obstacle_diagnosis / failure_review / waiting_comfort / large_goal / drop_or_adjust / health / work_study / relation / emotion_impulse / daily_24h / fantasy_safe_explore / obstacle_radar / weekly_review。'),
        MapEntry('{{user_input}}', '用户本轮输入的愿望、幻想、障碍、失败、等待、复盘或关系/健康/学习工作场景。'),
        MapEntry('{{source}}', '来源：manual / todo / daily_woop / review 等。'),
        MapEntry('{{extra_context}}', '模块传入的额外上下文，例如来源任务、历史摘要或用户补充信息。'),
        MapEntry('{{history_json}}', 'WOOP 模块历史行动卡、复盘、障碍雷达或愿望地图摘要 JSON。'),
        MapEntry('{{output_mode}}', '输出模式：json / review / target_filter / woop。'),
      ];
    }
    if (id.startsWith('am_')) {
      return const <MapEntry<String, String>>[
        MapEntry('{{scene}}', '当前 ActionMind 场景：wish_start / procrastination / failure / emotion / long_goal / fantasy / habit / social / goal_conflict / review / daily_cockpit / weekly_system。'),
        MapEntry('{{user_input}}', '用户本轮输入的愿望、目标、情绪、拖延、失败、诱惑、人际场景或复盘内容。'),
        MapEntry('{{profile_json}}', 'ActionMind 个性化档案 JSON：核心价值、身份方向、生活领域、内在锚点、外部压力、常见防御、情绪模式、环境线索、社会互动模式。'),
        MapEntry('{{goals_json}}', '近期目标画像与 if–then 执行意图 JSON。'),
        MapEntry('{{recent_context_json}}', '近期 AI 会话、情绪记录、复盘记录和行动统计 JSON。'),
        MapEntry('{{output_mode}}', '输出模式：common / quick / deep / json。'),
      ];
    }
    if (id.startsWith('act_')) {
      return const <MapEntry<String, String>>[
        MapEntry('{{scene}}', '当前 ACT 场景：daily_checkin / anxiety / procrastination / self_criticism / relationship / values_confusion / action_failure / bedtime_rumination / impulse / thought_defusion / acceptance_training / values_compass / committed_action / review / safety / present_moment / self_as_context / clean_dirty_pain / value_experiment / weekly_report / profile_update。'),
        MapEntry('{{user_input}}', '用户本轮输入的真实场景、头脑故事、情绪、身体感受、回避策略、价值或行动困难。'),
        MapEntry('{{profile_json}}', '用户行愿 Compass 价值档案 JSON，包括核心价值、身份方向、生活领域、常见头脑故事、回避策略和有效练习。'),
        MapEntry('{{radar_json}}', '心理灵活性雷达 JSON，包括当下觉察、解离、接纳、观察者自我、价值和承诺行动评分。'),
        MapEntry('{{recent_context_json}}', '最近 ACT 对话、价值行动卡、行动复盘和个性化地图摘要。'),
        MapEntry('{{output_mode}}', '输出模式：common / quick / deep / action_card。'),
      ];
    }
    if (id.startsWith('st_')) {
      return const <MapEntry<String, String>>[
        MapEntry('{{scene}}', '当前第二念场景：capture / type_diagnosis / inner_committee / values / big_picture / change_talk / action_experiment / review / integration / social_influence。'),
        MapEntry('{{user_input}}', '用户本轮输入的矛盾、纠结、拖延、选择摇摆、价值冲突或复盘内容。'),
        MapEntry('{{profile_json}}', '用户第二念价值档案 JSON，包括核心价值、身份愿景、关系背景、长期方向和改变语言库。'),
        MapEntry('{{recent_context_json}}', '最近第二念案例、行动实验、复盘和价值候选摘要。'),
      ];
    }
    if (id.startsWith('mi_')) {
      return const <MapEntry<String, String>>[
        MapEntry('{{scene}}', '当前 MI 场景：daily_growth / habit_change / confusion_focus / low_motivation / action_failure / life_transition / help_others / review / repairing_discord / safety。'),
        MapEntry('{{user_input}}', '用户本轮输入的改变、困扰、复盘或帮助别人改变的原始内容。'),
        MapEntry('{{profile_json}}', '用户价值罗盘 JSON，包括核心价值、身份愿景、重要关系、长期方向和改变理由。'),
        MapEntry('{{recent_context_json}}', '最近 MI 会话、改变语言、小步行动和复盘摘要。'),
      ];
    }
    if (id.startsWith('rot_')) {
      return const <MapEntry<String, String>>[
        MapEntry('{{user_input}}', '用户在现实主义乐观训练系统输入的事件、目标、失败、拖延、感恩、环境困扰或复盘内容。'),
        MapEntry('{{scene}}', '当前训练场景：intensity_check / event_reframe / emotion_container / explanation_radar / dual_lens / failure_immunity / controlled_failure_challenge / process_action / prime_design / anti_prime_cleanup / gratitude_savoring / identity_evidence / weekly_baseline。'),
        MapEntry('{{extra_context}}', '系统汇总的最近训练记录、幸福基线、行动证据或来源 Todo 等额外上下文。'),
      ];
    }
    if (id.startsWith('se_')) {
      return const <MapEntry<String, String>>[
        MapEntry('{{user_goal}}', '用户输入的目标、Todo、拖延、失败或完美主义困扰。'),
        MapEntry('{{user_state}}', '用户当前状态或 Todo 正文。'),
        MapEntry('{{source}}', '来源：manual / todo / sustainable_excellence 等。'),
        MapEntry('{{extra_context}}', '结构化额外上下文 JSON，例如 source_todo_id、source_list_id、body。'),
        MapEntry('{{user_input}}', '用户在训练或扫描中输入的描述。'),
        MapEntry('{{context}}', '当前实验、成长证据或补充上下文。'),
        MapEntry('{{tasks}}', '压力恢复规划中的任务摘要。'),
        MapEntry('{{state}}', '压力恢复规划中的身心状态描述。'),
        MapEntry('{{goal}}', '失败复盘中的原目标。'),
        MapEntry('{{experiment}}', '失败复盘中的行动实验标题。'),
        MapEntry('{{actual_result}}', '失败复盘中的实际发生情况。'),
        MapEntry('{{emotion}}', '失败复盘中的情绪/卡点。'),
        MapEntry('{{history}}', '最近成长证据历史。'),
        MapEntry('{{task}}', '过程享受重构中的任务。'),
        MapEntry('{{feeling}}', '过程享受重构中的痛苦/枯燥感。'),
        MapEntry('{{cases_summary}}', '每日/周度复盘中的目标摘要。'),
        MapEntry('{{logs_summary}}', '每日/周度复盘中的证据摘要。'),
        MapEntry('{{review_type}}', 'daily / weekly。'),
      ];
    }
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
    if (id.startsWith('cc_')) {
      return const <MapEntry<String, String>>[
        MapEntry('{{user_goal}}', '用户输入的目标、愿望或想做但一直拖延的事情。'),
        MapEntry('{{user_context}}', '用户当前状态、阻力、内耗或现实背景。'),
        MapEntry('{{user_values}}', '用户手动填写或系统提取的价值/身份方向。'),
        MapEntry('{{recent_evidence}}', '最近身份证据账本记录摘要。'),
        MapEntry('{{today}}', '客户端今天日期。'),
        MapEntry('{{user_event}}', '用户描述的失调、拖延、逃避或自我矛盾事件。'),
        MapEntry('{{one_dollar_action}}', '当前 1 美元行动。'),
        MapEntry('{{hesitation}}', '行动前犹豫、拖延或想放弃的具体内容。'),
        MapEntry('{{value_link}}', '行动连接到的价值或身份方向。'),
        MapEntry('{{completed_action}}', '用户实际完成的行动。'),
        MapEntry('{{user_reflection}}', '行动后体验、阻力、感受和证据记录。'),
        MapEntry('{{old_story}}', '这次行动要松动的旧解释或旧模式。'),
        MapEntry('{{reward_context}}', '用户对打卡、积分、监督、奖惩等外部理由的描述。'),
        MapEntry('{{user_explanation}}', '用户可能用于降低失调的解释。'),
        MapEntry('{{known_facts}}', '与解释相关的可确认事实。'),
        MapEntry('{{recent_records_json}}', '最近行动证据记录 JSON。'),
        MapEntry('{{report_range}}', '价值一致性报告的时间范围。'),
        MapEntry('{{modern_profile_json}}', 'V18 现代认知失调画像 JSON：失调类型、强度、温度、验证任务、自我完整等。'),
        MapEntry('{{daily_reviews_json}}', '最近每日一致性复盘 JSON。'),
        MapEntry('{{before_temperature}}', '行动前失调温度计结构化记录。'),
        MapEntry('{{after_temperature}}', '行动后失调温度计结构化记录。'),
        MapEntry('{{dissonance_types}}', '本次相关认知失调类型。'),
        MapEntry('{{growth_explanation}}', '本次成长性解释。'),
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
                const SizedBox(height: 10),
                _ccBackupRestoreCard(),
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
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _previewPrompt,
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('预览拼接'),
                    ),
                    if (_isConfigurablePromptModule(_promptId)) OutlinedButton.icon(
                      onPressed: _saving ? null : _exportModulePrompts,
                      icon: const Icon(Icons.ios_share_outlined),
                      label: const Text('导出本模块 Prompt'),
                    ),
                    if (_isConfigurablePromptModule(_promptId)) OutlinedButton.icon(
                      onPressed: _saving ? null : _importModulePrompts,
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('导入本模块 Prompt'),
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


  Widget _ccBackupRestoreCard() {
    if (!_promptId.startsWith('cc_') && !_promptId.startsWith('se_') && !_promptId.startsWith('rot_') && !_promptId.startsWith('mi_') && !_promptId.startsWith('st_') && !_promptId.startsWith('act_') && !_promptId.startsWith('am_') && !_promptId.startsWith('woop_') && !_promptId.startsWith('rpo_')) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('历史备份 / 自定义 Prompt 恢复', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
            '认知一致性、可持续卓越、现实主义乐观训练、MI 成长向导、第二念、行愿 Compass、ActionMind、WOOP 行动引擎与真实积极行动系统模块保存/恢复 Prompt 时会自动备份旧模板。这里可以恢复旧的自定义版本，避免升级或误改后丢失个人调校。',
            style: TextStyle(fontSize: 12, color: Color(0xFF78350F)),
          ),
          const SizedBox(height: 8),
          if (_backupLoading) const LinearProgressIndicator(),
          if (_ccBackups.isEmpty)
            const Text('暂无可恢复备份。', style: TextStyle(fontSize: 12, color: Colors.grey))
          else
            ..._ccBackups.take(5).map(
              (backup) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${backup.displayTime} · ${backup.preview}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: _backupLoading ? null : () => _restoreCcBackup(backup),
                      child: const Text('恢复'),
                    ),
                  ],
                ),
              ),
            ),
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
