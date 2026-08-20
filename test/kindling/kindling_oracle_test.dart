import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/kindling/kindling.dart';
import 'package:quote_app/kindling/src/copy.dart';
import 'package:quote_app/kindling/src/data/models.dart';

void main() {
  const LocalOracle oracle = LocalOracle();

  test('candidates are split on line breaks and Chinese punctuation',
      () async {
    final List<String> out = await oracle.extractCandidates(<String, String>{
      KRecallQuestion.lostTrack: '改渲染管线到三点。修一个老 bug；顺手写了点笔记',
      KRecallQuestion.itch: '把 §9 那段译完\n写「一个人如何被消耗掉」',
      KRecallQuestion.envy: '',
    });

    expect(out, <String>[
      '改渲染管线到三点',
      '修一个老 bug',
      '顺手写了点笔记',
      '把 §9 那段译完',
      '写「一个人如何被消耗掉」',
    ]);
  });

  test('too short, too long and duplicate fragments are dropped', () async {
    final String long = '啊' * (LocalOracle.maxLength + 1);
    final List<String> out = await oracle.extractCandidates(<String, String>{
      KRecallQuestion.lostTrack: '好\n$long\n把 §9 那段译完',
      KRecallQuestion.itch: '把 §9 那段译完',
      KRecallQuestion.envy: '   ',
    });
    expect(out, <String>['把 §9 那段译完']);
  });

  test('list markers are stripped from candidates', () async {
    final List<String> out = await oracle.extractCandidates(<String, String>{
      KRecallQuestion.itch: '- 修渲染 bug\n1. 译完第九节\n• 写那篇长文',
    });
    expect(out, <String>['修渲染 bug', '译完第九节', '写那篇长文']);
  });

  test('the resistance ladder asks four questions and then stops', () async {
    final List<({String q, String? a})> history = <({String q, String? a})>[];
    final List<String> asked = <String>[];

    while (true) {
      final String? q = await oracle.nextResistanceQuestion(history);
      if (q == null) break;
      asked.add(q);
      history.add((q: q, a: null));
      expect(asked.length, lessThanOrEqualTo(8));
    }

    expect(asked, KCopy.resistanceLadder);
    expect(asked.last, KCopy.resistance4);
  });
}
