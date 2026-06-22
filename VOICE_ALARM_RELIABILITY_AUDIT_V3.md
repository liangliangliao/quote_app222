# Voice Alarm Reliability Audit V3

本轮继续检查发现并修复：

1. `voice_alarm_page.dart` 的 Resemble voice_uuid 三元表达式被重复插入一行，可能导致 Dart 编译失败，已修复。
2. Android 14+ 多数新装应用不会默认获得 `SCHEDULE_EXACT_ALARM`，闹钟类应用应补充 `USE_EXACT_ALARM`，已在 Manifest 中声明。
3. 用户从系统设置授予精确闹钟权限后，缺少自动重排；已为 `BootReceiver` 增加 `android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED`，收到后恢复语音闹钟调度。
4. 为极端 OEM 冷启动场景增加 `Activity PendingIntent` 兜底触发：主链路仍为 BroadcastReceiver -> ForegroundService -> Full-screen notification，兜底链路为 ForegroundService PendingIntent 和 Activity PendingIntent。
5. 修复长语音播报仍可能被自己打断：之前 `onBeginningOfSpeech` 和云 STT 能量检测会在识别到任何声音时立刻 `postponeVoiceReplay()`，即使那只是闹钟播报回声；现在先做文本级回声过滤，再决定是否停止/推迟播报。
6. 增加 `alarmVoicePlaying` 状态：系统播报开始到结束期间，原生 `SpeechRecognizer` 不再抢麦克风打断当前播报；云 STT 仍可捕获文本并经回声过滤后再处理。
7. 锁屏 Activity 增强：API 27+ 继续 `setShowWhenLocked/setTurnScreenOn`，同时补上兼容 flags 与 `requestDismissKeyguard` 尝试。
8. `VoiceAlarmRingingService` 增加 `onTaskRemoved` 兜底，用户滑掉闹钟任务时重发前台通知并维持唤醒锁。

仍需注意：用户在系统设置里“强行停止/Force stop”应用后，Android 会冻结应用闹钟与广播，普通应用无法绕过；部分国产 ROM 的自启动/后台弹窗限制也需要用户在系统管家里放行。
