# PATCH_REALISTIC_OPTIMISM_TRAINING_SYSTEM_V19_DEEP_SCENE_SEPARATION

本次补丁基于最终版产品设计方案，对 v18 “场景聚焦 UI”之后仍然存在的类似问题做继续核查与修复。

## 发现的问题

1. 核心训练流虽然入口减少为 4 个，但内部 4 步表单仍然对所有 scene 使用同一套“复盘/感恩/Prime/身份”收尾，导致过程行动、失败免疫、情绪容器仍然容易看起来相似。
2. `RotCoreBusinessFlowPage._finish()` 在拿到 AI 输出后，用 `_buildDeterministicPayload()` 对 AI payload 做 `addAll` 覆盖，导致 AI 的 scene 专属输出被本地通用闭环内容覆盖，是“不同选项结果相似”的关键原因之一。
3. L3/L4 安全模式只保存草稿并返回第一步，没有生成安全支持结果页，用户无法看到清晰的“当前适合/不适合/下一步安全行动”。
4. 输出校验器仍然使用全局强制规则，要求所有非安全场景都必须有 Prime、身份、If-Then 等字段，导致非主场景更容易触发 fallback，进一步造成结果同质化。
5. 详情页缺少 P2 场景和可控失败挑战的专属展示区，`todo_goal_bridge`、`daily_review`、`course_card` 等容易落入默认事件重构模板。
6. “环境”页仍混入事件强度分级、过程行动计划等后台诊断沉淀，产品层级仍不够清晰。
7. “证据”页把“生成了 5 分钟行动”的记录误当成“我做成过”，没有区分真实已完成行动证据与未完成卡点。

## 修复内容

1. 场景专属收尾
   - 情绪容器：收尾改为“稳定与是否继续”。
   - 过程行动/Todo：收尾改为“行动证据”。
   - 失败免疫/可控失败：收尾改为“恢复与心理抗体”。
   - 感恩/晚间复盘：收尾改为“感恩、品味与明日线索”。
   - Prime/Anti-Prime：收尾改为“环境线索”。

2. 修复 AI 输出被本地通用 payload 覆盖的问题
   - 新增 `_mergeAiWithSessionPayload()`。
   - 改为保留 AI scene 专属结构，只用本地会话字段补足用户手动输入的事实、强度、情绪、可控点和行动计划。

3. L3/L4 安全分流落地
   - 新增 `_buildSafetyPayload()`。
   - 高强度/安全风险不再只保存草稿，而是生成安全支持 record 并进入结果页。
   - 禁止普通重构、感恩、失败挑战和身份拔高。

4. 场景化校验器
   - `RealisticOptimismTrainingOutputValidator` 改为 scene-aware。
   - 只有相关场景才要求 Prime、身份、If-Then、感恩、心理抗体或 P2 产物。
   - 避免为了满足统一 JSON 而把所有工具都强行填满。

5. 详情页场景专属展示
   - 新增可控失败挑战专属 section。
   - 新增 P2 / 日常延伸产物 section。
   - 支持 `todo_goal_bridge`、`daily_review`、`course_card`、`role_model_case`、`proactive_reminder`、`monthly_report` 的标题、焦点说明和主展示区。
   - 行动证据 FAB 只在适合的行动类场景出现，L3/L4 不显示。

6. 页面层级清理
   - “环境”页只保留 Prime、Anti-Prime、关系表达。
   - 强度分级与过程计划沉淀移动到“高级/后台诊断沉淀”。

7. 证据库真实化
   - DAO 新增 `listAllActionEvidence()`。
   - “我做成过”只显示真实完成的 action_evidence。
   - 未完成行动单独进入“A2. 我看见了卡点 / 未完成也能复盘”。

## 设计原则

普通用户看到的是少数真实场景入口；内部工具由系统自动调用。统一 JSON 是数据契约，不等于用户结果页必须展示所有字段。
