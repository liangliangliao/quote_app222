# 行为观察模块 · 每日预设行为 AI 人类行为坐标分析 V43

本次在 V42 编译修复包基础上，继续完善“每日预设行为复盘”流程，新增自动 AI 分析能力。

## 主要改动

1. 新增每日复盘 AI 分析服务
   - 文件：`lib/behavior_tracking/behavior_preset_ai_analysis_service.dart`
   - 复盘时自动把当天所有预设行为、完成/未完成状态、未完成原因、目标值、实际值、提醒信息等组装成结构化 JSON。
   - 调用统一 AI 配置，要求 AI 只返回 JSON。
   - 支持解析代码块、纯 JSON、文本中嵌入 JSON 三种返回情况。
   - 如果未配置 API Key 或返回无法解析，会生成可保存的兜底结构，避免流程中断。

2. 新增 AI 分析结果持久化
   - 数据表：`behavior_observation_preset_ai_analyses`
   - 模型：`BehaviorPresetAiAnalysisRecord`
   - DAO 方法：
     - `savePresetAiAnalysis`
     - `presetAiAnalysisForDate`
     - `recentPresetAiAnalyses`
   - 导出 JSON 时增加 `behavior_preset_ai_analyses`。

3. 每日复盘页前端展示
   - 在“每日预设行为复盘”页面新增“AI 人类行为坐标分析”卡片。
   - 复盘保存后自动分析并保存。
   - 支持手动点击“立即分析 / 重新分析”。
   - 前端展示内容包括：
     - 总体结论
     - 人类行为坐标
     - 可靠性说明
     - 每个预设行为的常见程度、全球人数估算、概率、历史占比、是否绝无仅有、风险、难度、自我成长意义、正面价值、负面影响、罕见行为额外分析
     - 至少 10 组罕见、高风险但长期有巨大正面意义的行为案例
     - 方法说明

4. 提示词统一配置
   - 在 `GlobalAiSettings` 中新增：
     - `defaultBehaviorPresetDailyReviewAiPrompt`
     - `getBehaviorPresetDailyReviewAiPrompt`
     - `saveBehaviorPresetDailyReviewAiPrompt`
     - `inspectBehaviorPresetDailyReviewAiPromptState`
   - 在“AI 提示词设置页”新增模块：
     - 行为观察模块
     - 每日预设行为 AI 人类行为坐标分析
   - 支持统一编辑提示词，参数为 `{{review_input_json}}`。

## 说明

AI 对“人类迄今所有行为”的比较分析无法访问真实全人类完整行为数据库，因此默认提示词已经要求 AI 使用公开知识、心理学/社会学/行为科学常识、人口统计数量级进行粗略估算，并明确写出证据等级、不确定性和方法限制，避免把推测伪装成精确事实。
