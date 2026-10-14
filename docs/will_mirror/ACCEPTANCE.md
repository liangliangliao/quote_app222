# T1–T366 实现与验收索引

每项保留正式 PRD 原文、来源行、实现文件和相关回归文件，详见 [acceptance.json](acceptance.json)。**没有将 366 项声明为全部验收通过。** 程序规则测试、模拟 HTTP 合约、真实模型盲审与 Android 真机验证分别记录。

| 范围 | 产品部分 | 主要实现 | 验证边界 |
|---|---|---|---|
| T1–T34 | 课题、理论约束和真实反馈 | `ai/protocol.dart`、`ai/pipeline.dart`、`domain/rules.dart` | 自动回归覆盖结构/状态；语义与设备表现见逐条记录 |
| T35–T43 | 路线和独立适配维度 | `domain/schema.dart`、`domain/rules.dart`、`ai/protocol.dart` | 自动回归覆盖结构/状态；语义与设备表现见逐条记录 |
| T44–T56 | 可选预演与现场核验 | `domain/rules.dart`、`ai/pipeline.dart`、`presentation/visuals.dart` | 自动回归覆盖结构/状态；语义与设备表现见逐条记录 |
| T57–T69 | 认识、事实与假想 | `domain/schema.dart`、`domain/rules.dart`、`ai/protocol.dart` | 自动回归覆盖结构/状态；语义与设备表现见逐条记录 |
| T70–T84 | 条件性经验与反例 | `domain/model.dart`、`domain/rules.dart`、`ai/protocol.dart` | 自动回归覆盖结构/状态；语义与设备表现见逐条记录 |
| T85–T101 | 动机关系与认知修订 | `ai/pipeline.dart`、`domain/ranking.dart`、`application/controller.dart` | 自动回归覆盖结构/状态；语义与设备表现见逐条记录 |
| T102–T120 | 时间后果与未来不确定性 | `domain/schema.dart`、`domain/rules.dart`、`ai/protocol.dart` | 自动回归覆盖结构/状态；语义与设备表现见逐条记录 |
| T121–T144 | 决意、机会、尝试与行动 | `domain/model.dart`、`domain/rules.dart`、`presentation/workbench_action.dart` | 自动回归覆盖结构/状态；语义与设备表现见逐条记录 |
| T145–T169 | 障碍、偏差和补救 | `domain/schema.dart`、`ai/protocol.dart`、`presentation/workbench_analysis.dart` | 自动回归覆盖结构/状态；语义与设备表现见逐条记录 |
| T170–T186 | 身体、技能与任务要求 | `domain/schema.dart`、`domain/rules.dart`、`ai/protocol.dart` | 自动回归覆盖结构/状态；语义与设备表现见逐条记录 |
| T187–T210 | T0、真实触发与现场重估 | `domain/rules.dart`、`application/controller.dart`、`integration/reminders.dart` | 自动回归覆盖结构/状态；语义与设备表现见逐条记录 |
| T211–T236 | 因果准备与同课题多轮历程 | `domain/model.dart`、`domain/rules.dart`、`ai/protocol.dart` | 自动回归覆盖结构/状态；语义与设备表现见逐条记录 |
| T237–T266 | 资源取舍与获得后体验 | `domain/schema.dart`、`domain/rules.dart`、`ai/protocol.dart` | 自动回归覆盖结构/状态；语义与设备表现见逐条记录 |
| T267–T292 | 人生领域与开放探索 | `domain/schema.dart`、`ai/protocol.dart`、`presentation/me_page.dart` | 自动回归覆盖结构/状态；语义与设备表现见逐条记录 |
| T293–T326 | Top5与Decisions固定量规 | `domain/ranking.dart`、`ai/decisions_gateway.dart`、`ai/pipeline.dart` | 自动回归覆盖结构/状态；语义与设备表现见逐条记录 |
| T327–T343 | 个人原则形成、采用与修订 | `domain/rules.dart`、`domain/schema.dart`、`ai/protocol.dart` | 自动回归覆盖结构/状态；语义与设备表现见逐条记录 |
| T344–T349 | 任务优势与可训练差距 | `domain/schema.dart`、`domain/rules.dart`、`ai/protocol.dart` | 自动回归覆盖结构/状态；语义与设备表现见逐条记录 |
| T350–T359 | 改变、接受与他人边界 | `domain/schema.dart`、`ai/protocol.dart`、`presentation/workbench_review.dart` | 自动回归覆盖结构/状态；语义与设备表现见逐条记录 |
| T360–T366 | 跨情境应用与综合回归 | `application/controller.dart`、`data/store.dart`、`integration/runtime.dart` | 自动回归覆盖结构/状态；语义与设备表现见逐条记录 |

## 明确的交付边界

- T230：遵照用户最新指令从头重建；旧数据库/Keystore 原样保留，新版不自动继承旧推论，也未提供旧数据自动导入。
- T234：本地数据库是唯一事实账本，没有云端数据同步；网络恢复不自动上传，用户授权后继续分析。
- T305：在线评分有原评分时间、24 小时缓存提示和旧榜单入口；来源变化先于 TTL 触发失效，改权重不刷新在线时间。真实断网/超时仍需端到端核验。
- T326：提供评价协议，没有真人效果研究结论。
- 真实模型的 50–70 条语义差异、少数算子选择、跨域反证和个体化质量仍需执行盲审。
- 真机通知、省电/重启、TalkBack、TTS 和原生 Keystore 需要执行设备矩阵；APK 编译不替代这些测试。

## 核对方法

`python3 docs/will_mirror/check_acceptance.py` 验证编号完整、原文可追溯、路径存在、没有伪造“全部通过”状态；它不判断 AI 推理质量。
