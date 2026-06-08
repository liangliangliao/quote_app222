# V21 行为观察通知直达表单与去重修复

## 本次修复目标

针对通知栏提醒的实际体验问题，本版做了三项收束：

1. 点击通知栏「选择层面填写」不再进入行为观察首页，而是直接进入轻量记录表单页。
2. 同一条通知点击后只打开一次表单，避免重复弹出 2-3 次。
3. 通知栏正文删除复杂操作步骤说明，只保留简短提醒。

## 关键调整

### 1. 新增通知直达表单页

新增 `BehaviorObservationNotificationFormPage`。

该页面会：

- 直接加载类别；
- 默认进入“选择观察层面”的表单；
- 用户通过下拉框选择时间、行为、情绪、认知、结果、环境、身体；
- 选择后仅显示该层对应字段；
- 保存后直接关闭该表单页。

### 2. 通知点击去重

新增 `BehaviorObservationNotificationOpenGuard`。

原因是原生通知点击可能同时经过：

- 通用通知通道 `native.scheduler`；
- 行为观察专用通道 `behavior.tracking.native`；
- 冷启动 payload 消费逻辑。

过去可能导致同一条通知弹出多个编辑页。本版用 payload 指纹在短时间内去重。

### 3. NativeGuard 路由调整

`NativeGuard` 收到 `behavior_tracking` payload 后，不再 push `BehaviorTrackingHomePage`，而是直接 push：

```dart
BehaviorObservationNotificationFormPage(...)
```

这样用户点击通知后看到的就是表单页，而不是首页。

### 4. 通知栏文案精简

`NotifyHelper.sendBehaviorObservationReminder` 删除 BigText 中的操作步骤说明。

旧版显示：

> 打开后：1）在下拉框选择观察层面；2）系统只显示该层对应字段；3）填写后保存。

新版只显示简短提醒，例如：

> 现在可以记录一条行为观察。

## 修改文件

- `lib/behavior_tracking/behavior_tracking_home_page.dart`
- `lib/services/native_guard.dart`
- `lib/behavior_tracking/behavior_tracking_external_sources.dart`
- `android/app/src/main/kotlin/com/example/quote_app/NotifyHelper.kt`

## 注意

当前容器无法执行真实 Flutter/Android 编译与通知真机测试。源码层已完成逻辑修复，仍需在 Android 真机上验证通知点击路径。
