# Voice Alarm V9 - Barge-in STT Recovery

修复问题：AI/TTS 语音播报过程中，用户说话打断后，后续语音识别可能全部失效。

## 根因分析

V8 的回声隔离为了避免“AI 自己播报又被识别成用户输入”，在 AI/TTS 播报期间会设置 `speaking=true` 并暂停原生 `SpeechRecognizer`。

部分 Android TTS 引擎在以下场景下不会稳定回调 `onDone()` / `onError()`：

- 用户说话打断时 TTS 被系统音频焦点、引擎内部或 `QUEUE_FLUSH/stop` 中断；
- 播报被新的语音/闹钟音频抢占；
- 设备厂商 TTS 服务异常终止；
- SpeechRecognizer 与 TTS 竞争麦克风/音频焦点。

如果 `onDone/onError` 没回来，`speaking=true` 会永久残留；而 `listenAgain()` 开头会因为 `speaking=true` 直接 return，导致后续识别全部无法重启。

## 修复内容

1. 新增 App TTS watchdog：
   - 每次 `speak()` 开始时记录 utteranceId 和开始时间；
   - 按文本长度估算最大播报时间；
   - 如果 TTS 完成回调丢失，自动释放 `speaking` 状态并恢复识别。

2. 新增 barge-in 打断恢复：
   - 当分类器确认播放期间收到的是真人用户语音，而不是回声时；
   - 立即 `tts.stop()` 停止 AI 播报；
   - 不等待 TTS 回调，直接清理 `speaking/currentAppTtsUtteranceId/ttsRestartByUtterance`；
   - 保留用户已说内容，进入缓冲处理链路。

3. 新增 listening 卡死恢复：
   - 记录 `listeningStartedAt`；
   - 如果系统 SpeechRecognizer 长时间没有 onResults/onError/onEndOfSpeech，自动 cancel 并允许重新监听。

4. 新增打断后识别健康检查：
   - barge-in 后延迟检查 cloud STT 线程是否还活着；
   - 如果云识别线程死亡，自动重新启动语音助手；
   - 如果使用系统识别且没有在 speaking/listening，自动恢复 `listenAgain()`。

## 修改文件

- `android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmActivity.kt`

## 说明

这次修复的核心不是放宽回声过滤，而是避免播放状态机残留。用户插话应触发“打断播报 + 释放播放锁 + 保留用户语音 + 恢复识别”，而不是让 `speaking=true` 永久阻断下一轮识别。
