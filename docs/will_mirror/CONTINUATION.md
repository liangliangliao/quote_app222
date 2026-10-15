# v2.8 真机问题修复与后续开发

本轮从最新相关分支 `codex/will-mirror-v28-rebuild@c94151a1` 继续，沿用 PR #173。已 fetch 核对 `main@ec8f7749`；没有把无关功能分支的提交时间当作本模块的开发基线。用户反馈是覆盖安装后首次进入即报错。

## 本轮完成

1. 修复 Android `SQLiteDatabase.execSQL` 不能执行返回结果的 PRAGMA：首次打开的 `secure_delete`、撤回与删除后的 `wal_checkpoint` 改走查询接口。保留数据库、加密格式和密钥 alias。详见 [启动修复](DEVICE_STARTUP_FIX.md)。
2. 启动错误按安全代码分类，支持重试；AI 配置或提醒同步失败不阻断已经读取成功的本地资料。真正的存储/解密失败不能被空列表掩盖。
3. 个人原则必须由本人采纳才成为本轮现场提示。看到或打开原则不代表想起、采用或有效；准备阶段的未核实安全限制明确显示原因，仍可不使用原则完成课题。
4. 原则被修订、需要复核、存在新安全限制或本人标记当前不适用后，停止作为新提示。跨课题复用同时要求来源授权和本轮适用性比较。
5. 实际采用必须有具体做法及本轮真实尝试/观察，且不能发生在 T0/T1；本人自述不能冒充外部核实。应用记录锁定当时的原则版本，允许事后回看旧版，不把新版替换进旧记录。
6. 新增 Android 平台调用契约回归、真实 sqflite/Keystore 集成测试和 API 26/35 覆盖安装测试工作流。测试库与用户正式库分离。

## P0 完成与待验收矩阵

“已有”表示存在可运行实现；“部分”表示仍有明确交付或验收缺口。程序测试和模拟服务不证明真实模型质量，也不证明用户设备行为。

| P0 要求 | 当前状态 | 实现与测试证据 | 仍需完成的验收 |
|---|---|---|---|
| 发现之旅单入口、一步输入、渐进工作台 | 已有 | `discover_page.dart`、`presentation/module_page.dart`、`workbench.dart`；`widget_flow_test.dart` | 厂商设备、TalkBack、TTS 的实际交互 |
| 覆盖安装后首次打开、错误恢复 | 本轮修复；真机验收部分 | `data/store.dart`、`WillMirrorV28Vault.kt`、`startup_recovery_test.dart`、`android_sqlite_contract_test.dart`、`integration_test/will_mirror_storage_test.dart` | 用户原签名 APK 与原设备直接覆盖复测 |
| 同一 Case 的事实/信念/未知及欲求证据 | 已有 | `domain/model.dart`、`rules.dart`、`ai/protocol.dart`；`domain_test.dart`、`ai_contract_test.dart` | 真实模型生成内容逐条盲审 |
| 50–70 个语义候选、Top5 正反理由与不足说明 | 已有；语义验收部分 | `ai/pipeline.dart`、`domain/ranking.dart`；`ai_contract_test.dart`、`regression_v28_test.dart` | 24 个跨域案例的真实生成、去重及反方质量 |
| 路线、能力、可行性和安全独立门槛 | 已有 | `domain/schema.dart`、`rules.dart`、`workbench_analysis.dart`；领域与回归测试 | 复杂现实限制的模型判断 |
| T0 封存、等待、T1 核验、T2 实际反馈、T3 体验 | 已有 | `rules.dart`、`workbench_action.dart`、`workbench_review.dart`；领域/控制器/Widget 测试 | 通知、锁屏、省电、重启设备矩阵 |
| 同 Case 多轮、真实道路、取得与满足分离 | 已有 | `domain/model.dart`、`presentation/visuals.dart`、`me_page.dart`；`widget_flow_test.dart`、`scenario_integrity_test.dart` | 长期真实使用反馈 |
| 原则形成、本人采纳、适用性、真实应用与版本 | 本轮补齐程序约束 | `rules.dart`、`workbench_review.dart`；`principle_application_test.dart` 的 13 项领域/Widget 测试 | 原则质量、反例修订的真实模型评审 |
| 宿主 Provider、最小授权、结构校验、评分降级 | 已有；在线验收部分 | `integration/private_model.dart`、`integration/host_settings.dart`、`ai/pipeline.dart`、`ai/decisions_gateway.dart`、`server/will_mirror`；HTTP 契约与 12 项服务测试 | 使用用户已有 Provider 的真实请求；没有新增凭据或声称已做在线验证 |
| 加密账本、撤回、历史删节、跨 Case 撤权 | 已有；本轮补 Android 回归 | `data/store.dart`、`application/controller.dart`；`store_controller_test.dart`、原生集成测试 | 原设备/原发布签名验收；不提供跨设备同步或旧格式自动导入 |
| T1–T366 可追溯验收 | 部分 | `acceptance.json`、`check_acceptance.py` | 索引完整不代表 366 项全部通过；各项剩余工作保留 |

## 原则流程复测

1. 在一个有真实证据的课题中生成原则候选；未采纳前它不能出现在现场行动提示中。
2. 准备页点击“采用为本次参考”，记录仍显示尚无实际应用证据；不使用原则也能保存预案。
3. 现场核实条件后可以记录“我现场确实想起了它”；这不会自动写成实际采用。
4. 点击“当前条件不适用”，当前提示停止展示。新增安全限制同样阻断复用。
5. 反馈中记录真实尝试/观察后，说明具体如何采用；外部结果未知仍保留未知，不宣布原则有效。
6. 修改原则生成新版本，原应用记录继续引用旧版。跨课题引用必须有授权和新情境比较；撤权后不能继续推荐原原则。

实际执行结果见 [VALIDATION.md](VALIDATION.md)。未合并 main，未把自动测试结果标记为完整产品验收。
