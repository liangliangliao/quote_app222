# 语音闹钟非实时识别漏录与日志查看修复

## 背景
用户反馈：非实时语音模式仍会漏掉用户说话，导致语音转文字返回空；同时不知道日志文件在哪里，也无法在页面上查看。

## 根因判断
上一版为了避免把闹钟播报/AI TTS 录进非实时音频，加入了较强的播放保护门控。但实现里存在两个高风险点：

1. Activity 在注册闹钟播报广播接收器之前就启动了 RingingService。
   - 如果播放开始/结束广播错过，Activity 只能依赖初始预估保护时长。
   - 旧逻辑把初始保护估算到 6-45 秒，并把 `alarmVoicePlaying` 置为 true，期间非实时录音会被完全阻断。
   - 用户在播报结束后马上说话时，可能仍处于门控窗口，音频没有被写入 PCM，因此提交给 STT 的文件为空或接近空。

2. 播报结束后的冷却窗口过长。
   - 旧逻辑常用 900ms~1200ms 冷却。
   - 用户习惯在播报刚结束立刻说话，前几个字容易被丢弃。

## 本次修复

### 1. 播报广播接收器提前注册
- `onCreate()` 中先 `setContentView()`、注册 `alarmPlaybackReceiver`，再启动 `VoiceAlarmRingingService`。
- `handleAlarmFireIntent()` 内再次确保接收器已注册，注册函数做幂等保护。

### 2. 初始保护从“长时间猜测”改为“短 fail-open 保护”
- 初始 gate 只保留约 1.6 秒，用于防止 Service 刚启动时的扬声器泄漏。
- 不再在初始保护里直接把 `alarmVoicePlaying=true` 锁死。
- 若 1.6 秒内未收到播放开始广播，自动恢复收音，并写日志 `batch.initialPlaybackGate.failOpen`。

### 3. 播报结束后更快恢复非实时收音
- 闹钟播报结束冷却从 900ms 缩短到约 220ms。
- AI TTS 播报结束冷却也缩短到约 220ms。
- 保留文本级回声过滤，避免短冷却带来的少量尾音被误当成用户输入。

### 4. 页面内查看日志
全屏闹钟页新增按钮：

```text
查看语音调试日志
```

点击后可直接查看当天日志、日志路径，并可一键复制全部日志。

### 5. 日志读取能力
`VoiceAlarmDebugLog.kt` 新增：

- `logDirectoryPath(context)`
- `latestLogText(context, maxBytes)`
- 内部 `latestLogFile(context)`

日志仍写入：

```text
Android/data/<package>/files/voice_alarm_logs/voice_alarm_YYYYMMDD.log
```

同时也写入 Logcat：

```bash
adb logcat -s VoiceAlarmDebug
```

## 主要修改文件

- `android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmActivity.kt`
- `android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmDebugLog.kt`
- `lib/voice_alarm/voice_alarm_page.dart`
