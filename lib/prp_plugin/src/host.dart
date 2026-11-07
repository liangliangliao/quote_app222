import 'models.dart';
import 'text_guard.dart';

/// 插件需要的外部能力，由宿主适配器提供（lib/prp_plugin_host）。
/// 插件核心不 import 任何功能模块；没接上就用 [NoopPrpHost]，功能降级但不报错。
abstract class PrpHost {
  int nowMs();

  /// 禁用词 / 身份句式 / 危机词。宿主可以接敌人的 SafetyValve。
  GuardResult guardText(String text);

  /// 是否处于静默时段（沿用敌人的设置）。
  Future<bool> isQuietNow();

  /// 是否处于静音（用户点了“停战”，或安全阀触发）。
  Future<bool> isMuted();

  /// “拉远”用：近 N 天的真实记录。没有就返回空列表。
  Future<List<PrpMark>> recentMarks(String subjectKey, {int days = 30});

  /// 把 ref（如 commitment:12）解析成结果：'done' | 'missed' | null（还没结果）。
  Future<String?> resolveRef(String ref);

  /// 可选：AI 调用。返回 null 表示不可用，插件改用离线模板。
  Future<String?> callAi(String task, Map<String, dynamic> input);

  /// 可选：教训盖印后，把一行摘要镜像到宿主自己的教训页。
  Future<void> mirrorLesson(PrpLesson lesson);
}

class NoopPrpHost implements PrpHost {
  const NoopPrpHost();

  @override
  int nowMs() => DateTime.now().millisecondsSinceEpoch;

  @override
  GuardResult guardText(String text) => BuiltinTextGuard.check(text);

  @override
  Future<bool> isQuietNow() async => false;

  @override
  Future<bool> isMuted() async => false;

  @override
  Future<List<PrpMark>> recentMarks(String subjectKey, {int days = 30}) async =>
      const <PrpMark>[];

  @override
  Future<String?> resolveRef(String ref) async => null;

  @override
  Future<String?> callAi(String task, Map<String, dynamic> input) async => null;

  @override
  Future<void> mirrorLesson(PrpLesson lesson) async {}
}
