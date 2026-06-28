# 语音闹钟非实时识别：聊天 App 式完整录音管线修复

## 问题定位

日志显示用户一段话被本地拆成多个片段后分别提交 STT，后续片段出现空结果、超时或低质量过滤，导致页面只显示前半段或局部内容。典型日志包括：

- `batch.record.rollingSubmit`
- `batch.chunk.retry.*`
- `finalWithAudio=false`
- 讯飞返回 `ls=true` 时客户端尚未发送完整尾部音频

这说明旧逻辑并不是 ChatGPT / Claude / Grok 那种“录完整一句话 → 一次性发服务端 → 返回最终转写”，而是“本地滚动切段 → 分段转写 → 尝试合并”。

## 修复原则

非实时模式现在改成聊天 App 式管线：

1. 打开麦克风后先保存完整 utterance PCM。
2. VAD 只判断这一句话何时结束，不再负责本地切段。
3. 触发静音或手动发送后，只提交一整段音频给 STT。
4. 不再执行滚动分段、chunk retry、trimmed/original 多轮重试。
5. STT 返回最终文字后再进入 AI；不把片段提前发给 AI。

## 关键代码变更

- `batchRollingSegmentMs()` 返回 `batchMaxRecordMs() + 10000`，正常流程不再触发 `rollingSubmit`。
- `recordBatchPcmUntilSubmit()` 返回完整 `strictAudio`，不再做 `trimPcmForBatchSubmission()`。
- `startBatchCloudStt()` 的识别线程改为 `batch.singleUpload.start`：一次完整音频上传，不再调用 `recognizeBatchByChunks()`。
- `isLowQualityBatchTranscript()` 仅过滤纯填充词，不再把“听见了吗/今天没定吧”这类短句误杀。
- `interruptPlaybackForUserSpeech()` 在确认用户 barge-in 并停止播报后立即释放 echo gate，避免持续重置捕获导致首词丢失。

## 讯飞 IAT 修复

讯飞 WebAPI 文档中后端点检测参数是 `eos`，表示静默多少毫秒后引擎认为音频结束。旧代码发送的是 `vad_eos`，可能被 WebAPI v2 忽略，导致默认 2000ms 生效；当用户一句话中有自然停顿时，服务端可能提前返回 `ls=true`，客户端因此停止发送尾部音频。

现在首帧 business 同时发送：

```json
{
  "eos": 8000,
  "vad_eos": 8000
}
```

并在日志中记录：

```text
stt.iflytek.batch.open | {"eosMs":"..."}
batch.singleUpload.start
batch.record.segment | {"pipeline":"single_upload"}
```

## 验证重点

安装后查看日志，正常非实时转写应出现：

```text
batch.record.segment | complete utterance segment ready | pipeline=single_upload
batch.singleUpload.start | upload one complete utterance audio to STT
stt.iflytek.batch.open | eosMs=...
batch.result | batch STT text returned
```

不应再在正常流程里出现：

```text
batch.record.rollingSubmit
batch.chunk.retry.*
batch.trim.discardDestructive
```
