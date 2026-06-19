# 可持续卓越实验室 V4：Prompt 配置中心与闭环一致性修复

本补丁基于 v30 继续修复 P0/P1/P2 遗留问题，并将“可持续卓越实验室”的全部 AI Prompt 接入设置页的 AI 提示词统一配置中心。

## P0 修复

1. Todo 正文不再无限追加污染。
   - 改为固定管理区块：`<!-- sustainable_excellence:start --> ... <!-- sustainable_excellence:end -->`
   - 每次更新替换区块，而不是不断追加“当前阶段/下一环”。
   - 最近事件只保留 5 条。

2. Todo 传参改为 JSON。
   - `extraContext` 从分号拼接改为 `jsonEncode`。
   - 避免 Todo 正文中出现分号、换行、等号导致上下文截断。

3. Todo 导入种子真正接入。
   - 从 Todo 进入时先调用 `buildCaseSeedFromTodo()`。
   - AI 不可用或解析失败时使用稳定 Todo 种子，不再完全依赖临时 fallback。

4. 失败复盘写回下一轮 Todo 使用最新 Case。
   - `applyFailureReview()` 后重新读取最新实验，再写回 Todo。

5. 训练页返回详情页自动刷新。
   - 完美主义训练器 / 过程享受训练页返回后自动 `_reload()`。

6. 行动执行页避免重复 Action 日志。
   - 计时结束只切换到恢复阶段，不再写入 action 证据。
   - 真正“完成并复盘”时才写入 action 证据。

7. 恢复记录按阶段限制。
   - 行动阶段禁用手动恢复记录。
   - 准备阶段记录行动前恢复。
   - 恢复/复盘阶段记录行动后恢复。

## P1 增强

1. 完美主义扫描 Prompt 真正接入 AI 服务。
   - 新增 `generatePerfectionismScan()`。
   - 完美主义训练完成后调用 AI/兜底扫描，写入 aiSummary 与详情。

2. 压力—恢复规划 Prompt 真正接入 AI 服务。
   - 新增 `generatePressureRecoveryPlan()`。
   - 恢复记录时调用，用于生成节律、警示和恢复建议。

3. 过程享受重构 Prompt 真正接入 AI 服务。
   - 新增 `generateProcessReframe()`。
   - 过程训练保存时调用，生成 1% 体验、低压力方式和行动中提醒。

4. 每日/周度复盘避免重复堆积。
   - 每天/每周只保留同类型同周期最新一份复盘，新的复盘会覆盖旧周期报告。

5. 积极心理课程模块反向接入。
   - 在“积极心理知行课”顶部增加 Lecture 14–16 实践入口。

## P2 长期能力

1. 成长档案支持从剪贴板导入/合并 JSON。
   - 首页新增“从剪贴板导入档案”。

2. Prompt 全部进入 AI 提示词统一配置中心。
   - 新增模块：`可持续卓越实验室`
   - 可配置：全局价值层、目标转实验、完美主义扫描、压力恢复、失败复盘、过程享受、每日/周度复盘、输出格式。

## 涉及文件

- `lib/sustainable_excellence/sustainable_excellence_prompt_config.dart`
- `lib/sustainable_excellence/sustainable_excellence_ai_service.dart`
- `lib/sustainable_excellence/sustainable_excellence_todo_bridge.dart`
- `lib/sustainable_excellence/sustainable_excellence_home_page.dart`
- `lib/sustainable_excellence/sustainable_excellence_pages.dart`
- `lib/sustainable_excellence/sustainable_excellence_dao.dart`
- `lib/pages/ai_prompt_settings_page.dart`
- `lib/pages/settings_page.dart`
- `lib/external_data/todo_pages.dart`
- `lib/positive_psych_module/positive_psych_module_home_page.dart`
