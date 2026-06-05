import '../models/health_profile.dart';

class HealthDietOptions {
  static const genders = <HealthDietOption>[
    HealthDietOption('unknown', '暂不填写'),
    HealthDietOption('female', '女性'),
    HealthDietOption('male', '男性'),
    HealthDietOption('other', '其他/不便透露'),
  ];

  static const activityLevels = <HealthDietOption>[
    HealthDietOption('low', '低活动量', description: '久坐为主，很少运动'),
    HealthDietOption('normal', '一般活动量', description: '日常走动，偶尔运动'),
    HealthDietOption('medium', '中等活动量', description: '每周规律运动'),
    HealthDietOption('high', '高活动量', description: '体力劳动或高频训练'),
  ];

  static const goals = <HealthDietOption>[
    HealthDietOption('restore_energy', '恢复体力 / 改善疲劳'),
    HealthDietOption('stomach_care', '调理肠胃 / 清淡养胃'),
    HealthDietOption('weight_control', '控制体重 / 减脂不挨饿'),
    HealthDietOption('muscle_gain', '高蛋白增肌'),
    HealthDietOption('blood_sugar_friendly', '控糖饮食'),
    HealthDietOption('low_sodium', '低盐护血压'),
    HealthDietOption('sleep_support', '改善睡眠'),
    HealthDietOption('teen_growth', '青少年健康成长'),
    HealthDietOption('post_recovery', '术后/病后恢复参考'),
    HealthDietOption('balanced', '普通健康均衡饮食'),
  ];

  static const conditions = <HealthDietOption>[
    HealthDietOption('hypertension', '血压偏高 / 高血压'),
    HealthDietOption('diabetes_or_high_glucose', '血糖偏高 / 糖尿病'),
    HealthDietOption('stomach_sensitive', '胃肠敏感'),
    HealthDietOption('kidney_problem', '肾脏问题'),
    HealthDietOption('gout_or_high_uric_acid', '痛风 / 尿酸偏高'),
    HealthDietOption('anemia', '贫血 / 容易头晕'),
    HealthDietOption('high_lipids', '血脂偏高'),
    HealthDietOption('fatty_liver', '脂肪肝'),
    HealthDietOption('constipation', '便秘'),
    HealthDietOption('sleep_problem', '睡眠差'),
    HealthDietOption('fatigue', '容易疲劳'),
    HealthDietOption('pregnancy_or_lactation', '孕期 / 哺乳期'),
    HealthDietOption('post_surgery_recovery', '术后恢复'),
  ];

  static const restrictions = <HealthDietOption>[
    HealthDietOption('peanut_allergy', '花生过敏'),
    HealthDietOption('seafood_allergy', '海鲜过敏'),
    HealthDietOption('egg_allergy', '鸡蛋过敏'),
    HealthDietOption('milk_allergy', '牛奶过敏'),
    HealthDietOption('lactose_intolerance', '乳糖不耐'),
    HealthDietOption('gluten_intolerance', '麸质不耐'),
    HealthDietOption('vegetarian', '素食'),
    HealthDietOption('halal', '清真饮食'),
    HealthDietOption('no_spicy', '不吃辣'),
    HealthDietOption('no_cold_food', '少吃生冷'),
    HealthDietOption('no_offal', '不吃内脏'),
    HealthDietOption('low_budget', '低预算优先'),
  ];

  static const preferences = <HealthDietOption>[
    HealthDietOption('chinese_food', '中餐 / 家常菜'),
    HealthDietOption('light_taste', '清淡口味'),
    HealthDietOption('quick_meal', '快手菜'),
    HealthDietOption('beginner_cooking', '不太会做饭'),
    HealthDietOption('rice_cooker', '有电饭煲'),
    HealthDietOption('air_fryer', '有空气炸锅'),
    HealthDietOption('oven', '有烤箱'),
    HealthDietOption('meal_prep', '适合备餐'),
  ];

  static String labelOf(List<HealthDietOption> options, String code) {
    for (final option in options) {
      if (option.code == code) return option.label;
    }
    return code;
  }

  static List<String> labelsOf(List<HealthDietOption> options, List<String> codes) {
    return codes.map((code) => labelOf(options, code)).toList();
  }
}
