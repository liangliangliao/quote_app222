import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/epistemic/cognitive_mode.dart';
import 'package:quote_app/epistemic/cognitive_preferences.dart';
import 'package:quote_app/epistemic/cognitive_training.dart';
import 'package:quote_app/epistemic/cognitive_settings.dart';

void main() {
  testWidgets(
      'build flag overrides saved enabled mode and preserves legacy fallback',
      (tester) async {
    CognitivePreferenceStore.instance.value =
        const CognitivePreferences(enabled: true);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: Column(children: [
      CognitiveMode(fallback: Text('原有模式'), child: Text('认知风格')),
      CognitiveTrainingPanel(),
      CognitiveSettingsSection(),
    ])))));
    expect(
        tester
            .widget<SwitchListTile>(
                find.byKey(const ValueKey('schopenhauer-style-toggle')))
            .value,
        CognitivePreferenceStore.enabledInBuild);
    if (CognitivePreferenceStore.enabledInBuild) {
      expect(find.text('认知风格'), findsOneWidget);
      expect(find.text('识别共同点'), findsOneWidget);
    } else {
      expect(find.text('原有模式'), findsOneWidget);
      expect(find.text('认知风格'), findsNothing);
      expect(find.text('识别共同点'), findsNothing);
    }
  });
}
