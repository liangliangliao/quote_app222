import 'package:flutter/material.dart';

import 'xiangji_knowledge_repository.dart';

class XiangjiMentorSettingPage extends StatefulWidget {
  const XiangjiMentorSettingPage({
    super.key,
    required this.mentor,
    this.initialAnswers = const <String, String>{},
    this.onProgress,
  });

  final XiangjiKnowledgeSystem mentor;
  final Map<String, String> initialAnswers;
  final Future<void> Function(
    int stepIndex,
    Map<String, String> answers,
    bool completed,
  )? onProgress;

  @override
  State<XiangjiMentorSettingPage> createState() =>
      _XiangjiMentorSettingPageState();
}

class _XiangjiMentorSettingPageState
    extends State<XiangjiMentorSettingPage> {
  late final Map<String, String> _answers =
      Map<String, String>.of(widget.initialAnswers);
  late final TextEditingController _controller;
  int _index = 0;
  bool _saving = false;

  List<XiangjiMentorSettingStep> get _steps => widget.mentor.settingSteps;

  @override
  void initState() {
    super.initState();
    while (_index < _steps.length &&
        (_answers[_steps[_index].title] ?? '').trim().isNotEmpty) {
      _index++;
    }
    if (_index >= _steps.length) _index = _steps.length - 1;
    _controller = TextEditingController(
      text: _answers[_steps[_index].title] ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先用自己的话回答这一问；可以很短。')),
      );
      return;
    }
    _answers[_steps[_index].title] = value;
    final completed = _index == _steps.length - 1;
    setState(() => _saving = true);
    try {
      final callback = widget.onProgress;
      if (callback != null) {
        await callback(_index + 1, _answers, completed);
      }
      if (!mounted) return;
      if (completed) {
        Navigator.pop(context, Map<String, String>.of(_answers));
        return;
      }
      setState(() {
        _index++;
        _controller.text = _answers[_steps[_index].title] ?? '';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _previous() {
    if (_index == 0) return;
    _answers[_steps[_index].title] = _controller.text.trim();
    setState(() {
      _index--;
      _controller.text = _answers[_steps[_index].title] ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_index];
    final progress = (_index + 1) / _steps.length;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3EB),
      appBar: AppBar(
        title: Text('${widget.mentor.displayName} · 目标设定'),
        backgroundColor: const Color(0xFFF6F3EB),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    '第 ${_index + 1} / ${_steps.length} 步',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: LinearProgressIndicator(value: progress)),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                step.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(step.purpose, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 22),
              Card(
                color: const Color(0xFFE6EFE9),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    step.mentorQuestion,
                    style: const TextStyle(
                      fontSize: 19,
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: '用你的原话回答。这里不会自动公开，也不会成为 AI 对你的永久标签。',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '本步操作：${step.operation}\n产出：${step.outputArtifact}\n'
                '完成标准：${step.acceptanceCriteria}\n边界：${step.caution}',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  OutlinedButton(
                    onPressed: _saving || _index == 0 ? null : _previous,
                    child: const Text('上一步'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _next,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: Text(
                          _index == _steps.length - 1 ? '完成目标设定' : '保存并继续',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
