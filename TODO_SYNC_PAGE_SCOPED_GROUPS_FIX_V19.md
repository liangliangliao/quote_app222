# Microsoft To Do 外部数据同步修复说明（v19）

本次主要修复：

1. 首页仍保留进入页面后自动全量同步；列表页/智能视图页取消进入页面自动同步。
2. 列表页右上角刷新、下拉刷新改为当前页精准同步：真实列表按 listId 请求 `/me/todo/lists/{id}` 与该列表 tasks，不再按列表名或空列表名触发全量同步。
3. 智能视图页（我的一天、重要、计划内、全部、已分配给我）刷新时只刷新本地智能视图，不再在子页面误触发全量远端同步。
4. 增加 App 本地 To Do 组结构：`ms_todo_groups`、`ms_todo_group_lists`，首页按“组 → 列表”展示，并支持新建组、修改组、删除组、在组内新建列表。
5. 创建列表时可绑定到本地组；如果同时写回 Microsoft To Do，远端列表创建成功后会把本地组映射从 local list id 更新为远端 list id。
6. 修复重复任务 PATCH 时的 Graph `Microsoft.OData.Edm.Date` 报错：未修改重复规则时不再把 recurrence 原样带入 PATCH；确实修改重复规则且 Graph 返回 Edm.Date 错误时，会记录日志并自动退化为不带 recurrence 的 PATCH，避免标题、备注、状态、日期等其他字段全部写回失败。
7. “我的一天”标记继续作为 App 本地智能视图标记保存，并在远端同步回来的任务覆盖时保留该本地标记，避免本地开关失效。

注意：Microsoft Graph To Do v1.0 的公开 `todoTaskList` 资源未提供列表组字段，`todoTask` 资源也未提供可写回的 To Do My Day 标记；因此组结构和 My Day 标记采用 App 本地结构保存。
