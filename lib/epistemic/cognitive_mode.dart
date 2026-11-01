import 'package:flutter/material.dart';
import 'cognitive_preferences.dart';

AnimationStyle? cognitiveExpansionStyle(BuildContext context) =>
    CognitivePreferenceStore.active &&
            (CognitivePreferenceStore.instance.value.reduceMotion ||
                MediaQuery.disableAnimationsOf(context))
        ? AnimationStyle.noAnimation
        : null;

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

class CognitiveDisabledView extends StatelessWidget {
  final String? originalText;
  const CognitiveDisabledView({super.key, this.originalText});

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(24), children: [
        const Text('叔本华认知风格已关闭',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        const Text('返回原页面即可继续使用默认模式。已保存的注释仍会保留。'),
        if (originalText != null) ...[
          const SizedBox(height: 24),
          SelectableText(originalText!),
        ],
        const SizedBox(height: 16),
        Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
                icon: const Icon(Icons.arrow_back),
                label: const Text('返回原页面'),
                onPressed: () => Navigator.maybePop(context))),
      ]);
}

/// A pushed enhancement route also follows the master switch while it is open.
class CognitiveModePage extends StatelessWidget {
  final String title;
  final Widget child;
  const CognitiveModePage(
      {super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) => CognitiveMode(
      child: child,
      fallback: Scaffold(
          appBar: AppBar(title: Text(title)),
          body: const CognitiveDisabledView()));
}
