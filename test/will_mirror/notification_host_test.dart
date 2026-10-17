import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/services/notification_service.dart';
import 'package:quote_app/utils/simple_bus.dart';
import 'package:quote_app/will_mirror/integration/reminders.dart';
import 'package:quote_app/will_mirror/presentation/module_page.dart';

void main() {
  testWidgets(
      'a foreground notification consumes pending navigation and opens only once',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('native.scheduler'), (_) async => null);
    final payload = MirrorLink(caseId: 'fixture_case').encode();
    await tester.pumpWidget(MaterialApp(
        navigatorKey: SimpleBus.navigatorKey,
        home: const Scaffold(body: Text('host'))));
    await NotificationService.markLaunchedFromNotification(payload);
    await NotificationService.handleNotificationPayload(payload);
    await NotificationService.handleNotificationPayload(payload);
    await tester.pumpAndSettle();
    expect(find.byType(WillMirrorModulePage), findsOneWidget);
    expect(
        await NotificationService.handlePendingNotificationNavigation(), false);
    expect(tester.takeException(), isNull);
    SimpleBus.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });
}
