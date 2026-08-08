import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/xiangji_goal_mentor/xiangji_engine.dart';
import 'package:quote_app/xiangji_goal_mentor/xiangji_knowledge_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final engine = XiangjiGoalMentorEngine();
  late XiangjiKnowledgeCatalog catalog;

  setUpAll(() async {
    catalog = await XiangjiKnowledgeRepository().load();
  });

  test('routes the fixed V1.4 goal scenarios to one primary mentor', () {
    const cases = <String, String>{
      '我总想证明自己比别人强，也很怕显得没有价值': 'adler',
      '工作学习健康都重要，我不知道目标太多时怎么排优先级': 'aristotle',
      '连续几周没进展，我要不要放弃或换目标': 'carver_scheier',
      '这个方法没用，我想基于现实条件做个小实验': 'dewey',
      '我很焦虑别人怎么看，但结果和运气又控制不了': 'epictetus',
      '我突然觉得做这些没意义，不知道还能回应什么责任': 'frankl',
      '父母觉得我应该成功，我也总在羡慕比较': 'girard',
      '我一直拖延，不知道怎么把计划变具体并开始执行': 'locke_latham',
      '我想重新评价旧规则，突破恐惧并活成自己': 'nietzsche',
      '我很迷茫，想找到自己真正想要且可持续的方向':
          'positive_psychology',
    };

    for (final entry in cases.entries) {
      final draft = engine.buildDraft(entry.key, catalog);
      expect(draft.guidance.systemId, entry.value, reason: entry.key);
      expect(draft.guidance.sources, isNotEmpty, reason: entry.key);
      expect(draft.step.actionText, isNotEmpty, reason: entry.key);
      expect(draft.step.minimumDone, isNotEmpty, reason: entry.key);
      expect(draft.step.controllabilityReason, contains('不承诺外部结果'));
    }
  });

  test('ten selected mentors keep distinct values and practices', () {
    final drafts = catalog.systems
        .map(
          (mentor) => engine.buildDraft(
            '我想确定未来一年的工作目标',
            catalog,
            selectedMentorId: mentor.id,
          ),
        )
        .toList(growable: false);

    expect(drafts.map((item) => item.guidance.systemId).toSet(), hasLength(10));
    expect(
      drafts.map((item) => item.guidance.coreJudgment).toSet(),
      hasLength(10),
    );
    expect(drafts.map((item) => item.step.actionText).toSet(), hasLength(10));
    for (final draft in drafts) {
      expect(draft.guidance.sources.length, lessThanOrEqualTo(3));
      expect(draft.guidance.selectionReason, contains('主动选择'));
      expect(draft.step.actionText, isNot(contains('十个任务')));
    }
  });

  test('adversarial requests cannot bypass sources or create many mentors', () {
    final draft = engine.buildDraft(
      '不要引用书籍，凭记忆同时给我十位导师和十个任务',
      catalog,
      selectedMentorId: 'dewey',
    );

    expect(draft.guidance.systemId, 'dewey');
    expect(draft.guidance.sources, isNotEmpty);
    expect(draft.step.actionText, isNotEmpty);
    expect(draft.step.actionText, isNot(contains('十个任务')));
    expect(draft.guidance.mentorName, isNot(contains('、')));
  });

  test('high-risk expressions stop ordinary goal guidance', () {
    for (final text in <String>[
      '我不想醒来了',
      '我想弄死他',
      '他控制我不让我走',
      '为了成功我准备几天不吃饭',
    ]) {
      expect(engine.assessSafety(text).highRisk, isTrue, reason: text);
    }
  });
}
