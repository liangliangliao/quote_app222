# 发现之旅语音闹钟冷启动与播报中断修复 V2

## 修复问题 1：App 进程不在/最近任务被移除后到点无提醒

本次在原有 `AlarmManager.setAlarmClock -> VoiceAlarmReceiver -> VoiceAlarmRingingService -> 全屏通知/Activity` 主链路基础上增加了更强的兜底：

1. `VoiceAlarmScheduler` 增加 `FLAG_RECEIVER_FOREGROUND`，让闹钟广播以更高优先级派发。
2. 保留主链路 `setAlarmClock`，同时保留 `setExactAndAllowWhileIdle` 广播兜底。
3. 新增第三条兜底链路：`AlarmManager -> PendingIntent.getForegroundService(...) -> VoiceAlarmRingingService`。
   - 目的：即使某些设备/OEM 对冷启动广播派发不稳定，也尽量直接拉起前台响铃服务。
   - 该链路延后 1.5 秒触发，避免与主链路完全同时竞争。
4. `VoiceAlarmRingingService` 增加同 payload 去重：如果主链路已经开始响铃，兜底服务再次到达不会重新执行 `stopSignals()/startSignals()`，避免重复触发导致当前播报/铃声被重置。
5. `VoiceAlarmChannel` 和 Flutter 设置页增加“忽略电池优化”检查/跳转，降低被最近任务清理或厂商省电策略拦截的概率。
6. `startForeground(...)` 增加多层 fallback，避免前台服务类型或权限异常直接导致服务崩溃。

说明：如果用户在系统设置里对 App 执行“强行停止/Force stop”，Android 会清除/冻结该应用的闹钟与广播，任何普通应用都无法在用户重新打开 App 前被系统唤醒。代码已尽量覆盖“进程被系统杀死/最近任务清理/锁屏/重启恢复”的常规场景。

## 修复问题 2：闹钟提醒语音刚开始播报就中断

根因在 `VoiceAlarmActivity.handleAlarmVoicePlaybackStart()`：

- 服务开始播报时发送 `ACTION_VOICE_PLAYBACK_START`。
- Activity 收到后立刻调用 `postponeAlarmVoiceReplay(30_000L)`。
- `postponeAlarmVoiceReplay()` 会进入 `VoiceAlarmRingingService.postponeVoiceReplay()`，直接 `stop()` 当前 `voicePlayer/alarmTts`。
- 因此语音播报刚开始就被自己停止。

已修改为：

- 播报开始时只做短暂回声抑制和识别暂停。
- 不再停止当前播报。
- 只有用户真正开始说话、AI 正在回复、关闭/贪睡等明确交互时，才推迟下一轮播报。

## 涉及文件

- `android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmScheduler.kt`
- `android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmRingingService.kt`
- `android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmActivity.kt`
- `android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmChannel.kt`
- `lib/voice_alarm/voice_alarm_page.dart`
