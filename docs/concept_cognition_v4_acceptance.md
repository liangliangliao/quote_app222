# 概念层级、多概念含义圈与自动认识论视图

基线：PR #201 的 `codex/cognition-prototype-depth`，提交 `dd6bf22e78dfebb3855ceeaa12e4dfc1b8b6a604`。

## 阅读与概念树

在「设置 → 叔本华认知风格」开启认知模式，进入「阅读全文与解读 → 概念」。默认显示概念树，可切换「含义圈 / 相关名言」。首次分析由用户主动触发；已保存的定义、实例与 v1 分析可离线阅读。

树使用当前原文的概念身份，不借用个人念头分类中的同名节点。实线表示下位概念，虚线表示个别实例。点节点可查看定义、共同规定、省略细节、反例与逐字原文；实例可返回上位概念。全屏画布也支持节点检查。原文已有配画作为视觉类比复用，缺图时保留文字，不自动请求图片。

「相关名言」只读取本地名言及名言范围内的概念标注、分析索引和文字匹配。新分析得出的概念即使没有逐字出现在原句，也可定位到对应名言；索引标记为 AI 暂定理解。进入概念详情时携带原文、节点 ID 与分析上下文，不读写个人念头分类。

## 多概念含义圈

五种图式保留原有成员判准与区域解释，并可组合成连续的多概念画布。相同含义复用 ID，同名异义使用不同 ID；包含、相交、重合和上位分类可以共同出现。支持缩放、平移、重置、全屏及点选。

布局先合并外延重合的圆，再满足包含、相交和互斥约束，最后检验几何。矛盾或无法同时排布的关系改为相邻局部图，保留共享概念身份。未标注的关系尚未判断，圆大小不表示数量，交集不证明因果。

## 比较与其他认识论视图

A、B 与跨句理解分别保留，可通过含义圈、直观与抽象、概念树、判断力或四重根据呈现。推荐值只在该视图确有可用内容时生效，用户可以手动切换。

图三两句的验收示例使用判断力视图：A 区分追问意义与回应处境；B 区分意欲的对象与意欲活动；跨句比较讨论二者的问题和尺度。此分析是模拟模型响应，不是对作者原意的外部核验。疑问句按内容选择视图，不按标点机械分类。

根据图按四重根组织：生成根据（因果）、认识根据（判断依据）、存在根据（时间与空间）、行动根据（动机）。保持原句主张、暂定解释与实际证明的区别。

## 返回不完整、缓存与兼容

- 逐项核对原文引用、概念身份、层级类型和区域成员。坏项不会丢弃其他可用分析；格式问题最多自动修复一次，真实未知不循环重试。
- 原句不适合外延图、确实需要补充条件、模型返回不完整分别呈现。普通比较文字仍可阅读。
- 缓存纳入材料、模型、版本、判断目的、情境和焦点概念。旧请求迟到不会覆盖新材料；展开新概念不能覆盖其他节点身份。
- 使用 v2 分析契约，继续读取 v1 缓存和旧名言分析。数据沿用 `app_kv`，不修改名言正文、日记或个人分类主表。
- 模型显示名与内部缓存身份分离，界面不会显示 endpoint 指纹。

## 自动化与预览

新增 `test/cognitive_semantic_views_test.dart`，覆盖层级/实例、同名异义、四概念包含与多重相交、矛盾布局、其他视图推荐、一次修复、不同情境缓存、旧缓存、晚到请求、全屏节点检查、相关名言索引和真实阅读入口。

认知工作流已纳入新增测试，并继续运行名言、原画框布局、旧模块及关闭开关的回归。

运行：

```sh
flutter pub get
flutter analyze --no-pub lib/epistemic lib/models/quote_insight.dart lib/data/quote_insight_store.dart lib/services/quote_comparison_service.dart lib/widgets/quote_comparison_sheet.dart test/cognitive_semantic_views_test.dart
flutter test --no-pub test/cognitive_semantic_views_test.dart test/semantic_scope_test.dart test/quote_comparison_test.dart test/cognitive_widgets_test.dart test/cognitive_catalog_test.dart test/quote_insight_store_test.dart test/quote_insight_delivery_test.dart
flutter build apk --release -t lib/main.dart
```

Flutter 版本：3.35.3。CI 的 SQLite 和中文预览字体准备方式保持原有配置。

测试会生成以下截图，并随认知 CI 的 `quote-reading-comparison-previews-*` artifact 上传：

- `build/cognitive-preview/v4-reading-tree.png`
- `build/cognitive-preview/v4-meaning-network.png`
- `build/cognitive-preview/v4-comparison-judgment.png`

截图来自实际 Flutter 组件；分析内容与模型响应使用明确标记的验收样例。真实供应商输出的解释质量、已有图片的实际关联和 Android 真机手势仍需在应用中复核。

## 真机验收

1. 开启认知模式，从首页阅读入口进入概念页；分析原句，核对层级、实例、返回概念与原文摘录。
2. 进入含义圈，核对多个节点共享同一身份；缩放、全屏、点选，并尝试主动展开一个概念。
3. 比较图三的两句，检查推荐视图和可切换视图；确认不出现成排的「待确定」或配置指纹。
4. 改变判断目的与情境后重分析；断网重新打开已分析内容，确认原文与已有结果保留。
5. 关闭认知模式及概念关系图，检查既有阅读、历史比较和首页画框行为。
