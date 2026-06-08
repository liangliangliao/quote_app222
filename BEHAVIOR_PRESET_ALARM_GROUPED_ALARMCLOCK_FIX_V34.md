# Behavior Preset Alarm Grouped AlarmClock Fix V34

本次修复聚焦行为跟踪/行为观察预设提醒闹钟：

- 使用 `AlarmManager.setAlarmClock` 注册预设行为闹钟，保证 App 后台、进程不在运行时仍按系统闹钟级别触发；并在开机/应用替换后恢复未来 14 天的预设闹钟。
- 按“日期 + 时 + 分”合并预设行为提醒。同一时刻多个预设行为只注册一个系统闹钟，触发时只显示一个全屏表单。
- 原生触发接收器会在响铃前重新查询数据库并合并同一时刻预设，兼容旧版本已注册的单预设闹钟，并用 fire guard 抑制 60 秒内重复表单。
- 全屏表单支持一次展示该时刻所有预设行为，点击确认后逐个写入“已收到预设提醒”记录。
- 当明天没有任何预设行为闹钟时，预设页会显示“设置预设提醒闹钟”入口；无预设时也可先设置预设提醒闹钟。
- 新增统一闹钟设置：系统铃声选择、音量、震动开关。响铃表单使用当前统一设置播放系统铃声并循环震动，通知渠道不再额外覆盖默认声音/震动。
- 稍后提醒也使用系统闹钟级调度，保持锁屏/后台提醒能力。

关键文件：

- `lib/behavior_tracking/behavior_observation_presets.dart`
- `lib/platform/native_scheduler.dart`
- `android/app/src/main/kotlin/com/example/quote_app/NativeSchedulerK.kt`
- `android/app/src/main/kotlin/com/example/quote_app/BehaviorPresetAlarmScheduler.kt`
- `android/app/src/main/kotlin/com/example/quote_app/BehaviorPresetAlarmFormActivity.kt`
- `android/app/src/main/kotlin/com/example/quote_app/BehaviorPresetAlarmSettings.kt`
- `android/app/src/main/kotlin/com/example/quote_app/BehaviorPresetRingtonePickActivity.kt`
- `android/app/src/main/kotlin/com/example/quote_app/NotifyHelper.kt`
- `android/app/src/main/java/com/example/quote_app/am/AlarmReceiver.java`
- `android/app/src/main/kotlin/com/example/quote_app/BootReceiver.kt`
