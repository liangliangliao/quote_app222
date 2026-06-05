import 'dart:async';

import 'package:flutter/services.dart';

import '../models/health_connect_daily_summary.dart';
import '../repositories/health_connect_summary_repository.dart';
import '../repositories/health_profile_repository.dart';

class HealthConnectStatus {
  const HealthConnectStatus({
    required this.available,
    required this.status,
    this.message,
    this.granted = false,
    this.raw = const {},
  });

  final bool available;
  final String status;
  final String? message;
  final bool granted;
  final Map<String, Object?> raw;

  factory HealthConnectStatus.fromMap(Map<String, Object?> map) {
    return HealthConnectStatus(
      available: map['available'] == true,
      granted: map['granted'] == true,
      status: (map['status'] ?? 'unknown').toString(),
      message: map['message']?.toString(),
      raw: map,
    );
  }
}

class HealthConnectDietContextService {
  static const MethodChannel _channel = MethodChannel('health_diet/health_connect');

  final HealthConnectSummaryRepository _repo = HealthConnectSummaryRepository();

  Future<HealthConnectStatus> status() async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>('status');
      return HealthConnectStatus.fromMap(result ?? const {'available': false, 'status': 'empty'});
    } on MissingPluginException {
      return const HealthConnectStatus(
        available: false,
        status: 'missing_plugin',
        message: '当前构建未注册 Health Connect 原生通道。',
      );
    } catch (e) {
      return HealthConnectStatus(available: false, status: 'error', message: e.toString());
    }
  }

  Future<HealthConnectStatus> requestPermissions() async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>('requestPermissions');
      return HealthConnectStatus.fromMap(result ?? const {'available': false, 'status': 'empty'});
    } on MissingPluginException {
      return const HealthConnectStatus(available: false, status: 'missing_plugin', message: '当前构建未注册 Health Connect 原生通道。');
    } catch (e) {
      return HealthConnectStatus(available: false, status: 'error', message: e.toString());
    }
  }

  Future<HealthConnectDailySummary> readAndSaveToday({
    String userId = HealthProfileRepository.defaultUserId,
  }) async {
    final date = _todayDate();
    try {
      final result = await _channel.invokeMapMethod<String, Object?>('readTodaySummary');
      final map = Map<String, Object?>.from(result ?? const {});
      await _repo.upsertFromNativeMap(userId: userId, date: date, map: map);
      return (await _repo.latestForDate(userId: userId, date: date)) ??
          HealthConnectDailySummary(
            userId: userId,
            summaryDate: date,
            status: (map['status'] ?? 'empty').toString(),
            message: map['message']?.toString() ?? '未读取到 Health Connect 数据。',
          );
    } on MissingPluginException {
      final fallback = HealthConnectDailySummary(
        userId: userId,
        summaryDate: date,
        status: 'missing_plugin',
        message: '当前构建未注册 Health Connect 原生通道。',
      );
      await _repo.upsert(fallback);
      return fallback;
    } catch (e) {
      final fallback = HealthConnectDailySummary(
        userId: userId,
        summaryDate: date,
        status: 'error',
        message: e.toString(),
      );
      await _repo.upsert(fallback);
      return fallback;
    }
  }

  Future<HealthConnectDailySummary?> latestToday({String userId = HealthProfileRepository.defaultUserId}) {
    return _repo.latestForDate(userId: userId, date: _todayDate());
  }

  List<String> dietHintsFromSummary(HealthConnectDailySummary? summary) {
    if (summary == null || !summary.hasAnyData) return const [];
    final hints = <String>[];
    if (summary.sleepLow) {
      hints.add('昨晚睡眠偏少，今天建议不要主要依赖奶茶、甜饮或过量咖啡硬撑，早餐优先补蛋白质和稳定碳水。');
    }
    if (summary.stepsLow) {
      hints.add('今日步数偏少，晚餐更适合清淡、少油、少糖，避免继续叠加高油高糖夜宵。');
    }
    if (summary.stepsHigh || summary.exerciseHigh) {
      hints.add('今日活动量较高，下一餐可以补充鸡蛋、牛奶/豆浆、鱼肉、豆腐等优质蛋白，并搭配适量主食帮助恢复。');
    }
    if ((summary.exerciseMinutes ?? 0) > 0 && (summary.activeCalories ?? 0) > 250) {
      hints.add('今天已有运动消耗，饮食复盘会优先关注运动后恢复：蛋白质、适量碳水和水分。');
    }
    final hydration = summary.extraDouble('hydrationLiters');
    if (hydration != null && hydration > 0 && hydration < 1.2) {
      hints.add('今天 Health Connect 中记录的饮水量偏少，可以把补水作为明天的一个最小改变。');
    }
    final nutritionProtein = summary.extraDouble('nutritionProteinG');
    if (nutritionProtein != null && nutritionProtein > 0 && nutritionProtein < 45) {
      hints.add('今天记录到的蛋白质摄入偏少，下一餐可优先选择鸡蛋、鱼肉、豆腐、牛奶/豆浆等。');
    }
    final sodium = summary.extraDouble('nutritionSodiumMg');
    if (sodium != null && sodium > 2000) {
      hints.add('今天 Health Connect 中记录的钠摄入偏高，晚餐或明天建议减少方便面、腌制品、火腿肠和外卖汤汁。');
    }
    final glucose = summary.extraDouble('bloodGlucoseMmolL');
    if (glucose != null) {
      hints.add('已读取到血糖记录。饮食建议只做一般参考；如你有糖尿病、正在用药或血糖异常，请优先遵循医生/营养师建议。');
    }
    return hints;
  }

  String _todayDate() => DateTime.now().toIso8601String().substring(0, 10);
}
