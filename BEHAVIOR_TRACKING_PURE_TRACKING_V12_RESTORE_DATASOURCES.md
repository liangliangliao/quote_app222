# V12 纯行为跟踪 + 数据源保留版

本版本基于 V11 的“纯行为跟踪简化版”继续调整：

## 设计原则

行为跟踪模块仍然只做“观察与记录”，不再恢复行为改变、干预实验、A/B 替代方案等功能。

但保留以下与“行为证据采集”直接相关的能力：

1. 记录提醒配置：只提醒用户记录，不要求改变行为。
2. Health Connect 身体数据同步：作为身体状态层面的行为证据。
3. Android 真实屏幕使用时间读取：作为时间/行为层面的外部证据。
4. Android 真实系统日历读取：作为计划时间块，确认后才写入正式记录。
5. 番茄钟事件总线：专注开始/完成/取消事件，完成后生成时间块记录。

## 入口调整

顶部 Tab 从 V11 的 4 个增加为 5 个：

- 首页
- 七层
- 记录
- 统计
- 数据源

“数据源”集中放置所有外部证据采集能力，避免干扰日常秒记/七层记录。

## 新增/恢复文件

- `lib/behavior_tracking/behavior_tracking_external_sources.dart`

包含：

- `BehaviorTrackingNativeBridge`
- `BehaviorTrackingExternalDao`
- `BehaviorTrackingExternalService`
- `BehaviorTrackingDataSourcesPage`
- `BehaviorPomodoroEventBus`
- 简化导入确认队列
- 简化提醒配置表

## 修改文件

- `lib/behavior_tracking/behavior_tracking_home_page.dart`

新增：

- 数据源 Tab
- 通知点击 payload 处理
- 点击行为跟踪提醒后打开对应模板

## 不恢复的内容

为了保持模块纯粹，本版本仍不恢复：

- 行为干预实验
- A/B 替代方案比较
- 行为改变建议
- 复杂阶段完成度验收
- 云同步与复盘邮件

## 真机验证说明

当前源码层已接回 Flutter 与 Android 原生通道，但以下能力仍必须在 Android 真机验证：

- 使用情况访问权限授权与 UsageStatsManager 数据读取
- READ_CALENDAR 权限与 CalendarContract 数据读取
- Health Connect 权限与数据同步
- 通知权限、精确闹钟权限、点击通知后路由跳转
