# 足下意志：完整实践流程与提示词全配置升级

本次针对用户反馈继续改造：模块不再只做 AI 分析和结果呈现，而是补充“核心业务逻辑实践闭环”，并让 AI 从“替用户给答案”转为“提供结构、判断、案例、多种可能，由用户自己选择”。

## 新增实践闭环

入口：行动观念卡详情页 → **完整实践流程：由我选择实验**。

完整流程：

1. 澄清真实需要：用户先写下真正需要解决的问题、处境、限制与资源。
2. AI 打开多种可能：至少输出 3 条实践路径，每条包含适用条件、代价取舍、第一实验、参考案例。
3. 用户自主选择：用户自己选择本轮低风险实验，并写下实践承诺。
4. 执行第一身体动作：返回行动观念卡进入五分钟启动器。
5. 复盘反馈：记录真实经验，再决定继续、调小、换路径或进入 7 天封存实验。

## 新增文件

- `lib/external_data/james_will_training_practice_models.dart`
- `lib/external_data/james_will_training_practice_dao.dart`
- `lib/external_data/james_will_training_practice_ai_service.dart`
- `lib/external_data/james_will_training_practice_page.dart`

## 新增数据表

- `james_will_practice_sessions`

保存实践流程、用户真实需要、多路径选项、用户选择、实践承诺和实践反馈。

## AI 提示词升级

所有 AI 调用都统一改为可配置提示词，新增配置项：

- `unified_background`：统一核心价值体系背景
- `action_idea_prompt`：行动观念生成完整提示词
- `decision_prompt`：决定分析完整提示词
- `review_prompt`：意志复盘完整提示词
- `weekly_report_prompt`：每周报告完整提示词
- `voice_pullback_prompt`：语音注意力拉回完整提示词
- `seven_day_experiment_prompt`：7 天行动实验完整提示词
- `cooldown_prompt`：冲动决定冷却完整提示词
- `value_map_prompt`：长期价值地图完整提示词
- `practice_guide_prompt`：完整实践流程引导提示词

保留原有尾部附加提示词，同时通过 `jamesWillApplyTemplate` 追加默认输出结构和 JSON schema，避免用户配置后破坏结构化输出。

## AI 行为约束

所有提示词都强调：

- 不直接替用户做选择。
- 不输出唯一标准答案。
- 先澄清真实需要，再提供多种可能。
- 给出明确判断框架、适用条件、代价、风险、案例和低风险实验。
- 最终由用户自己判断和选择。
- 目标必须进入行动观念、第一身体动作、最小行动、实践反馈。

