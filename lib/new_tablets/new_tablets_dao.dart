import 'dart:convert';

import '../data/kv_dao.dart';

class NewTabletsDao {
  static const String _prefix = 'new_tablets.state.';
  static const String _oldKey = '${_prefix}old_tablets';
  static const String _newKey = '${_prefix}new_tablets';
  static const String _commitmentKey = '${_prefix}commitments';
  static const String _rewriteKey = '${_prefix}rewrites';
  static const String _dailyKey = '${_prefix}daily_commands';
  static const String _outputKey = '${_prefix}creative_outputs';

  final KeyValueDao _kv = KeyValueDao();

  Future<List<OldTablet>> loadOldTablets() async => _decodeList(await _kv.getString(_oldKey), OldTablet.fromJson);
  Future<void> saveOldTablets(List<OldTablet> items) => _saveList(_oldKey, items.map((e) => e.toJson()).toList());

  Future<List<NewTablet>> loadNewTablets() async => _decodeList(await _kv.getString(_newKey), NewTablet.fromJson);
  Future<void> saveNewTablets(List<NewTablet> items) => _saveList(_newKey, items.map((e) => e.toJson()).toList());

  Future<List<SovereignCommitment>> loadCommitments() async => _decodeList(await _kv.getString(_commitmentKey), SovereignCommitment.fromJson);
  Future<void> saveCommitments(List<SovereignCommitment> items) => _saveList(_commitmentKey, items.map((e) => e.toJson()).toList());

  Future<List<BadConscienceRewrite>> loadRewrites() async => _decodeList(await _kv.getString(_rewriteKey), BadConscienceRewrite.fromJson);
  Future<void> saveRewrites(List<BadConscienceRewrite> items) => _saveList(_rewriteKey, items.map((e) => e.toJson()).toList());

  Future<List<DailyCommandRecord>> loadDailyCommands() async => _decodeList(await _kv.getString(_dailyKey), DailyCommandRecord.fromJson);
  Future<void> saveDailyCommands(List<DailyCommandRecord> items) => _saveList(_dailyKey, items.map((e) => e.toJson()).toList());

  Future<List<CreativeOutputRecord>> loadCreativeOutputs() async => _decodeList(await _kv.getString(_outputKey), CreativeOutputRecord.fromJson);
  Future<void> saveCreativeOutputs(List<CreativeOutputRecord> items) => _saveList(_outputKey, items.map((e) => e.toJson()).toList());

  Future<NewTabletsState> loadState() async => NewTabletsState(
    oldTablets: await loadOldTablets(),
    newTablets: await loadNewTablets(),
    commitments: await loadCommitments(),
    rewrites: await loadRewrites(),
    dailyCommands: await loadDailyCommands(),
    creativeOutputs: await loadCreativeOutputs(),
  );

  Future<void> _saveList(String key, List<Map<String, dynamic>> list) => _kv.setString(key, jsonEncode(list));

  List<T> _decodeList<T>(String? raw, T Function(Map<String, dynamic>) fromJson) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return <T>[];
    final decoded = jsonDecode(text);
    if (decoded is! List) return <T>[];
    return decoded.whereType<Map>().map((e) => fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
  }
}

class NewTabletsState {
  final List<OldTablet> oldTablets;
  final List<NewTablet> newTablets;
  final List<SovereignCommitment> commitments;
  final List<BadConscienceRewrite> rewrites;
  final List<DailyCommandRecord> dailyCommands;
  final List<CreativeOutputRecord> creativeOutputs;

  const NewTabletsState({
    required this.oldTablets,
    required this.newTablets,
    required this.commitments,
    required this.rewrites,
    required this.dailyCommands,
    required this.creativeOutputs,
  });
}

class OldTablet {
  final String value;
  final String source;
  final String impact;
  final String status;
  const OldTablet(this.value, this.source, this.impact, this.status);
  Map<String, dynamic> toJson() => {'value': value, 'source': source, 'impact': impact, 'status': status};
  factory OldTablet.fromJson(Map<String, dynamic> json) => OldTablet((json['value'] ?? '').toString(), (json['source'] ?? '').toString(), (json['impact'] ?? '').toString(), (json['status'] ?? '').toString());
}

class NewTablet {
  final String value;
  final String proof;
  final String status;
  const NewTablet(this.value, this.proof, this.status);
  Map<String, dynamic> toJson() => {'value': value, 'proof': proof, 'status': status};
  factory NewTablet.fromJson(Map<String, dynamic> json) => NewTablet((json['value'] ?? '').toString(), (json['proof'] ?? '').toString(), (json['status'] ?? '').toString());
}

class SovereignCommitment {
  final String title;
  final String period;
  final double rate;
  final int repairs;
  const SovereignCommitment(this.title, this.period, this.rate, this.repairs);
  Map<String, dynamic> toJson() => {'title': title, 'period': period, 'rate': rate, 'repairs': repairs};
  factory SovereignCommitment.fromJson(Map<String, dynamic> json) => SovereignCommitment(
    (json['title'] ?? '').toString(),
    (json['period'] ?? '').toString(),
    (json['rate'] is num) ? (json['rate'] as num).toDouble() : double.tryParse((json['rate'] ?? '').toString()) ?? 0,
    (json['repairs'] is num) ? (json['repairs'] as num).toInt() : int.tryParse((json['repairs'] ?? '').toString()) ?? 0,
  );
  SovereignCommitment recordResult({required bool completed}) {
    final nextRate = (completed ? ((rate * 0.8) + 0.2).clamp(0.0, 1.0) : (rate * 0.8).clamp(0.0, 1.0)).toDouble();
    return SovereignCommitment(title, period, nextRate, completed ? repairs : repairs + 1);
  }
}

class BadConscienceRewrite {
  final String bad;
  final String rewrite;
  const BadConscienceRewrite(this.bad, this.rewrite);
  Map<String, dynamic> toJson() => {'bad': bad, 'rewrite': rewrite};
  factory BadConscienceRewrite.fromJson(Map<String, dynamic> json) => BadConscienceRewrite((json['bad'] ?? '').toString(), (json['rewrite'] ?? '').toString());
}

class DailyCommandRecord {
  final int createdAtMs;
  final String ruler;
  final String oldSelf;
  final String command;
  final String minAction;
  final bool completed;
  const DailyCommandRecord({required this.createdAtMs, required this.ruler, required this.oldSelf, required this.command, required this.minAction, this.completed = false});
  Map<String, dynamic> toJson() => {'createdAtMs': createdAtMs, 'ruler': ruler, 'oldSelf': oldSelf, 'command': command, 'minAction': minAction, 'completed': completed};
  factory DailyCommandRecord.fromJson(Map<String, dynamic> json) => DailyCommandRecord(
    createdAtMs: (json['createdAtMs'] is num) ? (json['createdAtMs'] as num).toInt() : int.tryParse((json['createdAtMs'] ?? '').toString()) ?? 0,
    ruler: (json['ruler'] ?? '').toString(),
    oldSelf: (json['oldSelf'] ?? '').toString(),
    command: (json['command'] ?? '').toString(),
    minAction: (json['minAction'] ?? '').toString(),
    completed: json['completed'] == true,
  );
  DailyCommandRecord copyWith({bool? completed}) => DailyCommandRecord(createdAtMs: createdAtMs, ruler: ruler, oldSelf: oldSelf, command: command, minAction: minAction, completed: completed ?? this.completed);
}

class CreativeOutputRecord {
  final int createdAtMs;
  final String type;
  final String title;
  final String linkedNewTablet;
  const CreativeOutputRecord({required this.createdAtMs, required this.type, required this.title, required this.linkedNewTablet});
  Map<String, dynamic> toJson() => {'createdAtMs': createdAtMs, 'type': type, 'title': title, 'linkedNewTablet': linkedNewTablet};
  factory CreativeOutputRecord.fromJson(Map<String, dynamic> json) => CreativeOutputRecord(
    createdAtMs: (json['createdAtMs'] is num) ? (json['createdAtMs'] as num).toInt() : int.tryParse((json['createdAtMs'] ?? '').toString()) ?? 0,
    type: (json['type'] ?? '').toString(),
    title: (json['title'] ?? '').toString(),
    linkedNewTablet: (json['linkedNewTablet'] ?? '').toString(),
  );
}
