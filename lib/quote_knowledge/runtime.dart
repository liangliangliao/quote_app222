import 'dart:async';
import 'package:flutter/widgets.dart';
import 'classifier.dart';
import 'repository.dart';
import 'schema.dart';

/// Durable jobs survive process death; leases prevent competing foreground and
/// scheduled workers from applying two results to one record.
class QuoteKnowledgeWorker {
  final QuoteKnowledgeRepository repository;
  final QuoteKnowledgeClassifier classifier;
  bool _running = false;
  QuoteKnowledgeWorker(
      {QuoteKnowledgeRepository? repository,
      QuoteKnowledgeClassifier? classifier})
      : repository = repository ?? QuoteKnowledgeRepository(),
        classifier = classifier ?? QuoteKnowledgeClassifier();
  Future<int> drain({int limit = 3}) async {
    if (_running) return 0;
    _running = true;
    var completed = 0;
    try {
      for (var i = 0; i < limit; i++) {
        final claim = await repository.claim();
        if (claim == null) break;
        try {
          final candidates = await repository.candidates(claim.quote);
          final result = await classifier.classify(claim.quote, candidates);
          if (await repository.apply(claim, result)) completed++;
        } on ClassificationUnavailable {
          await repository.provisional(claim);
          await repository.defer(claim,
              unavailable: true, message: '请配置全局文字 AI。已保留原主题初分，配置后可继续整理。');
          break;
        } catch (_) {
          await repository.provisional(claim);
          await repository.defer(claim);
        }
      }
    } finally {
      _running = false;
    }
    return completed;
  }
}

class QuoteKnowledgeRuntime with WidgetsBindingObserver {
  static final instance = QuoteKnowledgeRuntime();
  final QuoteKnowledgeWorker worker;
  Timer? _timer, _debounce;
  StreamSubscription<void>? _subscription;
  bool _started = false, _foreground = true;
  QuoteKnowledgeRuntime({QuoteKnowledgeWorker? worker})
      : worker = worker ?? QuoteKnowledgeWorker();
  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _subscription = QuoteKnowledgeEvents.changes.listen((_) => kick());
    _timer = Timer.periodic(const Duration(seconds: 35), (_) => kick());
    // Old records get a fast, explicitly provisional local index. No old quote
    // is sent to AI until the user starts the batch action.
    unawaited(_indexLegacy());
    kick();
  }

  Future<void> _indexLegacy() async {
    try {
      while (_started && await worker.repository.bootstrapLegacy() == 200) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
    } catch (_) {/* Retry on the next launch; saving quotes stays available. */}
  }

  void kick() {
    if (!_started || !_foreground || _debounce?.isActive == true) return;
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        await worker.drain();
      } catch (_) {/* Durable jobs retry later. */}
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) kick();
  }

  void stop() {
    _started = false;
    _timer?.cancel();
    _debounce?.cancel();
    _subscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
