
import 'package:flutter/material.dart';
import 'diary_dao.dart';

class TagPickerPage extends StatefulWidget {
  final DiaryDao dao;
  final List<int> initialSelected;
  const TagPickerPage({super.key, required this.dao, required this.initialSelected});

  @override
  State<TagPickerPage> createState() => _TagPickerPageState();
}

class _TagPickerPageState extends State<TagPickerPage> {
  bool _loading = true;
  List<Tag> _tags = [];
  final Set<int> _selected = {};

  final _newCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.initialSelected);
    _load();
  }

  Future<void> _load() async {
    final list = await widget.dao.listTags();
    setState(() { _tags = list; _loading = false; });
  }

  Future<void> _addTag() async {
    final name = _newCtrl.text.trim();
    if (name.isEmpty) return;
    final id = await widget.dao.upsertTag(name);
    _newCtrl.clear();
    await _load();
    setState(() { _selected.add(id); });
  }

  void _done() {
    Navigator.pop(context, _selected.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('选择标签'), actions: [TextButton(onPressed: _done, child: const Text('完成'))]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(child: TextField(controller: _newCtrl, decoration: const InputDecoration(hintText: '新增标签', border: OutlineInputBorder(), isDense: true))),
              const SizedBox(width: 8),
              FilledButton(onPressed: _addTag, child: const Text('添加')),
            ]),
          ),
          Expanded(child: ListView.builder(
            itemCount: _tags.length,
            itemBuilder: (_, i) {
              final t = _tags[i];
              final checked = _selected.contains(t.id);
              return CheckboxListTile(
                value: checked,
                title: Text(t.name),
                onChanged: (v){ setState((){ if (v==true) _selected.add(t.id); else _selected.remove(t.id); }); },
              );
            },
          )),
        ],
      ),
    );
  }
}
