# V23 行为观察：清空全部记录按钮

本次更新在「行为观察 → 记录」页增加了「清空全部记录」按钮，便于用户在测试、重新开始记录或清理历史数据时一键删除全部行为观察记录。

## 功能说明

- 入口：行为观察 → 记录 → 记录列表卡片右下角「清空全部记录」
- 清空范围：仅删除 `behavior_tracking_records` 表中的行为观察记录
- 保留内容：自定义类别、提醒配置、数据源授权/同步配置、自动读取配置等不会被删除
- 安全措施：点击后会弹出二次确认，并显示将删除的记录数量

## 修改文件

- `lib/behavior_tracking/behavior_tracking_dao.dart`
  - 新增 `deleteAllRecords()`
- `lib/behavior_tracking/behavior_tracking_home_page.dart`
  - 新增 `_clearAllRecords()`
  - 记录页新增「清空全部记录」按钮
