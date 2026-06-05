import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'eleven_labs_service.dart';
import 'voice_lab_dao.dart';
import 'voice_lab_models.dart';

class TtsAudioLibraryPage extends StatefulWidget {
  const TtsAudioLibraryPage({super.key});

  @override
  State<TtsAudioLibraryPage> createState() => _TtsAudioLibraryPageState();
}

class _TtsAudioLibraryPageState extends State<TtsAudioLibraryPage> {
  final VoiceLabDao _dao = VoiceLabDao();
  final ElevenLabsService _service = ElevenLabsService();
  final AudioPlayer _player = AudioPlayer();
  List<TtsAudioFile> _items = <TtsAudioFile>[];
  bool _loading = true;
  String? _playingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _dao.listTtsAudio();
      if (!mounted) return;
      setState(() => _items = items);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _play(TtsAudioFile item) async {
    final f = File(item.audioFilePath);
    if (!await f.exists()) {
      _toast('音频文件已不存在');
      return;
    }
    await _player.stop();
    await _player.play(DeviceFileSource(item.audioFilePath));
    setState(() => _playingId = item.id);
  }

  Future<void> _download(TtsAudioFile item) async {
    try {
      final saved = await _service.exportAudioToDownloads(item);
      _toast('已保存到下载目录：$saved');
      await _load();
    } catch (e) {
      _toast('下载失败：$e');
    }
  }

  Future<void> _delete(TtsAudioFile item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除语音文件'),
        content: const Text('将删除 App 内部保存的 mp3 文件和数据库记录。已经导出到系统下载目录的副本不会自动删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (_playingId == item.id) await _player.stop();
      await _service.deleteAudioRecordAndFile(item);
      _toast('已删除');
      await _load();
    } catch (e) {
      _toast('删除失败：$e');
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  String _time(int ms) {
    if (ms <= 0) return '';
    return DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(ms));
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  String _providerName(String provider) {
    return switch (provider) {
      'resemble' => 'Resemble AI',
      'minimax' => 'MiniMax',
      _ => 'ElevenLabs',
    };
  }

  String _voiceSourceName(TtsAudioFile item) {
    if (item.voiceSource == 'premade' || item.voiceSource == 'minimax_system') return '普通/系统声音';
    if (item.voiceSource == 'resemble_manual') return 'Resemble 手动声音';
    return '克隆声音';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TTS 语音文件库')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 160),
                        Center(child: Text('暂无语音文件。生成 TTS 后会自动保存到这里。')),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final exists = File(item.audioFilePath).existsSync();
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(exists ? Icons.audiotrack : Icons.error_outline, color: exists ? Colors.black87 : Colors.red),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(item.sourceText, maxLines: 3, overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('来源：${item.moduleName}    服务商：${_providerName(item.provider)}    模型：${item.modelId}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                Text("声音：${_voiceSourceName(item)} ${item.voiceDisplayName.isEmpty ? item.elevenlabsVoiceId : item.voiceDisplayName}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                Text('参数：speed ${item.ttsSpeed.toStringAsFixed(2)} / stability ${item.ttsStability.toStringAsFixed(2)} / style ${item.ttsStyle.toStringAsFixed(2)} / 场景 ${item.scene}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                if (item.scene == 'meditation_relax')
                                  Text('冥想：${item.meditationPauseProfile} / 句间 ${item.meditationSentenceBreakSec.toStringAsFixed(1)}s / 段落 ${item.meditationParagraphBreakSec.toStringAsFixed(1)}s / 呼吸 ${item.meditationBreathBreakSec.toStringAsFixed(1)}s / ${item.meditationTone}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                Text('文件：${item.audioFileName}    ${_size(item.fileSize)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                Text("时间：${_time(item.createdAt)}    ${item.isDownloaded ? '已下载' : '未下载'}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: exists ? () => _play(item) : null,
                                      icon: Icon(_playingId == item.id ? Icons.volume_up : Icons.play_arrow),
                                      label: const Text('播放'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: exists ? () => _download(item) : null,
                                      icon: const Icon(Icons.download),
                                      label: const Text('下载'),
                                    ),
                                    TextButton.icon(
                                      onPressed: () => _delete(item),
                                      icon: const Icon(Icons.delete_outline),
                                      label: const Text('删除'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
