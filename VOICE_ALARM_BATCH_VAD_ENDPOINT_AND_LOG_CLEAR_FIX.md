# 非实时语音：VAD 端点修复、播放中断保留、日志清理增强

## 背景
用户日志显示：

- `AudioRecord` 已启动，且页面持续显示“已检测到声音”。
- 但非实时录音长时间没有静音自动提交。
- 闹钟语音再次播报时，当前录音缓存被丢弃。
- 用户说了一段话后没有语音转文字，也没有 AI 返回。

这说明问题不只是服务商 STT，而是本地非实时录音端点判断存在严重缺陷。

## 根因
上一版在 batch 录音里有一个核心错误：

```kotlin
val confirmedSpeech = speechStarted || ...
if (confirmedSpeech) {
  lastSpeechAt = now
}
```

一旦 `speechStarted = true`，后续每一帧都会刷新 `lastSpeechAt`，即使那一帧只是底噪、环境声或静音。因此“静音 5 秒自动提交”永远无法触发。

另外，`candidateVoiceActivity` 阈值过低，导致页面把很多非人声输入显示成“已检测到声音”，用户误以为已经确认了用户说话。

## 修复

1. 拆分“检测到声音输入”和“检测到用户说话”
   - 候选声音只用于页面提示/手动发送可用性。
   - 只有正式语音/软语音才启动并刷新自动提交的静音倒计时。

2. 修复 `lastSpeechAt` 刷新逻辑
   - `speechStarted=true` 不再每帧刷新 `lastSpeechAt`。
   - 只有当前帧仍然满足 `speech || softSpeech` 时才刷新。
   - 用户说完后，环境底噪不会阻止静音倒计时结束。

3. 提高候选声音/语音阈值
   - 避免把持续底噪、设备噪声、扬声器尾音误判成用户说话。
   - 页面会显示“检测到声音输入，尚未确认是用户说话”。

4. 播报中断时不再直接丢掉已确认的用户语音
   - 如果闹钟/TTS 播报突然开始，而当前缓存已经确认有用户说话，则先提交这段录音，再暂停麦克风。
   - 如果只是环境声缓存，则仍然丢弃，避免把播报声音转写成用户文字。

5. 日志状态增强
   - 新增 `batch.vad.speechStart`。
   - 新增 `batch.vad.status`，记录 rms/peak/noiseRms/speech/soft/activity/candidate。
   - 新增 `batch.record.playbackInterruptSubmit`。

6. 清空日志增强
   - “清空日志”现在会清理 `voice_alarm_logs` 下的日志，也会清理 `voice_alarm_audio_debug` 下的调试 wav/pcm 文件，避免隐私音频残留。

## 主要修改文件

- `android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmActivity.kt`
- `android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmDebugLog.kt`
