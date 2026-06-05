# Microsoft To Do 同步与写回集成说明 V14

本次基于用户提供的源码包集成了 Microsoft To Do API，并调整“外部数据同步”页面结构。

## 已完成

1. 同一个 Microsoft 登录用于 OneNote 与 Microsoft To Do。
2. Microsoft Graph scope 已扩展为：
   - User.Read
   - Notes.Read
   - Tasks.Read
   - Tasks.ReadWrite
   - offline_access
3. 外部数据同步首页已精简：
   - 只保留 Microsoft 登录/退出
   - 只显示 OneNote 与 Microsoft To Do 两个入口
   - 配置迁移到右上角“统一配置”页面
4. OneNote 同步迁移到独立页面：
   - 按笔记本名称/分区名称精准同步
   - 笔记本 → 分区 → 页面 → 附件 结构展示
5. 新增 Microsoft To Do 独立页面：
   - 可同步全部任务列表，或按任务列表名称精准同步
   - 保存 任务列表 → 任务 → 检查项/附件/关联资源 结构
   - 支持任务列表本地新增、修改、删除，也可写回 Microsoft To Do
   - 支持任务本地新增、修改、删除，也可写回 Microsoft To Do
   - 任务列表 → 任务 → 任务详情分页/分层展示
6. 新增本地数据库表：
   - ms_todo_lists
   - ms_todo_tasks
   - ms_todo_task_children
   - ms_todo_settings
   - external_api_logs 复用并记录 todo 来源日志

## 需要在 Microsoft Entra 中额外添加权限

在 quoteapp_note 应用中添加 Microsoft Graph 委托权限：

- Tasks.Read
- Tasks.ReadWrite

添加后需要重新登录 Microsoft，旧 token 不会自动拥有新权限。

## 主要文件

- lib/external_data/onenote_config.dart
- lib/external_data/onenote_pages.dart
- lib/external_data/todo_models.dart
- lib/external_data/todo_dao.dart
- lib/external_data/todo_service.dart
- lib/external_data/todo_pages.dart
- lib/main.dart

## 注意

当前容器没有 Flutter/Dart SDK，无法在容器中执行 flutter analyze 或 flutter build apk。请在本地或 GitHub Actions 编译验证。
