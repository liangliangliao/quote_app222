import 'dart:convert';

import '../cognitive_consistency/cognitive_consistency_models.dart';
import '../data/kv_dao.dart';

/// Prompt configuration for the NewTablets module.
///
/// This class intentionally mirrors the other prompt-config modules so the
/// unified AI prompt settings page can compile and manage any `nt_` prompt IDs
/// that are registered by this feature branch.
class NewTabletsPromptConfig {
  static const String moduleId = 'new_tablets';
  static const String moduleName = 'NewTablets';

  static const String globalId = 'nt_global';
  static const String sceneGeneralId = 'nt_scene_general';
  static const String outputCommonId = 'nt_output_common';

  static const List<String> allIds = <String>[
    globalId,
    sceneGeneralId,
    outputCommonId,
  ];

  static const Map<String, String> labels = <String, String>{
    globalId: '全局价值层 Prompt',
    sceneGeneralId: '通用场景层 Prompt',
    outputCommonId: '输出格式 Prompt',
  };

  static const Map<String, String> _defaults = <String, String>{
    globalId: '你是 NewTablets 模块的 AI 助手。请基于用户输入提供清晰、可执行、结构化的帮助。',
    sceneGeneralId: '当前场景：{{scene}}。用户输入：{{user_input}}。请结合上下文 {{context_json}} 进行分析。',
    outputCommonId: '请输出：1. 关键理解；2. 可执行建议；3. 下一步行动；4. 复盘问题。',
  };

  final KeyValueDao _kv = KeyValueDao();

  static String _key(String id) => 'ai_prompt.$moduleId.$id';
  String _backupPrefix(String id) => 'backup_${_key(id)}_';

  List<String> allPromptIds() => allIds;

  String defaultFor(String id) => _defaults[id] ?? '';

  Future<String> getPrompt(String id, [String? fallback]) async {
    final saved = ((await _kv.getString(_key(id))) ?? '').trim();
    if (saved.isNotEmpty) return saved;
    return fallback ?? defaultFor(id);
  }

  Future<void> savePrompt(String id, String value) async {
    await _backupCurrent(id);
    await _kv.setString(_key(id), value.trim());
  }

  Future<void> clearPromptOverride(String id) async {
    await _backupCurrent(id);
    await _kv.setString(_key(id), '');
  }

  Future<Map<String, String>> inspectPrompt(String id) async {
    final saved = ((await _kv.getString(_key(id))) ?? '').trim();
    return <String, String>{
      'value': saved.isEmpty ? defaultFor(id) : saved,
      'source': saved.isEmpty ? 'default_builtin' : 'local_saved',
      'sourceLabel': saved.isEmpty ? '内置默认 Prompt' : '本地已保存 Prompt',
      'note': saved.isEmpty
          ? '当前使用 NewTablets 内置 Prompt。'
          : '当前实际使用设置页保存的 NewTablets Prompt，下一次本模块 AI 调用立即生效。',
    };
  }

  List<String> missingRequiredPlaceholders(String id, String template) =>
      const <String>[];

  Future<List<CcPromptBackupRecord>> listBackups(String id) async {
    final rows = await _kv.keyValuesWithPrefix(_backupPrefix(id));
    return rows.map((e) {
      final key = e['key'] ?? '';
      final suffix = key.replaceFirst(_backupPrefix(id), '');
      final ms = int.tryParse(suffix) ?? 0;
      final dt = ms > 0 ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
      final label = dt == null
          ? key
          : '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      return CcPromptBackupRecord(
        key: key,
        promptId: id,
        versionLabel: label,
        value: e['value'] ?? '',
      );
    }).toList(growable: false);
  }

  Future<void> restoreBackup(String id, String backupKey) async {
    final rows = await _kv.keyValuesWithPrefix(backupKey);
    final match = rows
        .where((e) => (e['key'] ?? '') == backupKey)
        .toList(growable: false);
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

  String render(String template, Map<String, String> values) {
    var result = template;
    for (final entry in values.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }
    return result;
  }

  Future<void> _backupCurrent(String id) async {
    final current = ((await _kv.getString(_key(id))) ?? '').trim();
    if (current.isEmpty) return;
    await _kv.setString(
      '${_backupPrefix(id)}${DateTime.now().millisecondsSinceEpoch}',
      current,
    );
  }
}
