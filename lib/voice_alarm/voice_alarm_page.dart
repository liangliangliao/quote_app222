import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/kv_dao.dart';
import '../voice_lab/multi_provider_tts_service.dart';

class VoiceAlarmPage extends StatefulWidget {
  const VoiceAlarmPage({super.key});

  @override
  State<VoiceAlarmPage> createState() => _VoiceAlarmPageState();
}

class _VoiceAlarmPageState extends State<VoiceAlarmPage> {
  final _text = TextEditingController(text: '早上好，新的一天开始了。愿你平静、专注、充满力量。');
  final _tts = MultiProviderTtsService();
  final _kv = KeyValueDao();
  final _player = AudioPlayer();
  final _notifications = FlutterLocalNotificationsPlugin();
  TimeOfDay _time = TimeOfDay.now();
  String _provider = 'microsoft';
  String? _customMusic;
  String? _generatedVoice;
  bool _vibrate = true;
  bool _systemMusic = true;
  bool _saving = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    _player.dispose();
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
      if (_provider == 'microsoft') {
        _generatedVoice = await _tts.synthesizeMicrosoftToFile(text: _text.text.trim());
      }
      final when = _nextTime();
      await _kv.setString('voice_alarm.time', when.toIso8601String());
      await _kv.setString('voice_alarm.text', _text.text.trim());
      await _kv.setString('voice_alarm.provider', _provider);
      await _kv.setString('voice_alarm.voice_file', _generatedVoice ?? '');
      await _kv.setString('voice_alarm.music_file', _customMusic ?? '');
      await _kv.setString('voice_alarm.vibrate', _vibrate ? '1' : '0');
      await _kv.setString('voice_alarm.system_music', _systemMusic ? '1' : '0');

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _notifications.initialize(const InitializationSettings(android: android));
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _notifications.show(
        74001,
        '语音闹钟已设置',
        '${when.month}月${when.day}日 ${TimeOfDay.fromDateTime(when).format(context)} · $_provider',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'voice_alarm_schedule',
            '语音闹钟',
            channelDescription: '语音闹钟设置与到点提醒',
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: _vibrate,
          ),
        ),
      );
      _timer?.cancel();
      _timer = Timer(when.difference(DateTime.now()), _ring);
      _toast('已设置语音闹钟；保持 App 运行时将自动朗读，系统通知用于后台提醒');
      setState(() {});
    } catch (e) {
      _toast('设置失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _ring() async {
    if (_customMusic != null && File(_customMusic!).existsSync()) {
      await _player.play(DeviceFileSource(_customMusic!));
    }
    if (_generatedVoice != null && File(_generatedVoice!).existsSync()) {
      await _player.play(DeviceFileSource(_generatedVoice!));
    }
    if (mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('语音闹钟'),
          content: Text(_text.text),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _timer = Timer(const Duration(minutes: 5), _ring);
                _toast('将在 5 分钟后再次提醒');
              },
              child: const Text('5分钟后再次提醒'),
            ),
            FilledButton(
              onPressed: () {
                _player.stop();
                Navigator.pop(context);
              },
              child: const Text('关闭闹钟'),
            ),
          ],
        ),
      );
    }
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
        ],
      ),
    );
  }
}
