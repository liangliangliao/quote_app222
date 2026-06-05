import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/db.dart';
import 'diary_theme.dart';

class DiarySettingsPage extends StatefulWidget {
  const DiarySettingsPage({super.key});

  @override
  State<DiarySettingsPage> createState() => _DiarySettingsPageState();
}

class _DiarySettingsPageState extends State<DiarySettingsPage> {
  String? _bgPath;
  double _opacity = 0.25;
  final _pinCtrl = TextEditingController();
  bool _loaded = false;
  int? _targetConfigId; // 我们优先更新这一行

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await AppDatabase.ensureDiaryColumns();
    final db = await AppDatabase.instance();
    try {
      // 读取最近一条包含 diary 字段的记录
      final rows = await db.rawQuery(
          "SELECT id, diary_bg_image, diary_bg_opacity, diary_pin "
          "FROM configs "
          "WHERE (diary_bg_image IS NOT NULL OR diary_bg_opacity IS NOT NULL OR diary_pin IS NOT NULL) "
          "ORDER BY id DESC LIMIT 1");
      Map<String, Object?>? row;
      if (rows.isNotEmpty) {
        row = rows.first;
      } else {
        // 退化为最新一条（用于 update 目标行）
        final latest = await db.query('configs', columns: ['id'], orderBy: 'id DESC', limit: 1);
        if (latest.isNotEmpty) {
          _targetConfigId = latest.first['id'] as int?;
        }
      }
      if (row != null) {
        _targetConfigId = (row['id'] as int?);
        final op = row['diary_bg_opacity'];
        if (op != null) _opacity = double.tryParse(op.toString()) ?? _opacity;
        final pin = (row['diary_pin'] ?? '').toString();
        _pinCtrl.text = pin;
        final img = (row['diary_bg_image'] ?? '').toString();
        _bgPath = img.isEmpty ? null : img;
      }
    } catch (_) {
      // ignore
    }
    // 将读取到的配置同步到全局内存缓存，保证其它页面首帧即可使用正确背景
    DiaryTheme.updateInMemory(imagePath: _bgPath, opacity: _opacity);
    if (!mounted) return;
    setState(() => _loaded = true);
  }

  Future<String> _persistBgImageFromPath(String sourcePath) async {
    final src = File(sourcePath);
    if (!src.existsSync()) return sourcePath;
    final dir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(p.join(dir.path, 'diary_bg'));
    if (!targetDir.existsSync()) targetDir.createSync(recursive: true);
    final ext = p.extension(sourcePath).isNotEmpty ? p.extension(sourcePath) : '.jpg';
    final filename = 'bg_${DateTime.now().millisecondsSinceEpoch}$ext';
    final destPath = p.join(targetDir.path, filename);
    await src.copy(destPath);
    return destPath;
  }

  Future<String> _persistBgImageFromBytes(Uint8List bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(p.join(dir.path, 'diary_bg'));
    if (!targetDir.existsSync()) targetDir.createSync(recursive: true);
    final filename = 'bg_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final destPath = p.join(targetDir.path, filename);
    final f = File(destPath);
    await f.writeAsBytes(bytes, flush: true);
    return destPath;
  }

  Future<void> _pickBg() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (res == null || res.files.isEmpty) return;
    final file = res.files.single;
    String? dest;
    if (file.path != null && file.path!.isNotEmpty) {
      dest = await _persistBgImageFromPath(file.path!);
    } else if (file.bytes != null) {
      dest = await _persistBgImageFromBytes(file.bytes!);
    }
    if (dest != null) {
      setState(() => _bgPath = dest);
    }
  }

  Future<void> _save() async {
    await AppDatabase.ensureDiaryColumns();
    await AppDatabase.ensureDiaryColumns();
    final db = await AppDatabase.instance();
    final data = {
      'diary_bg_image': _bgPath,
      'diary_bg_opacity': _opacity,
      'diary_pin': _pinCtrl.text.trim(),
    };
    // 先刷新内存中的背景配置，确保后续打开日记页面首帧就是新样式
    DiaryTheme.updateInMemory(imagePath: _bgPath, opacity: _opacity);
    try {
      if (_targetConfigId != null) {
        await db.update('configs', data, where: 'id=?', whereArgs: [_targetConfigId]);
      } else {
        _targetConfigId = await db.insert('configs', data);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    }
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final exists = _bgPath != null && _bgPath!.isNotEmpty && File(_bgPath!).existsSync();
    return Scaffold(
      appBar: AppBar(title: const Text('日记设置')),
      body: ListView(
        children: [
          const ListTile(title: Text('背景设置')),
          ListTile(
            title: const Text('选择背景图'),
            subtitle: Text(exists ? _bgPath! : '未设置'),
            onTap: _pickBg,
          ),
          if (exists)
            ListTile(
              title: const Text('清除背景图'),
              onTap: () => setState(() => _bgPath = null),
            ),
          ListTile(
            title: const Text('背景透明度'),
            subtitle: Text('${(_opacity * 100).round()}%'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Slider(
              value: _opacity.clamp(0.0, 1.0),
              onChanged: (v) => setState(() => _opacity = v),
            ),
          ),
          const Divider(),
          const ListTile(title: Text('PIN 锁（进入日记模块时验证）')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _pinCtrl,
              decoration: const InputDecoration(
                labelText: '4位数字（留空表示不开启）',
                border: OutlineInputBorder(),
              ),
              maxLength: 4,
              keyboardType: TextInputType.number,
              obscureText: true,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: FilledButton(
              onPressed: _save,
              child: const Text('保存设置'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
