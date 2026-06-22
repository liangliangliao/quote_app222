# Voice Alarm V14 - Endpointing Confidence and TTS Reliability

本轮修复两个问题：

1. 句段端点提示“可能还没说完”过于主观，且短句如“你确定吗”会被最少字数阈值错误拦截。
2. AI 已返回文字但偶尔不播报语音，通常发生在系统 TTS 尚未初始化完成、TTS `speak()` 返回错误，或 TTS 返回成功但没有触发 `onStart()`。

## 关键修复

### 1. 端点检测改为更可解释的状态机

- UI 不再说“检测到这段话可能还没说完”。
- 改为：已收到，继续等待补充；若指定秒数内没有新语音，将自动提交。
- 这不是声称 AI 准确判断用户内心是否说完，而是透明展示等待策略。

### 2. 短句完整白名单

新增 `isShortCompleteUtterance()`：

- 识别没有标点的中文短问句，例如“你确定吗 / 可以吗 / 行吗 / 对吗 / 真的吗”。
- 识别短确认/否定，例如“可以 / 确定 / 好的 / 行 / 对 / 不用 / 不要 / 继续”。
- 这些短句不再被 `minCommitChars` 阈值拦截。

### 3. 软语义等待不再硬阻塞

语义完整度只作为一次性的软等待信号，不再反复阻塞提交。稳定静音达到阈值后会提交，避免“因为/我想”等词误伤真实短句。

### 4. TTS 初始化等待队列

如果 AI 文本返回时系统 TTS 还没 ready：

- 先显示 AI 文本；
- 暂存待播报文本；
- TTS ready 后自动播报；
- 若多次仍不可用，提示用户文字已显示并恢复语音识别。

### 5. TTS 启动 watchdog 与自动重试

如果 `tts.speak()` 返回成功但 1.7 秒内没有触发 `onStart()`：

- 自动停止并重试最多 2 次；
- 重试仍失败时释放 `speaking` 锁，恢复聆听；
- 避免“AI 有文字但无声音，同时后续识别被 speaking 状态卡住”。

## 修改文件

- `android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmActivity.kt`
- `lib/voice_alarm/voice_alarm_page.dart`
