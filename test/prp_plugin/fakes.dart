import 'package:quote_app/prp_plugin/src/core.dart';
import 'package:quote_app/prp_plugin/src/engine.dart';
import 'package:quote_app/prp_plugin/src/host.dart';
import 'package:quote_app/prp_plugin/src/lesson_validator.dart';
import 'package:quote_app/prp_plugin/src/models.dart';
import 'package:quote_app/prp_plugin/src/settings.dart';
import 'package:quote_app/prp_plugin/src/store.dart';
import 'package:quote_app/prp_plugin/src/text_guard.dart';

/// 可控的宿主：时间、静默、静音、ref 结果、近 30 天记录都能设置。
class FakeHost implements PrpHost {
  int now = DateTime(2026, 11, 4, 10, 0).millisecondsSinceEpoch;
  bool muted = false;
  bool quiet = false;
  bool mirrorThrows = false;
  final Map<String, String> refs = <String, String>{};
  List<PrpMark> marks = <PrpMark>[];
  final List<PrpLesson> mirrored = <PrpLesson>[];

  @override
  int nowMs() => now;

  @override
  GuardResult guardText(String text) => BuiltinTextGuard.check(text);

  @override
  Future<bool> isQuietNow() async => quiet;

  @override
  Future<bool> isMuted() async => muted;

  @override
  Future<List<PrpMark>> recentMarks(String subjectKey, {int days = 30}) async =>
      marks;

  @override
  Future<String?> resolveRef(String ref) async => refs[ref];

  @override
  Future<String?> callAi(String task, Map<String, dynamic> input) async => null;

  @override
  Future<void> mirrorLesson(PrpLesson lesson) async {
    if (mirrorThrows) throw StateError('mirror failed');
    mirrored.add(lesson);
  }
}

/// 一碰就抛异常的存储，用来测试熔断。
class FailingStore extends MemoryPrpStore {
  int calls = 0;

  @override
  Future<int> insertSession(PrpSession s) async {
    calls++;
    throw StateError('boom');
  }

  @override
  Future<int> countSessionsSince(int sinceMs) async {
    calls++;
    throw StateError('boom');
  }
}

/// 一套装配好的内存环境。
class Rig {
  Rig({PrpStore? storeOverride})
    : store = storeOverride ?? MemoryPrpStore(),
      host = FakeHost(),
      kv = MemoryPrpKv() {
    settings = PrpSettings(kv);
    engine = PrpEngine(store: store, host: host, settings: settings);
    core = PrpCore(
      store: store,
      host: host,
      settings: settings,
      engine: engine,
    );
  }

  final PrpStore store;
  final FakeHost host;
  final MemoryPrpKv kv;
  late final PrpSettings settings;
  late final PrpEngine engine;
  late final PrpCore core;

  MemoryPrpStore get mem => store as MemoryPrpStore;
}

const LessonDraft goodDraft = LessonDraft(
  category: '拖延',
  worked: <String>['开始前设了提醒'],
  failed: <String>['晚上十点还在刷手机'],
  earlySignal: '打开了别的 App',
  ifCue: '打开别的 App',
  thenAction: '先放下手机 2 分钟再做第一步',
);

PrpSignal enemySignal({
  String key = 'commitment:1',
  String expected = '每天晨读20分钟',
  bool userInitiated = true,
  int? rewriteOf,
}) => PrpSignal(
  surface: PrpSurface.enemy,
  kind: 'commitment_missed',
  subjectKey: key,
  expected: expected,
  facts: const <String>['07:30 提醒已响，未打卡'],
  userInitiated: userInitiated,
  rewriteOf: rewriteOf,
);
