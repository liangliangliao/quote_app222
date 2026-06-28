# V14 最终方案一致性补全

本次改造基于用户最新上传的 `quote_app-main.zip`，不再依据之前口头版本说明。目标是逐一补齐源码审计中发现的最终方案缺口：训练会话状态化、主流程确定性沉淀、来源锚点管理、AI 输出质量校验、首页继续会话入口。

## 1. 训练会话状态化

新增模型：

- `RealisticOptimismTrainingSession`

新增数据库表：

- `realistic_optimism_training_sessions`

新增 DAO 方法：

- `upsertSession`
- `getSession`
- `listOpenSessions`
- `abandonSession`
- `completeSession`

`RotCoreBusinessFlowPage` 现在支持：

- 创建训练会话草稿
- 每一步保存当前进度
- 手动保存草稿
- 中途退出后从首页继续
- 安全分流会话保存为 `safety_routed`
- 完成后把会话标记为 `completed`

## 2. 主流程确定性沉淀

新增 DAO 方法：

- `upsertDeterministicArtifactsFromSession`

完成核心业务流后，除保存 AI 生成记录外，还会根据用户在会话里亲自填写的内容确定性写入：

- 强度分级：`realistic_optimism_training_event_intensity`
- 解释风格：`realistic_optimism_training_explanation_scores`
- Benefit Finder：`realistic_optimism_training_benefit_reframes`
- 过程行动：`realistic_optimism_training_process_plans`
- 未完成复盘：`realistic_optimism_training_failure_immunity`
- 感恩：`realistic_optimism_training_gratitude_entries`
- 品味：`realistic_optimism_training_savoring_entries`
- Prime：`realistic_optimism_training_primes`
- 身份证据：`realistic_optimism_training_identity_evidence`

这样核心业务流不再只保存一个 `event_reframe` AI record，而是真正成为所有子功能的数据统一入口。

## 3. 来源锚点结构化管理

新增模型：

- `RotValueSourceAnchor`

新增数据库表：

- `realistic_optimism_training_value_source_anchors`

新增 DAO 方法：

- `seedValueSourceAnchors`
- `listValueSourceAnchors`

已内置四类来源锚点：

- Seligman / Biondi：解释风格与事实解释分离
- Edison / Simonton / Babe Ruth：失败免疫
- Bargh / Dijksterhuis / Langer：Prime 与环境启动
- Gratitude / Savoring / VIA：感恩品味与身份沉淀

用于确保 UI 文案与 AI Prompt 均围绕此前总结归纳的价值体系，而不是无中生有。

## 4. AI 输出质量校验

新增：

- `RealisticOptimismTrainingOutputValidator`
- `RealisticOptimismTrainingValidationReport`

校验内容包括：

- `core_value_reference` 是否存在
- L1/L2/L3/L4 强度等级是否合法
- 情绪允许是否足够
- 是否包含事实层
- 是否包含自动解释
- Benefit Finder 是否具体
- 5 分钟行动是否具体
- If-Then 是否存在
- Prime 是否落地
- 身份句是否基于证据
- L3/L4 是否避免强行积极化

AI 输出轻微不完整时会写入 `validation_repair_note`，详情页展示该提示；严重不完整时回退到内置策略。

## 5. 首页继续未完成会话

首页新增：

- `_OpenSessionsCard`

展示：

- 当前未完成会话数量
- 最新未完成会话停在哪一步
- 强度等级
- 情绪
- 事件摘要
- 继续会话
- 放弃草稿

统计新增：

- `sessions`
- `openSessions`

## 6. 核心业务流记录确定性 payload

`RotCoreBusinessFlowPage` 完成时会生成一份确定性 payload，优先保留用户在会话中填写的事实、解释、行动、复盘、感恩、Prime 和身份句。AI 仍可辅助表达，但不再是唯一事实来源。

## 仍未执行的验证

当前环境没有 `dart` / `flutter` 命令，无法运行：

- `flutter analyze`
- `dart format`
- 真机/模拟器编译

已完成源码级括号、引用、关键字段和打包检查。
