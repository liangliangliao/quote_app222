# Voice Alarm Reliability + STT Smoothness Fix V1

## 修复范围
- 发现之旅页面下的 `lib/voice_alarm/voice_alarm_page.dart`
- Android 原生链路：
  - `VoiceAlarmScheduler.kt`
  - `VoiceAlarmReceiver.kt`
  - `VoiceAlarmRingingService.kt`
  - `VoiceAlarmActivity.kt`
  - `VoiceAlarmChannel.kt`

## 1. 进程不在、重启、锁屏全屏提醒

### 已修复
1. 闹钟到点主链路从 `AlarmManager -> Activity PendingIntent` 改为：
   `AlarmManager.setAlarmClock -> DirectBoot BroadcastReceiver -> Foreground Ringing Service -> FullScreen Notification -> LockScreen Activity`。
2. `VoiceAlarmReceiver` 使用 `goAsync()`，避免广播冷启动时还没拉起前台服务就被系统回收。
3. `VoiceAlarmScheduler` 对 exact alarm 权限被拒绝的情况增加 `setAndAllowWhileIdle` 兜底，避免直接注册失败导致完全没有提醒。
4. 保留设备保护存储 `deviceProtectedStorage`，`BootReceiver` 已在 `LOCKED_BOOT_COMPLETED / BOOT_COMPLETED / MY_PACKAGE_REPLACED / TIME_SET / TIMEZONE_CHANGED` 恢复语音闹钟。
5. `VoiceAlarmChannel` 新增：
   - `restore`
   - `canUseFullScreenIntent`
   - `requestFullScreenIntentPermission`
6. Flutter 保存闹钟时会检查：
   - 精确闹钟权限
   - Android 14+ 全屏通知权限
   - 麦克风权限
   - 通知权限

### 支持说明
- App 进程被杀：支持，由系统 AlarmManager 冷启动 BroadcastReceiver。
- 手机重启：支持，依赖 BootReceiver 恢复；用户未解锁前可从 device-protected prefs 恢复下一次闹钟。
- 锁屏/熄屏：支持，前台响铃服务 + `CATEGORY_ALARM` 全屏通知 + `VoiceAlarmActivity` 的 `showWhenLocked/turnScreenOn`。
- Android 14+：若用户关闭“全屏通知/全屏提醒”权限，只能退化为高优先级通知，无法保证自动弹出全屏页。

## 2. 语音识别不稳定、延迟高、漏字、卡住

### 已修复
1. 系统 SpeechRecognizer：
   - 优先使用 Android 12+ on-device recognizer，失败再回落普通 recognizer。
   - 将长静默等待从 2500ms/6000ms 降为 650~1200ms 级别。
   - 每次识别结束后 80ms 快速重启，减少断句间隔。
   - AI 请求中不再完全停止监听，可继续缓存用户新语音。
2. Microsoft STT：
   - 从固定 12 秒录音改为 VAD 短分段录音。
   - 检测到说话后立即暂停闹钟语音重播，只录有效语音段，约 900ms 静音后就提交识别。
3. 讯飞 STT：
   - 从固定 15 秒流式窗口改为 VAD 早停。
   - 检测说话后暂停闹钟语音重播，用户说完约 850ms 后关闭本轮流并处理结果。
4. 闹钟语音播报与用户说话冲突：
   - 原先播报开始会压制识别 30 秒，导致漏字。
   - 现在播报开始只保留约 1.4 秒短回声抑制，并立即通知响铃服务暂停本轮语音重播，音乐/震动继续。
5. 语音缓冲策略：
   - 云识别 final chunk 的处理延迟从 6500ms 降到 1400ms。
   - 系统识别 final chunk 的处理延迟从 2800ms 降到 900ms。
   - partial chunk 延迟从 4200ms 降到 1500ms。
   - “关闭闹钟/延迟五分钟”仍保持快速 250ms 响应。

## 注意
- Android 系统不允许所有场景都强制后台弹 Activity。当前实现使用官方推荐的 alarm/full-screen notification 路径；如果系统或用户关闭全屏通知，只能退化为通知。
- 云 STT 的最终稳定性仍受网络、服务商接口、API Key、机型麦克风/回声消除影响，但本次已解决源码中明显的长等待、强压制、AI 忙时停听、播报期间漏听等结构性问题。
