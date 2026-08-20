import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/models.dart';
import '../domain/controller.dart';

/// 回溯里新建出来的火种。返回给清单页，由它逐条弹判别式。
typedef KindlingCreatedItem = ({int id, String title});

/// 回溯会话：三问，一屏一问，顺序固定，不可跳过，可留空。
///
/// 第四屏把三段回答切成候选条目，由用户勾选哪些成为火种。
/// 全程不出现「你的目标是」「你想成为」这类措辞。
class KindlingRecallPage extends StatefulWidget {
  const KindlingRecallPage({super.key, required this.controller});

  static const Key nextKey = ValueKey<String>('kindling_recall_next');
  static const Key inputKey = ValueKey<String>('kindling_recall_input');
  static const Key doneKey = ValueKey<String>('kindling_recall_done');

  final KindlingController controller;

  @override
  State<KindlingRecallPage> createState() => _KindlingRecallPageState();
}

class _KindlingRecallPageState extends State<KindlingRecallPage> {
  final PageController _pager = PageController();
  late final List<TextEditingController> _inputs = List<TextEditingController>
      .generate(KRecallQuestion.ordered.length, (_) => TextEditingController());

  int _index = 0;
  bool _picking = false;
  bool _working = false;
  List<String> _candidates = const <String>[];
  final Set<String> _checked = <String>{};

  @override
  void dispose() {
    _pager.dispose();
    for (final TextEditingController c in _inputs) {
      c.dispose();
    }
    super.dispose();
  }

  /// 候选出自哪一问，就落哪一类。
  ///
  /// 用原话反查而不是让切分器带出来，是为了不动方案 §7 定死的
  /// extractCandidates 接口——换成 AI 追问器时同样适用；认不出来的
  /// （比如 AI 重写过措辞）落回 recall。
  String _kindOf(String candidate) {
    final Map<String, String> answers = _answers;
    for (final String key in KRecallQuestion.ordered) {
      if ((answers[key] ?? '').contains(candidate)) {
        return kindOfRecallQuestion(key);
      }
    }
    return KKind.recall;
  }

  Map<String, String> get _answers {
    final Map<String, String> map = <String, String>{};
    for (int i = 0; i < KRecallQuestion.ordered.length; i++) {
      map[KRecallQuestion.ordered[i]] = _inputs[i].text.trim();
    }
    return map;
  }

  Future<void> _next() async {
    if (_index < KRecallQuestion.ordered.length - 1) {
      setState(() => _index += 1);
      await _pager.animateToPage(
        _index,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
      return;
    }
    await _toPicking();
  }

  Future<void> _toPicking() async {
    setState(() => _working = true);
    final Map<String, String> answers = _answers;
    await widget.controller.saveRecall(answers);
    final List<String> candidates =
        await widget.controller.extractCandidates(answers);
    if (!mounted) return;
    setState(() {
      _candidates = candidates;
      _checked
        ..clear()
        ..addAll(candidates);
      _picking = true;
      _working = false;
    });
  }

  Future<void> _finish() async {
    if (_working) return;
    setState(() => _working = true);
    final List<String> picked = _candidates
        .where((String c) => _checked.contains(c))
        .toList(growable: false);
    final List<KCandidate> candidates = picked
        .map((String title) => (title: title, kind: _kindOf(title)))
        .toList(growable: false);
    final List<KindlingCreatedItem> created = <KindlingCreatedItem>[];
    if (candidates.isNotEmpty) {
      final List<int> ids =
          await widget.controller.addItemsFromRecall(candidates);
      for (int i = 0; i < ids.length && i < picked.length; i++) {
        created.add((id: ids[i], title: picked[i]));
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF2B2B2B),
        title: const Text(KCopy.recall, style: TextStyle(fontSize: 17)),
      ),
      body: SafeArea(
        child: _picking ? _buildPicking() : _buildQuestions(),
      ),
    );
  }

  Widget _buildQuestions() {
    return Column(
      children: <Widget>[
        Expanded(
          child: PageView.builder(
            controller: _pager,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: KRecallQuestion.ordered.length,
            onPageChanged: (int i) => setState(() => _index = i),
            itemBuilder: (BuildContext context, int i) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      KCopy.recallQuestions[i],
                      style: const TextStyle(
                        fontSize: 19,
                        height: 1.6,
                        color: Color(0xFF2B2B2B),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: TextField(
                        key: i == 0 ? KindlingRecallPage.inputKey : null,
                        controller: _inputs[i],
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: const TextStyle(fontSize: 16, height: 1.6),
                        decoration: const InputDecoration(
                          hintText: KCopy.writeHint,
                          hintStyle: TextStyle(color: Color(0xFFBBBBBB)),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: KindlingRecallPage.nextKey,
              onPressed: _working ? null : _next,
              style: _buttonStyle,
              child: Text(
                _index == KRecallQuestion.ordered.length - 1
                    ? KCopy.done
                    : KCopy.next,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPicking() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 6),
          child: Text(
            KCopy.pickHint,
            style: TextStyle(fontSize: 15, color: Color(0xFF8A8A8A)),
          ),
        ),
        Expanded(
          child: _candidates.isEmpty
              ? const Center(
                  child: Text(
                    KCopy.emptyCandidates,
                    style: TextStyle(fontSize: 15, color: Color(0xFFAAAAAA)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _candidates.length,
                  itemBuilder: (BuildContext context, int i) {
                    final String text = _candidates[i];
                    return CheckboxListTile(
                      value: _checked.contains(text),
                      onChanged: (bool? on) {
                        setState(() {
                          if (on ?? false) {
                            _checked.add(text);
                          } else {
                            _checked.remove(text);
                          }
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        text,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF2B2B2B),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: KindlingRecallPage.doneKey,
              onPressed: _working ? null : _finish,
              style: _buttonStyle,
              child: const Text(KCopy.done, style: TextStyle(fontSize: 16)),
            ),
          ),
        ),
      ],
    );
  }

  ButtonStyle get _buttonStyle => OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF2B2B2B),
        side: const BorderSide(color: Color(0xFFDDDDDD)),
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
}
