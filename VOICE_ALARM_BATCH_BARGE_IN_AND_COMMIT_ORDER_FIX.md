# 语音闹钟非实时模式：后半段丢失、提前 AI 提交、播报期间打断修复

本补丁针对日志中暴露出的三个问题：

1. 讯飞对 19 秒左右录音直接返回空文本，导致只有前面已识别片段进入 AI。
2. `batch.aiHold.forceRelease` 在仍有 STT 分段 in-flight 时提前把前半句发送给 AI。
3. 非实时模式在闹钟/AI 播报期间硬停麦克风，用户打断播报时后续语音会被挡掉。

## 关键修复

- 非实时模式不再默认硬停麦克风：播报期间继续监听，进入 `batch.playbackEchoGuard`，通过更严格的 VAD 和文本级回声过滤区分播报声与真人语音。
- `shouldHoldBatchAiCommit()` 调整为：只要队列中有分段、识别线程 in-flight、或提交状态未结束，就不允许 AI 提前处理前半句。
- 长录音返回空文本时，新增 `recognizeBatchByChunks()`：自动按约 8 秒窗口拆分重试，尽量从服务商提前结束的长音频中恢复后半段内容。
- 滚动分段默认从 18 秒调整为 30 秒，减少短片段残句、空片段和“只有一部分成功”的概率。
- 播报期间的 UI 文案改为“继续监听并过滤回声”，不再提示硬暂停。

## 关键日志

- `batch.playbackEchoGuard`
- `batch.chunk.retry.piece`
- `batch.chunk.retry.empty`
- `batch.chunk.retry.done`
- `batch.aiHold.forceRelease` 现在只会在队列已清空、无 in-flight 后出现

