import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/services/quote_frame_theme.dart';

void main() {
  group('semantic frame classification', () {
    test('千里之行 routes to journey, not generic wood frame', () {
      final theme = QuoteFrameTheme.resolve(topic: '行动', quote: '千里之行，始于足下。');
      expect(theme.scene, QuoteScene.journey);
      expect(theme.label, '山间小径');
    });

    test('resilience has a storm-resistant tree', () {
      final theme = QuoteFrameTheme.resolve(topic: '面对困难', quote: '失败不是终点，重要的是站起来。');
      expect(theme.scene, QuoteScene.resilience);
    });

    test('title topic outranks incidental words in the quote', () {
      final theme = QuoteFrameTheme.resolve(topic: '平静与接纳', quote: '当下的内心可以从恐惧中恢复。');
      expect(theme.scene, QuoteScene.serenity);
    });

    test('hope chooses dawn scene', () {
      final theme = QuoteFrameTheme.resolve(topic: '希望', quote: '黑暗过去，便是黎明。');
      expect(theme.scene, QuoteScene.hope);
    });

    test('English tags work as well', () {
      final theme = QuoteFrameTheme.resolve(topic: 'freedom', quote: 'Freedom is worth protecting.');
      expect(theme.scene, QuoteScene.freedom);
    });

    test('unknown content has a dignified fallback', () {
      final theme = QuoteFrameTheme.resolve(topic: '', quote: '无匹配文本');
      expect(theme.scene, QuoteScene.reflection);
      expect(theme.imageScene, isNotEmpty);
    });
  });
}
