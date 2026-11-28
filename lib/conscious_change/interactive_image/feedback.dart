enum TouchAction {
  highlight('高亮区域'),
  pulse('区域脉冲动画'),
  sound('短提示音'),
  vibration('轻震动'),
  learning('打开学习模块'),
  books('打开书籍下载'),
  link('打开链接'),
  app('打开手机应用'),
  audio('播放音频'),
  video('播放视频'),
  systemSound('播放系统声音'),
  speak('系统语音朗读');

  const TouchAction(this.label);
  final String label;
  bool get isFile => this == audio || this == video;
}

const defaultWakePhrase = '图片助手';

// Recognition engines may add spaces and punctuation around Chinese or English commands.
String normalizeCommand(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[\s，。！？、；：,.!?;:「」『』"“”]+'), '');

Uri? feedbackLink(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      !const {'http', 'https'}.contains(uri.scheme) ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) return null;
  return uri;
}

bool validFeedbackMediaName(String name) =>
    RegExp(r'^[a-f0-9]{32}\.(audio|video)$').hasMatch(name);

class FeedbackStep {
  const FeedbackStep(this.action, {this.value, this.name});

  final TouchAction action;
  final String? value;
  final String? name;

  String get title =>
      name ?? (action == TouchAction.link ? value : null) ?? action.label;

  static FeedbackStep? fromJson(Object? raw) {
    // Version 1 wrote one action name directly under each gesture.
    final type = raw is String
        ? raw
        : raw is Map
            ? raw['action']
            : null;
    final action =
        TouchAction.values.where((item) => item.name == type).firstOrNull;
    if (action == null) return null;
    final value =
        raw is Map && raw['value'] is String ? raw['value'] as String : null;
    final name =
        raw is Map && raw['name'] is String ? raw['name'] as String : null;
    final valid = switch (action) {
      TouchAction.link => value != null && feedbackLink(value) != null,
      TouchAction.app => name != null && name.trim().isNotEmpty,
      TouchAction.audio || TouchAction.video => value != null &&
          validFeedbackMediaName(value) &&
          value.endsWith('.${action.name}'),
      TouchAction.systemSound =>
        const {'notification', 'ringtone', 'alarm'}.contains(value),
      TouchAction.speak =>
        value != null && value.trim().isNotEmpty && value.length <= 300,
      _ => true,
    };
    return valid ? FeedbackStep(action, value: value, name: name) : null;
  }

  Map<String, Object> toJson() => {
        'action': action.name,
        if (value != null) 'value': value!,
        if (name != null) 'name': name!,
      };

  @override
  bool operator ==(Object other) =>
      other is FeedbackStep &&
      other.action == action &&
      other.value == value &&
      other.name == name;

  @override
  int get hashCode => Object.hash(action, value, name);
}

List<FeedbackStep> feedbackChainFromJson(Object? raw) => [
      for (final entry in raw is List ? raw : [raw])
        if (FeedbackStep.fromJson(entry) case final step?) step,
    ];

class VoiceFeedback {
  const VoiceFeedback(this.phrase, this.steps);

  final String phrase;
  final List<FeedbackStep> steps;

  static VoiceFeedback? fromJson(Object? raw) {
    if (raw is! Map || raw['phrase'] is! String) return null;
    final phrase = raw['phrase'] as String;
    final steps = feedbackChainFromJson(raw['steps']);
    return normalizeCommand(phrase).isEmpty || steps.isEmpty
        ? null
        : VoiceFeedback(phrase, steps);
  }

  Map<String, Object> toJson() =>
      {'phrase': phrase, 'steps': steps.map((step) => step.toJson()).toList()};
}

class WakePhraseMatcher {
  WakePhraseMatcher(String phrase, {this.window = const Duration(seconds: 8)})
      : _phrase = normalizeCommand(phrase);

  final String _phrase;
  final Duration window;
  DateTime? _until;

  bool armedAt(DateTime time) => _until?.isAfter(time) ?? false;

  String? commandFor(
      Iterable<String> transcripts, DateTime now, Set<String> commands) {
    final armed = armedAt(now);
    var wakeOnly = false;
    for (final transcript in transcripts) {
      final text = normalizeCommand(transcript);
      if (text.isEmpty) continue;
      if (text == _phrase) {
        wakeOnly = true;
        continue;
      }
      final withWake = _phrase.isNotEmpty && text.startsWith(_phrase);
      if (withWake && commands.contains(text.substring(_phrase.length))) {
        reset();
        return text.substring(_phrase.length);
      }
      if (armed && commands.contains(text)) {
        reset();
        return text;
      }
      wakeOnly |= withWake;
    }
    if (wakeOnly) _until = now.add(window);
    return null;
  }

  void reset() => _until = null;
}
