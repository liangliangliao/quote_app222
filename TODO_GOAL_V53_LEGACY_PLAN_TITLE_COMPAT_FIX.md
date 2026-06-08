# To Do 目标实践系统 V53：legacy plan_title 兼容与兜底标识修复

本次修复针对已安装旧包后出现的运行时 SQLite 结构不一致问题：

## 修复内容

1. 修复目标转化时报错：
   - `NOT NULL constraint failed: goal_solution_plans.plan_title`
   - 原因：旧数据库中 `goal_solution_plans` 曾创建过 `plan_title TEXT NOT NULL`，而新代码只写入 `title`。
   - 处理：插入方案时动态读取真实表结构；若存在 `plan_title / plan_id / plan_name` 等旧字段，会同时写入兼容值。

2. 增强旧表结构容错：
   - 新增通用 `_compatibleInsertValues`，插入前自动过滤不存在字段。
   - 自动补齐旧表里没有默认值的 NOT NULL 字段，避免再次因为旧字段约束导致转化失败。

3. 修复旧方案数据显示：
   - 若旧数据只有 `plan_title` 没有 `title`，会自动把 `plan_title` 同步到 `title`。
   - 读取方案时支持 `title / plan_title / plan_name` 等兼容字段。

4. 强化本地兜底识别：
   - 旧目标如果没有 AI 来源、或内容明显来自本地通用兜底模板，会自动标记为本地兜底。
   - 目标详情页会更明确提示：这些内容只是兜底启动方案，不代表 AI 已成功深度分析。

## 安装说明

直接覆盖安装即可，不需要清除 App 数据。
