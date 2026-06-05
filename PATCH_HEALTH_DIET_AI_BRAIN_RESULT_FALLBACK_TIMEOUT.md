# 健康饮食 Agent：AI 大脑、最终结果、兜底页面与超时策略升级

## 本次目标
围绕“AI 营养膳食专家”作为整个模块的大脑中心继续改造：

- 让页面不仅显示巡检步骤，还显示“本轮最终结果”。
- 关键动态数据用不同样式突出：完成/提醒/失败、风险、可信度、确认食物、营养匹配等。
- 数据不足、API/AI 不完整时直接进入兜底托管页面，不再假装精准。
- AI 专家叙述不再 38 秒就跳过，改为更合理的前台/后台超时。
- 各健康平台 API 超时重新评估，尽量等待真实返回，但仍避免页面永久转圈。
- AI 不再只是附属解释，而是作为 Agent 的分析、判断、决策、计划与兜底大脑参与。

## 主要修改文件

- `lib/health_diet/services/health_diet_autopilot_service.dart`
- `lib/health_diet/services/health_diet_external_api_service.dart`
- `lib/health_diet/services/health_diet_expert_service.dart`
- `lib/health_diet/expert/health_diet_expert_dashboard_page.dart`
- `lib/health_diet/pages/today_meal_plan_page.dart`
- `lib/health_diet/recipe/healthy_recipe_search_page.dart`

## 核心变化

### 1. AutopilotResult 增加最终结果能力
新增：

- `okCount`
- `warningCount`
- `errorCount`
- `hasCriticalDataGap`
- `shouldShowFallback`
- `finalVerdictTitle`
- `finalVerdictMessage`
- `immediateActions`

这些字段会写入日志和 Agent 记忆，用于页面展示和后续调试。

### 2. 专家页先显示本地兜底方案，再继续巡检
`AI 营养膳食专家` 页面不再一进来就只显示大圆圈等完整巡检结束。

现在流程：

1. 先快速生成本地兜底专家方案。
2. 页面立刻展示。
3. 后台继续执行完整 Agent 巡检。
4. 巡检完成后刷新为最终方案。

### 3. 增加“本轮最终结果”卡片
专家页新增最终结果卡片，展示：

- 本轮是否完整成功。
- 是否进入兜底托管。
- 完成/提醒/失败数量。
- 风险等级。
- 数据完整度。
- 现在最该做什么。

### 4. 增加兜底托管页面
当出现这些情况时显示兜底卡片：

- 今日确认食物为 0。
- Health Connect 未授权或无有效数据。
- API/AI 多处返回不完整。
- Agent 巡检 warning 数过多。
- 有失败步骤。

兜底卡片直接给入口：

- 补饮食记录。
- 授权 Health Connect。
- 让 AI 再判断。

### 5. 今日饮食调理页增加最终结果和兜底卡片
`今日饮食调理` 不再只显示固定分餐建议，还会显示：

- 当前最终安排。
- 可信度。
- 确认食物数。
- 营养匹配数。
- 风险等级。
- 下一步重点。
- 兜底托管提示。

### 6. 超时策略调整
原先 AI 专家叙述 38 秒就跳过，过短。

调整后：

- 前台 interactive AI 专家分析：120 秒。
- 完整后台/专家页 AI 分析：180 秒。
- 手动生成 AI 专家分析：240 秒。
- 专家页完整巡检：300 秒。
- 今日饮食调理前台托管：240 秒。
- 营养平台 API 自动调用：45 秒。
- 菜谱平台 API 自动调用：60 秒。
- 复盘自动生成：90 秒。
- 单个外部健康平台 HTTP 请求：20 秒。
- 菜谱搜索页在线查询：45 秒。

### 7. AI 角色升级
AI Prompt 改为：

> 你是本功能模块的“营养专家、膳食专家、健康调理与恢复教练、Agent 总调度大脑”。

AI 需要主动完成：

- 分析。
- 判断。
- 决策。
- 计划。
- 提醒。
- 兜底。

输出结构固定：

- 最终判断。
- 依据与可信度。
- 今天最优先做的 1 件事。
- 下一餐安排。
- 今天少选/避免。
- 数据不足时的兜底方案。
- 需要用户补充的数据。
- 谨慎事项。

## 注意

本次仍是源码级改造，未在当前环境实际运行 Flutter 编译。若本地编译出现新日志，请继续按日志修复。
