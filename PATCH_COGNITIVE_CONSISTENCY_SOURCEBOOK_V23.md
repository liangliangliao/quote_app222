# V23 Sourcebook Cognitive Consistency Stabilization Patch

- 修复 `_saveSourcebookProtectedSelfAndDefense` 缺失导致的编译级错误。
- Prompt 版本升级为 `v22_sourcebook_structured_case_engine`，用于触发从旧 V21 模板迁移。
- `CcPlanResult` 正式加入 `CcSourcebookAnalysis`，并接入 copyWith / toJson / fromJson / AI 解析 / fallback。
- `saveTriggerSuggestion` 改为同源同类型 active 建议去重更新，避免 FutureBuilder/滚动反复插入。
- Todo 自动源书提示卡持久化到 `cc_trigger_suggestions`。
- 全部源书案例改为直接查询 `cc_sourcebook_cases`，不再依赖最近 `_sessions` 列表。
- 案例详情增加下一步导航，并展示被保护自我形象、防御模式。
- 反态度实验复盘后推进案例到 `review_integration`。
- 新增 `CcSourcebookCaseListPage` 独立源书案例档案页，支持按阶段筛选并展开查看案例结构。
