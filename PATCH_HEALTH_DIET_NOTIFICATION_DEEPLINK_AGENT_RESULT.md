# 健康饮食 Agent 通知跳转与动态结果说明修复

## 修复内容

1. 通知点击不再只回到首页。
   - 支持解析旧 payload：`health_diet_agent:<slot>`。
   - 支持解析新 JSON payload：`{"type":"health_diet_agent","slot":"...","target":"..."}`。

2. 不同定时任务跳转不同页面：
   - `morning_plan` / `lunch_plan` / `snack_check` / `dinner_plan` → 今日饮食调理页。
   - `breakfast_check` → 每日饮食分享页，方便补早餐/上午记录。
   - `evening_review` → 今日饮食复盘页。
   - `weekly_report` → 长期趋势报告页。
   - 其他未知任务 → AI 营养膳食专家页。

3. 冷启动、后台点击、前台点击都尽量保留 payload 并延迟到 Navigator 可用后处理，避免通知点击丢失。

4. 通知文案明确标记为“Agent 定时巡检结果”，避免用户误解为静态模板。

## 重要说明

当前通知不是写死的纯静态数据。它来自 `HealthDietDailySchedulerService.runSlot()`：

- 到点任务触发；
- 执行 `HealthDietAutopilotService.run()`；
- 生成本轮饮食方案、微行动、菜谱方向或复盘策略；
- 再把 `plan.focusTitle` / `plan.microActionTitle` / `plan.recipeGoal` / `plan.next24hStrategy` 组合成通知。

不过，如果当天缺少饮食记录、Health Connect 未授权、营养 API 没有命中，Agent 会使用本地专家规则和兜底方案生成通知。因此它是“动态 Agent 结果 + 兜底模板”，不是完全静态文案。
