import 'dart:convert';
import 'package:flutter/material.dart';
import '../fp_dao.dart';
import '../fp_models.dart';

class FpJournalPage extends StatefulWidget {
  const FpJournalPage({super.key});

  @override
  State<FpJournalPage> createState() => _FpJournalPageState();
}

class _FpJournalPageState extends State<FpJournalPage> {
  final _dao = FpDao();
  bool _loading = true;
  String? _err;
  List<FpLearningCard> _cards = const [];
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cs = await _dao.listLearningCards(limit: 300);
      if (!mounted) return;
      setState(() {
        _cards = cs;
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

  Future<void> _create() async {
    await _dao.addLearningCard(title: '学习卡', body: '', tags: ['failure_perfectionism']);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_err != null) return Center(child: Text(_err!));

    final q = _q.trim().toLowerCase();
    final xs = q.isEmpty
        ? _cards
        : _cards
            .where((c) => c.title.toLowerCase().contains(q) || c.body.toLowerCase().contains(q) || c.tagsJson.toLowerCase().contains(q))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: '搜索学习卡',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _q = v),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('新建'),
              )
            ],
          ),
        ),
        Expanded(
          child: xs.isEmpty
              ? const Center(child: Text('还没有学习卡。完成一次练习会自动生成。'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                  itemCount: xs.length,
                  itemBuilder: (context, i) {
                    final c = xs[i];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.black.withOpacity(0.08)),
                      ),
                      child: ListTile(
                        title: Text(c.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(c.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'edit') {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => _LearningCardEditor(card: c)),
                              );
                              await _load();
                            }
                            if (v == 'delete') {
                              await _dao.deleteLearningCard(c.id);
                              await _load();
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('编辑')),
                            PopupMenuItem(value: 'delete', child: Text('删除')),
                          ],
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => _LearningCardEditor(card: c)),
                          );
                          await _load();
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _LearningCardEditor extends StatefulWidget {
  final FpLearningCard card;
  const _LearningCardEditor({required this.card});

  @override
  State<_LearningCardEditor> createState() => _LearningCardEditorState();
}

class _LearningCardEditorState extends State<_LearningCardEditor> {
  final _dao = FpDao();
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _tags;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.card.title);
    _body = TextEditingController(text: widget.card.body);
    final tags = (() {
      try {
        final xs = jsonDecode(widget.card.tagsJson);
        if (xs is List) return xs.map((e) => e.toString()).join(',');
      } catch (_) {}
      return '';
    })();
    _tags = TextEditingController(text: tags);
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final tags = _tags.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    await _dao.updateLearningCard(
      id: widget.card.id,
      title: _title.text.trim().isEmpty ? '学习卡' : _title.text.trim(),
      body: _body.text,
      tags: tags,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑学习卡'),
        actions: [
          IconButton(onPressed: _save, icon: const Icon(Icons.save)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: '标题', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tags,
            decoration: const InputDecoration(labelText: '标签（逗号分隔）', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            maxLines: 12,
            decoration: const InputDecoration(labelText: '内容', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('保存')),
        ],
      ),
    );
  }
}
