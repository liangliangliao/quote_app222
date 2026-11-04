# PRP v1.0.0 审计与验收记录

日期：2026-11-04。开发基线：`d83386c20f8243cd0e35f5c582de03e5a1595a8c`，远端分支 `fix/schopenhauer-audit-economy-20261103`。本地分支：`feature/prp-plugin`。

## 实现边界

核心目录为 `lib/prp_plugin/`，宿主目录为 `lib/prp_plugin_host/`，既有模块通过 `prp_plugin.dart` 门面交互。详见 [接口及数据说明](lib/prp_plugin/README.md)。应用启动同步配置门面，首帧后读取设置；未增加独立后台任务或通知。

总开关默认关；敌人、行为追踪、失败模块分开关默认开，火种、首页默认关。AI、自己的名言流及录音授权默认关。AI 使用 App 已有配置，未创建密钥或发起在线模型测试。

新增持久化只涉及 `prp_lesson`、`prp_session`、`prp_recall` 以及已有 KeyValueDao 中的 `prp.*` 键。旧模块建表和护栏文件与基线的哈希对比见 [schema-guard-hashes.json](docs/prp/evidence/schema-guard-hashes.json)。失败模块双写使用既有表结构，危机退场使用既有敌人静音机制。

设置关闭会撤下会话/回访/自己的名言、取消在途写入并停止插件音频，数据保留。设置中的手册、导出、清除属于用户主动管理操作。清除仅删除 PRP 数据和插件音频，不删除已经双写到失败模块的历史学习卡。

| 接入位置 | 改动目的 |
| --- | --- |
| `lib/main.dart`、设置分区及 `settings_page.dart` | 注册门面、首帧后初始化、独立设置入口 |
| `beautiful_enemy/src/domain/enemy_engine.dart` | 开启时等待到期确认、字据完成反馈、回访关联 |
| `beautiful_enemy/src/ui/enemy_tabs.dart`、`enemy_thread_tab.dart` | 失效确认、内联会话、手册、新字据回访、安全状态刷新 |
| `beautiful_enemy_host/enemy_sources.dart` | 新增单独授权的 PRP 来源 |
| `beautiful_enemy_host/enemy_host_presence.dart`、`enemy_voice_out.dart` | PRP 会话显示期间暂停自动插话与声音 |
| `behavior_tracking/behavior_observation_presets.dart` | 显式状态反馈、未完成弹层、Flutter 回访、日复盘草稿 |
| `behavior_tracking/behavior_preset_ai_analysis_service.dart` | 授权后增加受来源约束的草稿候选 |
| `failure_module/pages/fp_practice_page.dart` | 3P 与失败复盘入口接管，保留旧表单降级 |
| `kindling/src/ui/recall_page.dart` | 仅附加已盖印的有效做法候选，不发信号 |
| `pages/home_page.dart` | 临时自己的名言、关闭立即撤下、隔离持久收藏与 AI 配画 |

## 自动化验证

环境：Flutter 3.35.3 / Dart 3.9.2，Linux，SQLite FFI，Android arm64 目标 Flutter bundle。测试使用注入时钟、本地数据库、模拟宿主与模拟 AI 输出。

| 检查 | 证据及结论 |
| --- | --- |
| 插件及宿主静态分析 | [analyze-core.log](docs/prp/evidence/analyze-core.log)；无问题 |
| 集成点静态分析 | [analyze-integrations.log](docs/prp/evidence/analyze-integrations.log)；无错误，集成文件仍有 249 条提示/警告，未在本次范围内统一清理 |
| PRP 专项测试 | [prp-tests.log](docs/prp/evidence/prp-tests.log)；83 项全部通过，覆盖状态、治理、宿主、交互、首页和图像快照 |
| 受影响旧功能回归 | [regressions.log](docs/prp/evidence/regressions.log)；48 项全部通过，包含护栏、火种红线/结构/流程、设置、首页刷新/控制 |
| 敌人和火种完整测试 | [full-regressions.log](docs/prp/evidence/full-regressions.log)；242 通过、5 失败；[失败名称逐项对照一致](docs/prp/evidence/baseline-comparison.txt) |
| 整应用 Flutter bundle | [build-bundle.log](docs/prp/evidence/build-bundle.log)；Android arm64 debug bundle 编译通过 |
| 旧库结构和护栏不变 | [schema-guard-hashes.json](docs/prp/evidence/schema-guard-hashes.json)；逐文件 SHA-256 与基线一致；另有 SQLite 建表前后比较测试 |
| 界面证据 | [8 张 Flutter 界面快照](docs/prp/screenshots/README.md)，包含深色宿主可读性及危机退场；并非手机截图 |

重点断言：开关组合无写入、关闭取消在途操作、后台时间不计入 P、未完成暂停或短按不能盖印、自责不入账、未盖印不回访、缺失数据保持未知、显式反馈幂等、历史补登不验证未来回访、改写成功后才退休旧版、AI 未授权不调用及撤回后不采纳结果、危机文字不保留、15 秒录音限制、清除撤下已显示回访、自己的名言不写 quotes/收藏。

CI 文件：[prp_plugin_ci.yml](.github/workflows/prp_plugin_ci.yml)。专项测试、静态分析、bundle、选定回归和源码打包为必过步骤。完整敌人套件沿用上游的已知失败展示方式，单独保留输出，不用它宣称全仓测试全绿。

## 上游已有失败

在未修改的基线工作树 `/tmp/prp-baseline` 上复跑了对应两个测试文件，53 项通过、以下 5 项失败；证据为 [baseline-tests.log](docs/prp/evidence/baseline-tests.log)。本次完整敌人/火种回归中的失败项与之相同。

1. `enemy_host_test.dart`：证据来源 / 行为记录不含预设打卡生成的和 AI 每日总结。
2. `enemy_host_test.dart`：AI 判词解析 / 截止时间缺失或已过期：用默认两小时，不废掉整条判词。
3. `enemy_patrol_test.dart`：主动巡查 / 发呆：这段时间里有过新记录就不点名；会话太短也不点名；后台没有会话。
4. `enemy_patrol_test.dart`：自检：它为什么没开口 / 刚上线先记起点；之后没有新动静就是没有新动静。
5. `enemy_patrol_test.dart`：自检：它为什么没开口 / 静音、静默时段、间隔、上限各有各的原因。

这些问题未混入 PRP 改动中修复，不能将本版称为全仓测试通过。

## 产品方案的适配与限制

- 设置整体原子存于 `prp.preferences.v1`，另存安全退场期限，避免多个独立键部分写入。
- 行为追踪可读近 30 天显式状态；敌人只把当前字据的显式状态作为可靠点，历史自动到期记录无法区分用户是否确认，不填充为失败。证据不足时页面明确提示。
- 敌人证据源需用户另行授权，仅同步盖印标记、引用和验证次数，不复制复盘原文，避免进入敌人自身的 AI 缓存。原文在本地手册和回访卡可见。
- AI 候选采用保守的原文来源匹配；无法对齐来源的建议会被丢弃，用户仍可手工完善和盖印。
- JSON 导出包含录音路径，不含音频二进制；录音文件不上传。
- 自己的名言仅存于首页运行时列表，不进入原有名言表、收藏、作者查询或 AI 配画。
- I5 可选痛感预测与 I6 原生提醒浮层未实现。

## 待真机验收

环境没有 Android SDK 和连接设备，本次未生成或安装 APK。Flutter bundle 编译不能代替 Gradle/native 插件构建、权限和设备测试。语音识别、录音权限/打断、触感、实际字体、文件选择器及系统返回键需在 Android 真机确认。

- [ ] 关闭总开关，敌人/行为追踪/失败模块走旧流程，无 PRP 提示；重新开启后手册仍在。
- [ ] 在三个入口触发明确未完成，分别看到对话卡片/底部弹层/全屏；默认 60 秒内没有分析控件；退到后台不计时。
- [ ] 拖拽分类、划线修订、双栏与具体动作，长按不足 3 秒不盖印，满 3 秒有印章和触感。
- [ ] 下次相关行为显示回访；完成/未挡住均只计一次；未反馈保持未验证；改写后的旧版仍可查。
- [ ] 任一文字输入中命中危机词，编辑器关闭、敌人口吻和声音停止、求助入口持续可见。
- [ ] 火种中途退出无失败提示；开启候选后只看到已盖印的有效做法。
- [ ] 失败模块历史中可见双写结果；日复盘候选留在待盖印区，不自动回访。
- [ ] AI 默认关，打开后沿用现有配置；离线/超时仍可完成全流程。
- [ ] 录音最多 15 秒，切后台和关闭开关停止；权限拒绝可继续使用文字；清除删除本地录音。
- [ ] 逐条同意自己的名言，首页印记可见且不能收藏；撤销同意或关闭后立即撤下。
- [ ] 在真实数据副本上确认旧记录完整、导出可打开、二次确认清除仅影响 PRP。

按产品方案“未过验收不合并”，本次保留为开发分支及可审查源码包，未合并主分支。
