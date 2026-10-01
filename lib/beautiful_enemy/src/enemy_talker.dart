import 'data/models.dart';

/// 敌人开口说话的来源。宿主接模型；不接或模型不可用时，模块用 [PersonaLines]
/// 里写好的台词——同样是这个角色的声音，只是没那么贴着你的处境。
///
/// 返回 null 表示这次没产出，调用方会重试一次，再退回本地台词。
/// 返回的文本一律要过 [DraftValidator.validateLine]，过不了就当没产出。
abstract class EnemyTalker {
  Future<String?> talk({
    required Map<String, dynamic> digest,
    required List<EnemyMessage> history,
    required String situation,
    required String userText,
    required int intensity,
    required String address,
    required int nowMs,
  });
}

/// 敌人的声音输出（TTS）。模块不引入语音依赖，由宿主实现。
abstract class EnemyVoiceOut {
  Future<void> speak(String text);
  Future<void> stop();
}

class NoopEnemyVoiceOut implements EnemyVoiceOut {
  const NoopEnemyVoiceOut();

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}
