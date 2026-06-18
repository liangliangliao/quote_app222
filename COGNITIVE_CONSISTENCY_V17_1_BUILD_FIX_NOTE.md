# 足下一致行动 V17.1 编译修复说明

## 修复问题

Flutter release 构建时报错：

- `The getter 'reductionModeCounts' isn't defined for the type 'CognitiveConsistencyDao'`
- `The getter 'verificationCounts' isn't defined for the type 'CognitiveConsistencyDao'`

## 错误原因

V17 在 `modernPatternProfile()` 返回的画像数据中新增了：

- `reductionModeCounts`
- `verificationCounts`

但只在返回 Map 中引用了这两个变量，没有在方法体内提前声明和计算，导致 Dart 将其识别为未定义 getter，从而编译失败。

## 修复内容

在 `lib/cognitive_consistency/cognitive_consistency_dao.dart` 的 `modernPatternProfile()` 中补充：

1. 从 `cc_evidence_records.dissonance_reduction_mode` 聚合解释型/行动型降低失调计数。
2. 当证据表没有相关数据时，回退从 `cc_dissonance_events.dissonance_reduction_mode` 聚合。
3. 从 `cc_verification_tasks.status` 聚合专项验证任务状态计数。
4. 额外统计逾期但仍 open 的验证任务数量。

## 影响范围

仅修复长期画像数据聚合中的未定义变量问题，不改变已有业务入口和数据结构。
