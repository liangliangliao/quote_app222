# TODO Goal V51 Runtime Schema and Rotating Prompts Fix

## 修复内容

1. 修复目标转化时报错：`no such column: sort_order`。
   - 原因：v50 新增 `goal_solution_plans.sort_order` 后，只在 `CREATE TABLE IF NOT EXISTS` 中声明；已安装过旧版本的用户数据库不会自动新增该字段。
   - 处理：在 `TodoGoalDao.ensureTables()` 中对 AI 目标相关表增加幂等列修复，覆盖 `goal_solution_plans`、`goal_problem_nodes`、`goal_step_reviews`。

2. 修复进入“已转化目标”详情页一直转圈的问题。
   - 原因：详情页 `_load()` 中数据库异常没有捕获，异常后 `_loading` 无法恢复为 false。
   - 处理：为首页和目标详情页 `_load()` 增加异常捕获，失败时停止转圈并展示错误。

3. 首页/转化页/今日旅程/复盘页/详情页的提示卡支持自动轮换。
   - `_ContextualQuoteCard` 改为 StatefulWidget。
   - 每 9 秒自动轮换当前场景下的多条提示。
   - 增加 `1/n` 提示序号和淡入淡出切换效果。

4. 顺手去除写回 Microsoft To Do 内容中的重复“父步骤”行。

## 涉及文件

- `lib/external_data/todo_goal_dao.dart`
- `lib/external_data/todo_goal_pages.dart`

## 注意

无需清除 App 数据。升级后首次进入 To Do 目标实践系统时会自动修复本地 SQLite 表结构。
