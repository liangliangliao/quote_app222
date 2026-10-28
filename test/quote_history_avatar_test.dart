import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/widgets/quote_history_avatar.dart';

void main() {
  testWidgets('history avatar enlarges the circle and protects the head crop',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QuoteHistoryAvatar(
            key: ValueKey('history-avatar'),
            image: AssetImage('assets/avatars/talbenshahar .jpeg'),
            diameter: 56,
          ),
        ),
      ),
    );

    final avatar = find.byKey(const ValueKey('history-avatar'));
    expect(tester.getSize(avatar), const Size.square(56));
    expect(find.descendant(of: avatar, matching: find.byType(ClipOval)),
        findsOneWidget);
    final image = tester.widget<Image>(
      find.descendant(of: avatar, matching: find.byType(Image)),
    );
    expect(image.fit, BoxFit.cover);
    expect(image.alignment, Alignment.topCenter);
  });

  test('history page uses enlarged list and detail portraits', () {
    final source = File('lib/pages/history_page.dart').readAsStringSync();
    expect(source, contains('diameter: 56'));
    expect(source, contains('diameter: 96'));
    expect(source, contains('QuoteHistoryAvatar'));
  });
}
