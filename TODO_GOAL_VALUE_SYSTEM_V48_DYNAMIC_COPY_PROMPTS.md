# V48 Microsoft To Do 目标实践系统：动态文案轮换 + AI 提示词统一配置

## 1. 动态文案轮换

V47 中积极环境文案只在少数固定位置出现。V48 已改为“场景化动态轮换”：

- 入口 / 实践应用页：从“享受现在、朝山顶攀登、方向化解冲突、带着愉悦做得更好、为沿途而活”中每日轮换。
- 目标转化页：围绕自我和谐、目标澄清、热爱与动力动态轮换。
- 今日旅程页：围绕过程、当下、愉悦行动、沿途体验动态轮换。
- 目标详情页：根据目标 ID 参与轮换，不同目标可看到不同提示。
- 复盘页：围绕沿途、过程、意义澄清和当下投入轮换。
- 写回 Microsoft To Do：写回任务正文中只放一条合适的“今日提示”，不再堆叠大段理论。

所有课程原文翻译文案仍保留在 `todo_goal_value_system.dart`，通过 `todoGoalQuoteForMoment(...)` 按场景调用。

## 2. AI 提示词统一配置

新增文件：

```text
lib/external_data/todo_goal_prompt_config.dart
```

新增设置项，保存到 `ms_todo_settings`：

```text
todo_goal_ai_system_prompt_v1
todo_goal_ai_task_prompt_v1
todo_goal_ai_review_prompt_v1
```

设置入口：

```text
外部数据同步 → 右上角统一配置 → To Do 目标实践系统 AI 提示词
```

可配置内容：

1. 系统提示词：控制 AI 角色、语气、输出格式。
2. 任务转目标提示词：控制 To Do 任务如何转化为方向、意义、过程价值和今日最小行动。
3. 每日复盘提示词：控制复盘如何生成过程洞察和明日最小一步。

支持占位符：

```text
{{VALUE_SYSTEM}}
{{TASK_TITLE}}
{{TASK_BODY}}
{{TASK_LIST}}
{{TASK_IMPORTANCE}}
{{TASK_DUE}}
{{TASK_STATUS}}
{{GOAL_TITLE}}
{{DEEP_MEANING}}
{{PROCESS_VALUE}}
{{ACTION_TITLE}}
{{COMPLETED_TEXT}}
{{USER_REFLECTION}}
```

## 3. 主要修改文件

```text
lib/external_data/todo_goal_value_system.dart
lib/external_data/todo_goal_prompt_config.dart
lib/external_data/todo_goal_ai_service.dart
lib/external_data/todo_goal_pages.dart
lib/external_data/onenote_pages.dart
```
