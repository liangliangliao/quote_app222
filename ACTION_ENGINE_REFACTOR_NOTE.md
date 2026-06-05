# Action Engine Refactor (local-first MVP)

This build adds a new **概念行动引擎** main path focused on:

- 概念 → 行动方向
- 行动拆解
- 行动链组装
- 执行
- 反馈

Key points:
- Normal path is the default. Friction is only handled when the user explicitly gets stuck.
- Local concept trees are included for: 责任感 / 边界感 / 自律.
- Local storage added for action plans, executions, step records, friction events and growth snapshots.
- Existing training cabin / virtual world code is kept as secondary paths.

Primary new files:
- lib/concept_engine/action_engine/models/action_engine_models.dart
- lib/concept_engine/action_engine/repository/action_engine_repository.dart
- lib/concept_engine/action_engine/repository/action_engine_dao.dart
- lib/concept_engine/action_engine/pages/action_engine_home_page.dart
- lib/concept_engine/action_engine/pages/action_concept_tree_page.dart
- lib/concept_engine/action_engine/pages/action_breakdown_page.dart
- lib/concept_engine/action_engine/pages/action_plan_builder_page.dart
- lib/concept_engine/action_engine/pages/action_execution_page.dart
- lib/concept_engine/action_engine/pages/action_feedback_page.dart
- lib/concept_engine/action_engine/pages/action_growth_page.dart

Modified:
- lib/concept_engine/concept_engine_home_page.dart
