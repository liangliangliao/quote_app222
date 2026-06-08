# V37 行为预设闹钟：全屏表单、指定铃声、震动可靠性修复

本次修复针对 v36 仍然存在的现象：后台/进程不在时到点只听到系统默认声音、不弹出全屏表单、选择的自定义 MP3 不生效、震动不执行。

## 关键修复

1. **全屏表单触发链路改为双 AlarmClock**
   - 同一闹钟时刻同时注册两个 `AlarmManager.setAlarmClock` 操作：
     - Receiver -> 前台响铃服务：保证后台/进程不在时仍先响铃/震动。
     - Activity UI：由系统闹钟 PendingIntent 直接拉起 `BehaviorPresetAlarmFormActivity`，增强后台/进程不在时的全屏表单弹出能力。
   - 表单 Activity 启动后也会主动确保响铃服务已启动，避免 UI 和声音链路互相依赖。

2. **避免通知渠道旧声音覆盖用户设置**
   - 行为预设闹钟通知渠道更换为新的静音渠道：
     - `behavior_preset_alarm_v37_silent`
     - `behavior_preset_alarm_ringing_v37_silent`
   - 通知本身 `setSound(null)` / `setSilent(true)`，铃声只由响铃服务按统一设置播放，避免 Android 8+ 旧通知渠道不可变导致继续播放系统默认通知声。

3. **修复自定义系统铃声 / MP3 无法播放**
   - 新增 `READ_MEDIA_AUDIO` 权限声明。
   - 系统铃声选择器打开前会请求音频读取权限；Android 12 及以下请求 `READ_EXTERNAL_STORAGE`。
   - 对系统默认铃声 URI 会展开为实际铃声 URI，减少 `content://settings/system/alarm_alert` 播放失败后退回默认音的问题。
   - `MediaPlayer` 播放失败时仍保留 `RingtoneManager` 兜底。

4. **增强震动执行**
   - 震动改为携带 `AudioAttributes.USAGE_ALARM` 执行。
   - 震动开关同时参考当前统一设置和 payload 中的 `alarmVibrate`，提高升级后旧 payload 的兼容性。

5. **权限提示**
   - 重新注册闹钟前会请求通知/音频权限。
   - Android 14+ 如果系统未允许全屏提醒，会打开全屏提醒权限页，用户开启后需要返回并重新注册。

## 测试建议

安装 v37 后建议执行一次：行为观察 → 预设 → 闹钟提醒 → 选择铃声/确认震动开启 → 重新注册已开启提醒。

如果选择的是本地 MP3，首次会弹出音频读取权限；授权后再重新注册一次。

注意：如果用户在系统设置中“强行停止”应用，Android 会阻止第三方 App 的闹钟 PendingIntent 触发，这属于系统限制，无法完全绕过。
