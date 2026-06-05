import 'package:flutter/material.dart';
import 'belief_models.dart';
import 'belief_dao.dart';

enum BeliefFlowKind { episode, mission }

class BeliefFlowPage extends StatefulWidget {
  final BeliefFlowKind kind;
  final String id;
  final String title;
  final String subtitle;
  final List<BeliefStep> steps;

  // Optional override for progress key (default: episode:<id> / mission:<id>).
  final String? progressKeyOverride;

  // Extra fields to persist into progress payload.
  final Map<String, dynamic>? extraPayload;

  const BeliefFlowPage({
    super.key,
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.steps,
    this.progressKeyOverride,
    this.extraPayload,
  });

  @override
  State<BeliefFlowPage> createState() => _BeliefFlowPageState();
}

class _BeliefFlowPageState extends State<BeliefFlowPage> {
  final _dao = BeliefDao();

  int _idx = 0;
  bool _loading = true;
  String? _err;

  // answers
  final Map<String, dynamic> _ans = {};

  // extra persisted fields (template metadata etc.)
  final Map<String, dynamic> _meta = {};
  final Map<String, TextEditingController> _textCtrls = {};

  String get _progressKey => widget.progressKeyOverride ?? '${widget.kind == BeliefFlowKind.episode ? 'episode' : 'mission'}:${widget.id}';

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    for (final c in _textCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _init() async {
    try {
      await _dao.seedIfNeeded();
      final p = await _dao.getProgress(_progressKey);
      if (p != null) {
        final payload = p.payload;
        final savedIdx = (payload['idx'] as num?)?.toInt();
        final savedAns = payload['ans'];
        if (savedIdx != null && savedIdx >= 0 && savedIdx < widget.steps.length) {
          _idx = savedIdx;
        }
        if (savedAns is Map) {
          savedAns.forEach((k, v) {
            _ans[k.toString()] = v;
          });
        }

        // keep extra fields
        payload.forEach((k, v) {
          final kk = k.toString();
          if (kk == 'idx' || kk == 'ans' || kk == 'title' || kk == 'subtitle') return;
          _meta[kk] = v;
        });
      }
      final extra = widget.extraPayload;
      if (extra != null && extra.isNotEmpty) {
        for (final e in extra.entries) {
          _meta.putIfAbsent(e.key, () => e.value);
        }
      }

      _primeControllers();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = e.toString();
      });
    }
  }

  void _primeControllers() {
    for (final s in widget.steps) {
      if (s.type == BeliefStepType.input) {
        final key = s.id;
        final existing = _textCtrls[key];
        if (existing == null) {
          final c = TextEditingController(text: (_ans[key] ?? '').toString());
          _textCtrls[key] = c;
        } else {
          existing.text = (_ans[key] ?? '').toString();
        }
      }
    }
  }

  Future<void> _save({int? status}) async {
    // sync text controllers
    for (final e in _textCtrls.entries) {
      _ans[e.key] = e.value.text;
    }
    final payload = {
      ..._meta,
      'idx': _idx,
      'ans': _ans,
      'title': widget.title,
      'subtitle': widget.subtitle,
    };
    await _dao.upsertProgress(_progressKey, status: status ?? 1, payload: payload);
  }

  BeliefStep get _step => widget.steps[_idx];

  bool _isStepComplete(BeliefStep s) {
    final v = _ans[s.id];
    if (!s.required) return true;
    switch (s.type) {
      case BeliefStepType.info:
        return true;
      case BeliefStepType.singleChoice:
        return (v is String) && v.isNotEmpty;
      case BeliefStepType.multiChoice:
        return (v is List) && v.isNotEmpty;
      case BeliefStepType.input:
        return (v is String) && v.trim().isNotEmpty;
      case BeliefStepType.checklist:
        return (v is Map) ? (v.values.any((x) => x == true)) : false;
      case BeliefStepType.rating:
        return v is num;
      case BeliefStepType.summary:
        return true;
    }
  }

  Future<void> _next() async {
    if (!_isStepComplete(_step)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('这一关还没完成：请先填写/选择后再继续。')),
      );
      return;
    }
    if (_idx < widget.steps.length - 1) {
      setState(() => _idx++);
      await _save();
    }
  }

  Future<void> _prev() async {
    if (_idx > 0) {
      setState(() => _idx--);
      await _save();
    }
  }

  Future<void> _finish() async {
    await _save(status: 2);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已完成并保存进度 ✅')));
    Navigator.pop(context);
  }

  Widget _buildStep(BeliefStep s) {
    switch (s.type) {
      case BeliefStepType.info:
        return _StepCard(title: s.title, body: s.body, child: const SizedBox.shrink());
      case BeliefStepType.singleChoice:
        final selected = (_ans[s.id] ?? '') as String;
        return _StepCard(
          title: s.title,
          body: s.body,
          child: Column(
            children: s.choices
                .map(
                  (c) => RadioListTile<String>(
                    value: c.id,
                    groupValue: selected.isEmpty ? null : selected,
                    title: Text(c.text),
                    subtitle: c.hint == null ? null : Text(c.hint!),
                    onChanged: (v) => setState(() => _ans[s.id] = v ?? ''),
                  ),
                )
                .toList(),
          ),
        );
      case BeliefStepType.multiChoice:
        final selected = (_ans[s.id] is List) ? List<String>.from(_ans[s.id] as List) : <String>[];
        return _StepCard(
          title: s.title,
          body: s.body,
          child: Column(
            children: s.choices
                .map(
                  (c) => CheckboxListTile(
                    value: selected.contains(c.id),
                    title: Text(c.text),
                    subtitle: c.hint == null ? null : Text(c.hint!),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          selected.add(c.id);
                        } else {
                          selected.remove(c.id);
                        }
                        _ans[s.id] = selected;
                      });
                    },
                  ),
                )
                .toList(),
          ),
        );
      case BeliefStepType.input:
        final ctrl = _textCtrls[s.id]!;
        return _StepCard(
          title: s.title,
          body: s.body,
          child: TextField(
            controller: ctrl,
            minLines: 4,
            maxLines: 10,
            decoration: InputDecoration(
              hintText: '在这里输入…',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onChanged: (v) => _ans[s.id] = v,
          ),
        );
      case BeliefStepType.checklist:
        final m = (_ans[s.id] is Map) ? Map<String, dynamic>.from(_ans[s.id] as Map) : <String, dynamic>{};
        return _StepCard(
          title: s.title,
          body: s.body,
          child: Column(
            children: s.checklist
                .map(
                  (t) => CheckboxListTile(
                    value: (m[t] == true),
                    title: Text(t),
                    onChanged: (v) => setState(() {
                      m[t] = (v == true);
                      _ans[s.id] = m;
                    }),
                  ),
                )
                .toList(),
          ),
        );
      case BeliefStepType.rating:
        final cur = (_ans[s.id] is num) ? (_ans[s.id] as num).toDouble() : s.minRating.toDouble();
        final min = s.minRating.toDouble();
        final max = s.maxRating.toDouble();
        return _StepCard(
          title: s.title,
          body: s.body,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Slider(
                value: cur.clamp(min, max),
                min: min,
                max: max,
                divisions: (max - min).toInt() == 0 ? null : (max - min).toInt(),
                label: cur.round().toString(),
                onChanged: (v) => setState(() => _ans[s.id] = v.round()),
              ),
              Text('当前：${cur.round()} / ${s.maxRating}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                '提示：评分不是考试，是为了让你看到“心态/可能性”在变化。',
                style: TextStyle(color: Colors.black.withOpacity(0.65)),
              ),
            ],
          ),
        );
      case BeliefStepType.summary:
        return _StepCard(
          title: s.title,
          body: s.body,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text('你已到达关卡结尾。点击下方“完成”保存为 ✅ Done。'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.steps.length;
    final pct = total == 0 ? 0.0 : ((_idx + 1) / total);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: '保存',
            onPressed: _loading ? null : () async {
              await _save();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存进度')));
            },
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: _err != null
          ? Center(child: Text(_err!))
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.subtitle, style: TextStyle(color: Colors.black.withOpacity(0.7))),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(value: pct),
                          ),
                          const SizedBox(height: 6),
                          Text('进度：${_idx + 1} / $total', style: TextStyle(color: Colors.black.withOpacity(0.65))),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        children: [
                          _buildStep(_step),
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _idx == 0 ? null : () => _prev(),
                                child: const Text('上一步'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  // last step
                                  if (_idx == widget.steps.length - 1) {
                                    if (!_isStepComplete(_step)) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('请先完成当前内容再结束。')),
                                      );
                                      return;
                                    }
                                    await _finish();
                                  } else {
                                    await _next();
                                  }
                                },
                                child: Text(_idx == widget.steps.length - 1 ? '完成' : '下一步'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String title;
  final String body;
  final Widget child;

  const _StepCard({required this.title, required this.body, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 6),
            color: Colors.black.withOpacity(0.04),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(body, style: TextStyle(color: Colors.black.withOpacity(0.75), height: 1.45)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
