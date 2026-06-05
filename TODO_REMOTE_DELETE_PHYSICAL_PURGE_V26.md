# Microsoft To Do v26：远端删除后的本地物理清理

本版本把 v25 的“远端已删除后仅 local_deleted 隐藏”改为更接近 Microsoft To Do 镜像逻辑的物理清理方案。

## 关键原则

- Microsoft To Do 远端已经不存在的真实 list / task，本地主镜像表最终也不再长期保留。
- 展示层不再依赖 remote_deleted 隐藏旧数据，而是通过同步阶段把旧任务、步骤、附件、关联资源从本地库物理删除。
- 只保留必要的同步日志与 tombstone 记录，不再让主任务表成为僵尸数据来源。

## 修改点

1. 新增 `ms_todo_sync_tombstones`
   - 保存被远端删除确认后的最小墓碑记录：entity_type、entity_id、parent_id、reason、raw_json、deleted_at_ms。
   - 只用于排查同步历史，不参与任务展示和智能视图查询。

2. 远端任务缺失处理
   - `markRemoteTasksDeletedForList` 改为物理删除任务。
   - 同步某个列表后，远端返回集合中不存在的 task id 会被判定为远端已删除。
   - 本地执行：删除 task children → 删除 task 主记录 → 写 tombstone。

3. 远端列表缺失处理
   - `markRemoteListsDeleted` 与 `markRemoteListDeleted` 改为物理删除列表镜像。
   - 本地执行：删除 group-list 映射 → 删除列表下 children → 删除列表下 tasks → 删除 list 主记录 → 写 tombstone。

4. App 内删除处理
   - 删除任务：远端删除成功后，本地任务和子结构物理删除；如果只做本地删除，也直接物理删除。
   - 删除列表：远端删除成功后，本地列表、任务、子结构和组映射物理删除；如果只做本地删除，也直接物理删除。
   - 删除 checklist item：远端删除成功后物理删除；本地删除同样物理删除。

5. 兼容旧版本僵尸数据
   - `ensureTables` 中会清理 v25 遗留的 `local_status = 'remote_deleted'` 行。
   - 清理时会把主记录写入 tombstone，再删除旧主表/子表数据。

## 影响

- 计划内、全部、重要、我的一天、已完成、普通列表页不会再被远端已删除任务污染。
- 本地数据库不会长期堆积 remote_deleted 僵尸任务。
- 同步日志仍保留在 `external_api_logs`，删除墓碑保留在 `ms_todo_sync_tombstones`。
