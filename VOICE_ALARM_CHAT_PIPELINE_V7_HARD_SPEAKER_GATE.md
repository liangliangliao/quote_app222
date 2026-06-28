# Voice Alarm chat pipeline v7 hard speaker gate

本版针对 2026-06-28 日志中仍然出现的两个问题继续修复：

1. 录音跨过闹钟/AI 播报窗口，导致服务端 STT 返回“早安天亮了……”等 App 自己的播报词。
2. Microsoft STT 出现 HTTP 200 / RecognitionStatus=Success 但 DisplayText 与 NBest 均为空，导致用户真实语音被判定为转写失败。

## 核心改动

- 将 batch pipeline 标记升级为 `chat_input_v7_hard_speaker_gate_20260628`。
- 新增 `batchSpeakerPlaybackEpoch`。每次闹钟/AI 播报开始、结束或回声冷却重置时都会递增；录音线程在开始时记录 epoch，只要录音过程中 epoch 变化，整段缓存直接作废，不再上传 STT。
- 在上传前再次检查 epoch，防止 AudioRecord 被播报事件 release 后仍把已经跨播报窗口的缓存作为完整语音提交。
- 对被识别为闹钟/AI 播报文本的结果给出明确状态：这是播报声，已丢弃，不再提示为普通“未返回文字”。
- Microsoft STT 在 `Success + 空文本` 时自动用前后静音 padding 重试一次，并在仍为空时尝试其他已配置的 STT provider（讯飞 / xAI / Microsoft 互为兜底）。

## 期望日志

安装后日志应出现：

```text
pipeline=chat_input_v7_hard_speaker_gate_20260628
batch.capture.invalidatedByPlayback
batch.capture.invalidatedBeforeSubmit
stt.microsoft.http.retryPadded
batch.stt.fallback.success
```

不应再把 `早安天亮了，新的一天已经开始...` 作为用户有效语音发送给 AI。
