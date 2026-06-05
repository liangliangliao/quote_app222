# BUILD FIX V15.1

本次根据 `logs_63297072312.zip` 中的 GitHub Actions 构建日志修复了以下编译失败点：

## 1. `ConceptEngineDetailPage` 参数不一致
日志报错：
- `No named parameter with the name 'recordId'`

原因：
- `ConceptEngineDetailPage` 只接受 `record`
- 多个新页面使用了 `recordId`

修复：
- `ConceptEngineDetailPage` 现在同时支持：
  - `record`
  - `recordId`
- 当只传 `recordId` 时，页面会通过 `ConceptEngineDao().getById()` 异步加载记录

## 2. `ReplayResult` 缺少 `dimensionScores`
日志报错：
- `The getter 'dimensionScores' isn't defined for the type 'ReplayResult'`

原因：
- 训练舱结算页读取了 `replay.dimensionScores`
- 但 `ReplayResult` 模型里没有该字段

修复：
- 给 `ReplayResult` 增加 `dimensionScores`
- 支持从 `dimension_scores` JSON 字段解析
- `toJson()` 同步输出该字段
- 训练舱结果页在 `dimensionScores` 为空时，会基于最终状态给出一套兜底维度分

## 3. 同类问题排查
额外做了以下排查与兜底：
- 保留所有 `recordId:` 调用点兼容，不需要再逐页改回 `record:`
- 详情页缺失记录时显示“未找到这条练习记录”，避免空崩溃

## 受影响文件
- `lib/concept_engine/concept_engine_detail_page.dart`
- `lib/concept_engine/concept_engine_models.dart`
- `lib/concept_engine/cabins/training_result_page.dart`
