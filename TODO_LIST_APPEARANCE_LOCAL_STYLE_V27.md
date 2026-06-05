# v27 - Microsoft To Do 列表外观本地化

## 结论
Microsoft Graph To Do v1.0 的 todoTaskList 公开字段不包含 Microsoft To Do 客户端里的列表背景图片、背景颜色、主题照片字段；创建列表 API 只要求/写回 displayName。因此列表颜色和图片不能可靠从 Microsoft To Do 同步，也不能写回 To Do 原生客户端外观。

## 本版本实现

1. 本地数据库 `ms_todo_lists` 新增外观字段：
   - `theme_color`
   - `background_mode`: `color` / `asset_photo` / `local_photo`
   - `background_asset`
   - `background_local_path`

2. 同步远端列表时保留本地外观字段。
   - Microsoft Graph 列表同步只覆盖列表名称、owner/shared/wellknown 等公开字段。
   - 不会因为远端列表刷新导致本地颜色/背景图片丢失。

3. 新建/修改列表页面增加 Microsoft To Do 风格外观设置：
   - 选择背景颜色；
   - 选择内置照片背景；
   - 从本地相册导入自定义背景图片。

4. 任务列表页按外观字段渲染：
   - 颜色背景：全页颜色主题；
   - 图片背景：全页图片背景 + 深色遮罩 + 顶部文字阴影；
   - 任务卡片保持白色卡片风格，增强可读性。

## 相关文件
- `lib/external_data/todo_models.dart`
- `lib/external_data/todo_dao.dart`
- `lib/external_data/todo_service.dart`
- `lib/external_data/todo_pages.dart`
- `assets/todo_bg/`
- `pubspec.yaml`
