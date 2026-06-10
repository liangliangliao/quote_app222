import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/external_data/todo_failure_growth_engine.dart';

void main() {
  const engine = TodoFailureGrowthEngine();

  test('turns perfectionistic delay into a 70 percent experiment', () {
    final draft = engine.build(
      event: '文章一直没有发布',
      emotion: '焦虑',
      automaticThought: '我还没准备好，必须做到完美',
      fearedOutcome: '别人觉得我水平很差',
    );

    expect(draft.patternCode, 'perfectionism');
    expect(draft.experimentTitle, contains('70 分'));
    expect(draft.minimumStandard, contains('30 分钟'));
  });

  test('separates identity judgment from behavioral feedback', () {
    final draft = engine.build(
      event: '汇报没有讲清楚',
      emotion: '羞耻',
      automaticThought: '我就是不行',
      fearedOutcome: '不适合这份工作',
    );

    expect(draft.patternCode, 'identity_failure');
    expect(draft.factStatement, contains('尚未被证实'));
    expect(draft.growthReframe, contains('不是“你是谁”'));
  });
}
