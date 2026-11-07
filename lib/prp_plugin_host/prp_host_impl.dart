import 'package:sqflite/sqflite.dart';

import '../beautiful_enemy/beautiful_enemy.dart';
import '../data/db.dart';
import '../data/kv_dao.dart';
import '../prp_plugin/prp_plugin.dart';

/// 插件设置的键值存储：用 App 现有的 KeyValueDao（键以 prp. 为前缀）。
class KeyValueDaoPrpKv implements PrpKv {
  KeyValueDaoPrpKv([KeyValueDao? dao]) : _dao = dao ?? KeyValueDao();

  final KeyValueDao _dao;

  @override
  Future<String?> get(String key) => _dao.getString(key);

  @override
  Future<void> set(String key, String value) => _dao.setString(key, value);
}

/// 宿主适配器：把插件需要的外部能力接到美丽的敌人和 App 数据库上。
/// 只读敌人的数据；唯一的写入是 [mirrorLesson]（盖印后在敌人教训页留一行摘要）。
class PrpHostImpl implements PrpHost {
  PrpHostImpl({Future<Database> Function()? dbProvider})
    : _dbProvider = dbProvider ?? AppDatabase.instance;

  final Future<Database> Function() _dbProvider;

  Future<EnemyDao> _dao() async {
    final Database db = await _dbProvider();
    await EnemySchema.createAll(db);
    return EnemyDao(db);
  }

  @override
  int nowMs() => DateTime.now().millisecondsSinceEpoch;

  /// 危机词沿用敌人的 SafetyValve（单一事实来源）；身份判断用插件自带的句式。
  @override
  GuardResult guardText(String text) {
    if (SafetyValve.isCrisis(text)) {
      return const GuardResult(
        ok: false,
        crisis: true,
        problems: <String>['crisis'],
        message: BuiltinTextGuard.crisisMessage,
      );
    }
    return BuiltinTextGuard.check(text);
  }

  @override
  Future<bool> isQuietNow() async {
    final EnemyDao dao = await _dao();
    final int start = await dao.intSetting(EnemySettings.quietStartHour, 23);
    final int end = await dao.intSetting(EnemySettings.quietEndHour, 7);
    final int hour = DateTime.fromMillisecondsSinceEpoch(nowMs()).hour;
    if (start == end) return false;
    if (start > end) return hour >= start || hour < end;
    return hour >= start && hour < end;
  }

  @override
  Future<bool> isMuted() async {
    final EnemyDao dao = await _dao();
    return await dao.intSetting(EnemySettings.mutedUntilMs, 0) > nowMs();
  }

  /// “拉远”用：近 N 天的字据（兑现 / 失效 / 其他），label 是字据的 subjectKey。
  @override
  Future<List<PrpMark>> recentMarks(String subjectKey, {int days = 30}) async {
    final EnemyDao dao = await _dao();
    final int since = nowMs() - days * 24 * 3600 * 1000;
    final List<EnemyCommitment> items = await dao.commitmentsSince(since);
    final List<PrpMark> out = <PrpMark>[];
    for (final EnemyCommitment c in items) {
      if (c.status == CommitmentStatus.proposed ||
          c.status == CommitmentStatus.declined) {
        continue;
      }
      final String status = c.status == CommitmentStatus.done
          ? 'done'
          : (c.status == CommitmentStatus.missed ? 'missed' : 'other');
      out.add(
        PrpMark(
          tsMs: c.dueMs ?? c.createdMs,
          status: status,
          label: 'commitment:${c.id}',
        ),
      );
    }
    out.sort((PrpMark a, PrpMark b) => a.tsMs.compareTo(b.tsMs));
    return out;
  }

  /// commitment:<id> → 'done' | 'missed' | null（还没结果）。
  @override
  Future<String?> resolveRef(String ref) async {
    const String prefix = 'commitment:';
    if (!ref.startsWith(prefix)) return null;
    final int? id = int.tryParse(ref.substring(prefix.length));
    if (id == null) return null;
    final EnemyDao dao = await _dao();
    final EnemyCommitment? c = await dao.commitment(id);
    if (c == null) return null;
    if (c.status == CommitmentStatus.done) return 'done';
    if (c.status == CommitmentStatus.missed) return 'missed';
    return null;
  }

  /// 本版本不接 AI：返回 null，插件使用离线模板。
  @override
  Future<String?> callAi(String task, Map<String, dynamic> input) async => null;

  /// 盖印后在敌人的教训页留一行摘要（走敌人已有的教训入口，不改表结构）。
  @override
  Future<void> mirrorLesson(PrpLesson lesson) async {
    if (lesson.source != 'enemy') return;
    final EnemyDao dao = await _dao();
    final String category = lesson.category.isEmpty ? '其他' : lesson.category;
    String reason = lesson.failed.join('、');
    if (reason.length > 60) reason = reason.substring(0, 60);
    await dao.addOrBumpLesson(
      verdictId: null,
      category: category,
      reasonText: reason,
      lesson: lesson.summaryLine(),
      nowMs: nowMs(),
    );
  }
}
