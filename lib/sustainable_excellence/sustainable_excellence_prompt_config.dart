import 'dart:convert';

import '../data/kv_dao.dart';
import '../cognitive_consistency/cognitive_consistency_models.dart';

class SustainableExcellencePromptConfig {
  static const String moduleId = 'sustainable_excellence';
  static const String globalId = 'se_global';
  static const String goalToExperimentId = 'se_scene_goal_to_experiment';
  static const String perfectionismScanId = 'se_scene_perfectionism_scan';
  static const String pressureRecoveryId = 'se_scene_pressure_recovery';
  static const String failureReviewId = 'se_scene_failure_review';
  static const String processEnjoymentId = 'se_scene_process_enjoyment';
  static const String dailyReviewId = 'se_scene_daily_review';
  static const String outputCommonId = 'se_output_common';

  final KeyValueDao _kv = KeyValueDao();
  static String _key(String id) => 'ai_prompt.$moduleId.$id';

  static const String globalValuePrompt = '''
你是“可持续卓越实验室”的 AI 行动教练。你的核心背景来自哈佛积极心理课程 Lecture 14–16 的价值体系：压力需要恢复，失败是学习的组成部分，完美主义不是高标准而是对失败的失能性恐惧，真正的卓越不是无错直线，而是目标、尝试、失败、恢复、反馈、修正、再行动构成的成长螺旋；幸福不是等到终点才开始，而是在通向有意义目标的过程中也能体验意义、掌控、成长和生命感。

你的任务不是替用户做选择，不是给标准答案，不是用鸡汤鼓励用户硬撑，也不是把失败解释成用户人格有问题。你的任务是帮助用户看清现实处境，区分“追求卓越”和“完美主义恐惧”，把目标转化为可执行的小实验，把失败转化为学习样本，把压力转化为有节律的投入与恢复，把过程重新连接到意义、兴趣、能力、自主和长期价值。

你必须始终遵守以下原则：
1. 保留用户的雄心、目标感、责任感和成长愿望，不要把“降低完美主义”误解成“降低追求”。
2. 区分高标准与完美主义：高标准可以保留，失能性的失败恐惧、全有全无、自我审判、过度准备、无法开始需要被调整。
3. 任何目标都要被转化为“实验”，而不是一次性证明用户价值的考试。
4. 失败不是结论，而是数据；未完成不是人格否定，而是阻碍信息。
5. 任何行动建议都必须配套恢复建议，避免把自我成长变成过度训练。
6. 不直接替用户决定，而是提供 2-4 个有差异的可能路径，并说明每条路径适合什么状态，让用户自己选择。
7. 输出要具体、可执行、现实、温和但不空泛；不要只分析，要引导用户进入下一步行动。
8. 不要制造新的完美主义，例如“你必须完美地克服完美主义”“你必须永远享受过程”。
9. 对用户的失败、拖延、焦虑、犹豫保持非评判态度，但也要帮助用户看到可改变的变量。
10. 每次输出都要尽量包含：当前模式识别、核心价值映射、行动选项、恢复安排、失败预案、过程体验提示、复盘问题。
11. 语言风格要像清醒、务实、有同理心的行动教练：既不纵容逃避，也不羞辱用户。
12. 如果用户出现严重危机、自伤风险、极端绝望或无法维持基本生活，应建议寻求现实中的专业支持和可信任的人帮助；不要冒充医疗诊断或治疗。
''';

  static String scenePrompt({
    required String userGoal,
    required String userState,
    String source = 'manual',
    String extraContext = '',
  }) => '''
场景：用户输入或导入了一个目标/Todo，请把它转化为“可持续卓越实验”。

用户目标：
$userGoal

用户当前状态/补充背景：
$userState

来源：$source
额外上下文：$extraContext

请你完成：
1. 判断这个目标背后的真实价值：它可能连接到生存、安全、自由、能力、尊严、关系、成长、意义中的哪些部分。
2. 判断当前最可能的阻碍模式：压力过载、恢复不足、失败恐惧、完美主义、目标过大、缺少下一步、只盯结果、环境诱因、能量不足、意义断裂。
3. 区分用户需要保留的部分和需要调整的部分：保留雄心、责任感、认真、高标准、长期目标；调整自我审判、全有全无、过度准备、害怕失败、只等终点。
4. 给出 3 个可选行动实验：最低可行动作、标准行动、挑战行动。
5. 每个行动实验必须配套行动步骤、可能失败点、失败后如何学习、行动前/后恢复方式、过程体验锚点。
6. 不要替用户做最终选择，只说明每个选项适合什么状态。
7. 输出必须是严格 JSON，不要 Markdown，不要解释。
''';



  static String perfectionismScanPrompt({
    required String userInput,
    String context = '',
  }) => """
场景：用户描述了拖延、害怕失败、迟迟不开始、反复修改、无法提交、只盯结果或对自己不满意。请识别其中的完美主义模式。

用户描述：
$userInput

上下文：$context

请输出严格 JSON：
{
  "mode": "excellence | perfectionism | mixed",
  "preserve": ["需要保留的积极部分"],
  "adjust": ["需要调整的完美主义部分"],
  "explanation": "为什么这不是简单懒惰，也不是用户不行，而是一种可以调整的目标关系和失败关系",
  "practices": [
    {"title":"提交不完美版本练习","steps":[""],"gentle_reminder":""},
    {"title":"5分钟粗糙开始练习","steps":[""],"gentle_reminder":""},
    {"title":"失败预演与复盘练习","steps":[""],"gentle_reminder":""}
  ]
}
只输出 JSON，不要 Markdown。
""";

  static String pressureRecoveryPrompt({
    required String tasks,
    required String state,
  }) => """
场景：用户当前压力大、任务多、疲惫、焦虑、失去动力或连续高强度行动。请根据“压力需要恢复”的价值体系给出节律方案。

用户当前任务：
$tasks

用户状态：
$state

请输出严格 JSON：
{
  "pressure_level":"low | medium | high | overload",
  "recovery_gap":"enough | insufficient | severe",
  "explanation":"压力本身不是敌人，但没有恢复的压力会破坏动力、情绪和长期表现。",
  "must_do_tasks":[""],
  "defer_tasks":[""],
  "shrink_tasks":[""],
  "pause_or_delete_tasks":[""],
  "micro_recovery":[""],
  "medium_recovery":[""],
  "deep_recovery":[""],
  "rhythm":"25/5 | 45/8 | 90/15",
  "warning":"避免继续硬撑的提醒"
}
只输出 JSON，不要 Markdown。
""";

  static String failureReviewPrompt({
    required String goal,
    required String experiment,
    required String actualResult,
    required String emotion,
    required String history,
  }) => """
场景：用户没有完成目标、失败、拖延、做砸、放弃或中断。请把失败转化为学习样本。

原目标：$goal
行动实验：$experiment
实际发生：$actualResult
用户感受：$emotion
历史记录：$history

请输出严格 JSON：
{
  "depersonalized_reframe":"先去人格化：这次失败不是对用户价值的判决，而是具体行动系统中的反馈。",
  "failure_type":"启动失败 | 任务过大 | 恢复不足 | 情绪过载 | 环境诱因 | 完美主义拖延 | 目标不清 | 缺少反馈 | 身体能量不足",
  "learning_point":"最重要的学习点",
  "is_repeated_pattern": false,
  "strategy_change":"如果重复失败，需要改变策略而不是只增加压力",
  "next_smaller_experiment":"下一轮更小实验",
  "restart_sentence":"失败后重新开始行动句",
  "todo_writeback_title":"下一步 Todo 标题",
  "todo_writeback_steps":[""],
  "spiral_stage":"failed_or_stuck"
}
只输出 JSON，不要 Markdown。
""";

  static String processEnjoymentPrompt({
    required String task,
    required String feeling,
    String context = '',
  }) => """
场景：用户觉得任务痛苦、枯燥、只想快点完成、只等结果，无法享受过程。请根据 Enjoy the Process 帮助用户重构过程体验。

任务：$task
用户感受：$feeling
上下文：$context

请输出严格 JSON：
{
  "validation":"承认不是所有过程都会立刻快乐，不要求用户强行喜欢。",
  "long_term_value":"任务连接到什么长期价值",
  "one_percent_experience":["能力感","掌控感","意义感"],
  "process_anchor":"过程锚点",
  "low_pressure_method":"低压力执行方式",
  "during_action_sentence":"行动中提醒短句",
  "after_action_questions":[""]
}
只输出 JSON，不要 Markdown。
""";

  static String dailyReviewPrompt({
    required String casesSummary,
    required String logsSummary,
    String reviewType = 'daily',
  }) => """
场景：用户完成一天/一周行动后进行复盘。请围绕压力、恢复、失败、卓越、过程五个维度总结。

复盘类型：$reviewType
目标摘要：$casesSummary
证据摘要：$logsSummary

请输出严格 JSON：
{
  "title":"可持续卓越复盘",
  "summary":"今天/本周不是简单成功失败，而是处在卓越螺旋的哪一环。",
  "action_evidence":[""],
  "failure_patterns":[""],
  "recovery_insights":[""],
  "process_insights":[""],
  "perfectionism_pattern":"是否出现完美主义模式",
  "next_one_variable":"下一轮只调整一个关键变量",
  "todo_next_step":"写回 Todo 的下一步",
  "coach_message":"温和但有行动感的总结"
}
只输出 JSON，不要 Markdown。
""";

  static const String outputFormatPrompt = '''
只输出一个 JSON 对象，字段如下：
{
  "module": "sustainable_excellence_lab",
  "title": "可持续卓越实验",
  "core_theme": "压力-恢复-失败-反馈-卓越-过程",
  "user_goal": "",
  "current_state_summary": "",
  "mode_detection": {
    "pressure_level": "low | medium | high | overload",
    "recovery_level": "enough | insufficient | severely_insufficient",
    "perfectionism_level": "low | medium | high",
    "failure_fear_level": "low | medium | high",
    "process_connection_level": "low | medium | high"
  },
  "value_mapping": {
    "preserve": ["用户需要保留的积极部分，例如雄心、责任感、高标准、认真、目标感"],
    "adjust": ["需要调整的部分，例如失败恐惧、全有全无、自我审判、过度准备"],
    "core_reframe": "一句核心重构：不是降低追求，而是把完美主义直线改造成卓越螺旋"
  },
  "obstacle_analysis": [
    {"obstacle": "", "evidence": "", "changeable_variable": ""}
  ],
  "action_experiments": [
    {
      "type": "minimum_action",
      "title": "",
      "suitable_when": "",
      "steps": [],
      "time_required": "",
      "failure_point": "",
      "failure_learning_method": "",
      "recovery_before": "",
      "recovery_after": "",
      "process_anchor": ""
    },
    {
      "type": "standard_action",
      "title": "",
      "suitable_when": "",
      "steps": [],
      "time_required": "",
      "failure_point": "",
      "failure_learning_method": "",
      "recovery_before": "",
      "recovery_after": "",
      "process_anchor": ""
    },
    {
      "type": "challenge_action",
      "title": "",
      "suitable_when": "",
      "steps": [],
      "time_required": "",
      "failure_point": "",
      "failure_learning_method": "",
      "recovery_before": "",
      "recovery_after": "",
      "process_anchor": ""
    }
  ],
  "recovery_plan": {
    "micro_recovery": [],
    "medium_recovery": [],
    "deep_recovery": [],
    "recommended_rhythm": ""
  },
  "failure_learning": {
    "possible_failure_type": "",
    "if_failed_then": "",
    "learning_question": "",
    "next_smaller_experiment": ""
  },
  "process_enjoyment": {
    "meaning_connection": "",
    "one_percent_experience": "",
    "during_action_reminder": "",
    "after_action_reflection": ""
  },
  "todo_writeback": {
    "next_todo_title": "",
    "next_todo_steps": [],
    "parent_goal": "",
    "status_label": "not_started | attempted | completed | partially_completed | reviewed | adjusted",
    "evidence_tags": []
  },
  "reflection_questions": [],
  "coach_message": "",
  "risk_note": ""
}
''';

  String defaultFor(String id) {
    switch (id) {
      case globalId:
        return globalValuePrompt;
      case goalToExperimentId:
        return scenePrompt(
          userGoal: '{{user_goal}}',
          userState: '{{user_state}}',
          source: '{{source}}',
          extraContext: '{{extra_context}}',
        );
      case perfectionismScanId:
        return perfectionismScanPrompt(userInput: '{{user_input}}', context: '{{context}}');
      case pressureRecoveryId:
        return pressureRecoveryPrompt(tasks: '{{tasks}}', state: '{{state}}');
      case failureReviewId:
        return failureReviewPrompt(
          goal: '{{goal}}',
          experiment: '{{experiment}}',
          actualResult: '{{actual_result}}',
          emotion: '{{emotion}}',
          history: '{{history}}',
        );
      case processEnjoymentId:
        return processEnjoymentPrompt(task: '{{task}}', feeling: '{{feeling}}', context: '{{context}}');
      case dailyReviewId:
        return dailyReviewPrompt(
          casesSummary: '{{cases_summary}}',
          logsSummary: '{{logs_summary}}',
          reviewType: '{{review_type}}',
        );
      case outputCommonId:
      default:
        return outputFormatPrompt;
    }
  }


  String keyFor(String id) => _key(id);
  String _backupPrefix(String id) => 'backup_${_key(id)}_';

  List<String> allPromptIds() => const <String>[
        globalId,
        goalToExperimentId,
        perfectionismScanId,
        pressureRecoveryId,
        failureReviewId,
        processEnjoymentId,
        dailyReviewId,
        outputCommonId,
      ];

  List<String> requiredPlaceholders(String id) {
    switch (id) {
      case goalToExperimentId:
        return const <String>['{{user_goal}}', '{{user_state}}', '{{source}}', '{{extra_context}}'];
      case perfectionismScanId:
        return const <String>['{{user_input}}', '{{context}}'];
      case pressureRecoveryId:
        return const <String>['{{tasks}}', '{{state}}'];
      case failureReviewId:
        return const <String>['{{goal}}', '{{experiment}}', '{{actual_result}}', '{{emotion}}', '{{history}}'];
      case processEnjoymentId:
        return const <String>['{{task}}', '{{feeling}}', '{{context}}'];
      case dailyReviewId:
        return const <String>['{{cases_summary}}', '{{logs_summary}}', '{{review_type}}'];
      default:
        return const <String>[];
    }
  }

  List<String> missingRequiredPlaceholders(String id, String value) =>
      requiredPlaceholders(id).where((p) => !value.contains(p)).toList(growable: false);

  Future<void> _backupCurrent(String id) async {
    final current = ((await _kv.getString(_key(id))) ?? '').trim();
    if (current.isEmpty) return;
    final key = '${_backupPrefix(id)}${DateTime.now().toIso8601String()}';
    await _kv.setString(key, current);
  }

  Future<void> clearPromptOverride(String id) async {
    await _backupCurrent(id);
    await _kv.setString(_key(id), '');
  }

  Future<List<CcPromptBackupRecord>> listBackups(String id) async {
    final prefix = _backupPrefix(id);
    final rows = await _kv.keyValuesWithPrefix(prefix);
    return rows.map((row) {
      final key = row['key'] ?? '';
      return CcPromptBackupRecord(
        key: key,
        promptId: id,
        versionLabel: key.startsWith(prefix) ? key.substring(prefix.length) : key,
        value: row['value'] ?? '',
      );
    }).where((e) => e.value.trim().isNotEmpty).toList(growable: false);
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

  String previewFor(String id) {
    final sample = <String, String>{
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
    };
    return render(defaultFor(id), sample);
  }

  Future<String> getPrompt(String id) async {
    final saved = ((await _kv.getString(_key(id))) ?? '').trim();
    return saved.isEmpty ? defaultFor(id) : saved;
  }

  Future<void> savePrompt(String id, String value) async {
    final normalized = value.trim();
    await _backupCurrent(id);
    await _kv.setString(_key(id), normalized.isEmpty ? '' : normalized);
  }

  Future<Map<String, String>> inspectPrompt(String id) async {
    final saved = ((await _kv.getString(_key(id))) ?? '').trim();
    return <String, String>{
      'value': saved.isEmpty ? defaultFor(id) : saved,
      'source': saved.isEmpty ? 'default_builtin' : 'local_saved',
      'sourceLabel': saved.isEmpty ? '内置默认 Prompt' : '本地已保存 Prompt',
      'note': saved.isEmpty ? '当前使用可持续卓越模块内置默认模板。' : '当前实际使用设置页保存的可持续卓越模板。',
    };
  }

  String render(String template, Map<String, String> values) {
    var result = template;
    for (final entry in values.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }
    return result;
  }

  Future<String> buildGoalToExperimentPrompt({
    required String userGoal,
    required String userState,
    String source = 'manual',
    String extraContext = '',
  }) async => render(await getPrompt(goalToExperimentId), <String, String>{
        'user_goal': userGoal,
        'user_state': userState,
        'source': source,
        'extra_context': extraContext,
      });

  Future<String> buildPerfectionismScanPrompt({required String userInput, String context = ''}) async =>
      render(await getPrompt(perfectionismScanId), <String, String>{'user_input': userInput, 'context': context});

  Future<String> buildPressureRecoveryPrompt({required String tasks, required String state}) async =>
      render(await getPrompt(pressureRecoveryId), <String, String>{'tasks': tasks, 'state': state});

  Future<String> buildFailureReviewPrompt({
    required String goal,
    required String experiment,
    required String actualResult,
    required String emotion,
    required String history,
  }) async => render(await getPrompt(failureReviewId), <String, String>{
        'goal': goal,
        'experiment': experiment,
        'actual_result': actualResult,
        'emotion': emotion,
        'history': history,
      });

  Future<String> buildProcessEnjoymentPrompt({required String task, required String feeling, String context = ''}) async =>
      render(await getPrompt(processEnjoymentId), <String, String>{'task': task, 'feeling': feeling, 'context': context});

  Future<String> buildDailyReviewPrompt({required String casesSummary, required String logsSummary, String reviewType = 'daily'}) async =>
      render(await getPrompt(dailyReviewId), <String, String>{
        'cases_summary': casesSummary,
        'logs_summary': logsSummary,
        'review_type': reviewType,
      });

}
