import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/xiangji_goal_mentor/xiangji_knowledge_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the complete goal-first V2.1 knowledge baseline', () async {
    final catalog = await XiangjiKnowledgeRepository().load();

    expect(catalog.version, '2.1.0');
    expect(catalog.defaultLayer, 'mentor_goal_core_v21');
    expect(catalog.systems, hasLength(10));
    expect(catalog.primaryThemeCount, 40);
    expect(catalog.secondaryThemeCount, 30);
    expect(catalog.evidenceCount, 350);
    expect(catalog.conciseProfiles, hasLength(10));
    expect(
      catalog.conciseProfiles.every((item) => item.defaultHidden),
      isTrue,
    );

    for (final mentor in catalog.systems) {
      expect(mentor.profile, isNotNull, reason: mentor.id);
      expect(mentor.primaryThemes, hasLength(4), reason: mentor.id);
      expect(mentor.secondaryThemes, hasLength(3), reason: mentor.id);
      expect(mentor.modules, hasLength(16), reason: mentor.id);
      expect(mentor.settingSteps, hasLength(8), reason: mentor.id);
      expect(mentor.practices, hasLength(6), reason: mentor.id);
      expect(mentor.diagnosticRoutes, hasLength(6), reason: mentor.id);
      expect(mentor.cases, hasLength(4), reason: mentor.id);
      expect(mentor.journey?.stages, hasLength(6), reason: mentor.id);
      expect(catalog.citationsFor(mentor), isNotEmpty, reason: mentor.id);
      expect(
        catalog.citationsFor(mentor).every(
              (item) =>
                  item.locator.isNotEmpty &&
                  item.summary.runes.length <= 181,
            ),
        isTrue,
        reason: mentor.id,
      );
    }
  });
}
