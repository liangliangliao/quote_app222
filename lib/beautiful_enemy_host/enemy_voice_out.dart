import 'package:flutter_tts/flutter_tts.dart';

import '../beautiful_enemy/beautiful_enemy.dart';

/// 敌人的声音：宿主已有的 flutter_tts。语速放慢、音调压低，听起来冷一点。
/// 任何一步失败都吞掉：没声音不该影响敌人说话。
class EnemyHostVoiceOut implements EnemyVoiceOut {
  EnemyHostVoiceOut();

  FlutterTts? _tts;

  Future<FlutterTts> _ensure() async {
    final FlutterTts existing = _tts ?? FlutterTts();
    if (_tts == null) {
      await existing.setLanguage('zh-CN');
      await existing.setSpeechRate(0.42);
      await existing.setPitch(0.8);
      await existing.setVolume(1.0);
      _tts = existing;
    }
    return existing;
  }

  @override
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    try {
      final FlutterTts tts = await _ensure();
      await tts.stop();
      await tts.speak(text);
    } catch (_) {
      // 没有语音引擎就算了。
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {
      // 没在说就没什么好停的。
    }
  }
}
