import 'dart:convert';

class HealthConnectDailySummary {
  const HealthConnectDailySummary({
    this.id,
    this.userId = 'default_user',
    required this.summaryDate,
    this.steps,
    this.sleepMinutes,
    this.exerciseMinutes,
    this.activeCalories,
    this.weightKg,
    this.restingHeartRate,
    this.status = 'unknown',
    this.message,
    this.rawJson,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String userId;
  final String summaryDate;
  final int? steps;
  final int? sleepMinutes;
  final int? exerciseMinutes;
  final double? activeCalories;
  final double? weightKg;
  final double? restingHeartRate;
  final String status;
  final String? message;
  final String? rawJson;
  final String? createdAt;
  final String? updatedAt;

  Map<String, dynamic> get extraMap {
    if (rawJson == null || rawJson!.isEmpty) return const {};
    try {
      final decoded = jsonDecode(rawJson!);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.map((key, value) => MapEntry(key.toString(), value));
    } catch (_) {}
    return const {};
  }

  bool get hasAnyData =>
      (steps != null && steps! > 0) ||
      (sleepMinutes != null && sleepMinutes! > 0) ||
      (exerciseMinutes != null && exerciseMinutes! > 0) ||
      (activeCalories != null && activeCalories! > 0) ||
      weightKg != null ||
      restingHeartRate != null ||
      extraMap.keys.any((key) => const {
            'heartRateBpm',
            'heartRateAvgBpm',
            'totalCalories',
            'nutritionCalories',
            'bloodPressureSystolic',
            'oxygenSaturationPercent',
            'bloodGlucoseMmolL',
            'distanceMeters',
            'heightCm',
            'speedAvgMps',
            'hydrationLiters',
            'bodyTemperatureCelsius',
            'bodyFatPercent',
            'powerAvgWatts',
            'respiratoryRate',
            'basalMetabolicRateKcalDay',
          }.contains(key));

  double? extraDouble(String key) {
    final v = extraMap[key];
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  int? extraInt(String key) {
    final v = extraMap[key];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString());
  }

  String? extraText(String key) {
    final v = extraMap[key];
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  bool get sleepLow => (sleepMinutes ?? 9999) > 0 && (sleepMinutes ?? 9999) < 360;
  bool get stepsLow => (steps ?? 999999) < 4000;
  bool get stepsHigh => (steps ?? 0) >= 9000;
  bool get exerciseHigh => (exerciseMinutes ?? 0) >= 45;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'summary_date': summaryDate,
      'steps': steps,
      'sleep_minutes': sleepMinutes,
      'exercise_minutes': exerciseMinutes,
      'active_calories': activeCalories,
      'weight_kg': weightKg,
      'resting_heart_rate': restingHeartRate,
      'status': status,
      'message': message,
      'raw_json': rawJson,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory HealthConnectDailySummary.fromMap(Map<String, Object?> map) {
    int? asInt(Object? v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.round();
      return int.tryParse(v.toString());
    }

    double? asDouble(Object? v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return HealthConnectDailySummary(
      id: asInt(map['id']),
      userId: (map['user_id'] ?? 'default_user').toString(),
      summaryDate: (map['summary_date'] ?? '').toString(),
      steps: asInt(map['steps']),
      sleepMinutes: asInt(map['sleep_minutes']),
      exerciseMinutes: asInt(map['exercise_minutes']),
      activeCalories: asDouble(map['active_calories']),
      weightKg: asDouble(map['weight_kg']),
      restingHeartRate: asDouble(map['resting_heart_rate']),
      status: (map['status'] ?? 'synced').toString(),
      message: map['message']?.toString(),
      rawJson: map['raw_json']?.toString(),
      createdAt: map['created_at']?.toString(),
      updatedAt: map['updated_at']?.toString(),
    );
  }

  String compactText() {
    if (!hasAnyData) return message?.isNotEmpty == true ? message! : '尚未读取到 Health Connect 今日数据';
    final parts = <String>[];
    if (sleepMinutes != null && sleepMinutes! > 0) parts.add('睡眠 ${_fmtMinutes(sleepMinutes!)}');
    if (steps != null && steps! > 0) parts.add('步数 $steps 步');
    final totalCalories = extraDouble('totalCalories');
    if (totalCalories != null) parts.add('总消耗 ${totalCalories.round()} kcal');
    if (exerciseMinutes != null && exerciseMinutes! > 0) parts.add('运动 $exerciseMinutes 分钟');
    if (activeCalories != null && activeCalories! > 0) parts.add('活动消耗 ${activeCalories!.round()} kcal');
    if (weightKg != null) parts.add('体重 ${weightKg!.toStringAsFixed(1)} kg');
    final hr = extraDouble('heartRateBpm') ?? extraDouble('heartRateAvgBpm');
    if (hr != null) parts.add('心率 ${hr.round()} bpm');
    return parts.join(' · ');
  }

  static String _fmtMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h <= 0) return '$m 分钟';
    if (m == 0) return '$h 小时';
    return '$h 小时 $m 分钟';
  }
}
