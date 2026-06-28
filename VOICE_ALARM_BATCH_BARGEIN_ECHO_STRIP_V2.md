# Voice Alarm Batch Barge-in Echo Strip V2

本补丁针对用户日志中“后半段没有转成功 / 转出了闹钟播报内容 / 听见了吗、补水整理好心情被当成用户语音”的问题继续修复。

## 根因

日志显示非实时 STT 录音段中混入了 App 自己的闹钟播报：

- 讯飞返回 `补水整理好心情，听见了吗？`
- 讯飞返回 `整理好心情。`
- 播报开始后仍然使用非 echo-guard 的普通 AudioRecord，导致扬声器声音进入录音文件
- 播报期间的 pre-roll 被写入待转写音频，造成服务商把播报文本转成用户文本

## 修复

1. 播报开始时，如果当前录音源还不是 echo-guard/AEC 模式，立即释放普通 AudioRecord，丢弃易混入扬声器的缓存，然后重开 VOICE_COMMUNICATION/AEC 录音源。
2. 播报期间检测到强用户语音时，不再把播报期间的 pre-roll 写入音频，而是先停止/延后 App 播报，再从干净帧重新开始保存用户语音。
3. 真正打断闹钟播报时，会调用 `VoiceAlarmRingingService.postponeVoiceReplay(...)` 停掉服务侧 MediaPlayer/TTS，而不是只在 Activity 内把 `alarmVoicePlaying=false`。
4. 批量 STT 结果增加播报文本片段剥离：如果结果里混有闹钟/AI 播报短语，会先去掉播报片段，再保留剩余用户内容。
5. 播报状态下的 VAD 门限大幅提高，减少把扬声器声音当成用户 barge-in。
6. `听见了吗？` 这类短问句不再因为“音频较长但文字短”被一律判成低质量噪声，避免误杀用户测试语句。

## 新增日志

- `batch.capture.reopenForEchoGuard`
- `batch.capture.reopenForEchoGuardSubmit`
- `batch.bargeIn.detected`
- `batch.result.echoStripped`

