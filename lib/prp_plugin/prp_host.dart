import 'src/models.dart';

/// All app-specific capabilities live behind this interface. The core does not
/// import app modules, app storage, notification services or AI providers.
abstract class PrpHost {
  const PrpHost();
  Future<List<PrpEvidence>> evidenceFor(PrpSignal signal);
  Future<List<PrpDayMark>> recentDays(String subjectKey, {int days = 30});
  PrpGuardResult guardText(String text);
  Future<PrpGovernance> governance();
  Future<void> safetyExit({bool crisis = true});
  Future<void> sessionStarted();
  Future<void> nativeStateChanged(Map<String, dynamic> state);
  Future<String> commitmentFromLesson(PrpLesson lesson, DateTime due);
  Future<String?> callAi(String task, Map<String, dynamic> input);
  Future<void> lessonSealed(PrpLesson lesson, int sessionId);
  Future<String> authorName();
  Future<String> calligraphyFont();
  Future<String?> dictate();
  Future<String?> startRecording(int lessonId);
  Future<void> stopRecording();
  Future<void> playRecording(String path);
  Future<void> stopAudio();
  Future<void> deleteRecordings(List<String> paths, {bool all = false});
  Future<String?> exportJson(String json);
}

class NoopPrpHost extends PrpHost {
  const NoopPrpHost();
  @override
  Future<List<PrpEvidence>> evidenceFor(PrpSignal signal) async => const [];
  @override
  Future<List<PrpDayMark>> recentDays(String subjectKey,
          {int days = 30}) async =>
      const [];
  @override
  PrpGuardResult guardText(String text) =>
      const PrpGuardResult(problems: ['guard_unavailable']);
  @override
  Future<PrpGovernance> governance() async => const PrpGovernance();
  @override
  Future<void> safetyExit({bool crisis = true}) async {}
  @override
  Future<void> sessionStarted() async {}
  @override
  Future<void> nativeStateChanged(Map<String, dynamic> state) async {}
  @override
  Future<String> commitmentFromLesson(PrpLesson lesson, DateTime due) async =>
      '当前宿主尚不支持创建字据。';
  @override
  Future<String?> callAi(String task, Map<String, dynamic> input) async => null;
  @override
  Future<void> lessonSealed(PrpLesson lesson, int sessionId) async {}
  @override
  Future<String> authorName() async => '我';
  @override
  Future<String> calligraphyFont() async => 'QuoteXingShu';
  @override
  Future<String?> dictate() async => null;
  @override
  Future<String?> startRecording(int lessonId) async => null;
  @override
  Future<void> stopRecording() async {}
  @override
  Future<void> playRecording(String path) async {}
  @override
  Future<void> stopAudio() async {}
  @override
  Future<void> deleteRecordings(List<String> paths, {bool all = false}) async {}
  @override
  Future<String?> exportJson(String json) async => null;
}
