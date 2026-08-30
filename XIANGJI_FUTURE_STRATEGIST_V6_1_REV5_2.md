# 向己·未来军师 V6.1 Final Rev.5.2 实现与验收索引

本次升级在现有 `agent/xiangji-v6-1-rev2` 最新产品分支上继续迭代；保留“未来军师”与“向己·智能目标导师”两个独立入口，不改主导航，不覆盖用户原始材料。

## Master PRD 体验级纠偏

`01_Xiangji_V6.1_Rev5.2_Master_PRD.pdf` 是唯一产品验收母版。不再把“数据表存在”、“方法事件已记录”或“单元测试通过”单独视为产品完成。本轮以用户在真实问题中是否能看见、操作并理解状态变化为门禁。

| 母版硬要求 | 纠偏后的产品行为 | 验收 |
|---|---|---|
| 首页是“今日指挥部” | 默认首屏改为北极星、主战役、五色战况、关键差距、军师判断、今日战斗、换路条件与下次验算；对话是第二入口 | DOC-01 §28.1 / DOC-08 §1 |
| 军师解题台首屏可见 | 对话结果与问题工作页共用同一解题台，默认显示真问题、现状、目标、唯一关键差距、当前原因、小步、唯一行动、机制和事前预测 | G3 / DOC-08 §2 |
| 不在默认页泄露内部术语 | 默认解题链全部使用用户语言；原始对象、完整分层和债务收进“高级：完整解题纸” | DOC-08 §§3/12/14 |
| 出征模式只保留行动所需信息 | 明确当前战斗、目的、唯一行动、时间边界、停止条件和回来后需报告的 1–3 项现实 | DOC-01 §22 / DOC-08 §10 |
| 不允许模板化“先侦察” | 本地保底也会按求职、关系、市场/创业与一般问题分别计算差距、行动机制和预测；同为求职也区分“获得面试”与“面试转化” | G8 / T-SCK-02 |
| 认识世界是变化档案，不是数据浏览器 | 每条用户可见方法变化显示对问题/办法的实际影响和现实验证，可直达对应军师解题台 | DOC-08 §8 |

## Rev.5.2 差异落地

- 新增持久化 `XiangjiSolverSnapshot`，显式保存 ProblemFrame、CurrentState、Goal、GapVector、KeyGap、AND/OR SubGoal、Operator、Prediction/Reality 与 BacktrackHistory。
- 新增 `XiangjiMethodEvent` 与数据库 Method Effect Gate。每项事件必须包含 Trigger、可审计操作摘要、数据变更、决策影响、用户摘要与现实检验；说明文字不能替代状态效果。
- 新增 contextual `XiangjiSignatureCapabilityRouter`。MEC-001..014 作用于同一条持续求解链；每轮最多显示 3 项，Action Mode 全部隐藏。
- “问题解题纸”升级为“军师解题台”，主屏使用自然产品语言直接呈现现状、目标、关键差距、当前小步、唯一行动、机制和事前预测，内部术语只留在高级诊断。
- 关键状态改变后显示轻量“军师改判”；现实反驳会更新 Hypothesis/Gap、失效旧 Operator，并按 Execution→Operator→Precondition→SubGoal→KeyGap→Goal→ProblemFrame→Concept→Judgment→Fact 回溯。
- Agent 编排由旧角色集恢复为 A00–A19；提示词版本升级为 `xiangji-v6.1-rev5.2-p0-p9`，22 份基线提示词与能力注册表随应用打包。
- Operator 合约补齐 preconditions、expected_effect、cost、risk、reversibility、information_value；缺失前提自动递归成为 PreconditionSubGoal。

## 概念与知识库一致性修正（#155）

本次重新核对发现，旧实现存在三个与产品方案不一致的问题：MEC-001..014 只存在于引擎代码和静态 JSON 中，没有进入运行时知识节点；“我的知识库”不展示内置方法与保护规则；MEC-011..014 等产品求解机制又被页面统一归因为叔本华概念。

修正后的合约如下：

- `xiangji_method_catalog.dart` 作为运行时规范目录，为 14 项方法分别保留产品名称、原概念 / 求解概念、触发条件、状态效果、现实验算与来源定位。
- 数据库增量写入 14 个受保护知识节点，路由、事件、页面与导出共用同一组 MEC 编号与名称。
- “我的知识库”新增“内置体系”，完整呈现 14 项方法、18 条 SCK、18 条 CEL、10 条 PS 及 K0 边界；内置定位性要旨明确标注为“非逐字引文”。
- 主对话仍按产品方案每轮只显示实际触发的 0–3 项；完整目录在知识库查看，不把“全面”误做成单轮信息过载。
- K0–K4 页面标签与数据模型统一：K0 认识论内核、K1 问题求解、K2 战略决策、K3 思想与行动方法、K4 个人经验科学。

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
6. 对话结果和完整工作页的解题台使用同一可复用 UI 契约，并在 200% 字号下无溢出。
7. 出征行动持久化 `action_purpose`、`stop_condition` 和 1–3 项 `reporting_facts`，任务打勾不能绕过现实验算。
