# V30 行为观察：预设行为系统闹钟全屏确认表单

本次升级围绕“预设行为每日确认”增加系统闹钟能力。

## 新增能力

1. 预设行为支持系统闹钟提醒
   - 编辑/新增预设行为时，可开启“到点弹出全屏确认表单”。
   - 可选择提醒时间。
   - 保存后自动注册未来 14 天内符合重复日期的系统闹钟。

2. 到点弹出全屏原生表单
   - 闹钟触发后，不进入 Flutter 首页。
   - 直接显示原生全屏确认表单。
   - 表单包含：预设行为、类别、计划量、实际完成量、实际时长、备注。
   - 支持直接选择：完成 / 未完成 / 跳过。

3. 原生落库
   - 完成后写入正式行为观察记录。
   - 同时写入 `behavior_observation_preset_checkins` 每日确认表。
   - 未完成/跳过只写入每日确认状态；如之前已有完成记录，会删除对应正式记录，避免数据误导。

4. 权限提示
   - Android 13+ 需要通知权限。
   - Android 12+ 可能需要“闹钟和提醒/精确闹钟”权限。
   - 如果没有精确闹钟权限，保存时会提示用户授权后重新注册。

## 主要修改文件

- `lib/behavior_tracking/behavior_tracking_models.dart`
- `lib/behavior_tracking/behavior_tracking_dao.dart`
- `lib/behavior_tracking/behavior_observation_presets.dart`
- `android/app/src/main/kotlin/com/example/quote_app/BehaviorPresetAlarmFormActivity.kt`
- `android/app/src/main/kotlin/com/example/quote_app/BehaviorObservationNativeRecorder.kt`
- `android/app/src/main/kotlin/com/example/quote_app/NotifyHelper.kt`
- `android/app/src/main/java/com/example/quote_app/am/AlarmReceiver.java`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/res/values/styles.xml`

## 说明

当前容器无法进行 Android 真机验证。该版本已完成源码层改造，但全屏闹钟表单是否能在锁屏/后台场景直接弹出，还需要在真机上验证系统通知权限、精确闹钟权限和厂商后台限制。
