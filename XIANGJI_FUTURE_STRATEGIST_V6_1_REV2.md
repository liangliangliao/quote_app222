# 向己·未来军师 V6.1 Rev2 实现与验收索引

> 当前增量基线已升级为 `XIANGJI_FUTURE_STRATEGIST_V6_1_REV5_2.md`；本文件保留用于追踪 Rev2 历史实现，不代表最新产品要求。

本模块严格按以下六份开发文档实现，并从“发现之旅”进入：

1. `01_Xiangji_V6.1_Rev2_PRD`
2. `02_Xiangji_V6.1_Rev2_State_Machine`
3. `03_Xiangji_V6.1_Rev2_Data_Knowledge_Model`
4. `04_Xiangji_V6.1_Rev2_AI_Agent_Knowledge_Router`
5. `05_Xiangji_V6.1_Rev2_UI_UX_Knowledge_Center`
6. `06_Xiangji_V6.1_Rev2_Acceptance_Tests`

## 入口与代码结构

- 发现之旅入口：`lib/pages/discover_page.dart`
- 主页/今日指挥部：`lib/xiangji_future_strategist/xiangji_home_page.dart`
- 问题解题纸：`xiangji_problem_pages.dart`
- 战役作战室/行动模式：`xiangji_campaign_action_pages.dart`
- 我的认识世界/战史/设置/数据治理：`xiangji_insight_pages.dart`
- 我的知识库/Provider/检索来源：`xiangji_knowledge_pages.dart`
- 领域模型：`xiangji_models.dart`
- P0 状态机与 K0 离线规则：`xiangji_state_machine.dart`
- SQLite 数据/知识/审计层：`xiangji_database.dart`
- A12 纯路由内核：`xiangji_knowledge_route_core.dart`
- 知识导入与 Provider 生命周期适配：`xiangji_knowledge_router.dart`
- A00—A12 Agent 编排：`xiangji_agent_service.dart`
- 问题—行动—Todo—现实验算编排：`xiangji_repository.dart`

## P0 硬约束落点

| 约束 | 代码守卫 | 验收测试 |
|---|---|---|
| 用户原题/原始经验不可被 AI 覆盖 | `createProblem` 分开保存 RawEvent、Experience、Claim | `TC-PS-001` |
| CAPTURED 不可跳到 EXECUTING | `XiangjiProblemStateMachine` 合法边 | `xiangji_state_machine_test.dart` |
| 事实、体验、解释、预测、未知项分层 | `completeFormalization` + `xf_problem_item` | `TC-PS-*` 工作流 |
| 高影响无根据 Claim 不得 GROUNDED | `XiangjiClaimStateMachine` | `TC-EP-016` |
| 系统复杂度与确定性分离 | `XiangjiEpistemicProfile.systematicity` | `TC-EP-014/015` |
| 概念循环不等于现实根据 | `XiangjiGroundingGraph` | `TC-LG` cycle test |
| Embedding 只能召回，不能成为 Evidence | K0-RULE-025 + DAO 拒绝写入 | `TC-KB-025` 两层测试 |
| 战役执行前完成值得一战、情报、胜利/止损、兵力、红队、用户决断 | `XiangjiCampaignStateMachine` | `TC-ST` gate test |
| AI 负责谋、用户负责断 | DECISION→PREPARE 的 userConfirmed guard | `TC-ST` |
| Action DONE 不自动解决 Problem/Campaign | Todo 只改 Action；RealityResult 单独保存 | `TC-LG-005` |
| 没有 RealityResult 不得 VERIFY/RESOLVED | Problem 状态守卫 + `verifyAction` | `TC-PS-010` |
| RED 预警改变系统行为 | `startAction`/`resumeAction`/战役 EXECUTING 冻结 | `TC-AC-006` |
| 单次 AI 推断不得成为稳定个人规则 | `XiangjiKnowledgeItemStateMachine` | `TC-KB-018` |
| 未验证 Provider 不得宣称永久知识库 | Provider capability negotiation + READY guard | `TC-KB-010` |
| 远程删除必须确认后才标记 DELETED | Provider file state machine | `TC-KB-015` |

## 知识路由优先级

`XiangjiKnowledgeRouter` 固定记录并执行以下顺序：

1. 当前现实/用户材料
2. K0 离线硬规则预检
3. 当前 Problem/Campaign/Claim 图
4. K4 个人历史、候选知识与个人兵法
5. K1/K2 认识论与问题求解方法
6. K3 思想家/战略方法（相关时）
7. 原著段落与精确 locator（用户要求时）
8. Provider 大文件知识（能力满足、状态 READY、未过期时）

每次路由写入 `xf_retrieval_trace`；UI 的“此次知识来源”展示采用来源、拒绝来源、冲突、K0 规则与认识债务。K0 在代码与受保护结构化规则中执行，不依赖 RAG 或网络。

## Provider 生命周期

每个本地 Source 可以有多个 ProviderFile 映射，分别记录 remote file/store ID、留存策略、错误、过期时间与状态：

`NOT_UPLOADED → UPLOADING → PROCESSING/READY/FAILED → DELETING → DELETED`

模块复用知行树已有 OpenAI/Azure/xAI/Gemini/Claude/OpenRouter/EdenAI/兼容 Provider 适配器，但本地来源身份、能力协商、状态记录和删除确认由向己模块独立负责。

## 隐私与数据治理

- 默认不允许把敏感 Problem/Campaign 上下文发送给云端 AI；未授权时 Agent 强制使用本地结构化 fallback。
- API Key 由全局 AI 设置持有，不写入 `xf_` 表，也不进入模块导出。
- 数据导出只读取 `xf_` 前缀表。
- 模块删除前自动导出 JSON，只清理 `xf_` 表，之后恢复受保护 K0 与 Provider 能力登记；Todo、日记和其他模块不受影响。

## 自动化验收

- `test/xiangji_future_strategist/xiangji_state_machine_test.dart`
- `test/xiangji_future_strategist/xiangji_database_test.dart`
- `test/xiangji_future_strategist/xiangji_knowledge_router_test.dart`
- `.github/workflows/android_build_source_repo.yml` 会运行以上测试并执行 Flutter Android release build。

本地环境若没有 Flutter/Dart，可先运行语法树解析与 `git diff --check`；最终语义编译、测试和 Android 构建由 GitHub Actions 使用 Flutter 3.35.3 执行。
