
import 'dart:math';
import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:sqflite/sqflite.dart';
import 'db.dart';
import 'thought_taxonomy_seed.dart';
import '../utils/text_utils.dart';
import '../utils/debug_logger.dart';

String _uid(String prefix){
  final r = Random();
  final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final rnd = r.nextInt(1<<32).toRadixString(36);
  return '${prefix}_${ts}_${rnd}';
}

class ConfigDao {
  static const int defaultMoodCardDelayMs = 5000;

  Future<void> _ensureMoodCardPopupColumns(Database db) async {
    final info = await db.rawQuery("PRAGMA table_info(configs)");
    final cols = info.map((e) => e['name'] as String).toSet();
    if (!cols.contains('mood_card_popup_enabled')) {
      await db.execute("ALTER TABLE configs ADD COLUMN mood_card_popup_enabled INTEGER DEFAULT 1");
    }
    if (!cols.contains('mood_card_popup_delay_ms')) {
      await db.execute("ALTER TABLE configs ADD COLUMN mood_card_popup_delay_ms INTEGER DEFAULT 5000");
    }
  }

  Future<bool> getMoodCardPopupEnabled() async {
    try {
      final db = await AppDatabase.instance();
      await _ensureMoodCardPopupColumns(db);
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      if (rows.isEmpty) return true;
      final v = rows.first['mood_card_popup_enabled'];
      if (v == null) return true;
      if (v is int) return v == 1;
      final s = v.toString().trim().toLowerCase();
      return s == '1' || s == 'true';
    } catch (_) {
      return true;
    }
  }

  Future<void> setMoodCardPopupEnabled(bool enabled) async {
    final val = enabled ? 1 : 0;
    try {
      final db = await AppDatabase.instance();
      await _ensureMoodCardPopupColumns(db);
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      if (rows.isEmpty) {
        await db.insert('configs', {'mood_card_popup_enabled': val, 'mood_card_popup_delay_ms': defaultMoodCardDelayMs});
      } else {
        await db.update('configs', {'mood_card_popup_enabled': val}, where: 'id=?', whereArgs: [rows.first['id']]);
      }
    } catch (_) {}
  }

  Future<int> getMoodCardPopupDelayMs() async {
    try {
      final db = await AppDatabase.instance();
      await _ensureMoodCardPopupColumns(db);
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      if (rows.isEmpty) return defaultMoodCardDelayMs;
      final raw = rows.first['mood_card_popup_delay_ms'];
      final v = int.tryParse((raw ?? '').toString()) ?? defaultMoodCardDelayMs;
      return v < 0 ? 0 : (v > 60000 ? 60000 : v);
    } catch (_) {
      return defaultMoodCardDelayMs;
    }
  }

  Future<void> setMoodCardPopupDelayMs(int delayMs) async {
    final val = delayMs < 0 ? 0 : (delayMs > 60000 ? 60000 : delayMs);
    try {
      final db = await AppDatabase.instance();
      await _ensureMoodCardPopupColumns(db);
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      if (rows.isEmpty) {
        await db.insert('configs', {'mood_card_popup_enabled': 1, 'mood_card_popup_delay_ms': val});
      } else {
        await db.update('configs', {'mood_card_popup_delay_ms': val}, where: 'id=?', whereArgs: [rows.first['id']]);
      }
    } catch (_) {}
  }

  Future<int> getRecentHours() async {
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      if (rows.isEmpty) return 2;
      final v = rows.first['recent_hours'];
      final h = int.tryParse((v ?? '').toString()) ?? 2;
      return h < 1 ? 1 : h;
    } catch (_) {
      return 2;
    }
  }

  /// Returns the configured TMDb read access token. Empty means not configured.
  /// Movie Role Lab now stores user-provided TMDb credentials only; no API key
  /// or token is hardcoded in source code.
  Future<String> getMovieToken() async {
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      if (rows.isEmpty) return '';
      return (rows.first['movie_token'] ?? '').toString().trim();
    } catch (_) {
      return '';
    }
  }

  /// Persists the TMDb read access token. Inserts a config row if none
  /// exists; otherwise updates the latest row. Whitespace surrounding
  /// [token] is trimmed before saving.
  Future<void> setMovieToken(String token) async {
    final t = token.trim();
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      if (rows.isEmpty) {
        await db.insert('configs', {
          'api_key': '',
          'model': 'gpt-5',
          'endpoint': 'https://api.openai.com/v1/responses',
          'recent_hours': 2,
          'overview_threshold': 500,
          'auto_report_enabled': 0,
          'ema_enabled': 0,
          'esteem_scale': 100,
          'sses_index': 0,
          'location_rules_enabled': 0,
          'movie_token': t,
        });
      } else {
        final id = rows.first['id'];
        await db.update('configs', {'movie_token': t}, where: 'id=?', whereArgs: [id]);
      }
    } catch (_) {
      // ignore errors
    }
  }
  Future<void> setRecentHours(int hours) async {
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      final v = hours < 1 ? 1 : hours;
      if (rows.isEmpty) {
        await db.insert('configs', {'recent_hours': v});
      } else {
        await db.update('configs', {'recent_hours': v}, where: 'id=?', whereArgs: [rows.first['id']]);
      }
    } catch (_) {}
  }

  Future<int> getOverviewThreshold() async {
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      if (rows.isEmpty) return 500;
      final v = rows.first['overview_threshold'];
      final t = int.tryParse((v ?? '').toString()) ?? 500;
      return t < 1 ? 1 : t;
    } catch (_) {
      return 500;
    }
  }

  /// Returns whether automatic report generation for scales is enabled.
  /// A missing or non-1 value will be treated as disabled (false).
  Future<bool> getAutoReportEnabled() async {
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      if (rows.isEmpty) return false;
      final v = rows.first['auto_report_enabled'];
      // Accept truthy integer/string values as enabled
      if (v == null) return false;
      if (v is int) return v == 1;
      final s = v.toString();
      return s == '1' || s.toLowerCase() == 'true';
    } catch (_) {
      return false;
    }
  }

  /// Set whether automatic report generation for scales is enabled.
  /// Persists the flag in the configs table; inserts a config row if needed.
  Future<void> setAutoReportEnabled(bool enabled) async {
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      final val = enabled ? 1 : 0;
      if (rows.isEmpty) {
        await db.insert('configs', {
          'api_key': '',
          'model': 'gpt-5',
          'endpoint': 'https://api.openai.com/v1/responses',
          'recent_hours': 2,
          'overview_threshold': 500,
          'auto_report_enabled': val,
          'ema_enabled': 0,
          'esteem_scale': 100,
          'sses_index': 0,
        });
      } else {
        final id = rows.first['id'];
        await db.update('configs', {'auto_report_enabled': val}, where: 'id=?', whereArgs: [id]);
      }
    } catch (_) {}
  }

  /// 获取是否启用 EMA / SSES 自尊题问答的配置。
  /// 默认返回 false（关闭）。
  Future<bool> getEmaEnabled() async {
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      if (rows.isEmpty) return false;
      final v = rows.first['ema_enabled'];
      if (v == null) return false;
      if (v is int) return v == 1;
      final s = v.toString();
      return s == '1' || s.toLowerCase() == 'true';
    } catch (_) {
      return false;
    }
  }

  /// 设置是否启用 EMA / SSES 自尊题问答。
  Future<void> setEmaEnabled(bool enabled) async {
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      final val = enabled ? 1 : 0;
      if (rows.isEmpty) {
        await db.insert('configs', {
          'api_key': '',
          'model': 'gpt-5',
          'endpoint': 'https://api.openai.com/v1/responses',
          'recent_hours': 2,
          'overview_threshold': 500,
          'auto_report_enabled': 0,
          'ema_enabled': val,
          'esteem_scale': 100,
          'sses_index': 0,
        });
      } else {
        final id = rows.first['id'];
        await db.update('configs', {'ema_enabled': val}, where: 'id=?', whereArgs: [id]);
      }
    } catch (_) {}
  }

  /// 获取当前自尊评分尺度（100 或 30）。
  /// 默认返回 100。
  Future<int> getSelfEsteemScale() async {
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      if (rows.isEmpty) return 100;
      final v = rows.first['esteem_scale'];
      final n = int.tryParse((v ?? '').toString());
      if (n == null) return 100;
      return (n == 30) ? 30 : 100;
    } catch (_) {
      return 100;
    }
  }

  /// 设置自尊评分尺度（100 或 30）。其它值将被忽略并转为 100。
  Future<void> setSelfEsteemScale(int scale) async {
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      final v = (scale == 30) ? 30 : 100;
      if (rows.isEmpty) {
        await db.insert('configs', {
          'api_key': '',
          'model': 'gpt-5',
          'endpoint': 'https://api.openai.com/v1/responses',
          'recent_hours': 2,
          'overview_threshold': 500,
          'auto_report_enabled': 0,
          'ema_enabled': 0,
          'esteem_scale': v,
          'sses_index': 0,
        });
      } else {
        final id = rows.first['id'];
        await db.update('configs', {'esteem_scale': v}, where: 'id=?', whereArgs: [id]);
      }
    } catch (_) {}
  }

  /// 获取当前 SSES 轮换索引（0-5），如果不存在则返回 0。
  Future<int> getSsesIndex() async {
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      if (rows.isEmpty) return 0;
      final v = rows.first['sses_index'];
      final n = int.tryParse((v ?? '').toString());
      if (n == null) return 0;
      return n % 6;
    } catch (_) {
      return 0;
    }
  }

  /// 设置 SSES 轮换索引（0-5）。
  Future<void> setSsesIndex(int index) async {
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      final v = index % 6;
      if (rows.isEmpty) {
        await db.insert('configs', {
          'api_key': '',
          'model': 'gpt-5',
          'endpoint': 'https://api.openai.com/v1/responses',
          'recent_hours': 2,
          'overview_threshold': 500,
          'auto_report_enabled': 0,
          'ema_enabled': 0,
          'esteem_scale': 100,
          'sses_index': v,
        });
      } else {
        final id = rows.first['id'];
        await db.update('configs', {'sses_index': v}, where: 'id=?', whereArgs: [id]);
      }
    } catch (_) {}
  }

  Future<void> setOverviewThreshold(int threshold) async {
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      final v = threshold < 1 ? 1 : threshold;
      if (rows.isEmpty) {
        await db.insert('configs', {
          'api_key': '',
          'model': 'gpt-5',
          'endpoint': 'https://api.openai.com/v1/responses',
          'recent_hours': 2,
          'overview_threshold': v,
        });
      } else {
        await db.update('configs', {'overview_threshold': v}, where: 'id=?', whereArgs: [rows.first['id']]);
      }
    } catch (_) {
      // ignore
    }
  }

  /// 获取 DeepSeek API 密钥。
  /// 如果未配置则返回空字符串。
  Future<String> getDeepseekKey() async {
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      if (rows.isEmpty) return '';
      final v = rows.first['deepseek_key'];
      if (v == null) return '';
      return v.toString().trim();
    } catch (_) {
      return '';
    }
  }

  /// 设置 DeepSeek API 密钥。
  /// 会自动插入或更新 configs 表中的 deepseek_key 字段。
  Future<void> setDeepseekKey(String key) async {
    final k = key.trim();
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      if (rows.isEmpty) {
        await db.insert('configs', {'deepseek_key': k});
      } else {
        final id = rows.first['id'];
        await db.update('configs', {'deepseek_key': k}, where: 'id=?', whereArgs: [id]);
      }
    } on DatabaseException catch (e) {
      // 自愈：如果列不存在，尝试添加列并重试。
      if (e.toString().contains('no such column') && e.toString().contains('deepseek_key')) {
        try {
          final db = await AppDatabase.instance();
          await db.execute("ALTER TABLE configs ADD COLUMN deepseek_key TEXT");
          final rows2 = await db.query('configs', orderBy: 'id DESC', limit: 1);
          if (rows2.isEmpty) {
            await db.insert('configs', {'deepseek_key': k});
          } else {
            await db.update('configs', {'deepseek_key': k}, where: 'id=?', whereArgs: [rows2.first['id']]);
          }
        } catch (_) {}
      }
    } catch (_) {
      // ignore other errors
    }
  }

  /// 获取 DeepSeek 模型名称。
  /// 如果未设置返回 'deepseek-chat'。

  /// 获取 OpenRouter API 密钥。
  Future<String> getOpenRouterKey() async {
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      if (rows.isEmpty) return '';
      return (rows.first['openrouter_key'] ?? '').toString().trim();
    } catch (_) {
      return '';
    }
  }

  /// 设置 OpenRouter API 密钥。
  Future<void> setOpenRouterKey(String key) async {
    final k = key.trim();
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      if (rows.isEmpty) {
        await db.insert('configs', {'openrouter_key': k});
      } else {
        final id = rows.first['id'];
        await db.update('configs', {'openrouter_key': k}, where: 'id=?', whereArgs: [id]);
      }
    } on DatabaseException catch (e) {
      if (e.toString().contains('no such column') && e.toString().contains('openrouter_key')) {
        try {
          final db = await AppDatabase.instance();
          await db.execute("ALTER TABLE configs ADD COLUMN openrouter_key TEXT");
          final rows2 = await db.query('configs', orderBy: 'id DESC', limit: 1);
          if (rows2.isEmpty) {
            await db.insert('configs', {'openrouter_key': k});
          } else {
            await db.update('configs', {'openrouter_key': k}, where: 'id=?', whereArgs: [rows2.first['id']]);
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<String> getDeepseekModel() async {
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      if (rows.isEmpty) return 'deepseek-chat';
      final v = rows.first['deepseek_model'];
      final s = (v ?? 'deepseek-chat').toString().trim();
      return s.isEmpty ? 'deepseek-chat' : s;
    } catch (_) {
      return 'deepseek-chat';
    }
  }

  /// 设置 DeepSeek 模型名称。
  /// 传入空字符串时将重置为默认模型 deepseek-chat。
  Future<void> setDeepseekModel(String model) async {
    final m = model.trim().isEmpty ? 'deepseek-chat' : model.trim();
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      if (rows.isEmpty) {
        await db.insert('configs', {'deepseek_model': m});
      } else {
        final id = rows.first['id'];
        await db.update('configs', {'deepseek_model': m}, where: 'id=?', whereArgs: [id]);
      }
    } on DatabaseException catch (e) {
      if (e.toString().contains('no such column') && e.toString().contains('deepseek_model')) {
        try {
          final db = await AppDatabase.instance();
          await db.execute("ALTER TABLE configs ADD COLUMN deepseek_model TEXT DEFAULT 'deepseek-chat'");
          final rows2 = await db.query('configs', orderBy: 'id DESC', limit: 1);
          if (rows2.isEmpty) {
            await db.insert('configs', {'deepseek_model': m});
          } else {
            await db.update('configs', {'deepseek_model': m}, where: 'id=?', whereArgs: [rows2.first['id']]);
          }
        } catch (_) {}
      }
    } catch (_) {
      // ignore
    }
  }
  Future<Map<String, dynamic>> getOne() async {
    final db = await AppDatabase.instance();
    final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
    if (rows.isNotEmpty) return rows.first;
    await db.insert('configs', {'api_key':'','model':'gpt-5','endpoint':'https://api.openai.com/v1/responses','openrouter_key':''});
    final one = await db.query('configs', orderBy: 'id DESC', limit: 1);
    return one.first;
  }

  Future<void> save({required String apiKey, required String model, required String endpoint}) async {
    final db = await AppDatabase.instance();
    final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
    if (rows.isEmpty) {
      await db.insert('configs', {'api_key': apiKey, 'model': model, 'endpoint': endpoint, 'openrouter_key': ''});
    } else {
      await db.update('configs', {'api_key': apiKey, 'model': model, 'endpoint': endpoint}, where: 'id=?', whereArgs: [rows.first['id']]);
    }
  }

  Future<bool> isGeoRulesEnabled() async {
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      if (rows.isEmpty) return false;
      final v = (rows.first['location_rules_enabled'] ?? 0).toString();
      return v == '1';
    } catch (_) { return false; }
  }

  
  Future<void> setGeoRulesEnabled(bool enabled) async {
    final val = enabled ? 1 : 0;
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);

      if (rows.isEmpty) {
        // 插入一条完整的配置记录，确保后续读取不会出错。
        await db.insert(
          'configs',
          {
            'api_key': '',
            'model': 'gpt-5',
            'endpoint': 'https://api.openai.com/v1/responses',
            'recent_hours': 2,
            'overview_threshold': 500,
            'auto_report_enabled': 0,
            'ema_enabled': 0,
            'esteem_scale': 100,
            'sses_index': 0,
            'location_rules_enabled': val,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        final id = rows.first['id'];
        await db.update(
          'configs',
          {'location_rules_enabled': val},
          where: 'id=?',
          whereArgs: [id],
        );
      }
    } on DatabaseException catch (e) {
      // 兼容老版本：如果列不存在，则尝试补充列并重试一次。
      if (e.toString().contains('no such column: location_rules_enabled')) {
        try {
          final db = await AppDatabase.instance();
          await db.execute(
            "ALTER TABLE configs ADD COLUMN location_rules_enabled INTEGER DEFAULT 0",
          );

          final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
          if (rows.isEmpty) {
            await db.insert(
              'configs',
              {'location_rules_enabled': val},
            );
          } else {
            await db.update(
              'configs',
              {'location_rules_enabled': val},
              where: 'id=?',
              whereArgs: [rows.first['id']],
            );
          }
        } catch (e2) {
          try {
            await DLog.w('DB', '【ConfigDao】setGeoRulesEnabled 自愈失败：$e2');
          } catch (_) {}
        }
      } else {
        try {
          await DLog.w('DB', '【ConfigDao】setGeoRulesEnabled 失败：$e');
        } catch (_) {}
      }
    } catch (e) {
      try {
        await DLog.w('DB', '【ConfigDao】setGeoRulesEnabled 失败：$e');
      } catch (_) {}
    }
  }


  Future<String> getBaiduAk() async {
    // Web AK: used by Baidu Web APIs (reverse-geocoding/place/IP etc.)
    const def = 'kmHcLsW5heS5miYWLpbRUsrQapGIJ5m2';
    try {
      final db = await AppDatabase.instance();
      // 1) 优先读 configs.baidu_ak
      try {
        final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
        if (rows.isNotEmpty) {
          final v = (rows.first['baidu_ak'] ?? '').toString().trim();
          if (v.isNotEmpty) return v;
        }
      } catch (_) {}

      // 2) 兼容老版本：notify_config['baidu_ak']
      try {
        final rows2 = await db.query('notify_config', where: 'key=?', whereArgs: ['baidu_ak'], limit: 1);
        if (rows2.isNotEmpty) {
          final v2 = (rows2.first['value'] ?? '').toString().trim();
          if (v2.isNotEmpty) return v2;
        }
      } catch (_) {}

      return def;
    } catch (_){ return def; }
  }

  Future<void> setBaiduAk(String ak) async {
    // Web AK
    const def = 'kmHcLsW5heS5miYWLpbRUsrQapGIJ5m2';
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      final val = ak.trim();
      if (rows.isEmpty) {
        await db.insert('configs', {'baidu_ak': val});
      } else {
        await db.update('configs', {'baidu_ak': val}, where: 'id=?', whereArgs: [rows.first['id']]);
      }
    } on DatabaseException catch (e) {
      // 自愈：新建库/旧库可能还没有 baidu_ak 列
      if (e.toString().contains('no such column: baidu_ak')) {
        try {
          final db = await AppDatabase.instance();
          await db.execute("ALTER TABLE configs ADD COLUMN baidu_ak TEXT DEFAULT '$def'");
          final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
          final val = ak.trim();
          if (rows.isEmpty) {
            await db.insert('configs', {'baidu_ak': val});
          } else {
            await db.update('configs', {'baidu_ak': val}, where: 'id=?', whereArgs: [rows.first['id']]);
          }
        } catch (_) {}
      }
    } catch (_){}
  }

  /// Android AK: used by Baidu Location/Map/Search SDK (requires package + SHA1 binding).
  Future<String> getBaiduAndroidAk() async {
    const def = 'oMtxRk6dE7Q8w8SXZ3frrwzAak3gqOTh';
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      if (rows.isEmpty) return def;
      final v = (rows.first['baidu_ak_android'] ?? '').toString().trim();
      // 兼容老版本：如果新列为空，则仍返回默认 Android AK（避免误用 Web AK）
      return v.isEmpty ? def : v;
    } catch (_){ return def; }
  }

  Future<void> setBaiduAndroidAk(String ak) async {
    const def = 'oMtxRk6dE7Q8w8SXZ3frrwzAak3gqOTh';
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      final val = ak.trim();
      if (rows.isEmpty) {
        await db.insert('configs', {'baidu_ak_android': val});
      } else {
        await db.update('configs', {'baidu_ak_android': val}, where: 'id=?', whereArgs: [rows.first['id']]);
      }
    } on DatabaseException catch (e) {
      if (e.toString().contains('no such column: baidu_ak_android')) {
        try {
          final db = await AppDatabase.instance();
          await db.execute("ALTER TABLE configs ADD COLUMN baidu_ak_android TEXT DEFAULT '$def'");
          final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
          final val = ak.trim();
          if (rows.isEmpty) {
            await db.insert('configs', {'baidu_ak_android': val});
          } else {
            await db.update('configs', {'baidu_ak_android': val}, where: 'id=?', whereArgs: [rows.first['id']]);
          }
        } catch (_) {}
      }
    } catch (_){}
  }

  // ===== Sport settings (local only; can be migrated to server later) =====

  Future<String?> getSportRunningBg() async {
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      if (rows.isEmpty) return null;
      final v = rows.first['sport_running_bg'];
      final s = (v ?? '').toString().trim();
      return s.isEmpty ? null : s;
    } catch (_) {
      return null;
    }
  }

  Future<void> setSportRunningBg(String? path) async {
    final val = (path ?? '').trim();
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      if (rows.isEmpty) {
        await db.insert('configs', {'sport_running_bg': val});
      } else {
        await db.update('configs', {'sport_running_bg': val}, where: 'id=?', whereArgs: [rows.first['id']]);
      }
    } on DatabaseException catch (e) {
      if (e.toString().contains('no such column') && e.toString().contains('sport_running_bg')) {
        try {
          final db = await AppDatabase.instance();
          await db.execute("ALTER TABLE configs ADD COLUMN sport_running_bg TEXT");
          final rows2 = await db.query('configs', orderBy: 'id DESC', limit: 1);
          if (rows2.isEmpty) {
            await db.insert('configs', {'sport_running_bg': val});
          } else {
            await db.update('configs', {'sport_running_bg': val}, where: 'id=?', whereArgs: [rows2.first['id']]);
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<String?> getSportStartSound() async {
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      if (rows.isEmpty) return null;
      final v = rows.first['sport_start_sound'];
      final s = (v ?? '').toString().trim();
      return s.isEmpty ? null : s;
    } catch (_) {
      return null;
    }
  }

  Future<void> setSportStartSound(String? path) async {
    final val = (path ?? '').trim();
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      if (rows.isEmpty) {
        await db.insert('configs', {'sport_start_sound': val});
      } else {
        await db.update('configs', {'sport_start_sound': val}, where: 'id=?', whereArgs: [rows.first['id']]);
      }
    } on DatabaseException catch (e) {
      if (e.toString().contains('no such column') && e.toString().contains('sport_start_sound')) {
        try {
          final db = await AppDatabase.instance();
          await db.execute("ALTER TABLE configs ADD COLUMN sport_start_sound TEXT");
          final rows2 = await db.query('configs', orderBy: 'id DESC', limit: 1);
          if (rows2.isEmpty) {
            await db.insert('configs', {'sport_start_sound': val});
          } else {
            await db.update('configs', {'sport_start_sound': val}, where: 'id=?', whereArgs: [rows2.first['id']]);
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  // ===== Sport music playlist =====

  Future<List<String>> getSportMusicPlaylist() async {
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      if (rows.isEmpty) return <String>[];
      final raw = (rows.first['sport_music_playlist'] ?? '').toString().trim();
      if (raw.isEmpty) return <String>[];
      final v = jsonDecode(raw);
      if (v is List) {
        return v.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
      }
      return <String>[];
    } on DatabaseException catch (e) {
      // Older schema – treat as empty.
      if (e.toString().contains('no such column') && e.toString().contains('sport_music_playlist')) {
        return <String>[];
      }
      return <String>[];
    } catch (_) {
      return <String>[];
    }
  }

  Future<void> setSportMusicPlaylist(List<String> paths) async {
    final cleaned = paths.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final val = jsonEncode(cleaned);
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      if (rows.isEmpty) {
        await db.insert('configs', {'sport_music_playlist': val});
      } else {
        await db.update('configs', {'sport_music_playlist': val}, where: 'id=?', whereArgs: [rows.first['id']]);
      }
    } on DatabaseException catch (e) {
      if (e.toString().contains('no such column') && e.toString().contains('sport_music_playlist')) {
        try {
          final db = await AppDatabase.instance();
          await db.execute("ALTER TABLE configs ADD COLUMN sport_music_playlist TEXT");
          final rows2 = await db.query('configs', orderBy: 'id DESC', limit: 1);
          if (rows2.isEmpty) {
            await db.insert('configs', {'sport_music_playlist': val});
          } else {
            await db.update('configs', {'sport_music_playlist': val}, where: 'id=?', whereArgs: [rows2.first['id']]);
          }
        } catch (_) {}
      }
    } catch (_) {}
  }



  Future<Map<String, List<String>>> getSportMusicBgBindings() async {
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      if (rows.isEmpty) return <String, List<String>>{};
      final raw = (rows.first['sport_music_bg_bindings'] ?? '').toString().trim();
      if (raw.isEmpty) return <String, List<String>>{};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, List<String>>{};
      final Map<String, List<String>> result = <String, List<String>>{};
      decoded.forEach((key, value) {
        final music = key.toString().trim();
        if (music.isEmpty) return;
        final List<String> images = <String>[];
        if (value is List) {
          for (final item in value) {
            final s = item.toString().trim();
            if (s.isNotEmpty) images.add(s);
          }
        }
        result[music] = images;
      });
      return result;
    } on DatabaseException catch (e) {
      if (e.toString().contains('no such column') && e.toString().contains('sport_music_bg_bindings')) {
        return <String, List<String>>{};
      }
      return <String, List<String>>{};
    } catch (_) {
      return <String, List<String>>{};
    }
  }

  Future<void> setSportMusicBgBindings(Map<String, List<String>> bindings) async {
    final Map<String, List<String>> cleaned = <String, List<String>>{};
    bindings.forEach((key, value) {
      final music = key.trim();
      if (music.isEmpty) return;
      cleaned[music] = value.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    });
    final val = jsonEncode(cleaned);
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      if (rows.isEmpty) {
        await db.insert('configs', {'sport_music_bg_bindings': val});
      } else {
        await db.update('configs', {'sport_music_bg_bindings': val}, where: 'id=?', whereArgs: [rows.first['id']]);
      }
    } on DatabaseException catch (e) {
      if (e.toString().contains('no such column') && e.toString().contains('sport_music_bg_bindings')) {
        try {
          final db = await AppDatabase.instance();
          await db.execute("ALTER TABLE configs ADD COLUMN sport_music_bg_bindings TEXT");
          final rows2 = await db.query('configs', orderBy: 'id DESC', limit: 1);
          if (rows2.isEmpty) {
            await db.insert('configs', {'sport_music_bg_bindings': val});
          } else {
            await db.update('configs', {'sport_music_bg_bindings': val}, where: 'id=?', whereArgs: [rows2.first['id']]);
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<String> getSportMusicMode() async {
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      if (rows.isEmpty) return 'order';
      final raw = (rows.first['sport_music_mode'] ?? 'order').toString().trim();
      if (raw == 'random' || raw == 'order') return raw;
      return 'order';
    } on DatabaseException catch (e) {
      if (e.toString().contains('no such column') && e.toString().contains('sport_music_mode')) {
        return 'order';
      }
      return 'order';
    } catch (_) {
      return 'order';
    }
  }

  Future<void> setSportMusicMode(String mode) async {
    final val = (mode == 'random') ? 'random' : 'order';
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('configs', orderBy: 'id DESC', limit: 1);
      if (rows.isEmpty) {
        await db.insert('configs', {'sport_music_mode': val});
      } else {
        await db.update('configs', {'sport_music_mode': val}, where: 'id=?', whereArgs: [rows.first['id']]);
      }
    } on DatabaseException catch (e) {
      if (e.toString().contains('no such column') && e.toString().contains('sport_music_mode')) {
        try {
          final db = await AppDatabase.instance();
          await db.execute("ALTER TABLE configs ADD COLUMN sport_music_mode TEXT DEFAULT 'order'");
          final rows2 = await db.query('configs', orderBy: 'id DESC', limit: 1);
          if (rows2.isEmpty) {
            await db.insert('configs', {'sport_music_mode': val});
          } else {
            await db.update('configs', {'sport_music_mode': val}, where: 'id=?', whereArgs: [rows2.first['id']]);
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

}

class TaskDao {
  Future<List<Map<String,dynamic>>> all() async {
    final db = await AppDatabase.instance();
    return await db.query('tasks', orderBy: 'id DESC');
  }

  Future<Map<String,dynamic>?> getByUid(String uid) async {
    final db = await AppDatabase.instance();
    final rows = await db.query('tasks', where: 'task_uid=?', whereArgs: [uid], limit: 1);
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<String> create({
    required String name,
    required String type,
    String status = 'on',
    String prompt = '',
    String avatarPath = '',
    String startTime = '09:00',
    String? freqType,
    int? freqWeekday,
    int? freqDayOfMonth,
    String? freqCustom,
    String carouselOrder = 'desc',
  }) async {
    final db = await AppDatabase.instance();
    final uid = _uid('task');
    await db.insert('tasks', {
      'task_uid': uid,
      'name': name,
      'type': type,
      'status': status,
      'prompt': prompt,
      'avatar_path': avatarPath,
      'start_time': startTime,
      'freq_type': (freqType ?? 'daily'),
      'freq_weekday': freqWeekday,
      'freq_day_of_month': freqDayOfMonth,
      'freq_custom': (freqCustom ?? ''),
      'carousel_order': carouselOrder,
    });
    return uid;
  }

  Future<void> update(String uid, Map<String, dynamic> patch) async {
    final db = await AppDatabase.instance();
    await db.update('tasks', patch, where: 'task_uid=?', whereArgs: [uid]);
  }

  Future<void> delete(String uid) async {
    final db = await AppDatabase.instance();
    // Fill snapshots in logs before deleting the task
    final t = await getByUid(uid);
    if (t != null) {
      await db.rawUpdate(
        "UPDATE logs SET task_name_snapshot = COALESCE(task_name_snapshot, ?), task_start_time_snapshot = COALESCE(task_start_time_snapshot, ?) WHERE task_uid = ?",
        [ (t['name'] ?? '') as String, (t['start_time'] ?? '') as String, uid ]
      );
    }
    await db.delete('tasks', where: 'task_uid=?', whereArgs: [uid]);
  }
}

class QuoteDao {
  Future<Map<String,dynamic>?> latestForTask(String taskUid) async {
    final db = await AppDatabase.instance();
    final rows = await db.query('quotes', where: 'task_uid=?', whereArgs: [taskUid], orderBy: 'id DESC', limit: 1);
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<Map<String, dynamic>?> latestNotifiedToday() async {
  final db = await AppDatabase.instance();
  String two(int v) => v.toString().padLeft(2,'0');
  final now = DateTime.now();
  final int recentHours = await ConfigDao().getRecentHours();
  final ws = now.subtract(Duration(hours: recentHours));
  final wsStr = "${ws.year}-${two(ws.month)}-${two(ws.day)} ${two(ws.hour)}:${two(ws.minute)}:${two(ws.second)}";
  final wsEpochMs = ws.millisecondsSinceEpoch;
  final ymd = "${now.year}-${two(now.month)}-${two(now.day)}";

  // 动态检测是否存在旧列 last_notify_time，避免 SQLite 在编译含有不存在列的 SQL 时抛错
  bool _hasLegacy;
  try {
    final _info = await db.rawQuery("PRAGMA table_info(quotes)");
    _hasLegacy = _info.any((row) => (row['name']?.toString().toLowerCase() ?? '') == 'last_notify_time');
  } catch (_) {
    _hasLegacy = false;
  }
  if (!_hasLegacy) {
    // 直接使用仅 last_notified_at 的查询，避免引用不存在的列导致的编译错误
    final rows2 = await db.query(
      'quotes',
      where: "notified=1 AND substr(last_notified_at,1,10)=? AND datetime(replace(last_notified_at,'T',' ')) >= datetime(?)",
      whereArgs: [ymd, wsStr],
      orderBy: "last_notified_at DESC",
      limit: 1,
    );
    try { await DLog.i('DAO', 'latestNotifiedToday 列检测：无 last_notify_time，仅按 last_notified_at 检索；返回: ' + rows2.length.toString()); } catch (_){ }
    return rows2.isNotEmpty ? rows2.first : null;
  }
  try {
    final rows = await db.rawQuery(
      """
      SELECT * FROM quotes
      WHERE notified=1 AND (
        substr(COALESCE(last_notified_at, last_notify_time),1,10) = ? AND (
          (last_notified_at IS NOT NULL AND last_notified_at >= ?)
          OR (last_notify_time IS NOT NULL AND CAST(last_notify_time AS INTEGER) >= ?)
        )
        OR (
          /* 兼容 last_notify_time 为毫秒时间戳（int/string）的旧数据 */
          (CASE WHEN CAST(COALESCE(last_notify_time,'0') AS INTEGER) > 1000000000 THEN 1 ELSE 0 END) = 1
          AND DATE(DATETIME(CAST(last_notify_time AS INTEGER)/1000,'unixepoch','localtime')) = DATE('now','localtime')
        )
      )
      ORDER BY COALESCE(last_notified_at, last_notify_time) DESC
      LIMIT 1
      """,
      [ymd, wsStr, wsEpochMs],
    );
    try { await DLog.i('DAO', 'latestNotifiedToday 查询成功，返回条数: ' + rows.length.toString()); } catch (_){ }
    return rows.isNotEmpty ? rows.first : null;
  } catch (e) {
    try { await DLog.e('DAO', 'latestNotifiedToday 查询失败，将回退到仅按 last_notified_at 检索: ' + e.toString()); } catch (_){ }
    final rows2 = await db.query(
      'quotes',
      where: "notified=1 AND substr(last_notified_at,1,10)=? AND datetime(replace(last_notified_at,'T',' ')) >= datetime(?)",
      whereArgs: [ymd, wsStr],
      orderBy: "last_notified_at DESC",
      limit: 1,
    );
    return rows2.isNotEmpty ? rows2.first : null;
  }
}
Future<List<Map<String,dynamic>>> all({int limit=100, int offset=0, String q=''}) async {
    final db = await AppDatabase.instance();
    if (q.trim().isEmpty) {
      return await db.query('quotes', orderBy: 'id DESC', limit: limit, offset: offset);
    } else {
      return await db.query('quotes', where: 'content LIKE ?', whereArgs: ['%$q%'], orderBy: 'id DESC', limit: limit, offset: offset);
    }
  }

  Future<String> insertQuote({required String taskUid, required String content, String? theme, String? authorName, String? sourceFrom, String? explanation, String? avatarPath, String? taskName, String? taskType, String? insertedAt}) async {
    final db = await AppDatabase.instance();
    final uid = _uid('quote');
    await db.insert('quotes', {
      'quote_uid': uid,
      'task_uid': taskUid,
      'task_type': taskType ?? '',
      'task_name': taskName ?? '',
      'content': content,
      'theme': theme ?? '',
      'author_name': authorName ?? '',
      'source_from': sourceFrom ?? '',
      'explanation': explanation ?? '',
      'avatar': avatarPath ?? '',
      'inserted_at': insertedAt ?? '',
      'notified': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    await LogDao().add(taskUid: taskUid, detail: '成功! 已插入名言');
    return uid;
  }

  // Deduplication: return true if content is unique against all existing quotes
  Future<bool> isUnique(String content, {double threshold = 0.90}) async {
    final db = await AppDatabase.instance();
    final rows = await db.query('quotes', columns: ['content']);
    final normNew = normalizeText(content);
    for (final r in rows) {
      final c = (r['content'] ?? '').toString();
      if (c.trim().isEmpty) continue;
      final sim = jaroWinkler(normNew, normalizeText(c));
      if (sim >= threshold || normalizeText(c) == normNew) {
        return false;
      }
    }
    return true;
  }

  // Round-robin (sequential) carousel for a task: oldest -> newest loop
  Future<Map<String,dynamic>?> carouselNextSequential(String taskUid) async {
    final db = await AppDatabase.instance();
    // Try to fetch quotes bound to this task first
    List<Map<String, dynamic>> rows = await db.query('quotes', where: 'task_uid=?', whereArgs: [taskUid], orderBy: 'id ASC');
    // Fallback: if none exist, read all quotes globally (for carousel tasks with empty task)
    if (rows.isEmpty) {
      rows = await db.query('quotes', orderBy: 'id ASC');
      if (rows.isEmpty) return null;
      // Do not persist index for global fallback; always pick first row
      return rows.first;
    }
    final key = 'carousel_index_'+taskUid;
    final meta = await db.query('meta', where: 'key=?', whereArgs: [key], limit: 1);
    int idx = -1;
    if (meta.isNotEmpty) {
      idx = int.tryParse((meta.first['value'] ?? '-1').toString()) ?? -1;
    }
    final nextIdx = (idx + 1) % rows.length;
    final row = rows[nextIdx];
    // update cursor
    if (meta.isEmpty) {
      await db.insert('meta', {'key': key, 'value': nextIdx.toString()});
    } else {
      await db.update('meta', {'value': nextIdx.toString()}, where: 'key=?', whereArgs: [key]);
    }
    return row;
  }

  Future<void> markNotifiedByUid(String quoteUid) async {
  final db = await AppDatabase.instance();
  final now = DateTime.now();
  String two(int v)=> v.toString().padLeft(2,'0');
  final ts = "${now.year}-${two(now.month)}-${two(now.day)} ${two(now.hour)}:${two(now.minute)}:${two(now.second)}";
  try {
    await db.rawUpdate("UPDATE quotes SET notified=1, last_notified_at=? WHERE quote_uid=?", [ts, quoteUid]);
    try { await db.rawUpdate("UPDATE quotes SET last_notify_time=? WHERE quote_uid=?", [ts, quoteUid]); } catch (_) {}
    try { await db.rawUpdate("UPDATE quotes SET notify_status=1 WHERE quote_uid=?", [quoteUid]); } catch (_) {}
  } catch (_) {}
}
  // Compatibility wrapper used by UI pages
  Future<List<Map<String,dynamic>>> latest({int limit=100, int offset=0, String? q}) {
    return all(limit: limit, offset: offset, q: q ?? '');
  }


  Future<Map<String,dynamic>?> latestOne() async {
    final rows = await all(limit: 1, offset: 0);
    return rows.isNotEmpty ? rows.first : null;
  }


  Future<bool> existsSimilar(String content, {double threshold=0.90}) async {
    return !(await isUnique(content, threshold: threshold));
  }


  Future<bool> insertIfUnique({required String taskUid, required String content}) async {
    if (await isUnique(content, threshold: 0.90)) {
      await insertQuote(taskUid: taskUid, content: content);
      return true;
    }
    return false;
  }


  
          Future<bool> insertIfUniqueDetailed({required String taskUid, required String content, String? theme, String? authorName, String? sourceFrom, String? explanation, String? avatarPath, String? taskName, String? taskType, String? insertedAt}) async {
  if (await isUnique(content, threshold: 0.90)) {
    await insertQuote(taskUid: taskUid, content: content, theme: theme, authorName: authorName, sourceFrom: sourceFrom, explanation: explanation, avatarPath: avatarPath, taskName: taskName, taskType: taskType, insertedAt: insertedAt);
    return true;
  }
  return false;
}

Future<bool> updateLatestForTask(String taskUid, String content) async {
    final db = await AppDatabase.instance();
    final rows = await db.query('quotes', where: 'task_uid=?', whereArgs: [taskUid], orderBy: 'id DESC', limit: 1);
    if (rows.isNotEmpty) {
      final id = rows.first['id'] as int;
      await db.update('quotes', {'content': content}, where: 'id=?', whereArgs: [id]);
      return true;
    } else {
      await insertQuote(taskUid: taskUid, content: content);
      return true;
    }
  }

  /// Update the latest quote for a task with additional fields.  If no quote
  /// exists for the task, a new one will be inserted with the provided
  /// values.  Returns true on success.
  Future<bool> updateLatestForTaskDetailed({
    required String taskUid,
    required String content,
    String? theme,
    String? authorName,
    String? sourceFrom,
    String? explanation,
    String? avatarPath,
  }) async {
    final db = await AppDatabase.instance();
    final rows = await db.query('quotes', where: 'task_uid=?', whereArgs: [taskUid], orderBy: 'id DESC', limit: 1);
    final now = DateTime.now();
    String two(int n) => n < 10 ? '0$n' : '$n';
    final nowStr = '${now.year}-${two(now.month)}-${two(now.day)} ${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
    if (rows.isNotEmpty) {
      final id = rows.first['id'] as int;
      final patch = <String, Object?>{
        'content': content,
        'theme': theme ?? '',
        'author_name': authorName ?? '',
        'source_from': sourceFrom ?? '',
        'explanation': explanation ?? '',
      };
      if (avatarPath != null) patch['avatar'] = avatarPath;
      patch['inserted_at'] = nowStr;
      await db.update('quotes', patch, where: 'id=?', whereArgs: [id]);
      return true;
    } else {
      // Insert new quote with provided fields and the generated timestamp
      await insertQuote(
        taskUid: taskUid,
        content: content,
        theme: theme,
        authorName: authorName,
        sourceFrom: sourceFrom,
        explanation: explanation,
        avatarPath: avatarPath,
        taskName: '',
        taskType: '',
        insertedAt: nowStr,
      );
      return true;
    }
  }

  /// Fetch the most recent notified quote (notify_status=1) sorted by last_notified_at descending.
  /// Returns null if none exist.
  Future<Map<String,dynamic>?> latestNotified() async {
    final db = await AppDatabase.instance();
    // Use last_notified_at if present, otherwise fall back to inserted_at or created_at
    // We order by last_notified_at DESC to get the most recently notified quote
    final rows = await db.query('quotes', where: 'notified=1', orderBy: 'last_notified_at DESC', limit: 1);
    if (rows.isNotEmpty) return rows.first;
    return null;
  }

  /// Fetch a quote belonging to [taskUid] by descending order index.  The
  /// [offset] parameter specifies which quote to return (0=latest, 1=second
  /// latest, etc).  Returns null if there are fewer quotes than the offset+1.
  Future<Map<String, dynamic>?> findByTaskOffsetDesc(String taskUid, int offset) async {
    final db = await AppDatabase.instance();
    // Use rawQuery with limit/offset to fetch by offset due to Sqflite limitations on offset in query method
    final rows = await db.rawQuery(
      'SELECT * FROM quotes WHERE task_uid = ? ORDER BY id DESC LIMIT 1 OFFSET ?',
      [taskUid, offset],
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  /// Find a quote by exact content and theme.  Returns null if none match.
  Future<Map<String, dynamic>?> findByContentAndTheme(String content, String? theme) async {
    final db = await AppDatabase.instance();
    final rows = await db.query(
      'quotes',
      where: 'content = ? AND theme = ?',
      whereArgs: [content, (theme ?? '')],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }
  // ---------------------------------------------------------------------------
  // Fallback quote carousel state (for assets/fallback/camus_fallback.json)
  // ---------------------------------------------------------------------------

  /// Read an integer value from app_kv. Returns [defaultValue] if missing.
  Future<int> _getIntKv(String key, {int defaultValue = 0}) async {
    final db = await AppDatabase.instance();
    // Ensure kv table exists for older databases.
    await db.execute(
      'CREATE TABLE IF NOT EXISTS app_kv (key TEXT PRIMARY KEY, value TEXT)'
    );
    final rows = await db.query(
      'app_kv',
      where: 'key=?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return defaultValue;
    return int.tryParse((rows.first['value'] ?? '').toString()) ?? defaultValue;
  }

  /// Read a string value from app_kv. Returns null if missing.
  Future<String?> _getStrKv(String key) async {
    final db = await AppDatabase.instance();
    await db.execute(
      'CREATE TABLE IF NOT EXISTS app_kv (key TEXT PRIMARY KEY, value TEXT)'
    );
    final rows = await db.query(
      'app_kv',
      where: 'key=?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (rows.first['value'] ?? '').toString();
  }

  /// Write an integer value into app_kv.
  Future<void> _setIntKv(String key, int value) async {
    final db = await AppDatabase.instance();
    await db.execute(
      'CREATE TABLE IF NOT EXISTS app_kv (key TEXT PRIMARY KEY, value TEXT)'
    );
    await db.insert(
      'app_kv',
      {'key': key, 'value': value.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Write a string value into app_kv.
  Future<void> _setStrKv(String key, String value) async {
    final db = await AppDatabase.instance();
    await db.execute(
      'CREATE TABLE IF NOT EXISTS app_kv (key TEXT PRIMARY KEY, value TEXT)'
    );
    await db.insert(
      'app_kv',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get next index for Camus/W. James fallback quotes using a shuffle-bag.
  ///
  /// Guarantees:
  ///  (1) random selection across a cycle,
  ///  (2) no adjacent repeats when length > 1,
  ///  (3) near-even long‑run appearance counts (each item appears once per bag).
  ///
  /// We persist:
  ///  - camus_fallback_bag: JSON array of remaining indices in current cycle.
  ///  - camus_fallback_last: last emitted index.
  Future<int> nextCamusFallbackIndex(int length) async {
    if (length <= 0) return 0;

    const bagKey = 'camus_fallback_bag';
    const lastKey = 'camus_fallback_last';

    final last = await _getIntKv(lastKey, defaultValue: -1);

    List<int> bag = <int>[];
    try {
      final bagStr = await _getStrKv(bagKey);
      if (bagStr != null && bagStr.isNotEmpty) {
        final decoded = json.decode(bagStr);
        if (decoded is List) {
          bag = decoded.map((e) => int.tryParse(e.toString()) ?? -1)
              .where((e) => e >= 0 && e < length)
              .toList();
        }
      }
    } catch (_) {
      bag = <int>[];
    }

    // Refill a new shuffled bag if empty.
    if (bag.isEmpty) {
      bag = List<int>.generate(length, (i) => i);
      bag.shuffle();

      // Avoid adjacent repeat across bag boundaries when possible.
      if (length > 1 && bag.isNotEmpty && bag.first == last) {
        // Swap first with last element (or any other) to break adjacency.
        final swapIdx = bag.length - 1;
        final tmp = bag[0];
        bag[0] = bag[swapIdx];
        bag[swapIdx] = tmp;
      }
    }

    final next = bag.removeAt(0);

    await _setStrKv(bagKey, json.encode(bag));
    await _setIntKv(lastKey, next);

    return next;
  }

}

/// DAO for the quotes_fixed table (名人名言固定表).  Provides operations to
/// query, insert and delete fixed quotes.  Each fixed record stores a
/// snapshot of a quote's data (content, theme, author_name, source_from,
/// explanation, avatar) and a link back to the original quote via quote_id.
class QuoteFixedDao {
  /// Return a list of fixed quotes ordered by descending id.  Supports
  /// pagination via limit and offset.  By default returns up to 20 items.
  Future<List<Map<String, dynamic>>> all({int limit = 20, int offset = 0}) async {
    final db = await AppDatabase.instance();
    return await db.query('quotes_fixed', orderBy: 'id DESC', limit: limit, offset: offset);
  }

  /// Find a fixed quote by exact content and theme.  Returns null if none exist.
  Future<Map<String, dynamic>?> findByContentAndTheme(String content, String theme) async {
    final db = await AppDatabase.instance();
    final rows = await db.query(
      'quotes_fixed',
      where: 'content = ? AND theme = ?',
      whereArgs: [content, theme],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  /// Insert a new fixed quote.  [content] and [theme] are required.
  /// Optionally pass authorName, sourceFrom, explanation, avatar and quoteId.
  /// Returns the inserted record id on success.
  Future<int> insert({
    required String content,
    required String theme,
    String? authorName,
    String? sourceFrom,
    String? explanation,
    String? avatar,
    int? quoteId,
  }) async {
    final db = await AppDatabase.instance();
    final fixedUid = _uid('fixed');
    return await db.insert(
      'quotes_fixed',
      {
        'fixed_uid': fixedUid,
        'quote_id': quoteId,
        'content': content,
        'theme': theme,
        'author_name': authorName ?? '',
        'source_from': sourceFrom ?? '',
        'explanation': explanation ?? '',
        'avatar': avatar ?? '',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Delete a fixed quote by content and theme.  Returns the number of rows removed.
  Future<int> deleteByContentAndTheme(String content, String theme) async {
    final db = await AppDatabase.instance();
    return await db.delete('quotes_fixed', where: 'content = ? AND theme = ?', whereArgs: [content, theme]);
  }

  /// Return count of all fixed quotes.
  Future<int> count() async {
    final db = await AppDatabase.instance();
    final List<Map<String, Object?>> result =
        await db.rawQuery('SELECT COUNT(*) AS c FROM quotes_fixed');
    if (result.isNotEmpty) {
      final dynamic v = result.first['c'];
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? 0;
    }
    return 0;
  }
}

class LogDao {
  Future<void> clearAll() async { final db = await AppDatabase.instance(); await db.delete('logs'); }

  Future<String> add({
    required String taskUid,
    required String detail,
    String? taskNameSnapshot,
    String? taskStartTimeSnapshot,
  }) async {
    final db = await AppDatabase.instance();
    // snapshot task name and start_time
    String? name = taskNameSnapshot, start = taskStartTimeSnapshot;
    final trows = await db.query('tasks', where: 'task_uid=?', whereArgs: [taskUid], limit: 1);
    if (trows.isNotEmpty) {
      name ??= (trows.first['name'] ?? '').toString();
      start ??= (trows.first['start_time'] ?? '').toString();
    }
    final logUid = _uid('log');
    await db.insert('logs', {
      'log_uid': logUid,
      'task_uid': taskUid,
      'detail': detail,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'task_name_snapshot': name,
      'task_start_time_snapshot': start,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    return logUid;
  }

  Future<List<Map<String,dynamic>>> latest({
    int limit=50,
    int offset=0,
    String? keyword,
    bool deepseekOnly=false,
    bool errorOnly=false,
  }) async {
    final db = await AppDatabase.instance();
    final where = <String>[];
    final args = <Object?>[];

    if (deepseekOnly) {
      where.add('(' 
          'COALESCE(logs.task_name_snapshot, tasks.name, "") LIKE ? OR '
          'COALESCE(logs.task_name_snapshot, tasks.name, "") LIKE ? OR '
          'logs.detail LIKE ? OR logs.detail LIKE ? OR logs.detail LIKE ? OR logs.detail LIKE ? OR logs.detail LIKE ? OR logs.detail LIKE ? OR logs.detail LIKE ? OR logs.detail LIKE ? OR logs.detail LIKE ? OR logs.detail LIKE ? OR logs.detail LIKE ? OR logs.detail LIKE ?'
          ')');
      args.add('%DeepSeek%');
      args.add('%OpenAI%');
      args.add('%【DeepSeek请求】%');
      args.add('%【DeepSeek响应】%');
      args.add('%【DeepSeek异常】%');
      args.add('%【OpenAI请求】%');
      args.add('%【OpenAI响应】%');
      args.add('%【OpenAI异常】%');
      args.add('%【DeepSeek-Proxy请求】%');
      args.add('%【DeepSeek-Proxy响应】%');
      args.add('%【DeepSeek-Proxy异常】%');
      args.add('%【OpenAI-Proxy请求】%');
      args.add('%【OpenAI-Proxy响应】%');
      args.add('%【OpenAI-Proxy异常】%');
    }
    if (errorOnly) {
      where.add('(logs.detail LIKE ? OR logs.detail LIKE ? OR logs.detail LIKE ? OR logs.detail LIKE ? OR logs.detail LIKE ?)');
      args.add('%【错误】%');
      args.add('%【DeepSeek异常】%');
      args.add('%【OpenAI异常】%');
      args.add('%【DeepSeek-Proxy异常】%');
      args.add('%【OpenAI-Proxy异常】%');
    }
    if ((keyword ?? '').trim().isNotEmpty) {
      final q = '%${keyword!.trim()}%';
      where.add('(logs.detail LIKE ? OR COALESCE(logs.task_name_snapshot, tasks.name, "") LIKE ? OR COALESCE(logs.task_start_time_snapshot, tasks.start_time, "") LIKE ?)');
      args.add(q);
      args.add(q);
      args.add(q);
    }

    final whereSql = where.isEmpty ? '' : 'WHERE ' + where.join(' AND ');
    final rows = await db.rawQuery(
      'SELECT logs.*, '
      'COALESCE(logs.task_name_snapshot, tasks.name, "") AS task_name, '
      'COALESCE(logs.task_start_time_snapshot, tasks.start_time, "") AS task_start_time '
      'FROM logs LEFT JOIN tasks ON tasks.task_uid = logs.task_uid '
      '$whereSql '
      'ORDER BY logs.id DESC LIMIT ? OFFSET ?', [...args, limit, offset]);
    return rows;
  }
}

/// Simple key-value cache backed by the local SQLite database.
///
/// Used by the Space module to cache tab list API responses so that if cached
/// data exists, we can avoid sending network requests.
class ApiCacheDao {
  Future<String?> getJson(String key) async {
    final db = await AppDatabase.instance();
    final rows = await db.query('api_cache', where: 'cache_key=?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return (rows.first['json'] ?? '').toString();
  }

  Future<void> putJson(String key, String json) async {
    final db = await AppDatabase.instance();
    await db.insert(
      'api_cache',
      {
        'cache_key': key,
        'json': json,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // Basic pruning to avoid unlimited growth.
    await _prune(db, maxRows: 250);
  }

  Future<void> delete(String key) async {
    final db = await AppDatabase.instance();
    await db.delete('api_cache', where: 'cache_key=?', whereArgs: [key]);
  }

  Future<void> _prune(Database db, {required int maxRows}) async {
    try {
      final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM api_cache');
      final dynamic v = rows.isNotEmpty ? rows.first['c'] : 0;
      final count = (v is int) ? v : int.tryParse(v.toString()) ?? 0;
      if (count <= maxRows) return;
      final toDelete = count - maxRows;
      await db.execute(
        'DELETE FROM api_cache WHERE cache_key IN (SELECT cache_key FROM api_cache ORDER BY updated_at ASC LIMIT ?)',
        [toDelete],
      );
    } catch (_) {
      // ignore pruning failures
    }
  }
}

/// Persistent translation cache (DeepSeek translation results).
///
/// key is generated by caller (e.g. sha1(model|target|sourceText)).
class TranslationCacheDao {
  Future<String?> getTranslatedText(String cacheKey) async {
    final db = await AppDatabase.instance();
    final rows = await db.query(
      'translation_cache',
      where: 'cache_key=?',
      whereArgs: [cacheKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (rows.first['translated_text'] ?? '').toString();
  }

  Future<void> put({
    required String cacheKey,
    required String model,
    required String target,
    required String sourceText,
    required String translatedText,
  }) async {
    final db = await AppDatabase.instance();
    await db.insert(
      'translation_cache',
      {
        'cache_key': cacheKey,
        'model': model,
        'target': target,
        'source_text': sourceText,
        'translated_text': translatedText,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}


class FailureStatDao {
  Future<void> insertFail({required String taskUid, required String channel, required String uniqueId, required String dateStr}) async {
    final db = await AppDatabase.instance();
    await db.insert('notify_failures', {
      'task_uid': taskUid,
      'channel': channel,
      'unique_id': uniqueId,
      'status': 'fail',
      'date_str': dateStr,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> markLatestSuccess(String taskUid) async {
    final db = await AppDatabase.instance();
    await db.execute("UPDATE notify_failures SET status='success' WHERE id=(SELECT id FROM notify_failures WHERE task_uid=? ORDER BY id DESC LIMIT 1)", [taskUid]);
  }

  Future<List<Map<String,dynamic>>> failsOfToday() async {
    final db = await AppDatabase.instance();
    final now = DateTime.now();
    final d = now.toIso8601String().substring(0,10); // YYYY-MM-DD
    return await db.query('notify_failures', where: "date_str=? AND status='fail'", whereArgs: [d]);
  }
}


class NotifyConfigDao {
  Future<int> getSelfCheckMinutes() async {
    final db = await AppDatabase.instance();
    final rows = await db.query('notify_config', where: 'key=?', whereArgs: ['selfcheck_minutes']);
    if (rows.isEmpty) return 15;
    final v = int.tryParse((rows.first['value'] ?? '15').toString()) ?? 15;
    return v < 15 ? 15 : v; // WM 最小 15 分钟
  }

  Future<void> setSelfCheckMinutes(int minutes) async {
    final db = await AppDatabase.instance();
    final m = minutes < 15 ? 15 : minutes;
    final exists = await db.query('notify_config', where: 'key=?', whereArgs: ['selfcheck_minutes']);
    if (exists.isEmpty) {
      await db.insert('notify_config', {'key':'selfcheck_minutes','value': m.toString()});
    } else {
      await db.update('notify_config', {'value': m.toString()}, where:'key=?', whereArgs: ['selfcheck_minutes']);
    }
  }

  /// 获取解锁提醒冷却时间（分钟）。如果未设置，则返回默认的 30 分钟。
  /// 如果用户设置了按天的冷却时间（unlock_cooldown_days > 0），则优先返回按天计算的分钟数。
  Future<int> getUnlockCooldownMinutes() async {
    final db = await AppDatabase.instance();
    try {
      // 优先读取 unlock_cooldown_days，如果存在且大于 0，则将天数转为分钟返回
      final daysRows = await db.query('notify_config', where: 'key=?', whereArgs: ['unlock_cooldown_days'], limit: 1);
      if (daysRows.isNotEmpty) {
        final v = daysRows.first['value'];
        final d = double.tryParse((v ?? '').toString());
        if (d != null && d > 0) {
          final mins = (d * 24 * 60).round();
          return mins;
        }
      }
      // 否则读取 unlock_cooldown_minutes，若不存在则返回默认 30
      final rows = await db.query('notify_config', where: 'key=?', whereArgs: ['unlock_cooldown_minutes'], limit: 1);
      if (rows.isEmpty) return 30;
      final v = int.tryParse((rows.first['value'] ?? '').toString());
      if (v == null || v <= 0) return 30;
      return v;
    } catch (_) {
      return 30;
    }
  }

  /// 设置解锁提醒冷却时间。可同时传入分钟和天数，按以下规则处理：
  /// - 若 days > 0，则仅写入 unlock_cooldown_days，并删除 unlock_cooldown_minutes；
  /// - 否则若 minutes > 0，则写入 unlock_cooldown_minutes，并删除 unlock_cooldown_days。
  Future<void> setUnlockCooldown({int? minutes, double? days}) async {
    final db = await AppDatabase.instance();
    // 规范化输入：负数或 null 视为未设置
    final int? m = (minutes != null && minutes! > 0) ? minutes! : null;
    final double? d = (days != null && days! > 0) ? days! : null;
    if (d != null) {
      // 写入天数
      final exists = await db.query('notify_config', where: 'key=?', whereArgs: ['unlock_cooldown_days'], limit: 1);
      final val = d.toString();
      if (exists.isEmpty) {
        await db.insert('notify_config', {'key': 'unlock_cooldown_days', 'value': val});
      } else {
        await db.update('notify_config', {'value': val}, where: 'key=?', whereArgs: ['unlock_cooldown_days']);
      }
      // 清除分钟配置
      await db.delete('notify_config', where: 'key=?', whereArgs: ['unlock_cooldown_minutes']);
    } else if (m != null) {
      // 写入分钟
      final exists = await db.query('notify_config', where: 'key=?', whereArgs: ['unlock_cooldown_minutes'], limit: 1);
      final val = m.toString();
      if (exists.isEmpty) {
        await db.insert('notify_config', {'key': 'unlock_cooldown_minutes', 'value': val});
      } else {
        await db.update('notify_config', {'value': val}, where: 'key=?', whereArgs: ['unlock_cooldown_minutes']);
      }
      // 清除天数配置
      await db.delete('notify_config', where: 'key=?', whereArgs: ['unlock_cooldown_days']);
    }
  }

  /// 获取存储的百度定位 AK。若不存在则返回空字符串。
  Future<String> getBaiduAk() async {
    final db = await AppDatabase.instance();
    try {
      final rows = await db.query('notify_config', where: 'key=?', whereArgs: ['baidu_ak'], limit: 1);
      if (rows.isEmpty) return '';
      final v = rows.first['value'];
      return v?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  /// 获取解锁提醒冷却时间（天）。当未设置 days 时返回 0。
  Future<double> getUnlockCooldownDays() async {
    final db = await AppDatabase.instance();
    try {
      final rows = await db.query('notify_config', where: 'key=?', whereArgs: ['unlock_cooldown_days'], limit: 1);
      if (rows.isEmpty) return 0.0;
      final v = rows.first['value'];
      final d = double.tryParse((v ?? '').toString());
      if (d == null || d <= 0) return 0.0;
      return d;
    } catch (_) {
      return 0.0;
    }
  }

  /// 设置百度定位 AK。传入空字符串将清除该配置。
  Future<void> setBaiduAk(String ak) async {
    final db = await AppDatabase.instance();
    final trimmed = ak.trim();
    if (trimmed.isEmpty) {
      await db.delete('notify_config', where: 'key=?', whereArgs: ['baidu_ak']);
      return;
    }
    final exists = await db.query('notify_config', where: 'key=?', whereArgs: ['baidu_ak'], limit: 1);
    if (exists.isEmpty) {
      await db.insert('notify_config', {'key': 'baidu_ak', 'value': trimmed});
    } else {
      await db.update('notify_config', {'value': trimmed}, where: 'key=?', whereArgs: ['baidu_ak']);
    }
  }

  /// Returns whether the screen-unlock notification switch is enabled.
  /// This reads the value of the `unlock_switch_enabled` key from the
  /// notify_config table. Accepts '1' or 'true' (case-insensitive) as
  /// enabled. If the key is missing or an error occurs, returns false.
  Future<bool> getUnlockSwitchEnabled() async {
    try {
      final db = await AppDatabase.instance();
      final rows = await db.query('notify_config', where: 'key=?', whereArgs: ['unlock_switch_enabled'], limit: 1);
      if (rows.isEmpty) return false;
      final v = rows.first['value'];
      if (v == null) return false;
      if (v is int) return v == 1;
      final s = v.toString();
      return s == '1' || s.toLowerCase() == 'true';
    } catch (_) {
      return false;
    }
  }

  /// Sets the screen-unlock notification switch. Persists the value in
  /// the notify_config table as '1' for enabled or '0' for disabled. If
  /// the key does not yet exist, it will be inserted. Exceptions are
  /// swallowed to avoid propagating database errors to callers.
  Future<void> setUnlockSwitchEnabled(bool enabled) async {
    try {
      final db = await AppDatabase.instance();
      final val = enabled ? '1' : '0';
      final exists = await db.query('notify_config', where: 'key=?', whereArgs: ['unlock_switch_enabled'], limit: 1);
      if (exists.isEmpty) {
        await db.insert('notify_config', {'key': 'unlock_switch_enabled', 'value': val});
      } else {
        await db.update('notify_config', {'value': val}, where: 'key=?', whereArgs: ['unlock_switch_enabled']);
      }
    } catch (_) {}
  }
}


class NotifyGuardDao {
  Future<bool> alreadySent(String taskUid, String runKey, {String chan='main-wm', int attempt=1}) async {
    final db = await AppDatabase.instance();
    final rows = await db.query('notify_guard', where: 'task_uid=? AND run_key=? AND (chan=? OR chan IS NULL) AND (attempt=? OR attempt IS NULL)', whereArgs: [taskUid, runKey, chan, attempt]);
    return rows.isNotEmpty;
  }
  Future<void> markSent(String taskUid, String runKey, {String chan='main-wm', int attempt=1}) async {
    final db = await AppDatabase.instance();
    await db.insert('notify_guard', {'task_uid': taskUid, 'run_key': runKey, 'chan': chan, 'attempt': attempt, 'created_at': DateTime.now().toIso8601String()});
  }
}


class _AuxTables {

static Future<void> _addColumnIfMissing(
    Database db, String table, String column, String definition) async {
  final info = await db.rawQuery("PRAGMA table_info($table)");
  final cols = info.map((e) => e['name'] as String).toList();
  if (!cols.contains(column)) {
    await db.execute("ALTER TABLE $table ADD COLUMN $column $definition");
  }
}

  static Future<void> ensure() async {
    final db = await AppDatabase.instance();
    await db.execute("CREATE TABLE IF NOT EXISTS notify_failures (id INTEGER PRIMARY KEY AUTOINCREMENT, task_uid TEXT, channel TEXT, unique_id TEXT, status TEXT, date_str TEXT, created_at TEXT)");
    await db.execute("CREATE TABLE IF NOT EXISTS notify_config (key TEXT PRIMARY KEY, value TEXT)");
    await db.execute("CREATE TABLE IF NOT EXISTS notify_guard (id INTEGER PRIMARY KEY AUTOINCREMENT, task_uid TEXT, run_key TEXT, created_at TEXT, UNIQUE(task_uid, run_key))");
  
    await _AuxTablesTasksExt.ensureTaskColumns();
    // Migrate notify_guard to precise keys (safe, no duplicate-column logs)
    await _addColumnIfMissing(db, "notify_guard", "chan", "TEXT");
    await _addColumnIfMissing(db, "notify_guard", "attempt", "INTEGER");
    try { await db.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_notify_guard ON notify_guard(task_uid, run_key, chan, attempt)"); } catch (_) {}

  }
}

class _AuxTablesTasksExt {
  static Future<void> ensureTaskColumns() async {
    final db = await AppDatabase.instance();
    await _AuxTables._addColumnIfMissing(db, "tasks", "scheduled_run_key", "TEXT");
    await _AuxTables._addColumnIfMissing(db, "tasks", "next_time", "TEXT");
  }
}

// Public helper to ensure auxiliary tables and columns exist.  This should be
// invoked early in the app startup to add missing columns (like next_time
// and scheduled_run_key) on older databases.  It simply forwards to the
// internal _AuxTables.ensure() which is private to this library.  Do not
// reference _AuxTables from outside this file directly since it is
// library‑private.
Future<void> ensureExtraTaskColumns() async {
  await _AuxTables.ensure();
}

extension TaskDaoPatch on TaskDao {
  Future<void> setScheduledRunKey(String uid, String runKey) async {
    final db = await AppDatabase.instance();
    try {
      // Try update scheduled_run_key normally. If column missing, ensure extra columns then retry.
      await db.update('tasks', {'scheduled_run_key': runKey}, where: 'task_uid=?', whereArgs: [uid]);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('no such column') && msg.contains('scheduled_run_key')) {
        try {
          await ensureExtraTaskColumns();
          await db.update('tasks', {'scheduled_run_key': runKey}, where: 'task_uid=?', whereArgs: [uid]);
        } catch (_) {}
      }
    }
  }
}


class BulkImportResult {
  final bool success;
  final List<Map<String, dynamic>> details; // [{row, reason}]
  BulkImportResult(this.success, this.details);
}

extension QuoteDaoBulk on QuoteDao {
  Future<BulkImportResult> bulkImportCsv({required String csvPath, String? avatarPath}) async {
    final db = await AppDatabase.instance();
    final content = await File(csvPath).readAsString();
    final rows = LineSplitter().convert(content);
    if (rows.isEmpty) return BulkImportResult(false, [{'row':0,'reason':'CSV为空'}]);
    // Parse using simple CSV rules or rely on commas
    // Try to use package:csv if available
    List<List<dynamic>> table = [];
    try {
      // ignore: undefined_prefixed_name
      table = CsvToListConverter(eol: '\n').convert(content);
    } catch (_) {
      // Fallback naive split
      for (final line in rows) {
        table.add(line.split(','));
      }
    }
    if (table.isEmpty) return BulkImportResult(false, [{'row':0,'reason':'CSV解析失败'}]);
    final header = table.first.map((e)=> e.toString().trim()).toList();
    // 自动匹配 CSV 标题与字段名称（支持关键词匹配）。
    // 定义每个字段名称对应的一组中文关键词。只要标题包含其中任意一个关键词，就认为匹配到该字段。
    final Map<String, List<String>> _fieldKeywords = {
      '主题': ['主题','标题','中心思想','中心主题','主题思想'],
      '名人名言内容': ['名人名言内容','名句内容','名言','经典名言','核心内容','内容'],
      '署名': ['署名','作者','签名'],
      '出处': ['出处','来源','著作','出自','引用出处'],
      '解释': ['解释','概要','详细解释','解释和具体案例','为什么和该如何做','为什么','该如何做','深度分析','是什么'],
    };
    // 根据表头逐列匹配字段索引。若列标题包含某个字段的关键词且该字段尚未被匹配，则记录索引。
    final Map<String,int> idx = {};
    for (int i = 0; i < header.length; i++) {
      final col = header[i];
      _fieldKeywords.forEach((field, keywords) {
        for (final kw in keywords) {
          if (!idx.containsKey(field) && col.contains(kw)) {
            idx[field] = i;
            break;
          }
        }
      });
    }
    // 检查是否缺少必需的字段；若任何字段未匹配，则返回错误。
    final missingFields = _fieldKeywords.keys.where((k) => !idx.containsKey(k)).toList();
    if (missingFields.isNotEmpty) {
      return BulkImportResult(false, [{'row':1,'reason':'缺少表头: ' + missingFields.join('、')}]);
    }
    // Prepare duplicate checks
    final errors = <Map<String,dynamic>>[];
    final seen = <String>{};
    // DB duplicates
    final dbRows = await db.query('quotes', columns: ['content']);
    final dbSet = dbRows.map((e)=> (e['content']??'').toString().trim().toLowerCase()).toSet();
    for (int i=1;i<table.length;i++){
      final row = table[i];
      String contentCell = (row.length>idx['名人名言内容']! ? row[idx['名人名言内容']!].toString() : '').trim();
      final rnum = i+1;
      if (contentCell.isEmpty) {
        errors.add({'row': rnum, 'reason': '名人名言内容为空'});
      } else {
        final key = contentCell.toLowerCase();
        if (seen.contains(key)) errors.add({'row': rnum, 'reason': '名人名言内容在CSV中重复'});
        if (dbSet.contains(key)) errors.add({'row': rnum, 'reason': '名人名言内容与数据库重复'});
        seen.add(key);
      }
    }
    if (errors.isNotEmpty) return BulkImportResult(false, errors);

    // Ensure a task '批量导入' exists
    final taskDao = TaskDao();
    String bulkTaskUid;
    final rowsTasks = await db.query('tasks', where: 'name=?', whereArgs: ['批量导入'], limit: 1);
    if (rowsTasks.isEmpty) {
      // Create a bulk import task with type '批量导入任务'.  Use empty fields for prompt and startTime; cursor defaults to 0.
      bulkTaskUid = await taskDao.create(
        name: '批量导入',
        type: '批量导入任务',
        status: 'on',
        prompt: '',
        avatarPath: '',
        startTime: '',
        freqType: 'daily',
        freqWeekday: null,
        freqDayOfMonth: null,
        freqCustom: null,
      );
    } else {
      bulkTaskUid = rowsTasks.first['task_uid'] as String;
      // Ensure the existing bulk-import task has the correct type
      final existingType = (rowsTasks.first['type'] ?? '').toString();
      if (existingType != '批量导入任务') {
        await taskDao.update(bulkTaskUid, {'type': '批量导入任务'});
      }
    }

    // Insert all within a transaction
    try {
      await db.transaction((txn) async {
        // Compute once the timestamp string used for all inserted quotes' task_name (批量导入_YYYY-MM-DD HH:mm:SS)
        final now = DateTime.now();
        String two(int n) => n < 10 ? '0$n' : '$n';
        final nowStr = '${now.year}-${two(now.month)}-${two(now.day)} ${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
        for (int i = 1; i < table.length; i++) {
          final row = table[i];
          String theme = row.length > idx['主题']! ? row[idx['主题']!].toString().trim() : '';
          String contentCell = row.length > idx['名人名言内容']! ? row[idx['名人名言内容']!].toString().trim() : '';
          String authorName = row.length > idx['署名']! ? row[idx['署名']!].toString().trim() : '';
          String sourceFrom = row.length > idx['出处']! ? row[idx['出处']!].toString().trim() : '';
          String explanation = row.length > idx['解释']! ? row[idx['解释']!].toString().trim() : '';
          final uid = _uid('quote');
          await txn.insert('quotes', {
            'quote_uid': uid,
            'task_uid': bulkTaskUid,
            // task_type for bulk import tasks is 批量导入任务
            'task_type': '批量导入任务',
            // task_name should include timestamp to differentiate this batch
            'task_name': '批量导入_$nowStr',
            'content': contentCell,
            'theme': theme,
            'author_name': authorName,
            'source_from': sourceFrom,
            'explanation': explanation,
            'avatar': avatarPath ?? '',
            'inserted_at': nowStr,
            'notified': 0,
            'created_at': now.millisecondsSinceEpoch,
          });
          await txn.insert('logs', {
            'log_uid': _uid('log'),
            'task_uid': bulkTaskUid,
            'detail': '批量导入: 已插入一条名言'
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      });
      return BulkImportResult(true, []);
    } catch (e) {
      // Transaction will rollback automatically
      return BulkImportResult(false, [{'row': 0, 'reason': '插入数据库失败: ' + e.toString()}]);
    }
  }


/// 物理洗牌：真正改变 quotes 表的行顺序（方案B：重建表并写入新 id）
Future<void> shuffleQuotesPhysically() async {
  // -- 改进版物理洗牌：随机写入 quotes_new，然后替换 --
  final db = await AppDatabase.instance();
  await db.transaction((txn) async {
    // 1) 复制表结构到 quotes_new
    final schemaRows = await txn.query(
      'sqlite_master',
      columns: ['sql'],
      where: "type='table' AND name='quotes'",
      limit: 1,
    );
    final String rawCreate = (schemaRows.first['sql'] as String);
    final String createSql = rawCreate.replaceFirst(
      RegExp(r'CREATE\s+TABLE\s+[\"`]?quotes[\"`]?', caseSensitive: false),
      'CREATE TABLE quotes_new'
    );
    await txn.execute('DROP TABLE IF EXISTS quotes_new');
    await txn.execute(createSql);

    // 2) 随机盐 + random() 打散行顺序，然后直接插入 quotes_new
    final int salt = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    await txn.rawInsert('''
      INSERT INTO quotes_new (
        quote_uid, task_uid, content, notified, created_at,
        theme, author_name, source_from, explanation, avatar,
        inserted_at, last_notified_at, taskType, taskName, task_type, task_name
      )
      SELECT
        quote_uid, task_uid, content, notified, created_at,
        theme, author_name, source_from, explanation, avatar,
        inserted_at, last_notified_at, taskType, taskName, task_type, task_name
      FROM quotes
      ORDER BY abs(random() + ?), rowid
    ''', [salt]);

    // 3) 替换旧表
    await txn.execute('DROP TABLE quotes');
    await txn.execute('ALTER TABLE quotes_new RENAME TO quotes');
  });

  // 4) VACUUM 固化页顺序
  try {
    await db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
  } catch (_) {}
  try {
    await db.execute('VACUUM');
  } catch (_) {}
}

/// 恢复到“最初插入表时”的顺序（使用备份表中 original_pos / original_id）
Future<void> restoreQuotesToOriginalOrder() async {
  final db = await AppDatabase.instance();
  await db.transaction((txn) async {
    // 1) 确保备份表存在（若不存在则无从恢复）
    await txn.execute('CREATE TABLE IF NOT EXISTS quotes_id_backup(quote_uid TEXT PRIMARY KEY, original_id INTEGER, original_pos INTEGER)');
    await txn.execute('INSERT OR IGNORE INTO quotes_id_backup(quote_uid, original_id, original_pos) SELECT quote_uid, id, rowid FROM quotes');

    // 2) 用当前 quotes 表的结构创建新表
    final schemaRows = await txn.rawQuery("SELECT sql FROM sqlite_master WHERE type='table' AND name='quotes'");
    if (schemaRows.isEmpty || schemaRows.first['sql'] == null) {
      throw Exception('无法读取 quotes 表结构');
    }
    final String rawCreate2 = (schemaRows.first['sql'] as String);
final String createSql2 = rawCreate2.replaceFirst(
  RegExp(r'CREATE\s+TABLE\s+[\"`]?quotes[\"`]?', caseSensitive: false),
  'CREATE TABLE quotes_new'
);
await txn.execute('DROP TABLE IF EXISTS quotes_new');
await txn.execute(createSql2);

    // 2.1 备份索引
    final idxRows = await txn.rawQuery("SELECT sql FROM sqlite_master WHERE type='index' AND tbl_name='quotes' AND sql IS NOT NULL");

    // 3) 动态列集合（除 id 外）
    final cols = await txn.rawQuery('PRAGMA table_info(quotes)');
    final allCols = <String>[];
    for (final c in cols) {
      final name = (c['name'] ?? '') as String;
      if (name.isNotEmpty) allCols.add(name);
    }
    final nonId = allCols.where((e) => e != 'id').toList();
    final nonIdJoined = nonId.map((c) => 'q.' + c).join(', ');
    final newColsJoined = nonId.join(', ');

    // 4) 按 original_pos 顺序恢复，并把 id 恢复为 original_id
    final insertSql = 'INSERT INTO quotes_new (id, ' + newColsJoined + ') '
        'SELECT b.original_id, ' + nonIdJoined + ' FROM quotes q JOIN quotes_id_backup b ON b.quote_uid=q.quote_uid '
        'ORDER BY b.original_pos ASC';
    await txn.execute(insertSql);

    // 5) 替换原表
    await txn.execute('DROP TABLE quotes');
    await txn.execute('ALTER TABLE quotes_new RENAME TO quotes');

    // 6) 重建索引
    for (final row in idxRows) {
      final sql = row['sql'] as String?;
      if (sql != null && sql.trim().isNotEmpty) {
        await txn.execute(sql);
      }
    }
  });
}
}


/// VisionDao: 愿景与目标 / WOOP / 触发规则 / 专注会话 / 未完成钩子 / 反思。
/// 为了兼容现有代码：
/// - 不修改任何已有表结构；
/// - 所有新增内容使用独立表，并通过 IF NOT EXISTS 创建。
class VisionDao {
  Future<Database> _db() => AppDatabase.instance();

  Future<void> _ensureTables(Database db) async {
    // 单一核心愿景（仅存一行）
    await db.execute(
      'CREATE TABLE IF NOT EXISTS vision_goal ('
      'id TEXT PRIMARY KEY,'
      'title TEXT NOT NULL,'
      'domain TEXT,'
      'why_surface TEXT,'
      'why_life TEXT,'
      'why_identity TEXT,'
      'identity_stmt TEXT,'
      'updated_at INTEGER'
      ')'
    );
    // WOOP：同样只存一行（当前阶段 WOOP）
    await db.execute(
      'CREATE TABLE IF NOT EXISTS vision_woop ('
      'id TEXT PRIMARY KEY,'
      'wish TEXT,'
      'outcome TEXT,'
      'obstacles TEXT,'
      'plan TEXT,'
      'updated_at INTEGER'
      ')'
    );
    // 执行意向 / 情境触发规则（可以多条）
    await db.execute(
      'CREATE TABLE IF NOT EXISTS vision_triggers ('
      'id TEXT PRIMARY KEY,'
      'type TEXT,'
      'config TEXT,'
      'then_text TEXT,'
      'enabled INTEGER,'
      'updated_at INTEGER'
      ')'
    );
    // 专注会话（时间盒）
    await db.execute(
      'CREATE TABLE IF NOT EXISTS vision_sessions ('
      'id TEXT PRIMARY KEY,'
      'title TEXT,'
      'planned_minutes INTEGER,'
      'actual_minutes INTEGER,'
      'start_ts INTEGER,'
      'end_ts INTEGER,'
      'focus_score INTEGER,'
      'mood_tag TEXT'
      ')'
    );
    // Ensure columns for persistent countdown / pause-resume (idempotent, avoid noisy duplicate-column logs)
    final _vsInfo = await db.rawQuery('PRAGMA table_info(vision_sessions)');
    final _vsCols = _vsInfo.map((e) => (e['name'] ?? '').toString()).toSet();
    if (!_vsCols.contains('paused_total_ms')) {
      await db.execute('ALTER TABLE vision_sessions ADD COLUMN paused_total_ms INTEGER');
    }
    if (!_vsCols.contains('paused_at_ms')) {
      await db.execute('ALTER TABLE vision_sessions ADD COLUMN paused_at_ms INTEGER');
    }
    if (!_vsCols.contains('state')) {
      await db.execute('ALTER TABLE vision_sessions ADD COLUMN state TEXT');
    }

    // 未完成钩子
    await db.execute(
      'CREATE TABLE IF NOT EXISTS vision_hooks ('
      'id TEXT PRIMARY KEY,'
      'session_id TEXT,'
      'text TEXT,'
      'next_action TEXT,'
      'resolved INTEGER,'
      'created_ts INTEGER'
      ')'
    );
    // Ensure columns for associating hook with goal/woop/task (idempotent)
    final _vhInfo = await db.rawQuery('PRAGMA table_info(vision_hooks)');
    final _vhCols = _vhInfo.map((e) => (e['name'] ?? '').toString()).toSet();
    if (!_vhCols.contains('goal_title')) {
      await db.execute('ALTER TABLE vision_hooks ADD COLUMN goal_title TEXT');
    }
    if (!_vhCols.contains('woop_wish')) {
      await db.execute('ALTER TABLE vision_hooks ADD COLUMN woop_wish TEXT');
    }
    if (!_vhCols.contains('task_title')) {
      await db.execute('ALTER TABLE vision_hooks ADD COLUMN task_title TEXT');
    }

    // 每日反思 & 健康边界
    await db.execute(
      'CREATE TABLE IF NOT EXISTS vision_reflections ('
      'id TEXT PRIMARY KEY,'
      'date TEXT,'  // YYYY-MM-DD
      'presence INTEGER,'
      'mood TEXT,'
      'note TEXT,'
      'goal_title TEXT,'
      'woop_wish TEXT,'
      'task_title TEXT,'
      'created_ts INTEGER'
      ')'
    );
    // Ensure columns for associating reflection with goal/woop/task (idempotent, 兼容旧库)
    final _vrInfo = await db.rawQuery('PRAGMA table_info(vision_reflections)');
    final _vrCols = _vrInfo.map((e) => (e['name'] ?? '').toString()).toSet();
    if (!_vrCols.contains('goal_title')) {
      await db.execute('ALTER TABLE vision_reflections ADD COLUMN goal_title TEXT');
    }
    if (!_vrCols.contains('woop_wish')) {
      await db.execute('ALTER TABLE vision_reflections ADD COLUMN woop_wish TEXT');
    }
    if (!_vrCols.contains('task_title')) {
      await db.execute('ALTER TABLE vision_reflections ADD COLUMN task_title TEXT');
    }

    // 念头记录（弹窗速记）
    await db.execute(
      'CREATE TABLE IF NOT EXISTS vision_thoughts ('
      'id TEXT PRIMARY KEY,'
      'thought TEXT,'
      'task_title TEXT,'
      'goal_title TEXT,'
      'woop_wish TEXT,'
      'created_ts INTEGER'
      ')'
    );

    // 念头概念树（可配置、可扩展、支持懒加载）
    // - vision_taxonomy / vision_node / vision_property_def / vision_node_property
    // - vision_thought_node (thought 多选节点映射)
    await ensureThoughtTaxonomy(db);
  }

  /// 读取当前唯一核心愿景（没有则返回 null）
  Future<Map<String, dynamic>?> loadGoal() async {
    final db = await _db();
    await _ensureTables(db);
    final rows = await db.query('vision_goal', limit: 1);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// 保存/更新核心愿景（总是覆盖为单一愿景）
  Future<void> saveGoal({
    required String title,
    String? domain,
    String? whySurface,
    String? whyLife,
    String? whyIdentity,
    String? identityStmt,
  }) async {
    final db = await _db();
    await _ensureTables(db);
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'vision_goal',
      {
        'id': 'one', // 单一愿景
        'title': title,
        'domain': domain ?? '',
        'why_surface': whySurface ?? '',
        'why_life': whyLife ?? '',
        'why_identity': whyIdentity ?? '',
        'identity_stmt': identityStmt ?? '',
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 读取当前 WOOP 配置
  Future<Map<String, dynamic>?> loadWoop() async {
    final db = await _db();
    await _ensureTables(db);
    final rows = await db.query('vision_woop', limit: 1);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// 保存 WOOP 配置（Wish / Outcome / Obstacles / Plan）
  Future<void> saveWoop({
    required String wish,
    String? outcome,
    String? obstacles,
    String? plan,
  }) async {
    final db = await _db();
    await _ensureTables(db);
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'vision_woop',
      {
        'id': 'one',
        'wish': wish,
        'outcome': outcome ?? '',
        'obstacles': obstacles ?? '',
        'plan': plan ?? '',
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 列出所有触发规则（按更新时间逆序）
  Future<List<Map<String, dynamic>>> listTriggers() async {
    final db = await _db();
    await _ensureTables(db);
    final rows = await db.query(
      'vision_triggers',
      orderBy: 'updated_at DESC',
    );
    return rows;
  }

  /// 新增或更新触发规则（若 id 为空则自动生成）
  Future<String> upsertTrigger({
    String? id,
    required String type,   // 例如 time / behavior
    required String config, // JSON 字符串
    required String thenText,
    bool enabled = true,
  }) async {
    final db = await _db();
    await _ensureTables(db);
    final now = DateTime.now().millisecondsSinceEpoch;
    final uid = (id == null || id.isEmpty) ? _uid('vtrg') : id;
    await db.insert(
      'vision_triggers',
      {
        'id': uid,
        'type': type,
        'config': config,
        'then_text': thenText,
        'enabled': enabled ? 1 : 0,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return uid;
  }

  Future<void> deleteTrigger(String id) async {
    final db = await _db();
    await _ensureTables(db);
    await db.delete('vision_triggers', where: 'id=?', whereArgs: [id]);
  }

  /// 创建一条专注会话记录，并返回其 id
  Future<String> startSession({
    required String title,
    required int plannedMinutes,
  }) async {
    final db = await _db();
    await _ensureTables(db);
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uid('vses');
    await db.insert(
      'vision_sessions',
      {
        'id': id,
        'title': title,
        'planned_minutes': plannedMinutes,
        'actual_minutes': 0,
        'start_ts': now,
        'end_ts': null,
        'focus_score': null,
        'mood_tag': null,
        'paused_total_ms': 0,
        'paused_at_ms': null,
        'state': 'running',
      },
    );
    return id;
  }

  /// 获取一条专注会话（用于倒计时持久化）
  Future<Map<String, dynamic>?> getSessionById(String sessionId) async {
    final db = await _db();
    await _ensureTables(db);
    final rows = await db.query(
      'vision_sessions',
      where: 'id=?',
      whereArgs: [sessionId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// 更新专注会话的暂停/继续状态（用于前台/后台不中断）
  Future<void> updateSessionPauseState({
    required String sessionId,
    required String state, // running | paused | finished
    int? pausedAtMs,
    int? pausedTotalMs,
  }) async {
    final db = await _db();
    await _ensureTables(db);
    final m = <String, dynamic>{
      'state': state,
    };
    if (pausedAtMs != null) m['paused_at_ms'] = pausedAtMs;
    if (pausedTotalMs != null) m['paused_total_ms'] = pausedTotalMs;
    await db.update(
      'vision_sessions',
      m,
      where: 'id=?',
      whereArgs: [sessionId],
    );
  }

  /// 重置专注会话的计时（用于倒计时页面的 Reset）
  Future<void> resetSessionTiming({
    required String sessionId,
    required int startTsMs,
  }) async {
    final db = await _db();
    await _ensureTables(db);
    await db.update(
      'vision_sessions',
      {
        'start_ts': startTsMs,
        'end_ts': null,
        'actual_minutes': 0,
        'paused_total_ms': 0,
        'paused_at_ms': null,
        'state': 'running',
      },
      where: 'id=?',
      whereArgs: [sessionId],
    );
  }



  /// 结束一条专注会话，并可选生成一个未完成钩子
  Future<void> finishSession({
    required String sessionId,
    required int actualMinutes,
    int? focusScore,
    String? moodTag,
    String? hookText,
    String? nextAction,
    String? goalTitle,
    String? woopWish,
    String? taskTitle,
  }) async {
    final db = await _db();
    await _ensureTables(db);
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'vision_sessions',
      {
        'actual_minutes': actualMinutes,
        'end_ts': now,
        'focus_score': focusScore,
        'mood_tag': moodTag,
        'state': 'finished',
      },
      where: 'id=?',
      whereArgs: [sessionId],
    );
    if (hookText != null && hookText.trim().isNotEmpty) {
      final hookId = _uid('vhk');
      await db.insert(
        'vision_hooks',
        {
          'id': hookId,
          'session_id': sessionId,
          'text': hookText.trim(),
          'next_action': (nextAction ?? '').trim(),
          'resolved': 0,
          'created_ts': now,
          'goal_title': (goalTitle ?? '').trim(),
          'woop_wish': (woopWish ?? '').trim(),
          'task_title': (taskTitle ?? '').trim(),
        },
      );
    }
  }

  /// 最近一个未完成钩子（未 resolved）
  Future<Map<String, dynamic>?> latestOpenHook() async {
    final db = await _db();
    await _ensureTables(db);
    final rows = await db.query(
      'vision_hooks',
      where: 'resolved=0',
      orderBy: 'created_ts DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> resolveHook(String id) async {
    final db = await _db();
    await _ensureTables(db);
    await db.update(
      'vision_hooks',
      {'resolved': 1},
      where: 'id=?',
      whereArgs: [id],
    );
  }


  /// 钩子历史（包含未完成与已接上）
  Future<List<Map<String, dynamic>>> listHooksAll() async {
    final db = await _db();
    await _ensureTables(db);
    final rows = await db.query(
      'vision_hooks',
      orderBy: 'created_ts DESC',
    );
    return rows;
  }

  /// 读取近 N 天的专注会话（用于统计）
  Future<List<Map<String, dynamic>>> listSessionsSince(int startTs) async {
    final db = await _db();
    await _ensureTables(db);
    final rows = await db.query(
      'vision_sessions',
      where: 'start_ts>=?',
      whereArgs: [startTs],
      orderBy: 'start_ts DESC',
    );
    return rows;
  }

  /// 读取近 N 天的反思记录（按 date 倒序）
  Future<List<Map<String, dynamic>>> listReflectionsSince(String startDate) async {
    final db = await _db();
    await _ensureTables(db);
    final rows = await db.query(
      'vision_reflections',
      where: 'date>=?',
      whereArgs: [startDate],
      orderBy: 'date DESC',
    );
    return rows;
  }

  /// 新增一条“念头”记录
  Future<String> addThought({
    required String thought,
    required String taskTitle,
    required String goalTitle,
    required String woopWish,
    List<String>? nodeUids,
    int? createdTs,
  }) async {
    final db = await _db();
    await _ensureTables(db);
    final now = createdTs ?? DateTime.now().millisecondsSinceEpoch;
    final id = _uid('vtht');
    await db.transaction((txn) async {
      await txn.insert(
        'vision_thoughts',
        {
          'id': id,
          'thought': thought,
          'task_title': taskTitle,
          'goal_title': goalTitle,
          'woop_wish': woopWish,
          'created_ts': now,
        },
      );

      final uids = (nodeUids ?? <String>[]).where((e) => e.trim().isNotEmpty).toSet().toList();
      if (uids.isNotEmpty) {
        final b = txn.batch();
        for (final uid in uids) {
          b.insert(
            'vision_thought_node',
            {'thought_id': id, 'node_uid': uid},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
        await b.commit(noResult: true);
      }
    });
    return id;
  }

  /// 最近一条念头
  Future<Map<String, dynamic>?> latestThought() async {
    final db = await _db();
    await _ensureTables(db);
    final rows = await db.rawQuery('''
      SELECT t.*,
        (
          SELECT group_concat(n.title, ' · ')
          FROM vision_thought_node j
          JOIN vision_node n
            ON n.taxonomy_id = ? AND n.uid = j.node_uid
          WHERE j.thought_id = t.id
          ORDER BY n.depth ASC, n.display_order ASC, n.id ASC
        ) AS node_titles,
        (
          SELECT group_concat(j.node_uid, ',')
          FROM vision_thought_node j
          WHERE j.thought_id = t.id
        ) AS node_uids
      FROM vision_thoughts t
      ORDER BY t.created_ts DESC
      LIMIT 1
    ''', [kThoughtTaxonomyId]);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// 分页读取念头历史（默认每页 50）
  Future<List<Map<String, dynamic>>> listThoughtsPaged({int limit = 50, int offset = 0}) async {
    final db = await _db();
    await _ensureTables(db);
    final rows = await db.rawQuery('''
      SELECT t.*,
        (
          SELECT group_concat(n.title, ' · ')
          FROM vision_thought_node j
          JOIN vision_node n
            ON n.taxonomy_id = ? AND n.uid = j.node_uid
          WHERE j.thought_id = t.id
          ORDER BY n.depth ASC, n.display_order ASC, n.id ASC
        ) AS node_titles,
        (
          SELECT group_concat(j.node_uid, ',')
          FROM vision_thought_node j
          WHERE j.thought_id = t.id
        ) AS node_uids
      FROM vision_thoughts t
      ORDER BY t.created_ts DESC
      LIMIT ? OFFSET ?
    ''', [kThoughtTaxonomyId, limit, offset]);
    return rows;
  }

  /// 根节点列表（用于懒加载树）
  Future<List<Map<String, dynamic>>> listThoughtRootNodes() async {
    final db = await _db();
    await _ensureTables(db);
    return db.query(
      'vision_node',
      where: 'taxonomy_id=? AND parent_uid IS NULL AND is_active=1',
      whereArgs: [kThoughtTaxonomyId],
      orderBy: 'display_order ASC, id ASC',
    );
  }

  /// 子节点列表（用于懒加载树）
  Future<List<Map<String, dynamic>>> listThoughtChildNodes(String parentUid) async {
    final db = await _db();
    await _ensureTables(db);
    return db.query(
      'vision_node',
      where: 'taxonomy_id=? AND parent_uid=? AND is_active=1',
      whereArgs: [kThoughtTaxonomyId, parentUid],
      orderBy: 'display_order ASC, id ASC',
    );
  }

  /// 批量读取节点（用于思维导图/概念树回显）
  Future<List<Map<String, dynamic>>> listThoughtNodesByUids(Set<String> uids) async {
    final db = await _db();
    await _ensureTables(db);
    final list = uids.where((e) => e.trim().isNotEmpty).toList();
    if (list.isEmpty) return const <Map<String, dynamic>>[];

    const chunkSize = 900; // SQLite 变量上限通常为 999
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < list.length; i += chunkSize) {
      final chunk = list.sublist(i, (i + chunkSize).clamp(0, list.length));
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await db.rawQuery('''
        SELECT uid, title, parent_uid, depth, display_order, has_children
        FROM vision_node
        WHERE taxonomy_id = ? AND uid IN ($placeholders) AND is_active=1
      ''', [kThoughtTaxonomyId, ...chunk]);
      out.addAll(rows);
    }
    return out;
  }

  /// 批量读取某些父节点的所有子节点（用于补充“并列关系”）
  Future<List<Map<String, dynamic>>> listThoughtNodesByParentUids(Set<String> parentUids) async {
    final db = await _db();
    await _ensureTables(db);
    final list = parentUids.where((e) => e.trim().isNotEmpty).toList();
    if (list.isEmpty) return const <Map<String, dynamic>>[];

    const chunkSize = 900;
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < list.length; i += chunkSize) {
      final chunk = list.sublist(i, (i + chunkSize).clamp(0, list.length));
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await db.rawQuery('''
        SELECT uid, title, parent_uid, depth, display_order, has_children
        FROM vision_node
        WHERE taxonomy_id = ? AND parent_uid IN ($placeholders) AND is_active=1
        ORDER BY depth ASC, display_order ASC, id ASC
      ''', [kThoughtTaxonomyId, ...chunk]);
      out.addAll(rows);
    }
    return out;
  }

  /// 分页读取反思历史（默认每页 50）
  Future<List<Map<String, dynamic>>> listReflectionsPaged({int limit = 50, int offset = 0}) async {
    final db = await _db();
    await _ensureTables(db);
    final rows = await db.query(
      'vision_reflections',
      orderBy: 'created_ts DESC',
      limit: limit,
      offset: offset,
    );
    return rows;
  }

  /// 写入每日反思记录
  Future<void> addReflection({
    required DateTime date,
    required int presenceScore, // 0~10
    String? mood,
    String? note,
    String? goalTitle,
    String? woopWish,
    String? taskTitle,
  }) async {
    final db = await _db();
    await _ensureTables(db);
    final id = _uid('vref');
    final now = DateTime.now().millisecondsSinceEpoch;
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final dateStr = '$y-$m-$d';
    await db.insert(
      'vision_reflections',
      {
        'id': id,
        'date': dateStr,
        'presence': presenceScore,
        'mood': mood ?? '',
        'note': note ?? '',
        'goal_title': (goalTitle ?? '').trim(),
        'woop_wish': (woopWish ?? '').trim(),
        'task_title': (taskTitle ?? '').trim(),
        'created_ts': now,
      },
    );
  }

  /// 最近一条反思
  Future<Map<String, dynamic>?> latestReflection() async {
    final db = await _db();
    await _ensureTables(db);
    final rows = await db.query(
      'vision_reflections',
      orderBy: 'created_ts DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// 最近一条专注会话（用于概要展示）
  Future<Map<String, dynamic>?> latestSession() async {
    final db = await _db();
    await _ensureTables(db);
    final rows = await db.query(
      'vision_sessions',
      orderBy: 'start_ts DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }
}