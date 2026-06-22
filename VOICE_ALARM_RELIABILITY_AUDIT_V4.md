# Voice Alarm Reliability Audit V4

本轮继续围绕“发现之旅 → 语音闹钟”做第四轮可靠性审计，重点检查 app 进程不在、最近任务移除、锁屏/重启、全屏通知、重复 PendingIntent、播报与识别互相抢占、以及旧状态残留。

## 新发现的问题与修复

### 1. 直接 ForegroundService 兜底触发不会自动排下一次每日闹钟

V3 已新增 `AlarmManager -> PendingIntent.getForegroundService -> VoiceAlarmRingingService` 作为部分 ROM 上广播链路不稳定时的兜底。但这个兜底路径绕过了 `VoiceAlarmReceiver`，因此如果只有这个路径成功，而广播和 Activity fallback 被限制，当前闹钟会响，但下一次每日闹钟不会被重新排程。

修复：

- `VoiceAlarmScheduler.alarmServiceIntent()` 增加 `fromAlarmFire=true`。
- `VoiceAlarmRingingService.onStartCommand()` 检测 `fromAlarmFire`，自动调用 `VoiceAlarmScheduler.scheduleNextDaily()`。
- 重复触发无副作用，因为 requestCode 固定且 `FLAG_UPDATE_CURRENT` 会覆盖同一模式闹钟。

### 2. 锁屏通知动作在 Direct Boot 阶段不够完整

`VoiceAlarmActionReceiver` 之前没有 `directBootAware=true`。如果闹钟在重启后、用户尚未首次解锁时响起，锁屏通知上的“关闭 / 5 分钟后提醒”动作可能不稳定。

修复：

- Manifest 中为 `VoiceAlarmActionReceiver` 增加 `android:directBootAware="true"`。

### 3. 停止闹钟仍依赖 startService(ACTION_STOP)，后台/锁屏下可能被系统拒绝

V3 的 `VoiceAlarmRingingService.stop()` 通过 `context.startService(ACTION_STOP)` 通知服务停止。在 Android O+ 后台服务限制下，通知动作或锁屏状态下启动一个普通 service 可能抛异常。虽然大多数情况下服务已在前台，但这个停止链路不应只依赖 startService。

修复：

- 停止前立即清理 `activePayload` 持久状态。
- 立即取消前台通知 ID。
- 保留 `startService(ACTION_STOP)`，同时增加 `stopService()` 兜底。
- 避免用户已经点击关闭后，旧 `activePayload` 又让 App 打开时恢复全屏闹钟。

### 4. activePayload 没有过期时间，服务被系统异常杀死后可能留下陈旧响铃状态

V3 为了在服务被系统杀死后恢复全屏界面，持久化了 active payload。但如果服务异常退出、旧状态未清理，用户后来打开 App 时可能误恢复一个早已过期的全屏闹钟。

修复：

- 增加 `activeAt` 时间戳。
- `readActivePayload()` 只接受 12 小时内的 active payload。
- 旧版本没有 `activeAt` 的残留状态会被自动清理。

### 5. 闹钟 TTS 播放状态广播可能重复触发，导致 Activity 状态机混乱

V3 中系统 TTS 在已初始化时会手动发送一次 `ACTION_VOICE_PLAYBACK_START`，随后 `UtteranceProgressListener.onStart()` 又发送一次。虽然通常不会直接中断播报，但会导致 Activity 中的 `alarmVoicePlaying / suppressRecognitionUntil / watchdog` 被重复重置。

修复：

- 在 `VoiceAlarmRingingService` 中新增 `notifyVoicePlaybackStart()` / `notifyVoicePlaybackEnd()` 状态锁。
- 播放开始/结束广播只在状态真实变化时发送一次。
- 系统 TTS 只依赖 `UtteranceProgressListener` 发开始/结束事件。
- `speak()` 返回 `TextToSpeech.ERROR` 时会主动结束状态，避免 Activity 误以为仍在播报。

### 6. 自定义语音文件存在但无法播放时，会直接返回而不是退回系统 TTS

V3 只检查 `voicePath` 文件存在。如果文件损坏、格式不支持、权限不可读，`createPlayer()` 会失败，但 `playVoiceOnce()` 直接 return，导致闹钟可能只剩音乐/震动，没有朗读内容。

修复：

- 当自定义 voice file 创建 MediaPlayer 失败时，继续 fallback 到系统 TTS 播报 `text`。

### 7. TTS 引擎初始化失败后对象未清空，可能阻止后续重试

如果 `TextToSpeech` 初始化失败，V3 将 `alarmTtsReady=false`，但没有把 `alarmTts=null`。后续 `speakAlarmTextOnce()` 会因为 `alarmTts != null` 直接 return，无法重试。

修复：

- 初始化失败时 shutdown 并置空 `alarmTts`。
- 下一轮语音重播可以重新初始化 TTS。

### 8. 云识别在闹钟播报期间仍可能大量录到扬声器回声

V3 虽然通过文本相似度过滤回声，但在播报期间仍会频繁把大段扬声器声音送给云识别，带来延迟、误判和网络浪费。

修复：

- Microsoft STT：播报期间把单次录音窗口从 6500ms 降到 2800ms。
- 讯飞 STT：播报期间把流式窗口从 9000ms 降到 3200ms。
- 播报期间 VAD 能量阈值从 520 提高到 1400，降低扬声器回声触发概率。
- 播报期间起始等待和静音结束判断更短，减少卡住。
- 仍保留用户插话能力：如果用户声音明显进入，会进入统一 `onSpeechChunk()`，再由文本回声过滤判断是否是真人语音。

### 9. 长语音播报超过 45 秒时，Activity 可能提前恢复识别

V3 的播放结束 watchdog 固定 45 秒。如果用户设置了很长的闹钟文案或自定义长音频，播放尚未结束时 Activity 可能重新开启识别，进而把剩余播报当成用户语音。

修复：

- watchdog 改为根据文本长度估算：`12s + 字数 * 320ms`。
- 范围限制在 45s 到 150s。
- 播放结束广播正常到达时仍会立即恢复，不会无谓等待到 watchdog。

### 10. 短片段闹钟回声过滤不够强

V3 的 `isLikelyAlarmPlayback()` 要求识别文本长度至少 8。如果扬声器回声只识别出“早上好新”“今天辛苦了”等短片段，可能被当成用户语音，从而触发 `postponeVoiceReplay()` 并打断当前播报。

修复：

- 播报中/回声抑制期允许 4 字以上短片段参与回声匹配。
- 增加字符 bigram 相似度比例判断，减少短回声误触发。

## 本轮修改文件

- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmScheduler.kt`
- `android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmRingingService.kt`
- `android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmActivity.kt`

## 仍需真实设备验证的边界

1. 用户在系统设置中“强行停止 / Force stop”App 后，Android 会冻结该应用的闹钟、广播和后台启动能力，普通应用不能绕过。
2. 部分国产 ROM 仍需要用户手动允许：自启动、后台弹出界面、锁屏显示、忽略电池优化、通知、全屏通知。
3. Android 13+ 若用户拒绝通知权限，前台服务仍可能运行，但锁屏通知/全屏提醒体验会明显下降。
4. 云 STT 与扬声器外放天然存在回声问题；当前已通过状态锁、短窗口、VAD 阈值、文本回声过滤减少误判，但极大音量/外放环境仍建议真机调参。

## 静态检查

- Manifest XML 解析通过。
- 关键 Kotlin/Dart 文件括号结构检查通过。
- 仍无法完成 Gradle 编译，因为源码包缺少 `android/gradle/wrapper/gradle-wrapper.jar`，当前环境无法解析 `raw.githubusercontent.com` 下载 wrapper。
