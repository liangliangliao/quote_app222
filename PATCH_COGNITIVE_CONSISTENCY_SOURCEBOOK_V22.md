# PATCH_COGNITIVE_CONSISTENCY_SOURCEBOOK_V22

本补丁在 v21 源书结构化实践闭环基础上继续落地前次审计的 P0 / P1 / P2。

## P0 落地
- 将 Prompt 版本升级为 `v21_sourcebook_structured_practice_loop`，统一 V21 UI 文案，避免 V20/V21 混用导致 Prompt 不自动迁移。
- `_analyzeDissonance()` 成功后补充 `_load()`，确保新建 sourcebook case 后立即读回认知节点、冲突边、价值分层、行动契约等数据库结构化数据。
- 对源书专项场景拆分更小的 JSON 输出格式：认知结构地图、矛盾分流、心理功能、价值分层、人际平衡、反态度实验不再强制共用超大通用 JSON，降低 AI 输出截断和解析失败风险。
- 新增源书类型边界模型：`CcSourcebookAnalysis`、`CcSourcebookCaseDetail`，为后续进一步类型化替代 raw JSON 做准备。

## P1 落地
- 认知节点和关系边的“需修正”不再只是状态标记：新增编辑弹窗，支持用户改写节点标题、节点类型、节点内容、关系类型、关系说明和修正备注。
- 选择用户路径后，如果存在 `next_action`，自动生成/更新源书行动契约，并把案例推进到 action_contract 阶段。
- 设为当前行动时，同步把行动契约状态更新为 `in_progress`。
- 行动契约新增“未完成复盘”和“调整/降级”入口，并写入学习证据账本。
- 反态度实验复盘完成后写入行动证据账本，包含旧信念、实验行动、结果、新信念与信念松动分数。
- 人际平衡行动结果写入行动证据账本，沉淀为边界/沟通实践证据。
- 源书工作台新增“开始一个完整源书案例”和“查看全部源书案例”入口，减少用户不知道从哪里开始的问题。

## P2 落地
- 新增 `cc_protected_self_images` 与 `cc_defense_pattern_records` 表，沉淀“被保护的自我形象”和“自我辩护/防御模式”。
- 源书案例详情读回并展示被保护自我形象与防御模式。
- 长期报告新增：高频被保护自我形象、高频自我辩护/防御模式、源书触发建议状态。
- 认知节点/关系边新增 `sort_order`，同一次生成的节点和边排序更稳定。
- `cc_trigger_suggestions` 增加 `status` 和 `updated_at_ms` 字段，为后续“稍后提醒/不再提示/已转化”打基础。

## 备注
当前容器无 Flutter/Dart SDK，无法执行 `flutter analyze`。已做静态括号结构检查。
