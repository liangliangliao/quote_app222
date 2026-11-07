import 'models.dart';
import 'text_guard.dart';

/// 用户在会话里填写的教训草稿。
class LessonDraft {
  const LessonDraft({
    this.category = '',
    this.worked = const <String>[],
    this.failed = const <String>[],
    this.triggerText = '',
    this.earlySignal = '',
    this.ifCue = '',
    this.thenAction = '',
  });

  final String category;
  final List<String> worked;
  final List<String> failed;
  final String triggerText;
  final String earlySignal;
  final String ifCue;
  final String thenAction;

  LessonDraft copyWith({
    String? category,
    List<String>? worked,
    List<String>? failed,
    String? triggerText,
    String? earlySignal,
    String? ifCue,
    String? thenAction,
  }) {
    return LessonDraft(
      category: category ?? this.category,
      worked: worked ?? this.worked,
      failed: failed ?? this.failed,
      triggerText: triggerText ?? this.triggerText,
      earlySignal: earlySignal ?? this.earlySignal,
      ifCue: ifCue ?? this.ifCue,
      thenAction: thenAction ?? this.thenAction,
    );
  }

  bool get isEmpty =>
      worked.isEmpty &&
      failed.isEmpty &&
      earlySignal.trim().isEmpty &&
      ifCue.trim().isEmpty &&
      thenAction.trim().isEmpty;

  static LessonDraft fromLesson(PrpLesson l) => LessonDraft(
    category: l.category,
    worked: l.worked,
    failed: l.failed,
    triggerText: l.triggerText,
    earlySignal: l.earlySignal,
    ifCue: l.ifCue,
    thenAction: l.thenAction,
  );
}

class LessonCheck {
  const LessonCheck({
    required this.canSeal,
    required this.problems,
    required this.missing,
    required this.quality,
  });

  final bool canSeal;

  /// crisis | identity | action_too_long
  final List<String> problems;

  /// worked | failed | early_signal | if_then（缺什么）
  final List<String> missing;

  /// 成色 0–5。
  final int quality;

  bool get hasCrisis => problems.contains('crisis');
}

/// 教训校验：
/// 盖印必须有“有效”、有“没起作用（具体场景）”、有“如果—那么”，且不含对人的评价；
/// 成色 5 项各 1 分：有证据、有“有效”、行为层无身份判断、有预警、有可检验的如果—那么。
class LessonValidator {
  LessonValidator(this.guard);

  final GuardResult Function(String text) guard;

  static const int maxActionChars = 40;
  static const int minItemChars = 2;

  LessonCheck check(LessonDraft d, {required bool hasEvidence}) {
    final List<String> problems = <String>[];
    final List<String> missing = <String>[];

    final List<String> pieces = <String>[
      ...d.worked,
      ...d.failed,
      d.triggerText,
      d.earlySignal,
      d.ifCue,
      d.thenAction,
    ].where((String s) => s.trim().isNotEmpty).toList();

    for (final String p in pieces) {
      final GuardResult g = guard(p);
      if (g.crisis && !problems.contains('crisis')) problems.add('crisis');
      if (g.problems.contains('identity') && !problems.contains('identity')) {
        problems.add('identity');
      }
    }

    final bool workedOk = d.worked.any(
      (String s) => s.trim().length >= minItemChars,
    );
    final bool failedOk = d.failed.any((String s) => !VagueCheck.isVague(s));
    final bool signalOk = d.earlySignal.trim().length >= minItemChars;
    final String cue = d.ifCue.trim();
    final String action = d.thenAction.trim();
    final bool actionLong = action.length > maxActionChars;
    final bool ifThenOk =
        cue.length >= minItemChars &&
        action.length >= minItemChars &&
        !actionLong;
    if (actionLong) problems.add('action_too_long');

    if (!workedOk) missing.add('worked');
    if (!failedOk) missing.add('failed');
    if (!signalOk) missing.add('early_signal');
    if (!ifThenOk) missing.add('if_then');

    final bool identityFree =
        !problems.contains('identity') && pieces.isNotEmpty;
    final int quality = <bool>[
      hasEvidence,
      workedOk,
      identityFree,
      signalOk,
      ifThenOk,
    ].where((bool b) => b).length;

    final bool canSeal = problems.isEmpty && workedOk && failedOk && ifThenOk;
    return LessonCheck(
      canSeal: canSeal,
      problems: problems,
      missing: missing,
      quality: quality,
    );
  }
}
