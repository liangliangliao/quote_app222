# 名人名言认识论优化：P0-0 / P0-1 / P0-2

基于 2026-10-29 的 `main`：`5e34413363c73c5c65411fef662d7d9b6d89b711`。范围对应《名人名言 APP 认识论融合优化方案》v1.0 的前三项；日记 P0-3 与 P1/P2 留待后续。

## 入口与行为

- **P0-0**：阅读弹层、历史详情显示来源状态与依据。模型自评、模型返回的 `verified`、模型伪造的审核信息均不能产生“已核对出处”。解读标“一种理解”，情境标“示例 / 模拟”。
- **P0-1**：在原“阅读全文与解读”内增加默认折叠的“具体是什么样子”“相似与不同”“哪些条件下不成立”“这个解释依据什么”。木框、画芯、签名与字体布局不变；普通阅读不请求模型。
- **P0-2**：历史页点“选择比较”（或长按记录），选满两条后点“开始比较”。可跨搜索选取，最多两条，可退出。BottomSheet 保留两条原句，并展示共同点、决定性差异、不能等同之处、条件与未知。失败可重试，不阻塞原文。

## 安装后如何确认生效

1. 下载对应提交的 Android 构建产物。新的 APK 文件及 artifact 名称包含源提交号和运行序号，包内 `build-info.json` 记录源分支、源提交、实际构建提交和 Actions 链接，`SHA256SUMS` 可校验 APK。PR 的实际构建提交可能是 GitHub 生成的合并预览提交。
2. 打开底部“历史”页，搜索栏下面应出现“选择比较”。这一步不依赖 AI 配置、新名言或网络；旧记录也可以选中。选择两条并点击“开始比较”才会请求模型，首次比较需要已有全局 AI 配置。
3. 首页点画框内“阅读全文与解读”，向下滚动。所有记录都能看到来源状态和“这个解释依据什么”；画框外观按方案保持原样。
4. “具体是什么样子”“相似与不同”“哪些条件下不成立”只显示已有附属字段的内容。旧名言、CSV 导入记录和随包默认名言不会自动补写分析；要验收完整新解读，可使用原有 AI 自动获取任务生成并保存一条新名言，然后在历史详情或首页阅读中查看。
5. 退出比较再进入时应使用缓存。相同模型配置下离线重开已生成的比较也应可读；清除此比较缓存后，下一次主动比较才重新请求。

原先的 artifact 名称 `quote_app-fixed-portrait-v0.1.3-build7` 无法区分源码版本；不要用该名称或手机显示的旧版本字符串判断是否已安装本批代码。主分支是否包含功能，以 PR 合并状态和 `build-info.json` 的提交为准。

## 数据与信任边界

`lib/models/quote_insight.dart` 定义来源状态、认识状态、内容身份、关系枚举与可选附属分析。`QuoteAiService` 在原本的一次生成内返回新字段；不另发请求。缺例子时复用本次已有的实践情境，缺边界时明确“尚未明确”，不伪造限制依据。

`EpistemicSource.fromModelJson` 只接受待核对 / 有争议，丢弃模型审核信息。只有可信本地审核路径调用 `fromReviewedRecord`，提供可追溯定位、审核者、审核时间后，才可保留“已核对”状态。已有内置名言未被批量升级为已核对；此批次没有新增外部文献核验服务。来源经过核对也不使 AI 解读自动成为事实。

新增数据保存在已有 `app_kv` 中：

| 数据 | 键与有效性 |
| --- | --- |
| 附属解读 | `quote_insight.addon.<正文+作者+出处哈希>`，包含版本、实例、共同点、关键差异、边界、原句分析依据、待核对线索、来源状态 |
| 双句比较 | `quote_insight.comparison.<键哈希>`，键包含按选择顺序排列的两条 ID、各自内容哈希、供应商 / 模型 / 端点哈希 / 部署、提示词版本 |

不迁移或改写 `quotes`、`quotes_fixed`、日记或其他业务表。内容身份使附属解读在物理洗牌和固定副本间仍可读取，正文、署名或出处改变则失效。普通阅读与对比只读取当前记录，不检索日记或其他隐私模块。

缓存最多保存 100 个比较，可在结果页清除此比较缓存。同一比较的并发请求合并；缓存损坏或写入失败可降级。离线时保留原文与已缓存结果；没有缓存且 AI 不可用时提示重试。端点仅以哈希参与缓存身份，不在附属结果中保存凭据。

## 关系图选择规则

- 包含 / 交集 / 排斥：只有 `relation_scope=extension`、两组对象定义、解释理由齐全，且 A/B 的根据均能逐字定位到对应原句时才画集合图。图示明确不证明因果或普遍正确性。
- 类比 / 特征对照 / 不确定：使用原句并列卡与共同点、差异文字。
- 因果 / 条件：方向明确时显示有向关系与条件说明；因果仍标为待验证假设。
- 认识根据：方向明确时显示“判断 ← 所引依据”。缺方向时降级为文字对照。

所有比较仍为暂定解释。逐字对应只能排除编造原句根据，不能代替专家对关系语义的核对。

## 关闭与回退

分别通过构建参数关闭可选功能：

```sh
flutter build apk --release \
  --dart-define=QUOTE_READING_INSIGHTS=false \
  --dart-define=QUOTE_COMPARISON_ENABLED=false
```

来源诚实规则始终保留。回退旧程序时附属 KV 数据可以保留；原有表和原文不受影响。缺失、损坏或未知版本的附属解读按旧记录处理。

## 验证

使用仓库 CI 一致的 Flutter 3.35.3 / Dart 3.9.2：

```sh
flutter test --no-pub \
  test/quote_insight_test.dart test/quote_comparison_test.dart \
  test/quote_insight_store_test.dart test/quote_insight_widgets_test.dart \
  test/quote_insight_delivery_test.dart \
  test/quote_insight_flags_test.dart test/quote_ai_service_test.dart \
  test/quote_paper_layout_test.dart test/quote_history_avatar_test.dart \
  test/quote_ai_integration_compile_test.dart

flutter test --no-pub \
  --dart-define=QUOTE_READING_INSIGHTS=false \
  --dart-define=QUOTE_COMPARISON_ENABLED=false \
  test/quote_insight_flags_test.dart
```

以上 51 项相关测试与 1 项关闭开关测试通过。涵盖模型伪造核验、缺字段、实践复用、固定副本、原文保护、离线缓存、模型 / 内容 / 版本失效、并发合并、缓存损坏恢复、缓存上限、关系图降级、跨搜索选择、错误重试、320 宽度 / 两倍文字 / 减弱动画，以及原有 240–620 宽度画框排版与头像。

`quote_insight_delivery_test.dart` 使用真实宿主数据库、DAO、附属存储和页面入口，验证“生成结果解析 → 保存 → 实际画框阅读弹层”以及“旧/新记录 → 历史选择 → 比较 → 离线重开”。只模拟模型响应和原生平台通道；它会在 `build/quote-insight-preview/` 输出实际 Widget 渲染预览，不冒充真机截图。专用 `Quote Reading and Comparison CI` 对相关 PR 和 main 改动执行以上检查，并上传预览图。

新增模型 / 存储 / 服务 / 组件和对应测试静态检查无问题。关联旧页面中有 16 项既有 warning / info，无编译错误；不扩大本批范围清理无关告警。测试使用模拟 AI，不需要或消耗真实模型凭据。

`flutter build bundle --release --no-pub` 通过，生成 release Flutter 资源包。另运行以下命令，通过 Android arm64 的 release Dart 编译并生成 `app.dill`：

```sh
flutter assemble --output=build/quote-p0-release-kernel \
  -dTargetPlatform=android-arm64 -dBuildMode=release \
  -dTargetFile=lib/main.dart kernel_snapshot_program
```

本地 Android APK 构建曾因 `mobile_scanner` 的 AGP 8.3.2 / tools 31.3.2 Maven 下载收到 HTTP 503 而中断；同一功能提交 `7fc770c` 的 [GitHub Actions Android release 构建](https://github.com/liangliangliao/quote_app222/actions/runs/40882515709) 已成功。后续构建按提交号单独交付，当前主分支构建结果以 Actions 为准。尚未执行真机验收或真实供应商输出质量验证。

## 方案验收对应

| 要求 | 实现与可重复验证 |
| --- | --- |
| P0-0 无证不伪称核实；区分原句、解释与示例 | 模型审核字段降级、来源定位校验；模型测试、实际阅读入口测试 |
| P0-1 在原阅读入口折叠展示实例、同异、边界、依据 | 真实存储到阅读弹层测试；旧字段隐藏、失败可读测试 |
| 画框、字体、署名、正文适配保持原样 | 原有排版、头像回归；240–620 宽度覆盖 |
| P0-2 两句选择、共同点、决定性差异、不能等同、条件 | 实际历史页选择和缓存重开；跨搜索选择、最多两条、重试测试 |
| 外延才画集合；其他关系用对照或有向表达 | 关系枚举、双句原文根据校验、图表选择与降级测试 |
| 原文不改、旧记录兼容、失败和离线可读 | 真实数据库原文断言；缓存损坏、离线、身份和版本失效测试 |
| 主动操作才追加请求；不读取其他模块隐私 | 普通浏览零调用、明确开始后调用、并发去重测试；提示词审查 |
| 可关闭、可回退、小屏与文字放大 | 独立构建开关测试、320 宽度与两倍文字测试、减弱动画 |
| Dart / Widget / Android release | 本地测试、专用 CI、Android APK 构建及可追溯交付 |

以上为 P0-0～P0-2 的实现与自动化验收记录。真实手机上的安装体验和实际供应商模型输出质量需要单独实测，不将自动化通过率表述成这两项已完成。
