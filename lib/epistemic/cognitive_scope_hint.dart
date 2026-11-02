import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'cognitive_hint_budget.dart';
import 'cognitive_preferences.dart';
import 'cognitive_usage.dart';
import 'cognitive_mode.dart';

class AbsoluteClaim {
  final int start, end;
  final String text, quantifier;
  const AbsoluteClaim(this.start, this.end, this.text, this.quantifier);
}

AbsoluteClaim? findAbsoluteClaim(String text) {
  final quantifiers =
      RegExp(r'总是|永远|一定|每次都|从来不|必然|\balways\b|\bnever\b', caseSensitive: false);
  for (final sentence in RegExp(r'[^。！？!?；;\n]+[。！？!?；;]?').allMatches(text)) {
    final value = sentence.group(0)!;
    for (final word in quantifiers.allMatches(value)) {
      final prefix = value.substring(math.max(0, word.start - 6), word.start);
      if (RegExp(r'(不|并非|未必|不是|并不|不能说|不见得)\s*$').hasMatch(prefix)) continue;
      return AbsoluteClaim(sentence.start, sentence.end, value, word.group(0)!);
    }
  }
  return null;
}

/// A local, dismissible invitation beside an existing input. It neither saves
/// a draft nor calls AI. Saving remains the host editor's original operation.
class CognitiveScopeHint extends StatefulWidget {
  final TextEditingController controller;
  final CognitiveHintBudget? budget;
  final Duration debounce;
  const CognitiveScopeHint(
      {super.key,
      required this.controller,
      this.budget,
      this.debounce = const Duration(milliseconds: 650)});
  @override
  State<CognitiveScopeHint> createState() => _CognitiveScopeHintState();
}

class _CognitiveScopeHintState extends State<CognitiveScopeHint> {
  late final _budget = widget.budget ?? CognitiveHintBudget();
  Timer? _timer;
  AbsoluteClaim? _claim;
  bool _claimed = false, _dismissed = false, _checking = false;
  bool get _allowed =>
      CognitivePreferenceStore.active &&
      CognitivePreferenceStore.instance.value.prompts;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    CognitivePreferenceStore.instance.addListener(_changed);
    CognitivePreferenceStore.instance.load().then((_) {
      if (mounted) _changed();
    });
    _changed();
  }

  @override
  void didUpdateWidget(CognitiveScopeHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
      _changed();
    }
  }

  void _changed() {
    _timer?.cancel();
    if (!_allowed || _dismissed) {
      if (mounted && _claim != null) setState(() => _claim = null);
      return;
    }
    _timer = Timer(widget.debounce, _check);
  }

  Future<void> _check() async {
    if (!mounted || !_allowed || _dismissed || _checking) return;
    final claim = findAbsoluteClaim(widget.controller.text);
    if (claim == null) {
      setState(() => _claim = null);
      return;
    }
    _checking = true;
    try {
      if (!_claimed) {
        _claimed = await _budget.claim();
        if (_claimed)
          CognitiveUsageStore.instance.track(CognitiveEvent.hintShown);
      }
      if (mounted && _allowed && !_dismissed && _claimed) {
        setState(() => _claim = findAbsoluteClaim(widget.controller.text));
      }
    } catch (_) {/* Optional hints never interrupt the input. */} finally {
      _checking = false;
    }
  }

  void _open() {
    final claim = findAbsoluteClaim(widget.controller.text);
    if (claim == null || !_allowed) return;
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) => ConstrainedBox(
            constraints:
                BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * .75),
            child: CognitiveMode(
                fallback: CognitiveDisabledView(originalText: claim.text),
                child: SafeArea(
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('还有哪些可能',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 12),
                              SelectableText(claim.text),
                              const SizedBox(height: 16),
                              Text(
                                  '“${claim.quantifier}”的范围：这一次的观察是否足以说明所有时间、对象和处境？'),
                              const SizedBox(height: 12),
                              const Text(
                                  '可能反例：是否有过一次不同的结果，或另一个条件下的例外？没有材料时，先保留未知。'),
                              const SizedBox(height: 12),
                              const Text('可检验问题：再观察哪件具体事情？出现什么新材料，你会调整这个判断？'),
                              const SizedBox(height: 12),
                              const Text(
                                  '感受可以保留，判断仍可修订。此处为本地通用提示；保存原文后可自愿进一步分析。'),
                            ]))))));
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_changed);
    CognitivePreferenceStore.instance.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => !_allowed || _claim == null
      ? const SizedBox.shrink()
      : Row(children: [
          Expanded(
              child: TextButton.icon(
                  onPressed: _open,
                  icon: const Icon(Icons.help_outline, size: 18),
                  label: const Text('看看这句话的适用范围', softWrap: true))),
          IconButton(
              tooltip: '跳过这次范围提示',
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                setState(() {
                  _dismissed = true;
                  _claim = null;
                });
                CognitiveUsageStore.instance.track(CognitiveEvent.hintSkipped);
              }),
        ]);
}
