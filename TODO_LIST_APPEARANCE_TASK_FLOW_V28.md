# Microsoft To Do 列表外观与任务创建流程修复 v28

## 本次修复

1. 任务卡片白底偏暗
   - `_TaskCard` 明确设置 `color: Color(0xFFFFFFFF)`。
   - 增加 `surfaceTintColor: Colors.transparent`，避免 Material 3 默认 surface tint 让白色卡片发灰。
   - `ListTile` 也设置纯白 `tileColor`。
   - 保持轻微阴影和圆角，接近 Microsoft To Do 在图片/颜色背景上的白色任务卡片效果。

2. 列表页创建任务后停留在当前列表页
   - `TodoListPage._addTask()` 改为只刷新当前列表数据。
   - 保存成功后不会跳转回首页。
   - 增加保存成功提示：`任务已保存，已停留在当前列表。`

3. 新增/修改列表页面简化
   - 移除大段说明文字和过大的预览区域。
   - 改成更轻量的结构：列表名称 → 简洁预览 → 外观选择 → 写回开关 → 保存按钮。
   - 保留颜色、内置照片、本地导入背景图片能力。
   - 新建列表保存成功后返回新列表 ID；首页创建列表后会自动打开新列表，更接近 Microsoft To Do 创建列表后的体验。

## 修改文件

- `lib/external_data/todo_pages.dart`

## 说明

Microsoft Graph To Do v1.0 仍不开放列表背景颜色/图片字段，因此外观继续只保存在 App 本地，不写回 Microsoft To Do。
