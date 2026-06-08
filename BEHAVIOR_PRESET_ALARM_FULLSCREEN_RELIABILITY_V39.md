# V39 预设行为闹钟全屏表单稳定性修复

本补丁基于 V38，针对“闹钟会响，但 App 在后台/进程不在时全屏表单只偶尔弹出”的问题继续修复。

## 问题原因

V38 已经通过 Receiver + 前台响铃服务保证了响铃，但全屏表单仍主要依赖一次 fullScreenIntent / Activity 启动。部分 Android/OEM ROM 会出现以下情况：

- 同一毫秒注册两个 setAlarmClock PendingIntent 时，ROM 只投递其中一个，到点只进入响铃服务，Activity 型 PendingIntent 没有稳定触发。
- 通知被标记为 silent 后，部分 ROM 会把高优先级 full-screen 通知降级，只显示普通前台服务通知，不弹全屏。
- 屏幕关闭/锁屏时只有 PARTIAL_WAKE_LOCK，CPU 被唤醒但屏幕未被主动唤醒，fullScreenIntent 的可见性不稳定。
- Android 14+ 对由后台进程发送 Activity PendingIntent 有额外限制，需要在运行时尽量声明 background activity start opt-in。

## 修改内容

1. `NativeSchedulerK.scheduleAlarmClockAt()`
   - 保留准点 Receiver + 前台响铃服务。
   - 将 Activity 型 UI 闹钟改为 `epochMs + 1000ms` 的 staggered setAlarmClock，避免和 Receiver 在同一毫秒被 ROM 合并。
   - 额外注册 `setExactAndAllowWhileIdle(epochMs + 1800ms)` 的 Activity 兜底触发。

2. `BehaviorPresetAlarmRingingService`
   - 新建通知渠道 `behavior_preset_alarm_ringing_v39_fullscreen`，避免旧 silent 渠道属性不可变导致降级。
   - 不再调用 `NotificationCompat.setSilent(true)`，仅将渠道声音设为 null，响铃/震动仍由服务统一控制。
   - 新增短时 `FULL_WAKE_LOCK | ACQUIRE_CAUSES_WAKEUP | ON_AFTER_RELEASE`，让闹钟到点时主动点亮屏幕。
   - 前台服务启动后在 0ms / 350ms / 1200ms / 3000ms / 6500ms 多次尝试拉起表单：
     - `PendingIntent.send()`；
     - Android 14+ 通过反射设置 background activity start allowed；
     - `startActivity()`；
     - 重新发送 full-screen notification。

3. `NotifyHelper.sendBehaviorPresetAlarmFullScreen()`
   - 新建 full-screen 通知渠道 `behavior_preset_alarm_v39_fullscreen`。
   - 移除 `setSilent(true)`，保留 `IMPORTANCE_HIGH + CATEGORY_ALARM + fullScreenIntent`。

4. `BehaviorPresetAlarmFormActivity`
   - 同时使用现代 API 和旧 window flags：
     - `setShowWhenLocked(true)`
     - `setTurnScreenOn(true)`
     - `FLAG_SHOW_WHEN_LOCKED`
     - `FLAG_TURN_SCREEN_ON`
     - `FLAG_DISMISS_KEYGUARD`
     - `FLAG_KEEP_SCREEN_ON`

5. `AndroidManifest.xml`
   - 给全屏闹钟表单单独设置 `taskAffinity="com.example.quote_app.behaviorAlarm"`，避免复用主 Flutter 任务导致后台拉起不稳定。

## 测试建议

安装 V39 后，进入：行为观察 → 预设 → 闹钟提醒，点击“重新注册已开启提醒”。

需要确认系统权限：

- 通知权限已允许。
- Android 14+ 已允许“全屏提醒/全屏通知”。
- 国产 ROM 需要允许锁屏显示/后台弹出界面/自启动/忽略电池优化，否则系统仍可能拦截第三方 App 的全屏 UI。

说明：Android 系统允许闹钟声音通过前台服务稳定播放，但全屏 UI 仍受系统/ROM 的后台弹窗策略约束。V39 已把可用的系统闹钟级路径、full-screen notification、前台服务重试、屏幕唤醒和 Activity PendingIntent 兜底全部接入。
