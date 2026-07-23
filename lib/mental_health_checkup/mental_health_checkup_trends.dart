import 'mental_health_checkup_models.dart';

enum CheckupTrendSeverity { info, attention, elevated }

class CheckupTrendInsight {
  final CheckupTrendSeverity severity;
  final String title;
  final String message;

  const CheckupTrendInsight({
    required this.severity,
    required this.title,
    required this.message,
  });
}

class MentalHealthCheckupTrendAnalyzer {
  const MentalHealthCheckupTrendAnalyzer();

  List<CheckupTrendInsight> analyze(List<CheckupSession> sessions) {
    if (sessions.isEmpty) return const <CheckupTrendInsight>[];
    final latest = sessions.first.report;
    final insights = <CheckupTrendInsight>[];

    if (sessions.length >= 2) {
      final prior = sessions
          .skip(1)
          .take(3)
          .map((session) => session.report.overallScore)
          .toList(growable: false);
      final baseline = prior.reduce((a, b) => a + b) / prior.length;
      final decline = baseline - latest.overallScore;
      if (decline >= 15) {
        insights.add(CheckupTrendInsight(
          severity: CheckupTrendSeverity.elevated,
          title: '较个人基线下降',
          message:
              '最近综合分较前期基线下降 ${decline.toStringAsFixed(1)} 分，'
              '已达到优先复查阈值；先看安全、现实功能与共同原因。',
        ));
      }
    }

    if (sessions.length >= 2) {
      final currentById = <String, CheckupDomainResult>{
        for (final domain in latest.domains) domain.id: domain,
      };
      final previousById = <String, CheckupDomainResult>{
        for (final domain in sessions[1].report.domains) domain.id: domain,
      };
      for (final entry in currentById.entries) {
        final previous = previousById[entry.key];
        if (entry.value.answered > 0 &&
            previous != null &&
            previous.answered > 0 &&
            entry.value.score < 60 &&
            previous.score < 60) {
          insights.add(CheckupTrendInsight(
            severity: CheckupTrendSeverity.attention,
            title: '${entry.value.name}持续需要关注',
            message: '连续两次低于60分，建议使用聚焦深入版补充行为、功能和反证，'
                '不要仅凭重复低分升级结论。',
          ));
        }
      }
    }

    final domainById = <String, CheckupDomainResult>{
      for (final domain in latest.domains) domain.id: domain,
    };
    final recovery = domainById['D5'];
    final body = domainById['D6'];
    if (recovery != null &&
        body != null &&
        recovery.answered > 0 &&
        body.answered > 0 &&
        recovery.score < 60 &&
        body.score < 60) {
      insights.add(const CheckupTrendInsight(
        severity: CheckupTrendSeverity.attention,
        title: '恢复与身心基础成簇',
        message: '压力恢复和睡眠运动同时偏低，应先检查负荷、身体和睡眠因素，'
            '避免直接增加更多课程任务。',
      ));
    }

    final attitude = latest.attitudeScore;
    final behavior = latest.behaviorScore;
    if (attitude != null && behavior != null) {
      if (attitude >= 75 && behavior < 50) {
        insights.add(const CheckupTrendInsight(
          severity: CheckupTrendSeverity.attention,
          title: '知识/态度—行为差距',
          message: '理解与认同没有稳定转化为现实行动，优先缩小任务、调整环境和恢复。',
        ));
      } else if (behavior >= 75 && attitude < 50) {
        insights.add(const CheckupTrendInsight(
          severity: CheckupTrendSeverity.attention,
          title: '外部驱动风险',
          message: '行为完成较高但内在认同偏低，需检查强迫打卡、外界压力与自主性。',
        ));
      }
    }

    if (insights.isEmpty && sessions.length >= 2) {
      insights.add(const CheckupTrendInsight(
        severity: CheckupTrendSeverity.info,
        title: '暂未出现规则级趋势提醒',
        message: '继续按计划低频复验；一次波动不等于恢复，也不等于持续恶化。',
      ));
    }
    return insights.take(6).toList(growable: false);
  }
}
