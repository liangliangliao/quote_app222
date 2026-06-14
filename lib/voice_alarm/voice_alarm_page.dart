import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/kv_dao.dart';
import '../voice_lab/eleven_labs_service.dart';
import '../voice_lab/multi_provider_tts_service.dart';

class VoiceAlarmPage extends StatefulWidget {
  const VoiceAlarmPage({super.key});

  @override
  State<VoiceAlarmPage> createState() => _VoiceAlarmPageState();
}

class _VoiceAlarmPageState extends State<VoiceAlarmPage> {
  final _text = TextEditingController(text: '早上好，新的一天开始了。愿你平静、专注、充满力量。');
  final _tts = MultiProviderTtsService();
  final _elevenLabs = ElevenLabsService();
  final _kv = KeyValueDao();
  static const _native = MethodChannel('com.example.quote_app/voice_alarm');
  TimeOfDay _time = TimeOfDay.now();
  String _provider = 'microsoft';
  String? _customMusic;
  String? _generatedVoice;
  bool _vibrate = true;
  bool _systemMusic = true;
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  DateTime _nextTime() {
    final now = DateTime.now();
    var value = DateTime(now.year, now.month, now.day, _time.hour, _time.minute);
    if (!value.isAfter(now)) value = value.add(const Duration(days: 1));
    return value;
  }

  Future<void> _pickMusic() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    final path = result?.files.single.path;
    if (path != null && mounted) setState(() => _customMusic = path);
  }

  Future<void> _schedule() async {
    if (_text.text.trim().isEmpty) {
      _toast('请输入闹钟朗读内容');
      return;
    }
    setState(() => _saving = true);
    try {
      final hasPermission = await _native.invokeMethod<bool>('hasExactAlarmPermission') ?? true;
      if (!hasPermission) {
        await _native.invokeMethod<void>('requestExactAlarmPermission');
        _toast('请在系统页面允许“闹钟和提醒”，返回后再次点击保存');
        return;
      }
      _generatedVoice = await _generateVoiceFile();
      final when = _nextTime();
      await _kv.setString('voice_alarm.time', when.toIso8601String());
      await _kv.setString('voice_alarm.text', _text.text.trim());
      await _kv.setString('voice_alarm.provider', _provider);
      await _kv.setString('voice_alarm.voice_file', _generatedVoice ?? '');
      await _kv.setString('voice_alarm.music_file', _customMusic ?? '');
      await _kv.setString('voice_alarm.vibrate', _vibrate ? '1' : '0');
      await _kv.setString('voice_alarm.system_music', _systemMusic ? '1' : '0');
      final payload = _payload();
      await _native.invokeMethod<void>('schedule', {
        'atMs': when.millisecondsSinceEpoch,
        'payload': payload,
      });
      _toast('已注册 Android 系统精确闹钟；App 在后台或进程被清理后仍可响铃');
      setState(() {});
    } catch (e) {
      _toast('设置失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String> _generateVoiceFile() async {
    final text = _text.text.trim();
    if (_provider == 'microsoft') {
      return _tts.synthesizeMicrosoftToFile(text: text);
    }
    if (_provider == 'resemble') {
      final voiceUuid = (await _kv.getString(VoiceProviderSettings.resembleVoiceUuid) ?? '').trim();
      if (voiceUuid.isEmpty) throw StateError('请先在“语音与美好的祝福配置”中选择 Resemble voice_uuid');
      final audio = await _tts.synthesizeResembleAndSave(
        text: text,
        voiceUuid: voiceUuid,
        voiceDisplayName: await _kv.getString(VoiceProviderSettings.resembleVoiceName) ?? 'Resemble AI',
        moduleName: 'voice_alarm_resemble',
      );
      return audio.audioFilePath;
    }
    if (_provider == 'minimax') {
      final voiceId = (await _kv.getString(VoiceProviderSettings.minimaxVoiceId) ?? VoiceProviderSettings.defaultMiniMaxVoiceId).trim();
      final audio = await _tts.synthesizeMiniMaxAndSave(
        text: text,
        voiceId: voiceId,
        voiceDisplayName: await _kv.getString(VoiceProviderSettings.minimaxVoiceName) ?? VoiceProviderSettings.defaultMiniMaxVoiceName,
        moduleName: 'voice_alarm_minimax',
      );
      return audio.audioFilePath;
    }
    final voiceId = (await _kv.getString(ElevenLabsSettings.presetVoiceId) ?? ElevenLabsSettings.defaultPresetVoiceId).trim();
    final audio = await _elevenLabs.synthesizeAndSaveByVoiceId(
      text: text,
      voiceId: voiceId,
      voiceSource: 'premade',
      voiceDisplayName: await _kv.getString(ElevenLabsSettings.presetVoiceName) ?? ElevenLabsSettings.defaultPresetVoiceName,
      moduleName: 'voice_alarm_elevenlabs',
    );
    return audio.audioFilePath;
  }

  Future<void> _ring() async {
    await _native.invokeMethod<void>('testRing', {'payload': _payload()});
  }

  String _payload() {
    return jsonEncode({
      'text': _text.text.trim(),
      'provider': _provider,
      'voicePath': _generatedVoice ?? '',
      'musicPath': _customMusic ?? '',
      'vibrate': _vibrate,
      'systemMusic': _systemMusic,
      'hour': _time.hour,
      'minute': _time.minute,
    });
  }

  void _toast(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final next = _nextTime();
    return Scaffold(
      appBar: AppBar(title: const Text('语音闹钟')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('提醒时间', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.alarm),
                  title: Text(_time.format(context), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600)),
                  subtitle: Text('下一次：${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}'),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () async {
                    final value = await showTimePicker(context: context, initialTime: _time);
                    if (value != null) setState(() => _time = value);
                  },
                ),
              ]),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('语音内容与服务商', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(controller: _text, maxLines: 4, decoration: const InputDecoration(labelText: '到点朗读内容', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _provider,
                  decoration: const InputDecoration(labelText: '文字转语音服务商', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'microsoft', child: Text('Microsoft Azure Speech（默认）')),
                    DropdownMenuItem(value: 'elevenlabs', child: Text('ElevenLabs')),
                    DropdownMenuItem(value: 'resemble', child: Text('Resemble AI')),
                    DropdownMenuItem(value: 'minimax', child: Text('MiniMax')),
                  ],
                  onChanged: (value) => setState(() => _provider = value ?? 'microsoft'),
                ),
                const SizedBox(height: 8),
                const Text('服务商参数复用“设置 → 语音与美好的祝福配置”。当前版本会为微软服务预先生成闹钟语音。', style: TextStyle(color: Colors.black54)),
              ]),
            ),
          ),
          Card(
            child: Column(children: [
              SwitchListTile(title: const Text('震动'), subtitle: const Text('同时启用系统通知震动'), value: _vibrate, onChanged: (value) => setState(() => _vibrate = value)),
              SwitchListTile(title: const Text('系统闹钟音乐'), subtitle: const Text('未选择自定义音乐时使用系统提醒通道'), value: _systemMusic, onChanged: (value) => setState(() => _systemMusic = value)),
              ListTile(
                leading: const Icon(Icons.library_music_outlined),
                title: const Text('自定义音乐'),
                subtitle: Text(_customMusic == null ? '未选择' : _customMusic!.split('/').last),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickMusic,
              ),
            ]),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _schedule,
            icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.alarm_add),
            label: Text(_saving ? '正在生成语音并设置…' : '保存并启用语音闹钟'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _ring, icon: const Icon(Icons.play_arrow), label: const Text('立即测试闹钟与稍后提醒')),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await _native.invokeMethod<void>('snooze', {'payload': _payload()});
                    await _native.invokeMethod<void>('stopRing');
                    _toast('已通过 Android 系统设置为 5 分钟后再次提醒');
                  },
                  icon: const Icon(Icons.snooze),
                  label: const Text('5分钟后提醒'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _native.invokeMethod<void>('stopRing'),
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('停止响铃'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
