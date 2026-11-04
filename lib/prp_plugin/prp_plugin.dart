import 'package:flutter/material.dart';

import 'src/models.dart';

export 'prp_host.dart';
export 'src/models.dart';
export 'src/settings.dart' show PrpPreferences;

/// The sole import for calling modules. Noop is safe before host registration.
abstract class PrpPlugin {
  const PrpPlugin();
  static PrpPlugin instance = const NoopPrpPlugin();
  static final ValueNotifier<int> changes = ValueNotifier(0);
  static void changed() => changes.value++;

  bool get enabled;
  bool get aiAllowed;
  bool get quoteStreamEnabled;
  bool get hasActiveSession;
  bool enabledFor(PrpSurface surface);
  Future<PrpOffer?> signal(PrpSignal signal);
  Future<List<PrpRecall>> recallFor(PrpContext context);
  Future<void> reportOutcome(int recallId, PrpOutcome outcome);
  Future<void> reportSubjectOutcome(PrpContext context, PrpOutcome outcome);
  Future<void> linkAttempt(PrpContext context);
  Widget sessionCard(PrpOffer offer, {VoidCallback? onFinished});
  Widget recallChip(PrpContext context);
  Widget playbook({bool management = false});
  Widget settingsPage();
  Future<List<PrpQuote>> quotesForStream();
  Future<List<String>> workedItems();
  Future<List<Map<String, dynamic>>> evidenceRows(int sinceMs);
  Future<void> importReviewDrafts(List<Map<String, dynamic>> details,
      {required int reviewMs});

  Future<void> showOffer(BuildContext context, PrpOffer offer,
      {bool fullScreen = false}) async {
    if (!context.mounted || !enabledFor(offer.signal.surface)) return;
    BuildContext? mountedRoute;
    void closeIfDisabled() {
      if (enabledFor(offer.signal.surface)) return;
      final ctx = mountedRoute;
      if (ctx == null || !ctx.mounted) return;
      final route = ModalRoute.of(ctx);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ctx.mounted && route != null && route.isActive)
          Navigator.of(ctx).removeRoute(route);
      });
    }

    changes.addListener(closeIfDisabled);
    try {
      if (fullScreen) {
        await Navigator.of(context)
            .push<void>(MaterialPageRoute(builder: (ctx) {
          mountedRoute = ctx;
          return Scaffold(
            appBar: AppBar(title: const Text('缓一缓 · 对账 · 留下一条教训')),
            body: SafeArea(
                child: SingleChildScrollView(
                    child: sessionCard(offer, onFinished: () {
              if (ctx.mounted) Navigator.of(ctx).maybePop();
            }))),
          );
        }));
      } else {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          useSafeArea: true,
          builder: (ctx) {
            mountedRoute = ctx;
            return Padding(
              padding:
                  EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
              child: SingleChildScrollView(
                  child: sessionCard(offer, onFinished: () {
                if (ctx.mounted) Navigator.of(ctx).maybePop();
              })),
            );
          },
        );
      }
    } finally {
      changes.removeListener(closeIfDisabled);
    }
  }
}

class NoopPrpPlugin extends PrpPlugin {
  const NoopPrpPlugin();
  @override
  bool get enabled => false;
  @override
  bool get aiAllowed => false;
  @override
  bool get quoteStreamEnabled => false;
  @override
  bool get hasActiveSession => false;
  @override
  bool enabledFor(PrpSurface surface) => false;
  @override
  Future<PrpOffer?> signal(PrpSignal signal) async => null;
  @override
  Future<List<PrpRecall>> recallFor(PrpContext context) async => const [];
  @override
  Future<void> reportOutcome(int recallId, PrpOutcome outcome) async {}
  @override
  Future<void> reportSubjectOutcome(
      PrpContext context, PrpOutcome outcome) async {}
  @override
  Future<void> linkAttempt(PrpContext context) async {}
  @override
  Widget sessionCard(PrpOffer offer, {VoidCallback? onFinished}) =>
      const SizedBox.shrink();
  @override
  Widget recallChip(PrpContext context) => const SizedBox.shrink();
  @override
  Widget playbook({bool management = false}) => const SizedBox.shrink();
  @override
  Widget settingsPage() => Scaffold(
      appBar: AppBar(title: const Text('PRP 插件 · 失败成长')),
      body: const Center(child: Text('插件尚未注册；其它功能照常可用。')));
  @override
  Future<List<PrpQuote>> quotesForStream() async => const [];
  @override
  Future<List<String>> workedItems() async => const [];
  @override
  Future<List<Map<String, dynamic>>> evidenceRows(int sinceMs) async =>
      const [];
  @override
  Future<void> importReviewDrafts(List<Map<String, dynamic>> details,
      {required int reviewMs}) async {}
}
