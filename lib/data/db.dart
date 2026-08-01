
import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/services.dart';

class AppDatabase {
  static Database? _db;
  static Future<Database>? _opening;

  static Future<Database> instance() async {
    if (_db != null) return _db!;
    if (_opening != null) return await _opening!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'quotes.db');
    _opening = openDatabase(
      path,
      // Bump the database version to trigger onUpgrade for recent migrations.
      // Increasing this version number ensures that any device with an older
      // schema (missing columns or tables) will run the upgrade logic below.
      // Without bumping, onUpgrade would not be invoked on devices that have
      // already migrated, and thus they would not receive fixes such as
      // idempotent creation of the logs table.  We bump the version to 13 here
      // so that devices upgrading from version 12 will still execute the
      // _upgrade logic which ensures the logs table exists.  Future changes
      // should increment this value accordingly.
      // v35: rebuild legacy 知行树 action tables that still contain required
      // columns such as diagnosis_id from pre-product schemas.
      version: 35,
      onCreate: _create,
      onUpgrade: _upgrade,
    );
    try {
      _db = await _opening!;
    } finally {
      _opening = null;
    }

    // Debug: print DB absolute path and notify native
    try {
      // ignore: avoid_print
      print('[DBG] AppDatabase opened at: ' + path);

    // --- enumerate db schema
    final db = _db!;  // assert non-null: we just opened it above (all user tables & columns) ---
    final List<Map<String, Object?>> _tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");
    final Map<String, List<String>> _schema = {};
    for (final t in _tables) {
      final name = (t['name'] ?? '') as String;
      if (name.isEmpty) continue;
      final cols = await db.rawQuery('PRAGMA table_info(' + name + ')');
      final List<String> colNames = [];
      for (final c in cols) {
        final cn = (c['name'] ?? '') as String;
        if (cn.isNotEmpty) colNames.add(cn);
      }
      _schema[name] = colNames;
    }

      // Notify native side about database info. When running in background isolates (e.g. WorkManager),
      // the native.scheduler channel may not be registered, which would cause an unhandled
      // MissingPluginException if the future is not awaited and caught.  To avoid crashing,
      // await the call and catch any exception.
      try {
        const _ch = MethodChannel('native.scheduler');
        await _ch.invokeMethod('dbInfo', {'dbPath': path, 'version': 5, 'schema': _schema});
      } catch (_) {
        // ignore missing plugin errors when background isolate is missing native channel
      }
    } catch (t) { /* ignore */ }

    await _db!.execute('PRAGMA foreign_keys = ON');

    // This lives at the database boundary (rather than only inside the 知行树
    // DAO) so an already-installed app repairs the legacy table as soon as it
    // opens the database.  It prevents an old schema from reaching the
    // “开始并记录” insert path without action_uid.
    try {
      await ensureZhixingActionSchema(_db!);
    } catch (_) {
      // The DAO repeats this idempotent repair before every 知行树 access.
    }

    // --- Ensure "Change · Self-help" and Fitbit integration tables exist ---
    // These CREATE statements are idempotent and safe to run on every open.
    try {
      final db = _db!;
      await db.execute('''
        CREATE TABLE IF NOT EXISTS self_help_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          timestamp_ms INTEGER NOT NULL,
          stai6_score INTEGER,
          stai6_prorated REAL,
          arousal_0_100 REAL,
          valence_0_100 REAL,
          demand_0_100 REAL,
          resources_0_100 REAL,
          distress_0_100 REAL,
          bpm REAL,
          rmssd_ms REAL,
          signal_quality REAL,
          -- composite model outputs
          arousal_0_10 REAL,
          confidence_0_1 REAL,
          subjective_index_0_1 REAL,
          physiological_index_0_1 REAL,
          model_version TEXT,
          model_explain TEXT,
          warnings_json TEXT,
          -- wearable snapshot (Fitbit, best-effort)
          fitbit_resting_bpm REAL,
          fitbit_current_bpm REAL,
          fitbit_hrv_rmssd_ms REAL,
          fitbit_breathing_rate REAL,
          fitbit_sleep_minutes REAL,
          fitbit_sleep_efficiency REAL,
          fitbit_steps REAL,
          fitbit_spo2_avg REAL,
          fitbit_skin_temp_dev REAL,
          fitbit_active_zone_minutes REAL,
          fitbit_cardio_score REAL,
          zone TEXT,
          note TEXT
        )
      ''');


      // Ensure new subjective appraisal columns exist (idempotent on upgrades).
      try {
        final infoSelfHelp = await db.rawQuery("PRAGMA table_info(self_help_records)");
        final colsSelfHelp = infoSelfHelp.map((e) => e['name'] as String).toList();
        if (!colsSelfHelp.contains('demand_0_100')) await db.execute("ALTER TABLE self_help_records ADD COLUMN demand_0_100 REAL");
        if (!colsSelfHelp.contains('resources_0_100')) await db.execute("ALTER TABLE self_help_records ADD COLUMN resources_0_100 REAL");
        if (!colsSelfHelp.contains('distress_0_100')) await db.execute("ALTER TABLE self_help_records ADD COLUMN distress_0_100 REAL");

        // Composite model columns (idempotent)
        if (!colsSelfHelp.contains('arousal_0_10')) await db.execute("ALTER TABLE self_help_records ADD COLUMN arousal_0_10 REAL");
        if (!colsSelfHelp.contains('confidence_0_1')) await db.execute("ALTER TABLE self_help_records ADD COLUMN confidence_0_1 REAL");
        if (!colsSelfHelp.contains('subjective_index_0_1')) await db.execute("ALTER TABLE self_help_records ADD COLUMN subjective_index_0_1 REAL");
        if (!colsSelfHelp.contains('physiological_index_0_1')) await db.execute("ALTER TABLE self_help_records ADD COLUMN physiological_index_0_1 REAL");
        if (!colsSelfHelp.contains('model_version')) await db.execute("ALTER TABLE self_help_records ADD COLUMN model_version TEXT");
        if (!colsSelfHelp.contains('model_explain')) await db.execute("ALTER TABLE self_help_records ADD COLUMN model_explain TEXT");
        if (!colsSelfHelp.contains('warnings_json')) await db.execute("ALTER TABLE self_help_records ADD COLUMN warnings_json TEXT");

        // Fitbit snapshot columns
        if (!colsSelfHelp.contains('fitbit_resting_bpm')) await db.execute("ALTER TABLE self_help_records ADD COLUMN fitbit_resting_bpm REAL");
        if (!colsSelfHelp.contains('fitbit_current_bpm')) await db.execute("ALTER TABLE self_help_records ADD COLUMN fitbit_current_bpm REAL");
        if (!colsSelfHelp.contains('fitbit_hrv_rmssd_ms')) await db.execute("ALTER TABLE self_help_records ADD COLUMN fitbit_hrv_rmssd_ms REAL");
        if (!colsSelfHelp.contains('fitbit_breathing_rate')) await db.execute("ALTER TABLE self_help_records ADD COLUMN fitbit_breathing_rate REAL");
        if (!colsSelfHelp.contains('fitbit_sleep_minutes')) await db.execute("ALTER TABLE self_help_records ADD COLUMN fitbit_sleep_minutes REAL");
        if (!colsSelfHelp.contains('fitbit_sleep_efficiency')) await db.execute("ALTER TABLE self_help_records ADD COLUMN fitbit_sleep_efficiency REAL");
        if (!colsSelfHelp.contains('fitbit_steps')) await db.execute("ALTER TABLE self_help_records ADD COLUMN fitbit_steps REAL");
        if (!colsSelfHelp.contains('fitbit_spo2_avg')) await db.execute("ALTER TABLE self_help_records ADD COLUMN fitbit_spo2_avg REAL");
        if (!colsSelfHelp.contains('fitbit_skin_temp_dev')) await db.execute("ALTER TABLE self_help_records ADD COLUMN fitbit_skin_temp_dev REAL");
        if (!colsSelfHelp.contains('fitbit_active_zone_minutes')) await db.execute("ALTER TABLE self_help_records ADD COLUMN fitbit_active_zone_minutes REAL");
        if (!colsSelfHelp.contains('fitbit_cardio_score')) await db.execute("ALTER TABLE self_help_records ADD COLUMN fitbit_cardio_score REAL");
      } catch (_) {
        // ignore
      }

      await db.execute('''
        CREATE TABLE IF NOT EXISTS fitbit_auth (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT,
          access_token TEXT,
          refresh_token TEXT,
          scope TEXT,
          expires_at_ms INTEGER
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS fitbit_cache (
          cache_key TEXT PRIMARY KEY,
          endpoint TEXT,
          date TEXT,
          json TEXT,
          updated_at_ms INTEGER
        )
      ''');

      // Lightweight key-value storage used by integrated modules for
      // small records such as prompt overrides, actions and progress.
      // Some existing user databases may predate this table, so we
      // ensure it exists on every open instead of relying only on
      // onCreate/onUpgrade.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS notify_config (
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');

      await _ensureVoiceLabTables(db);
      await ensureAiAssistantTables(db);
      await ensureSemanticConsistencyTables(db);

      // Lightweight telemetry logs for self-help module (PPG / Fitbit / model debugging).
      await db.execute('''
        CREATE TABLE IF NOT EXISTS self_help_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ts_ms INTEGER NOT NULL,
          level TEXT,
          module TEXT,
          message TEXT,
          extra_json TEXT
        )
      ''');

    } catch (_) {
      // ignore: table creation should never break app startup
    }

    // Ensure critical columns exist in quotes and tasks tables.  Some devices may
    // have upgraded to a newer database version without running onUpgrade (for
    // example, if the version number did not change), leaving columns such
    // as task_type/task_name missing.  To avoid "no column named task_type"
    // errors during inserts, we detect missing columns here and add them on
    // first open.  Each ALTER TABLE is wrapped in a try/catch to be idempotent.
    try {
      final db = _db!;
      // Quotes table columns to ensure (avoid duplicate-column logs)
final infoQuotes = await db.rawQuery("PRAGMA table_info(quotes)");
final colsQuotes = infoQuotes.map((e) => e['name'] as String).toList();
if (!colsQuotes.contains('task_type'))        await db.execute("ALTER TABLE quotes ADD COLUMN task_type TEXT");
if (!colsQuotes.contains('task_name'))        await db.execute("ALTER TABLE quotes ADD COLUMN task_name TEXT");
if (!colsQuotes.contains('theme'))            await db.execute("ALTER TABLE quotes ADD COLUMN theme TEXT");
if (!colsQuotes.contains('author_name'))      await db.execute("ALTER TABLE quotes ADD COLUMN author_name TEXT");
if (!colsQuotes.contains('source_from'))      await db.execute("ALTER TABLE quotes ADD COLUMN source_from TEXT");
if (!colsQuotes.contains('explanation'))      await db.execute("ALTER TABLE quotes ADD COLUMN explanation TEXT");
if (!colsQuotes.contains('inserted_at'))      await db.execute("ALTER TABLE quotes ADD COLUMN inserted_at TEXT");
if (!colsQuotes.contains('last_notified_at')) await db.execute("ALTER TABLE quotes ADD COLUMN last_notified_at TEXT");
if (!colsQuotes.contains('avatar'))           await db.execute("ALTER TABLE quotes ADD COLUMN avatar TEXT");
// Legacy camelCase columns for backward-compat with older builds
if (!colsQuotes.contains('taskType'))         await db.execute("ALTER TABLE quotes ADD COLUMN taskType TEXT");
if (!colsQuotes.contains('taskName'))         await db.execute("ALTER TABLE quotes ADD COLUMN taskName TEXT");

// Configs table columns to ensure
final infoConfigs = await db.rawQuery("PRAGMA table_info(configs)");
final colsConfigs = infoConfigs.map((e) => e['name'] as String).toList();
if (!colsConfigs.contains('recent_hours'))        await db.execute("ALTER TABLE configs ADD COLUMN recent_hours INTEGER DEFAULT 2");
if (!colsConfigs.contains('overview_threshold')) await db.execute("ALTER TABLE configs ADD COLUMN overview_threshold INTEGER DEFAULT 500");
if (!colsConfigs.contains('ema_enabled'))     await db.execute("ALTER TABLE configs ADD COLUMN ema_enabled INTEGER DEFAULT 0");
if (!colsConfigs.contains('esteem_scale'))   await db.execute("ALTER TABLE configs ADD COLUMN esteem_scale INTEGER DEFAULT 100");
if (!colsConfigs.contains('sses_index'))     await db.execute("ALTER TABLE configs ADD COLUMN sses_index INTEGER DEFAULT 0");
if (!colsConfigs.contains('baidu_ak'))       await db.execute("ALTER TABLE configs ADD COLUMN baidu_ak TEXT DEFAULT 'kmHcLsW5heS5miYWLpbRUsrQapGIJ5m2'");
if (!colsConfigs.contains('baidu_ak_android')) await db.execute("ALTER TABLE configs ADD COLUMN baidu_ak_android TEXT DEFAULT 'oMtxRk6dE7Q8w8SXZ3frrwzAak3gqOTh'");
if (!colsConfigs.contains('sport_running_bg')) await db.execute("ALTER TABLE configs ADD COLUMN sport_running_bg TEXT");
if (!colsConfigs.contains('sport_start_sound')) await db.execute("ALTER TABLE configs ADD COLUMN sport_start_sound TEXT");
if (!colsConfigs.contains('sport_music_playlist')) await db.execute("ALTER TABLE configs ADD COLUMN sport_music_playlist TEXT");
if (!colsConfigs.contains('sport_music_mode')) await db.execute("ALTER TABLE configs ADD COLUMN sport_music_mode TEXT DEFAULT 'order'");
if (!colsConfigs.contains('openrouter_key')) await db.execute("ALTER TABLE configs ADD COLUMN openrouter_key TEXT");
if (!colsConfigs.contains('mood_card_popup_enabled')) await db.execute("ALTER TABLE configs ADD COLUMN mood_card_popup_enabled INTEGER DEFAULT 1");
if (!colsConfigs.contains('mood_card_popup_delay_ms')) await db.execute("ALTER TABLE configs ADD COLUMN mood_card_popup_delay_ms INTEGER DEFAULT 5000");

// Emotions table columns to ensure
final infoEmotions = await db.rawQuery("PRAGMA table_info(emotions)");
final colsEmotions = infoEmotions.map((e) => e['name'] as String).toList();
if (!colsEmotions.contains('type'))           await db.execute("ALTER TABLE emotions ADD COLUMN type TEXT");

// Tasks table columns to ensure

      final infoTasks = await db.rawQuery("PRAGMA table_info(tasks)");
      final colsTasks = infoTasks.map((e) => e['name'] as String).toList();
      if (!colsTasks.contains('task_uid'))   await db.execute("ALTER TABLE tasks ADD COLUMN task_uid TEXT");
      if (!colsTasks.contains('name'))       await db.execute("ALTER TABLE tasks ADD COLUMN name TEXT");
      if (!colsTasks.contains('task_type'))  await db.execute("ALTER TABLE tasks ADD COLUMN task_type TEXT");
      if (!colsTasks.contains('start_time')) await db.execute("ALTER TABLE tasks ADD COLUMN start_time TEXT");
      if (!colsTasks.contains('prompt'))     await db.execute("ALTER TABLE tasks ADD COLUMN prompt TEXT");
      if (!colsTasks.contains('avatar'))     await db.execute("ALTER TABLE tasks ADD COLUMN avatar TEXT");
      if (!colsTasks.contains('status'))     await db.execute("ALTER TABLE tasks ADD COLUMN status TEXT");
      // Ensure cursor column exists; used by bulk import tasks for quote navigation
      if (!colsTasks.contains('cursor'))     await db.execute("ALTER TABLE tasks ADD COLUMN cursor INTEGER DEFAULT 0");
      // Ensure carousel_order column exists; used by carousel tasks to store play order
      if (!colsTasks.contains('carousel_order')) await db.execute("ALTER TABLE tasks ADD COLUMN carousel_order TEXT DEFAULT 'desc'");
    } catch (_) {
      // ignore any errors; missing columns will raise on next upgrade
    }
    return _db!;
  }

  static Future<void> _create(Database db, int version) async {
    // Configs
    await db.execute('''
      CREATE TABLE configs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        api_key TEXT,
        model TEXT,
        endpoint TEXT,
        recent_hours INTEGER DEFAULT 2,
        overview_threshold INTEGER DEFAULT 500,
        -- 开关：是否启用量表自动报告功能，0=关闭，1=开启
        auto_report_enabled INTEGER DEFAULT 0,
        -- EMA 开关：是否启用即时自尊问答（EMA/SSES），0=关闭，1=开启
        ema_enabled INTEGER DEFAULT 0,
        -- 自尊评分尺度：100 或 30
        esteem_scale INTEGER DEFAULT 100,
        -- SSES 轮换问卷索引（0-5），默认 0
        sses_index INTEGER DEFAULT 0,
        -- 百度 Web API AK（用于 Web 逆地理 / Place / IP 等）
        baidu_ak TEXT DEFAULT 'kmHcLsW5heS5miYWLpbRUsrQapGIJ5m2',
        -- 百度 Android SDK AK（用于定位/搜索 SDK，依赖包名+SHA1）
        baidu_ak_android TEXT DEFAULT 'oMtxRk6dE7Q8w8SXZ3frrwzAak3gqOTh',
        -- 地点规则开关：是否启用地点规则提醒（0=关闭，1=开启）
        location_rules_enabled INTEGER DEFAULT 0,
        -- TMDb Read Access Token，用于电影榜单与收藏功能
        movie_token TEXT,
        -- DeepSeek API key（用于 DeepSeek 翻译功能）
        deepseek_key TEXT,
        -- DeepSeek 模型名称（默认为 deepseek-v4-pro）
        deepseek_model TEXT DEFAULT 'deepseek-v4-pro',
        -- OpenRouter API key（用于通过 OpenRouter 调用聚合模型）
        openrouter_key TEXT,
        -- 运动进行时背景图片路径（本地文件）
        sport_running_bg TEXT,
        -- 运动开始铃声（自定义本地音频路径；为空则使用系统通知铃声）
        sport_start_sound TEXT,
        -- 运动进行时播放清单（JSON 数组，保存本地音频路径）
        sport_music_playlist TEXT,
        -- 播放模式：order / random
        sport_music_mode TEXT DEFAULT 'order',
        -- 运动音乐与背景图绑定映射，JSON: {musicPath:[img1,img2]}
        sport_music_bg_bindings TEXT,
        -- 发现之旅：此时此刻心情卡片弹出开关，0=关闭，1=开启
        mood_card_popup_enabled INTEGER DEFAULT 1,
        -- 发现之旅：此时此刻心情卡片延迟弹出时间（毫秒）
        mood_card_popup_delay_ms INTEGER DEFAULT 5000
      )
    ''');
    // 轻量键值配置表：用于存储解锁冷却时间、开关、百度AK等配置
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notify_config (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await _ensureVoiceLabTables(db);
    await ensureAiAssistantTables(db);

    // Self-help measurement records (Change module)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS self_help_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp_ms INTEGER NOT NULL,
        stai6_score INTEGER,
        stai6_prorated REAL,
        arousal_0_100 REAL,
        valence_0_100 REAL,
        demand_0_100 REAL,
        resources_0_100 REAL,
        distress_0_100 REAL,
        bpm REAL,
        rmssd_ms REAL,
        signal_quality REAL,
        -- composite model outputs
        arousal_0_10 REAL,
        confidence_0_1 REAL,
        subjective_index_0_1 REAL,
        physiological_index_0_1 REAL,
        model_version TEXT,
        model_explain TEXT,
        warnings_json TEXT,
        -- wearable snapshot (Fitbit, best-effort)
        fitbit_resting_bpm REAL,
        fitbit_current_bpm REAL,
        fitbit_hrv_rmssd_ms REAL,
        fitbit_breathing_rate REAL,
        fitbit_sleep_minutes REAL,
        fitbit_sleep_efficiency REAL,
        fitbit_steps REAL,
        fitbit_spo2_avg REAL,
        fitbit_skin_temp_dev REAL,
        fitbit_active_zone_minutes REAL,
        fitbit_cardio_score REAL,
        zone TEXT,
        note TEXT
      )
    ''');

    // Fitbit auth + cache (OAuth tokens are stored locally; cache stores raw JSON for endpoints)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fitbit_auth (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT,
        access_token TEXT,
        refresh_token TEXT,
        scope TEXT,
        expires_at_ms INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fitbit_cache (
        cache_key TEXT PRIMARY KEY,
        endpoint TEXT,
        date TEXT,
        json TEXT,
        updated_at_ms INTEGER
      )
    ''');


    // Backup table for restoring original order (方案B)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quotes_id_backup (
        quote_uid TEXT PRIMARY KEY,
        original_id INTEGER,
        original_pos INTEGER
      )
    ''');
    await db.insert('configs', {
      'api_key': '',
      'model': 'gpt-5',
      'endpoint': 'https://api.openai.com/v1/responses',
      'recent_hours': 2,
      'overview_threshold': 500,
      'auto_report_enabled': 0,
      'location_rules_enabled': 0,
      // DeepSeek defaults
      'deepseek_key': '',
      'deepseek_model': 'deepseek-v4-pro',
      // Initialize movie_token as null; the DAO will fall back to a default constant
      'movie_token': null
    });

    // Meta key-value
    await db.execute('''
      CREATE TABLE meta (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // Create movie favorites table. This stores user‑collected movies from TMDb.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS movie_favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tmdb_id INTEGER UNIQUE,
        title TEXT,
        overview TEXT,
        poster_path TEXT,
        backdrop_path TEXT,
        vote_average REAL,
        vote_count INTEGER,
        release_date TEXT,
        raw_json TEXT NOT NULL,
        created_at TEXT
      )
    ''');

    // Tasks
    // Additional columns `next_time` and `scheduled_run_key` are included by
    // default in the schema.  They will be used to store the next scheduled
    // run time and the last registered runKey respectively.  Older database
    // versions will be migrated via ensureExtraTaskColumns().
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_uid TEXT UNIQUE,
        name TEXT,
        type TEXT,          -- manual | auto | carousel | 批量导入任务
        status TEXT,        -- on | off
        prompt TEXT,        -- for auto
        avatar_path TEXT,   -- icon path
        start_time TEXT,    -- 'HH:mm' or 'YYYY-MM-DD HH:mm[:ss]'
        freq_type TEXT,     -- daily | weekly | monthly | custom
        freq_weekday INTEGER,       -- 1-7 (Mon-Sun) when weekly
        freq_day_of_month INTEGER,  -- 1-31 when monthly
        freq_custom TEXT,            -- reserved
        next_time TEXT,              -- ISO8601 next run time
        scheduled_run_key TEXT,      -- last scheduled runKey for cancellation
        cursor INTEGER DEFAULT 0,     -- index into quotes for bulk import tasks
        carousel_order TEXT DEFAULT 'desc'    -- order for carousel tasks: desc | asc | random
      )
    ''');

    // Quotes
    await db.execute('''
      CREATE TABLE quotes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        quote_uid TEXT UNIQUE,
        task_uid TEXT,
        content TEXT,
        notified INTEGER DEFAULT 0,
        created_at INTEGER,
        
        theme TEXT,
        author_name TEXT,
        source_from TEXT,
        explanation TEXT,
        avatar TEXT,
        inserted_at TEXT,
        last_notified_at TEXT,
        taskType TEXT,
        taskName TEXT,
        FOREIGN KEY(task_uid) REFERENCES tasks(task_uid) ON DELETE CASCADE
      )
    ''' );

    // Table for fixed quotes.  Each record stores a snapshot of quote data
    // for the "名人名言固定表" feature.  This table references the quotes
    // table via quote_id (nullable, on delete set null) and enforces
    // uniqueness on content to prevent duplicate pins.  Fields mirror the
    // primary quote fields (theme/topic, author_name, source_from, explanation,
    // avatar) so that pinned items remain intact even if the original quote
    // record is edited.  A separate fixed_uid is used as a stable primary key.
    await db.execute('''
      CREATE TABLE quotes_fixed (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fixed_uid TEXT UNIQUE,
        quote_id INTEGER,
        content TEXT UNIQUE,
        theme TEXT,
        author_name TEXT,
        source_from TEXT,
        explanation TEXT,
        avatar TEXT,
        FOREIGN KEY(quote_id) REFERENCES quotes(id) ON DELETE SET NULL
      )
    ''');

    // Logs table.  Using IF NOT EXISTS here makes creation idempotent in
    // case the table already exists when onCreate is triggered.  Without
    // IF NOT EXISTS the CREATE TABLE statement would throw "table ... already exists"
    // which propagates as a DatabaseException and blocks subsequent
    // database operations.  See bug reports around 2025-11-23.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        log_uid TEXT UNIQUE,
        task_uid TEXT,
        detail TEXT,
        created_at INTEGER,
        task_name_snapshot TEXT,
        task_start_time_snapshot TEXT
      )
    ''');

    // Telemetry logs for self-help module (PPG / Fitbit / model debugging).
    await db.execute('''
      CREATE TABLE IF NOT EXISTS self_help_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ts_ms INTEGER NOT NULL,
        level TEXT,
        module TEXT,
        message TEXT,
        extra_json TEXT
      )
    ''');


    // ------------------------------------------------------------------
    // API response cache for Space module (tab list data caching)
    // key: stable identifier (endpoint + parameters)
    // json: raw response or serialized list
    await db.execute('''
      CREATE TABLE IF NOT EXISTS api_cache (
        cache_key TEXT PRIMARY KEY,
        json TEXT NOT NULL,
        updated_at INTEGER
      )
    ''');

    // Translation cache for DeepSeek (persistent translation results)
    // key: sha1(model|target|sourceText)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS translation_cache (
        cache_key TEXT PRIMARY KEY,
        model TEXT,
        target TEXT,
        source_text TEXT,
        translated_text TEXT NOT NULL,
        updated_at INTEGER
      )
    ''');
  

    // Emotions: user mood records
    await db.execute('''
      CREATE TABLE emotions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        emotion_uid TEXT UNIQUE,
        emoji_char TEXT,
        emoji_name TEXT,
        emoji_tags TEXT,
        behavior TEXT,
        trigger_event TEXT,
        thought TEXT,
        type TEXT,
        inserted_at TEXT
      )
    ''');

    // Sport plans: stores user-defined exercise plans. Each row captures the
    // configuration of a scheduled exercise such as walk/run.  The repeat
    // columns encode how often the plan repeats and are stored as simple
    // strings (e.g. 'daily', 'weekly', 'monthly', 'custom').  Plan times
    // are stored in ISO8601 strings for ease of parsing.  Status is a
    // free‑form text field allowing enums like: not_started, in_progress,
    // paused, completed, stopped, expired, canceled.  The notify_enabled
    // column stores whether notifications should be triggered (0/1) and
    // notify_advance holds the number of minutes prior to the plan time to
    // send the reminder.  Repeat_detail stores serialized JSON of
    // additional scheduling info such as selected weekdays.
    await db.execute('''
      CREATE TABLE sport_plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        sport_type TEXT,
        target_type TEXT,
        target_value REAL,
        target_unit TEXT,
        repeat_type TEXT,
        repeat_detail TEXT,
        plan_time TEXT,
        notify_enabled INTEGER,
        notify_advance INTEGER,
        status TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Sport records: stores historical exercise records.  Each record may
    // reference a sport plan via plan_id or be null when the exercise is
    // started instantly.  Mode indicates whether the record originated
    // from a plan ('plan') or was started on demand ('instant').  The
    // start_time and end_time fields capture the actual timestamps of
    // activity.  Duration, steps, distance and average speed capture
    // metrics measured during the exercise.  Start_location and
    // end_location store serialized JSON containing geolocation data (e.g.
    // latitude, longitude, address).  The target fields mirror the
    // associated plan's target at the time of execution.  Status matches
    // the plan status definitions.
    await db.execute('''
      CREATE TABLE sport_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id INTEGER,
        title TEXT,
        sport_type TEXT,
        mode TEXT,
        plan_time TEXT,
        start_time TEXT,
        end_time TEXT,
        total_duration INTEGER,
        paused_total_sec INTEGER,
        total_steps INTEGER,
        total_distance REAL,
        avg_speed REAL,
        current_speed REAL,
        start_location TEXT,
        end_location TEXT,
        target_type TEXT,
        target_value REAL,
        target_unit TEXT,
        status TEXT,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY(plan_id) REFERENCES sport_plans(id) ON DELETE SET NULL
      )
    ''');

    // Sport quotes: 名人名言（运动专用）。为空时由业务层兜底。
    await db.execute('''
      CREATE TABLE sport_quotes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT,
        author TEXT,
        explanation TEXT,
        enabled INTEGER,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // 量表相关表：用于存储量表元数据、题目配置、选项、评分规则以及测评记录。
    // 这些表与原有功能相互独立，通过 scale_id 与 assessment 外键关联。
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scale_code TEXT UNIQUE,
        version TEXT,
        name TEXT,
        language TEXT,
        description TEXT,
        author TEXT,
        copyright TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scale_dimensions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scale_id INTEGER,
        dimension_code TEXT,
        name TEXT,
        description TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scale_id INTEGER,
        item_code TEXT,
        item_no INTEGER,
        content TEXT,
        item_type TEXT,
        dimension_code TEXT,
        is_reverse INTEGER,
        scoring_type TEXT,
        remark TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scale_item_options (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scale_item_id INTEGER,
        option_code TEXT,
        label TEXT,
        option_value TEXT,
        base_score REAL,
        extra_rule TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scale_report_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scale_id INTEGER,
        dimension_code TEXT,
        min_score REAL,
        max_score REAL,
        level TEXT,
        template TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scale_assessments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT,
        scale_id INTEGER,
        total_score REAL,
        level TEXT,
        report_text TEXT,
        created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scale_assessment_answers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        assessment_id INTEGER,
        scale_item_id INTEGER,
        option_id INTEGER,
        option_value TEXT,
        score REAL
      )
    ''');
    // Safe: seed backup mapping AFTER quotes table exists
    try {
      await db.execute("INSERT OR IGNORE INTO quotes_id_backup(quote_uid, original_id, original_pos) SELECT quote_uid, id, rowid FROM quotes");
    } catch (_) {}
}

  static Future<void> _ensureMeta(Database db) async {
    // placeholder if future migrations need to alter meta schema
  }

  


static Future<void> ensureAiAssistantTables(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ai_assistant_conversations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL DEFAULT '新会话',
      provider TEXT,
      model TEXT,
      context_mode TEXT NOT NULL DEFAULT 'full_history',
      created_at_ms INTEGER NOT NULL,
      updated_at_ms INTEGER NOT NULL,
      deleted_at_ms INTEGER,
      message_count INTEGER NOT NULL DEFAULT 0,
      provider_conversation_id TEXT,
      provider_previous_response_id TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ai_assistant_messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      conversation_id INTEGER NOT NULL,
      role TEXT NOT NULL,
      content TEXT NOT NULL,
      provider TEXT,
      model TEXT,
      created_at_ms INTEGER NOT NULL,
      latency_ms INTEGER,
      error TEXT,
      embedding_json TEXT,
      embedding_model TEXT,
      embedding_updated_at_ms INTEGER,
      feedback_rating INTEGER NOT NULL DEFAULT 0,
      feedback_reason TEXT,
      feedback_comment TEXT,
      context_weight REAL NOT NULL DEFAULT 0,
      exclude_from_context INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY(conversation_id) REFERENCES ai_assistant_conversations(id) ON DELETE CASCADE
    )
  ''');
  await _addColumnIfMissing(db, 'ai_assistant_conversations', 'context_mode', "TEXT NOT NULL DEFAULT 'full_history'");
  await _addColumnIfMissing(db, 'ai_assistant_conversations', 'provider_conversation_id', 'TEXT');
  await _addColumnIfMissing(db, 'ai_assistant_conversations', 'provider_previous_response_id', 'TEXT');
  await _addColumnIfMissing(db, 'ai_assistant_messages', 'embedding_json', 'TEXT');
  await _addColumnIfMissing(db, 'ai_assistant_messages', 'embedding_model', 'TEXT');
  await _addColumnIfMissing(db, 'ai_assistant_messages', 'embedding_updated_at_ms', 'INTEGER');
  await _addColumnIfMissing(db, 'ai_assistant_messages', 'feedback_rating', 'INTEGER NOT NULL DEFAULT 0');
  await _addColumnIfMissing(db, 'ai_assistant_messages', 'feedback_reason', 'TEXT');
  await _addColumnIfMissing(db, 'ai_assistant_messages', 'feedback_comment', 'TEXT');
  await _addColumnIfMissing(db, 'ai_assistant_messages', 'context_weight', 'REAL NOT NULL DEFAULT 0');
  await _addColumnIfMissing(db, 'ai_assistant_messages', 'exclude_from_context', 'INTEGER NOT NULL DEFAULT 0');
  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_ai_assistant_messages_conversation
    ON ai_assistant_messages(conversation_id, created_at_ms, id)
  ''');
  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_ai_assistant_messages_embedding
    ON ai_assistant_messages(conversation_id, embedding_model, embedding_updated_at_ms)
  ''');
  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_ai_assistant_conversations_updated
    ON ai_assistant_conversations(deleted_at_ms, updated_at_ms DESC)
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ai_assistant_context_chunks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      conversation_id INTEGER NOT NULL,
      start_message_id INTEGER NOT NULL,
      end_message_id INTEGER NOT NULL,
      source_message_ids TEXT NOT NULL,
      chunk_text TEXT NOT NULL,
      content_hash TEXT NOT NULL,
      embedding_json TEXT,
      embedding_model TEXT,
      created_at_ms INTEGER NOT NULL,
      updated_at_ms INTEGER NOT NULL,
      start_created_at_ms INTEGER NOT NULL DEFAULT 0,
      end_created_at_ms INTEGER NOT NULL DEFAULT 0,
      chunk_version TEXT NOT NULL DEFAULT '',
      FOREIGN KEY(conversation_id) REFERENCES ai_assistant_conversations(id) ON DELETE CASCADE
    )
  ''');
  await _addColumnIfMissing(db, 'ai_assistant_context_chunks', 'start_created_at_ms', 'INTEGER NOT NULL DEFAULT 0');
  await _addColumnIfMissing(db, 'ai_assistant_context_chunks', 'end_created_at_ms', 'INTEGER NOT NULL DEFAULT 0');
  await _addColumnIfMissing(db, 'ai_assistant_context_chunks', 'chunk_version', "TEXT NOT NULL DEFAULT ''");
  await db.execute('''
    CREATE UNIQUE INDEX IF NOT EXISTS idx_ai_assistant_context_chunks_hash
    ON ai_assistant_context_chunks(conversation_id, chunk_version, content_hash)
  ''');
  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_ai_assistant_context_chunks_embedding
    ON ai_assistant_context_chunks(conversation_id, embedding_model, start_message_id, end_message_id)
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ai_assistant_memories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      conversation_id INTEGER NOT NULL,
      memory_key TEXT NOT NULL,
      memory_value TEXT NOT NULL,
      created_at_ms INTEGER NOT NULL DEFAULT 0,
      updated_at_ms INTEGER NOT NULL DEFAULT 0,
      UNIQUE(conversation_id, memory_key),
      FOREIGN KEY(conversation_id) REFERENCES ai_assistant_conversations(id) ON DELETE CASCADE
    )
  ''');
  // Some devices may already have an older ai_assistant_memories table from a
  // previous AI assistant build. CREATE TABLE IF NOT EXISTS will not add new
  // columns to an existing table, so keep these ALTERs idempotent and run them
  // whenever the assistant DAO ensures tables.
  await _addColumnIfMissing(db, 'ai_assistant_memories', 'created_at_ms', 'INTEGER NOT NULL DEFAULT 0');
  await _addColumnIfMissing(db, 'ai_assistant_memories', 'updated_at_ms', 'INTEGER NOT NULL DEFAULT 0');
  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_ai_assistant_memories_conversation
    ON ai_assistant_memories(conversation_id, updated_at_ms DESC)
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ai_assistant_summaries (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      conversation_id INTEGER NOT NULL UNIQUE,
      summary TEXT NOT NULL,
      covered_message_id_until INTEGER NOT NULL DEFAULT 0,
      created_at_ms INTEGER NOT NULL DEFAULT 0,
      updated_at_ms INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY(conversation_id) REFERENCES ai_assistant_conversations(id) ON DELETE CASCADE
    )
  ''');
  await _addColumnIfMissing(db, 'ai_assistant_summaries', 'covered_message_id_until', 'INTEGER NOT NULL DEFAULT 0');
  await _addColumnIfMissing(db, 'ai_assistant_summaries', 'created_at_ms', 'INTEGER NOT NULL DEFAULT 0');
  await _addColumnIfMissing(db, 'ai_assistant_summaries', 'updated_at_ms', 'INTEGER NOT NULL DEFAULT 0');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ai_assistant_attachments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      conversation_id INTEGER NOT NULL,
      message_id INTEGER NOT NULL,
      attachment_type TEXT NOT NULL DEFAULT 'file',
      name TEXT NOT NULL,
      path TEXT NOT NULL,
      mime_type TEXT,
      size_bytes INTEGER NOT NULL DEFAULT 0,
      extracted_text TEXT,
      provider TEXT,
      provider_file_id TEXT,
      provider_uploaded_at_ms INTEGER,
      provider_expires_at TEXT,
      created_at_ms INTEGER NOT NULL,
      FOREIGN KEY(conversation_id) REFERENCES ai_assistant_conversations(id) ON DELETE CASCADE,
      FOREIGN KEY(message_id) REFERENCES ai_assistant_messages(id) ON DELETE CASCADE
    )
  ''');
  await _addColumnIfMissing(db, 'ai_assistant_attachments', 'attachment_type', "TEXT NOT NULL DEFAULT 'file'");
  await _addColumnIfMissing(db, 'ai_assistant_attachments', 'mime_type', 'TEXT');
  await _addColumnIfMissing(db, 'ai_assistant_attachments', 'size_bytes', 'INTEGER NOT NULL DEFAULT 0');
  await _addColumnIfMissing(db, 'ai_assistant_attachments', 'extracted_text', 'TEXT');
  await _addColumnIfMissing(db, 'ai_assistant_attachments', 'provider', 'TEXT');
  await _addColumnIfMissing(db, 'ai_assistant_attachments', 'provider_file_id', 'TEXT');
  await _addColumnIfMissing(db, 'ai_assistant_attachments', 'provider_uploaded_at_ms', 'INTEGER');
  await _addColumnIfMissing(db, 'ai_assistant_attachments', 'provider_expires_at', 'TEXT');
  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_ai_assistant_attachments_message
    ON ai_assistant_attachments(conversation_id, message_id)
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ai_assistant_message_feedback_events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      conversation_id INTEGER NOT NULL,
      message_id INTEGER NOT NULL,
      rating INTEGER NOT NULL,
      reason TEXT,
      comment TEXT,
      created_at_ms INTEGER NOT NULL,
      FOREIGN KEY(conversation_id) REFERENCES ai_assistant_conversations(id) ON DELETE CASCADE,
      FOREIGN KEY(message_id) REFERENCES ai_assistant_messages(id) ON DELETE CASCADE
    )
  ''');
  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_ai_assistant_feedback_message
    ON ai_assistant_message_feedback_events(message_id, created_at_ms DESC)
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ai_assistant_ui_state (
      module_key TEXT PRIMARY KEY,
      bubble_dx REAL NOT NULL DEFAULT 0,
      bubble_dy REAL NOT NULL DEFAULT 0,
      updated_at_ms INTEGER NOT NULL
    )
  ''');
}

static Future<void> ensureSemanticConsistencyTables(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS semantic_consistency_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      mode TEXT NOT NULL,
      text_a TEXT NOT NULL,
      text_b TEXT NOT NULL,
      cosine_score REAL,
      relation TEXT,
      is_consistent INTEGER NOT NULL DEFAULT 0,
      confidence REAL,
      error_type TEXT,
      key_difference TEXT,
      reason TEXT,
      provider TEXT,
      model TEXT,
      embedding_provider TEXT,
      embedding_model TEXT,
      judge_provider TEXT,
      judge_model TEXT,
      raw_request TEXT,
      raw_response TEXT,
      created_at INTEGER NOT NULL,
      extra_json TEXT
    )
  ''');
  await _addColumnIfMissing(db, 'semantic_consistency_records', 'extra_json', 'TEXT');
  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_semantic_consistency_records_created
    ON semantic_consistency_records(created_at DESC, id DESC)
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS semantic_embedding_cache (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      text_hash TEXT NOT NULL,
      text_content TEXT NOT NULL,
      provider TEXT NOT NULL,
      model TEXT NOT NULL,
      dimensions INTEGER,
      vector_json TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      UNIQUE(text_hash, provider, model, dimensions)
    )
  ''');
  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_semantic_embedding_cache_lookup
    ON semantic_embedding_cache(text_hash, provider, model, dimensions)
  ''');
}

static Future<void> _ensureVoiceLabTables(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS voice_profile (
      id TEXT PRIMARY KEY,
      provider TEXT NOT NULL DEFAULT 'elevenlabs',
      display_name TEXT NOT NULL,
      elevenlabs_voice_id TEXT NOT NULL,
      clone_type TEXT DEFAULT 'instant',
      sample_audio_path TEXT,
      consent_audio_path TEXT,
      language TEXT DEFAULT 'zh',
      status TEXT NOT NULL DEFAULT 'ready',
      is_default INTEGER DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS tts_audio_file (
      id TEXT PRIMARY KEY,
      module_name TEXT NOT NULL,
      source_text TEXT NOT NULL,
      text_hash TEXT NOT NULL,
      provider TEXT NOT NULL DEFAULT 'elevenlabs',
      elevenlabs_voice_id TEXT NOT NULL,
      voice_profile_id TEXT,
      model_id TEXT DEFAULT 'eleven_multilingual_v2',
      audio_file_name TEXT NOT NULL,
      audio_file_path TEXT NOT NULL,
      mime_type TEXT DEFAULT 'audio/mpeg',
      file_size INTEGER DEFAULT 0,
      duration_ms INTEGER DEFAULT 0,
      is_downloaded INTEGER DEFAULT 0,
      downloaded_uri TEXT,
      downloaded_file_name TEXT,
      voice_source TEXT DEFAULT 'cloned',
      voice_display_name TEXT,
      tts_speed REAL DEFAULT 1.0,
      tts_stability REAL DEFAULT 0.55,
      tts_similarity_boost REAL DEFAULT 0.8,
      tts_style REAL DEFAULT 0.2,
      tts_use_speaker_boost INTEGER DEFAULT 1,
      language_code TEXT,
      text_normalization TEXT DEFAULT 'auto',
      scene TEXT DEFAULT 'natural_dialogue',
      pause_mode TEXT DEFAULT 'none',
      meditation_auto_pauses INTEGER DEFAULT 0,
      meditation_pause_profile TEXT DEFAULT 'standard',
      meditation_sentence_break_sec REAL DEFAULT 1.5,
      meditation_paragraph_break_sec REAL DEFAULT 2.4,
      meditation_breath_break_sec REAL DEFAULT 2.0,
      meditation_tone TEXT DEFAULT 'calm',
      meditation_auto_breath_pauses INTEGER DEFAULT 1,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
  await _addColumnIfMissing(db, 'tts_audio_file', 'voice_source', "TEXT DEFAULT 'cloned'");
  await _addColumnIfMissing(db, 'tts_audio_file', 'voice_display_name', 'TEXT');
  await _addColumnIfMissing(db, 'tts_audio_file', 'tts_speed', 'REAL DEFAULT 1.0');
  await _addColumnIfMissing(db, 'tts_audio_file', 'tts_stability', 'REAL DEFAULT 0.55');
  await _addColumnIfMissing(db, 'tts_audio_file', 'tts_similarity_boost', 'REAL DEFAULT 0.8');
  await _addColumnIfMissing(db, 'tts_audio_file', 'tts_style', 'REAL DEFAULT 0.2');
  await _addColumnIfMissing(db, 'tts_audio_file', 'tts_use_speaker_boost', 'INTEGER DEFAULT 1');
  await _addColumnIfMissing(db, 'tts_audio_file', 'language_code', 'TEXT');
  await _addColumnIfMissing(db, 'tts_audio_file', 'text_normalization', "TEXT DEFAULT 'auto'");
  await _addColumnIfMissing(db, 'tts_audio_file', 'scene', "TEXT DEFAULT 'natural_dialogue'");
  await _addColumnIfMissing(db, 'tts_audio_file', 'pause_mode', "TEXT DEFAULT 'none'");
  await _addColumnIfMissing(db, 'tts_audio_file', 'meditation_auto_pauses', 'INTEGER DEFAULT 0');
  await _addColumnIfMissing(db, 'tts_audio_file', 'meditation_pause_profile', "TEXT DEFAULT 'standard'");
  await _addColumnIfMissing(db, 'tts_audio_file', 'meditation_sentence_break_sec', 'REAL DEFAULT 1.5');
  await _addColumnIfMissing(db, 'tts_audio_file', 'meditation_paragraph_break_sec', 'REAL DEFAULT 2.4');
  await _addColumnIfMissing(db, 'tts_audio_file', 'meditation_breath_break_sec', 'REAL DEFAULT 2.0');
  await _addColumnIfMissing(db, 'tts_audio_file', 'meditation_tone', "TEXT DEFAULT 'calm'");
  await _addColumnIfMissing(db, 'tts_audio_file', 'meditation_auto_breath_pauses', 'INTEGER DEFAULT 1');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS virtual_teacher_config (
      id TEXT PRIMARY KEY,
      teacher_name TEXT NOT NULL,
      voice_profile_id TEXT,
      persona_prompt TEXT NOT NULL,
      opening_message TEXT,
      model_provider TEXT DEFAULT 'global',
      model_name TEXT,
      tts_model_id TEXT DEFAULT 'eleven_multilingual_v2',
      enable_voice_reply INTEGER DEFAULT 1,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
}

/// Adds a column only if it does not already exist.
/// This avoids noisy "duplicate column name" errors in SQLiteLog.
static Future<void> _addColumnIfMissing(
    Database db, String table, String column, String definition) async {
  final info = await db.rawQuery("PRAGMA table_info($table)");
  final cols = info.map((e) => e['name'] as String).toList();
  if (!cols.contains(column)) {
    await db.execute("ALTER TABLE $table ADD COLUMN $column $definition");
  }
}

/// Repairs the released pre-action_uid 知行树 action table in place.
///
/// Some devices already have the database at the previous app version, so
/// relying on `CREATE TABLE IF NOT EXISTS` is insufficient: SQLite keeps the
/// old columns.  Preserve every row and give legacy records a deterministic
/// ID before creating the unique index required by current writes.
static Future<void> ensureZhixingActionSchema(Database db) async {
  final exists = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'zhixing_actions'",
  );
  if (exists.isEmpty) return;

  final info = await db.rawQuery('PRAGMA table_info(zhixing_actions)');
  final existingColumns = info
      .map((row) => (row['name'] ?? '').toString())
      .where((name) => name.isNotEmpty)
      .toSet();
  const canonicalColumns = <String>{
    'id',
    'action_uid',
    'goal_id',
    'session_id',
    'title',
    'status',
    'difficulty',
    'barrier',
    'risk_level',
    'prescription_json',
    'created_at_ms',
    'updated_at_ms',
  };
  const requiredColumns = <String>{
    'action_uid',
    'title',
    'status',
    'difficulty',
    'barrier',
    'risk_level',
    'prescription_json',
    'created_at_ms',
    'updated_at_ms',
  };
  final nullableColumns = <String>{'goal_id', 'session_id'};
  final constraintsAreCanonical = info.every((row) {
    final name = (row['name'] ?? '').toString();
    final notNull = (row['notnull'] as num?)?.toInt() == 1;
    final primaryKey = (row['pk'] as num?)?.toInt() == 1;
    if (name == 'id') return primaryKey;
    if (requiredColumns.contains(name)) return notNull;
    if (nullableColumns.contains(name)) return !notNull;
    return false;
  });
  final needsRebuild = existingColumns.length != canonicalColumns.length ||
      !existingColumns.containsAll(canonicalColumns) ||
      !constraintsAreCanonical;

  if (needsRebuild) {
    final identity = existingColumns.contains('id') ? 'id' : 'rowid';
    final rows = await db.rawQuery(
      'SELECT $identity AS legacy_row_id, * '
      'FROM zhixing_actions ORDER BY $identity ASC',
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    final usedActionIds = <String>{};

    int integer(Object? value, [int fallback = 0]) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    int? nullableInteger(Object? value) {
      if (value == null) return null;
      final parsed = integer(value, -1);
      return parsed < 0 ? null : parsed;
    }

    String stringValue(Object? value, String fallback) {
      final text = (value ?? '').toString().trim();
      return text.isEmpty ? fallback : text;
    }

    String uniqueActionId(Map<String, Object?> row, int rowId) {
      final current = (row['action_uid'] ?? '').toString().trim();
      final fallback = 'legacy_action_$rowId';
      final base = current.isEmpty ? fallback : current;
      var candidate = base;
      var suffix = 2;
      while (usedActionIds.contains(candidate)) {
        candidate = '${base}_$suffix';
        suffix++;
      }
      usedActionIds.add(candidate);
      return candidate;
    }

    await db.transaction((txn) async {
      await txn.execute(
        'DROP TABLE IF EXISTS zhixing_actions__canonical_v35',
      );
      await txn.execute('''
        CREATE TABLE zhixing_actions__canonical_v35 (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          action_uid TEXT NOT NULL UNIQUE,
          goal_id INTEGER,
          session_id INTEGER,
          title TEXT NOT NULL,
          status TEXT NOT NULL,
          difficulty TEXT NOT NULL,
          barrier TEXT NOT NULL,
          risk_level TEXT NOT NULL,
          prescription_json TEXT NOT NULL,
          created_at_ms INTEGER NOT NULL,
          updated_at_ms INTEGER NOT NULL
        )
      ''');
      for (final row in rows) {
        final rowId = integer(row['legacy_row_id']);
        final storedId = integer(row['id'], rowId);
        final createdAt = integer(row['created_at_ms'], now);
        await txn.insert(
          'zhixing_actions__canonical_v35',
          <String, Object?>{
            if (storedId > 0) 'id': storedId,
            'action_uid': uniqueActionId(row, rowId),
            'goal_id': nullableInteger(row['goal_id']),
            'session_id': nullableInteger(
              row['session_id'] ?? row['diagnosis_id'],
            ),
            'title': stringValue(row['title'], '历史行动'),
            'status': stringValue(row['status'], 'active'),
            'difficulty': stringValue(row['difficulty'], 'l0'),
            'barrier': stringValue(
              row['barrier'],
              'reflectiveMotivation',
            ),
            'risk_level': stringValue(row['risk_level'], 'r0'),
            'prescription_json': stringValue(
              row['prescription_json'],
              '{}',
            ),
            'created_at_ms': createdAt,
            'updated_at_ms': integer(row['updated_at_ms'], createdAt),
          },
        );
      }
      await txn.execute('DROP TABLE zhixing_actions');
      await txn.execute(
        'ALTER TABLE zhixing_actions__canonical_v35 '
        'RENAME TO zhixing_actions',
      );
    });
  }
  await db.execute(
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_zhixing_actions_uid '
    'ON zhixing_actions(action_uid)',
  );
}

static Future<void> _upgrade(Database db, int oldV, int newV) async {

await _ensureVoiceLabTables(db);
await ensureAiAssistantTables(db);
await ensureSemanticConsistencyTables(db);

// Add missing columns safely (no duplicate-column logs).
await _addColumnIfMissing(db, 'quotes', 'task_type', 'TEXT');
await _addColumnIfMissing(db, 'quotes', 'task_name', 'TEXT');
await _addColumnIfMissing(db, 'quotes', 'theme', 'TEXT');
await _addColumnIfMissing(db, 'quotes', 'author_name', 'TEXT');
await _addColumnIfMissing(db, 'quotes', 'source_from', 'TEXT');
await _addColumnIfMissing(db, 'quotes', 'explanation', 'TEXT');
await _addColumnIfMissing(db, 'quotes', 'inserted_at', 'TEXT');
await _addColumnIfMissing(db, 'quotes', 'last_notified_at', 'TEXT');
await _addColumnIfMissing(db, 'quotes', 'avatar', 'TEXT');
// Legacy camelCase columns for older builds
await _addColumnIfMissing(db, 'quotes', 'taskType', 'TEXT');
await _addColumnIfMissing(db, 'quotes', 'taskName', 'TEXT');

await _addColumnIfMissing(db, 'configs', 'recent_hours', 'INTEGER DEFAULT 2');

    // Ensure measurement related schema exists and new config column is present.
    // 自动报告开关列
    await _addColumnIfMissing(db, 'configs', 'auto_report_enabled', 'INTEGER DEFAULT 0');

    // === 自定义新增列 ===
    // 是否启用 EMA / SSES 自尊题问答（0 关闭, 1 开启）
    await _addColumnIfMissing(db, 'configs', 'ema_enabled', 'INTEGER DEFAULT 0');
    // 自尊评分尺度（100 或 30），默认为 100
    await _addColumnIfMissing(db, 'configs', 'esteem_scale', 'INTEGER DEFAULT 100');
    // SSES 轮换问卷索引（0-5），记录用户上次答题进度，默认 0
    await _addColumnIfMissing(db, 'configs', 'sses_index', 'INTEGER DEFAULT 0');
    // 地点规则开关列
    await _addColumnIfMissing(db, 'configs', 'location_rules_enabled', 'INTEGER DEFAULT 0');
    // 百度 AK（Web & Android）
    await _addColumnIfMissing(db, 'configs', 'baidu_ak', "TEXT DEFAULT 'kmHcLsW5heS5miYWLpbRUsrQapGIJ5m2'");
    await _addColumnIfMissing(db, 'configs', 'baidu_ak_android', "TEXT DEFAULT 'oMtxRk6dE7Q8w8SXZ3frrwzAak3gqOTh'");

    // Movie token column for TMDb integration
    await _addColumnIfMissing(db, 'configs', 'movie_token', 'TEXT');

    // DeepSeek columns: API key and model. These fields are used for DeepSeek translation service.
    await _addColumnIfMissing(db, 'configs', 'deepseek_key', 'TEXT');
    await _addColumnIfMissing(db, 'configs', 'deepseek_model', "TEXT DEFAULT 'deepseek-v4-pro'");
    await _addColumnIfMissing(db, 'configs', 'openrouter_key', 'TEXT');
    await _addColumnIfMissing(db, 'configs', 'sport_running_bg', 'TEXT');
    await _addColumnIfMissing(db, 'configs', 'sport_start_sound', 'TEXT');
    await _addColumnIfMissing(db, 'configs', 'sport_music_playlist', 'TEXT');
    await _addColumnIfMissing(db, 'configs', 'sport_music_mode', "TEXT DEFAULT 'order'");
    await _addColumnIfMissing(db, 'configs', 'sport_music_bg_bindings', 'TEXT');
    await _addColumnIfMissing(db, 'configs', 'mood_card_popup_enabled', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'configs', 'mood_card_popup_delay_ms', 'INTEGER DEFAULT 5000');

    // v19: extend sport_records fields for plan/running compatibility, and add sport_quotes table.
    if (oldV < 19) {
      await _addColumnIfMissing(db, 'sport_records', 'title', 'TEXT');
      await _addColumnIfMissing(db, 'sport_records', 'sport_type', 'TEXT');
      await _addColumnIfMissing(db, 'sport_records', 'plan_time', 'TEXT');
      await _addColumnIfMissing(db, 'sport_records', 'paused_total_sec', 'INTEGER');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sport_quotes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          content TEXT,
          author TEXT,
          explanation TEXT,
          enabled INTEGER,
          created_at TEXT,
          updated_at TEXT
        )
      ''');
    }
    // v20: persist live speed for restore when leaving page / process kill.
    if (oldV < 20) {
      await _addColumnIfMissing(db, 'sport_records', 'current_speed', 'REAL');
    }


    // Space module caches (v17+). These CREATE statements are idempotent.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS api_cache (
        cache_key TEXT PRIMARY KEY,
        json TEXT NOT NULL,
        updated_at INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS translation_cache (
        cache_key TEXT PRIMARY KEY,
        model TEXT,
        target TEXT,
        source_text TEXT,
        translated_text TEXT NOT NULL,
        updated_at INTEGER
      )
    ''');

    // 创建 SSES 答案表，用于存储生态瞬时评估自尊题的历史答题记录
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sses_answers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id TEXT,
        dimension TEXT,
        score INTEGER,
        created_at TEXT
      )
    ''');
    // Create tables for questionnaire scales if they do not already exist. These are idempotent.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scale_code TEXT UNIQUE,
        version TEXT,
        name TEXT,
        language TEXT,
        description TEXT,
        author TEXT,
        copyright TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scale_dimensions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scale_id INTEGER,
        dimension_code TEXT,
        name TEXT,
        description TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scale_id INTEGER,
        item_code TEXT,
        item_no INTEGER,
        content TEXT,
        item_type TEXT,
        dimension_code TEXT,
        is_reverse INTEGER,
        scoring_type TEXT,
        remark TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scale_item_options (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scale_item_id INTEGER,
        option_code TEXT,
        label TEXT,
        option_value TEXT,
        base_score REAL,
        extra_rule TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scale_report_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scale_id INTEGER,
        dimension_code TEXT,
        min_score REAL,
        max_score REAL,
        level TEXT,
        template TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scale_assessments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT,
        scale_id INTEGER,
        total_score REAL,
        level TEXT,
        report_text TEXT,
        created_at TEXT
      )
    ''');

    // Ensure the logs table exists when upgrading from older versions.  Some
    // devices created the database before the logs table was introduced.
    // Without this, calls to LogDao.add() will fail with "no such table: logs".
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scale_assessment_answers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        assessment_id INTEGER,
        scale_item_id INTEGER,
        option_id INTEGER,
        option_value TEXT,
        score REAL
      )
    ''');

    // Ensure movie_favorites table exists. On upgrade from older versions the
    // table may not yet exist. Creating it with IF NOT EXISTS makes the
    // operation idempotent and safe to call repeatedly.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS movie_favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tmdb_id INTEGER UNIQUE,
        title TEXT,
        overview TEXT,
        poster_path TEXT,
        backdrop_path TEXT,
        vote_average REAL,
        vote_count INTEGER,
        release_date TEXT,
        raw_json TEXT NOT NULL,
        created_at TEXT
      )
    ''');

    // ---------------------------------------------------------------------
    // Sport tables migration
    // Ensure sport_plans table exists (v15+).  The table captures user
    // configured exercise plans.  See _create() for full schema definition.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sport_plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        sport_type TEXT,
        target_type TEXT,
        target_value REAL,
        target_unit TEXT,
        repeat_type TEXT,
        repeat_detail TEXT,
        plan_time TEXT,
        notify_enabled INTEGER,
        notify_advance INTEGER,
        status TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Ensure sport_records table exists.  This table stores historical
    // exercise metrics associated with sport_plans or standalone sessions.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sport_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id INTEGER,
        mode TEXT,
        start_time TEXT,
        end_time TEXT,
        total_duration INTEGER,
        total_steps INTEGER,
        total_distance REAL,
        avg_speed REAL,
        current_speed REAL,
        start_location TEXT,
        end_location TEXT,
        target_type TEXT,
        target_value REAL,
        target_unit TEXT,
        status TEXT,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY(plan_id) REFERENCES sport_plans(id) ON DELETE SET NULL
      )
    ''');

await _addColumnIfMissing(db, 'tasks', 'task_uid', 'TEXT');
await _addColumnIfMissing(db, 'tasks', 'name', 'TEXT');
await _addColumnIfMissing(db, 'tasks', 'task_type', 'TEXT');
await _addColumnIfMissing(db, 'tasks', 'start_time', 'TEXT');
await _addColumnIfMissing(db, 'tasks', 'prompt', 'TEXT');
await _addColumnIfMissing(db, 'tasks', 'avatar', 'TEXT');
await _addColumnIfMissing(db, 'tasks', 'status', 'TEXT');
await _addColumnIfMissing(db, 'tasks', 'cursor', 'INTEGER DEFAULT 0');
await _addColumnIfMissing(db, 'tasks', 'carousel_order', "TEXT DEFAULT 'desc'");


    // Ensure the quotes_fixed table exists.  On upgrades from versions prior
    // to 9, the fixed quotes table may not yet exist.  Using IF NOT EXISTS
    // makes this operation idempotent and safe to call repeatedly.
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS quotes_fixed (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          fixed_uid TEXT UNIQUE,
          quote_id INTEGER,
          content TEXT UNIQUE,
          theme TEXT,
          author_name TEXT,
          source_from TEXT,
          explanation TEXT,
          avatar TEXT,
          FOREIGN KEY(quote_id) REFERENCES quotes(id) ON DELETE SET NULL
        )
      ''');
    } catch (_) {}


    // Ensure emotions table exists for mood records
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS emotions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          emotion_uid TEXT UNIQUE,
          emoji_char TEXT,
          emoji_name TEXT,
          emoji_tags TEXT,
          behavior TEXT,
          trigger_event TEXT,
          thought TEXT,
          type TEXT,
          inserted_at TEXT
        )
      ''');
    } catch (_) {}

    // Continue with legacy upgrade logic for very old versions.
    if (oldV < 5) {
      // Best-effort ensure required tables/columns exist
      await db.execute("CREATE TABLE IF NOT EXISTS configs (id INTEGER PRIMARY KEY AUTOINCREMENT, api_key TEXT, model TEXT, endpoint TEXT)");
      await db.execute("CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT)");
      await db.execute("CREATE TABLE IF NOT EXISTS tasks (id INTEGER PRIMARY KEY AUTOINCREMENT, task_uid TEXT UNIQUE, name TEXT, type TEXT, status TEXT, prompt TEXT, avatar_path TEXT, start_time TEXT, freq_type TEXT, freq_weekday INTEGER, freq_day_of_month INTEGER, freq_custom TEXT)");
      await db.execute("CREATE TABLE IF NOT EXISTS quotes (id INTEGER PRIMARY KEY AUTOINCREMENT, quote_uid TEXT UNIQUE, task_uid TEXT, content TEXT, notified INTEGER DEFAULT 0, created_at INTEGER)");
      await db.execute("CREATE TABLE IF NOT EXISTS logs (id INTEGER PRIMARY KEY AUTOINCREMENT, log_uid TEXT UNIQUE, task_uid TEXT, detail TEXT, created_at INTEGER, task_name_snapshot TEXT, task_start_time_snapshot TEXT)");

      // === Ensure standardized schema (backward compatible) ===
      // Logs: id AUTOINCREMENT, log_uid PRIMARY KEY, task_uid (FK, nullable, ON DELETE SET NULL), detail
      await db.execute("CREATE TABLE IF NOT EXISTS logs (id INTEGER PRIMARY KEY AUTOINCREMENT, log_uid TEXT UNIQUE, task_uid TEXT, detail TEXT)");
      // Ensure required columns exist
      // quotes: add required columns if missing
      var infoQuotes = await db.rawQuery("PRAGMA table_info(quotes)");
      var colsQuotes = infoQuotes.map((e)=> e['name'] as String).toList();
      


if (!colsQuotes.contains('task_type')) { await db.execute("ALTER TABLE quotes ADD COLUMN task_type TEXT"); }
if (!colsQuotes.contains('task_name')) { await db.execute("ALTER TABLE quotes ADD COLUMN task_name TEXT"); }
if (!colsQuotes.contains('theme')) { await db.execute("ALTER TABLE quotes ADD COLUMN theme TEXT"); }
if (!colsQuotes.contains('author_name')) { await db.execute("ALTER TABLE quotes ADD COLUMN author_name TEXT"); }
if (!colsQuotes.contains('source_from')) { await db.execute("ALTER TABLE quotes ADD COLUMN source_from TEXT"); }
if (!colsQuotes.contains('explanation')) { await db.execute("ALTER TABLE quotes ADD COLUMN explanation TEXT"); }
if (!colsQuotes.contains('inserted_at')) { await db.execute("ALTER TABLE quotes ADD COLUMN inserted_at TEXT"); }
if (!colsQuotes.contains('last_notified_at')) { await db.execute("ALTER TABLE quotes ADD COLUMN last_notified_at TEXT"); }
if (!colsQuotes.contains('avatar')) { await db.execute("ALTER TABLE quotes ADD COLUMN avatar TEXT"); }
if (!colsQuotes.contains('theme')) { await db.execute("ALTER TABLE quotes ADD COLUMN theme TEXT"); }
if (!colsQuotes.contains('author_name')) { await db.execute("ALTER TABLE quotes ADD COLUMN author_name TEXT"); }
if (!colsQuotes.contains('source_from')) { await db.execute("ALTER TABLE quotes ADD COLUMN source_from TEXT"); }
if (!colsQuotes.contains('explanation')) { await db.execute("ALTER TABLE quotes ADD COLUMN explanation TEXT"); }
if (!colsQuotes.contains('inserted_at')) { await db.execute("ALTER TABLE quotes ADD COLUMN inserted_at TEXT"); }
if (!colsQuotes.contains('last_notified_at')) { await db.execute("ALTER TABLE quotes ADD COLUMN last_notified_at TEXT"); }
if (!colsQuotes.contains('avatar')) { await db.execute("ALTER TABLE quotes ADD COLUMN avatar TEXT"); }
if (!colsQuotes.contains('quote_uid')) { await db.execute("ALTER TABLE quotes ADD COLUMN quote_uid TEXT"); }
      if (!colsQuotes.contains('task_uid'))  { await db.execute("ALTER TABLE quotes ADD COLUMN task_uid TEXT"); }
      if (!colsQuotes.contains('task_type')) { await db.execute("ALTER TABLE quotes ADD COLUMN task_type TEXT"); }
      if (!colsQuotes.contains('task_name')) { await db.execute("ALTER TABLE quotes ADD COLUMN task_name TEXT"); }
      if (!colsQuotes.contains('avatar'))    { await db.execute("ALTER TABLE quotes ADD COLUMN avatar TEXT"); }
      if (!colsQuotes.contains('notified'))  { await db.execute("ALTER TABLE quotes ADD COLUMN notified INTEGER DEFAULT 0"); }
      // unique for content
      await db.execute("CREATE UNIQUE INDEX IF NOT EXISTS uq_quotes_content ON quotes(content)");
      await db.execute("CREATE UNIQUE INDEX IF NOT EXISTS uq_quotes_uid ON quotes(quote_uid)");
      await db.execute("CREATE UNIQUE INDEX IF NOT EXISTS uq_tasks_uid ON tasks(task_uid)");
      await db.execute("CREATE UNIQUE INDEX IF NOT EXISTS uq_logs_uid ON logs(log_uid)");

      // tasks: ensure required columns
      var infoTasks = await db.rawQuery("PRAGMA table_info(tasks)");
      var colsTasks = infoTasks.map((e)=> e['name'] as String).toList();
      if (!colsTasks.contains('task_uid'))   { await db.execute("ALTER TABLE tasks ADD COLUMN task_uid TEXT"); }
      if (!colsTasks.contains('name'))       { await db.execute("ALTER TABLE tasks ADD COLUMN name TEXT"); }
      if (!colsTasks.contains('task_type'))  { await db.execute("ALTER TABLE tasks ADD COLUMN task_type TEXT"); }
      if (!colsTasks.contains('start_time')) { await db.execute("ALTER TABLE tasks ADD COLUMN start_time TEXT"); }
      if (!colsTasks.contains('prompt'))     { await db.execute("ALTER TABLE tasks ADD COLUMN prompt TEXT"); }
      if (!colsTasks.contains('avatar'))     { await db.execute("ALTER TABLE tasks ADD COLUMN avatar TEXT"); }
      if (!colsTasks.contains('status'))     { await db.execute("ALTER TABLE tasks ADD COLUMN status TEXT"); }
      if (!colsTasks.contains('cursor'))     { await db.execute("ALTER TABLE tasks ADD COLUMN cursor INTEGER DEFAULT 0"); }
      // configs: ensure required columns (notice_id aka id, api_key, bg_image, model, endpoint)
      var infoCfg = await db.rawQuery("PRAGMA table_info(configs)");
      var colsCfg = infoCfg.map((e)=> e['name'] as String).toList();

      if (!colsCfg.contains('location_rules_enabled')) { await db.execute("ALTER TABLE configs ADD COLUMN location_rules_enabled INTEGER DEFAULT 0"); }
      if (!colsCfg.contains('baidu_ak')) { await db.execute("ALTER TABLE configs ADD COLUMN baidu_ak TEXT DEFAULT 'kmHcLsW5heS5miYWLpbRUsrQapGIJ5m2'"); }
      if (!colsCfg.contains('baidu_ak_android')) { await db.execute("ALTER TABLE configs ADD COLUMN baidu_ak_android TEXT DEFAULT 'oMtxRk6dE7Q8w8SXZ3frrwzAak3gqOTh'"); }
      if (!colsCfg.contains('bg_image'))     { await db.execute("ALTER TABLE configs ADD COLUMN bg_image TEXT"); }
      if (!colsCfg.contains('openrouter_key')) { await db.execute("ALTER TABLE configs ADD COLUMN openrouter_key TEXT"); }// --- Diary module config columns ---
try {
  final infoConfigs2 = await db.rawQuery("PRAGMA table_info(configs)");
  final cols2 = infoConfigs2.map((e) => e['name'] as String).toList();
  if (!cols2.contains('diary_bg_image')) {
    await db.execute("ALTER TABLE configs ADD COLUMN diary_bg_image TEXT");
  }
  if (!cols2.contains('diary_bg_opacity')) {
    await db.execute("ALTER TABLE configs ADD COLUMN diary_bg_opacity REAL DEFAULT 0.25");
  }
  if (!cols2.contains('diary_pin')) {
    await db.execute("ALTER TABLE configs ADD COLUMN diary_pin TEXT");
  }
} catch (_) {}

// --- Diary tables (idempotent creation) ---
try {
  await db.execute("CREATE TABLE IF NOT EXISTS notebooks(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)");
  await db.execute("CREATE TABLE IF NOT EXISTS entries(id INTEGER PRIMARY KEY AUTOINCREMENT, notebook_id INTEGER NOT NULL, entry_time INTEGER NOT NULL, weather_code INTEGER, weather_name TEXT, mood_name TEXT, mood_icon TEXT, content TEXT NOT NULL, preview TEXT NOT NULL, starred INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, FOREIGN KEY(notebook_id) REFERENCES notebooks(id) ON DELETE CASCADE)");
  await db.execute("CREATE INDEX IF NOT EXISTS idx_entries_notebook_time ON entries(notebook_id, entry_time DESC, id DESC)");
  await db.execute("CREATE TABLE IF NOT EXISTS tags(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE)");
  await db.execute("CREATE TABLE IF NOT EXISTS entry_tags(entry_id INTEGER NOT NULL, tag_id INTEGER NOT NULL, PRIMARY KEY(entry_id, tag_id), FOREIGN KEY(entry_id) REFERENCES entries(id) ON DELETE CASCADE, FOREIGN KEY(tag_id) REFERENCES tags(id) ON DELETE CASCADE)");
} catch (_) {}

      // Foreign key relationships (best-effort: create views/triggers if needed)
      await db.execute("PRAGMA foreign_keys=ON");
      // Ensure snapshots columns
      final info = await db.rawQuery("PRAGMA table_info(logs)");
      final cols = info.map((e)=> e['name'] as String).toList();
      if (!cols.contains('task_name_snapshot')) {
        await db.execute("ALTER TABLE logs ADD COLUMN task_name_snapshot TEXT");
      }
      if (!cols.contains('task_start_time_snapshot')) {
        await db.execute("ALTER TABLE logs ADD COLUMN task_start_time_snapshot TEXT");
      }
    }
  }
  // Public helper: ensure diary-related columns exist on 'configs' table.
  // This is safe to call multiple times (idempotent). It allows call-sites
  // outside of the first database open (e.g. settings page) to guarantee
  // columns exist even if the DB was opened earlier in the same session.
  static Future<void> ensureDiaryColumns() async {
    final db = await instance();
    try {
      final infoConfigs2 = await db.rawQuery("PRAGMA table_info(configs)");
      final cols2 = infoConfigs2.map((e) => e['name'] as String).toList();
      if (!cols2.contains('diary_bg_image')) {
        await db.execute("ALTER TABLE configs ADD COLUMN diary_bg_image TEXT");
      }
      if (!cols2.contains('diary_bg_opacity')) {
        await db.execute("ALTER TABLE configs ADD COLUMN diary_bg_opacity REAL DEFAULT 0.25");
      }
      if (!cols2.contains('diary_pin')) {
        await db.execute("ALTER TABLE configs ADD COLUMN diary_pin TEXT");
      }
    } catch (_) {}
  }


  /// Ensure all tables required by the Health Diet module exist.
  ///
  /// Kept idempotent because this module may be opened on databases created by
  /// older app versions. Repositories also call this before reading/writing, so
  /// the first-stage module can land safely without depending on a fresh install.
  static Future<void> ensureHealthDietTables() async {
    final db = await instance();
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS health_profiles (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT,
          gender TEXT,
          age INTEGER,
          height_cm REAL,
          weight_kg REAL,
          activity_level TEXT,
          main_goal TEXT,
          created_at TEXT,
          updated_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS health_conditions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          profile_id INTEGER,
          condition_code TEXT,
          condition_name TEXT,
          severity TEXT,
          source TEXT,
          created_at TEXT,
          FOREIGN KEY(profile_id) REFERENCES health_profiles(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS diet_restrictions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          profile_id INTEGER,
          restriction_code TEXT,
          restriction_name TEXT,
          restriction_type TEXT,
          created_at TEXT,
          FOREIGN KEY(profile_id) REFERENCES health_profiles(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS diet_preferences (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          profile_id INTEGER,
          preference_code TEXT,
          preference_name TEXT,
          created_at TEXT,
          FOREIGN KEY(profile_id) REFERENCES health_profiles(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS food_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          source TEXT,
          source_food_id TEXT,
          barcode TEXT,
          name TEXT,
          brand TEXT,
          category TEXT,
          serving_size_g REAL,
          calories_kcal REAL,
          protein_g REAL,
          fat_g REAL,
          carbs_g REAL,
          fiber_g REAL,
          sugar_g REAL,
          sodium_mg REAL,
          saturated_fat_g REAL,
          allergens_json TEXT,
          ingredients_json TEXT,
          health_tags_json TEXT,
          data_quality TEXT,
          raw_json TEXT,
          created_at TEXT,
          updated_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS healthy_recipes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          source TEXT,
          source_recipe_id TEXT,
          title TEXT,
          image_url TEXT,
          health_tags TEXT,
          diet_tags TEXT,
          calories_kcal REAL,
          protein_g REAL,
          fat_g REAL,
          carbs_g REAL,
          sodium_mg REAL,
          ready_minutes INTEGER,
          servings INTEGER,
          raw_json TEXT,
          created_at TEXT,
          updated_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS recipe_steps (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          recipe_id INTEGER,
          step_index INTEGER,
          instruction TEXT,
          ingredients_json TEXT,
          equipment_json TEXT,
          FOREIGN KEY(recipe_id) REFERENCES healthy_recipes(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS meal_plans (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          profile_id INTEGER,
          plan_date TEXT,
          plan_type TEXT,
          goal_summary TEXT,
          ai_summary TEXT,
          risk_notice TEXT,
          created_at TEXT,
          FOREIGN KEY(profile_id) REFERENCES health_profiles(id) ON DELETE SET NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS meal_plan_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          meal_plan_id INTEGER,
          meal_type TEXT,
          recipe_id INTEGER,
          food_item_id INTEGER,
          title TEXT,
          portion_desc TEXT,
          reason TEXT,
          caution TEXT,
          sort_order INTEGER,
          FOREIGN KEY(meal_plan_id) REFERENCES meal_plans(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS health_recommendation_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          profile_id INTEGER,
          request_type TEXT,
          user_query TEXT,
          data_sources TEXT,
          ai_provider TEXT,
          ai_model TEXT,
          prompt TEXT,
          response TEXT,
          parsed_json TEXT,
          status TEXT,
          error_message TEXT,
          created_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS daily_diet_entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT,
          entry_date TEXT,
          meal_type TEXT,
          input_type TEXT,
          text_description TEXT,
          voice_text TEXT,
          image_count INTEGER DEFAULT 0,
          barcode TEXT,
          created_at TEXT,
          updated_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS daily_diet_images (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          entry_id INTEGER,
          local_path TEXT,
          image_type TEXT,
          recognized_text TEXT,
          ai_detected_foods_json TEXT,
          user_confirmed_foods_json TEXT,
          confidence_score REAL,
          created_at TEXT,
          FOREIGN KEY(entry_id) REFERENCES daily_diet_entries(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS daily_diet_voice_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          entry_id INTEGER,
          local_audio_path TEXT,
          transcript_text TEXT,
          duration_ms INTEGER,
          stt_provider TEXT,
          created_at TEXT,
          FOREIGN KEY(entry_id) REFERENCES daily_diet_entries(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS detected_diet_foods (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          entry_id INTEGER,
          food_name TEXT,
          normalized_food_id INTEGER,
          amount_text TEXT,
          estimated_grams REAL,
          meal_type TEXT,
          cooking_method TEXT,
          confidence_score REAL,
          confirmed_by_user INTEGER DEFAULT 0,
          source TEXT,
          created_at TEXT,
          FOREIGN KEY(entry_id) REFERENCES daily_diet_entries(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS daily_nutrition_summary (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT,
          summary_date TEXT,
          total_calories_kcal REAL,
          total_protein_g REAL,
          total_fat_g REAL,
          total_carbs_g REAL,
          total_fiber_g REAL,
          total_sugar_g REAL,
          total_sodium_mg REAL,
          vegetable_score REAL,
          protein_score REAL,
          fiber_score REAL,
          sugar_risk_score REAL,
          sodium_risk_score REAL,
          ultra_processed_score REAL,
          recovery_score REAL,
          overall_summary TEXT,
          good_points_json TEXT,
          main_problems_json TEXT,
          next_day_advice TEXT,
          confidence_score REAL,
          confidence_level TEXT,
          evidence_json TEXT,
          data_gaps_json TEXT,
          recipe_needs_json TEXT,
          ai_review_json TEXT,
          nutrition_totals_json TEXT,
          created_at TEXT
        )
      ''');

      try {
        final dnsInfo = await db.rawQuery('PRAGMA table_info(daily_nutrition_summary)');
        final dnsCols = dnsInfo.map((e) => e['name'] as String).toList();
        if (!dnsCols.contains('confidence_score')) await db.execute('ALTER TABLE daily_nutrition_summary ADD COLUMN confidence_score REAL');
        if (!dnsCols.contains('confidence_level')) await db.execute('ALTER TABLE daily_nutrition_summary ADD COLUMN confidence_level TEXT');
        if (!dnsCols.contains('evidence_json')) await db.execute('ALTER TABLE daily_nutrition_summary ADD COLUMN evidence_json TEXT');
        if (!dnsCols.contains('data_gaps_json')) await db.execute('ALTER TABLE daily_nutrition_summary ADD COLUMN data_gaps_json TEXT');
        if (!dnsCols.contains('recipe_needs_json')) await db.execute('ALTER TABLE daily_nutrition_summary ADD COLUMN recipe_needs_json TEXT');
        if (!dnsCols.contains('ai_review_json')) await db.execute('ALTER TABLE daily_nutrition_summary ADD COLUMN ai_review_json TEXT');
        if (!dnsCols.contains('nutrition_totals_json')) await db.execute('ALTER TABLE daily_nutrition_summary ADD COLUMN nutrition_totals_json TEXT');
      } catch (_) {}

      await db.execute('''
        CREATE TABLE IF NOT EXISTS diet_habit_patterns (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT,
          pattern_type TEXT,
          pattern_name TEXT,
          evidence_json TEXT,
          frequency_count INTEGER,
          first_seen_at TEXT,
          last_seen_at TEXT,
          status TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS diet_micro_actions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT,
          action_date TEXT,
          action_title TEXT,
          action_reason TEXT,
          difficulty_level TEXT,
          related_pattern TEXT,
          status TEXT,
          created_at TEXT,
          completed_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS health_diet_goals (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT,
          goal_type TEXT,
          goal_title TEXT,
          duration_days INTEGER,
          difficulty TEXT,
          preferences_json TEXT,
          avoid_json TEXT,
          success_metrics_json TEXT,
          status TEXT,
          created_at TEXT,
          updated_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS health_diet_goal_progress (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          goal_id INTEGER,
          user_id TEXT,
          progress_date TEXT,
          progress_score REAL,
          evidence_json TEXT,
          note TEXT,
          created_at TEXT,
          FOREIGN KEY(goal_id) REFERENCES health_diet_goals(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS health_diet_agent_tasks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT,
          goal_id INTEGER,
          task_type TEXT,
          task_title TEXT,
          task_reason TEXT,
          trigger_type TEXT,
          trigger_time TEXT,
          status TEXT,
          priority INTEGER,
          evidence_json TEXT,
          result_json TEXT,
          created_at TEXT,
          executed_at TEXT,
          completed_at TEXT,
          FOREIGN KEY(goal_id) REFERENCES health_diet_goals(id) ON DELETE SET NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS health_diet_agent_memory (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT,
          memory_type TEXT,
          memory_key TEXT,
          memory_value TEXT,
          confidence REAL,
          evidence_json TEXT,
          first_seen_at TEXT,
          last_seen_at TEXT,
          updated_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS health_diet_agent_plans (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT,
          goal_id INTEGER,
          plan_date TEXT,
          source TEXT,
          plan_json TEXT,
          created_at TEXT,
          FOREIGN KEY(goal_id) REFERENCES health_diet_goals(id) ON DELETE SET NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS health_connect_daily_summary (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT,
          summary_date TEXT,
          steps INTEGER,
          sleep_minutes INTEGER,
          exercise_minutes INTEGER,
          active_calories REAL,
          weight_kg REAL,
          resting_heart_rate REAL,
          status TEXT,
          message TEXT,
          raw_json TEXT,
          created_at TEXT,
          updated_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS grocery_lists (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT,
          recipe_source_id TEXT,
          recipe_title TEXT,
          status TEXT,
          created_at TEXT,
          updated_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS grocery_list_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          list_id INTEGER,
          item_name TEXT,
          amount_text TEXT,
          checked INTEGER DEFAULT 0,
          sort_order INTEGER DEFAULT 0,
          FOREIGN KEY(list_id) REFERENCES grocery_lists(id) ON DELETE CASCADE
        )
      ''');
      try {
        final hcInfo = await db.rawQuery('PRAGMA table_info(health_connect_daily_summary)');
        final hcCols = hcInfo.map((e) => e['name'] as String).toList();
        if (!hcCols.contains('status')) await db.execute('ALTER TABLE health_connect_daily_summary ADD COLUMN status TEXT');
        if (!hcCols.contains('message')) await db.execute('ALTER TABLE health_connect_daily_summary ADD COLUMN message TEXT');
      } catch (_) {}

      await db.execute('CREATE INDEX IF NOT EXISTS idx_health_profiles_user_updated ON health_profiles(user_id, updated_at DESC)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_health_conditions_profile ON health_conditions(profile_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_diet_restrictions_profile ON diet_restrictions(profile_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_diet_preferences_profile ON diet_preferences(profile_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_food_items_source_id ON food_items(source, source_food_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_food_items_barcode ON food_items(barcode)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_healthy_recipes_source_id ON healthy_recipes(source, source_recipe_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_health_recommendation_logs_created ON health_recommendation_logs(created_at DESC)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_daily_diet_entries_user_date ON daily_diet_entries(user_id, entry_date DESC)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_daily_diet_images_entry ON daily_diet_images(entry_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_daily_diet_voice_entry ON daily_diet_voice_records(entry_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_detected_diet_foods_entry ON detected_diet_foods(entry_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_daily_nutrition_summary_user_date ON daily_nutrition_summary(user_id, summary_date DESC)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_diet_habit_patterns_user ON diet_habit_patterns(user_id, status)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_diet_micro_actions_user_date ON diet_micro_actions(user_id, action_date DESC)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_health_connect_summary_user_date ON health_connect_daily_summary(user_id, summary_date DESC)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_health_diet_goals_user_status ON health_diet_goals(user_id, status, updated_at DESC)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_health_diet_agent_tasks_user_status ON health_diet_agent_tasks(user_id, status, priority DESC)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_health_diet_agent_memory_user ON health_diet_agent_memory(user_id, memory_type, memory_key)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_health_diet_agent_plans_user_date ON health_diet_agent_plans(user_id, plan_date DESC)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_grocery_lists_user ON grocery_lists(user_id, updated_at DESC)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_grocery_list_items_list ON grocery_list_items(list_id, sort_order ASC)');
    } catch (_) {}
  }

}
