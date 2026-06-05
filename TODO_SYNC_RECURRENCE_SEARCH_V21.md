# Microsoft To Do 同步修复 v21

## 1. 重复任务写回修复

- 修复 App 内选择“每周”后写回 Microsoft To Do 时，重复规则未能同步的问题。
- 重复规则 JSON 生成改为更接近 Microsoft Graph `patternedRecurrence` 的最小有效结构：
  - `pattern.type`
  - `pattern.interval`
  - 周重复时写入 `daysOfWeek` 与 `firstDayOfWeek`
  - `range.type`
  - `range.startDate`
  - `range.recurrenceTimeZone`
- 移除 App 自动生成时不必要的 `month: 0`、`dayOfMonth: 0`、空 `daysOfWeek`、`index: first`、`endDate: 0001-01-01`、`numberOfOccurrences: 0` 等字段，降低 Graph 对 To Do recurrence PATCH/POST 的 400 风险。
- 写回前会再次规范化 recurrence JSON：
  - 每天：只保留 daily 必要字段。
  - 每周：确保有 `daysOfWeek`。
  - 工作日：转换为 weekly + Monday-Friday。
  - 每月 / 每年：只保留对应必要字段。
- 取消此前 recurrence PATCH 失败时静默降级为“不带 recurrence 的 PATCH”的行为。现在如果 Microsoft Graph recurrence 写回失败，会明确报错，并保留本地修改，避免用户误以为已同步成功。

## 2. 同步转圈冗余优化

- 首页 AppBar 刷新按钮不再重复显示 CircularProgressIndicator。
- 列表页 AppBar 刷新按钮不再重复显示 CircularProgressIndicator。
- 同步配置卡片里的“开始同步 To Do”按钮不再重复显示 CircularProgressIndicator。
- 页面同步中只保留状态横幅中的一个轻量进度提示，避免同一页面多处同时转圈。

## 3. 搜索功能

- 新增 `TodoSearchPage`。
- 首页和列表页右上角新增搜索入口。
- 支持搜索：
  - 任务标题
  - 任务备注 / body_text
  - 步骤 / checklist item 标题
  - 子项内容
- 搜索结果可点击进入任务详情页。

## 4. 主要修改文件

- `lib/external_data/todo_pages.dart`
- `lib/external_data/todo_service.dart`
- `lib/external_data/todo_dao.dart`
