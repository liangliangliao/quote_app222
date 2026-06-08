# To Do 目标实践系统 v52 修复说明

本次针对用户反馈的三个问题做修复：

1. 修复已转化目标详情页报错
   - 旧数据库表 `goal_problem_nodes` 可能缺少 `solution_id` 字段，导致进入目标详情页时执行 `WHERE solution_id = ?` 报错。
   - 现在 `ensureTables()` 会在运行时自动补齐 `goal_problem_nodes.node_id / goal_id / solution_id` 等核心字段。
   - 同时会对旧数据中的空 `node_id`、空 `solution_id` 做迁移补值，避免详情页空转或直接崩溃。

2. 修复重新分析时报错
   - 旧数据库表 `goal_solution_plans` 可能缺少 `solution_id` 字段，导致重新分析后插入方案时报错。
   - 现在会自动补齐 `goal_solution_plans.solution_id / goal_id` 字段。
   - 对旧方案记录自动生成迁移版 `solution_id`。

3. 明确区分 AI 成功结果与本地兜底数据
   - 新增 `goal_profiles.ai_provider / ai_model_label / ai_used_fallback` 字段。
   - 保存目标分析结果时会记录本次是否使用兜底。
   - 目标详情页如果检测到兜底内容，会显示黄色提示卡：明确告诉用户“当前目标内容是本地兜底，不代表 AI 已成功深度分析”。
   - 新生成的兜底内容也会带有“本地兜底分析 / 兜底过程价值 / 兜底阻力判断”标记，避免误以为这是 AI 对目标的真实深度分析。

说明：旧数据无需清除 App 数据；升级后打开 To Do 目标实践系统会自动修复表结构。
