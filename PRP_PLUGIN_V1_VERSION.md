# PRP 插件 · 失败成长 V1（第一批）版本说明

- 分支：`feature/prp-plugin`（从 main@3a16309 拉出）
- 对应方案：《PRP 插件 产品与迭代开发方案 v2.0》
- 范围：I0 + I1 + I2 + I3 的敌人侧 + I5a（自己的名言）。**按要求不接入「行为追踪」和「失败与完美主义」。**

## 1. 它是什么

设置页里的一个可开关插件。没做到的时候，带用户“缓一缓 → 对账 → 双栏（有效 / 没起作用）→ 预警与如果—那么 → 盖印 → 拉远”，
留下一条结构化教训；之后在相似的事出现时把用户自己盖印的话摆出来，并用后续结果验证它。

入口：**设置 → 功能模块 → PRP 插件 · 失败成长**。总开关默认关闭。

## 2. 开 / 关语义

| 状态 | 行为 |
| --- | --- |
| 总开关关（默认） | 信号被忽略；插槽不渲染；不写任何数据；不新增后台任务和通知；敌人和首页与原来完全一致；数据保留，设置页仍可查看、导出、清除 |
| 总开关开、某功能关 | 该功能的信号被忽略、插槽不渲染；其他功能照常 |
| 首次开启 | 弹一次说明（做什么、不做什么、随时可关、不是治疗工具） |
| 插件异常 | 本次启动内连续 3 次内部异常 → 整体静默（熔断），诊断页可见，重启后恢复 |

## 3. 已接入的功能

| 功能 | 接入点 | 说明 |
| --- | --- | --- |
| 美丽的敌人 | 用户点“没做到”之后 | 先做复犯提示（类似的事上次盖印过什么），再打开会话页；插件接管后不再弹原有的归因弹层；关闭则走原流程 |
| 美丽的敌人 | 新建字据 | 输入框上方提示“类似的事，你上次盖印过…”（只提示；每天最多 1 次）；创建成功后把字据和相关教训挂上，之后用结果验证 |
| 美丽的敌人 | 教训页 | 顶部放“我的教训手册”（有效 / 没起作用双栏、成色、验证 / 没挡住次数、待盖印草稿、改一版） |
| 美丽的敌人 | 安全阀 | 会话里出现危机内容 → 会话退场，敌人沿用 muteFor24h(crisis: true) |
| 名人名言首页 | “换一条” | 开启该功能后，每天最多 1 次把盖印的教训作为“自己的名言”运行时混入（不写入 quotes 表） |

**未接入（设置页显示“本版本尚未接入”）：** 行为追踪、失败与完美主义（按要求先不做）、火种。

## 4. 代码改动

新增：

- `lib/prp_plugin/`：门面 `PrpPlugin`（Noop 默认）、核心（模型、设置、存储接口、治理与熔断、校验、引擎、门控）、sqflite 存储、UI（会话卡、回访提示、教训手册、设置页、印章）
- `lib/prp_plugin_host/`：`PrpHostImpl`（接敌人的护栏、静默与静音、字据数据）、敌人钩子实现、`installPrpPlugin()`
- `lib/beautiful_enemy/src/enemy_host_hooks.dart`：敌人模块自己的“失败之后”钩子接口（Noop 默认），保持敌人模块不依赖宿主
- `test/prp_plugin/`：6 个测试文件
- `.github/workflows/prp_plugin_ci.yml`：**未随本分支推送**（推送用的令牌没有 workflow 权限），文件单独提供，需要时手动加入

修改（均为小改动）：

- `lib/beautiful_enemy/beautiful_enemy.dart`：导出钩子、`SafetyValve`、`EnemyCommitment`、`CommitmentStatus`
- `lib/beautiful_enemy/src/ui/enemy_tabs.dart`：`attributeFlow` 里先问宿主是否接管；新建字据处加提示插槽和创建回调；教训页顶部加插槽
- `lib/pages/settings_page.dart`：功能模块分组里加一个入口
- `lib/main.dart`：启动时同步调用 `installPrpPlugin()`（不访问数据库、不起后台任务）
- `lib/pages/home_page.dart`：`_nextQuote` 里先向插件要“自己的名言”

## 5. 数据

插件自有表（`CREATE TABLE IF NOT EXISTS`，第一次使用时建，不改任何既有表、不走 App 迁移）：
`prp_lesson`、`prp_session`、`prp_recall`。设置存 KeyValueDao，键前缀 `prp.`。

## 6. 测试与 CI

- `test/prp_plugin/`：67 个用例（文本护栏、校验、设置、治理与熔断、引擎、门控与零痕迹）
- `prp_plugin_ci.yml`（单独提供）：`flutter analyze`（lib/prp_plugin、lib/prp_plugin_host、lib/beautiful_enemy、test/prp_plugin）+ `flutter test test/prp_plugin`
