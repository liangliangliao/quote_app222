import 'package:flutter/widgets.dart';

import 'core.dart';
import 'models.dart';
import 'ui/playbook.dart';
import 'ui/recall_ui.dart';
import 'ui/session_card.dart';
import 'ui/settings_page.dart';

/// 门面：功能模块只依赖它。
///
/// 没接上（[NoopPrpPlugin]）、总开关关闭、对应功能的开关关闭、熔断，对调用方的效果都一样：
/// 信号返回 null / 未接管，插槽返回 SizedBox.shrink()，不写任何数据，不新增后台任务和通知。
abstract class PrpPlugin {
  const PrpPlugin();

  /// 启动时由宿主替换成 [RealPrpPlugin]；没替换就是 Noop。
  static PrpPlugin instance = const NoopPrpPlugin();

  bool get installed;

  Future<bool> isEnabled();
  Future<bool> enabledFor(PrpSurface surface);

  /// 发信号：返回“可以开始一次会话”的提议；关闭或受治理限制时返回 null。
  Future<PrpOffer?> signal(PrpSignal s);

  /// 用户点了“没做到”之后的一站式处理：复犯提示 → 会话页。
  /// 返回 handled=true 表示插件已经接管，调用方不必再走自己原来的流程。
  Future<PrpMissedResult> handleMissed(BuildContext context, PrpSignal s);

  /// 新建了一条字据之后，让插件把它和相关教训挂上，以便之后验证。
  Future<void> linkNewCommitment(String subjectKey, String text);

  // —— 插槽 ——
  Widget sessionCard(PrpOffer offer, {PrpCloseCallback? onClose});
  Widget commitmentHint(TextEditingController controller);
  Widget playbook();
  Widget settingsPage();

  /// 运行时给首页一条“自己的名言”；没有、关闭或未到时间返回 null。
  Future<Map<String, dynamic>?> ownQuoteRow({String? excludeContent});
}

class NoopPrpPlugin extends PrpPlugin {
  const NoopPrpPlugin();

  @override
  bool get installed => false;

  @override
  Future<bool> isEnabled() async => false;

  @override
  Future<bool> enabledFor(PrpSurface surface) async => false;

  @override
  Future<PrpOffer?> signal(PrpSignal s) async => null;

  @override
  Future<PrpMissedResult> handleMissed(
    BuildContext context,
    PrpSignal s,
  ) async => PrpMissedResult.notHandled;

  @override
  Future<void> linkNewCommitment(String subjectKey, String text) async {}

  @override
  Widget sessionCard(PrpOffer offer, {PrpCloseCallback? onClose}) =>
      const SizedBox.shrink();

  @override
  Widget commitmentHint(TextEditingController controller) =>
      const SizedBox.shrink();

  @override
  Widget playbook() => const SizedBox.shrink();

  @override
  Widget settingsPage() => const PrpSettingsPage(core: null);

  @override
  Future<Map<String, dynamic>?> ownQuoteRow({String? excludeContent}) async =>
      null;
}

class RealPrpPlugin extends PrpPlugin {
  RealPrpPlugin(this.core);

  final PrpCore core;

  @override
  bool get installed => true;

  @override
  Future<bool> isEnabled() => core.isEnabled();

  @override
  Future<bool> enabledFor(PrpSurface surface) => core.enabledFor(surface);

  @override
  Future<PrpOffer?> signal(PrpSignal s) => core.signal(s);

  @override
  Future<PrpMissedResult> handleMissed(
    BuildContext context,
    PrpSignal s,
  ) async {
    try {
      if (!await core.enabledFor(s.surface)) return PrpMissedResult.notHandled;

      // 复犯提示：又遇到类似的事，把上次盖印的话原样摆出来。
      int? rewriteOf;
      final List<PrpRecallHit> hits = await core.recallFor(
        PrpContext(
          surface: s.surface,
          subjectKey: s.subjectKey,
          text: s.expected,
          category: s.category,
          kind: 'repeat_detected',
          pull: true,
        ),
      );
      if (hits.isNotEmpty && context.mounted) {
        final PrpRepeatChoice c = await showPrpRepeatDialog(
          context,
          hits.first,
          s.surface.voice,
        );
        if (c == PrpRepeatChoice.rewrite) rewriteOf = hits.first.lesson.id;
      }
      if (!context.mounted) return PrpMissedResult.notHandled;

      final PrpOffer? offer = await core.signal(
        PrpSignal(
          surface: s.surface,
          kind: s.kind,
          subjectKey: s.subjectKey,
          expected: s.expected,
          facts: s.facts,
          category: s.category,
          userInitiated: s.userInitiated,
          rewriteOf: rewriteOf ?? s.rewriteOf,
          tsMs: s.tsMs,
        ),
      );
      if (offer == null) return PrpMissedResult.notHandled;
      if (!context.mounted) return const PrpMissedResult(handled: true);

      final PrpSessionResult? r = await openPrpSessionPage(
        context,
        core,
        offer,
      );
      return PrpMissedResult(handled: true, crisis: r?.crisis ?? false);
    } catch (e) {
      core.breaker.failure('handleMissed', e);
      return PrpMissedResult.notHandled;
    }
  }

  @override
  Future<void> linkNewCommitment(String subjectKey, String text) async {
    await core.recallFor(
      PrpContext(
        surface: PrpSurface.enemy,
        subjectKey: subjectKey,
        text: text,
        kind: 'new_commitment',
      ),
    );
  }

  @override
  Widget sessionCard(PrpOffer offer, {PrpCloseCallback? onClose}) =>
      PrpSessionCard(core: core, offer: offer, onClose: onClose);

  @override
  Widget commitmentHint(TextEditingController controller) =>
      PrpCommitmentHint(core: core, controller: controller);

  @override
  Widget playbook() => PrpPlaybook(core: core);

  @override
  Widget settingsPage() => PrpSettingsPage(core: core);

  @override
  Future<Map<String, dynamic>?> ownQuoteRow({String? excludeContent}) =>
      core.ownQuoteRow(excludeContent: excludeContent);
}
