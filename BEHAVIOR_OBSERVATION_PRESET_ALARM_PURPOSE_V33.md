# V33 预设行为闹钟语义修正

本次修复围绕一个核心：预设行为闹钟不是要求用户“现在完成预设行为”，而是用于督促用户先做好行为预设，或确认已经收到预设提醒。

## 主要调整

1. 无预设行为也可以注册闹钟
   - 新增通用“行为预设提醒闹钟”。
   - 即使当天没有任何预设行为，也可以先设置提醒时间。

2. 当天没有预设行为时，闹钟弹出“完成行为预设”表单
   - 表单要求填写预设行为名称。
   - 不能直接跳过。
   - 如果用户关闭、返回或选择稍后，会在 5 分钟后再次响铃提醒。
   - 直到用户真正创建预设行为。

3. 当天已有预设行为时，闹钟只用于确认收到提醒
   - 全屏表单文案改为“预设提醒”。
   - 不再显示“完成 / 未完成 / 跳过”作为闹钟主操作。
   - 提供“我已收到预设提醒”和“5 分钟后再提醒”。
   - 实际完成情况仍在 App 的“预设 → 每日确认”里处理。

4. 保留系统闹钟铃声与震动
   - 到点响铃。
   - 可震动。
   - 表单关闭或确认后停止。

## 修改文件

- `lib/behavior_tracking/behavior_observation_presets.dart`
- `lib/behavior_tracking/behavior_tracking_models.dart`
- `android/app/src/main/kotlin/com/example/quote_app/BehaviorPresetAlarmFormActivity.kt`
- `android/app/src/main/kotlin/com/example/quote_app/BehaviorObservationNativeRecorder.kt`
- `android/app/src/main/kotlin/com/example/quote_app/BehaviorPresetAlarmScheduler.kt`
- `android/app/src/main/java/com/example/quote_app/am/AlarmReceiver.java`

## 验证说明

当前容器无法联网下载 Gradle wrapper，因此无法执行真实 Android 编译。已做源码结构与括号配对检查。
