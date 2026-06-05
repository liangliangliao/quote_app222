# 健康饮食 Agent 日志风暴与页面转圈修复

## 问题现象

1. 日志页持续刷新、清空后又出现大量 `unified_ai.translation.attempt_1`、DeepSeek 请求日志。
2. `今日饮食调理` 页点击“立即让 Agent 重新安排今天饮食”后长时间转圈。
3. `按今日调理找菜谱 / 根据复盘找菜谱` 页面长时间显示在线菜谱加载中。

## 根因

### 1. 外部 API 结果中文化复用了“AI 饮食建议”总开关

上一版代码在 USDA / Open Food Facts / Spoonacular / Edamam 返回英文后，只要 `health_diet_ai_advice_enabled = 1`，就会对每个食物名称、品牌、类别、菜谱标题、食材、步骤逐条调用 `TranslationService.translateOne()`。

这会导致一次菜谱搜索触发几十次甚至上百次 AI 翻译请求，日志页不断刷新。

### 2. 页面加载时自动补跑重型 Agent

`TodayMealPlanPage._load()` 调用 `_scheduler.tick()`，而 `tick()` 会补跑已经到点的定时任务。上午/中午/下午打开页面时，可能一次性补跑多个 slot，每个 slot 又都会执行完整 `runAutopilot()`，从而串联 Health Connect、营养 API、菜谱 API、AI 复盘、AI 专家叙述。

### 3. 自动托管在没有真实饮食记录时也用推荐词批量查营养 API

今日确认食物为 0 时，自动补全仍然会把 `recommendedFoods / limitFoods` 等通用建议词拿去查 USDA / Open Food Facts，造成无效 API 与日志。

### 4. 菜谱搜索没有防抖、没有超时兜底

搜索框每次输入都会立刻调用在线平台，多个请求并发/排队；异常或超时时 `_onlineLoading` 可能长时间为 true。

## 修复内容

1. 新增独立开关 `health_diet_external_api_ai_translation_enabled`。
   - 默认关闭。
   - 不再复用“启用 AI 个性化饮食建议”。
   - 设置页新增“外部平台英文结果用 AI 翻译”。

2. 页面加载不再自动补跑重型 Agent。
   - `TodayMealPlanPage._load()` 改为 `tick(runDue: false)`，只维护定时注册和本地方案。
   - 真正需要重型托管时，用户点击“立即让 Agent 重新安排今天饮食”。

3. 定时补跑保护。
   - `HealthDietDailySchedulerService.tick()` 新增 `runDue` 与 `maxCatchUpRuns`。
   - 默认不补跑。
   - 即使补跑也只补跑最近到点的少量任务，避免一次性执行多个 slot。

4. 自动营养补全保护。
   - 今日确认食物为 0 时，不再用通用推荐词查 USDA / Open Food Facts。
   - 用户先记录真实食物后，再做营养补全。

5. 菜谱搜索保护。
   - 增加 650ms 防抖。
   - 增加请求 token，防止旧请求覆盖新结果。
   - 增加 22 秒页面级超时兜底。
   - 外部 API 单次超时从 18/20 秒缩短到 12 秒。
   - 在线失败/超时时强制停止 loading，显示本地保底菜谱。

6. 日志降噪。
   - Workmanager 定时注册成功不再每个 slot 写日志。
   - 只有真实执行、失败、异常才写日志。

## 修改文件

- `lib/health_diet/services/health_diet_settings_service.dart`
- `lib/health_diet/pages/health_diet_settings_page.dart`
- `lib/health_diet/services/health_diet_external_api_service.dart`
- `lib/health_diet/services/health_diet_autopilot_service.dart`
- `lib/health_diet/services/health_diet_daily_scheduler_service.dart`
- `lib/health_diet/pages/today_meal_plan_page.dart`
- `lib/health_diet/recipe/healthy_recipe_search_page.dart`

## 使用建议

- 保持“外部平台英文结果用 AI 翻译”默认关闭。
- 需要少量手动查询中文化时再打开。
- 自动托管仍可自动调用 AI 做复盘/专家分析，但不再对每条外部 API 结果逐条翻译。
