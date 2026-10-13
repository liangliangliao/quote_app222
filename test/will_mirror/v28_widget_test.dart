import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/will_mirror/will_mirror_vault.dart';
import 'package:quote_app/will_mirror/v28/case_models.dart';
import 'package:quote_app/will_mirror/v28/case_page.dart';
import 'package:quote_app/will_mirror/v28/case_reminders.dart';
import 'package:quote_app/will_mirror/v28/case_workflow.dart';

class _Vault extends WillMirrorVault {
  _Vault(this.value);
  WmCase value;
  int writes = 0;
  @override
  Future<WmCase?> caseFile(String goalId) async =>
      goalId == value.id ? value : null;
  @override
  Future<List<WmCase>> caseFiles() async => [value];
  @override
  Future<WmCase> saveCaseFile(WmCase c) async {
    writes++;
    value = c.change({'revision': c.revision + 1});
    return value;
  }

  @override
  Future<void> close() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('flutter_tts'), (_) async => 1);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
  });
  Future<void> open(WidgetTester tester, _Vault vault,
      {WmCaseLink? link, double scale = 1}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: WmCasePage(caseId: vault.value.id, vault: vault, link: link)));
    await tester.pumpAndSettle();
  }

  Future<void> button(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label).first);
    await tester.tap(find.text(label).first);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'phone flow records evidence, preparation and outcome as different facts',
      (tester) async {
    final vault = _Vault(WmWorkflow().start('phone_case', '尝试一个新任务，但信息还不齐'));
    await open(tester, vault);
    expect(find.text('从一句话开始'), findsOneWidget);
    await button(tester, '补充事实 / 信念 / 未知');
    await tester.enterText(find.byType(TextFormField).first, '所需材料已经取得');
    await button(tester, '保存');
    expect(vault.value.evidence.last.kind, WmFactKind.fact);
    expect(vault.value.evidence.last.text, '所需材料已经取得');
    expect(vault.value.evidence.last.happenedAt, isNull);
    await button(tester, '现场核实');
    expect(find.text('记录我的实际选择'), findsOneWidget);
    expect(vault.value.latest('trigger'), isNull);
    await button(tester, '已经做过准备');
    await tester.enterText(find.byType(TextFormField).first, '提前整理了三项材料');
    await button(tester, '保存');
    expect(vault.value.latest('preparation'), isNotNull);
    expect(vault.value.latest('preparation')!.happenedAt, isNull);
    expect(vault.value.latest('attempt'), isNull);
    await button(tester, '记录现实反馈');
    await tester.enterText(
        find.byType(TextFormField).first, '暂时没有机会使用这些材料，结果未知');
    await button(tester, '保存');
    expect(vault.value.latest('observation')!.data['status'], 'unknown');
    expect(vault.value.latest('observation')!.data['causalStatus'], 'unknown');
    expect(vault.value.latest('preparation'), isNotNull);
    expect(find.text('结果之后，继续认识自己'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'notification opens exact live case but does not report trigger, recall or action',
      (tester) async {
    final flow = WmWorkflow();
    final c = flow.seal(flow.start('link_case', '私密课题内容'),
        trigger: '真实条件', ifThen: '观察', fallback: '暂停');
    final vault = _Vault(c), seal = c.snapshots.single;
    await open(tester, vault,
        link: WmCaseLink(
            caseId: c.id,
            snapshotId: wmText(seal['id']),
            triggerId: wmText(wmMap(seal['payload'])['triggerId'])));
    expect(find.text('先确认现场，再作选择'), findsOneWidget);
    expect(find.textContaining('已打开计划对应的现场卡'), findsOneWidget);
    expect(vault.writes, 0);
    expect(vault.value.latest('trigger'), isNull);
    expect(vault.value.latest('attempt'), isNull);
  });

  testWidgets(
      'stale notification and larger Chinese text do not silently revive a plan or overflow',
      (tester) async {
    final vault = _Vault(
        WmWorkflow().start('large_text', '我想在新的兴趣里探索自己的能力，不因为尚未积累经验而停止尝试'));
    await open(tester, vault,
        scale: 1.4,
        link: const WmCaseLink(
            caseId: 'large_text',
            snapshotId: 'old_seal',
            triggerId: 'old_trigger'));
    expect(find.textContaining('已过期或撤回'), findsOneWidget);
    expect(vault.writes, 0);
    expect(tester.takeException(), isNull);
    await button(tester, '理由与路线');
    expect(find.text('此刻优先回看的理由 · 最多 5 条'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
