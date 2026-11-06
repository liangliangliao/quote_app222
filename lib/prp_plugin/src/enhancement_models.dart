class PrpForecast {
  const PrpForecast(
      {required this.id,
      required this.subjectKey,
      required this.label,
      required this.createdMs,
      required this.predictedIntensity,
      required this.predictedDays,
      this.actualIntensity,
      this.actualDays,
      this.closedMs});
  final int id;
  final String subjectKey;
  final String label;
  final int createdMs;
  final int predictedIntensity;
  final double predictedDays;
  final int? actualIntensity;
  final double? actualDays;
  final int? closedMs;
  bool get closed => closedMs != null;
  double? get intensityRatio => actualIntensity == null || actualIntensity == 0
      ? null
      : predictedIntensity / actualIntensity!;
  double? get durationRatio => actualDays == null || actualDays == 0
      ? null
      : predictedDays / actualDays!;
  factory PrpForecast.fromMap(Map<String, Object?> row) => PrpForecast(
      id: (row['id'] as num).toInt(),
      subjectKey: '${row['subject_key']}',
      label: '${row['label']}',
      createdMs: (row['created_ms'] as num).toInt(),
      predictedIntensity: (row['pred_intensity'] as num).toInt(),
      predictedDays: (row['pred_days'] as num).toDouble(),
      actualIntensity: (row['actual_intensity'] as num?)?.toInt(),
      actualDays: (row['actual_days'] as num?)?.toDouble(),
      closedMs: (row['closed_ms'] as num?)?.toInt());
}

class PrpObservation {
  const PrpObservation(
      {this.sessions = 0,
      this.completed = 0,
      this.sealed = 0,
      this.skipped = 0,
      this.pauseSeconds = 0,
      this.recalls = 0,
      this.clicked = 0,
      this.adopted = 0,
      this.helped = 0,
      this.repeated = 0,
      this.stepCounts = const {},
      this.repeatGaps = const {},
      this.meanRepeatDays,
      this.meanEmotionChange});
  final int sessions, completed, sealed, skipped, pauseSeconds;
  final int recalls, clicked, adopted, helped, repeated;
  final Map<String, int> stepCounts;
  final Map<int, List<double>> repeatGaps;
  final double? meanRepeatDays, meanEmotionChange;
  double? get completionRate => sessions == 0 ? null : completed / sessions;
  double? get sealRate => sessions == 0 ? null : sealed / sessions;
  double? get skipRate => sessions == 0 ? null : skipped / sessions;
  double? get clickRate => recalls == 0 ? null : clicked / recalls;
  double? get adoptionRate => recalls == 0 ? null : adopted / recalls;
  double? get verificationRate =>
      helped + repeated == 0 ? null : helped / (helped + repeated);
}

class PrpDraftQuote {
  const PrpDraftQuote(this.id, this.title, this.text);
  final String id, title, text;
  static const entries = [
    PrpDraftQuote('begin', '先留下一个开始', '把书翻到今天要读的一页，再决定接下来读多久。'),
    PrpDraftQuote('small', '把动作缩小', '先写一句能修改的话，下一句可以稍后再写。'),
    PrpDraftQuote('signal', '把线索留在眼前', '准备分心时，先把正在做的这一小步记下来。'),
    PrpDraftQuote('pause', '允许停一下', '先把呼吸放慢一点，等这一刻过去，再处理眼前的事。'),
    PrpDraftQuote('record', '留下发生过的事', '把今天完成的那一步记下来，也把卡住的地方写清楚。'),
    PrpDraftQuote('revise', '保留修改的痕迹', '把不合适的句子划掉，旁边留一行更接近事实的话。'),
    PrpDraftQuote('experiment', '再做一次小实验', '先试一个能在两分钟内完成的动作，结果出来后再改。'),
    PrpDraftQuote('enough', '给今天留一个边界', '写清今天做到哪一步就收工，到了那里便停下来。'),
    PrpDraftQuote('ask', '让请求具体一点', '把需要帮忙的那一步说清楚，再向一个可信任的人开口。'),
    PrpDraftQuote('return', '为下次留一个入口', '结束前把下一步写在纸上，下次从这一行继续。'),
    PrpDraftQuote('evidence', '先看记录', '先列出确实发生的三件事，再写下自己的解释。'),
    PrpDraftQuote('try', '用结果来修订', '一次尝试结束后，把有效的一步留下，把没用的一步改小。'),
  ];
}
