# 向己·未来军师 V6.1 Final Rev.5.2 实现与验收索引

本次升级在现有 `agent/xiangji-v6-1-rev2` 最新产品分支上继续迭代；保留“未来军师”与“向己·智能目标导师”两个独立入口，不改主导航，不覆盖用户原始材料。

## Rev.5.2 差异落地

- 新增持久化 `XiangjiSolverSnapshot`，显式保存 ProblemFrame、CurrentState、Goal、GapVector、KeyGap、AND/OR SubGoal、Operator、Prediction/Reality 与 BacktrackHistory。
- 新增 `XiangjiMethodEvent` 与数据库 Method Effect Gate。每项事件必须包含 Trigger、可审计操作摘要、数据变更、决策影响、用户摘要与现实检验；说明文字不能替代状态效果。
- 新增 contextual `XiangjiSignatureCapabilityRouter`。MEC-001..014 作用于同一条持续求解链；每轮最多显示 3 项，Action Mode 全部隐藏。
- “问题解题纸”升级为“军师解题台”，主屏直接呈现 S0、Goal、KeyGap、SubGoal、Operator 和事前预测，并提供三步内可展开的“为什么这一步”。
- 关键状态改变后显示轻量“军师改判”；现实反驳会更新 Hypothesis/Gap、失效旧 Operator，并按 Execution→Operator→Precondition→SubGoal→KeyGap→Goal→ProblemFrame→Concept→Judgment→Fact 回溯。
- Agent 编排由旧角色集恢复为 A00–A19；提示词版本升级为 `xiangji-v6.1-rev5.2-p0-p9`，22 份基线提示词与能力注册表随应用打包。
- Operator 合约补齐 preconditions、expected_effect、cost、risk、reversibility、information_value；缺失前提自动递归成为 PreconditionSubGoal。

## MEC-001..014 代码追踪

| 能力 | 运行时状态效果 | 验收测试 |
|---|---|---|
| MEC-001 经验/解释 | 分层并禁止无根据解释越权 | T-MEC-01 |
| MEC-002 感觉/外因 | 保留体验，外因降为 Hypothesis | T-MEC-02 |
| MEC-003 竞争因果 | 2–5 个不同机制及区分观察 | T-MEC-03 |
| MEC-004 判断力比较 | DecisiveDifference 重选 Gap/失效旧 Operator | T-MEC-04 |
| MEC-005 未概念化体验 | 跨场景保留，不强制贴标签 | T-MEC-05 |
| MEC-006 概念保真 | 保存遗漏/反例/压缩损失并收缩 Scope | T-MEC-06 |
| MEC-007 Ground Explorer | GroundChain/最弱前提改变行动承诺 | T-MEC-07 |
| MEC-008 系统性/确定性 | Systematicity 与 EpistemicStatus 分离 | T-MEC-08 |
| MEC-009 概念/现实冲突 | Mismatch、KeyGap 更新、旧 Operator 失效 | T-MEC-09 |
| MEC-010 Goal Audit | GoalVersion 与用户确认门 | T-MEC-10 |
| MEC-011 Gap Radar | 七维 Gap 排序并选择 KeyGap | T-MEC-11 |
| MEC-012 SubGoal/Operator/Precondition | AND/OR 与递归前提子目标 | T-MEC-12 |
| MEC-013 Prediction/Reality | 预测锁定、现实对账、H/Gap 更新 | T-MEC-13 |
| MEC-014 Backtrack | 定位最早失败层并换路 | T-MEC-14 |

核心实现：

- `lib/xiangji_future_strategist/xiangji_signature_method_engine.dart`
- `lib/xiangji_future_strategist/xiangji_models.dart`
- `lib/xiangji_future_strategist/xiangji_database.dart`
- `lib/xiangji_future_strategist/xiangji_repository.dart`
- `lib/xiangji_future_strategist/xiangji_problem_pages.dart`
- `lib/xiangji_future_strategist/xiangji_agent_service.dart`
- `test/xiangji_future_strategist/xiangji_signature_method_engine_test.dart`

## Release Gate

1. 14 项 T-MEC 测试全部闭环；每项事件有真实状态变更或明确保留理由。
2. SQLite 原子保存 SolverSnapshot + MethodEvent，导出/模块内重置覆盖新表。
3. 正常界面单轮 0–3 项方法；Action Mode 0 项。
4. A00–A19 代码注册连续，Prompt/ModelRun 记录 Rev.5.2 版本。
5. 既有未来军师、智能目标导师、知行树回归测试与 Android release 构建继续通过。
