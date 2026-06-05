import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/will_module/will_deep_content_seed.dart';
import 'package:quote_app/will_module/will_unit_index_seed.dart';

void main() {
  test('导论中段单元也能获得非空深内容', () {
    final unit = kWillUnitIndexes.firstWhere((e) => e.id == 'D-048');
    final content = getWillDeepLessonContent(unit);
    expect(content.coreMeaning.isNotEmpty, isTrue);
    expect(content.practiceAction.isNotEmpty, isTrue);
  });

  test('观念—运动后段单元也能获得非空深内容', () {
    final unit = kWillUnitIndexes.firstWhere((e) => e.id == 'I-018');
    final content = getWillDeepLessonContent(unit);
    expect(content.reviewPrompt.isNotEmpty, isTrue);
    expect(content.mirrorZone.isNotEmpty, isTrue);
  });
}
