# V11 - 播报结束后立即说话的语音衔接修复

## 问题
当 AI/TTS 或闹钟语音刚播报完，用户立刻说话时，第一句话可能无法被识别或被丢弃。

## 根因
上一版为了避免 TTS/闹钟外放被麦克风重新识别，播报结束后仍保留了较长的 `suppressRecognitionUntil` / `strongPlaybackGateUntil`：

- AI TTS 结束后约 450ms 抑制 + 650ms 后才重启识别；
- 闹钟播报结束后约 900ms 强门控；
- 云录音线程若在播报中启动，会使用较高 VAD 阈值，播报结束后的软声音也可能被丢弃。

这导致“播报结束 -> 用户马上说话”的边界存在收音空窗。

## 修复
1. 新增 `postPlaybackHandoffUntil` 交接窗口。
2. 播报结束后立即进入交接窗口，而不是继续强抑制近 1 秒。
3. 交接窗口内允许 `listenAgain(40L)` 快速启动原生识别。
4. 交接窗口内不再把 `suppressRecognitionUntil / strongPlaybackGateUntil` 当作强播放状态。
5. 微软 / 讯飞云识别录音线程改为动态判断播放状态：
   - 播报中仍使用高阈值防回声；
   - 播报一结束立即降回正常 VAD 阈值；
   - 即使录音 chunk 是在 TTS 播放中启动，也不会因为旧高阈值丢掉播报结束后的第一句话。
6. TTS watchdog、闹钟播放 watchdog、正常 onDone/onError 回调都统一走交接窗口。

## 修改文件
- `android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmActivity.kt`

## 说明
该修复不关闭回声过滤。播报结束后仍会用 `lastAssistantSpokenText` 和闹钟文本做文本相似度过滤，避免把尾音/回声发给 AI；但不再用长时间门控阻塞用户马上接话。
