# 叔本华概念图修复 · 审计 v1

基线：`feature/prp-plugin` @ `5ce4d70d`（Build Android APK #1688）。工作分支 `fix/schopenhauer-concept-graphs`。
该分支之后的 4 个提交（`dc55bbc` 等）只改测试、文档和 CI，不涉及本次文件，补丁可直接应用到最新 HEAD。

## 1 诊断（来自截图和代码）

| 现象 | 原因 |
|---|---|
| 概念树只有两条互不相连的两步链（心理能力→逆境中的韧性能力；自我认识活动→…），看不到原句的“隆冬/夏天/内心” | 现有校验只查“悬空”和类属结构，不查是否保留原句意象，也不查树是否碎成短链；提示词没有“意象→所指概念”的要求 |
| 解读停在“原句未说明这是字面季节还是隐喻” | 没有校验免责式结论 |
| 含义圈页签先给出“求职受挫”教学模拟案例 | 案例顶替了原句自己的概念（圈图本身在屏幕外，未能核对） |
| 概念星图是主题分类气泡（大小=条数，线=子主题/共现） | 不表达含义圈关系；“幸福”同名出现在两个位置 |
| 提示词（guidance v8）细则冗长 | 缺少“圈与点、是与追溯、按层数分殊相共相”这几条基本框架 |

## 2 改动

| 文件 | 内容 |
|---|---|
| `lib/epistemic/schopenhauer_circles.dart`（新） | 纯 Dart：`classifyExtensions`（由圈内个别事物判定重合/包含/相交/互斥/无依据，并生成“所有A是B/有些A是B”读法）、`GroundLayers`（概念离直观几层：殊相/共相·隔n层/悬空）、`connectedComponents` |
| `lib/epistemic/schopenhauer_guidance.dart` | 版本 8→9；开头加“读图总纲”七条（圈与点、是/追溯两个方向、按层数分殊相共相、隐喻先给正面读法、画不进圈的句子、判断力围绕目的、同名复用） |
| `lib/epistemic/semantic_scope_service.dart` | 提示词加：意象节点+metaphor 关系、含义圈含原句自身断言的判断、概念树连成一棵 |
| `lib/epistemic/reading_map_quality.dart` | 新检查：`reading.metaphor_disclaimer`（重试）、`reading.fragmented_tree`（所有分量≤3 个概念时重试）、`reading.metaphor_mapping`（缺意象节点；仅当解读已停滞时重试，否则只是提示） |
| `lib/epistemic/concept_hierarchy_view.dart` | 节点副标题显示“殊相·直接落地 / 共相·隔n层概念 / 悬空·尚无直观依据”；图例写明两个读法方向 |
| `lib/epistemic/concept_meaning_diagram.dart` | 含义圈标题下增加“读法”一行（所有A是B、有些A是B、相交不能读成“A是B”等） |
| `lib/quote_knowledge/repository.dart` | 新增 `categoryExtensions()`：每个类别含哪些名言，下位类别向上闭合 |
| `lib/quote_knowledge/constellation_view.dart` | “关系依据”面板新增“含义圈”：按已收录名言计算所选类别与其他类别的关系，附小圈图；提示同名类别 |
| `test/schopenhauer_circles_test.dart`、`test/schopenhauer_reading_checks_test.dart`、`test/quote_knowledge_circles_test.dart`（新） | 上述逻辑的测试 |

## 3 验证

做了：
- 用 Dart 3.13 对全部改动文件做语法解析，均通过。
- 纯逻辑部分用替身 `flutter_test` 实际执行：`schopenhauer_circles_test` 7 项、`schopenhauer_reading_checks_test` 5 项，全部通过。
- 用仓库里的 3 个现有夹具回归：`purposefulCase`、`winterMap`、`wangForms` 都没有新增“需重试”的问题（`purposefulCase` 只多一条提示级建议）；`semantic_json_transport_test` 用的 `wangForms` 为非隐喻材料，不受影响。
- 把截图里的输出还原成数据后，三个新检查都能抓到。

没做：
- 本环境没有 Flutter SDK，**未编译**四个界面/仓库文件的改动，也未运行 `quote_knowledge_circles_test`（依赖 sqflite_ffi）及全部既有 widget 测试。以 CI 为准。
- 未对真实模型验证提示词效果。

## 4 行为变化与风险
- guidance 版本 8→9，缓存键含版本：已保存的旧解读不再命中，打开时会按新版重新生成（消耗额度）。
- 带“字面或隐喻未说明”的旧结果现在算需修复。
- 星图面板多一次只读查询；失败时面板仍显示原有关系。
- 回滚：`git revert` 本次提交即可，无数据库结构变更。

## 5 验收步骤
1. CI 构建后打开卡缪名言，重新分析。
2. 概念树：是否含隆冬/夏天及其所指；节点副标题是否显示殊相/共相/悬空。
3. 含义圈：标题下是否有“读法”一行。
4. 历史页→概念星图→选一个类别→右上角 ⓘ：是否出现“含义圈”面板。

## 6 未完成
- 含义圈图上画出“个别经历”的点。
- 星图气泡按共有名言的重叠布局，而不是自由布局。
- 同名类别的合并入口。
- 补一个带意象节点的“新标准”夹具，再把 `reading.metaphor_mapping` 升为必须重试。
