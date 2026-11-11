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

## 7 第二轮：真机截图反馈（引用只给一边导致整条被丢）

现象：真机仍显示“部分内容返回不完整”，报错是“关系须对应本句；跨材料关系须分别引用参与材料”“连线依据须覆盖两端概念的来源”“命题缺少可定位的原文或结论”，同时缺含义圈、缺直观根据。

根因：教学案例在解析器里是单独一份“材料”（身份是案例 id）。原句概念与案例经验之间的连线、含义圈关系天然跨两份材料，而解析器要求引用同时覆盖两端。模型常只引用一边，于是整条被丢弃：含义圈没了，概念失去直观根据。这是引用形式问题，不是概念本身的问题。

修复（`lib/epistemic/semantic_scope.dart`）：
- 连线：缺哪一端的来源，就补上该端概念自己已有的原文定位，不再整条丢弃。
- 含义圈关系：放置来源按两端概念实际所在的材料校正（没有共同材料则为跨材料），引用随之补齐或过滤。
- 单句材料的命题缺定位时，以整句作依据，并给出非重试提示。
- 没有放宽的地方：摘录必须逐字出现在材料里，不符的仍然丢弃。

验证：6 个现有样本新旧解析结果逐字节一致；复现样本中旧版丢 1 条连线/3 条关系（报错与截图一致），新版保留；新增 4 个测试（在 `schopenhauer_reading_checks_test.dart`）。未经真机验证。

## 8 第三轮：为什么总是漏掉含义圈

截图里整句解读已是正面读法，只剩含义圈为空。根因在解析器：一个圈要依次通过十来道校验（放置来源、引用逐字、论域与两个概念的论域**逐字相同**、`relation_scope` 必须写 `extension`、`justification` 非空、`basis` 必须逐字出现在该关系引用的摘录中、区域成员齐全、与类属树不冲突……），任何一道不过就整圈丢弃。模型稍有偏差（论域换个说法、basis 转述一下、漏写一个常量字段）就全军覆没，所以“总是漏掉”。

修复（`semantic_scope.dart`）：由客户端补齐规范身份与协议常量，不再因格式小失误丢圈：
- 两个概念的论域相同时，圈的论域取该论域。
- 缺 `relation_scope` 补 `extension`；缺 `justification` 取关系的 `statement`。
- `basis` 不是逐字摘录时，换成该关系自己已逐字核对过的引用摘录。
- 仍然拒绝：区域成员缺失、两个概念论域不同、成员判准相同的真包含、与类属树冲突、摘录不在原文中。

界面（`semantic_scope_view.dart`）：含义圈为空时，在“补全”按钮上方直接列出每个圈未画出的原因，不必再展开折叠区。

验证：6 个现有样本新旧解析结果逐字节一致；用真实形态的输出做对照，论域写法、basis 转述、漏写 `relation_scope`、漏写 `justification` 四种小失误旧版全部丢圈，新版全部保留，缺区域和论域不同两种真缺口新旧都拒绝；新增 5 个测试。未经真机验证。
