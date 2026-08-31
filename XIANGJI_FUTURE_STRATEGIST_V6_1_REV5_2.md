# 向己·未来军师 V6.1 Final Rev.5.2 实现与验收索引

本次升级在现有 `agent/xiangji-v6-1-rev2` 最新产品分支上继续迭代；保留“未来军师”与“向己·智能目标导师”两个独立入口，不改主导航，不覆盖用户原始材料。

## V6.2 现实产出体验层（#155 后续纠偏）

Rev.5.2 已把叔本华 24 项 L0、14 项 MEC、持久求解和现实闭环放入运行时，但默认体验仍把内部驾驶舱和工作区直接交给用户。本轮在不删除任何原概念、知识节点、求解状态或高级页面的前提下，新增 V6.2 现实产出层：

- 默认首页只问“你现在想解决什么”，并显示当前唯一行动或待回填现实；
- 用户固定循环“说出需要 → 选择办法 → 只做一步 → 回报现实并改判”；
- 同一正确方向提供轻松起步、稳步推进和现实挑战三种负担，依据用户自愿选择的兴趣、价值、优势、能量、语气和时间调整；
- 对话结果默认显示真问题、一句判断、三种选择和现实动作，完整态势、假设与方法事件按需展开；
- 新增离线可靠、AI 可选增强的使用助手，可回答是什么、何时用、填什么、怎样做、产出什么和依据什么，并跳到正确入口；
- 新增 3 个不污染个人数据的完整持久案例，保留原话、事实/解释、竞争原因、目标、差距、路线、预测、现实、改判和下一步；
- 所有可见功能建立 `L0_GROUNDS_FEATURE` 知识边；24 项叔本华核心必须全部至少约束一个可操作功能；
- 行动轮数只统计有 RealityResult 的现实闭环，不用阅读、浏览或打卡冒充成长；
- 动机设计以自主、低门槛、兴趣匹配、可见结果和失败可恢复为边界，禁止羞耻、威胁、创伤利用、敌人刺激或制造依赖。

完整产品方案、流程图、逐条需求映射、案例和专项测试边界见：

- `docs/xiangji_future_strategist_v6_2_practical_redesign.md`

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

本次同时对照 Rev.5.2 母版与用户提供的旧版《向己·未来导师 V5.0》产品方案。旧方案冻结的不是一组可选哲学卡，而是以下 L0 主链：

`经验世界 I → 认识根据 G → 抽象反思世界 C → 问题求解 → 计划行动 → 新经验世界 I′ → 修订旧认识`

重新核对发现四个偏差：MEC-001..014 只存在于引擎代码和静态 JSON 中，没有进入运行时知识节点；“我的知识库”不展示内置方法与保护规则；MEC-011..014 等产品求解机制又曾被页面统一归因为叔本华概念；更关键的是，叔本华只剩 4 段隐藏要旨，没有作为所有功能的 L0 认识论操作系统在页面和知识图中居首。

修正后的合约如下：

- `xiangji_schopenhauer_core_catalog.dart` 冻结 24 项 L0 核心概念，逐项保存原概念、产品含义、硬约束、功能绑定、规则映射与来源定位。
- 原典核心与“认识债务、概念循环、根据率、竞争原因”等 V5 产品操作化明确分标；产品术语不会冒充叔本华原话或原生术语。
- `xiangji_method_catalog.dart` 作为运行能力目录，为 14 项方法分别保留产品名称、原概念 / 求解概念、触发条件、状态效果、现实验算、来源定位及其必须遵守的 L0 核心概念。
- 数据库增量写入 24 个 L0 概念节点、14 个方法节点、L0→方法约束边与冻结主链边；路由、事件、页面与导出共用同一组稳定编号。
- “我的知识库”将叔本华 L0 核心置于 14 项运行能力之前，随后完整呈现 18 条 SCK、18 条 CEL、10 条 PS 及 K0 边界；内置定位性要旨明确标注为“非逐字引文”。
- “我的认识世界”改为“经验世界 I / 概念世界 C / 现实验算”分层；解释、判断与认识债务不再混入经验世界。
- 主对话仍按产品方案每轮只显示实际触发的 0–3 项；完整目录在知识库查看，不把“全面”误做成单轮信息过载。
- 产品 L0–L3 与存储 K0–K4 建立显式映射：L0=K0 认识论内核；L1=K1/K2 形式化求解与战略；L2=K3 多思想家行动方法；L3=K4 个人经验科学。

### 叔本华 L0 核心知识覆盖

| 概念组 | 核心内容 | 已绑定功能 |
|---|---|---|
| 世界与认识起点（4） | 经验世界 I、抽象世界 C、表象的表象、直观与概念根本不同 | 原始经验、Claim/Concept 分层、未概念化直觉 |
| 根据与认识债务（5） | 认识根据、泉水—水渠、概念循环、认识债务、根据率 | 根据图、循环检测、信息子目标、承诺限制 |
| 概念、判断与直觉（4） | 镶嵌画、判断力、反例边界、面相例的方法意义 | 概念版本、案例比较、反例区、直觉箱 |
| 感受、知性与因果（3） | 感觉阶梯、知性与因果、竞争原因 | 体验/外因分层、2–N 假设、区分实验 |
| 理性、语言与确定性（5） | 隐藏概念链、系统性/确定性、弱前提、抽象目标、归纳规则 | 语言诊断、证明审查、目标判据、Always 检测 |
| 行动、科学与现实修订（3） | 熟练行动、个人经验科学、新现实纠错 | 反思/行动模式、个人规则、预测—现实与回溯 |

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
5. 本轮只运行 `test/xiangji_future_strategist`；不执行智能目标导师、知行树或其他无关模块专项测试。
6. 对话结果和完整工作页的解题台使用同一可复用 UI 契约，并在 200% 字号下无溢出。
7. 出征行动持久化 `action_purpose`、`stop_condition` 和 1–3 项 `reporting_facts`，任务打勾不能绕过现实验算。
