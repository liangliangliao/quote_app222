import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../copy.dart';
import '../data/kindling_dao.dart';
import '../data/models.dart';
import '../kindling_oracle.dart';
import '../kindling_reminder.dart';
import 'heat.dart';

/// 模块唯一的状态容器。不引入 provider/riverpod/get。
class KindlingController extends ChangeNotifier {
  KindlingController({
    required Database db,
    this.oracle = const LocalOracle(),
    this.reminder = const NoopKindlingReminder(),
  }) : dao = KindlingDao(db);

  final KindlingDao dao;
  final KindlingOracle oracle;
  final KindlingReminder reminder;

  bool _loading = true;
  bool _disposed = false;
  List<KItemView> _items = const <KItemView>[];
  List<KItem> _released = const <KItem>[];

  /// 本次进入模块是否已经复问过「说不准」。一次会话只问一次。
  bool _reaskConsumed = false;

  bool get loading => _loading;

  /// 清单顺序即痒度顺序。UI 只呈现顺序，不呈现分数。
  List<KItemView> get items => _items;

  List<KItem> get released => _released;

  int get releasedCount => _released.length;

  bool get isEmpty => _items.isEmpty;

  Future<void> load() async {
    _loading = true;
    _safeNotify();
    await dao.ensureSchema();
    final List<KItemView> views = await dao.liveItemViews();
    _items = sortByHeat(views);
    _released = await dao.releasedItems();
    _loading = false;
    _safeNotify();
  }

  /// 取一条需要复问「说不准」的火种（7 天后再问一次），每次会话至多一条。
  Future<KItem?> takeReaskCandidate() async {
    if (_reaskConsumed) return null;
    final List<KItem> due = await dao.itemsDueForReask();
    if (due.isEmpty) return null;
    _reaskConsumed = true;
    // 已经在应用内复问了，就不必再留一条系统通知。
    await reminder.onReaskResolved(itemId: due.first.id);
    return due.first;
  }

  KItemView? viewOf(int itemId) {
    for (final KItemView view in _items) {
      if (view.id == itemId) return view;
    }
    return null;
  }

  // ------------------------------------------------------------ 写入动作

  /// 清单为空时的「直接写一个」。返回新 id，调用方随即弹判别式。
  Future<int> addItem(String title, {String kind = KKind.other}) async {
    final int id = await dao.insertItem(title: title, kind: kind);
    await load();
    return id;
  }

  Future<List<int>> addItemsFromRecall(List<KCandidate> candidates) async {
    final List<int> ids = await dao.insertItems(candidates);
    await load();
    return ids;
  }

  Future<void> rename(int itemId, String title, {String? note}) async {
    await dao.renameItem(itemId, title, note: note);
    await load();
  }

  /// 痒度自评。分值只喂给排序，界面上永远只呈现措辞。
  Future<void> recordProbe(int itemId, int score) async {
    await dao.recordProbe(itemId, score);
    await load();
  }

  Future<void> release(int itemId, {String? reason}) async {
    await dao.releaseItem(
      itemId,
      reason: reason ?? KCopy.releaseReasonManual,
    );
    await reminder.onReaskResolved(itemId: itemId);
    await load();
  }

  Future<void> restore(int itemId) async {
    await dao.restoreItem(itemId);
    await load();
  }

  /// 判别式回答。答「不做」时不删除，移入「放掉的」。
  Future<void> recordVerdict(int itemId, String answer) async {
    final DateTime now = DateTime.now();
    await dao.recordVerdict(
      itemId,
      answer,
      releaseReason: KCopy.releaseReasonVerdict,
      at: now,
    );
    if (answer == KVerdictAnswer.unsure) {
      final KItem? item = await dao.findItem(itemId);
      await reminder.onUnsureRecorded(
        itemId: itemId,
        title: item?.title ?? '',
        askAgainAt: now.add(KindlingDao.unsureReaskAfter),
      );
    } else {
      await reminder.onReaskResolved(itemId: itemId);
    }
    await load();
  }

  /// 保存回溯原话并记一次回溯完成。
  Future<void> saveRecall(Map<String, String> answers) =>
      dao.saveRecallAnswers(answers);

  Future<List<String>> extractCandidates(Map<String, String> answers) =>
      oracle.extractCandidates(answers);

  /// 记一次十五分钟（含中途退出）。返回 burn 行 id。
  Future<int> recordBurn({
    required int itemId,
    required DateTime startedAt,
    required int seconds,
    required bool aborted,
  }) {
    return dao.insertBurn(
      itemId: itemId,
      startedAt: startedAt,
      seconds: seconds,
      aborted: aborted,
    );
  }

  Future<void> answerWantMore(int burnId, bool wantMore) async {
    await dao.answerWantMore(burnId, wantMore);
    await load();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }
}
