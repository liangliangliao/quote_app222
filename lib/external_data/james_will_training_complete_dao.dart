import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import 'james_will_training_complete_models.dart';
import 'james_will_training_models.dart';
import 'james_will_training_prompt_context.dart';

class JamesWillTrainingCompleteDao {
  Future<Database> get _db async {
    final db = await AppDatabase.instance();
    await ensureTables(db);
    return db;
  }

  Future<void> ensureTables([Database? database]) async {
    final db = database ?? await AppDatabase.instance();
    await db.execute('''
      CREATE TABLE IF NOT EXISTS james_will_habits (
        habit_id TEXT PRIMARY KEY,
        idea_id TEXT NOT NULL,
        name TEXT,
        trigger_text TEXT,
        place_text TEXT,
        first_body_action TEXT,
        minimum_version TEXT,
        standard_version TEXT,
        fallback_version TEXT,
        level INTEGER DEFAULT 1,
        status TEXT DEFAULT 'active',
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS james_will_weekly_reports (
        report_id TEXT PRIMARY KEY,
        from_ms INTEGER NOT NULL,
        to_ms INTEGER NOT NULL,
        completed_count INTEGER DEFAULT 0,
        total_logs INTEGER DEFAULT 0,
        average_effort REAL DEFAULT 0,
        recovery_count INTEGER DEFAULT 0,
        dominant_obstacle TEXT,
        best_action_idea TEXT,
        growth_level TEXT,
        summary TEXT,
        next_experiment TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS james_will_prompt_configs (
        config_key TEXT PRIMARY KEY,
        title TEXT,
        prompt_text TEXT,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_james_will_habits_idea ON james_will_habits(idea_id, updated_at_ms)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_james_will_habits_status ON james_will_habits(status, updated_at_ms)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_james_will_reports_created ON james_will_weekly_reports(created_at_ms)');
    await _seedPromptConfigs(db);
  }

  Future<void> _seedPromptConfigs(Database db) async {
    Future<void> seed(String key, String title, String prompt) async {
      final rows = await db.query('james_will_prompt_configs', where: 'config_key=?', whereArgs: <Object?>[key], limit: 1);
      if (rows.isNotEmpty) return;
      await db.insert(
        'james_will_prompt_configs',
        JamesWillPromptConfig(key: key, title: title, prompt: prompt, updatedAtMs: DateTime.now().millisecondsSinceEpoch).toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    await seed('unified_background', '统一核心价值体系背景', kJamesWillUnifiedBackground);
    await seed('action_idea_prompt', '行动观念生成完整提示词', '请基于统一背景，围绕用户目标{{goal}}和补充说明{{note}}，不要替用户做人生选择。先澄清真实需要，再提供行动观念、第一身体动作、最小行动、5分钟版本、观念竞争、多种替代观念和参考案例。必须输出指定 JSON。附加要求：{{additionalPrompt}}');
    await seed('decision_prompt', '决定分析完整提示词', '请基于统一背景，分析用户犹豫{{question}}。不要直接替用户决定，而是澄清事实、价值、代价、可控域，列出至少两种可能路径，说明适用条件与风险，最后建议低风险实验。必须输出指定 JSON。附加要求：{{additionalPrompt}}');
    await seed('review_prompt', '意志复盘完整提示词', '请基于统一背景复盘本次实践：目标{{goal}}，日志{{logSummary}}。重点不是评价成败，而是帮助用户看见阻碍观念、主导观念、努力性注意、下一次更小的实践步骤。附加要求：{{additionalPrompt}}');
    await seed('weekly_report_prompt', '每周报告完整提示词', '请基于统一背景生成周报。不要给标准答案，输出本周观念模式、实践证据、可选改进方向、下周实验建议。必须输出指定 JSON。附加要求：{{additionalPrompt}}');
    await seed('voice_pullback_prompt', '语音注意力拉回完整提示词', '请基于统一背景生成30-45秒语音拉回文案。用户状态{{stateLabel}}，行动观念{{actionIdea}}。不要批评，不替用户选择，只把注意力带回第一身体动作。');
    await seed('seven_day_experiment_prompt', '7天行动实验完整提示词', '请基于统一背景，为{{goal}}设计7天可撤回实验。必须给固定触发条件、地点、第一身体动作、最小版、标准版、失败恢复版；并说明这是用户可选择的实验，不是标准答案。必须输出指定 JSON。');
    await seed('cooldown_prompt', '冲动决定冷却完整提示词', '请基于统一背景，对冲动决定{{decisionText}}进行冷却分析。不要直接否定用户，而是提供风险判断、冷却问题、可控替代动作。必须输出指定 JSON。');
    await seed('value_map_prompt', '长期价值地图完整提示词', '请基于统一背景，把目标、行动观念与日志整理成价值地图。重点指出哪些已落地、哪些仍停留在口号，以及多个可选下一步实验。必须输出指定 JSON。');
    await seed('practice_guide_prompt', '完整实践流程引导提示词', '请基于统一背景，为行动观念{{actionIdea}}和用户真实需要{{userNeed}}设计完整实践流程。不能直接替用户做选择；必须先提出澄清问题，再给至少3种可能路径，每种包含适用条件、代价、第一实验和具体参考案例，最后让用户自己选择。必须输出指定 JSON。');
    await seed('action_idea_tail', '行动观念生成附加提示词', '强调：先问真实需要，再提供多种可能，不替用户做选择。必须服从统一背景，把目标落到行动观念、第一身体动作、5分钟版本、观念竞争、参考案例、可控行动。');
    await seed('decision_tail', '决定分析附加提示词', '强调：必须服从统一背景，先判断用户是否缺少真实信息；按五种决定类型识别犹豫结构；至少提供两种可行路径与低风险实验，而不是替用户拍板。');
    await seed('review_tail', '意志复盘附加提示词', '强调：必须服从统一背景，复盘重点是努力性注意、分心拉回、阻碍观念识别、行动观念如何重新占据注意力，以及下一次实践如何由用户自己调整。');
    await seed('weekly_report_tail', '每周报告附加提示词', '强调：必须服从统一背景，报告不是评价人格，而是提炼实践证据、主导观念、阻碍模式、决定稳定度、习惯化进展和多种下周实验可能。');
  }

  Future<void> saveHabit(JamesWillHabit habit) async {
    final db = await _db;
    await db.insert('james_will_habits', habit.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<JamesWillHabit?> activeHabitForIdea(String ideaId) async {
    final db = await _db;
    final rows = await db.query(
      'james_will_habits',
      where: "idea_id=? AND status='active'",
      whereArgs: <Object?>[ideaId],
      orderBy: 'updated_at_ms DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return JamesWillHabit.fromMap(rows.first);
  }

  Future<List<JamesWillHabit>> listHabits({int limit = 50}) async {
    final db = await _db;
    final rows = await db.query(
      'james_will_habits',
      where: "status='active'",
      orderBy: 'updated_at_ms DESC',
      limit: limit,
    );
    return rows.map(JamesWillHabit.fromMap).toList(growable: false);
  }

  Future<void> saveWeeklyReport(JamesWillWeeklyReport report) async {
    final db = await _db;
    await db.insert('james_will_weekly_reports', report.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<JamesWillWeeklyReport>> listWeeklyReports({int limit = 12}) async {
    final db = await _db;
    final rows = await db.query('james_will_weekly_reports', orderBy: 'created_at_ms DESC', limit: limit);
    return rows.map(JamesWillWeeklyReport.fromMap).toList(growable: false);
  }

  Future<void> savePromptConfig(JamesWillPromptConfig config) async {
    final db = await _db;
    await db.insert('james_will_prompt_configs', config.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<JamesWillPromptConfig?> getPromptConfig(String key) async {
    final db = await _db;
    final rows = await db.query('james_will_prompt_configs', where: 'config_key=?', whereArgs: <Object?>[key], limit: 1);
    if (rows.isEmpty) return null;
    return JamesWillPromptConfig.fromMap(rows.first);
  }

  Future<String> promptText(String key) async {
    final config = await getPromptConfig(key);
    return config?.prompt.trim() ?? '';
  }

  Future<List<JamesWillPromptConfig>> listPromptConfigs() async {
    final db = await _db;
    final rows = await db.query('james_will_prompt_configs', orderBy: 'config_key ASC');
    return rows.map(JamesWillPromptConfig.fromMap).toList(growable: false);
  }

  Future<Map<String, int>> completeStats() async {
    final db = await _db;
    Future<int> count(String table) async {
      final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
      return willIntValue(rows.first['c']);
    }
    return <String, int>{
      'habits': await count('james_will_habits'),
      'reports': await count('james_will_weekly_reports'),
      'prompts': await count('james_will_prompt_configs'),
    };
  }
}
