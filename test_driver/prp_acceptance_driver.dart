import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final root = Directory('build/prp/device-evidence')
    ..createSync(recursive: true);
  await integrationDriver(onScreenshot: (name, bytes, [args]) async {
    if (bytes.isEmpty || !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(name))
      return false;
    await File('${root.path}/$name.png').writeAsBytes(bytes, flush: true);
    return true;
  }, responseDataCallback: (data) async {
    final summary = Map<String, dynamic>.from(data ?? {})
      ..remove('screenshots');
    await File('${root.path}/flutter-results.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(summary));
  });
}
