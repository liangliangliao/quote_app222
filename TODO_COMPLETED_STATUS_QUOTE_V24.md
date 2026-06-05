# Microsoft To Do 已完成视图、完成状态切换与尼采名言卡片修复 v24

## 1. 首页新增“已完成”智能视图

- 在首页智能入口中新增 `已完成`。
- 本地查询条件：`status = 'completed'`。
- 该视图会展示所有已同步的已完成任务，保留任务原始所属列表关系。

## 2. 同步已完成任务及其结构

- 同步每个 Microsoft To Do 列表时，除普通 `/tasks?$top=100` 外，额外请求：
  - `/tasks?$top=100&$filter=status eq 'completed'`
- 以任务 ID 去重，避免重复插入。
- 对已完成任务同样同步：
  - checklistItems / 步骤
  - attachments / 附件
  - linkedResources / 关联资源
- 如果某些 Microsoft 账号/租户不支持该过滤查询，会记录到 To Do API 日志，并继续普通同步，不中断整个同步流程。

## 3. 列表页点击圆圈直接切换完成状态

- 任务列表卡片左侧圆圈改为可点击按钮。
- 未完成任务点击后：本地标记 `completed`，并 PATCH 写回 Microsoft To Do。
- 已完成任务点击后：本地恢复 `notStarted`，并 PATCH 写回 Microsoft To Do。
- 操作完成后自动刷新当前列表。

## 4. 编辑页点击标题旁圆圈标记完成

- 任务编辑页标题左侧圆圈支持点击。
- 点击后会在 `completed` / `notStarted` 之间切换。
- 保存时沿用原有写回流程，同步到 Microsoft To Do。

## 5. 首页新增尼采名言艺术卡片

加入名言卡片：

> 有了生命的“为什么”，几乎就能承受一切“如何”。
>
> Hat man sein warum? des Lebens, so verträgt man sich fast mit jedem wie?

出处：Friedrich Nietzsche, *Götzen-Dämmerung*, “Sprüche und Pfeile”, §12.

## 修改文件

- `lib/external_data/todo_dao.dart`
- `lib/external_data/todo_service.dart`
- `lib/external_data/todo_pages.dart`
