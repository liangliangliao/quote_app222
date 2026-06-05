# 健康饮食 Agent 前台等待与图片展示修复

## 修复点

1. 今日饮食调理页“立即让 Agent 重新安排今天饮食”不再使用重型完整托管流程。
   - 新增 `interactive` 前台快速安排模式。
   - 前台模式优先刷新 Health Connect、营养补全、本地方案和实时状态。
   - 跳过 Spoonacular / Edamam 批量抓取、AI 长文本专家叙述、AI 复盘等容易导致按钮长时间转圈的慢任务。
   - 超时从 45 秒提升到 120 秒，并对各子步骤设置独立软超时，避免单个 API 阻塞整个 Agent。

2. 健康平台返回图片后可以解析并显示。
   - Open Food Facts 食物图片：解析 `image_url`、`image_front_url`、`image_nutrition_url`、`selected_images`。
   - Spoonacular 菜谱图片：显示 `image`。
   - Edamam 菜谱图片：显示 `image` 或 `images.*.url`。

3. 图片展示位置。
   - 食物利弊查询结果卡片。
   - 条码/饮食确认页的已规范化食品卡片。
   - 菜谱搜索列表。
   - 已保存菜谱横向卡片。
   - 菜谱详情页顶部大图。
   - AI 专家分析文本中如果出现 Markdown 图片或图片 URL，也会尝试提取并横向展示。

4. 外部平台英文中文化仍由独立开关控制，避免因图片或菜谱批量结果触发大量 AI 翻译导致日志风暴和转圈。

## 关键修改文件

- `lib/health_diet/services/health_diet_autopilot_service.dart`
- `lib/health_diet/services/health_diet_app_agent_service.dart`
- `lib/health_diet/pages/today_meal_plan_page.dart`
- `lib/health_diet/models/normalized_food_item.dart`
- `lib/health_diet/repositories/food_item_repository.dart`
- `lib/health_diet/services/health_diet_external_api_service.dart`
- `lib/health_diet/pages/food_benefit_search_page.dart`
- `lib/health_diet/daily_share/diet_food_confirm_page.dart`
- `lib/health_diet/recipe/healthy_recipe_search_page.dart`
- `lib/health_diet/recipe/healthy_recipe_detail_page.dart`
- `lib/health_diet/expert/health_diet_expert_dashboard_page.dart`
