# 语音闹钟非实时语音 v6 严格单轮修复说明

本版针对日志里反复暴露的问题继续收敛，不再沿用“后台连续收音 + 多段排队 + 合并”的流程。

## 修复目标

1. 避免闹钟/AI 播报内容被录入 STT，例如“早安天亮了，新的一天已经开始...”被当成用户文字。
2. 避免用户一句话被拆成多条 STT 请求，导致只识别前半句、后半句丢失或卡在等待后续。
3. 避免“录音分段正在识别/排队”等旧流程状态继续出现。
4. 更接近 Grok / Claude / ChatGPT 的普通语音输入：一次只处理一条用户语音。

## 核心策略

状态流改为串行单轮：

```text
Idle
→ RecordingOneUtterance
→ UploadingSingleAudioToSTT
→ FinalTranscriptReady
→ SendToAI
→ AITalking / AlarmTalking
→ Idle
```

本轮未结束前，录音线程暂停，不再继续后台录下一条，也不再创建排队任务。

## 关键改动

- 新版本标记：`chat_input_v6_strict_single_turn_20260627`
- 新增严格忙碌判断：`isBatchStrictSingleTurnBusy()`
- 新增日志：`batch.singleTurn.wait`
- 禁用非实时模式下的 barge-in 边播边录：`batchPlaybackBargeInEnabled() = false`
- STT 识别、AI 生成、TTS/闹钟播报、回声冷却期间，非实时录音暂停。
- 队列改为只保留当前一条完整录音；不再合并多条语音，不再滚动分段。
- STT 最终文字返回后，批处理模式直接准备发送给 AI，不再继续等待“后续分段”。

## 应该不再出现

```text
batch.record.rollingSubmit
batch.chunk.retry.error
batch.capture.reopenForEchoGuardSubmit
录音分段正在识别/排队
```

## 应该出现

```text
pipeline=chat_input_v6_strict_single_turn_20260627
batch.singleUpload.start
batch.singleTurn.wait
```

## 测试建议

1. 安装后先打开语音调试日志，确认 `pipeline=chat_input_v6_strict_single_turn_20260627`。
2. 等闹钟播报时不要说话，确认不会把播报文本作为“非实时识别结果”。
3. 播报结束后完整说一段话，停顿 5 秒，确认只上传一次完整音频。
4. STT 返回后确认页面不再显示“分段/排队/等待后续”，而是等待 AI 回复。
