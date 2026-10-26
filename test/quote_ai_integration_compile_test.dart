import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/pages/history_page.dart';
import 'package:quote_app/pages/settings_page.dart';
import 'package:quote_app/services/scheduler_service.dart';
import 'package:quote_app/services/task_runner.dart';

void _typeCheck<T>() {}

void main() {
  test('AI quote UI and scheduling modules compile together', () {
    expect(const SettingsPage(), isA<SettingsPage>());
    expect(const HistoryPage(), isA<HistoryPage>());
    _typeCheck<SchedulerService>();
    _typeCheck<TaskRunner>();
  });
}
