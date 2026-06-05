import '../models/health_profile.dart';

class HealthRuleResult {
  const HealthRuleResult({
    required this.riskLevel,
    required this.recommendDirections,
    required this.limitDirections,
    required this.warnings,
  });

  final String riskLevel;
  final List<String> recommendDirections;
  final List<String> limitDirections;
  final List<String> warnings;
}

class HealthRuleEngine {
  HealthRuleResult evaluateProfile(HealthProfile profile) {
    final recommend = <String>{};
    final limit = <String>{};
    final warnings = <String>[];
    var riskLevel = 'low';

    if (profile.mainGoal == 'restore_energy') {
      recommend.addAll(['优质蛋白', '全谷物', '深色蔬菜', '规律三餐']);
      limit.addAll(['高糖饮料', '长期空腹', '油炸食品']);
    }
    if (profile.mainGoal == 'stomach_care' || profile.conditions.contains('stomach_sensitive')) {
      recommend.addAll(['清淡易消化', '温热软烂', '少油少刺激']);
      limit.addAll(['辛辣刺激', '冰冷饮品', '过油食物']);
      riskLevel = _maxRisk(riskLevel, 'medium');
    }
    if (profile.conditions.contains('hypertension') || profile.mainGoal == 'low_sodium') {
      recommend.addAll(['低盐', '蔬菜水果', '全谷物', '豆类']);
      limit.addAll(['咸菜', '加工肉', '方便面', '高钠调味料']);
      riskLevel = _maxRisk(riskLevel, 'medium');
      warnings.add('血压相关饮食需要结合实际血压、用药和医生建议调整。');
    }
    if (profile.conditions.contains('diabetes_or_high_glucose') || profile.mainGoal == 'blood_sugar_friendly') {
      recommend.addAll(['高纤维主食', '非淀粉类蔬菜', '优质蛋白']);
      limit.addAll(['含糖饮料', '甜点', '精制碳水大量摄入']);
      riskLevel = _maxRisk(riskLevel, 'medium');
      warnings.add('血糖相关饮食需要结合药物、活动量和医生/营养师建议。');
    }
    if (profile.conditions.contains('kidney_problem') ||
        profile.conditions.contains('pregnancy_or_lactation') ||
        profile.conditions.contains('post_surgery_recovery') ||
        profile.mainGoal == 'post_recovery') {
      riskLevel = 'high';
      warnings.add('当前情况可能涉及医学营养治疗，本功能仅提供一般健康饮食参考，不能替代医生或注册营养师建议。');
    }
    if (profile.restrictions.any((code) => code.contains('allergy'))) {
      riskLevel = _maxRisk(riskLevel, 'medium');
      warnings.add('已记录食物过敏限制，后续推荐会优先避开相关食材。');
    }

    if (recommend.isEmpty) {
      recommend.addAll(['饮食多样化', '蔬菜水果', '优质蛋白', '适量全谷物']);
    }
    if (limit.isEmpty) {
      limit.addAll(['高盐', '高糖', '油炸', '过度加工食品']);
    }

    return HealthRuleResult(
      riskLevel: riskLevel,
      recommendDirections: recommend.toList(),
      limitDirections: limit.toList(),
      warnings: warnings,
    );
  }

  String _maxRisk(String a, String b) {
    const order = {'low': 0, 'medium': 1, 'high': 2};
    return (order[b] ?? 0) > (order[a] ?? 0) ? b : a;
  }
}
