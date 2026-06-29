import 'dart:convert';

import '../cognitive_consistency/cognitive_consistency_models.dart';
import '../data/kv_dao.dart';

/// 自我价值模块 Prompt 配置兼容层。
///
/// 构建日志中已有 ai_prompt_settings_page.dart 对 SelfWorthAiPromptConfig
/// 和 _swPrompts 的引用；本类补齐统一配置中心所需的 API，避免设置页引用
/// 未定义符号导致 release 构建失败。
class SelfWorthAiPromptConfig {
  static const String moduleId = 'self_worth';
  static const String globalId = 'sw_global_value';
  static const String sceneSelfWorthRepairId = 'sw_scene_self_worth_repair';
  static const String sceneComparisonId = 'sw_scene_comparison';
  static const String sceneFailureId = 'sw_scene_failure';
  static const String outputCommonId = 'sw_output_common';

  static const List<String> allIds = <String>[
    globalId,
    sceneSelfWorthRepairId,
    sceneComparisonId,
    sceneFailureId,
    outputCommonId,
  ];

  static const Map<String, String> labels = <String, String>{
    globalId: '全局价值层 Prompt',
    sceneSelfWorthRepairId: '场景：自我价值修复',
    sceneComparisonId: '场景：比较与自我否定',
    sceneFailureId: '场景：失败后的自我价值稳定',
    outputCommonId: '输出格式：自我价值行动卡',
  };

  final KeyValueDao _kv = KeyValueDao();
  static String _key(String id) => 'ai_prompt.$moduleId.$id';
  String _backupPrefix(String id) => 'backup_${_key(id)}_';

  static const String globalPrompt = '你是自我价值修复教练。帮助用户把自我价值从外部评价、比较、成败和讨好中松绑，回到尊严、真实能力证据、边界与可执行行动。不要用鸡血或羞辱推动用户。';
  static const String sceneRepairPrompt = '用户正在表达自我价值受损、自我否定或“不配”。请区分事实、评价、旧脚本和可恢复行动，输出一个温和但具体的小行动。';
  static const String sceneComparisonPrompt = '用户正在被比较、排名、同龄人焦虑影响。请识别外部评价命令，将比较降级为信息，并恢复自主价值尺度。';
  static const String sceneFailurePrompt = '用户因失败而否定自我价值。请把失败转化为学习材料、责任修复和下一步可兑现行动。';
  static const String outputCommonPrompt = '请输出：状态诊断、价值受损来源、事实/评价区分、稳定自我价值的证据、今日最小行动、复盘问题。';

  String defaultFor(String id) => defaultPrompt(id);
  List<String> allPromptIds() => allIds;
  List<String> requiredPlaceholders(String id) => const <String>[];
  List<String> missingRequiredPlaceholders(String id, String value) => const <String>[];

  static String defaultPrompt(String id) {
    switch (id) {
      case globalId:
        return globalPrompt;
      case sceneComparisonId:
        return sceneComparisonPrompt;
      case sceneFailureId:
        return sceneFailurePrompt;
      case outputCommonId:
        return outputCommonPrompt;
      case sceneSelfWorthRepairId:
      default:
        return sceneRepairPrompt;
    }
  }

  Future<void> _backupCurrent(String id) async {
    final current = ((await _kv.getString(_key(id))) ?? '').trim();
    if (current.isEmpty) return;
    await _kv.setString('${_backupPrefix(id)}${DateTime.now().toIso8601String()}', current);
  }

  Future<List<CcPromptBackupRecord>> listBackups(String id) async {
    final prefix = _backupPrefix(id);
    final rows = await _kv.keyValuesWithPrefix(prefix);
    return rows.map((row) => CcPromptBackupRecord(
      key: row['key'] ?? '',
      promptId: id,
      versionLabel: (row['key'] ?? '').startsWith(prefix) ? (row['key'] ?? '').substring(prefix.length) : (row['key'] ?? ''),
      value: row['value'] ?? '',
    )).where((e) => e.value.trim().isNotEmpty).toList(growable: false);
  }

  Future<void> restoreBackup(String id, String backupKey) async {
    final rows = await _kv.keyValuesWithPrefix(backupKey);
    final match = rows.where((e) => (e['key'] ?? '') == backupKey).toList(growable: false);
    if (match.isEmpty) return;
    await _backupCurrent(id);
    await _kv.setString(_key(id), match.first['value'] ?? '');
  }

  Future<void> clearPromptOverride(String id) async {
    await _backupCurrent(id);
    await _kv.setString(_key(id), '');
  }

  Future<String> getPrompt(String id) async {
    final saved = ((await _kv.getString(_key(id))) ?? '').trim();
    return saved.isEmpty ? defaultPrompt(id) : saved;
  }

  Future<void> savePrompt(String id, String value) async {
    await _backupCurrent(id);
    await _kv.setString(_key(id), value.trim());
  }

  Future<Map<String, String>> inspectPrompt(String id) async {
    final saved = ((await _kv.getString(_key(id))) ?? '').trim();
    return <String, String>{
      'value': saved.isEmpty ? defaultPrompt(id) : saved,
      'source': saved.isEmpty ? 'default_builtin' : 'local_saved',
      'sourceLabel': saved.isEmpty ? '内置默认 Prompt' : '本地已保存 Prompt',
      'note': saved.isEmpty ? '当前使用自我价值模块默认 Prompt。' : '当前使用设置页保存的自我价值 Prompt。',
    };
  }

  Future<String> exportPromptsJson() async {
    final prompts = <String, dynamic>{};
    for (final id in allIds) {
      final saved = ((await _kv.getString(_key(id))) ?? '').trim();
      if (saved.isNotEmpty) prompts[id] = saved;
    }
    return jsonEncode(<String, dynamic>{'module': moduleId, 'schema_version': 1, 'prompts': prompts});
  }

  Future<int> importPromptsJson(String raw) async {
    final decoded = jsonDecode(raw);
    if (decoded is! Map || decoded['prompts'] is! Map) return 0;
    var count = 0;
    for (final entry in (decoded['prompts'] as Map).entries) {
      final id = entry.key.toString();
      if (!allIds.contains(id)) continue;
      await savePrompt(id, entry.value.toString());
      count += 1;
    }
    return count;
  }

  String render(String template, Map<String, String> values) {
    var out = template;
    values.forEach((key, value) => out = out.replaceAll('{{$key}}', value));
    return out;
  }
}
