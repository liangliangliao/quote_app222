import 'dart:async';
import 'package:sqflite/sqflite.dart';

class QuoteKnowledgeEvents {
  static final _changes = StreamController<void>.broadcast();
  static Stream<void> get changes => _changes.stream;
  static void notify() => _changes.add(null);
}

class QuoteKnowledgeSchema {
  static const quoteKey =
      "CASE WHEN trim(COALESCE(quote_uid,''))<>'' THEN trim(quote_uid) ELSE 'legacy:'||id END";
  static const newKey =
      "CASE WHEN trim(COALESCE(NEW.quote_uid,''))<>'' THEN trim(NEW.quote_uid) ELSE 'legacy:'||NEW.id END";
  static const oldKey =
      "CASE WHEN trim(COALESCE(OLD.quote_uid,''))<>'' THEN trim(OLD.quote_uid) ELSE 'legacy:'||OLD.id END";

  /// Physical reorder replaces row IDs. Give pre-UID records a stable identity
  /// and migrate their index keys before that operation drops the source table.
  static Future<void> preserveLegacyIdentity(DatabaseExecutor db) async {
    await db.execute('DROP TRIGGER IF EXISTS qk_quote_update');
    final rows = await db.query('quotes',
        columns: ['id'], where: "trim(COALESCE(quote_uid,''))=''");
    for (final row in rows) {
      final oldKey = 'legacy:${row['id']}';
      var uid = 'qk_legacy_${row['id']}';
      while ((await db.query('quotes',
              columns: ['id'], where: 'quote_uid=?', whereArgs: [uid]))
          .isNotEmpty) {
        uid = '${uid}_';
      }
      await db.update('quotes', {'quote_uid': uid},
          where: 'id=?', whereArgs: [row['id']]);
      for (final table in [
        'qk_jobs',
        'qk_memberships',
        'qk_relation_evidence'
      ]) {
        await db.update(table, {'quote_key': uid},
            where: 'quote_key=?', whereArgs: [oldKey]);
      }
    }
    await ensure(db);
  }

  static Future<void> ensure(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS qk_categories (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, name_key TEXT NOT NULL, definition TEXT NOT NULL,
      parent_id TEXT NOT NULL DEFAULT '', origin TEXT NOT NULL, created_ms INTEGER NOT NULL,
      UNIQUE(parent_id,name_key))''');
    await db.execute('''CREATE TABLE IF NOT EXISTS qk_aliases (
      category_id TEXT NOT NULL REFERENCES qk_categories(id) ON DELETE CASCADE,
      parent_id TEXT NOT NULL, alias_key TEXT NOT NULL,
      PRIMARY KEY(parent_id,alias_key))''');
    await db.execute('''CREATE TABLE IF NOT EXISTS qk_jobs (
      quote_key TEXT PRIMARY KEY, status TEXT NOT NULL, origin TEXT NOT NULL,
      input_hash TEXT NOT NULL DEFAULT '', token TEXT NOT NULL DEFAULT '', attempts INTEGER NOT NULL DEFAULT 0,
      next_ms INTEGER NOT NULL DEFAULT 0, lease_ms INTEGER NOT NULL DEFAULT 0,
      last_error TEXT NOT NULL DEFAULT '', method TEXT NOT NULL DEFAULT '', review_reason TEXT NOT NULL DEFAULT '')''');
    await db.execute('''CREATE TABLE IF NOT EXISTS qk_memberships (
      quote_key TEXT NOT NULL, category_id TEXT NOT NULL REFERENCES qk_categories(id) ON DELETE CASCADE,
      reason TEXT NOT NULL, evidence TEXT NOT NULL, status TEXT NOT NULL,
      PRIMARY KEY(quote_key,category_id))''');
    await db.execute('''CREATE TABLE IF NOT EXISTS qk_relations (
      id TEXT PRIMARY KEY, from_id TEXT NOT NULL REFERENCES qk_categories(id) ON DELETE CASCADE,
      to_id TEXT NOT NULL REFERENCES qk_categories(id) ON DELETE CASCADE, kind TEXT NOT NULL,
      UNIQUE(from_id,to_id,kind))''');
    await db.execute('''CREATE TABLE IF NOT EXISTS qk_relation_evidence (
      relation_id TEXT NOT NULL REFERENCES qk_relations(id) ON DELETE CASCADE,
      quote_key TEXT NOT NULL, excerpt TEXT NOT NULL, reason TEXT NOT NULL,
      PRIMARY KEY(relation_id,quote_key))''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS qk_jobs_due ON qk_jobs(status,next_ms)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS qk_category_parent ON qk_categories(parent_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS qk_members_category ON qk_memberships(category_id,quote_key)');
    await db.execute(
        '''CREATE TRIGGER IF NOT EXISTS qk_quote_insert AFTER INSERT ON quotes BEGIN
      DELETE FROM qk_memberships WHERE quote_key=$newKey;
      DELETE FROM qk_relation_evidence WHERE quote_key=$newKey;
      INSERT OR REPLACE INTO qk_jobs(quote_key,status,origin) VALUES($newKey,'pending','new');
    END''');
    await db.execute(
        '''CREATE TRIGGER IF NOT EXISTS qk_quote_update AFTER UPDATE OF content,theme,explanation,quote_uid,id ON quotes
      WHEN COALESCE(OLD.content,'')<>COALESCE(NEW.content,'') OR COALESCE(OLD.theme,'')<>COALESCE(NEW.theme,'')
       OR COALESCE(OLD.explanation,'')<>COALESCE(NEW.explanation,'') OR $oldKey<>$newKey
      BEGIN
        DELETE FROM qk_memberships WHERE quote_key=$oldKey;
        DELETE FROM qk_relation_evidence WHERE quote_key=$oldKey;
        DELETE FROM qk_jobs WHERE quote_key=$oldKey;
        INSERT OR REPLACE INTO qk_jobs(quote_key,status,origin) VALUES($newKey,'pending','new');
      END''');
    await db.execute(
        '''CREATE TRIGGER IF NOT EXISTS qk_quote_delete AFTER DELETE ON quotes BEGIN
      DELETE FROM qk_memberships WHERE quote_key=$oldKey;
      DELETE FROM qk_relation_evidence WHERE quote_key=$oldKey;
      DELETE FROM qk_jobs WHERE quote_key=$oldKey;
    END''');
  }
}
