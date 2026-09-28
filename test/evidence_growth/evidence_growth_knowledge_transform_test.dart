import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/evidence_growth/evidence_growth_knowledge.dart';
import 'package:quote_app/evidence_growth/evidence_growth_knowledge_transform.dart';

Map<String, dynamic> _valid() => {
      'core': '一次结果不是永久判决',
      'problem': '人们把一次失败想成世界末日，于是回避。',
      'examples': ['考试没考好后一周恢复', '被拒绝后第二天照常工作', '项目失败后仍能接新活'],
      'counter': '真正不可逆的事（如伤病致残）不适用“会恢复”。',
      'analogy': '像心情的“基准水位”，浪来了会退回去。',
      'differs': '水位是被动的，而基准线可以通过行动抬高。',
      'diagram': '成功 → 上升 → 回落到基准\n失败 → 下降 → 回升到基准',
      'explain': '好事坏事都会让心情起伏，但多数时候会回到原来的水平。',
      'selfCheck': '我过去有哪次失败后已经恢复了？',
      'rules': [
        {'trigger': '当我因为害怕失败想回避任务时', 'action': '我就先写下最坏结果和过去的恢复证据'}
      ],
      'experiment': {
        'action': '选一件拖着的小事，做 5 分钟',
        'predict': '预期难受程度 7/10',
        'check': '做完写实际难受程度，看差多少',
        'safety': '若明显恐慌就停下，找信任的人聊。'
      },
    };

void main() {
  test('parses a complete 6-step result and round-trips through JSON', () {
    final r = KnowledgeTransform.fromJson(_valid());
    expect(r.examples, hasLength(3));
    expect(r.rules.single.trigger, startsWith('当我'));
    final again = KnowledgeTransform.fromJson(r.toJson());
    expect(again.toPlainText('T'), r.toPlainText('T'));
    final text = r.toPlainText('T');
    for (final h in [
      '1 还原问题',
      '2 三正一反',
      '3 类比或画图',
      '4 用自己的话讲一遍',
      '5 压缩成行动规则',
      '6 马上小实验'
    ]) {
      expect(text, contains(h));
    }
  });

  test('rejects incomplete results instead of inventing content', () {
    final noExamples = _valid()..['examples'] = ['只有一个'];
    expect(() => KnowledgeTransform.fromJson(noExamples),
        throwsA(isA<FormatException>()));
    final noRules = _valid()..['rules'] = [];
    expect(() => KnowledgeTransform.fromJson(noRules),
        throwsA(isA<FormatException>()));
    final noDiffers = _valid()..['differs'] = '';
    expect(() => KnowledgeTransform.fromJson(noDiffers),
        throwsA(isA<FormatException>()));
  });

  test('optional fields fall back to the method\'s own wording', () {
    final json = _valid()
      ..['selfCheck'] = ''
      ..['diagram'] = ''
      ..['experiment'] = {
        'action': 'a',
        'predict': 'p',
        'check': 'c',
      };
    final r = KnowledgeTransform.fromJson(json);
    expect(r.selfCheck, KnowledgeTransform.defaultSelfCheck);
    expect(r.safety, KnowledgeTransform.defaultSafety);
    expect(r.diagram, isEmpty);
  });

  test('prompt carries only title and story, for every bundled card', () {
    expect(EvidenceGrowthKnowledge.talNodes, hasLength(142));
    for (final node in EvidenceGrowthKnowledge.bundledNodes) {
      final prompt = EvidenceGrowthKnowledgeTransform.buildPrompt(node);
      expect(prompt, contains(node.title.trim()), reason: node.id);
      expect(prompt, contains(node.storyOrStudy.trim()), reason: node.id);
    }
  });
}
