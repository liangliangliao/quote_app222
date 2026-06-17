import 'dart:convert';

import '../data/kv_dao.dart';
import '../services/global_ai_settings.dart';
import '../services/unified_ai_service.dart';
import 'consistency_action_prompt_config.dart';

class ConsistencyActionRecord {
  final String id;
  final String scene;
  final String input;
  final String aiText;
  final DateTime createdAt;
  final bool completed;
  final String evidence;
  final String valueName;
  final String identity;
  final String category;
  final String oldExplanation;
  final String newExplanation;
  final int durationMinutes;
  final bool returnedAfterBreak;

  const ConsistencyActionRecord({
    required this.id,
    required this.scene,
    required this.input,
    required this.aiText,
    required this.createdAt,
    this.completed = false,
    this.evidence = '',
    this.valueName = '',
    this.identity = '',
    this.category = '学习证据',
    this.oldExplanation = '我必须有动力才开始',
    this.newExplanation = '我可以在动力不足时完成一个小行动',
    this.durationMinutes = 5,
    this.returnedAfterBreak = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'scene': scene,
        'input': input,
        'aiText': aiText,
        'createdAt': createdAt.toIso8601String(),
        'completed': completed,
        'evidence': evidence,
        'valueName': valueName,
        'identity': identity,
        'category': category,
        'oldExplanation': oldExplanation,
        'newExplanation': newExplanation,
        'durationMinutes': durationMinutes,
        'returnedAfterBreak': returnedAfterBreak,
      };

  factory ConsistencyActionRecord.fromJson(Map<String, dynamic> json) =>
      ConsistencyActionRecord(
        id: (json['id'] ?? '').toString(),
        scene: (json['scene'] ?? 'ca_scene_dollar_action').toString(),
        input: (json['input'] ?? '').toString(),
        aiText: (json['aiText'] ?? '').toString(),
        createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
            DateTime.now(),
        completed: json['completed'] == true,
        evidence: (json['evidence'] ?? '').toString(),
        valueName: (json['valueName'] ?? '').toString(),
        identity: (json['identity'] ?? '').toString(),
        category: (json['category'] ?? '学习证据').toString(),
        oldExplanation:
            (json['oldExplanation'] ?? '我必须有动力才开始').toString(),
        newExplanation:
            (json['newExplanation'] ?? '我可以在动力不足时完成一个小行动').toString(),
        durationMinutes: (json['durationMinutes'] is num)
            ? (json['durationMinutes'] as num).toInt()
            : int.tryParse((json['durationMinutes'] ?? '5').toString()) ?? 5,
        returnedAfterBreak: json['returnedAfterBreak'] == true,
      );

  ConsistencyActionRecord copyWith({
    bool? completed,
    String? evidence,
    String? valueName,
    String? identity,
    String? category,
    String? oldExplanation,
    String? newExplanation,
    int? durationMinutes,
    bool? returnedAfterBreak,
  }) =>
      ConsistencyActionRecord(
        id: id,
        scene: scene,
        input: input,
        aiText: aiText,
        createdAt: createdAt,
        completed: completed ?? this.completed,
        evidence: evidence ?? this.evidence,
        valueName: valueName ?? this.valueName,
        identity: identity ?? this.identity,
        category: category ?? this.category,
        oldExplanation: oldExplanation ?? this.oldExplanation,
        newExplanation: newExplanation ?? this.newExplanation,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        returnedAfterBreak: returnedAfterBreak ?? this.returnedAfterBreak,
      );
}

class ConsistencyActionStats {
  final int total;
  final int completed;
  final int comebackCount;
  final int recentCompleted;
  final Map<String, int> categories;
  final Map<String, int> values;

  const ConsistencyActionStats({
    required this.total,
    required this.completed,
    required this.comebackCount,
    required this.recentCompleted,
    required this.categories,
    required this.values,
  });

  double get completionRate => total == 0 ? 0 : completed / total;
}

class ConsistencyActionService {
  static const String recordsKey = 'consistency_action.records.v2';
  static const String legacyRecordsKey = 'consistency_action.records.v1';
  final KeyValueDao _kv = KeyValueDao();
  final GlobalAiSettings _settings = GlobalAiSettings();
  final UnifiedAiService _ai = UnifiedAiService();

  Future<String> getPrompt(String id) async {
    final fallback = ConsistencyActionPromptConfig.defaults[id] ?? '';
    final saved =
        ((await _kv.getString('consistency_action.prompt.$id')) ?? '').trim();
    return saved.isEmpty ? fallback : saved;
  }

  Future<void> savePrompt(String id, String value) => _kv.setString(
        'consistency_action.prompt.$id',
        value.trim().isEmpty
            ? (ConsistencyActionPromptConfig.defaults[id] ?? '')
            : value.trim(),
      );

  Future<Map<String, String>> inspectPrompt(String id) async {
    final fallback = ConsistencyActionPromptConfig.defaults[id] ?? '';
    final saved =
        ((await _kv.getString('consistency_action.prompt.$id')) ?? '').trim();
    return {
      'value': saved.isEmpty ? fallback : saved,
      'sourceLabel': saved.isEmpty ? '内置默认 Prompt' : '本地已保存 Prompt',
      'note': saved.isEmpty
          ? '当前没有本地模板，实际使用内置默认模板。'
          : '当前实际使用的是设置页保存的本地模板。',
    };
  }

  Future<String> generate({
    required String scenePromptId,
    required String input,
    String valueName = '',
    String evidenceJson = '',
  }) async {
    final state = await _settings.getState();
    final prompt = '${await getPrompt(scenePromptId)}\n\n'
        '用户输入：\n$input\n\n'
        '用户选择的核心价值：$valueName\n\n'
        '历史行动证据：\n$evidenceJson\n\n'
        '${await getPrompt('ca_output_common')}';
    if (state['available'] == '1') {
      final text = await _ai.generateText(
        prompt: prompt,
        systemPrompt: await getPrompt('ca_global'),
        purpose: 'consistency_action.$scenePromptId',
        maxTokens: 2600,
        temperature: 0.7,
      );
      if (text.trim().isNotEmpty) return text.trim();
    }
    return fallbackOutput(input: input, valueName: valueName);
  }

  String fallbackOutput({required String input, String valueName = ''}) {
    final value = valueName.trim().isEmpty ? '成长 / 自主选择' : valueName.trim();
    return '【一、你现在的核心冲突】\n你在乎“$value”，也希望靠近“$input”，但当前行为还没有稳定给你足够证据。真正的冲突不是你这个人不行，而是价值、行为和自我解释之间暂时没有对齐。\n\n'
        '【二、这不是失败，而是一个改变入口】\n认知失调说明你仍然在乎某个方向。我们不靠羞耻或强奖励推动，而是用一个小到可以开始、真实到无法否认的行动制造新证据。\n\n'
        '【三、你的1美元行动】\n现在把“$input”缩小成第一步：打开相关页面、书本或工具，只做3分钟，并写下一句“我愿意给这件事一个机会”。如果3分钟都困难，就只做30秒。\n\n'
        '【四、行动前承诺语】\n我现在不是为了证明自己彻底改变，而是为了给自己一个新的证据：我可以先开始一点点。\n\n'
        '【五、行动中提醒语】\n先完成动作，完成后再评价。\n\n'
        '【六、行动后解释】\n这次行动虽然很小，但它说明我不是完全不能开始。它打破了“必须有动力才行动”的旧解释。它支持我成为一个能用小行动靠近价值的人。\n\n'
        '【七、下一步】\n明天重复同一个动作，或只增加1分钟。\n\n'
        '【八、风险提醒】\n不要用“太小了没用”否定它；它不能证明你已经彻底改变，但它是真实证据。';
  }

  Future<List<ConsistencyActionRecord>> records() async {
    var raw = ((await _kv.getString(recordsKey)) ?? '').trim();
    raw = raw.isEmpty ? ((await _kv.getString(legacyRecordsKey)) ?? '') : raw;
    if (raw.trim().isEmpty) return <ConsistencyActionRecord>[];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<Map>()
          .map((e) =>
              ConsistencyActionRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return <ConsistencyActionRecord>[];
    }
  }

  Future<void> saveRecord(ConsistencyActionRecord record) async {
    final list = await records();
    await _kv.setString(
      recordsKey,
      jsonEncode(
        [record, ...list.where((e) => e.id != record.id)]
            .take(160)
            .map((e) => e.toJson())
            .toList(),
      ),
    );
  }

  Future<String> evidenceJson({int limit = 20}) async {
    final list = await records();
    return jsonEncode(list.take(limit).map((e) => e.toJson()).toList());
  }

  ConsistencyActionStats stats(List<ConsistencyActionRecord> list) {
    final now = DateTime.now();
    final recentStart = now.subtract(const Duration(days: 14));
    final categories = <String, int>{};
    final values = <String, int>{};
    var completed = 0;
    var comeback = 0;
    var recentCompleted = 0;
    for (final r in list) {
      if (!r.completed) continue;
      completed += 1;
      if (r.returnedAfterBreak) comeback += 1;
      if (r.createdAt.isAfter(recentStart)) recentCompleted += 1;
      categories[r.category] = (categories[r.category] ?? 0) + 1;
      final value = r.valueName.trim().isEmpty ? '未标注价值' : r.valueName.trim();
      values[value] = (values[value] ?? 0) + 1;
    }
    return ConsistencyActionStats(
      total: list.length,
      completed: completed,
      comebackCount: comeback,
      recentCompleted: recentCompleted,
      categories: categories,
      values: values,
    );
  }

  String buildConsistencyReport(List<ConsistencyActionRecord> list) {
    final s = stats(list);
    final topCategory = _top(s.categories, '暂无证据分类');
    final topValue = _top(s.values, '暂无价值标签');
    final latest = list.where((e) => e.completed).take(3).toList();
    final evidence = latest.isEmpty
        ? '本周还没有完成证据。建议把行动降到30秒，优先制造第一张证据卡。'
        : latest.map((e) => '• ${e.evidence.isEmpty ? e.input : e.evidence}').join('\n');
    return '【本周最重要的行动证据】\n$evidence\n\n'
        '【本周最大的认知失调点】\n你可能仍在“我重视$topValue”与“行动入口不够小/不够具体”之间摇摆。\n\n'
        '【本周最常见的逃避解释】\n常见解释是“必须有动力、状态好、时间完整才开始”。系统建议继续把行动降到5分钟内可启动。\n\n'
        '【本周最有效的1美元行动】\n最有效证据类型：$topCategory。继续选择一个小到不能拒绝、但完成后能说明身份方向的动作。\n\n'
        '【下周建议强化的身份方向】\n成为一个不靠完美连续定义自己，而是能中断后回来、用真实证据靠近价值的人。';
  }

  String _top(Map<String, int> map, String fallback) {
    if (map.isEmpty) return fallback;
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }
}
