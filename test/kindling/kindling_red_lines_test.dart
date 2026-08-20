import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/kindling/src/copy.dart';

/// 设计红线的静态检查：把方案 §0、§6、§10 的禁令固定成测试。
void main() {
  final Directory moduleDir = Directory('lib/kindling');

  List<File> dartFiles(Directory dir) => dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList(growable: false);

  /// 去掉注释，只留下会被编译进界面的代码。
  String stripComments(String source) {
    final List<String> kept = <String>[];
    bool inBlock = false;
    for (String line in source.split('\n')) {
      if (inBlock) {
        final int end = line.indexOf('*/');
        if (end < 0) continue;
        line = line.substring(end + 2);
        inBlock = false;
      }
      final int block = line.indexOf('/*');
      if (block >= 0) {
        inBlock = true;
        line = line.substring(0, block);
      }
      final int slash = line.indexOf('//');
      if (slash >= 0) line = line.substring(0, slash);
      kept.add(line);
    }
    return kept.join('\n');
  }

  setUpAll(() {
    expect(
      moduleDir.existsSync(),
      isTrue,
      reason: '测试需要从仓库根目录运行',
    );
  });

  test('no copy carries an exclamation mark or a pep-talk word', () {
    final String copySource = File('lib/kindling/src/copy.dart').readAsStringSync();
    final String code = stripComments(copySource);

    expect(code.contains('！'), isFalse);
    expect(code.contains('!'), isFalse);

    for (final String banned in <String>[
      '加油',
      '相信自己',
      '你可以',
      '太棒了',
      '真棒',
      '不妨',
      '试试看',
      '建议',
      '继续保持',
      '恭喜',
    ]) {
      expect(
        code.contains(banned),
        isFalse,
        reason: '文案里不得出现「$banned」',
      );
    }
  });

  test('the module never speaks of streaks, badges, ranking or sharing', () {
    for (final File file in dartFiles(moduleDir)) {
      final String code = stripComments(file.readAsStringSync());
      for (final String banned in <String>[
        '打卡',
        '连击',
        '徽章',
        '排行',
        '完成率',
        '百分比',
        'streak',
        'badge',
        'leaderboard',
        'ranking',
      ]) {
        expect(
          code.toLowerCase().contains(banned.toLowerCase()),
          isFalse,
          reason: '${file.path} 出现了「$banned」',
        );
      }
    }
  });

  test('no progress indicator or percentage is rendered', () {
    // 百分号只在取模运算里合法，不得出现在任何字符串字面量中。
    final RegExp percentInLiteral = RegExp(r"'[^'\n]*%[^'\n]*'");
    for (final File file in dartFiles(moduleDir)) {
      final String code = stripComments(file.readAsStringSync());
      for (final String banned in <String>[
        'LinearProgressIndicator',
        'CircularProgressIndicator',
        'LinearProgressIndicator(',
      ]) {
        expect(
          code.contains(banned),
          isFalse,
          reason: '${file.path} 出现了「$banned」',
        );
      }
      expect(
        percentInLiteral.hasMatch(code),
        isFalse,
        reason: '${file.path} 的字面量里出现了百分号',
      );
    }
  });

  test('UI files hold no literal copy of their own', () {
    final RegExp cjk = RegExp(r'[一-鿿]');
    for (final File file in dartFiles(Directory('lib/kindling/src/ui'))) {
      final String code = stripComments(file.readAsStringSync());
      expect(
        cjk.hasMatch(code),
        isFalse,
        reason: '${file.path} 里写了字面量文案，应集中到 copy.dart',
      );
    }
  });

  test('the module depends on nothing beyond flutter and sqflite', () {
    final RegExp packageImport = RegExp(r"""import\s+'package:([a-z0-9_]+)/""");
    for (final File file in dartFiles(moduleDir)) {
      for (final RegExpMatch m
          in packageImport.allMatches(file.readAsStringSync())) {
        expect(
          <String>['flutter', 'sqflite'],
          contains(m.group(1)),
          reason: '${file.path} 引入了 ${m.group(1)}',
        );
      }
    }
  });

  test('the recall questions keep their fixed wording and order', () {
    expect(KCopy.recallQuestions, <String>[
      KCopy.qLostTrack,
      KCopy.qItch,
      KCopy.qEnvy,
    ]);
    for (final String q in KCopy.recallQuestions) {
      for (final String banned in <String>['你的目标是', '你想成为']) {
        expect(q.contains(banned), isFalse);
      }
    }
  });
}
