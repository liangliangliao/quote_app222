import 'package:flutter/material.dart';
import '../failure_module/fp_dao.dart';
import '../failure_module/tal/tal_failure_change.dart';
import '../prp_plugin/prp_plugin.dart';
import '../prp_plugin/src/runtime.dart';

/// Joins the existing offer, safety and recall governance to the shared FP ledger.
/// No background task, notification channel, AI Provider or history is added.
class TalPrpSession extends StatefulWidget {
  const TalPrpSession(
      {super.key,
      required this.runtime,
      required this.offer,
      required this.legacy,
      this.onFinished});
  final PrpRuntime runtime;
  final PrpOffer offer;
  final Widget legacy;
  final VoidCallback? onFinished;
  @override
  State<TalPrpSession> createState() => _TalPrpSessionState();
}

class _TalPrpSessionState extends State<TalPrpSession> {
  late final int _epoch;
  bool _loading = true, _legacy = false, _closed = false;
  PrpRuntime get r => widget.runtime;
  @override
  void initState() {
    super.initState();
    _epoch = r.sessionShown(widget.offer);
    _load();
  }

  Future<void> _load() async {
    final state = await r.sessionState(widget.offer);
    if (mounted)
      setState(() {
        _legacy = widget.offer.signal.surface == PrpSurface.failureModule ||
            state['lesson_id'] != null ||
            r.initialLessons.containsKey(widget.offer.sessionId);
        _loading = false;
      });
  }

  @override
  void dispose() {
    r.sessionHidden(widget.offer, _epoch);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_closed || !r.offerActive(widget.offer)) return const SizedBox.shrink();
    if (_loading)
      return const Padding(
          padding: EdgeInsets.all(16), child: Text('正在读取本地记录…'));
    if (_legacy) return widget.legacy;
    final signal = widget.offer.signal;
    final env = TalEnvironment(
        ledger: TalLessonLedger(
            dao: FpDao(openDatabase: r.store.openDatabase),
            clock: r.clock,
            canWrite: () => r.offerActive(widget.offer)),
        host: r.host,
        aiEnabled: () => r.aiAllowed && r.offerActive(widget.offer),
        onCrisis: () => r.crisisExit(widget.offer));
    return TalReflectionPanel(
      environment: env,
      eventId: signal.reference ?? 'prp:${widget.offer.sessionId}',
      subjectKey: signal.subjectKey == 'free' ? '' : signal.subjectKey,
      initialPlan: signal.expected,
      initialObserved: signal.facts.join('\n'),
      source: signal.surface.key,
      confirmed: signal.confirmed,
      onLegacyExercise: () => setState(() => _legacy = true),
      onSaved: (_) async {
        await r.completeExternalReflection(widget.offer);
        if (mounted) setState(() => _closed = true);
        widget.onFinished?.call();
      },
    );
  }
}

class TalPrpRecall extends StatefulWidget {
  const TalPrpRecall(
      {super.key,
      required this.runtime,
      required this.contextValue,
      required this.legacy});
  final PrpRuntime runtime;
  final PrpContext contextValue;
  final Widget legacy;
  @override
  State<TalPrpRecall> createState() => _TalPrpRecallState();
}

class _TalPrpRecallState extends State<TalPrpRecall> {
  late final ledger = TalLessonLedger(
      dao: FpDao(openDatabase: widget.runtime.store.openDatabase),
      clock: widget.runtime.clock);
  TalRecord? _record;
  bool _loaded = false;
  String get _reference =>
      widget.contextValue.reference ??
      '${widget.contextValue.subjectKey}:${widget.contextValue.location}:${widget.runtime.dayStartMs}';
  @override
  void initState() {
    super.initState();
    PrpPlugin.changes.addListener(_ledgerChanged);
    _load();
  }

  @override
  void dispose() {
    PrpPlugin.changes.removeListener(_ledgerChanged);
    super.dispose();
  }

  Future<void> _ledgerChanged() async {
    final previous = _record;
    if (previous == null) {
      await _load();
      return;
    }
    try {
      final current = await ledger.get(previous.eventId);
      if (mounted)
        setState(() {
          _record = current != null &&
                  current.reminderConsent &&
                  current.currentTrial?.id == previous.currentTrial?.id &&
                  current.currentTrial!.evidence.isEmpty
              ? current
              : null;
        });
    } catch (_) {
      if (mounted) setState(() => _record = null);
    }
  }

  @override
  void didUpdateWidget(covariant TalPrpRecall oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contextValue.subjectKey != widget.contextValue.subjectKey ||
        oldWidget.contextValue.reference != widget.contextValue.reference) {
      _loaded = false;
      _record = null;
      _load();
    }
  }

  Future<void> _load() async {
    final r = widget.runtime;
    final contextValue = widget.contextValue;
    try {
      // Governance may read this same SQLite connection; resolve it before
      // reserving a receipt inside the ledger transaction.
      final governance = await r.host.governance();
      final record = contextValue.surface == PrpSurface.kindling
          ? null
          : await ledger.nextRelevantAction(
              subjectKey: contextValue.subjectKey ?? '',
              reference: _reference,
              dailyCap: r.preferences.recallCap,
              matches: (record) =>
                  PrpRuntime.similarity(
                      '${record.plan}${record.currentTrial?.trigger ?? ''}',
                      contextValue.text) >=
                  .26,
              allowed: () =>
                  mounted &&
                  identical(contextValue, widget.contextValue) &&
                  r.enabledFor(contextValue.surface) &&
                  r.preferences.recalls &&
                  governance.allows);
      if (mounted && identical(contextValue, widget.contextValue)) {
        setState(() {
          _record = record;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted && identical(contextValue, widget.contextValue))
        setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final record = _record;
    if (record == null) return widget.legacy;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('上一条认识 · 尚待验证'),
              if (record.hasLesson) Text(record.lesson),
              Text('这次计划：${record.currentTrial!.action}'),
              const Text('行动后再核对有没有做和实际结果，不自动认定方法有效。'),
              Wrap(children: [
                TextButton(
                    onPressed: () => showTalOutcome(context,
                        record: record,
                        environment: TalEnvironment(
                            ledger: ledger,
                            host: widget.runtime.host,
                            aiEnabled: () => widget.runtime.aiAllowed,
                            onCrisis: () => widget.runtime.crisisExit(null))),
                    child: const Text('记录行动与结果')),
                TextButton(
                    onPressed: () async {
                      await ledger.ignoreReminder(record.eventId, _reference);
                      if (mounted) setState(() => _record = null);
                    },
                    child: const Text('这次不提醒')),
                TextButton(
                    onPressed: () async {
                      await ledger.cancelReminders(record.eventId);
                      if (mounted) setState(() => _record = null);
                    },
                    child: const Text('关闭这条回访')),
              ]),
            ])));
  }
}
