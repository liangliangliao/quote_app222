# Microsoft To Do completed/deletion/parent-list behavior fix v25

本次修复围绕 Microsoft To Do 的真实业务结构重新整理：

1. **已完成任务只进入“已完成”视图**
   - `我的一天`、`重要`、`计划内`、`全部`、普通任务列表页均只显示未完成任务。
   - `已完成` 智能视图显示所有已完成任务。
   - 侧栏普通列表计数改为未完成任务数，更贴近 Microsoft To Do 的侧栏计数逻辑。

2. **删除同步与本地镜像结构修复**
   - 每次同步真实列表后，会用远端返回的 task id 集合反向校验本地任务。
   - 如果某个远端任务已被删除，本地会把任务和步骤/附件/关联资源一起标记为 `remote_deleted`，从所有智能视图和列表页隐藏。
   - 全量同步后，会用远端 task list id 集合校验本地列表；远端已删除的列表会连同其任务、子结构和本地组映射一起隐藏。
   - App 内删除列表时，也会级联隐藏该列表下任务和子结构，避免任务继续出现在计划内、全部、重要、我的一天、已完成等视图中。

3. **任务显示所属上级列表**
   - `TodoTaskRecord` 新增 `listDisplayName` 派生字段。
   - 列表页、智能视图页、搜索页的任务摘要会显示 `列表：xxx`。
   - 任务详情页新增 `所属列表：xxx`。

4. **数据模型理解说明**
   - Microsoft Graph v1.0 中，`todoTask` 始终属于某一个 `todoTaskList`。
   - App 现在以 `ms_todo_lists -> ms_todo_tasks -> ms_todo_task_children` 为本地镜像主线，并通过级联隐藏避免脏数据继续显示。
   - Graph v1.0 仍不开放 Microsoft To Do 侧栏“组”的远端字段，所以组结构仍按 App 本地结构保存。
