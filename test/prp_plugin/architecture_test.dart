import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quote_app/prp_plugin/src/store.dart';

void main() {
  final imports = RegExp("import\\s+['\"]([^'\"]+)['\"]");
  test('plugin core imports no app module, DAO, AI service or host adapter',
      () {
    final root = Directory('lib/prp_plugin').absolute.path;
    for (final file in Directory(root)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      for (final match in imports.allMatches(file.readAsStringSync())) {
        final uri = match.group(1)!;
        if (uri.startsWith('dart:') ||
            (uri.startsWith('package:') &&
                !uri.startsWith('package:quote_app/'))) continue;
        final target = p.normalize(p.join(file.parent.path, uri));
        expect(p.isWithin(root, target), true,
            reason: '${file.path} imports $uri');
      }
    }
  });
  test('calling modules import only the plugin facade', () {
    for (final directory in [
      'lib/beautiful_enemy',
      'lib/behavior_tracking',
      'lib/failure_module',
      'lib/kindling'
    ]) {
      for (final file in Directory(directory)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        for (final match in imports.allMatches(file.readAsStringSync())) {
          final uri = match.group(1)!;
          if (uri.contains('prp_plugin/'))
            expect(uri.endsWith('prp_plugin/prp_plugin.dart'), true,
                reason: file.path);
        }
      }
    }
  });
  test('PRP schema statements only create PRP tables and indexes', () {
    for (final sql in PrpSchema.statements) {
      expect(
          RegExp(r'^CREATE (TABLE|INDEX) IF NOT EXISTS (prp_|idx_prp_)')
              .hasMatch(sql.trim()),
          true,
          reason: sql);
      expect(RegExp(r'\b(ALTER|DROP)\b', caseSensitive: false).hasMatch(sql),
          false);
    }
  });
}
