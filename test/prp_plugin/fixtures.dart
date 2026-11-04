import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/prp_plugin/prp_plugin.dart';
import 'package:quote_app/prp_plugin/src/runtime.dart';
import 'package:quote_app/prp_plugin/src/settings.dart';
import 'package:quote_app/prp_plugin/src/store.dart';
import 'package:quote_app/prp_plugin_host/enemy_adapter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MemorySettings {
  final values = <String, String>{};
  int writes = 0;
  late final adapter = PrpSettings(
      read: (key) async => values[key],
      write: (key, value) async {
        writes++;
        values[key] = value;
      });
}

class TestHost extends NoopPrpHost {
  TestHost(this.db);
  final Database db;
  bool quiet = false;
  bool muted = false;
  bool fail = false;
  int aiCalls = 0;
  int audioStops = 0;
  int recordingStops = 0;
  int safetyExits = 0;
  String? recordingPath;
  String? aiResponse;
  Completer<String?>? aiPending;
  Completer<void>? governancePending;
  final sealed = <PrpLesson>[];

  @override
  PrpGuardResult guardText(String text) =>
      PrpEnemyAdapter(() async => db).guardText(text);
  @override
  Future<PrpGovernance> governance() async {
    if (fail) throw StateError('injected host failure');
    await governancePending?.future;
    return PrpGovernance(quiet: quiet, muted: muted);
  }

  @override
  Future<String?> callAi(String task, Map<String, dynamic> input) async {
    aiCalls++;
    return aiPending == null ? aiResponse : await aiPending!.future;
  }

  @override
  Future<void> lessonSealed(PrpLesson lesson, int sessionId) async =>
      sealed.add(lesson);
  @override
  Future<void> stopAudio() async {
    audioStops++;
  }

  @override
  Future<String?> startRecording(int lessonId) async => recordingPath;
  @override
  Future<void> stopRecording() async {
    recordingStops++;
  }

  @override
  Future<void> safetyExit({bool crisis = true}) async {
    safetyExits++;
  }
}

class TestClock {
  DateTime now = DateTime(2026, 11, 4, 12);
  int monotonicMs = 0;
  void advance(Duration d) {
    now = now.add(d);
    monotonicMs += d.inMilliseconds;
  }

  DateTime call() => now;
}

class ControlledStopwatch implements Stopwatch {
  ControlledStopwatch(this.clock);
  final TestClock clock;
  int _base = 0;
  int? _started;
  @override
  bool get isRunning => _started != null;
  @override
  int get elapsedMilliseconds =>
      _base + (_started == null ? 0 : clock.monotonicMs - _started!);
  @override
  int get elapsedMicroseconds => elapsedMilliseconds * 1000;
  @override
  Duration get elapsed => Duration(milliseconds: elapsedMilliseconds);
  @override
  int get elapsedTicks => elapsedMicroseconds;
  @override
  int get frequency => 1000000;
  @override
  void start() {
    _started ??= clock.monotonicMs;
  }

  @override
  void stop() {
    _base = elapsedMilliseconds;
    _started = null;
  }

  @override
  void reset() {
    _base = 0;
    if (isRunning) _started = clock.monotonicMs;
  }
}

class PrpFixture {
  late Database db;
  late TestHost host;
  late PrpRuntime runtime;
  final settings = MemorySettings();
  final clock = TestClock();
  int databaseOpens = 0;
  Future<void> open() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false));
    host = TestHost(db);
    runtime = newRuntime();
    await runtime.initialize();
    PrpPlugin.instance = runtime;
  }

  PrpRuntime newRuntime() => PrpRuntime(
      settings: settings.adapter,
      store: PrpStore(() async {
        databaseOpens++;
        return db;
      }),
      host: host,
      clock: clock.call,
      stopwatchFactory: () => ControlledStopwatch(clock));
  Future<void> close() async {
    await runtime
        .updatePreferences(runtime.preferences.copyWith(enabled: false));
    PrpPlugin.instance = const NoopPrpPlugin();
    await db.close();
  }

  Future<void> enable({int cap = 3, bool sessions = true}) =>
      runtime.updatePreferences(runtime.preferences.copyWith(
          enabled: true,
          surfaces: {for (final s in PrpSurface.values) s: true},
          pauseSeconds: 30,
          offerCap: cap,
          recallCap: cap,
          sessions: sessions));

  PrpSignal signal(
          {PrpSurface surface = PrpSurface.behavior,
          String? ref,
          String subject = 'habit:preset:5',
          String kind = 'habit_missed',
          bool confirmed = true}) =>
      PrpSignal(
          surface: surface,
          kind: kind,
          subjectKey: subject,
          expected: '阅读 20 分钟',
          category: '拖延',
          tsMs: clock.now.millisecondsSinceEpoch,
          reference: ref ?? 'miss:$subject:${clock.now.millisecondsSinceEpoch}',
          confirmed: confirmed,
          facts: const ['用户明确标记本次未完成']);

  PrpLesson lesson(
          {PrpSurface source = PrpSurface.behavior,
          int? parentId,
          bool quote = false,
          String subject = 'habit:preset:5',
          String action = '打开书读 1 页',
          List<PrpSentence> sentences = const []}) =>
      PrpLesson(
          subjectKey: subject,
          source: source,
          createdMs: clock.now.millisecondsSinceEpoch,
          category: '拖延',
          worked: const ['把书放到桌上读了 1 页'],
          failed: const ['坐下后打开短视频'],
          triggerText: '阅读 20 分钟',
          earlySignal: '准备阅读时打开短视频',
          ifCue: '准备阅读时打开短视频',
          thenAction: action,
          parentId: parentId,
          quoteAllowed: quote,
          sentences: sentences,
          evidence: const [
            PrpEvidence(
                source: 'habit', id: '5:2026-11-04', label: '用户明确确认本次未完成')
          ]);

  Future<PrpLesson> seal(
      {String? ref,
      bool quote = false,
      PrpSurface surface = PrpSurface.behavior}) async {
    final offer = await runtime.signal(signal(
        ref: ref,
        surface: surface,
        kind: surface == PrpSurface.failureModule
            ? 'manual'
            : surface == PrpSurface.enemy
                ? 'commitment_missed'
                : 'habit_missed'));
    expect(offer, isNotNull);
    final result = await runtime.seal(
        offer!, lesson(source: surface, quote: quote),
        pauseSeconds: 30, heldMilliseconds: 3000);
    expect(result, isNotNull);
    return result!;
  }
}
