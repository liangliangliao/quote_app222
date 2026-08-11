# 向己·未来军师 V6.1 Final Rev3 实现与验收索引

本轮严格对应以下六份 Rev3 开发文档，并保留 Rev2 的认识、求解、战略、行动、知识与治理能力：

1. `01_Xiangji_V6.1_Rev3_PRD`
2. `02_Xiangji_V6.1_Rev3_State_Machine`
3. `03_Xiangji_V6.1_Rev3_Data_Knowledge_Model`
4. `04_Xiangji_V6.1_Rev3_AI_Agent_Knowledge_Router`
5. `05_Xiangji_V6.1_Rev3_UI_UX_AI_First`
6. `06_Xiangji_V6.1_Rev3_Acceptance_Tests`

## Rev3 主链

默认入口是“与军师对话”。用户用文字、语音或附件提供 Need、现实、体验或反馈；系统执行：

`Observe -> Model -> Judge -> Frame -> Solve -> Strategize -> RedTeam -> Plan -> Verify -> Learn`

- `xiangji_sck_runtime.dart`：SCK-001..018 可执行内核、AskUserGuard、Agent 顺序、离线完整草案和现实验算。
- `xiangji_cognitive_orchestrator.dart`：自动执行 A01/A04/A02/A03/A05/A06；重大决策追加 A07/A08/A00；A09 压缩为唯一当前行动。
- `xiangji_agent_service.dart`：Rev3 Prompt/输出合同/本地降级。离线时仍完成求解，不再把结构化作业退回用户。
- `xiangji_strategist_conversation.dart`：默认对话、单一澄清、军师回复卡、采用/修改/不认同/为什么/暂缓、语音与附件。PDF/DOCX/PPTX/XLSX/文本附件会提取原文并保留本地来源引用。

## 状态与数据

- `SituationModel`：`RAW -> PARSED -> JUDGED -> GROUNDED -> FRAMED`，必要时 `NEEDS_CLARIFICATION`，现实/纠正可令旧版本 `STALE`。
- AskUserGuard 仅允许 `CONTINUE_AUTONOMOUS / ASK_ONE / SCOUT_IN_REALITY / USER_DECISION`；不存在 `ASK_FORM`。
- 新增本地表：`xf_situation_model`、`xf_ai_inference`、`xf_information_need`、`xf_clarification_question`、`xf_user_correction`、`xf_agent_run`、`xf_reasoning_artifact`、`xf_judgment`、`xf_decision_draft`。
- 用户纠正会保留旧版本，并把下游 AIInference、ReasoningArtifact、DecisionDraft 标为 `STALE`；AI Claim 降为 `UNRESOLVED`，Concept 进入 `UNDER_REVIEW`。
- K0 会迁移/补种 SCK-001..018，旧安装不需要删库。
- 连续两轮现实证伪会由 A11 生成低打扰战况，再由 A00 形成可追溯的后台军议；未变化的警报不重复发起军议。

## AI-First 页面改造

- 未来军师打开后默认显示“与军师对话”，今日指挥部作为第二入口。
- 人生问题解题纸显示 AI 预填的事实/体验/解释、未知、因果、真问题、Gap、AND/OR、候选算子和决策草案；原表单仅在“高级手动校正”中可选使用。
- 战役作战室由军师自动生成值得一战、资源边界、至少两条战略、红队与兵棋；用户在 DECISION Gate 采用、修改、反对或暂缓。
- 行动模式只显示唯一行动、预计耗时、why-chain 和 3—5 个需要报告的事实；现实反馈使用一段自然语言自动验算并触发 SCK-018。
- “为什么？”直接展示认识根据、反方、ReasoningArtifact、Agent 顺序和 SCK 规则，能回到来源/原始态势版本。

## 永久业务守卫

- A02 必须先于高影响 Solver/Strategist。
- 重大战略自动执行 A08 红队，且至少两个真正不同的选项。
- AIRecommendation/DecisionDraft 不等于 UserDecision；Campaign 未确认不能进入执行。
- 每个关键 Operator 必须有 Gap、机制、战略意义、认识根据与事前 Prediction。
- RealityResult 与 Prediction 冲突时保留旧预测、标派生模型过期、回溯最早错误层并重算。
- 敏感对象未授权不外发；本地 SCK 草案始终可用。

## 测试入口

`test/xiangji_future_strategist/xiangji_rev3_sck_test.dart` 覆盖 AskUserGuard、判断力前置、重大决策自动红队、AI 预填、算子机制、现实冲突与状态机。

`test/xiangji_future_strategist/xiangji_rev3_database_test.dart` 覆盖 Rev3 新实体、版本、用户纠正失效链、SCK-018 AIError、A11→A00 审计链和 Rev2 旧库增量迁移。

`test/xiangji_future_strategist/xiangji_rev3_widget_test.dart` 覆盖 200% 字号下的对话首页、精确默认提示语、语音/附件入口和布局异常门禁。

Android CI 会运行 `test/xiangji_future_strategist` 的全部 Rev2 + Rev3 回归门禁。
