# 火种（Kindling）v1 — 实现审计

对照《火种（Kindling）模块 — 实现方案 v1》，记录本次实现与方案的一致项与差异项。

## 基线

本次实现叠在 PR #151（`agent/belief-mentor-discover-integration` @ `29dee88`）之上，
该分支又叠在 PR #150 之上，两者当时都还没合进 `main`。发现之旅的入口顺序因此是：
写日记 → Belief Mentor → 向己两项 → 意志之镜 → **火种** → 知行树 → …

## 集成方式（与方案的主要差异）

方案 §1.1 给的集成点是「抽屉入口 + 路由注册」。本次按需求把入口放在
**发现之旅（`lib/pages/discover_page.dart`）**，其余契约不变：

| 方案 | 本次实现 |
| --- | --- |
| 抽屉 `ListTile` → `pushNamed(KindlingEntry.route)` | 发现之旅列表里的 `KindlingDiscoverEntry` 卡片 → `push(KindlingEntry.build(...))` |
| `routes: { KindlingEntry.route: ... }` | 已注册。宿主的 `Database` 是异步打开的（`AppDatabase.instance()`），所以路由指向 `KindlingHostPage`，由它等库、接追问器与提醒，再建 `KindlingEntry` |
| 导出 3 个符号 | 导出 6 个：多 `KindlingDiscoverEntry`（发现页入口卡片）与 `KindlingReminder` / `NoopKindlingReminder`（复问提醒的挂载点，不接即默认关） |

数据库迁移按方案接：`lib/data/db.dart` 的 `_create`、`_upgrade` 与每次
`openDatabase` 之后各调一次 `KindlingSchema.createAll` / `migrate`，三处都幂等。

## 与方案一致的部分

- 目录结构、文件划分与 §2 一致，另加 `src/ui/kindling_discover_entry.dart`。
- 表结构、字段、索引与 §3 逐字一致，`schemaVersion = 1`，全部 `k_` 前缀，
  无 goal / plan / deadline / streak 字段，无任何指向宿主表的外键。
- `heat()` 与 §4 的算法逐行一致（含 `verdict == 'no'` 沉底、14 天半衰期、
  `yes` 加 0.15、`clamp(0, 1.2)`）。分数只用于排序，不渲染。
- 五个页面与 §5 的交互一致：清单只显示标题；顶部没有新建入口；空清单才给
  「直接写一个」并立刻弹判别式；回溯三问一屏一问、顺序固定、可留空；第四屏
  勾选候选；判别式三选一，「不做」不删除而是移入「放掉的」；十五分钟只有一个圆
  和剩余时间，中途退出静默记 `aborted=1`，结束只问一句；阻抗只追问不给建议；
  「放掉的」只有「拿回来」。
- 文案全部集中在 `src/copy.dart`，UI 文件里没有任何中文字面量（有测试守住）。
- `KindlingOracle` / `LocalOracle` 与 §7 一致，默认离线，全程不联网。
- §8 的三个埋点写入 `k_meta`，界面不读取：`recall_sessions`、`released_count`、
  `burn_want_more_rate`。

## 宿主侧装配层（`lib/kindling_host/`，不属于模块）

模块内不得依赖 flutter/sqflite 之外的任何东西，所以凡是要用宿主能力的都放在这一层，
删掉它模块照常工作（退回离线追问器 + 不发通知）：

| 文件 | 作用 |
| --- | --- |
| `kindling_host_page.dart` | 等库、装配追问器与提醒，发现页入口与全局路由都走它 |
| `kindling_ai_oracle.dart` | 方案 §7 的 AI 追问器。system prompt 逐字照抄 §7；问句超 25 字、含禁用词、不是问句、模型不可用或抛错，一律静默退回 `LocalOracle` |
| `kindling_host_reminder.dart` | §5.3 的复问通知。用宿主已有的 Workmanager 一次性任务排 7 天，到点弹一条判别式问句；重新作答/放掉/已在应用内复问都会撤掉排期 |

通知开关在「设置」里，键 `kindling.reask_notify_enabled`，**缺省即关**，与方案一致。
关掉时只是不发通知，应用内的复问照常发生。

## 实现细节说明（方案未写死、由实现决定的部分）

0. **痒度自评的采集口**：方案 §3 把它称作「唯一的主观信号」、§4 拿它排序，但 §5 的
   五个页面里没有一屏说在哪问。本次放在长按菜单第一条「现在还痒吗」，弹出五档措辞
   （不做就难受 / 常想起 / 说不上 / 淡了 / 没感觉了），对应 4..0。界面上没有数字、
   星级或程度条，答完不给任何反馈，用户无从知道自己"打了几分"。这是长按菜单相对
   §5.1 多出的一条，其余四条与方案一致。
1. **十五分钟的圆**：按 §5.4「界面只有一个圆和剩余时间」取字面实现——一个静态
   圆环 + 中间倒计时，没有随时间收缩的进度弧，避免读成进度条。
2. **「说不准」7 天后复问**：进入模块时查一次 `itemsDueForReask`，每次会话至多
   弹一条。本地通知按方案定为可选、默认关：模块只出 `KindlingReminder` 接口
   （默认实现什么都不做），通知本身由宿主侧的 `KindlingHostReminder` 提供。
3. **中途退出不进比例的分母**：`heat()` 的 `burnTotal` 只算已作答的十五分钟。若把
   未作答的也计入，中途退出一次就等于往「不想」那边记了一笔，与 §5.4「不记为失败」
   相悖。最近一次触碰仍包含中途退出——碰过就是碰过，时间衰减照算。
4. **连续 3 次「不想」**：`consecutiveNoCount` 只看已作答的记录，未作答（中途退出）
   不打断连续性。达到 3 次时长按菜单把「放掉」置顶，不弹窗、不劝退。
5. **`released_count`** 记的是「放掉」这个动作发生的累计次数；「拿回来」不回退这个
   计数（它衡量的是判别式起没起作用）。当前在册数量另有 `releasedCount()`。
6. **手动放掉的原因**记为「手动放掉」，判别式放掉记为「判别式：不做」。
7. **底部「十五分钟」**：清单只有一条时直接进入，多于一条时先选一个；清单为空时
   按钮不可用，且不给任何提示。
7. **候选切分**：按换行 / 。/ ；切分，去掉列表前缀（`-`、`•`、`1.`），保留 2–40 字，
   去重。

## 验收清单（§10）

| 项 | 状态 | 依据 |
| --- | --- | --- |
| 全 app 断网，所有功能可用 | 通过 | 模块只依赖 flutter + sqflite，无网络调用；`kindling_red_lines_test.dart` 守住依赖面 |
| 任何页面搜不到数字型进度、连击、百分比 | 通过 | `kindling_red_lines_test.dart` 扫描全模块源码 |
| 中途退出十五分钟，无任何提示或负面反馈 | 通过 | `burn_page.dart` 在 `dispose` 里静默落库；`kindling_dao_test.dart` |
| 「不做」的火种被保留而非删除，可拿回 | 通过 | `kindling_dao_test.dart` + `kindling_flow_widget_test.dart` |
| 卸载模块后宿主正常编译 | 通过 | 集成点只有三处：`lib/data/db.dart` 三行、`discover_page.dart` 的入口卡片与 `_openKindlingFromDiscover`、以及本目录 |
| `KindlingSchema.createAll` 重复调用不报错 | 通过 | `kindling_schema_test.dart` 连调三次 |
| 无一处文案含感叹号或激励词 | 通过 | `kindling_red_lines_test.dart` |
| 数据库无任何跨模块外键指向宿主表 | 通过 | `kindling_schema_test.dart` 遍历 `PRAGMA foreign_key_list` |

## 验证方式

- `dart analyze lib/kindling test/kindling` —— 无告警。
- `flutter test test/kindling` —— 38 条用例全绿（与 `test/belief_mentor` 并行跑
  同样全绿），覆盖 schema 幂等、外键边界、
  判别式与放掉、连续「不想」、7 天复问、痒度算法、候选切分、以及清单/回溯/
  判别式/阻抗/放掉的整条交互链。
- `.github/workflows/kindling_ci.yml` —— 除分析与测试外，还有一步静态检查：模块
  不得依赖 flutter/sqflite 以外的包，也不得自己开库或引用宿主的 `AppDatabase`。

## 交付物（§11）

`tools/pack_kindling.sh` 产出 `build/kindling/kindling_v1.zip`，根目录名 `kindling_v1`，
内含模块本体、`AUDIT.md`、宿主侧装配层（`host_integration/`）与全部测试。CI 每次跑完
会把这个 zip 作为构建产物传上去；zip 是构建产物，不入库。

## 卸载方式

1. 删掉 `lib/kindling/` 与 `lib/kindling_host/`；
2. 删掉 `lib/data/db.dart` 里的 import 与三处 `KindlingSchema.*` 调用；
3. 删掉 `lib/pages/discover_page.dart` 里的 import、`KindlingDiscoverEntry`
   卡片与 `_openKindlingFromDiscover`；
4. 删掉 `lib/main.dart` 的 `routes` 中那一条、`lib/services/wm_dispatcher.dart` 的
   `KindlingHostReminder` 分支、`lib/services/notification_service.dart` 的
   `_tryNavigateKindling`、以及 `lib/pages/settings_page.dart` 里的复问通知开关。

宿主库里遗留的 `k_` 表不影响任何宿主逻辑，可留可删。
