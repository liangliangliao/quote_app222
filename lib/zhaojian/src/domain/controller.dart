import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../data/models.dart';
import '../data/zhaojian_dao.dart';
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
  bool loaded = false;

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
