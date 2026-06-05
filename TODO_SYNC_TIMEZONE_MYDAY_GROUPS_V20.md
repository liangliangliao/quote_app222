# Microsoft To Do 同步修复说明 v20

本版本基于 v19 继续修复测试反馈，重点处理时间一致性，并明确 Microsoft Graph 当前公开能力边界。

## 1. 时间 / 时区一致性

已新增 To Do 首选同步时区：

- 默认值：`Asia/Shanghai`。
- 首页同步配置卡片可直接选择时区。
- 任务编辑页“更多同步字段”中也可选择时区。
- 选择结果保存到本地 `ms_todo_settings.todo_preferred_time_zone`。
- Microsoft Graph 读写请求统一携带：`Prefer: outlook.timezone="<用户选择的时区>"`。
- 本地“我的一天 / 计划内”的当天判断改为使用用户选择的时区，而不是固定设备本地时区或 UTC。

涉及文件：

- `lib/external_data/todo_dao.dart`
- `lib/external_data/todo_service.dart`
- `lib/external_data/todo_pages.dart`

## 2. “我的一天”同步能力确认

结论：不能通过 Microsoft Graph v1.0 对 Microsoft To Do 原生“我的一天”标记做稳定双向同步。

原因：

- Graph v1.0 的 `todoTask` 公开字段中没有可读写的 `isMyDay` / `isOnMyDay` / `myDay` 字段。
- Graph beta 的 `/me/planner/myDayTasks` 属于 Planner，不是 To Do v1.0 todoTask；并且个人 Microsoft 账户不支持。

因此本版本保留：

- App 本地 `is_my_day` 标记。
- 到期日 / 开始日期 / 提醒时间落在所选时区今天的任务，会进入本地“我的一天”智能视图。
- UI 中明确提示此限制，避免误以为可以写回 Microsoft To Do 原生 My Day。

## 3. Microsoft To Do 组同步能力确认

结论：不能通过 Microsoft Graph v1.0 可靠读取或写回 Microsoft To Do 侧栏原生“组”。

原因：

- Graph v1.0 To Do API 公开的是 `todoTaskList` 和 `todoTask`，`todoTaskList` 属性中没有组 ID、组名、组排序、列表归组关系字段。
- 旧的 Outlook taskGroups API 已被 Microsoft 标记为 deprecated，并且已停止返回数据，不能作为 To Do 组同步方案。

因此本版本保留：

- App 本地组结构：`ms_todo_groups`、`ms_todo_group_lists`。
- App 内可创建组、编辑组、删除组、在组内创建列表。
- 列表和任务本身仍通过 Microsoft Graph To Do API 与远端同步。

## 4. 仍建议后续测试项

1. 在首页同步配置中选择 `Asia/Shanghai` 后，手动同步一次。
2. 在 Microsoft To Do 中创建带提醒 / 到期时间的任务，然后同步到 App，检查显示时间。
3. 在 App 中修改提醒 / 到期时间并写回，重新打开 Microsoft To Do 检查是否一致。
4. 验证“我的一天”和“组”是否显示为本地能力边界提示，不再误报为远端双向同步失败。
