import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/quote_insight.dart';
import 'cognitive_store.dart';
import 'package:sqflite/sqflite.dart';

enum CognitiveStyle { intuitive, conceptual, comparative }

class CognitivePreferences {
  final CognitiveStyle style;
  final bool relations,
      prompts,
      grounds,
      evidenceReminders,
      reduceMotion,
      usageEnabled,
      enabled;
  const CognitivePreferences(
      {this.style = CognitiveStyle.intuitive,
      this.relations = true,
      this.prompts = true,
      this.grounds = true,
      this.evidenceReminders = true,
      this.reduceMotion = false,
      this.usageEnabled = false,
      this.enabled = false});
  factory CognitivePreferences.fromJson(dynamic value) {
    final m = insightObject(value);
    return CognitivePreferences(
        style: CognitiveStyle.values.firstWhere((e) => e.name == m['style'],
            orElse: () => CognitiveStyle.intuitive),
        relations: m['relations'] != false,
        prompts: m['prompts'] != false,
        grounds: m['grounds'] != false,
        evidenceReminders: m['evidence_reminders'] != false,
        reduceMotion: m['reduce_motion'] == true,
        usageEnabled: m['usage_enabled'] == true,
        enabled: m['enabled'] == true);
  }
  Map<String, dynamic> toJson() => {
        'style': style.name,
        'relations': relations,
        'prompts': prompts,
        'grounds': grounds,
        'evidence_reminders': evidenceReminders,
        'reduce_motion': reduceMotion,
        'usage_enabled': usageEnabled,
        'enabled': enabled
      };
  CognitivePreferences change(String key, Object value) =>
      CognitivePreferences.fromJson({...toJson(), key: value});
}

class CognitivePreferenceStore extends ValueNotifier<CognitivePreferences> {
  CognitivePreferenceStore({CognitiveStore? store})
      : _store = store ?? CognitiveStore(),
        super(const CognitivePreferences());
  static final instance = CognitivePreferenceStore();
  static const enabledInBuild =
      bool.fromEnvironment('COGNITIVE_EXPERIENCES', defaultValue: true);
  static bool get active => enabledInBuild && instance.value.enabled;
  final CognitiveStore _store;
  Future<void>? _loading;
  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    try {
      final db = await _store.database;
      final rows = await db.query('app_kv',
          where: 'key=?', whereArgs: ['cognition.preferences']);
      if (rows.isNotEmpty)
        value = CognitivePreferences.fromJson(rows.first['value']);
    } catch (_) {
      _loading = null;
    }
  }

  Future<void> update(CognitivePreferences next) async {
    await load();
    final db = await _store.database;
    await db.insert('app_kv',
        {'key': 'cognition.preferences', 'value': jsonEncode(next.toJson())},
        conflictAlgorithm: ConflictAlgorithm.replace);
    value = next;
  }
}
