import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import 'voice_lab_models.dart';

String voiceLabUid(String prefix) {
  final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  return '${prefix}_$now';
}

class VoiceLabDao {
  Future<void> ensureTables() async {
    final db = await AppDatabase.instance();
    await ensureTablesOn(db);
  }

  static Future<void> ensureTablesOn(Database db) async {
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

  static Future<void> _addColumnIfMissing(Database db, String table, String column, String definition) async {
    try {
      final cols = await db.rawQuery('PRAGMA table_info($table)');
      final exists = cols.any((row) => (row['name'] ?? '').toString() == column);
      if (!exists) {
        await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
      }
    } catch (_) {
      // Keep app startup resilient across reused/local SQLite schemas.
    }
  }

  Future<List<VoiceProfile>> listVoiceProfiles() async {
    await ensureTables();
    final db = await AppDatabase.instance();
    final rows = await db.query('voice_profile', orderBy: 'is_default DESC, created_at DESC');
    return rows.map(VoiceProfile.fromMap).toList();
  }

  Future<VoiceProfile?> getDefaultVoiceProfile() async {
    await ensureTables();
    final db = await AppDatabase.instance();
    final rows = await db.query('voice_profile', where: 'is_default = 1', limit: 1);
    if (rows.isNotEmpty) return VoiceProfile.fromMap(rows.first);
    final all = await listVoiceProfiles();
    return all.isEmpty ? null : all.first;
  }

  Future<VoiceProfile?> getVoiceProfileById(String id) async {
    await ensureTables();
    final db = await AppDatabase.instance();
    final rows = await db.query('voice_profile', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return VoiceProfile.fromMap(rows.first);
  }

  Future<void> upsertVoiceProfile(VoiceProfile profile, {bool makeDefault = false}) async {
    await ensureTables();
    final db = await AppDatabase.instance();
    await db.transaction((txn) async {
      if (makeDefault || profile.isDefault) {
        await txn.update('voice_profile', {'is_default': 0});
      }
      final map = profile.toMap();
      if (makeDefault) map['is_default'] = 1;
      await txn.insert('voice_profile', map, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> setDefaultVoiceProfile(String id) async {
    await ensureTables();
    final db = await AppDatabase.instance();
    await db.transaction((txn) async {
      await txn.update('voice_profile', {'is_default': 0});
      await txn.update('voice_profile', {'is_default': 1, 'updated_at': DateTime.now().millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> deleteVoiceProfile(String id) async {
    await ensureTables();
    final db = await AppDatabase.instance();
    await db.delete('voice_profile', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> insertTtsAudio(TtsAudioFile audio) async {
    await ensureTables();
    final db = await AppDatabase.instance();
    await db.insert('tts_audio_file', audio.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<TtsAudioFile?> findCachedAudio(String textHash, String voiceProfileId) async {
    await ensureTables();
    final db = await AppDatabase.instance();
    final rows = await db.query(
      'tts_audio_file',
      where: 'text_hash = ? AND voice_profile_id = ?',
      whereArgs: [textHash, voiceProfileId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TtsAudioFile.fromMap(rows.first);
  }


  Future<TtsAudioFile?> findCachedAudioByVoiceKey(String textHash, String voiceKey) async {
    await ensureTables();
    final db = await AppDatabase.instance();
    final rows = await db.query(
      'tts_audio_file',
      where: 'text_hash = ? AND (voice_profile_id = ? OR elevenlabs_voice_id = ?)',
      whereArgs: [textHash, voiceKey, voiceKey],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TtsAudioFile.fromMap(rows.first);
  }

  Future<List<TtsAudioFile>> listTtsAudio({String? moduleName}) async {
    await ensureTables();
    final db = await AppDatabase.instance();
    final rows = await db.query(
      'tts_audio_file',
      where: moduleName == null ? null : 'module_name = ?',
      whereArgs: moduleName == null ? null : [moduleName],
      orderBy: 'created_at DESC',
    );
    return rows.map(TtsAudioFile.fromMap).toList();
  }

  Future<void> markAudioDownloaded(String id, String uri, String fileName) async {
    await ensureTables();
    final db = await AppDatabase.instance();
    await db.update(
      'tts_audio_file',
      {
        'is_downloaded': 1,
        'downloaded_uri': uri,
        'downloaded_file_name': fileName,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTtsAudio(String id) async {
    await ensureTables();
    final db = await AppDatabase.instance();
    await db.delete('tts_audio_file', where: 'id = ?', whereArgs: [id]);
  }
}
