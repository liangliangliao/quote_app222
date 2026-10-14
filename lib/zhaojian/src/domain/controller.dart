import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../data/models.dart';
import '../data/zhaojian_dao.dart';
import '../data/zhaojian_schema.dart';
import '../zhaojian_oracle.dart';
import 'analysis.dart';

/// 模块的状态与业务动作。界面只读这里的列表，写都走这里。
class ZhaojianController extends ChangeNotifier {
  ZhaojianController({required Database db, required this.oracle})
      : dao = ZhaojianDao(db);

  final ZhaojianDao dao;
  final ZhaojianOracle oracle;

  List<ZDecision> decisions = <ZDecision>[];
  List<ZLog> logs = <ZLog>[];
  List<ZHypothesis> hypotheses = <ZHypothesis>[];
  List<ZMiss> misses = <ZMiss>[];
  final Map<String, List<ZEntry>> _items = <String, List<ZEntry>>{};
  Map<String, String> _kv = <String, String>{};
  bool loaded = false;

  /// 某一类通用条目（按创建时间从早到晚）。
  List<ZEntry> items(String kind) => _items[kind] ?? const <ZEntry>[];

  /// 键值（自评的长处短处、选定的线、自述线索等）。
  String kv(String key, [String fallback = '']) => _kv[key] ?? fallback;

  /// 行为证据的条数：行为记录、已开牌的决定、行为考古、他人观察、回望、有结果的绳子。
  int get evidenceCount =>
      logs.length +
      revealed.length +
      items('arch').length +
      items('obs').length +
      items('reg').length +
      items('rope').where((ZEntry r) => r.s('ok').isNotEmpty).length;

  List<ZDecision> get pending =>
      decisions.where((ZDecision d) => !d.revealed).toList().reversed.toList();

  List<ZDecision> get revealed =>
      decisions.where((ZDecision d) => d.revealed).toList();

  /// 用户常漏的动机类别，给 AI 补全和前 5 推荐当提示。
  Set<int> get missCats => topMissCategories(misses);

  Future<void> load() async {
    decisions = await dao.allDecisions();
    logs = await dao.allLogs();
    hypotheses = await dao.allHypotheses();
    misses = await dao.allMisses();
    _items.clear();
    for (final ZEntry it in await dao.allItems()) {
      _items.putIfAbsent(it.kind, () => <ZEntry>[]).add(it);
    }
    _kv = await dao.allKv();
    loaded = true;
    notifyListeners();
  }

  /// 封存一次预测。
  Future<int> seal(ZDecision d) async {
    final int id = await dao.insertDecision(d);
    await load();
    return id;
  }

  Future<void> deleteDecision(int id) async {
    await dao.deleteDecision(id);
    await load();
  }

  /// 开牌：写入实际结果、反应、身体信号，同时记一条行为记录，
  /// 并把「这次表达/背离了哪条主线」计入对应假设。
  Future<ZDecision?> reveal({
    required int decisionId,
    required String actual,
    required String reaction,
    int? jtActual,
    List<String> body = const <String>[],
    int? hypId,
    String? hypKind,
  }) async {
    final ZDecision? d = await dao.findDecision(decisionId);
    if (d == null || d.revealed) return d;
    d.actual = actual;
    d.actualAt = DateTime.now();
    d.reaction = reaction;
    d.jtActual = jtActual;
    d.body = List<String>.from(body);
    d.hypId = hypId;
    d.hypKind = hypId == null ? null : (hypKind ?? 'sup');
    await dao.updateDecision(d);
    final String chosen = actual == 'a' ? d.optionA : d.optionB;
    await dao.insertLog(ZLog(
      what: '决定：$chosen',
      reaction: reaction,
      deliberate: d.motives.isNotEmpty ? '思虑过' : '',
      body: d.body,
      hypId: d.hypId,
      hypKind: d.hypKind,
      createdAt: DateTime.now(),
    ));
    if (hypId != null) {
      await _bumpHypothesis(hypId, d.hypKind ?? 'sup');
    }
    await load();
    return d;
  }

  Future<void> markMissLogged(int decisionId) async {
    final ZDecision? d = await dao.findDecision(decisionId);
    if (d == null) return;
    d.missLogged = true;
    await dao.updateDecision(d);
    await load();
  }

  Future<void> addMiss({
    required int cat,
    required String text,
    int? decisionId,
  }) async {
    await dao.insertMiss(ZMiss(
      cat: cat,
      text: text,
      decisionId: decisionId,
      createdAt: DateTime.now(),
    ));
    if (decisionId != null) {
      await markMissLogged(decisionId);
    } else {
      await load();
    }
  }

  Future<void> addLog(ZLog l) async {
    await dao.insertLog(l);
    if (l.hypId != null) {
      await _bumpHypothesis(l.hypId!, l.hypKind ?? 'sup');
    }
    await load();
  }

  Future<void> deleteLog(int id) async {
    await dao.deleteLog(id);
    await load();
  }

  Future<int> addHypothesis(String text, String test) async {
    final int id = await dao.insertHypothesis(ZHypothesis(
      text: text,
      test: test,
      createdAt: DateTime.now(),
    ));
    await load();
    return id;
  }

  Future<void> bumpHypothesis(int id, String kind) async {
    await _bumpHypothesis(id, kind);
    await load();
  }

  Future<void> deleteHypothesis(int id) async {
    await dao.deleteHypothesis(id);
    await load();
  }

  Future<ZEntry> addItem(String kind, Map<String, dynamic> data) async {
    final ZEntry it = ZEntry(kind: kind, data: data);
    it.id = await dao.insertItem(it);
    _items.putIfAbsent(kind, () => <ZEntry>[]).add(it);
    notifyListeners();
    return it;
  }

  Future<void> saveItem(ZEntry it) async {
    it.updatedAt = DateTime.now();
    await dao.updateItem(it);
    notifyListeners();
  }

  Future<void> removeItem(ZEntry it) async {
    final int? id = it.id;
    if (id != null) await dao.deleteItem(id);
    _items[it.kind]?.remove(it);
    notifyListeners();
  }

  /// 某条主线被标注过的行为条数（行为记录、已开牌的决定、带主线标注的各类条目）。
  int actsOfHypothesis(int id) {
    int n = logs.where((ZLog l) => l.hypId == id).length +
        revealed.where((ZDecision d) => d.hypId == id).length;
    for (final List<ZEntry> list in _items.values) {
      n += list.where((ZEntry e) => e.i('th') == id).length;
    }
    return n;
  }

  /// 某条主线在几个不同的人生阶段出现过（来自带阶段标注的行为考古）。
  int phasesOfHypothesis(int id) {
    final Set<String> ph = <String>{};
    for (final ZEntry e in items('arch')) {
      if (e.i('th') == id && e.s('ph').isNotEmpty) ph.add(e.s('ph'));
    }
    return ph.length;
  }

  /// 导出全部数据（JSON 文本），用于备份或带给别人看。
  String exportJson() {
    return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'app': 'zhaojian',
      'schemaVersion': ZhaojianSchema.schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'decisions': decisions.map((ZDecision d) => d.toRow()).toList(),
      'logs': logs.map((ZLog l) => l.toRow()).toList(),
      'hypotheses': hypotheses.map((ZHypothesis h) => h.toRow()).toList(),
      'misses': misses.map((ZMiss m) => m.toRow()).toList(),
      'items': <String, dynamic>{
        for (final MapEntry<String, List<ZEntry>> e in _items.entries)
          e.key: e.value.map((ZEntry i) => i.toRow()).toList(),
      },
      'kv': _kv,
    });
  }

  Future<void> setKv(String key, String value) async {
    _kv[key] = value;
    await dao.setKv(key, value);
    notifyListeners();
  }

  /// 给一个条目标注「它表达了（或背离了）哪条主线」，同步计入该假设的支持或反驳。
  /// 换了主线或换了方向会先撤销上一次的计数；取消标注时 [hypId] 传 null。
  Future<void> tagItem(ZEntry it, int? hypId, String kind) async {
    final int? oldId = it.i('th');
    final String oldKind = it.s('tk', 'sup');
    if (oldId != null) await _unbumpHypothesis(oldId, oldKind);
    if (hypId == null) {
      it.data.remove('th');
      it.data.remove('tk');
    } else {
      it.data['th'] = hypId;
      it.data['tk'] = kind;
      await _bumpHypothesis(hypId, kind);
    }
    await dao.updateItem(it);
    await load();
  }

  Future<void> _unbumpHypothesis(int id, String kind) async {
    final ZHypothesis? h = await dao.findHypothesis(id);
    if (h == null) return;
    final List<int> list = kind == 'ref' ? h.ref : h.sup;
    if (list.isNotEmpty) list.removeLast();
    h.status = hypothesisStatus(h.sup.length, h.ref.length);
    await dao.updateHypothesis(h);
  }

  Future<void> _bumpHypothesis(int id, String kind) async {
    final ZHypothesis? h = await dao.findHypothesis(id);
    if (h == null) return;
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (kind == 'ref') {
      h.ref.add(now);
    } else {
      h.sup.add(now);
    }
    h.status = hypothesisStatus(h.sup.length, h.ref.length);
    await dao.updateHypothesis(h);
  }

  /// 给 AI 的背景：已被行为支持的主线，和常漏的动机类别。
  String profileText(List<String> categoryNames) {
    final List<String> sup = hypotheses
        .where((ZHypothesis h) => h.status == 1)
        .map((ZHypothesis h) => h.text)
        .toList();
    final List<String> miss = missCats
        .where((int c) => c >= 0 && c < categoryNames.length)
        .map((int c) => categoryNames[c])
        .toList();
    final StringBuffer b = StringBuffer();
    if (sup.isNotEmpty) b.write('用户已被行为支持的主线：${sup.join('；')}。');
    if (miss.isNotEmpty) b.write('用户常漏掉的动机类别：${miss.join('、')}。');
    return b.toString();
  }
}
