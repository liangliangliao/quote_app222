import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'meditation_ai_service.dart';
import 'meditation_dao.dart';
import 'meditation_models.dart';
import 'meditation_player_page.dart';
import 'meditation_script_pause_planner.dart';

class MeditationScriptImportPage extends StatefulWidget {
  const MeditationScriptImportPage({super.key});

  @override
  State<MeditationScriptImportPage> createState() => _MeditationScriptImportPageState();
}

class _MeditationScriptImportPageState extends State<MeditationScriptImportPage> {
  final _dao = MeditationDao();
  final _aiService = MeditationAiService();
  MeditationSessionTemplate? _preview;
  String? _rawText;
  String? _fileName;
  String? _error;
  String? _tip;
  bool _saving = false;
  bool _generating = false;
  bool _preferAi = true;
  int _targetDurationMinutes = 10;
  String _processMode = 'preserve';
  String _meditationType = '睡前放松';
  String _pauseStyle = '标准停顿';

  static const List<int> _durationOptions = <int>[8, 10, 12, 15, 20, 30, 45, 60];
  static const List<String> _typeOptions = <String>[
    '睡前放松',
    '呼吸稳定',
    '身体扫描',
    '情绪脱钩',
    '反刍中断',
    '自我接纳',
    '专注回收',
    '本地脚本',
  ];
  static const List<String> _pauseStyles = <String>['较少停顿', '标准停顿', '较长留白', '深度留白'];

  Future<void> _pickScript() async {
    setState(() {
      _error = null;
      _tip = null;
      _preview = null;
      _rawText = null;
      _fileName = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['txt', 'md', 'markdown', 'json'],
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      List<int>? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) {
        setState(() => _error = '未能读取文件内容，请选择 txt、md 或 json 文本脚本。');
        return;
      }
      final text = _decodeText(bytes);
      if (!mounted) return;
      setState(() {
        _rawText = text;
        _fileName = file.name;
        _targetDurationMinutes = _readExplicitMinutes(text) ?? _targetDurationMinutes;
        _meditationType = _guessType(text);
        _tip = '已读取脚本：${file.name}。请设置时长和停顿方式后生成预览。';
      });
      await _generatePreview(preferAi: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '导入失败：$e');
    }
  }

  MeditationScriptBuildOptions _options() => MeditationScriptBuildOptions(
        targetDurationMinutes: _targetDurationMinutes,
        meditationType: _meditationType,
        pauseStyle: _pauseStyle,
        processMode: _processMode,
      );

  Future<void> _generatePreview({required bool preferAi}) async {
    final raw = _rawText;
    final name = _fileName;
    if (raw == null || raw.trim().isEmpty || name == null) {
      setState(() => _error = '请先选择本地冥想脚本。');
      return;
    }
    setState(() {
      _generating = true;
      _error = null;
      _tip = preferAi ? '正在尽量保留原文并标注停顿……' : '正在用本地规则插入停顿……';
    });
    try {
      MeditationSessionTemplate? session;
      if (preferAi) {
        session = await _aiService.annotateUploadedScriptWithPauses(
          rawScript: raw,
          fileName: name,
          options: _options(),
        );
      }
      session ??= MeditationScriptPausePlanner.buildLocal(
        rawText: raw,
        fileName: name,
        options: _options(),
      );
      if (!mounted) return;
      final builtSession = session;
      if (builtSession == null) {
        setState(() => _error = '生成失败：未能生成可用的冥想脚本。');
        return;
      }
      setState(() {
        _preview = builtSession;
        _tip = preferAi && builtSession.source == 'local_imported'
            ? '已生成带停顿脚本。若 AI 不可用，系统已自动使用本地规则兜底。'
            : '已生成带停顿脚本。';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '生成失败：$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _save({required bool startAfterSave}) async {
    final session = _preview;
    if (session == null) return;
    setState(() => _saving = true);
    try {
      await _dao.upsertCustomSession(session);
      if (!mounted) return;
      if (startAfterSave) {
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => MeditationPlayerPage(session: session, currentState: '本地上传')),
        );
        if (!mounted) return;
        Navigator.of(context).pop(changed == true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存到练习库的“本地上传”分组')));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _decodeText(List<int> bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(title: const Text('上传冥想脚本')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(20)),
            child: const Text(
              '支持从本地选择 txt、md、json 冥想脚本。系统会尽量保留原文主体，只做轻微断句，并在句子之间插入可被播放器识别的停顿，冥想时会真实静默留白。',
              style: TextStyle(height: 1.55),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _saving || _generating ? null : _pickScript,
            icon: const Icon(Icons.upload_file),
            label: Text(_fileName == null ? '选择本地脚本' : '重新选择脚本'),
          ),
          if ((_fileName ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('当前脚本：$_fileName', style: const TextStyle(color: Colors.black54)),
          ],
          const SizedBox(height: 18),
          _buildOptionsCard(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _rawText == null || _saving || _generating ? null : () => _generatePreview(preferAi: _preferAi),
                  icon: _generating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome),
                  label: Text(_generating ? '生成中……' : '生成带停顿脚本'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _rawText == null || _saving || _generating ? null : () => _generatePreview(preferAi: false),
                child: const Text('本地规则'),
              ),
            ],
          ),
          if (_tip != null) ...[
            const SizedBox(height: 12),
            Text(_tip!, style: const TextStyle(color: Colors.black54, height: 1.45)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.deepOrange, height: 1.45)),
          ],
          if (preview != null) ...[
            const SizedBox(height: 18),
            _buildPreviewCard(preview),
          ],
          const SizedBox(height: 16),
          const Text(
            '停顿格式说明：你也可以在原文中手动写入 [pause 10s]，系统会把它解析成真实静默停顿，TTS 不会朗读该标记。',
            style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.black.withOpacity(0.06))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('生成设置', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _durationOptions.contains(_targetDurationMinutes) ? _targetDurationMinutes : 10,
              decoration: const InputDecoration(labelText: '目标时长', border: OutlineInputBorder()),
              items: _durationOptions.map((m) => DropdownMenuItem(value: m, child: Text('$m 分钟'))).toList(),
              onChanged: (v) => setState(() => _targetDurationMinutes = v ?? 10),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _typeOptions.contains(_meditationType) ? _meditationType : '本地脚本',
              decoration: const InputDecoration(labelText: '冥想类型', border: OutlineInputBorder()),
              items: _typeOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _meditationType = v ?? '本地脚本'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _pauseStyle,
              decoration: const InputDecoration(labelText: '停顿风格', border: OutlineInputBorder()),
              items: _pauseStyles.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _pauseStyle = v ?? '标准停顿'),
            ),
            const SizedBox(height: 12),
            const Text('脚本处理方式', style: TextStyle(fontWeight: FontWeight.w700)),
            RadioListTile<String>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('保留原文，仅自动插入停顿'),
              value: 'preserve',
              groupValue: _processMode,
              onChanged: (v) => setState(() => _processMode = v ?? 'preserve'),
            ),
            RadioListTile<String>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('轻微优化原文并插入停顿'),
              value: 'light',
              groupValue: _processMode,
              onChanged: (v) => setState(() => _processMode = v ?? 'light'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('优先使用 AI 标注停顿'),
              subtitle: const Text('AI 只做断句和停顿标注，失败时自动使用本地规则。'),
              value: _preferAi,
              onChanged: (v) => setState(() => _preferAi = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(MeditationSessionTemplate preview) {
    final totalPause = preview.steps.fold<int>(0, (sum, e) => sum + e.pauseAfterSeconds);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.black.withOpacity(0.06))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('脚本预览', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(preview.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('${preview.durationMinutes}分钟 · ${preview.type} · ${preview.steps.length} 句 · 停顿约 ${totalPause}s', style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 10),
            Text(preview.description, style: const TextStyle(height: 1.45)),
            const SizedBox(height: 14),
            const Text('前几段引导：', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...preview.steps.take(6).map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_formatOffset(e.startSecond)}  ${e.text}', style: const TextStyle(height: 1.45, color: Colors.black87)),
                        if (e.pauseAfterSeconds > 0)
                          Text('停顿 ${e.pauseAfterSeconds} 秒', style: const TextStyle(fontSize: 12, color: Color(0xFF5A7D61))),
                      ],
                    ),
                  ),
                ),
            if (preview.steps.length > 6) Text('……共 ${preview.steps.length} 句', style: const TextStyle(color: Colors.black45)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : () => _save(startAfterSave: true),
                    icon: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.play_arrow),
                    label: const Text('保存并开始'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(onPressed: _saving ? null : () => _save(startAfterSave: false), child: const Text('只保存')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int? _readExplicitMinutes(String raw) {
    final head = raw.split('\n').take(12).join('\n');
    final m = RegExp(r'(?:时长|duration)\s*[:：]?\s*(\d{1,3})\s*(?:分钟|min|m)', caseSensitive: false).firstMatch(head) ??
        RegExp(r'(\d{1,3})\s*(?:分钟|min)冥想', caseSensitive: false).firstMatch(head);
    final value = int.tryParse(m?.group(1) ?? '');
    if (value == null) return null;
    return value.clamp(8, 60).toInt();
  }

  String _guessType(String raw) {
    if (raw.contains('睡') || raw.contains('入睡')) return '睡前放松';
    if (raw.contains('反刍') || raw.contains('念头')) return '反刍中断';
    if (raw.contains('焦虑') || raw.contains('呼吸')) return '呼吸稳定';
    if (raw.contains('身体扫描') || raw.contains('身体')) return '身体扫描';
    if (raw.contains('羞耻') || raw.contains('自责')) return '自我接纳';
    return '本地脚本';
  }

  String _formatOffset(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
