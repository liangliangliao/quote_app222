# V27 行为观察：预设行为与每日确认

本次升级新增“预设行为”能力，用于把用户提前计划好的固定行为与临时发生的非计划行为区分开。

## 业务定位

行为观察模块仍然只做观察与记录，不做行为干预。预设行为的作用是：

- 用户提前定义自己经常要做的行为，例如阅读、运动、背单词、睡前复盘；
- 每天在“预设”页看到当天应确认的行为；
- 用户可确认“完成 / 未完成 / 跳过”；
- 完成时生成一条来源为 `planned_behavior` 的正式行为记录；
- 普通秒记、时间块、通知记录等仍然作为非计划行为保存。

## 新增数据表

### behavior_observation_presets

保存预设行为定义：

- name：预设行为名称
- category：行为类别
- primary_layer：主要观察层面
- target_value / unit：计划量与单位
- default_duration_min：默认时长
- weekdays_json：重复星期，空数组表示每天
- active：是否启用

### behavior_observation_preset_checkins

保存每日确认结果：

- preset_id
- check_date_ms
- status：done / missed / skipped
- actual_value
- actual_duration_min
- note
- record_id：完成后生成的正式行为记录 ID

## UI 改动

- 新增顶部 Tab：预设
- 预设页包含：
  - 新增预设行为
  - 日期切换
  - 当日应确认 / 已完成 / 待确认统计
  - 每个预设行为的完成、未完成、跳过、编辑操作
  - 全部预设管理

## 与非计划行为区分

完成的预设行为生成正式记录时，会带上：

- source = planned_behavior
- mode = planned_behavior_checkin
- entryMode = preset_confirmation
- templateKey = planned_behavior
- tags 包含：预设行为、计划行为

记录页新增筛选项：

- 预设行为
- 非计划行为

复盘页也会把预设行为作为独立来源/类别展示，避免与临时行为混淆。

## 说明

当前容器环境仍无法执行 Flutter / Android 编译验证，本次已完成源码结构检查、括号配对检查和 zip 完整性检查。
