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
| `routes: { KindlingEntry.route: ... }` | 未注册全局路由。宿主的 `Database` 是异步打开的（`AppDatabase.instance()`），路由表拿不到实例；`KindlingEntry.route` 常量保留，宿主日后想注册可直接用 |
| 导出 3 个符号 | 导出 4 个：多一个 `KindlingDiscoverEntry`（发现页入口卡片），因为集成点在发现页 |

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

## 实现细节说明（方案未写死、由实现决定的部分）

1. **十五分钟的圆**：按 §5.4「界面只有一个圆和剩余时间」取字面实现——一个静态
   圆环 + 中间倒计时，没有随时间收缩的进度弧，避免读成进度条。
2. **「说不准」7 天后复问**：进入模块时查一次 `itemsDueForReask`，每次会话至多
   弹一条。方案里「本地通知可选，默认关」的通知未实现——模块要求零外部依赖，
   通知需要宿主的 `flutter_local_notifications`，故不引入。
3. **连续 3 次「不想」**：`consecutiveNoCount` 只看已作答的记录，未作答（中途退出）
   不打断连续性。达到 3 次时长按菜单把「放掉」置顶，不弹窗、不劝退。
4. **`released_count`** 记的是「放掉」这个动作发生的累计次数；「拿回来」不回退这个
   计数（它衡量的是判别式起没起作用）。当前在册数量另有 `releasedCount()`。
5. **手动放掉的原因**记为「手动放掉」，判别式放掉记为「判别式：不做」。
6. **底部「十五分钟」**：清单只有一条时直接进入，多于一条时先选一个；清单为空时
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

## 卸载方式

1. 删掉 `lib/kindling/`；
2. 删掉 `lib/data/db.dart` 里的 `import '../kindling/kindling.dart';` 与三处
   `KindlingSchema.*` 调用；
3. 删掉 `lib/pages/discover_page.dart` 里的 import、`KindlingDiscoverEntry`
   卡片与 `_openKindlingFromDiscover`。

宿主库里遗留的 `k_` 表不影响任何宿主逻辑，可留可删。
