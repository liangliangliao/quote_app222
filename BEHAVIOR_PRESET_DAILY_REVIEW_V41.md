# BEHAVIOR_PRESET_DAILY_REVIEW_V41

本次补丁完善行为观察模块的“预设行为每日复盘”流程：

- 新增每日预设行为复盘提醒设置，默认 22:30，可自定义时间，可关闭/开启。
- 复盘提醒使用系统闹钟级 AlarmClock，全屏通知入口保留声音、震动、锁屏/悬浮窗唤起能力。
- 新增复盘页：汇总当天所有启用且排期命中的预设行为，逐项标记完成/未完成。
- 完成项保存为预设行为完成记录，并取消当天相关闹钟。
- 未完成项必须填写原因，提供常见原因下拉框并支持“其他”自定义输入。
- 未完成项可选择转入明天；转入后保留/重建未来闹钟提醒，不转入则移除当天提醒。
- 统计当天总数、完成数、未完成数、完成率，并保存每日复盘记录。
- 复盘页支持查看当前明细与历史复盘记录明细。
- 复盘完成后点击“下一步”直接进入明天预设行为准备页，可新增明天预设并注册闹钟提醒。

涉及文件：

- `lib/behavior_tracking/behavior_observation_presets.dart`
- `lib/behavior_tracking/behavior_tracking_models.dart`
- `lib/behavior_tracking/behavior_tracking_dao.dart`
- `lib/behavior_tracking/behavior_tracking_home_page.dart`
- `lib/services/native_guard.dart`
- `android/app/src/main/kotlin/com/example/quote_app/BehaviorPresetAlarmScheduler.kt`
- `android/app/src/main/kotlin/com/example/quote_app/BehaviorPresetAlarmFormActivity.kt`
- `android/app/src/main/kotlin/com/example/quote_app/BehaviorPresetAlarmRingingService.kt`
- `android/app/src/main/kotlin/com/example/quote_app/BehaviorPresetAlarmOverlay.kt`

验证说明：当前环境缺少 Gradle wrapper jar，无法离线执行完整 Android/Flutter 编译；已完成源码级检查与闹钟/路由入口一致性检查。
