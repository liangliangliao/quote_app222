# 失败—复盘—改变 V1.1：使用与交付说明

本次直接基于 GitHub `liangliangliao/quote_app222` 最新非主分支
`fix/schopenhauer-concept-graphs` 开发。拉取时其最新提交为
`efe30bb21bb60098f25f5e1415d7045c03beec1e`（2026-11-11 09:13:42 UTC），
本地开发分支为 `codex/tal-failure-change-v1.1`。

本目录的 `README.md`、`ai_prompt_contract.md`、`acceptance_scenarios.json`
保留用户压缩包的需求原文。两个知识 JSON 按原文件放入
`assets/failure_module/tal/`，没有让 AI 补写作者故事或原话。

## 从哪里开始

1. 发现之旅 → **失败 · 复盘 · 改变**，直接打开 **今天一件没有按计划发生的事**。
   原“失败与完美主义”模块概览中也保留同一入口。
2. 默认是 1–3 分钟的简短路径。事实、经历、认识和未知均可留空；可以记录成功经验，
   不会因为计划与实际不同就自动替用户定性为失败。
3. 可切换标准书写或原著 PRP。PRP 三步骤可自由往返，允许直接从视角或行动开始，
   无接纳情绪、找好处、倒计时或盖印的前置要求。
4. 选择继续 / 调整时，可以只保存，也可以明确动作、时机、检查方式，保存一个试验。
   不想分析、没有教训、暂不行动、放下或退出目标都能保存。
5. **学习卡**中打开记录，填写有没有做、实际结果和情境。效果未知保留为未知，
   没做不直接说明方法无效。可以改写认识、创建下一试验、导出或删除。

既有 3P、AAR、完整 PRP、课程、学习卡和敌人教训均保留。
已存在的 PRP 草稿仍进入旧编辑器；新会话提供“改用已有 App 完整练习”。
双栏、盖印、如果—那么和行动验证明确属于 App 扩展。

## 方法与案例

- 本地保存 15 种批准方法、19 个案例、18 个来源。默认优先展示作者明确自述应用 PRP 的 C18。
- 推荐依据用户主动选择的困难、明确原话及其已保存的实测结果，最多两种候选。
  原话仅做窄范围字面匹配并显示摘录，否定句不触发对应信号；安全、身体条件和寻找收益的意愿仍需明确选择。
  一次试验只保存一个主要干预。
- 每项显示选择依据、适用做法、不确定性、限制、何时换方法及原始出处。
- 可以拒绝方法；旧试验已明确没帮助的方法不自动重推。五分钟法也受失败记录与身体条件限制。
- 需要可承受的风险声明才建议挑战练习；疲劳不推断为不自律；寻找收获需要用户主动愿意。
- Unbundling 分别保存“希望保留的品质”和“希望减少的行为”。
- 案例六字段直接读库，区分亲述、记者报道与事后诠释；产品实验和方法映射单独说明。
  不使用 AI 生成故事、心理独白或治疗承诺。SPIRE 的本地检查标为产品扩展，保留著作来源。

## 与现有 App 如何融合

新增领域代码在 `lib/failure_module/tal/`，宿主适配在
`lib/prp_plugin_host/tal_adapter.dart`。没有新的业务数据库、通知服务或后台任务。

| 能力 | 实际复用 |
| --- | --- |
| 失败入口 | 现有 `PrpRuntime.signal` 的确认、额度、静默、安全及调用点开关 |
| 教训与反思 | `FpDao` / `fp_learning_card`，学习卡页仍是同一个入口 |
| 行为与敌人回访 | 既有 `recallChip` 插槽；对象匹配优先，手动记录使用原 PRP 文本相似度匹配 |
| 每日额度 | 新旧回访共同计算 `prp_recall` 与学习卡内的曝光凭据，SQLite 事务内分配 |
| 原生闹钟 | `PrpAlarmBridge` 沿用原通知流程，读取相同的额外曝光额度，不新增闹钟 |
| 静默与危机 | 原 `PrpHost.governance`、`SafetyValve`、`crisisExit`，关闭会话立即失效 |
| AI | 原 `PrpHostImpl` / `UnifiedAiService`，仅新增 `tal_extract` 窄任务 |
| 首页个人提醒 | 复用现有 `quotesForStream` 内存展示，不插入 `quotes` 或收藏库 |

`fp_learning_card` 仅渐进增加四个可空列：`tal_event_id`、`tal_subject_key`、
`tal_state`、`tal_data_json`，以及索引。旧行 ID、原文、标签及旧编辑入口均保留。
每个事件只用一张原有学习卡，事件 ID 有唯一约束；不同宿主重复触发不复制记录。
不修改 `be_lesson`，旧敌人教训保留在其原账本。

反思、单项干预试验、反馈证据、认识版本和展示凭据都存入这一张卡。
写反馈时使用稳定证据 ID 去重；新版本保存上一版认识和当时的证据引用，
不会把历史证据覆盖成最新结论。数据库操作兼容无 JSON1 的 Android 8 SQLite。

回访需单独勾选；默认不创建通知。相同事件与引用只登记一次展示，
忽略后遵守至少 24 小时冷却，累计三次忽略自动关闭该条回访。
已记录反馈、暂停或退出的试验不会继续作为待执行计划提示。
`pending`、缺日志、已收到通知及火种中途退出均不创建失败事件。

个人提醒还需要逐条授权和现有首页总开关，并共用每日额度、静默及 24 小时间隔。
显示“自己的话 / 我的学习卡 · 个人提醒”，不会混进名人名言的持久库。
撤销授权、改写认识或删除后，首页已有展示会撤下。

## 状态和隐私

- L0 记录、L1 待验证认识、L2 计划、L3 执行、L4 有个人改善证据分别计算。
  L4 需要用户确认及实际改善记录，不把单次观察当作确定因果。
- L5 额外要求用户确认，且至少三天、两个明确情境、三次改善证据。
  阅读故事、复制一句话或连续打卡不会提升层级。
- 本地路径不需要 API Key 或联网。AI 先检查原有独立授权，再逐次预览要发送的本次字段；
  不发送其他历史。不同意、超时、断网、格式或证据校验失败都保留本地表单。
- 严格验证 JSON、逐字原话、方法白名单、归属、限制、最多两个方法与一个问题。
  隐藏动机、人格诊断、未经核实的高置信断言与虚构案例被拒绝。
- AI 返回只供核对，不覆盖编辑内容、不替用户选择目标、不直接保存为有效教训。
  修改输入、关闭会话或撤销授权后，丢弃在途返回。
- 所有输入在保存前检查危机；表单和反馈输入立即进入支持指引，不保存或上传危机正文。
- 可导出含版本和证据的 JSON、撤销 AI / 提醒 / 首页授权，并删除整张记录。

## 验收对应

| 场景 | 实现与定向测试 |
| --- | --- |
| T01 不愿分析 | `widget_test` 空表单保存；`ledger_test` L0 无行动 |
| T02 原因未知 | `ledger_test` 原样保存未知；`catalog_routing_test` 无原因推断 |
| T03 全盘否定 | `catalog_routing_test` 3Ms、原话依据与边界 |
| T04 理性拒绝 | 路由目标复核、`GOAL_EXITED`、取消回访 |
| T05 缺日志 | 确认 missed 门槛与既有 PRP 运行时回归 |
| T06 火种退出 | 捕获端排除、既有火种 red-lines / schema / flow 回归 |
| T07 旧法无效 | 路由排除已失败方法，支持主动重试 |
| T08 不可承受风险 | 没有安全声明时不推荐伸展区 / Learn to Fail |
| T09 价值冲突 | Unbundling 路由和双字段真实界面保存 |
| T10 很难过 | 可暂停、无收益要求、无行动的草稿 |
| T11 提醒无效 | 展示去重、冷却、三次忽略关闭 |
| T12 拒绝 AI | 界面上传预览与拒绝、零调用、离线与异常降级 |
| T13 AI 编造动机 | 高置信、诊断、虚构原话的负例校验 |
| T14 虚构塔尔心理 | 静态故事原文、来源边界、拒绝 AI 新增 cases |
| T15 真实伤害 | 简短表单先显示责任与补救支持；保留 C15 报道边界 |
| T16 执行但未知 | 界面反馈和账本状态 `OUTCOME_UNCLEAR` / L3 |
| T17 降低打扰 | 忽略限额与关闭回访；无惩罚逻辑 |
| T18 自伤危机 | 界面即时退场、SQLite 不落危机原文、AI 调用前拒绝 |
| T19 多宿主触发 | 并发同事件唯一卡、不覆盖先前内容 |
| T20 新事实修订 | 认识版本链、证据引用、反馈幂等与旧结果保留 |

验证使用仓库现有 Flutter 3.35.3；所有 AI 测试为本地替身，没有真实 API 调用。
结果和原始日志见同目录 `evidence/`。Flutter bundle 构建验证 Dart 与资源集成，
不等于已编译或在设备运行 Android APK。本次已尝试安装 SDK / NDK 并编译调试 APK，
但 7.9 GB 工作区被依赖缓存耗尽，Gradle 在配置 `flutter_web_auth_2` 时因
`No space left on device` 失败，未完成 Kotlin / APK 编译；已清理本次临时依赖恢复空间。
本次未进行 Android 模拟器或物理手机验收。旧 Android 验收脚本已调整为明确选择保留的完整 App 练习，
不再假定默认必须进入线性步骤。

```sh
flutter pub get
flutter analyze --no-pub --no-fatal-infos lib/failure_module/tal lib/prp_plugin_host lib/prp_plugin test/tal_failure_change
flutter test --no-pub test/tal_failure_change test/prp_plugin
flutter test --no-pub test/beautiful_enemy/enemy_guard_test.dart test/kindling/kindling_red_lines_test.dart test/kindling/kindling_schema_test.dart test/kindling/kindling_flow_widget_test.dart
flutter build bundle --debug --no-pub --target-platform android-arm64
python3 tools/pack_tal_failure_change.py
```

源码包附 `TAL_DELIVERY.json` 和 SHA-256，记录基线、实际工作分支、提交、是否有未提交修改及逐文件摘要。
包含完整 App 源码和本次验证记录，不包含工作区缓存、构建目录或仓库中原有的签名私钥。
