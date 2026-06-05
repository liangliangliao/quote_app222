# Microsoft To Do 任务保存后详情页一直转圈修复 v23

## 问题
在任务详情页点击编辑，修改任务并同步成功后返回详情页，页面可能一直显示 CircularProgressIndicator。

## 根因
v22 为绕过 Microsoft Graph To Do 更新 recurrence 时的 Edm.Date PATCH 异常，会在必要时创建一个新的远端任务替代旧任务，并删除旧任务。此时本地任务主键会从旧 taskId 替换为新 taskId。

原详情页仍用路由传入的旧 taskId 重新读取任务；旧 taskId 已不存在，`getTask(oldId)` 返回 null。原 UI 使用 `t == null` 代表“加载中”，所以变成无限转圈。

## 修复
1. 详情页内部新增可变 `_taskId`，不再只依赖 widget.taskId。
2. 编辑页保存成功后返回实际 `savedTaskId`，而不是只返回 `true`。
3. 详情页接收到新的 taskId 后更新 `_taskId` 并重新读取。
4. 新建任务入口改为接收 `Object?` 返回值，只要非空就刷新列表，兼容返回 taskId。
5. 详情页增加 `_loading` 状态，区分“正在加载”和“任务不存在”。任务不存在时显示可操作提示，不再无限转圈。

## 修改文件
- `lib/external_data/todo_pages.dart`

## 备注
当前环境没有 Flutter / Dart SDK，因此未在容器内执行 Flutter 编译。
