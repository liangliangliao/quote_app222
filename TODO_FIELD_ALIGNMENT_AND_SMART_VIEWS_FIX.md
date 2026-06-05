# Microsoft To Do 字段一致性与智能视图修复说明

本次针对用户反馈的两个问题进行修复：

## 1. 任务编辑字段不一致

已将 App 内 To Do 任务编辑/详情字段与 Microsoft Graph `todoTask` 主要字段对齐：

- title / 任务标题
- body / 任务正文 Note
- status / 状态
- importance / 重要程度
- startDateTime / 开始时间
- dueDateTime / 截止时间
- isReminderOn / 是否提醒
- reminderDateTime / 提醒时间
- recurrence / 重复规则 JSON
- categories / 分类
- attachments / 附件读取展示
- checklistItems / 检查项读取展示
- linkedResources / 关联资源读取展示

写回 Microsoft To Do 时，正文统一使用 `contentType: html`，避免部分账号在 PATCH body 时拒绝 text 类型。

## 2. “我的一天 / 重要 / 计划内 / 全部 / 组”的处理

Microsoft Graph v1.0 To Do API 官方主要暴露 `task lists -> tasks` 结构；任务列表组、To Do App 原生“我的一天”标记等不是 v1.0 To Do API 的可读/可写 taskList 字段。

因此本次采取安全实现：

- “重要”：本地智能视图，基于 `importance == high` 汇总。
- “计划内”：本地智能视图，基于存在 `startDateTime / dueDateTime / reminderDateTime` 汇总。
- “全部”：本地智能视图，汇总所有已同步任务。
- “我的一天”：本地近似智能视图，基于今天的 `startDateTime / dueDateTime / reminderDateTime` 汇总；不承诺等同于 To Do App 原生“我的一天”。
- “组”：官方 Graph v1.0 To Do API 未暴露远端列表组结构，本次不伪造远端组同步；真实任务列表仍可全部同步与写回。

## 数据库迁移

`ms_todo_tasks` 自动补充新增列：

- start_date_time
- start_time_zone
- is_reminder_on
- recurrence_json
- categories_json

已有安装无需手动删库，启动时自动 ALTER TABLE。
