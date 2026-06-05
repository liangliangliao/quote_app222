# Microsoft To Do 截止日期 / 提醒 / 重复字段修复 v18

## 本次修复

1. 任务编辑页不再让用户手动输入截止日期字符串，而是通过系统日期选择器 + 时间选择器选择。
2. “到期”字段保存为 Microsoft Graph `dateTimeTimeZone` 所需结构：
   - 本地保存：`yyyy-MM-ddTHH:mm:ss`
   - 写回 Graph：`{"dateTime":"yyyy-MM-ddTHH:mm:ss","timeZone":"Asia/Shanghai"}`
3. “提醒我”同样支持日期 + 时间选择，并写回 `reminderDateTime` 与 `isReminderOn`。
4. “重复”字段改为接近 Microsoft To Do 的选择式操作：
   - 不重复
   - 每天
   - 每周
   - 每月
   - 每年
   - 自定义 recurrence JSON
5. 选择重复时会自动生成 Graph `patternedRecurrence` JSON，并根据当前截止日期生成 `range.startDate`。
6. 修改截止日期后，如果当前重复规则是内置规则（每天/每周/每月/每年），会自动同步更新 recurrence 的开始日期与星期/月日参数。
7. 详情页、列表摘要中的截止日期/提醒时间显示改为“5月3日周日 09:00”这种 To Do 风格。
8. 写回 Microsoft To Do 前会统一规范化时间字符串，避免出现手输格式不一致导致 Graph API 拒绝。

## 注意

Microsoft Graph v1.0 支持 `dueDateTime`、`reminderDateTime`、`recurrence` 等字段，但 To Do API 对重复任务 PATCH 的兼容性在个别账号/服务端版本上可能存在限制；如果远端写回失败，App 会保留本地修改并在 API 日志中记录完整错误。
