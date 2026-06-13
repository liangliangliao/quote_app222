# 足下意志 AI 统一背景提示词升级

本补丁针对“足下意志 · 行动观念训练”模块中所有 AI 调用进行了统一提示词背景升级。

## 核心改造

新增统一背景文件：

- `lib/external_data/james_will_training_prompt_context.dart`

该文件集中定义：

- `kJamesWillUnifiedBackground`
- `jamesWillSystemPrompt(...)`

所有 AI 调用都会同时在 `prompt` 和 `systemPrompt` 中注入统一背景，确保 AI 输出始终围绕威廉·詹姆斯《心理学原理》第26章“意志”的核心价值体系展开。

## 统一背景覆盖的核心思想

1. 意志不是神秘力量，而是行动观念在意识中取得主导地位。
2. 抽象目标必须转化为第一身体动作、最小行动、5分钟版本与反馈。
3. 行动观念在无强反对观念阻挡时更容易转入行动。
4. 犹豫来自行动观念、阻碍观念、逃避观念、恐惧观念、价值观念之间的竞争。
5. 决定用于终止摇摆，并区分五种决定类型。
6. AI 不替用户拍板，而是把无限犹豫转为可撤回、可复盘的小实验。
7. 努力的核心是努力性注意。
8. 快乐与痛苦需要转化为短期舒服 vs 长期力量。
9. 意志聚焦可控域，即此时此刻的第一身体动作。
10. 意志教育最终走向习惯自动化。
11. AI 负责深度思考、清晰结构、具体案例与行动引导，而非标准答案。
12. 所有建议必须务实、理性、客观、可执行。

## 已升级的 AI 调用

- 行动观念生成：`external_data.james_will.action_idea`
- 决定分析：`external_data.james_will.decision`
- 意志复盘：`external_data.james_will.review`
- 每周报告：`external_data.james_will.weekly_report`
- 语音注意力拉回：`external_data.james_will.voice_pullback`
- 7天行动实验：`external_data.james_will.stage3.experiment`
- 冲动决定冷却：`external_data.james_will.stage3.cooldown`
- 长期价值地图：`external_data.james_will.stage3.value_map`

## 修改文件

- `lib/external_data/james_will_training_prompt_context.dart`
- `lib/external_data/james_will_training_ai_service.dart`
- `lib/external_data/james_will_training_complete_ai_service.dart`
- `lib/external_data/james_will_training_stage3_ai_service.dart`
- `lib/external_data/james_will_training_complete_dao.dart`

## 说明

用户在 AI 提示词配置页面填写的附加提示词仍然生效，但统一背景现在作为硬性上层背景注入，不会因为自定义附加提示词为空或旧配置未更新而失效。
