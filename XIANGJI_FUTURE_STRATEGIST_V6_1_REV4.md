# 向己·未来军师 V6.1 Rev4 实现与追踪索引

本轮按 Rev4 开发包的实施顺序完成代码改造，基线为 GitHub PR #148 的最新提交。对照材料包括：

1. `00_Developer_Start_Here`
2. `01_Xiangji_V6.1_Rev4_Product_PRD`
3. `02_Xiangji_V6.1_Rev4_State_Machine`
4. `03_Xiangji_V6.1_Rev4_Data_Knowledge_Model`
5. `04_Xiangji_V6.1_Rev4_AI_SCK_Solver_Agent`
6. `05_Xiangji_V6.1_Rev4_UI_UX_Cognitive_Experience`
7. `06_Xiangji_V6.1_Rev4_Acceptance_Tests`
8. `07_Current_Implementation_Gap_Report`
9. `08_Schopenhauer_Book1_Product_Reference`

## 1. 持久问题求解

- `xiangji_rev4_models.dart` 定义输入分类、Rev4 持久生命周期、假设状态、概念—现实冲突状态、认知体验类型与问题进度视图。
- `xiangji_persistent_solver.dart` 在创建/更新问题前分类 Need、Fact、Experience、Correction、ActionFeedback 与 NewProblem；显式新议题才创建新身份，普通反馈继续原 `problem_id`。
- `xiangji_repository.dart` 处理稳定问题身份、已解决问题重开、真正独立子问题、阶段性解决判据、行动反馈与问题连续求解。
- 对话中的明确行动反馈会自动关联同一问题当前行动，生成 `RealityResult`、更新 `SolutionAttempt/HypothesisTest` 并继续求解，不要求用户另找复盘表单。
- `xiangji_problem_pages.dart` 提供持久进度：已经解决/澄清、当前焦点、关键未知、当前实验与下一次验算；不使用虚构百分比。

持久生命周期同时保留旧版兼容状态，并在不可覆盖的 `ProblemStateVersion` 中追加：

`CAPTURED -> MODELING -> JUDGING -> FRAMING -> SOLVING/TESTING/SCOUTING -> ACTION_READY -> EXECUTING -> REALITY_RETURN -> VERIFYING -> CONTINUE/BACKTRACK/REFRAME -> RESOLVED/ARCHIVED`

## 2. Rev4 数据与迁移

`xiangji_database.dart` 增量迁移旧安装并新增：

- `xf_input_classification`
- `xf_problem_state_version`
- `xf_solution_attempt`
- `xf_hypothesis` / `xf_hypothesis_test`
- `xf_case_comparison` / `xf_relevant_difference`
- `xf_concept_reality_conflict`
- `xf_cognitive_experience` / `xf_method_experience`
- `xf_learning_moment` / `xf_backtrack_event`
- `xf_explanation_card`
- `xf_problem_alias`

`xf_problem` 增加稳定身份、父子关系、当前状态版本和生命周期状态；概念版本增加适用边界与未解释细节；战略选项增加案例目标差距、作用机制、关键假设、首选理由、路线取舍、切换触发、用户摘要和唯一首选标记。

行动开始、受阻、恢复、完成、现实回填、验算与 Todo 完成都会同步追加生命周期版本并更新 `SolutionAttempt`，但“行动完成”不会自动冒充“问题解决”。

## 3. AI、SCK 与求解编排

- `xiangji_agent_service.dart` 升级 Rev4 宪法、输出合同和本地降级；加入 A13 ProblemStateManager、A14 CognitiveExperienceGenerator、A15 MethodLearningAdapter。
- `xiangji_sck_runtime.dart` 生成与当前案例绑定的竞争原因、相关同异、差异化路线、机制、停止/切换信号与低成本侦察。
- `xiangji_cognitive_orchestrator.dart` 保存输入分类、问题状态版本、竞争假设与区分试验、案例比较、认知体验、方法体验、解释卡和方案尝试。
- 现实结果会关闭对应假设试验，更新假设强度、方案结果和最早回溯层；旧预测、旧解释和旧问题版本不会被事后覆盖。
- “我不知道”不会触发重复追问；系统改用安全假设、保守默认或低成本现实侦察。

## 4. Cognitive Experience Layer

CEL-001..018 已写入受保护规则并落实到前台体验：

| 需求 | 用户体验 | 主要实现 |
| --- | --- | --- |
| CEL-001..003 | SCK 运行会产生自然语言体验；事实、体验、解释、AI 判断分层；AI 模型明确可修订 | `xiangji_persistent_solver.dart`、认识世界页 |
| CEL-004 | 展示多个机制不同的候选原因及区分实验 | 认知体验卡、假设/试验表 |
| CEL-005 | “这次真的一样吗？”展示目标相关同异及对下一步影响 | 案例比较与相关差异 |
| CEL-006 | “为什么军师这么判断？”下钻事实、反例、最弱前提、未知与改变信号 | `xf_explanation_card`、第二层抽屉 |
| CEL-007..008 | 概念连回实例、反例、边界和未解释细节；说不清的体验按原话保留，不强迫贴标签 | 概念版本、认知体验生成器 |
| CEL-009 | “现实正在挑战旧解释”，保留旧版本并启动回溯 | 冲突、学习与 AI 失误记录 |
| CEL-010..012 | 体系完整度与现实根据分离；逻辑不替现实证明前提；行动说明 Gap、机制与预测 | 认识根据、前提审查、行动机制卡 |
| CEL-013..015 | 方法只在“为什么”中按需出现；重要修订形成 LearningMoment；训练模式提供一步练习并接收反馈 | 方法体验、学习记录、练习反馈入口 |
| CEL-016..017 | 普通界面不显示内部对象名、Agent 编号或原始 JSON；第一层先回答“现在怎么办”，第二层再解释 | 对话、问题、战役、行动、认识世界、知识页 |
| CEL-018 | 后台与体验实现均已进入代码；验收状态必须等待后续测试执行 | 本索引与待执行验收清单 |

## 5. PS-016..025 追踪

| 需求 | 实现 |
| --- | --- |
| PS-016/017 | 每条输入先分类；相关输入复用稳定问题身份并追加版本 |
| PS-018 | 竞争 `Hypothesis` 与可区分的 `HypothesisTest` 持久化，现实回填后更新状态 |
| PS-019 | 历史迁移前保存 `CaseComparison` 与决定性 `RelevantDifference` |
| PS-020 | 问题页显示已解决项、当前焦点、未知、实验和下一次验证 |
| PS-021 | 预测被反驳时保存 `BacktrackEvent`、AI 失误、冲突与可理解说明 |
| PS-022 | 独立分支通过 `parent_problem_id/root_goal_id` 建立；普通反馈不生成平行问题 |
| PS-023 | 每个方案形成 `SolutionAttempt`，保留依据、预测、执行、结果与失效层 |
| PS-024 | 只有现实支持且满足成功判据才阶段性解决；新事实可在同一身份下重开 |
| PS-025 | 现实反馈更新事实版本、假设试验、关键差距、方案结果和下一算子优先级 |

## 6. 战略、界面与后台监督

- 每条战略均包含当前案例的目标差距、作用机制、关键假设、首选原因、其他路线取舍、切换触发与停止条件；当前版本只能有一个军师首选。首选会随决定性证据、资源准备度、承诺/退出边界与机会窗口改变：未知解决且资源边界就绪时从侦察切换为限额推进，不机械重复固定模板。
- 对话与问题页第一层直接给推荐和唯一当前一步；采用、修改、不认同、为什么、暂缓和“我不知道”均保留。
- “我的认识世界”按认识变化、经验与解释、概念边界、现实冲突组织，不再按内部表结构组织。
- AI 分析失败卡持续保留，原始输入不丢失，并提供重试和 AI 服务设置入口；错误详情不会向普通界面泄漏内部对象。
- 主动监督开关会真实注册或取消 Workmanager 周期任务。后台只在新的红/橙/蓝高价值变化时通知，并直接打开相关问题。

## 7. 本轮刻意未执行的工作

按本轮要求，尚未运行任何 Flutter/Dart 测试、Widget 测试、数据库迁移测试、构建、分析器、设备验证或 Rev4 验收脚本。`06_Xiangji_V6.1_Rev4_Acceptance_Tests` 中的验收项保持“待执行”，不能在测试完成前标记为已验收。
