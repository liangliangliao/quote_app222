# 名人名言认识论优化：P0-0 / P0-1 / P0-2

基于 2026-10-29 的 `main`：`5e34413363c73c5c65411fef662d7d9b6d89b711`。范围对应《名人名言 APP 认识论融合优化方案》v1.0 的前三项；日记 P0-3 与 P1/P2 留待后续。

## 入口与行为

- **P0-0**：阅读弹层、历史详情显示来源状态与依据。模型自评、模型返回的 `verified`、模型伪造的审核信息均不能产生“已核对出处”。解读标“一种理解”，情境标“示例 / 模拟”。
- **P0-1**：在原“阅读全文与解读”内增加默认折叠的“具体是什么样子”“相似与不同”“哪些条件下不成立”“这个解释依据什么”。木框、画芯、签名与字体布局不变；普通阅读不请求模型。
- **P0-2**：历史页点“选择比较”（或长按记录），选满两条后点“开始比较”。可跨搜索选取，最多两条，可退出。BottomSheet 保留两条原句，并展示共同点、决定性差异、不能等同之处、条件与未知。失败可重试，不阻塞原文。

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
  test/quote_insight_flags_test.dart test/quote_ai_service_test.dart \
  test/quote_paper_layout_test.dart test/quote_history_avatar_test.dart \
  test/quote_ai_integration_compile_test.dart

flutter test --no-pub \
  --dart-define=QUOTE_READING_INSIGHTS=false \
  --dart-define=QUOTE_COMPARISON_ENABLED=false \
  test/quote_insight_flags_test.dart
```

以上 49 项相关测试与 1 项关闭开关测试通过。涵盖模型伪造核验、缺字段、实践复用、固定副本、原文保护、离线缓存、模型 / 内容 / 版本失效、并发合并、缓存损坏恢复、缓存上限、关系图降级、跨搜索选择、错误重试、320 宽度 / 两倍文字 / 减弱动画，以及原有 240–620 宽度画框排版与头像。

新增模型 / 存储 / 服务 / 组件和对应测试静态检查无问题。关联旧页面中有 16 项既有 warning / info，无编译错误；不扩大本批范围清理无关告警。测试使用模拟 AI，不需要或消耗真实模型凭据。

`flutter build bundle --release --no-pub` 通过，生成 release Flutter 资源包。另运行以下命令，通过 Android arm64 的 release Dart 编译并生成 `app.dill`：

```sh
flutter assemble --output=build/quote-p0-release-kernel \
  -dTargetPlatform=android-arm64 -dBuildMode=release \
  -dTargetFile=lib/main.dart kernel_snapshot_program
```

Android APK release 已尝试构建，但现有 `mobile_scanner` 的 AGP 8.3.2 / tools 31.3.2 Maven 依赖下载收到环境转发链路的 HTTP 503；官方地址与镜像均复现，未修改项目依赖版本来规避。需在下载链路恢复后补跑 `flutter build apk --release --no-pub`。尚未执行真机验收或真实供应商输出质量验证。
