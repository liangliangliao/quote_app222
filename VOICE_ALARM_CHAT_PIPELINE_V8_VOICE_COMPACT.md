# Voice Alarm Chat Pipeline V8 - Voice Compaction Before STT

## 背景
用户询问是否可以把录音中的空白部分删除，只保留有声音的部分给服务端转文字。最近日志显示：

- Android 端确实能录到 PCM 并保存 debug WAV；
- 但提交给 STT 的音频中可能包含大量等待/静音/低能量空白；
- 某些服务商（特别是 Microsoft batch endpoint）会在长空白、弱语音或播报污染后返回 HTTP 200 但 DisplayText 为空。

## 本版目标
继续保持聊天 App 式“单轮完整语音输入”状态机，但在上传 STT 前做安全压缩：

```text
录一条用户语音 -> 删除长静音/空白帧 -> 保留短停顿和语音前后 padding -> 上传给 STT
```

这不是恢复旧版滚动分段，也不是把一句话拆给多个服务端请求。

## 关键改动

1. 新增 `compactPcmForStt(...)`
   - 以 20ms PCM 帧计算 RMS/peak；
   - 动态估计噪声底；
   - 标记 voice-like 帧；
   - 合并短间隔；
   - 每个有声段前后保留约 260ms padding；
   - 删除长静音/空白段。

2. 提交前应用语音压缩
   - 自动提交：`reason=autoSubmit`
   - 手动提交：`reason=manualSubmit`
   - fallback 路径：`reason=manualFallback/autoFallback`

3. 保留原始录音 debug
   - `last_batch_stt.wav`：实际上传给 STT 的压缩后音频；
   - `last_batch_stt_original.wav`：压缩前完整自然录音，便于对比。

4. 新日志
   - `batch.voiceCompact.applied`
   - `batch.voiceCompact.keepOriginal`
   - `batch.voiceCompact.noVoice`

## 版本标记

```text
chat_input_v8_voice_compact_20260628
```

## 预期效果

- 长时间等待/空白不会原样上传给 STT；
- 弱语音前后仍保留 padding，不会硬切断第一个字/最后一个字；
- 短停顿会保留，不会把自然句子剪碎；
- 如果压缩没有收益或会导致音频过短，会自动保留原始音频。

## 验证建议

安装后查看日志是否出现：

```text
pipeline=chat_input_v8_voice_compact_20260628
batch.voiceCompact.applied
```

若仍出现空转写，请 pull 两个文件对比：

```bash
adb pull /storage/emulated/0/Android/data/com.example.quote_app/files/voice_alarm_audio_debug/last_batch_stt.wav .
adb pull /storage/emulated/0/Android/data/com.example.quote_app/files/voice_alarm_audio_debug/last_batch_stt_original.wav .
```

先听 `last_batch_stt_original.wav` 确认原始录音里是否有用户语音，再听 `last_batch_stt.wav` 确认压缩后是否保留了完整用户语音。
