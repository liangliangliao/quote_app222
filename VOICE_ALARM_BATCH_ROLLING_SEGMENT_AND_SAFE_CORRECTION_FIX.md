# 非实时语音长句滚动分段与安全纠错修复

## 修复背景
用户日志显示：

1. 非实时模式在连续讲话时经常等到 `maxRecordMs=60000ms` 才提交，看起来像“每次都要等 60 秒”。
2. 讯飞已经返回完整识别文本，但进入页面/AI 前被“自动纠错”截短，只剩前半句。
3. 多个非实时分段同时识别时，前一段可能先被发送给 AI，后一段还没回来，导致 AI 只收到部分用户语音。

## 本次修改

### 1. 连续讲话滚动分段
新增 `segmentMaxMs`，默认约 18 秒。连续长句不再等到 60 秒兜底才提交；到滚动分段时先送 STT。`maxRecordMs` 仍作为异常兜底上限。

日志新增：

```text
batch.record.rollingSubmit
```

### 2. 多分段先合并再发给 AI
新增 `shouldHoldBatchAiCommit(...)`。当非实时识别队列、识别线程或当前录音仍有确认用户语音时，先暂缓 AI 调用，等待后续 STT 分段返回并合并到 `speechBuffer`，避免只把前半句发送给 AI。

### 3. 防止 AI 自动纠错截断文本
`maybeAutoCorrectBatchTranscript(...)` 增加长度保护：如果纠错结果明显短于原始 STT 文本，则丢弃纠错结果，保留服务商原始完整转写。

日志新增：

```text
batch.correct.discardShort
```

### 4. 提交状态使用实际音频时长
队列中的 `durationMs` 改为按提交 PCM 字节数计算，而不是按录音窗口耗时计算，避免 UI 显示“60 秒”但实际只提交了 13 秒有效语音的误导。

### 5. 用户说话判断更稳健
正式 speech 判断不再只依赖单一 RMS 或 peak，要求基本 RMS 与峰值组合达到门限，减少底噪/碰麦/残留声音持续刷新静音倒计时。

## 修改文件

```text
android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmActivity.kt
lib/voice_alarm/voice_alarm_page.dart
```
