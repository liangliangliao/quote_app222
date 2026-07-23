import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'mental_health_checkup_models.dart';

class MentalHealthBackupException implements Exception {
  final String message;

  const MentalHealthBackupException(this.message);

  @override
  String toString() => message;
}

class MentalHealthBackupEnvelope {
  static const int formatVersion = 1;
  static const int currentSchemaVersion = 4;

  const MentalHealthBackupEnvelope._();

  static String create({
    required MentalHealthCheckupState state,
    required String seedVersion,
    DateTime? now,
  }) {
    final stateJson = state.toJson();
    final canonicalState = jsonEncode(stateJson);
    final manifest = <String, Object?>{
      'format': 'quote-app-mental-health-checkup',
      'format_version': formatVersion,
      'schema_version': currentSchemaVersion,
      'seed_version': seedVersion,
      'created_at_ms': (now ?? DateTime.now()).millisecondsSinceEpoch,
      'state_sha256': sha256.convert(utf8.encode(canonicalState)).toString(),
      'counts': <String, int>{
        'sessions': state.sessions.length,
        'plans': state.plans.length,
        'retests': state.retests.length,
        'answers': state.sessions.fold<int>(
          0,
          (total, session) => total + session.answers.length,
        ),
        'execution_logs': state.plans.fold<int>(
          0,
          (total, plan) => total + plan.logs.length,
        ),
      },
    };
    return jsonEncode(<String, Object?>{
      'manifest': manifest,
      'state': stateJson,
    });
  }

  static MentalHealthCheckupState validateAndDecode({
    required String raw,
    required String expectedSeedVersion,
    required String currentInstallId,
  }) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const MentalHealthBackupException('备份不是有效的对象。');
      }
      final root = Map<String, dynamic>.from(decoded);
      final manifest = Map<String, dynamic>.from(
        root['manifest'] as Map? ?? const <String, Object?>{},
      );
      final stateJson = Map<String, dynamic>.from(
        root['state'] as Map? ?? const <String, Object?>{},
      );
      if (manifest['format'] != 'quote-app-mental-health-checkup') {
        throw const MentalHealthBackupException('备份类型不匹配。');
      }
      if ((manifest['format_version'] as num?)?.toInt() != formatVersion) {
        throw const MentalHealthBackupException('备份格式版本不受支持。');
      }
      final schemaVersion =
          (manifest['schema_version'] as num?)?.toInt() ?? 0;
      if (schemaVersion < 1 || schemaVersion > currentSchemaVersion) {
        throw const MentalHealthBackupException('备份数据库版本不受支持。');
      }
      if ((manifest['seed_version'] ?? '').toString() !=
          expectedSeedVersion) {
        throw MentalHealthBackupException(
          '课程种子版本不兼容：备份为 ${manifest['seed_version']}，'
          '当前为 $expectedSeedVersion。',
        );
      }
      final canonicalState = jsonEncode(stateJson);
      final actualHash =
          sha256.convert(utf8.encode(canonicalState)).toString();
      if (actualHash != (manifest['state_sha256'] ?? '').toString()) {
        throw const MentalHealthBackupException('备份内容校验失败。');
      }

      final state = MentalHealthCheckupState.decode(canonicalState);
      _validateCounts(manifest, state);
      _validateIdentifiers(state);
      return MentalHealthCheckupState(
        schemaVersion: currentSchemaVersion,
        installId: currentInstallId,
        onboardingAccepted: state.onboardingAccepted,
        settings: state.settings,
        sessions: state.sessions,
        plans: state.plans,
        retests: state.retests,
      );
    } on MentalHealthBackupException {
      rethrow;
    } on FormatException {
      throw const MentalHealthBackupException('备份 JSON 已损坏。');
    } catch (_) {
      throw const MentalHealthBackupException('备份预检失败，未修改现有数据。');
    }
  }

  static void _validateCounts(
    Map<String, dynamic> manifest,
    MentalHealthCheckupState state,
  ) {
    final counts = Map<String, dynamic>.from(
      manifest['counts'] as Map? ?? const <String, Object?>{},
    );
    final actual = <String, int>{
      'sessions': state.sessions.length,
      'plans': state.plans.length,
      'retests': state.retests.length,
      'answers': state.sessions.fold<int>(
        0,
        (total, session) => total + session.answers.length,
      ),
      'execution_logs': state.plans.fold<int>(
        0,
        (total, plan) => total + plan.logs.length,
      ),
    };
    for (final entry in actual.entries) {
      if ((counts[entry.key] as num?)?.toInt() != entry.value) {
        throw MentalHealthBackupException(
          '备份记录数不一致：${entry.key}。',
        );
      }
    }
  }

  static void _validateIdentifiers(MentalHealthCheckupState state) {
    _requireUnique(state.sessions.map((item) => item.id), '体检会话');
    _requireUnique(state.sessions.map((item) => item.report.id), '体检报告');
    _requireUnique(state.plans.map((item) => item.id), '课程行动');
    _requireUnique(state.retests.map((item) => item.id), '复验记录');

    final reportIds =
        state.sessions.map((item) => item.report.id).toSet();
    final planIds = state.plans.map((item) => item.id).toSet();
    for (final plan in state.plans) {
      if (!reportIds.contains(plan.sourceReportId)) {
        throw MentalHealthBackupException(
          '课程行动 ${plan.id} 缺少来源报告。',
        );
      }
    }
    for (final retest in state.retests) {
      if (!planIds.contains(retest.planId) ||
          !reportIds.contains(retest.baselineReportId) ||
          !reportIds.contains(retest.retestReportId)) {
        throw MentalHealthBackupException(
          '复验记录 ${retest.id} 的关联关系不完整。',
        );
      }
    }
  }

  static void _requireUnique(Iterable<String> values, String label) {
    final list = values.toList(growable: false);
    if (list.any((value) => value.trim().isEmpty) ||
        list.toSet().length != list.length) {
      throw MentalHealthBackupException('$label ID 缺失或重复。');
    }
  }
}
