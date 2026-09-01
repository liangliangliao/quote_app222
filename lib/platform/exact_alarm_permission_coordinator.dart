import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'native_scheduler.dart';

/// One user-facing permission flow for every feature backed by an exact alarm.
///
/// Callers await [ensureGranted] before changing their switch or persisting an
/// enabled state.  Android's grant broadcast brings the app task to the front;
/// this observer then verifies the grant and lets the original action continue.
class ExactAlarmPermissionCoordinator {
  ExactAlarmPermissionCoordinator._();

  static Future<bool>? _activeRequest;

  static Future<bool> ensureGranted(
    BuildContext context, {
    required String featureName,
    String? explanation,
  }) {
    final existing = _activeRequest;
    if (existing != null) return existing;
    final request = _ensureGranted(
      context,
      featureName: featureName,
      explanation: explanation,
    ).then((value) => value, onError: (_) => false);
    _activeRequest = request;
    unawaited(
      request.then((_) {
        if (identical(_activeRequest, request)) _activeRequest = null;
      }),
    );
    return request;
  }

  static Future<bool> _ensureGranted(
    BuildContext context, {
    required String featureName,
    String? explanation,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    if (await NativeScheduler.canScheduleExactAlarm()) return true;
    if (!context.mounted) return false;

    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.alarm_on_rounded, size: 34),
        title: const Text('先开启“闹钟和提醒”权限'),
        content: Text(
          '$featureName需要在你设定的时间准确触发。'
          '${explanation == null || explanation.trim().isEmpty ? '' : '\n\n${explanation.trim()}'}'
          '\n\n点击“前往授权”后，请打开系统页面中的允许开关。授权成功后会自动返回 App，并继续刚才的操作。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('暂不开启'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('前往授权'),
          ),
        ],
      ),
    );
    if (proceed != true || !context.mounted) return false;

    final resumeObserver = _ExactAlarmResumeObserver();
    WidgetsBinding.instance.addObserver(resumeObserver);
    try {
      final launched = await NativeScheduler.requestExactAlarmPermission();
      if (!launched) {
        _showMessage(context, '无法打开系统授权页，请在系统设置中允许“闹钟和提醒”。');
        return false;
      }

      // The grant broadcast normally brings MainActivity forward immediately.
      // Pressing Back from OEM settings pages reaches the same resume path.
      await resumeObserver.returned.timeout(
        const Duration(minutes: 3),
        onTimeout: () {},
      );
      for (final delay in const <Duration>[
        Duration.zero,
        Duration(milliseconds: 250),
        Duration(milliseconds: 650),
      ]) {
        if (delay != Duration.zero) await Future<void>.delayed(delay);
        if (await NativeScheduler.canScheduleExactAlarm()) {
          if (context.mounted)
            _showMessage(context, '精准闹钟权限已开启，$featureName已继续启用。');
          return true;
        }
      }
      if (context.mounted) {
        _showMessage(context, '尚未获得精准闹钟权限，$featureName保持关闭。');
      }
      await NativeScheduler.clearExactAlarmPermissionRequest();
      return false;
    } finally {
      WidgetsBinding.instance.removeObserver(resumeObserver);
    }
  }

  static void _showMessage(BuildContext context, String message) {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ExactAlarmResumeObserver with WidgetsBindingObserver {
  final Completer<void> _returned = Completer<void>();
  bool _leftApp = false;

  Future<void> get returned => _returned.future;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _leftApp = true;
      return;
    }
    if (_leftApp &&
        state == AppLifecycleState.resumed &&
        !_returned.isCompleted) {
      _returned.complete();
    }
  }
}
