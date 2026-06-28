# WOOP 行动引擎 V4 深度补全说明

本版本承认 V1/V2/V3 尚未完整实现最初产品设计方案，因此继续从“页面、数据、闭环、独立模块边界”四个层面补齐。

## 新增数据表

- `woop_action_plan_logs`：记录 if–then 计划是否真实触发、执行或卡住。
- `woop_action_daily_checkins`：记录每日能量、情绪、今日主线愿望和备注。

所有表继续使用 `woop_action_*` 前缀，与其他模块隔离。

## 新增模型

- `WoopActionPlanLog`
- `WoopActionDailyCheckIn`

## 新增 DAO 能力

- `addPlanLog`
- `listPlanLogs`
- `addDailyCheckIn`
- `listDailyCheckIns`
- `dailyCockpitJson`

并扩展 `counts()`：增加执行日志、Check-in 统计。

## 新增页面

- `WoopActionManualWizardPage`：手动 WOOP 向导，不依赖 AI，也能创建完整 W/O/O/P。
- `WoopActionTargetFilterPage`：目标筛选器，显式评估重要性、可行性、可控性、代价、归属感，并导向继续/调整/等待/放下。
- `WoopActionDailyCockpitPage`：今日 WOOP 驾驶舱，支持每日 Check-in、基于历史生成今日 24 小时 WOOP、对行动中卡片记录 if–then 执行结果。
- `WoopActionReviewCenterPage`：复盘中心，聚合 WOOP 卡、完成/障碍复盘、执行日志，并可生成周复盘/愿望地图卡。

## 首页工作台扩展

`WoopActionFeatureGrid` 从 6 个入口扩展为 10 个入口：

- 价值引导
- 场景工具库
- 手动 WOOP
- 目标筛选器
- 今日驾驶舱
- 愿望地图
- 障碍雷达
- if–then 计划库
- 复盘中心
- Prompt 配置

## 卡片详情页扩展

新增 if–then 执行日志记录：

- 记录已执行
- 记录未触发/卡住

并在详情页集中展示该卡的执行日志，补齐“计划是否真正触发”的行为数据闭环。

## 产品设计覆盖增强

本版本补齐了此前缺失的关键产品设计点：

- WOOP 不只是 AI 生成：增加手动向导。
- 目标筛选不只是文字字段：增加目标筛选器页面。
- 今日 24 小时 WOOP 不只是模板：增加每日驾驶舱、Check-in 和执行日志。
- if–then 不只是展示：增加执行记录。
- 复盘不只是单卡详情：增加全局复盘中心和周复盘生成。
- 愿望可继续、调整、等待、放下：通过目标筛选和愿望地图强化。

## 仍需本地验证

当前沙盒无 Flutter/Dart SDK，无法执行 `flutter analyze` 或 `flutter build`。请在本地运行构建命令，如出现编译日志，可继续基于日志修复。
