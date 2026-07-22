import 'dart:convert';

import '../data/db.dart';
import '../data/kv_dao.dart';
import 'mental_health_checkup_models.dart';

class MentalHealthCheckupRepository {
  static const String _stateKey = 'mental_health_checkup.state.v25';
  static const String _draftKey = 'mental_health_checkup.draft.v25';
  static const String _promptPrefix = 'ai_prompt.mental_health_checkup.';
  final KeyValueDao _kv;

  MentalHealthCheckupRepository({KeyValueDao? keyValueDao})
      : _kv = keyValueDao ?? KeyValueDao();

  Future<MentalHealthCheckupState> load() async {
    final raw = await _kv.getString(_stateKey);
    if (raw == null || raw.trim().isEmpty) {
      return const MentalHealthCheckupState();
    }
    try {
      return MentalHealthCheckupState.decode(raw);
    } catch (_) {
      return const MentalHealthCheckupState();
    }
  }

  Future<void> save(MentalHealthCheckupState state) =>
      _kv.setString(_stateKey, state.encode());

  Future<MentalHealthCheckupState> acceptOnboarding(
      MentalHealthCheckupState state) async {
    final next = state.copyWith(onboardingAccepted: true);
    await save(next);
    return next;
  }

  Future<MentalHealthCheckupState> addSession(
    MentalHealthCheckupState state,
    CheckupSession session,
  ) async {
    final sessions = <CheckupSession>[
      session,
      ...state.sessions.where((item) => item.id != session.id),
    ].take(60).toList(growable: false);
    final next = state.copyWith(sessions: sessions);
    await save(next);
    await clearDraft();
    return next;
  }

  Future<MentalHealthCheckupState> upsertPlan(
    MentalHealthCheckupState state,
    CheckupPrescriptionPlan plan,
  ) async {
    final plans = <CheckupPrescriptionPlan>[
      plan,
      ...state.plans.where((item) => item.id != plan.id),
    ];
    final next = state.copyWith(plans: plans);
    await save(next);
    return next;
  }

  Future<MentalHealthCheckupState> appendExecutionLog(
    MentalHealthCheckupState state,
    String planId,
    CheckupExecutionLog log,
  ) async {
    final plans = state.plans.map((plan) {
      if (plan.id != planId) return plan;
      return plan.copyWith(logs: <CheckupExecutionLog>[log, ...plan.logs]);
    }).toList(growable: false);
    final next = state.copyWith(plans: plans);
    await save(next);
    return next;
  }

  Future<MentalHealthCheckupState> completeRetest({
    required MentalHealthCheckupState state,
    required CheckupSession session,
    required CheckupRetestRecord retest,
    required CheckupPrescriptionPlan updatedPlan,
  }) async {
    final sessions = <CheckupSession>[
      session,
      ...state.sessions.where((item) => item.id != session.id),
    ].take(60).toList(growable: false);
    final plans = <CheckupPrescriptionPlan>[
      updatedPlan,
      ...state.plans.where((item) => item.id != updatedPlan.id),
    ];
    final retests = <CheckupRetestRecord>[
      retest,
      ...state.retests.where((item) => item.id != retest.id),
    ].take(60).toList(growable: false);
    final next = state.copyWith(
      sessions: sessions,
      plans: plans,
      retests: retests,
    );
    await save(next);
    await clearDraft();
    return next;
  }

  Future<void> saveDraft({
    required String sessionId,
    required String modeId,
    required String modeName,
    required String? focusDomainId,
    required int startedAtMs,
    required int currentIndex,
    required List<CheckupAnswer> answers,
  }) async {
    final payload = <String, Object?>{
      'session_id': sessionId,
      'mode_id': modeId,
      'mode_name': modeName,
      'focus_domain_id': focusDomainId,
      'started_at_ms': startedAtMs,
      'current_index': currentIndex,
      'answers': answers.map((answer) => answer.toJson()).toList(growable: false),
    };
    await _kv.setString(_draftKey, jsonEncode(payload));
  }

  Future<Map<String, dynamic>?> loadDraft() async {
    final raw = await _kv.getString(_draftKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  Future<void> clearDraft() => _kv.setString(_draftKey, '');

  Future<void> clearAllModuleData() async {
    final db = await AppDatabase.instance();
    await db.transaction((txn) async {
      await txn.delete(
        'notify_config',
        where: 'key = ? OR key = ? OR key LIKE ?',
        whereArgs: <Object?>[_stateKey, _draftKey, '$_promptPrefix%'],
      );
    });
  }
}
