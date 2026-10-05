import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/platform/native_scheduler.dart';
import 'package:quote_app/evidence_growth/evidence_growth_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const native = MethodChannel('native.scheduler');
  const notifications = MethodChannel('dexterous.com/flutter/local_notifications');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var appEnabled = false, channelEnabled = false, grant = false;
  var requests = 0;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    appEnabled = false; channelEnabled = false; grant = false; requests = 0;
    messenger.setMockMethodCallHandler(native, (call) async {
      if (call.method == 'eg_notification_status') {
        return {'available':true, 'notifications':appEnabled && channelEnabled, 'exact':true};
      }
      throw MissingPluginException();
    });
    messenger.setMockMethodCallHandler(notifications, (call) async {
      if (call.method == 'areNotificationsEnabled') return appEnabled;
      if (call.method == 'requestNotificationsPermission') {
        requests++;
        appEnabled = grant;
        return grant;
      }
      throw MissingPluginException();
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(native, null);
    messenger.setMockMethodCallHandler(notifications, null);
  });
  test('already enabled module bypasses missing legacy permission method', () async {
    appEnabled = true; channelEnabled = true;
    expect(await const EvidenceGrowthNotificationService().ensureNotificationsEnabled(), isTrue);
    expect(requests, 0);
  });
  test('shared permission request recognizes already authorized app', () async {
    appEnabled = true;
    expect(await NativeScheduler.requestNotificationPermissionSystem(), isTrue);
    expect(requests, 0);
  });
  test('new authorization is rechecked against the module channel', () async {
    channelEnabled = true; grant = true;
    expect(await const EvidenceGrowthNotificationService().ensureNotificationsEnabled(), isTrue);
    expect(requests, 1);
  });
  test('denied authorization does not enable reminders', () async {
    channelEnabled = true;
    expect(await const EvidenceGrowthNotificationService().ensureNotificationsEnabled(), isFalse);
    expect(requests, 1);
  });
  test('disabled module channel is not mistaken for enabled app permission', () async {
    appEnabled = true;
    expect(await const EvidenceGrowthNotificationService().ensureNotificationsEnabled(), isFalse);
    expect(requests, 0);
  });
}
