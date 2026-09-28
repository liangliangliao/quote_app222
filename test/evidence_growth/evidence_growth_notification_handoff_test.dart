import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/evidence_growth/evidence_growth_home_page.dart';
import 'package:quote_app/evidence_growth/evidence_growth_notification_link.dart';
import 'package:quote_app/services/native_guard.dart';
import 'package:quote_app/services/notification_service.dart';

// Observe the actual production route without mounting the full app/database.
class _RouteObserver extends NavigatorObserver {
  final links = <GrowthNotificationLink>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is MaterialPageRoute && previousRoute != null) {
      final page = route.builder(navigator!.context);
      if (page is EvidenceGrowthHomePage) links.add(page.notification!);
    }
  }
}

void main() {
  const native = MethodChannel('native.scheduler');
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  String payload(String token, String trial) => jsonEncode({
        'module': 'evidence_growth',
        'tap_token': token,
        'targets': [
          {'trial_id': trial, 'journey_id': 'goal-$trial', 'node': 'OUTCOME'}
        ]
      });
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(native, null);
  });

  testWidgets(
      'cold native payload survives missed event, acknowledges exact token and opens once',
      (tester) async {
    var pending = payload('cold-tap', 'cold-trial');
    final acknowledgements = <String>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(native,
        (call) async {
      if (call.method == 'eg_pending_notification') return pending;
      if (call.method == 'eg_ack_notification') {
        acknowledgements.add(call.arguments['tap_token'] as String);
        pending = '';
      }
      return null;
    });
    final observer = _RouteObserver();
    await tester.pumpWidget(MaterialApp(
        navigatorKey: SimpleBus.navigatorKey,
        navigatorObservers: [observer],
        home: const SizedBox()));
    // No markLaunchedFromNotification: simulate the native event occurring before Dart.
    expect(await NotificationService.handlePendingNotificationNavigation(),
        isTrue);
    expect(observer.links.single.targets.single.trialId, 'cold-trial');
    expect(observer.links.single.targets.single.node, 'OUTCOME');
    expect(acknowledgements, ['cold-tap']);
    expect(NotificationService.hasOpenEvidenceGrowthNotification, isTrue);
    // A second startup path must not mistake the consumed payload for a reason to go home.
    expect(await NotificationService.handlePendingNotificationNavigation(),
        isFalse);
    expect(NotificationService.hasOpenEvidenceGrowthNotification, isTrue);
    expect(observer.links, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    expect(NotificationService.hasOpenEvidenceGrowthNotification, isFalse);
  });

  testWidgets(
      'warm notification routing deduplicates same tap while accepting a new target',
      (tester) async {
    final acknowledged = <String>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(native,
        (call) async {
      if (call.method == 'eg_ack_notification')
        acknowledged.add(call.arguments['tap_token'] as String);
      return null;
    });
    final observer = _RouteObserver();
    await tester.pumpWidget(MaterialApp(
        navigatorKey: SimpleBus.navigatorKey,
        navigatorObservers: [observer],
        home: const SizedBox()));
    final first = payload('warm-tap-1', 'first');
    await NotificationService.markLaunchedFromNotification(first);
    await NotificationService.handlePendingNotificationNavigation();
    await NotificationService.markLaunchedFromNotification(first);
    await NotificationService.handlePendingNotificationNavigation();
    expect(observer.links, hasLength(1));
    await NotificationService.markLaunchedFromNotification(
        payload('warm-tap-2', 'second'));
    await NotificationService.handlePendingNotificationNavigation();
    expect(observer.links.map((l) => l.targets.single.trialId),
        ['first', 'second']);
    expect(acknowledged, ['warm-tap-1', 'warm-tap-2']);
    await tester.pumpWidget(const SizedBox());
  });
}
