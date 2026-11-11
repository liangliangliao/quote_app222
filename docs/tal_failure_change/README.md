# Tal Ben-Shahar｜失败—复盘—改变：App 集成设计规范 V1.1

版本：2026-11-06 · 修订 V1.1（核实原著 PRP）｜性质：**可直接交付开发的设计规范与结构化知识包，尚非已实现、已编译、已验证的 App 插件**。

> 核心宗旨：不要把“失败”美化；不要把“理解”冒充“改变”；不要把“行动一次”冒充“形成稳定习惯”。

## 0. 理论来源与归属边界

### A. 可核实的塔尔原著练习
- **PRP（Permission—Reconstruction—Perspective）**：《The Pursuit of Perfect》第九章 *Cognitive Therapy*，小节 *The PRP Process*、英文版约176—179页：允许情绪与事实→认知重构→拉远视野；**原著强调步骤可往返、非线性**。
- **Explore Your Failures**：《The Pursuit of Perfect》（原著摘录，2009）——花 10–15 分钟记录一次失败：自己做了什么、当时的想法、当时与现在的感受、教训、可能的其他收获。
- **Learn to Fail**：同上——选择因害怕失败而回避的事情，实际尝试、寻求反馈/帮助、承认错误，并接受成功或失败。
- **Enjoy the Journey / Use Time Efficiently**：同上；过程价值与时间投入的优化。
- **Creating Rituals**：《Happier》原著摘录——具体行为×具体时间×珍视的价值；一次新增一至两项日常惯例。
- **Unbundling Exercise**：《Being Happy / The Pursuit of Perfect》原著摘录——把希望保留的积极价值与希望减少的负面行为分开。
- **Five-Minute Takeoff**：《Choose the Life You Want》原著摘录——针对部分拖延场景，先开展五分钟工作；不保证适用于所有执行困难。
- **MVI 与 3Rs**：《Happy Habits》（2025）——微型可行干预；Reminders / Repetitions / Rituals。

### B. 塔尔在哈佛《Positive Psychology》公开课所教授的理论
- **Permission to Be Human**：接纳情绪，不等于肯定所有想法与行为。第4讲。
- **3Ms 与 Zoom Out**：检查放大、缩小/忽略、无证据推断。第7讲。
- **Benefit Finding**：不否认损失，尝试探索真实的收益与教训。第7–8讲。
- **ABCs of Change**：Affect / Behavior / Cognition，分别可渐进/集中改变；三者相关。第10–12讲。
- **Gradual Change / Stretch Zone**：适量挑战与逐渐提高。第11–12讲。

### C. 本规范额外设计、绝不冒充塔尔原创
- 失败事件状态机、症状路由、置信标记、问答分支、If–Then 计划字段、行动验证指标、长期教训账本、PRP/AAR 融合、行动预测、回访算法、隐私安全门槛、与现有 App 的 DAO/事件接口；这些属于**产品设计或其他框架方法**。
- **已核实 PRP 是塔尔原著明确命名的方法**：出处为《The Pursuit of Perfect》第九章 *Cognitive Therapy* 中的 *The PRP Process* 和配套练习；另有2009年媒体采访与法文译本目录交叉印证。
- 既有 App 的「PRP 会话」可能增加了「对账/双栏/预警/盖印/回访/如果—那么」等环节；**这些增补是 App 的整合设计，不是原著 PRP 的三个核心步骤**。原著 PRP 是 Permission→Reconstruction→Perspective，而且允许非线性往返。

## 1. 目标与验收定义

### 目标
从真实失败到下一次现实行为的差异，形成可验证证据。

### 成功的层级
- L0 **记录**：只有事件，未产生可检验教训。
- L1 **理解**：描述了事实与想法，提出尚未确认的假设。
- L2 **计划**：确定具体下一次行动，明确时间/触发/检查方式。
- L3 **执行**：现实中实施了新行为，记录了证据。
- L4 **有效**：新行为在相关情境下改善目标指标；不将单次效果认定为确定因果。
- L5 **巩固**：跨多次场景保持改善；允许偶尔失败和修正。

禁止用连续打卡天数代替真实行动结果；禁止把“看完一段名言”计为一次成功改变。

## 2. 最轻量的用户流程（默认）

**一键入口：**「今天一件没有按计划发生的事」。用户也可自主记录成功经验。

### 轻量路径（约1–3分钟，所有字段可跳过）
1. **事实**：原计划 ___；实际 ___。默认不自动判定“失败”。
2. **经历**：当时做了什么 / 在想什么 / 什么感受？自由文本或语音；不强制深挖。
3. **获得的认识**：自己目前知道什么？不知道什么？允许选「还不清楚」。
4. **下一次**：是要**继续**、**调整**，还是**重新评估/退出目标**？如继续，选一个具体变化。
5. **保存并等待验证**：下次相关行动出现时提醒“上一条教训”，后续只问“有没有做、结果如何”。

### 标准路径（有兴趣时 10–15 分钟）
依据塔尔 Explore Your Failures 的问题完整书写；也可选择原著 **PRP 三步练习**（情绪与事实允许→寻找可用教训→拉远视角）。PRP可前后往返，不得强制线性通关。只有发现相关证据才额外进入 3Ms、Benefit Finding、Unbundling。

### 深入路径（仅用户主动进入）
可选：失败类型对照、具体行为节点、反面证据、动机冲突、替代选择、情景模拟、长期规律；避免对用户连续强制心理审问。

**所有路径原则：** 不把接纳情绪强制设成门槛；可以从事实或行动直接开始。塔尔未规定统一步骤先后顺序。

## 3. 改变困难的路由规则（优先确定性，AI仅在需要时辅助）

| 用户描述/证据 | 推荐可试的方法 | 不应做什么 | 成功检查 |
|---|---|---|---|
| 羞耻、自责、强烈情绪 | Permission to Be Human | 不立刻灌输积极意义 | 是否能够更清楚陈述事实 |
| 反复把一次失败扩大成一生都失败 | 3Ms / Zoom Out | 不承诺“肯定能成功” | 判断是否补上被遗漏证据 |
| 只关注损失，主动愿意寻找教训 | Benefit Finding | 不美化伤害/强迫感恩 | 有无真实可迁移的经验 |
| 怕失败而回避可控挑战 | Learn to Fail / Stretch Zone | 不建议高风险豪赌 | 是否完成可承受尝试并反馈 |
| 认为改掉某缺点就会失去珍视的品质 | Unbundling | 不假设所有拖延皆有隐藏动机 | 明确保留/减少的不同部分 |
| 真想做、能开始、但临时缺动力 | Five-Minute Takeoff（可选） | 既往反复无效时不要继续首推 | 起始行为发生率 |
| 偶尔能做、难以持续 | Creating Rituals / 3Rs | 不把提醒数量当成果 | 在相关情境重复执行的稳定性 |
| 一开始挑战太难 | Gradual Change / Stretch Zone | 不用无限缩小动作替代关键目标 | 对目标有用的有效挑战是否逐步提高 |
| 疲劳/睡眠不足/过载 | 恢复与减负，必要时寻求评估 | 不简单解释成不自律 | 休息条件与执行能力是否改善 |
| 先前方法反复失败 | Research + Me-search（个人实测） | 不再固守失败方案 | 更改方法后新数据如何 |
| 目标本身不合适 | 目标重新评估，继续/调整/退出 | 不把理性拒绝当懦弱 | 选择与实际条件是否一致 |

路由结果必须显示「选择依据」「不确定性」「为什么是这个方法」「什么时候换方法」。

## 4. 真实案例如何驱动练习

每条故事卡固定六字段：
- 亲历事实（tal_first_person / his_book / journalist_report / uncertain）
- 当时遇到的问题（不得添加无法核实的心理内幕）
- 他**明确做了**什么（区别于后来总结的原则）
- 得到的结果（直接证据、自述变化、未知）
- 可对应的原著练习（只算诠释映射，不声称他当年有意采用该练习）
- 本地可做的体验实验（由产品设计，不冒充原著）

来源和案例数据详见 `method_case_catalog.json`。

**最值得优先展示的案例：**
0. 塔尔送女儿去托儿所导致写作计划落空：亲自应用PRP，发现过度忙碌，并选择陪女儿悠闲散步。
1. 获全国壁球冠军仍不幸福：原来追求的因果假设可能错误，后来转向研究幸福。
2. 哈佛研究生资格考试不及格：按条件重学基础知识，知识积累后来支持教学。
3. 电视采访后懊悔一句话：Zoom Out，检查整场表现、缩短反刍。
4. 完美主义多年改不了：Unbundling 后分离雄心与失败恐惧。
5. 个人写作启动困难：Five-Minute Takeoff（有时需多轮）。
6. 试着减少学习投入却差点不及格：Trial and Error，证明改进方案自己也要校准。

## 5. 现有 quote_app222 直接融合方案（基于 2026-11-04 已有规划，尚未现场核验最新代码）

**不要建立独立且重复的新业务模块。** 采用本地 Flutter/Dart 领域包 + 已有 SQLite 账本 + 既有页面卡片的形式：

- `lib/failure_module`：「我刚失败了」手动入口；`T_QUICK_3P` / `T_AAR` 保留为已有 App 训练模板；为PRP核心三步骤补充原著引用，额外的AAR、盖印和验证统一标注App扩展。
- `lib/beautiful_enemy`：承载行动前后的轻量对话和已有“字据”；可以沿用 PRP 名称；明确区分**塔尔原著三步骤**与已有App的额外「双栏/预警/盖印/回访」。
- `lib/behavior_tracking`：在用户明确确认 missed 后产生事件；不是看到 pending 或 no-data 就说用户失败。将教训在下一次同类行动前回访。
- 既有 `be_lesson` / `fp_learning_card`：共用教训账本；复用现有 DAO，不建立平行的新知识库。
- 「发现之旅」：显示“现实问题→可控行动→后续反馈→继续/调整/退出”的个人证据；首页只露一个主入口。
- 名人名言首页：仅在用户主动选择时，将自己的教训转为一句可回看的个人提醒，不冒充历史名人名言。
- 「火种」：只读参考其成功经验；**中途退出绝不触发失败事件、惩罚或通知**。

**应当复用已有 SQLite 数据层和 AI Provider，禁止新建第二套提醒引擎、第二套历史库或直接修改无关模块。** 所有已有实际实现状态以当前源码核查为准。

### 领域端口（适配层，无需改变其业务定义）
```
FailureCapturePort  -> captureConfirmedMissed / captureManualEvent
ReflectionPort      -> draftReflection / saveDraft
InterventionPort    -> chooseMethod / rejectMethod / recordTrial
LessonLedgerPort    -> upsertLesson / linkEvidence / reviseLesson
ReminderPort        -> scheduleOptIn / cancel / nextRelevantAction
EvidencePort        -> readUserApprovedEvidence / appendOutcome
SafetyPort          -> privacyCheck / crisisExit / guardWording
```

保留旧表单、旧记录；新字段迁移采用渐进升级，不覆盖既有内容。

## 6. 数据结构与状态机

### 事件生命周期
```
EVENT_RECORDED -> REFLECTION_DRAFT -> INSIGHT_CANDIDATE
                  |                       |
                  v                       v
             SAVED_UNFINISHED         ACTION_PLANNED
                                          |
                                          v
                                     ACTION_ATTEMPTED
                                          |
                       +------------------+------------------+
                       v                  v                  v
                  OUTCOME_HELPED     OUTCOME_UNCLEAR    OUTCOME_NOT_HELPED
                       |                  |                  |
                       +------------------+------------------+
                                          v
                                     LESSON_REVISED
                                          |
                                          v
                                     NEXT_TRIAL / CLOSED
```

- 支持「没有教训」「没有采取行动」「暂时放下」「明确退出目标」状态，不强迫每条失败产生动作。
- 同一行动结果可以关联多个原因假设，但**一个试验默认仅改变一项主要干预**，便于解释效果。
- 提醒必须经用户明确授权且按事件去重；数据缺失不代表行为失败。
- `source_provenance` 必须区分 `tal_original_exercise / tal_lecture / tal_autobiography / product_extension / external_research`。

### 推荐最小对象
`FailureEvent`、`Reflection`、`Hypothesis`、`InterventionTrial`、`ActionEvidence`、`Lesson`、`MethodSource`、`CaseStory`。

建议最小字段：
```
FailureEvent: id, user_goal_id, event_time_utc, plan, observed, user_confirmed, source, status
Reflection: event_id, did, thought, felt_then, felt_now, lessons, known_unknown, updated_at
Hypothesis: id, event_id, statement, basis_evidence_ids[], contradiction_ids[], confidence_label
InterventionTrial: id, event_id, method_id, chosen_reason, action_text, when_context, status, prev_trial_id
ActionEvidence: trial_id, observed_at_utc, action_done, observed_outcome, evidence_refs[], notes
Lesson: id, event_id, version, statement, status, next_trigger, next_action, trial_ids[], validated_by_user
MethodSource: method_id, provenance_kind, source_title, source_url, source_scope, evidence_limit
CaseStory: case_id, description, action_reported, outcome_reported, source_url, certainty, mappings[]
```

请优先迁移/扩展当前 `be_lesson` 和 `fp_learning_card` 对应的实际字段，以上仅为领域逻辑字段，不要求创建所有新表。

## 7. 低成本 AI 与严格输出契约

AI 只负责窄任务：
1. 从用户原话中提取 `事实/想法/情绪/未知`，每项附原话证据；不生成未经证实的心理原因。
2. 根据用户主动表达的困难和行为反馈，从**批准的 method catalog** 中选最多2种训练候选，说明来源与适用边界。
3. 生成一个可验证的具体行动计划；不得要求用户无限深挖。
4. 下一次结果回来后，比较执行前后差异，更新教训的信度，不自动宣告“治愈/永久改变”。

当输入不完整、信息不足、AI 网络不可用时必须支持**本地静态模板**；无需强制联网。详见 `ai_prompt_contract.md`。

## 8. 风险、隐私和治理

- 反思涉及心理、健康、求职等敏感叙述：**本地优先**；上传 AI 必须有独立明确同意，允许删除、导出与撤销。
- 不推断潜意识创伤、人格诊断、精神疾病；不把睡眠问题全都理解成心理回避。
- 对自伤风险、严重危机等情况退出角色化引导，提供恰当支持指引。
- 不奖励失败次数，不设置羞辱性赌注、金钱惩罚或“连续失败”恐吓话术。
- 用户主动退出一个不合适的目标，不默认计算为失败。
- 静默时段、提醒每日频率、拒绝/忽略次数上限必须继承现有设置；默认不强制监督。
- 不允许将作者个人故事转成“对用户一定有效”的治疗建议。

## 9. 开发验收与分期

P0 — **证据与历史**：现有失败入口和已有记录全部保留；源标记正确；未知原因不编造。

P1 — **教训账本与行动回访**：每条有效教训至少关联一次下一行动的真实反馈；可以“未完成/尚未验证”。

P2 — **方法路由与案例卡**：至少提供标准/简短两种训练长度；支持用户拒绝推荐的方法；同类旧失败不强推。

P3 — **长期稳定性**：提醒去重、离线、迁移、AI 失败降级、复杂事件与隐私压测。

验收测试见 `acceptance_scenarios.json`。只跑与本插件、既有失败/敌人/行为追踪相关的定向测试，避免无关 CI 工作流被反复触发。

## 10. 关键参考资料（具体范围和链接）
1. Tal 本人《How to Move From Perfectionism to Optimalism》（《The Pursuit of Perfect》摘录）：https://experiencelife.lifetime.life/article/beyond-perfect/
2. Tal 本人《Real Change》，含 Unbundling Exercise：https://wholebeinginstitute.com/real-change/
3. Tal 本人《Just Do It!》（《Choose the Life You Want》摘录）：https://wholebeinginstitute.com/just-do-it/
4. Tal 本人《Creating Rituals》（《Happier》摘录）：https://kripalu.org/living-kripalu/creating-rituals
5. Tal 哈佛《Positive Psychology》公开课逐字稿（非学校校订版）：https://positivepsychology.com/harvard-positive-psychology-course-1504/transcripts_-_lectures_1-12/
6. Tal《Happy Habits》书籍官方介绍：https://www.talbenshahar.com/media-podcasts-interviews-books-and-1/happy-habits
7. Tal《The Pursuit of Perfect》访谈（尝试—失误—校准）：https://www.mindtools.com/axyd3ab/the-myth-of-perfection/
8. Tal、Russo-Netzer，《Learning from success》，2011，强调 transformation rather than information：https://www.tandfonline.com/doi/abs/10.1080/17439760.2011.634823
9. Tal 访谈中哈佛壁球经历：https://squashmagazine.com/2019/04/why-does-squash-make-you-happy-tal-ben-shahar-and-positive-psychology/
10. 哈佛大学访谈中感恩日记亲身实践：https://harvard-thinking.simplecast.com/episodes/optimism-kLsLA99y
11. 哈佛《Crimson》2006年考试材料事故报道：https://www.thecrimson.com/article/2006/5/19/psych-students-show-tests-dont-of/
12. 《Happiness Studies》SPIRE 介绍：https://link.springer.com/book/10.1007/978-3-030-64869-5
13. 《The Pursuit of Perfect》第九章 `The PRP Process`（英文原著第176–179页）；法文译本法语目录独立列出 *Le PRP* 与练习：https://www.bnfa.fr/livre?biblionumber=67077
14. 2009年《TIME》对作者PRP的报道（原文标题 A Primer for Pessimists，网页目前可能被广告/赞助内容覆盖）：https://time.com/archive/6688052/a-primer-for-pessimists/

**版权提醒**：插件只收录以自己的语言编写的简短故事、事实摘要与来源链接；不要把原著章节或逐字稿整篇塞入 App 发布包中。
