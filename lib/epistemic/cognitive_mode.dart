import 'package:flutter/material.dart';
import 'cognitive_preferences.dart';

/// A live mode boundary. Hidden enhancements never replace the legacy branch.
class CognitiveMode extends StatelessWidget {
  final Widget child, fallback;
  const CognitiveMode(
      {super.key,
      required this.child,
      this.fallback = const SizedBox.shrink()});
  @override
  Widget build(BuildContext context) {
    CognitivePreferenceStore.instance.load();
    return ValueListenableBuilder<CognitivePreferences>(
        valueListenable: CognitivePreferenceStore.instance,
        builder: (context, prefs, _) =>
            CognitivePreferenceStore.active ? child : fallback);
  }
}
