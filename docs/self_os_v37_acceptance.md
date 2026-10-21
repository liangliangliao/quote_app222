# Self OS V3.7：实现与验收证据

审查日期：2026-10-21。开发基线：`main@37a34004`。范围仅为发现之旅中的 Self OS。

## 怎样回答这次的五个问题

| 问题 | 当前结论 | 判定边界 |
| --- | --- | --- |
| 原方案实现是否超过 90%？ | **尚不能认证这个百分比。** | 当前执行环境没有先前上传的 PDF 原件，下面依据前一轮从原文提取并保存在 `self_os_v37.md` 的需求映射核对。没有用页面数、代码行数、测试数量或自行缩小的分母当作原方案覆盖率。 |
| 核心和重点功能是否具备？ | 五引擎、欲求与路径选择、认识与证据门槛、冲突与决意、行动与反馈、未来准备、力量、因果地平线均有可运行实现。 | 区分可执行的业务机制与真实模型的分析质量；后者仍需实际模型验收。 |
| 业务逻辑是否清晰完善？ | 主流程已连接到同一数据模型，新增真实反馈回到原问题、动机、后果和下一轮的闭环。 | 自动化验证覆盖关键状态、反例、写入失败及恢复。不能据此声称不存在未知缺陷。 |
| 是否系统化和智能化？ | 已有统一下一步调度、独立持久化、可追溯快照、模型候选分析、用户校准和实际经历进入后续 AI 上下文。 | 智能化方式是模型推理、规则约束和经验检索，不是在线训练模型权重。当前无可用模型凭据，未验证真实生成质量。 |
| 是否还需要改进？ | **需要继续根据真实使用改进。** | 当前可完成的代码缺口已修复；原文全量复核、真实模型和 Android 真机验收不能由模拟响应替代。 |

以下清单包含 58 条技术与交互验收点，其中 53 条有专项自动化证据，5 条仅代码审阅，不作为原文全量需求的替代分母。“专项验证”指 Self OS 范围的可控自动化验证；“代码审阅”表示实现已检查，但该项没有独立的交互或效果验收证据。二者均不代表真实模型质量已通过。

## 可追溯验收清单

文件名均相对于仓库；实现位于 `lib/self_os/`，验证位于 `test/self_os/`。

| ID | 要求与通过条件 | 实现证据 | 验证证据 / 状态 |
| --- | --- | --- | --- |
| W01 | 发现之旅内独立入口；不修改其他产品数据 | `self_os_discover_entry.dart`、`self_os_repository.dart` | `self_os_widget_test.dart`、`self_os_repository_test.dart` · 专项验证 |
| W02 | 首页三个入口，案例可保存后继续 | `self_os_home_page.dart`、`self_os_guide_page.dart` | `self_os_widget_test.dart`、`self_os_guide_widget_test.dart` · 专项验证 |
| W03 | 独立提出 5–10 个欲求假设，不能读 Why Tree 充当独立分析 | `self_os_ai_service.dart: discover` | `self_os_ai_test.dart` · 专项验证 |
| W04 | Why Tree 分支、合并、回退，拒绝悬空父节点 | `self_os_models.dart: addWhy/removeWhy` | `self_os_domain_test.dart` · 专项验证 |
| W05 | 比较独立假设与自我解释，保留重合、独有与冲突 | `self_os_ai_service.dart: compare`、`self_os_case_page.dart` | 结构与入口已具备，真实比较质量待模型验收 · 代码审阅 |
| W06 | 欲求、手段、认识、环境四类阻塞分别分流 | `self_os_engine.dart: next` | `self_os_domain_test.dart` · 专项验证 |
| M01 | 50–100 个去重候选动机，保留正反两方 | `self_os_ai_service.dart: motives` | `self_os_ai_test.dart`：三批 60 个、去重与取消 · 专项验证 |
| M02 | 实际反馈参与动机排序；未知反馈不计失败 | `self_os_engine.dart: motiveRank/motiveFingerprint` | `self_os_domain_test.dart` · 专项验证 |
| K01 | 七类认识操作有独立选择与候选建议 | `self_os_models.dart: selfOsCognitiveOperations`、`self_os_case_page.dart` | 七类操作与输入输出已审阅；逐类真实效果未验收 · 代码审阅 |
| K02 | 保存认识、动机、注意及预测的前后基线 | `self_os_models.dart: beginCognition/completeCognition` | `self_os_v37_rules_test.dart`、`self_os_guide_test.dart` · 专项验证 |
| K03 | 新增、增强、减弱、失效由实际差异计算；可明确无变化 | `self_os_v37_rules.dart: motiveDelta`、`self_os_reentry_panel.dart` | `self_os_learning_test.dart`：AI 建议增强而本人取消时记录失效 · 专项验证 |
| O01 | 八类不同实现机制，不能只换路径名称 | `self_os_v37_models.dart: osMechanisms`、`self_os_v37_ai.dart: routes` | 枚举、结构键、提示与表单已审阅；语义差异需模型验收 · 代码审阅 |
| O02 | 扩面有停止依据，不强制凑满八种路径 | `self_os_v37_rules.dart: expansionStop`、`self_os_v37_ai.dart` | `self_os_v37_ai_source_test.dart` · 专项验证 |
| O03 | 一般价值与六项个人适配分开；未知不填零 | `self_os_routes_panel.dart`、`self_os_v37_models.dart: OsRoute.fit` | `self_os_handoff_widget_test.dart`：高一般价值不替代本人适配；空项与路线状态保存 · 专项验证 |
| O04 | 扩面、筛选、实验、承诺、守护、修订的阶段随真实操作推进 | `self_os_guidance.dart`、`self_os_models.dart`、`self_os_repository.dart` | `self_os_learning_test.dart`、`self_os_v37_repository_test.dart` · 专项验证 |
| O05 | 五种投入状态；跨案例只允许一条人生主线 | `self_os_repository.dart: transitionRoute` | `self_os_v37_repository_test.dart`：原子切换与失败回滚 · 专项验证 |
| O06 | 主线必须记录真实取舍、能力与现实条件、机会成本接受 | `self_os_routes_panel.dart`、`self_os_repository.dart` | `self_os_v37_repository_test.dart` · 专项验证 |
| O07 | Path Guard 区分证据改道与反复新鲜、比较、逃避 | `self_os_insights.dart: pathGuard` | `self_os_v37_rules_test.dart` · 专项验证 |
| O08 | Fish-Bird 比较完整生活结构，而非只比较羡慕的外观 | `self_os_routes_panel.dart`、`self_os_insights.dart` | 表单与提醒已审阅，实际选择效果未验收 · 代码审阅 |
| S01 | 区分稳定倾向、技能、习惯、认识、环境、限制和未知 | `self_os_strength_panel.dart`、`self_os_v37_rules.dart: natureAdvice` | 分流与证据字段已审阅；不提供人格诊断 · 代码审阅 |
| S02 | 力量至少 3 次、2 情境、2 案例；重复或不存在来源不增信 | `self_os_insights.dart: strength` | `self_os_v37_rules_test.dart` · 专项验证 |
| S03 | 力量记录使用不足、合适、过度及反作用 | `self_os_strength_panel.dart`、`self_os_case_page.dart` | `self_os_v37_rules_test.dart`：实际观察、反证及重复来源 · 专项验证 |
| S04 | 力量—弱点—机制—动作桥接，并设置过度使用边界 | `self_os_strength_panel.dart: bridge`、`self_os_models.dart: stageStrengthBridge` | `self_os_handoff_widget_test.dart`：带入动作草稿、保留冻结协议、不自动认可候选力量 · 专项验证 |
| D01 | 四类冲突基于高重要度、已选动机和互斥选项 | `self_os_v37_rules.dart: conflict` | `self_os_v37_rules_test.dart` · 专项验证 |
| D02 | 前景、中景、背景、遗漏；重要度与注意占据分开 | `self_os_conflict_panel.dart`、`self_os_v37_rules.dart: attentionBreaks` | `self_os_v37_rules_test.dart` · 专项验证 |
| D03 | 知道、相信、重视、现场可用、动作连接分级 | `self_os_v37_models.dart: osEndorsement`、`self_os_reentry_panel.dart` | `self_os_v37_rules_test.dart`、`self_os_learning_test.dart` · 专项验证 |
| D04 | James 五类仅在临近或事后且有过程证据时分类 | `self_os_v37_rules.dart: jamesMode` | `self_os_v37_rules_test.dart` · 专项验证 |
| D05 | 现场最多一条认可提示，10–20 秒，可拒绝、暂停再行动 | `self_os_action_focus.dart` | `self_os_v37_widget_test.dart` · 专项验证 |
| D06 | 重大冲动决定需要冷却；努力决意承认被舍弃的真实价值 | `self_os_v37_rules.dart: gate`、`self_os_models.dart: commit` | `self_os_v37_rules_test.dart`、`self_os_v37_repository_test.dart` · 专项验证 |
| D07 | 审议轮次及信息增益可追踪；无增益停止反复准备 | `self_os_models.dart: completeCognition`、`self_os_v37_rules.dart: stopAdvice` | `self_os_learning_test.dart`、`self_os_v37_rules_test.dart` · 专项验证 |
| D08 | 个人原则包含适用、不适用、证据覆盖条件 | `self_os_home_page.dart: _principle`、`self_os_conflict_panel.dart` | `self_os_handoff_widget_test.dart`：现代与旧字段都显示边界，采用后保留来源、不自动承诺 · 专项验证 |
| E01 | PASS / ASK / RETRIEVE / VERIFY / EXPERIMENT / HOLD 随风险和未知切换 | `self_os_v37_rules.dart: gate` | `self_os_v37_rules_test.dart`、`self_os_guide_test.dart` · 专项验证 |
| E02 | 小实验许可不等于重大决定充分或人生主线许可 | `self_os_guidance.dart: commitExperiment`、`self_os_repository.dart` | `self_os_guide_test.dart`、`self_os_v37_repository_test.dart` · 专项验证 |
| E03 | 六类证据；来源、时间、有效期、冲突不明不能充当核实依据 | `self_os_v37_models.dart: OsEvidence` | `self_os_v37_rules_test.dart` · 专项验证 |
| E04 | HTTPS 原文读取、重定向和体积边界、摘录必须匹配 | `self_os_source_service.dart`、`self_os_knowledge_panel.dart` | `self_os_v37_ai_source_test.dart`；网络用可控响应 · 专项验证 |
| E05 | 敏感性情景由用户确认后才允许停止搜索 | `self_os_v37_models.dart: OsGap`、`self_os_knowledge_panel.dart` | `self_os_learning_test.dart`、`self_os_v37_rules_test.dart` · 专项验证 |
| E06 | 关联证据不等于已回答；关闭问题需答案、范围和有效证据 | `self_os_learning.dart`、`self_os_v37_models.dart: resolvedBy` | `self_os_learning_test.dart` · 专项验证 |
| G01 | 七类结构缺口，不按生活领域词汇分流 | `self_os_v37_rules.dart: representationGaps` | `self_os_v37_rules_test.dart`：七类结构、六领域、措辞与顺序变换 · 专项验证 |
| G02 | 竞争路径同深度检查正负、时间、直接间接、单次累积；例外需理由 | `self_os_v37_rules.dart: coverage/symmetryWarnings/gate` | `self_os_learning_test.dart`、`self_os_v37_rules_test.dart` · 专项验证 |
| P01 | 明确 T* 后才提出 1–3 个最小准备，绑定缺口、来源、时点与预期变化 | `self_os_preparation_panel.dart`、`self_os_v37_ai.dart` | `self_os_v37_ai_source_test.dart`、`self_os_v37_rules_test.dart` · 专项验证 |
| P02 | 八类准备方式，现场只保留预演，不能堆叠复杂阅读 | `self_os_v37_models.dart: osInterventionTypes`、`self_os_models.dart` | `self_os_v37_rules_test.dart` · 专项验证 |
| P03 | 准备前后 K/M/Att 和预测对照，实际行动另行回写，迟到不能当事前效果 | `self_os_models.dart: completeIntervention`、`self_os_learning.dart` | `self_os_v37_rules_test.dart`、`self_os_learning_test.dart` · 专项验证 |
| H01 | 多阶条件图、分支、回路、打断条件、阈值和可逆窗口 | `self_os_v37_models.dart`、`self_os_horizon_view.dart` | `self_os_v37_rules_test.dart` · 专项验证 |
| H02 | 最弱依据、过期、冲突、深度限制推断；共享 7 条主链预算 | `self_os_v37_rules.dart: causalPaths` | `self_os_v37_rules_test.dart` · 专项验证 |
| H03 | 近景 1–2 阶、中景 3–5 阶、远景与未知可展开查看 | `self_os_horizon_view.dart` | `self_os_v37_widget_test.dart` · 专项验证 |
| H04 | 六类未来路径变化可以带回选择空间 | `self_os_horizon_view.dart`、`self_os_routes_panel.dart` | `self_os_v37_rules_test.dart`、`self_os_v37_widget_test.dart` · 专项验证 |
| H05 | 实际反证连接后果和未来路径；暂停沿旧推断延伸并保留前后记录 | `self_os_learning.dart`、`self_os_v37_rules.dart` | `self_os_learning_test.dart` · 专项验证 |
| R01 | 行动协议冻结，后续草稿不能改写原预测；新信息优先重审 | `self_os_models.dart`、`self_os_guide_page.dart` | `self_os_domain_test.dart`、`self_os_learning_widget_test.dart` · 专项验证 |
| R02 | 真实完成、部分完成、未行动均可复盘；每轮只有一个样本 | `self_os_models.dart: addReview`、`self_os_guidance.dart: review` | `self_os_domain_test.dart`、`self_os_guide_test.dart` · 专项验证 |
| R03 | 对照原预期，确认支持、反证、混合、未知或未观察；限定适用范围 | `self_os_learning.dart`、`self_os_guide_learning_panel.dart` | `self_os_learning_test.dart`、`self_os_learning_widget_test.dart` · 专项验证 |
| R04 | 下一轮从本人校准后的认识继续；AI 获得真实观察、来源和范围 | `self_os_models.dart: nextRound`、`self_os_ai_service.dart` | `self_os_learning_test.dart`、`self_os_v37_repository_test.dart` · 专项验证 |
| R05 | 先比较 K/M/Att/E/T/Skill；稳定模式需控制条件和跨情境样本 | `self_os_insights.dart: attribution/stableChanges` | `self_os_v37_rules_test.dart` · 专项验证 |
| R06 | 个人模型可回溯欲求、预测、代价、力量、决意、准备与校准案例 | `self_os_home_page.dart`、`self_os_insights.dart` | `self_os_domain_test.dart`、`self_os_v37_rules_test.dart`、`self_os_learning_widget_test.dart` · 专项验证 |
| T01 | 首页、引导、AI 上下文共用下一步，按证据结构排序 | `self_os_progress.dart` | `self_os_learning_test.dart`：六领域分流；`self_os_learning_widget_test.dart`：首页联动 · 专项验证 |
| T02 | SQLite 关闭重开保留案例、冻结快照、校准和个人模型；兼容旧 JSON | `self_os_repository.dart`、`self_os_models.dart` | `self_os_repository_test.dart`、`self_os_v37_repository_test.dart` · 专项验证 |
| T03 | AI 不得写核实状态、实际结果、主线承诺或伪造引用 | `self_os_v37_ai.dart`、`self_os_guide_models.dart` | `self_os_v37_ai_source_test.dart`、`self_os_guide_test.dart`、`self_os_learning_test.dart` · 专项验证 |
| T04 | 保存失败不推进；取消后迟到响应不覆盖；详细页返回读最新记录 | `self_os_guide_page.dart` | `self_os_guide_widget_test.dart`、`self_os_learning_widget_test.dart` · 专项验证 |
| T05 | 窄屏、大字体、现场后台暂停及提示拒绝可用 | `self_os_guide_page.dart`、`self_os_action_focus.dart` | `self_os_guide_widget_test.dart`、`self_os_learning_widget_test.dart`、`self_os_v37_widget_test.dart` · 专项验证 |

## 本轮修复的业务断点

1. 原来实验反馈只形成结果与感想。现在用户可校准预期、结论和适用范围，保存到证据、K/M/Att 变化、关联后果、未来路径与准备记录；下一轮直接使用校准结论。原来的协议与观察保持不变。
2. 原来 AI 生成的两个“同选择”情景可能自动让缺口不再重要。现在需要本人确认；同一情景不能冒充两个合理情景。旧数据与 AI 候选不会自动获得确认。
3. 原来只关联一条可靠材料就可能算作回答。现在还需具体答案、适用范围与本人确认；过期和冲突仍会使答案重新需要核验。
4. 原来动机重新入场只有文字建议。现在逐项采用前由本人调整选择、强弱、认可、注意及动作连接，差异由前后真实数据计算。
5. 原来首页、引导和工作台的下一步提示各自独立。现在基于同一记录给出新情况重审、校准、修订、准备、取证或路径取舍的入口。
6. 原来引导实验保存的约定时间未被到期判断读取。现在写入真正的 `dueAt`，保留具体时刻，不把未来准备误报成现在到期。
7. 原来旧风险确认可能压过新的 AI 高风险提醒，重大决定的对称比较也只是提示。现在新提醒需要重新审视，高风险门槛会检查对称性并尊重有理由的不适用。
8. 原来从详细分析返回或重开时，旧的行动阶段可能掩盖重要新信息。现在重新进入理解，完整协议与人生主线都检查未审视的新信息。
9. 筛选、实验、修订和重新比较的阶段随真实业务动作更新；认识确认会记录审议轮次及对决定是否产生变化。
10. 力量桥接可以直接带入行动草稿与停止边界。候选力量仍需验证，原协议保持封存；已有协议下更换动作会进入重审。个人原则的不适用字段读取修正，并兼容旧记录。

## 尚未完成的验收

- **原 PDF 全量逐条复核**：需恢复 V3.7 原件，包含可能未进入上一轮需求映射的细则；原件恢复前不发布“整体达到 90%”的结论。
- **真实模型质量**：当前环境没有配置可用模型凭据。现有 AI 使用应用已有 `UnifiedAiService`，本次未改模型、供应商或密钥。可控响应测试只能证明流程与权限约束。
- **Android 真机使用**：APK 编译、Flutter 窄屏交互和 SQLite 测试不能代替设备上的安装升级、实际联网、后台恢复、软键盘与连续使用。
- **长期效果**：同一个人的真实跨情境经历需逐步积累；不能通过生成样本证明产品帮助了真实选择或改变了稳定模式。

自动网络搜索、后台系统通知、云同步并未在本轮新增。当前公共资料读取需要本人提供 HTTPS 来源；准备时刻在产品内展示。它们是否属于原方案的必做验收项，需要原文复核，不能擅自认定必做或排除出分母。

## 真实模型与真机验收方法

使用应用中本人已经配置的模型，在六种处境各走完整主流程：岗位自主空间、照顾家人与个人时间、技能学习、预算取舍、共同生活安排、创作投入。每种至少包括一次纠正、一条未知和一次实际反馈；高风险例只做信息核对与可撤回动作。

每个案例记录：模型及配置、时间、实际输入输出、问题是否回应最新补充、路径机制是否不同、正反代价是否对称、是否索取该索取的来源、实验边界是否匹配动作、反馈是否回到原问题、下一轮是否避免重复已回答的问题、本人是否认为有所帮助。逐项通过或不通过，不用模型自己打分充当验收。

硬性失败包括：编造原话或历史、把推断当事实、用小实验绕过不可逆承诺、无新证据反复追问、把未行动当结果支持、校准覆盖原始预测、重要新信息出现后继续旧协议。任何一次出现都应回到缺陷修复，不用平均分掩盖。

真机还应验证：安装/升级后旧案例保留，断网/模型失败输入保留，切后台再进入能继续，取消后迟到响应不覆盖，复盘与校准保存后重开一致。只操作 Self OS，不开展无关模块测试。

## 验证命令与交付

```sh
flutter analyze --no-pub lib/self_os test/self_os
flutter test --no-pub test/self_os --reporter expanded
```

GitHub 手动运行源码工作流 `.github/workflows/android_build_source_repo.yml`，输入 `self_os_checks=true`。该流程只分析和测试 Self OS，然后编译完整 release APK。提交包含 `[skip ci]`，避免推送或 PR 自动触发无关模块测试。构建和产物链接记录在本轮 PR 中；未合并前，旧主分支产物不包含本轮改动。
