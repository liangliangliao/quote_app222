# Self OS V3.7 原文验收记录

审查日期：2026-10-22。开发基线：`main@37a34004`；交付分支：`codex/self-os-v37-closed-loop-20261021`。范围只包括发现之旅内的 Self OS。

## 原件与统计口径

本轮已恢复并通读用户重新提供的 59 页 V3.7 PDF，不再依据上一轮转述推定需求。原件 SHA-256：`847b81b331c3b6896670cd10ad6b5f6fb17260ff79bfde8472d7391319217ef4`。第 12.2 节（p47–50）共有 **53 条核心验收标准**；[机器可读清单](self_os_v37_requirements.json)保存原文、页码、实现文件和验证文件。此前 58 条技术检查点不再充当产品需求分母。

**核心工程实现：50/53 项（94.3%），另 3 项部分完成。** 分母仅是原文明确列出的核心标准，分子指有可执行业务机制并有针对性工程证据，不是“整个 PDF 已验收 94.3%”，也不代表 AI 回答正确率。A38、A40、A47 保守计为未完成；不把模拟响应当真实智能效果。

本地 Self OS 静态分析通过，**138 项专项测试通过**。AI 测试使用受控响应，覆盖候选解析、上下文、调度、权限边界、异常恢复；没有在本环境请求真实模型。没有执行其他模块测试。

## 对用户五个问题的回答

| 问题 | 目前结论 |
| --- | --- |
| 实现进度超过 90% 吗？ | 按上述原文核心工程清单，94.3%；整体产品的真实使用验收尚不能作同样声明。 |
| 核心和重点功能具备吗？ | 欲求、动机、认识、行动、反馈五引擎，以及证据门槛、路径主线、冲突、力量、未来准备、因果地平线都已接通。 |
| 业务逻辑清晰完善吗？ | 已形成问题→认识/路径→决定或有边界实验→实际反馈→校准→下一轮的闭环；新信息和失效证据可以中断旧协议，失败写入不会伪造完成。 |
| 系统化、智能化了吗？ | 已有统一调度、模型候选推理、可解释规则、个人实证上下文和长期持久化；不是只拼接几个分析页面。真实模型质量尚待验收。 |
| 还需要改进吗？ | 需要：细粒度表示偏好学习、真实模型跨场景质量和 Android 真机连续使用。完成工程清单不等于再无改进空间。 |

## 第 12.2 节逐项映射

“实现”表示工程机制完成；“部分”表示仍有明确缺口。所有依赖自然语言理解或生成的条目，其真实模型质量均未在本环境验收，不仅限于标为“部分”的行。实现文件位于 `lib/self_os/`，测试位于 `test/self_os/`，下表省略共同的 `self_os_` 前缀。

| ID / 页 | 核心要求 | 工程状态 | 实现 | 专项证据 |
| --- | --- | --- | --- | --- |
| A01 / p47 | 六类关键缺口 | 实现 | `v37_ai.dart`、`knowledge_panel.dart` | `v37_ai_source_test.dart`、`v37_rules_test.dart` |
| A02 / p47 | 证据标签、来源、置信度、时效与冲突 | 实现 | `v37_models.dart`、`knowledge_panel.dart` | `v37_rules_test.dart`、`v37_ai_source_test.dart` |
| A03 / p47 | ASK/RETRIEVE/VERIFY/EXPERIMENT/HOLD 分流 | 实现 | `v37_rules.dart`、`progress.dart` | `v37_rules_test.dart`、`spec37_test.dart` |
| A04 / p48 | 展示冲突证据并降级确定性 | 实现 | `v37_rules.dart`、`horizon_view.dart` | `v37_rules_test.dart`、`spec37_test.dart` |
| A05 / p48 | 按风险与可逆性调整门槛 | 实现 | `v37_rules.dart`、`progress.dart` | `v37_rules_test.dart`、`spec37_test.dart`、`spec37_widget_test.dart` |
| A06 / p48 | K1→K2 后重建动机并解释差异 | 实现 | `models.dart`、`reentry_panel.dart` | `learning_test.dart`、`v37_rules_test.dart` |
| A07 / p48 | 低敏感性、低信息增益允许停止 | 实现 | `v37_rules.dart`、`knowledge_panel.dart` | `learning_test.dart`、`v37_rules_test.dart` |
| A08 / p48 | 自动识别并展示冲突、注意与互斥 | 实现 | `v37_rules.dart`、`conflict_panel.dart`、`home_page.dart` | `v37_rules_test.dart`、`spec37_widget_test.dart` |
| A09 / p48 | 四类冲突及证据不足状态 | 实现 | `v37_rules.dart` | `v37_rules_test.dart` |
| A10 / p48 | James 过程证据与置信度 | 实现 | `v37_rules.dart`、`conflict_panel.dart` | `v37_rules_test.dart` |
| A11 / p48 | 四层注意舞台与反方保留 | 实现 | `conflict_panel.dart`、`progress.dart` | `v37_rules_test.dart`、`spec37_test.dart` |
| A12 / p48 | 审议停止：原则、实验或复审 | 实现 | `v37_rules.dart`、`conflict_panel.dart` | `v37_rules_test.dart`、`handoff_widget_test.dart` |
| A13 / p48 | 识别重视但不能进入行动的断点 | 实现 | `v37_rules.dart`、`progress.dart` | `v37_rules_test.dart`、`spec37_test.dart` |
| A14 / p48 | 一条现场观念、第一动作与真实回写 | 实现 | `action_focus.dart`、`models.dart` | `v37_widget_test.dart`、`learning_test.dart` |
| A15 / p48 | 舍弃价值与机会成本接受 | 实现 | `conflict_panel.dart`、`repository.dart` | `v37_rules_test.dart`、`v37_repository_test.dart` |
| A16 / p48 | 六种决策变化来源与过程复盘 | 实现 | `case_page.dart`、`insights.dart` | `domain_test.dart`、`v37_rules_test.dart` |
| A17 / p48 | 现实问题自动分流至对应引擎 | 实现 | `guide_models.dart`、`ai_service.dart`、`progress.dart`、`guide_learning_panel.dart` | `spec37_test.dart`、`spec37_widget_test.dart` |
| A18 / p48 | 欲求来源、支持、反证、置信度和修订 | 实现 | `ai_service.dart`、`case_page.dart` | `ai_test.dart`、`domain_test.dart`、`guide_test.dart` |
| A19 / p48 | 正反动机与计划/现场两种概率 | 实现 | `ai_service.dart`、`models.dart`、`case_page.dart` | `ai_test.dart`、`domain_test.dart`、`guide_test.dart` |
| A20 / p48 | 低意向先区分欲求/手段/认识/环境 | 实现 | `engine.dart`、`ai_service.dart`、`case_page.dart` | `domain_test.dart` |
| A21 / p48 | 行动后生成可复用真实证据 | 实现 | `models.dart`、`learning.dart`、`case_page.dart` | `learning_test.dart`、`widget_test.dart`、`spec37_widget_test.dart` |
| A22 / p48 | 不足样本不作确定人格结论 | 实现 | `engine.dart`、`insights.dart` | `domain_test.dart`、`v37_rules_test.dart` |
| A23 / p48 | 个人实证参与 AI 生成与动机排序 | 实现 | `ai_service.dart`、`engine.dart` | `domain_test.dart`、`spec37_test.dart` |
| A24 / p48 | 改变人格/情绪前分类改变对象 | 实现 | `ai_service.dart`、`strength_panel.dart`、`progress.dart` | `spec37_test.dart` |
| A25 / p49 | 力量依据、反证、置信度与过度使用 | 实现 | `insights.dart`、`strength_panel.dart`、`home_page.dart` | `v37_rules_test.dart`、`spec37_widget_test.dart` |
| A26 / p49 | 力量在认识、动机、行动中调用与回写 | 实现 | `ai_service.dart`、`strength_learning.dart`、`strength_feedback.dart` | `spec37_test.dart`、`spec37_widget_test.dart`、`v37_repository_test.dart` |
| A27 / p49 | 已记录倾向/限制冲突优先对齐 | 实现 | `progress.dart`、`strength_panel.dart`、`v37_rules.dart` | `spec37_test.dart`、`handoff_widget_test.dart` |
| A28 / p49 | 结构不同的路径与机制解释 | 实现 | `guide_models.dart`、`guidance.dart`、`v37_ai.dart`、`routes_panel.dart` | `guide_test.dart`、`v37_ai_source_test.dart` |
| A29 / p49 | 扩面停止与机制去重 | 实现 | `v37_rules.dart`、`v37_ai.dart` | `v37_ai_source_test.dart`、`v37_rules_test.dart` |
| A30 / p49 | 唯一 Active 主线与其他明确状态 | 实现 | `repository.dart`、`routes_panel.dart` | `v37_repository_test.dart`、`handoff_widget_test.dart` |
| A31 / p49 | 频繁切换/比较触发/多主线漂移提醒 | 实现 | `insights.dart`、`home_page.dart` | `v37_rules_test.dart` |
| A32 / p49 | 允许证据改道并保留旧路线理由 | 实现 | `repository.dart`、`routes_panel.dart` | `v37_repository_test.dart` |
| A33 / p49 | 欲求、能力、代价、主线关系与机会成本 | 实现 | `routes_panel.dart`、`repository.dart` | `v37_repository_test.dart`、`handoff_widget_test.dart` |
| A34 / p49 | 按语义结构而非领域词触发 GMRC | 实现 | `ai_service.dart`、`progress.dart`、`v37_rules.dart` | `v37_rules_test.dart`、`spec37_test.dart` |
| A35 / p49 | 后果图四组维度与有理由的不适用 | 实现 | `v37_rules.dart`、`knowledge_panel.dart` | `v37_rules_test.dart`、`learning_test.dart` |
| A36 / p49 | 选项对称与顺序/措辞不变性 | 实现 | `v37_rules.dart`、`v37_ai.dart` | `v37_rules_test.dart`、`learning_test.dart` |
| A37 / p49 | 关键边条件、依据与置信度 | 实现 | `v37_rules.dart`、`horizon_view.dart` | `v37_rules_test.dart`、`spec37_test.dart`、`spec37_widget_test.dart` |
| A38 / p49 | 按个人历史选择有效表示方式 | 部分 | `ai_service.dart`、`engine.dart` | `spec37_test.dart` |
| A39 / p49 | M0→M1 差异，文字增加不等于有效增益 | 实现 | `models.dart`、`v37_rules.dart`、`reentry_panel.dart` | `v37_rules_test.dart`、`learning_test.dart` |
| A40 / p49 | 至少六类同结构跨场景完整回归 | 部分 | `v37_rules.dart`、`ai_service.dart`、`learning.dart` | `v37_rules_test.dart`、`learning_test.dart`、`spec37_test.dart` |
| A41 / p49 | 未来 T* 与最小认识准备 | 实现 | `progress.dart`、`ai_service.dart`、`preparation_panel.dart`、`home_page.dart` | `v37_rules_test.dart`、`guide_test.dart`、`learning_test.dart`、`spec37_test.dart` |
| A42 / p50 | 干预绑定缺口/来源/时点/预期变化 | 实现 | `v37_ai.dart`、`models.dart`、`preparation_panel.dart` | `v37_ai_source_test.dart`、`v37_rules_test.dart` |
| A43 / p50 | 关键未知的翻转敏感性 | 实现 | `v37_models.dart`、`v37_rules.dart`、`knowledge_panel.dart` | `learning_test.dart`、`v37_rules_test.dart` |
| A44 / p50 | 干预前后 K/M/Att 与 D/A/R 对照 | 实现 | `models.dart`、`learning.dart`、`insights.dart` | `v37_rules_test.dart`、`learning_test.dart` |
| A45 / p50 | K/M/Att/E/T/Skill/稳定模式归因 | 实现 | `insights.dart`、`case_page.dart` | `v37_rules_test.dart` |
| A46 / p50 | 控制条件、跨情境多样本才更新稳定模式 | 实现 | `insights.dart` | `v37_rules_test.dart` |
| A47 / p50 | 跨领域措辞/顺序的多阶分支回路泛化 | 部分 | `v37_rules.dart`、`v37_ai.dart`、`ai_service.dart` | `v37_rules_test.dart`、`spec37_test.dart` |
| A48 / p50 | 决定无关、未知过多或超负荷时剪枝 | 实现 | `v37_rules.dart`、`horizon_view.dart` | `v37_rules_test.dart` |
| A49 / p50 | 近中远三级视图和分支折叠 | 实现 | `horizon_view.dart` | `v37_widget_test.dart`、`spec37_widget_test.dart` |
| A50 / p50 | 未来路径变化与选择/主线/护栏联动 | 实现 | `models.dart`、`horizon_view.dart`、`routes_panel.dart`、`repository.dart` | `v37_widget_test.dart`、`v37_repository_test.dart` |
| A51 / p50 | 逐节点/路径证据与远期置信度 | 实现 | `v37_rules.dart`、`horizon_view.dart` | `v37_rules_test.dart`、`spec37_test.dart`、`spec37_widget_test.dart` |
| A52 / p50 | 条件分支、回路、阈值和路径依赖 | 实现 | `v37_models.dart`、`v37_rules.dart`、`horizon_view.dart` | `v37_rules_test.dart`、`v37_widget_test.dart` |
| A53 / p50 | 继续追踪有价值的二阶、三阶及以后 | 实现 | `v37_rules.dart`、`v37_ai.dart`、`horizon_view.dart` | `v37_rules_test.dart`、`spec37_test.dart` |

## 核心标准之外的章节复核

| 原文章节 / 页码 | 工程对应与边界 |
| --- | --- |
| §1–3，p3–10：W→K→M→Att→D→A→R→K′、六阶段、个性/力量 | `models/guidance/learning` 保留冻结前态、实际结果与后态；`strength_panel/insights` 区分候选、反证、现实限制与稳定模式。不会推断基因或终极人格。 |
| §4，p10–15：冲突、James、注意、认识门槛与 LHCP | 对应 A01–A16、A34–A53；具体判定使用可解释提示和证据等级，不把心理学描述伪装成测量概率。 |
| §5，p16–20：欲求与动机 | 独立生成 5–10 个欲求；Why Tree 支持分支、合并、纠正；AI 比较重合/部分重合/双方独有/冲突。动机搜索 50–100 个，双向、三层、五个时间尺度；当前作用参考相关性×可信度×鲜明度×注意×历史，任一缺失显示未知。 |
| §6–7，p21–29：七类认识操作、八类未来准备、现场 Ritual | 用户选定操作进入真实请求；补全前后 K/M/Att 可比较；准备绑定来源、缺口、T* 和实际反馈；现场保持一条观念 10–20 秒并连接第一动作。 |
| §8，p29–35：行动之镜、能力、桥接、路线 | 实际证据区分已验证优势/硬限制/可训练/未验证/不适配；口头代价与真实遭遇分开；八类路径机制、停止依据、五种状态与全局唯一主线；原则有适用、不适用和覆盖条件。 |
| §9.1，p35–36：十二个长期模型 | 欲求、认知、信念、动机、能力、经验性格、获得性格、力量/个性、可能性/路线、冲突/决意/注意、认知干预、长时域图谱分别对应个人说明书、指纹、实际观察、力量、路线记录、干预及因果图；前五类包含本人可修订解释，不能当作自动验证的心理模型。 |
| §9.2–9.3，p36–37：三个指纹、九个校准数据库 | 动机/认知/决意注意指纹；预测、代价、取舍、力量、路线、决意、认识、干预、因果九类逻辑记录由独立 SQLite 的案例/个人模型 JSON 承载。原文未要求九张物理表。 |
| §9.4–9.5，p37–38：评分与成熟度 | 使用主观估计、实测频次、结构缺口、解释性等级和证据覆盖；未知不填零。没有为每个指标臆造百分比，成熟度是覆盖维度而非人格排名。 |
| §10，p39–41：AI 总管家与首页 | 三入口；语义路由与证据优先级共同决定下一步；模型生成候选、规则执行门槛；新增三项冲突摘要、经验证力量卡和 T* 最小准备卡。狭窄选择空间可扩面也可继续分析。 |
| §11，p41–45：完整案例 | 作为业务示例而非关键词模板。自动化含本人纠正、未知概率、小实验、未行动、真实反馈与下一轮；示例的实际问答效果仍待真实模型验证。 |
| §12.3–12.5，p50–52：泛化测试族 | 见下表；规则侧通过不等于模型在陌生自然语言变体上通过。 |
| 附录 A，p52–55：数据对象 | 使用可兼容扩展的 JSON，保留案例、力量、路径、决意、干预、因果对象与来源 ID；旧 schema 1 可读，当前 schema 2，数据库版本与名字保持兼容。 |
| p55–59：理论参考 | 提供设计依据，不作为新的功能条目计入完成率。 |

## 第 12.3–12.5 节验证边界

| 原文测试族 | 已有工程验证 | 仍需验证 |
| --- | --- | --- |
| 即时不适/延迟后果、即时奖励/累积成本、避免冲突/问题积累、显著收益/机会成本、抽象目标/现实链条、重复小行为 | 七类表征缺口跨六领域措辞和选项顺序不变；条件/未知、对称性、停止与动机重新入场分别验证 | 六类自然语言输入的真实模型全流程，不能由结构化 fixture 代替 |
| Decision-Flip Sensitive Unknown | 不同访问方式、两情景翻转、相同情景无效、本人确认才可停止 | 真实模型能否提出合理且有证据的情景 |
| Prospective Preparation | T*、到期边界、迟到标记、复杂输入不得塞入现场、前后差异、真实行动回写 | 数小时到数周的实际内容与时点适配 |
| Same Person/New Knowledge、Environment vs Character、Stable Pattern Update | 七种来源对照；未知条件不当作不变；跨情境/多样本/替代解释门槛 | 真实长期数据的解释质量，不能生成样本冒充经历 |
| Multi-order、Conditional Branching、Feedback Loop、Threshold/Lock-in、Future Options、Horizon Uncertainty | 多阶/分支/回路、剪枝预算、阈值/可逆窗口、六类未来路径、逐节点置信度和最弱依据；跨域与顺序变化验证 | 模型自由输入下对条件、回路、阈值及高价值中间节点的泛化识别 |

## 本轮实际补齐与修复

1. 原文驱动的十类语义分流接到对应工作台/引擎，可直接启动所需分析；新信息、反证、过期证据优先。已审视的冲突不会无变化地反复阻挡。
2. 个人真实复盘、校准、原则、认知偏好与力量证据进入分析请求；不存在的力量/路径/欲求引用会被剔除。用户选定的认识操作实际参与请求。
3. 力量在认识、动机和行动中分别记录使用与作用；一次复盘只增加一个力量样本，反作用保留。没有具体观察不增信，未知反馈可以撤回原先判断。
4. 关键因果边显示来源与置信度；近处直接事实不再被远处未知一起降为未知，沿推断路径逐级降低确定性。
5. 当前动机作用同时参考可信度、鲜明度、注意和个人历史；缺失因子不编造分数。
6. 完整决定的协议在进入现场前重新检查依据；权限范围从封存协议读取。核验失败会回到认识入口，有边界实验仍保持其范围。
7. 复盘与力量反馈原子保存；失败保留草稿并可重试。新一轮清除上轮实际反馈输入与现场力量选择，历史快照保留。
8. 首页新增三项冲突摘要、证据充分才展示的力量卡；未来准备卡显示时刻、1–3 项动作、最晚时间与一条现场观念/第一动作。

## 尚未完成的三项与真实使用验收

- **A38**：已有基于真实认知操作样本的偏好输入及表征候选；尚未完成对表示方式 × 任务 × 时点的细粒度效果学习和真实个体效果比较。
- **A40**：已有七类结构缺口、六领域变体与前后动机闭环的规则/流程回归；尚未运行六类自然语言输入在真实模型上的完整泛化验收。
- **A47**：已有跨域多阶/置信度不变性、条件分支、回路与阈值规则回归；真实模型对陌生领域的分支/回路/路径依赖识别仍待完整泛化验收。

本环境没有可用的真实模型凭据；应用继续使用现有 `UnifiedAiService` 与用户已有供应商配置，没有改动公共 AI 服务或索取明文密钥。真实模型验收应记录实际配置、输入输出和来源，覆盖第 12.3–12.5 节用例族，并逐项判定，而不是让模型自评分。编造来源、单向说服、误升级事实或用小实验越过不可逆决定均判失败。

还需在 Android 真机上完成本模块的安装/升级数据保留、真实联网、断网重试、键盘、后台恢复和连续使用。APK 编译与 Flutter 手机布局检查不能替代真机测试。长期效果只能由用户真实经历积累。

公共事实目前通过用户提供的 HTTPS 链接读取和核验，未接入自动搜索；准备时点在产品内展示，未增加后台推送；本机保存与导出，未新增云同步。原文要求获取/核验可验证信息及准备时点，并未指定搜索供应商、系统通知或云同步，它们不被假报为已经实现的能力。

## 验证与 APK

```sh
flutter analyze --no-pub lib/self_os test/self_os
flutter test --no-pub test/self_os --reporter expanded
```

本地结果：分析无问题，138 项通过；已检查新引导入口与力量反馈的中文手机布局。GitHub 手动运行源码工作流 `.github/workflows/android_build_source_repo.yml`，输入 `self_os_checks=true`，只跑 Self OS 专项检查，再编译完整 release APK。提交包含 `[skip ci]`，避免触发无关模块自动测试。当前构建状态和最终产物链接以 [PR #187](https://github.com/liangliangliao/quote_app222/pull/187) 的本次提交记录为准。未合并主分支，旧 APK 不包含当前提交。
