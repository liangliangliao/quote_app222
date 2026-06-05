import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class NotepadPage extends StatefulWidget {
  const NotepadPage({super.key});
  @override
  State<NotepadPage> createState() => _NotepadPageState();
}

class _NotepadPageState extends State<NotepadPage> {
  final _ctrl = TextEditingController();
  late File _file;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/quick_note.txt');
    if (await _file.exists()) {
      _ctrl.text = await _file.readAsString();
    }
    setState(() { _loaded = true; });
  }

  Future<void> _save() async {
    try { await _file.writeAsString(_ctrl.text); } catch (_) {}
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存到本地')));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      appBar: AppBar(title: const Text('记事本')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _ctrl,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '写点什么……',
          ),
          keyboardType: TextInputType.multiline,
          maxLines: null,
          minLines: 12,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _save,
        child: const Icon(Icons.save),
      ),
    );
  }
}