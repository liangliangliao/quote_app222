# 行为观察 V15：数据源自动同步、健康重新授权、类别必选与待确认跳转

本版本基于 V14 buildfix 继续完善，重点修复与增强：

## 1. Health Connect 支持重新授权

- 在「数据源」页的 Health Connect 卡片中新增「重新授权」。
- 新增 `HealthConnectDietContextService.openSettings()`。
- Android 原生 `HealthDietHealthConnectChannel` 新增 `openSettings` 方法，优先打开 Health Connect 授权/管理页面。
- 用户可重新管理睡眠、步数、运动等健康数据权限，然后返回模块重新同步。

## 2. 真实屏幕使用时间 / 系统日历支持每日自动读取时间配置

- 新增数据表：`behavior_tracking_auto_sync_plans`。
- 默认内置两类自动读取计划：
  - `screen_usage`：真实屏幕使用时间，默认 23:00；
  - `calendar`：真实系统日历，默认 07:30，读取未来 7 天。
- 「数据源」页新增「每日自动读取配置」卡片。
- 用户可启用/关闭各数据源、修改每日读取时间，并注册未来 30 天自动读取任务。
- 自动读取结果不会直接进入正式记录，而是写入待确认队列。

## 3. 原生后台自动导入器

新增：

- `BehaviorObservationNativeImporter.kt`

它允许 App 未打开时由 `AlarmReceiver` 触发：

- 读取 Android `UsageStatsManager` 今日应用使用时长；
- 读取 Android `CalendarContract.Instances` 日历事件；
- 映射成行为观察记录 JSON；
- 写入 `behavior_tracking_import_queue`，等待用户确认。

`AlarmReceiver.java` 新增 `type=behavior_auto_sync` 分支。

## 4. 行为记录类别必选，并支持自定义类别

- 新增数据表：`behavior_observation_categories`。
- 默认类别自动写入并兼容旧记录类别。
- 秒记与完整编辑页均要求类别必选。
- 用户可新增自定义类别，例如：写作、通勤、家务、短视频。
- 记录列表筛选会自动包含自定义类别。

## 5. 复盘页待确认项可点击跳转

- 复盘页如果存在待确认导入项，会显示黄色提示卡。
- 点击后自动跳转到「数据源」Tab 的待确认导入队列。
- 队列项支持点击查看详情，包括：原始数据、映射后的行为记录、确认写入、忽略。

## 说明

当前容器环境仍无法下载 Gradle wrapper，也没有 Flutter/Dart 真机环境，因此未能执行真实 APK 编译和真机授权验证。已完成源码结构和括号配对检查。
