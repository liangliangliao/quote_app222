# 可持续卓越实验室 V5：Prompt 配置中心稳定化与数据闭环收口

本次在 v31 基础上继续修复 P0 / P1 / P2 级问题，重点不是增加静态页面，而是修复编译风险、数据一致性、AI 场景反写、Todo 结构化关联和 Prompt 配置中心长期可用性。

## P0 修复

1. 修复 `sustainable_excellence_dao.dart` 中搜索文本拼接的非法多行普通字符串，改为 `List<String>.join('\n')`。
2. Todo 导入上下文进一步结构化：从 Todo 详情页进入时额外传入 checklist、due、reminder、importance、recurrence、categories、My Day 等信息。
3. `buildCaseSeedFromTodo()` 真正吸收 Todo checklist，并把 checklist 转为三个行动实验的步骤来源。
4. Todo 写回新增 `generatedTodoTaskIds` 历史字段，避免只保留最近一个生成任务。
5. Todo 管理区块显示最近生成任务与历史生成任务，继续采用固定区块替换，避免污染原 Todo 正文。
6. 行动执行页增加阶段约束：准备阶段不能直接失败学习，未到复盘阶段不能完成复盘，计时结束只进入恢复阶段，不再重复写 action 日志。
7. 恢复记录调用 AI 后会反写 `recoveryPlan` 与压力/恢复状态。
8. 完美主义训练调用 AI 后会反写 `modeDetection.perfectionismLevel` 与 `valueMapping`。
9. 过程享受训练调用 AI 后会反写 `processEnjoyment` 与过程连接状态。
10. 每日/周度复盘口径统一：周报按自然周统计，而不是内容按最近 7 天、覆盖按自然周。

## P1 增强

1. 可持续卓越所有 `se_` Prompt 保存前会检查关键占位符；缺失时弹窗提醒，并允许用户选择“仍然保存”。
2. Prompt 配置中心新增“预览拼接”，可查看模板被示例参数替换后的效果。
3. 可持续卓越 Prompt 保存前会自动备份旧模板。
4. 可持续卓越 Prompt 支持历史备份列表与恢复。
5. 可持续卓越 Prompt 支持模块级导出/导入。
6. “恢复源码默认模板”对可持续卓越模块改为清除本地覆盖值，而不是把默认模板重新保存成本地模板。

## P2 长期能力

1. 成长档案导出升级为完整归档：cases + reviews + 自定义 Prompt 配置。
2. 成长档案导入支持合并 cases、reviews 和 prompt_config。
3. Case 导入冲突处理优化：同 ID 时按更新时间选择主体，并合并日志，避免旧备份覆盖新成长证据。
4. 搜索范围扩展到生成 Todo 历史、螺旋阶段、失败类型、压力等级、完美主义等级等字段。

## 仍未做的高成本事项

- 没有强行迁移 SQLite，仍保持 KeyValue JSON 架构，避免一次性破坏现有数据。
- 没有新增系统级通知/提醒服务，后续可单独做“恢复节律提醒”和“失败后重新开始提醒”。
- 没有和现实乐观模块建立数据库级双向 relation 表，目前仍以跳转与上下文传入为主。
