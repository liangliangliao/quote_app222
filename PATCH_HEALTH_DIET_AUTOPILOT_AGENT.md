# 健康饮食模块自动托管 Agent 升级说明

本次升级把原来的“本地专家方案 + 手动 AI 分析”改造成 App 内置自动托管 Agent 闭环。

## 新增能力

1. 新增 `HealthDietAutopilotService`
   - 打开 AI 营养膳食专家页时自动执行托管巡检。
   - 自动读取已授权的 Health Connect 数据。
   - 自动调用 USDA / Open Food Facts 补全食物营养数据。
   - 自动调用 Spoonacular / Edamam 搜索并缓存健康菜谱。
   - 自动生成并保存今日饮食复盘。
   - 自动生成本地专家方案。
   - 在配置允许时自动调用全局 AI Provider 生成专家分析。
   - 自动写入 Agent 任务结果、Agent 记忆、自动托管方案日志。

2. 专家页 UI 升级
   - `AI 营养膳食专家` 页面进入后自动运行托管巡检。
   - 新增“Agent 自动托管巡检”卡片。
   - 展示自动同步、自动 API、自动复盘、自动 AI 的执行结果。
   - 新增“立即巡检”按钮，可手动强制重新执行一次完整托管流程。

3. 配置页升级
   - Agent 主动等级默认改为 L4。
   - 新增自动托管开关。
   - 新增自动调用 AI 开关。
   - 新增自动调用营养/菜谱 API 开关。
   - 新增自动同步 Health Connect 开关。
   - 配置页文案已明确：API Key 仍保存在手机端，Agent 由 App 本地自动编排。

4. 数据链路增强
   - 今日饮食记录中的食物会自动尝试匹配外部营养数据并回写 `normalized_food_id`。
   - 健康菜谱会自动保存到本地菜谱表。
   - 自动生成的复盘写入 `daily_nutrition_summary`。
   - 自动托管结果写入 `health_diet_agent_plans`，source 为 `app_autopilot_agent`。
   - 自动托管执行摘要写入 `health_diet_agent_memory`。
   - 已有 `health_diet_agent_tasks` 会被自动标记为 completed，并保存 evidence/result。

5. Boohee 兜底修复
   - 如果默认食物数据源选择“薄荷健康”，但当前没有正式接口实现，系统不再空跑，而是记录日志并回退到 USDA / Open Food Facts。

## 重要边界

- 这是手机 App 内置自动托管，不是服务器后台 Agent。
- Health Connect 不会自动弹权限框；必须用户先手动授权一次，之后才能自动读取。
- 自动 AI 会消耗用户配置模型的 token / 额度，因此提供独立开关。
- 真正系统级后台定时通知还需要后续接入本地通知/后台任务插件。
