import 'host.dart';
import 'models.dart';
import 'settings.dart';
import 'store.dart';

/// 计入每日回访预算的场景。用户主动查看（pull）不计入。
const Set<String> kBudgetedRecallContexts = <String>{
  'new_commitment',
  'quote_home',
  'habit_reminder',
};

/// 本地日界线（当天 0 点）的毫秒数。
int startOfLocalDayMs(int nowMs) {
  final DateTime d = DateTime.fromMillisecondsSinceEpoch(nowMs);
  return DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
}

/// 治理：静默时段、静音、每日提议与回访上限。
/// 用户亲手触发的（userInitiated / pull）不受限制。
class PrpGovernor {
  PrpGovernor({
    required this.store,
    required this.host,
    required this.settings,
  });

  final PrpStore store;
  final PrpHost host;
  final PrpSettings settings;

  Future<bool> allowOffer(PrpSignal s, int nowMs) async {
    if (s.userInitiated) return true;
    if (await host.isMuted()) return false;
    if (await host.isQuietNow()) return false;
    final int cap = await settings.offerCap();
    if (cap <= 0) return false;
    final int used = await store.countSessionsSince(startOfLocalDayMs(nowMs));
    return used < cap;
  }

  Future<bool> allowRecall(PrpContext c, int nowMs) async {
    if (c.pull) return true;
    if (await host.isMuted()) return false;
    if (await host.isQuietNow()) return false;
    final int cap = await settings.recallCap();
    if (cap <= 0) return false;
    final int used = await store.countRecallsSince(
      startOfLocalDayMs(nowMs),
      contexts: kBudgetedRecallContexts,
    );
    return used < cap;
  }
}

/// 熔断器：本次进程内连续 [threshold] 次内部异常，插件整体静默到下次启动。
class PrpBreaker {
  PrpBreaker({this.threshold = 3});

  final int threshold;
  int _consecutive = 0;
  int _total = 0;
  bool _tripped = false;
  final List<String> _log = <String>[];

  bool get tripped => _tripped;
  int get failures => _total;
  List<String> get log => List<String>.unmodifiable(_log);

  void success() => _consecutive = 0;

  void failure(String where, Object error) {
    _consecutive++;
    _total++;
    note('异常 $where：$error');
    if (!_tripped && _consecutive >= threshold) {
      _tripped = true;
      note('熔断：本次启动内插件静默，重启后恢复');
    }
  }

  void note(String message) {
    final String t = DateTime.now().toIso8601String();
    _log.add('${t.substring(11, 19)} $message');
    if (_log.length > 30) _log.removeAt(0);
  }

  void reset() {
    _consecutive = 0;
    _tripped = false;
  }
}
