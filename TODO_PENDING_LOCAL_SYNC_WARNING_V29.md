# v29 Microsoft To Do 本地待同步写回与醒目提醒修复

## 修复目标

本版本针对“本地创建或修改任务/列表并保存后，没有成功同步到 Microsoft To Do；后续再次同步时失败；同时用户缺少明显提醒”的问题做修复。

## 主要变化

1. **同步前先写回本地待同步数据**
   - 首页全量同步、列表页精准同步开始前，会先扫描本地 `local_status != 'synced'` 的列表、任务、步骤。
   - 本地新建列表会先 POST 到 Microsoft To Do，成功后把本地 `local_` 列表 ID 替换成远端列表 ID。
   - 本地修改过的远端列表会 PATCH 写回 Microsoft To Do。
   - 本地新建任务会先 POST 到其所属远端列表。
   - 本地修改过的远端任务会 PATCH 写回 Microsoft To Do。
   - 本地步骤/checklist 修改会跟随任务写回。

2. **修复 local_ 数据后续同步失败**
   - 不再在本地新建列表/任务后直接抛出“不能直接更新远端”。
   - 如果用户选择“同时写回 Microsoft To Do”，而列表仍是本地 `local_`，会先创建远端列表，再继续写回任务。
   - 如果任务仍是本地 `local_`，会走远端创建流程，而不是 PATCH 一个不存在的远端任务。

3. **待同步数据醒目提醒**
   - 首页增加黄色醒目提醒卡片：显示本地待同步列表、任务、步骤数量。
   - 列表页也会显示当前列表相关的待同步提醒。
   - 提醒卡片提供“立即写回并同步”按钮。
   - 任务卡片原有的本地状态标记继续保留，例如“本地新增待写回”“本地修改待写回”。

4. **保存失败提示更准确**
   - 如果本地已经保存，但远端写回失败，页面不再只显示笼统“保存失败”。
   - 会明确提示：本地已保存为待同步状态，但写回 Microsoft To Do 未成功，可稍后在黄色提醒处重试同步。

## 修改文件

- `lib/external_data/todo_models.dart`
- `lib/external_data/todo_dao.dart`
- `lib/external_data/todo_service.dart`
- `lib/external_data/todo_pages.dart`

## 注意

当前容器没有 Flutter/Dart SDK，因此未在容器内执行 `flutter analyze` 或 APK 编译验证。
