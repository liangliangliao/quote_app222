# Microsoft To Do recurrence PATCH fallback and search scope fix v22

## 修复内容

1. 修复重复规则写回失败

- 针对 Microsoft Graph To Do 在 PATCH `recurrence.range.startDate` / `endDate` 时可能返回 `Microsoft.OData.Edm.Date` 转换失败的问题，增加兜底方案。
- 当已有远端任务写回重复规则时，如果 PATCH 触发该错误：
  1. 使用同一 payload 通过 POST 创建一个带重复规则的新远端任务；
  2. 尝试删除旧远端任务；
  3. 用新远端任务 ID 替换本地任务记录；
  4. 后续步骤/checklist 会以新任务 ID 重新创建，避免步骤仍指向旧任务。
- 不再静默丢弃 recurrence，也不会提示“同步成功但实际重复规则未同步”。

2. 保留 v21 的 recurrence JSON 清洗

- 每周、工作日、每天、每月、每年仍生成标准 `pattern + range` 结构。
- 写回前继续清理 `month: 0`、`dayOfMonth: 0`、空数组、`0001-01-01` 等容易导致 Graph 报错的字段。

3. 搜索入口范围调整

- 搜索入口只保留在 Microsoft To Do 首页。
- 任务列表页不再显示搜索按钮，避免每个页面都有搜索功能。

## 主要修改文件

- `lib/external_data/todo_service.dart`
- `lib/external_data/todo_dao.dart`
- `lib/external_data/todo_pages.dart`
