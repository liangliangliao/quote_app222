import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'eleven_labs_service.dart';
import 'multi_provider_tts_service.dart';

class VoiceClonePage extends StatefulWidget {
  const VoiceClonePage({super.key});

  @override
  State<VoiceClonePage> createState() => _VoiceClonePageState();
}

class _VoiceClonePageState extends State<VoiceClonePage> {
  final ElevenLabsService _elevenLabs = ElevenLabsService();
  final MultiProviderTtsService _multi = MultiProviderTtsService();
  final TextEditingController _nameCtrl = TextEditingController(text: '美好的祝福声音');
  final TextEditingController _descCtrl = TextEditingController(text: '用于美好的祝福对话的中文克隆声音');
  final TextEditingController _manualVoiceIdCtrl = TextEditingController();
  final TextEditingController _resembleTranscriptCtrl = TextEditingController(text: '这是一段用于创建语音克隆的授权声音样本。');
  final TextEditingController _minimaxCustomVoiceIdCtrl = TextEditingController();
  final TextEditingController _minimaxPromptTextCtrl = TextEditingController(text: 'This voice sounds natural, calm, and pleasant.');
  final TextEditingController _minimaxPreviewTextCtrl = TextEditingController(text: '现在，慢慢闭上眼睛。把注意力放在你的呼吸上。');
  String _provider = VoiceProviderSettings.defaultProvider;
  String _resembleVoiceType = 'rapid_voice';
  String? _samplePath;
  String? _minimaxPromptAudioPath;
  bool _removeNoise = false;
  bool _consented = false;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _manualVoiceIdCtrl.dispose();
    _resembleTranscriptCtrl.dispose();
    _minimaxCustomVoiceIdCtrl.dispose();
    _minimaxPromptTextCtrl.dispose();
    _minimaxPreviewTextCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickSample() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
    );
    final path = res?.files.first.path;
    if (path == null || path.isEmpty) return;
    setState(() => _samplePath = path);
  }

  Future<void> _pickMiniMaxPromptAudio() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'm4a'],
    );
    final path = res?.files.first.path;
    if (path == null || path.isEmpty) return;
    setState(() => _minimaxPromptAudioPath = path);
  }

  Future<void> _createClone() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _toast('请填写声音名称');
      return;
    }
    if (_samplePath == null || _samplePath!.isEmpty) {
      _toast('请先选择声音样本文件');
      return;
    }
    if (!_consented) {
      _toast('请先确认你拥有该声音的使用权');
      return;
    }
    setState(() => _loading = true);
    try {
      if (_provider == 'resemble') {
        await _multi.createResembleVoiceClone(
          displayName: name,
          sampleAudioPath: _samplePath!,
          transcript: _resembleTranscriptCtrl.text.trim(),
          voiceType: _resembleVoiceType,
          makeDefault: true,
        );
      } else if (_provider == 'minimax') {
        await _multi.createMiniMaxVoiceClone(
          displayName: name,
          sampleAudioPath: _samplePath!,
          customVoiceId: _minimaxCustomVoiceIdCtrl.text.trim(),
          promptAudioPath: _minimaxPromptAudioPath ?? '',
          promptText: _minimaxPromptTextCtrl.text.trim(),
          previewText: _minimaxPreviewTextCtrl.text.trim(),
          makeDefault: true,
        );
      } else {
        await _elevenLabs.createInstantVoiceClone(
          displayName: name,
          sampleAudioPath: _samplePath!,
          description: _descCtrl.text.trim(),
          removeBackgroundNoise: _removeNoise,
          makeDefault: true,
        );
      }
      if (!mounted) return;
      _toast('创建成功，并已设为默认声音');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _toast('创建失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addManualVoiceId() async {
    if (!_consented) {
      _toast('请先确认你拥有该声音的使用权');
      return;
    }
    final name = _nameCtrl.text.trim().isEmpty ? '克隆声音' : _nameCtrl.text.trim();
    final voiceId = _manualVoiceIdCtrl.text.trim();
    if (voiceId.isEmpty) {
      _toast('请粘贴已有 voice_id / voice_uuid');
      return;
    }
    setState(() => _loading = true);
    try {
      if (_provider == 'elevenlabs') {
        await _elevenLabs.addManualVoiceProfile(displayName: name, elevenlabsVoiceId: voiceId, makeDefault: true);
      } else {
        await _multi.addManualVoiceProfile(provider: _provider, displayName: name, externalVoiceId: voiceId, makeDefault: true);
      }
      if (!mounted) return;
      _toast('已保存声音 ID，并设为默认声音');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _toast('保存失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final sampleName = _samplePath == null ? '未选择' : File(_samplePath!).uri.pathSegments.last;
    final promptName = _minimaxPromptAudioPath == null ? '未选择' : File(_minimaxPromptAudioPath!).uri.pathSegments.last;
    final idLabel = _provider == 'resemble' ? '已有 Resemble voice_uuid' : (_provider == 'minimax' ? '已有 MiniMax voice_id' : '已有 ElevenLabs voice_id');
    return Scaffold(
      appBar: AppBar(title: const Text('新建 / 添加克隆声音')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('声音服务商', style: TextStyle(fontWeight: FontWeight.bold)),
                  RadioListTile<String>(contentPadding: EdgeInsets.zero, value: 'elevenlabs', groupValue: _provider, title: const Text('ElevenLabs'), subtitle: const Text('Instant Voice Cloning，返回 voice_id。'), onChanged: _loading ? null : (v) => setState(() => _provider = v ?? 'elevenlabs')),
                  RadioListTile<String>(contentPadding: EdgeInsets.zero, value: 'resemble', groupValue: _provider, title: const Text('Resemble AI'), subtitle: const Text('Rapid / Professional Clone；API 克隆通常需要 Business 或更高计划。'), onChanged: _loading ? null : (v) => setState(() => _provider = v ?? 'resemble')),
                  RadioListTile<String>(contentPadding: EdgeInsets.zero, value: 'minimax', groupValue: _provider, title: const Text('MiniMax'), subtitle: const Text('上传 10 秒到 5 分钟音频，创建自定义 voice_id；适合中文和冥想停顿。'), onChanged: _loading ? null : (v) => setState(() => _provider = v ?? 'minimax')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('授权与合规确认', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('请只克隆你自己的声音，或已经获得声音所有者明确授权的声音。禁止用于冒充、欺骗、骚扰、诈骗或误导。'),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('我确认拥有该声音的使用权，并同意用于 AI 语音合成'),
                    value: _consented,
                    onChanged: _loading ? null : (v) => setState(() => _consented = v == true),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: '声音名称', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _descCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '声音说明', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('声音样本文件'),
            subtitle: Text(sampleName, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: OutlinedButton.icon(onPressed: _loading ? null : _pickSample, icon: const Icon(Icons.upload_file), label: const Text('选择')),
          ),
          if (_provider == 'elevenlabs')
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('提交时尝试去除背景噪声'), subtitle: const Text('录音已足够干净时建议关闭，避免影响音色'), value: _removeNoise, onChanged: _loading ? null : (v) => setState(() => _removeNoise = v)),
          if (_provider == 'resemble') ...[
            DropdownButtonFormField<String>(value: _resembleVoiceType, decoration: const InputDecoration(labelText: 'Resemble 克隆类型', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 'rapid_voice', child: Text('Rapid Voice Clone')), DropdownMenuItem(value: 'professional', child: Text('Professional Clone'))], onChanged: (v) => setState(() => _resembleVoiceType = v ?? 'rapid_voice')),
            const SizedBox(height: 8),
            TextField(controller: _resembleTranscriptCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '样本转写文本 / Transcript', helperText: '上传单条录音时用于 Resemble recording.text', border: OutlineInputBorder())),
          ],
          if (_provider == 'minimax') ...[
            TextField(controller: _minimaxCustomVoiceIdCtrl, decoration: const InputDecoration(labelText: '自定义 voice_id，可留空自动生成', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            ListTile(contentPadding: EdgeInsets.zero, title: const Text('可选：提示音频 prompt_audio（少于 8 秒）'), subtitle: Text(promptName, maxLines: 2, overflow: TextOverflow.ellipsis), trailing: OutlinedButton.icon(onPressed: _loading ? null : _pickMiniMaxPromptAudio, icon: const Icon(Icons.upload_file), label: const Text('选择'))),
            TextField(controller: _minimaxPromptTextCtrl, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: '可选：prompt_text', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _minimaxPreviewTextCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '克隆预览文本', helperText: 'MiniMax voice_clone 会用它生成预览音频', border: OutlineInputBorder())),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _loading ? null : _createClone, icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.record_voice_over), label: Text('提交 ${_providerName(_provider)} 创建声音克隆')),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          const Text('如果你已在对应平台网页端创建好声音，也可以直接粘贴 ID。', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          TextField(controller: _manualVoiceIdCtrl, decoration: InputDecoration(labelText: idLabel, border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: _loading ? null : _addManualVoiceId, icon: const Icon(Icons.save_outlined), label: const Text('保存已有声音 ID')),
        ],
      ),
    );
  }

  String _providerName(String provider) => switch (provider) {
        'resemble' => 'Resemble AI',
        'minimax' => 'MiniMax',
        _ => 'ElevenLabs',
      };
}
