# V32 预设行为闹钟响铃 / 震动修复

## 目标

用户要求：预设行为到点后应像系统闹钟一样响铃，并可开启震动，不需要再发送普通通知提醒。

## 已完成

1. 预设行为闹钟触发后不再通过通知提醒展示。
2. `AlarmReceiver` 收到 `behavior_preset_alarm` 后直接启动 `BehaviorPresetAlarmFormActivity`。
3. 全屏表单启动后自动使用系统默认闹钟铃声播放，优先读取 `RingtoneManager.TYPE_ALARM`，失败时回退到系统铃声 / 通知音。
4. 表单内增加响铃停止逻辑：完成、未完成、跳过、稍后再说或页面销毁都会停止铃声和震动。
5. 预设行为编辑页新增“开启震动”开关。
6. 新增 `reminder_vibrate` 字段，旧数据自动默认开启震动。
7. 调度预设行为闹钟时不再请求通知权限，只检查精确闹钟权限。
8. Manifest 增加 `android.permission.VIBRATE`。

## 说明

- Android 桌面和后台启动策略由系统控制。源码已改为闹钟到点直接拉起全屏原生表单，并在表单中响铃/震动。
- Android 12+ 仍可能需要用户授予“闹钟和提醒 / 精确闹钟”权限。
- 不再依赖 `POST_NOTIFICATIONS` 权限来完成预设行为闹钟响铃。
