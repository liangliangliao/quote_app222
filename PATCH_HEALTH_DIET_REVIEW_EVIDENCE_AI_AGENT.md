# 健康饮食复盘可靠性升级补丁

本补丁把“今日饮食复盘 / 根据复盘找菜谱”从简单规则复盘升级为：

- 本地规则复盘
- 外部营养数据粗估
- 复盘证据链
- 可信度评分
- 数据缺口提示
- AI 二次审查 Agent
- 复盘驱动的菜谱需求
- 自动调用在线菜谱平台保存候选菜谱

## 关键文件

### 新增/增强复盘结构

- `lib/health_diet/models/daily_diet_entry.dart`
  - `DailyDietReview` 增加：营养总量、可信度、证据链、数据缺口、菜谱需求、AI 复盘 JSON。
  - 新增 `DietReviewEvidence`。
  - 新增 `DietRecipeNeed`。

### 营养粗估和证据链

- `lib/health_diet/services/diet_food_analysis_service.dart`
  - 根据 `detected_diet_foods` + `food_items` 建立营养估算。
  - 使用 `estimated_grams / amount_text / serving_size_g` 粗估真实摄入。
  - 生成高盐、高糖、加工食品、蛋白质、膳食纤维等证据链。
  - 生成数据缺口。

### 复盘服务

- `lib/health_diet/services/daily_diet_review_service.dart`
  - 汇总饮食记录、外部营养数据、健康档案、Health Connect。
  - 计算复盘可信度：数据不足 / 基础可信 / 中等可信 / 较高可信。
  - 生成复盘驱动的 `DietRecipeNeed`。
  - 支持合并 AI 二次审查结果。

### AI 二次审查

- `lib/health_diet/services/health_diet_ai_bridge_service.dart`
  - 新增 `reviewDietWithEvidence()`。
  - AI 只能基于结构化证据链输出，不允许编造未出现的食物或健康数据。
  - 输出严格 JSON：核心问题、明日最小行动、数据缺口、菜谱需求。

### 复盘页面

- `lib/health_diet/daily_share/daily_diet_review_page.dart`
  - 打开复盘页会先生成本地复盘，再在 AI 开关开启时执行 AI 二次审查。
  - 展示可信度、营养总量粗估、复盘证据链、数据缺口、菜谱需求。
  - “根据复盘找菜谱”优先使用 `review.recipeNeeds.first.queryText`。

### 自动托管 Agent

- `lib/health_diet/services/health_diet_autopilot_service.dart`
  - 自动复盘阶段支持 AI 二次审查。
  - 复盘生成后自动根据 `recipeNeeds` 调用 Spoonacular / Edamam 并保存候选菜谱。

### 数据库

- `lib/data/db.dart`
  - `daily_nutrition_summary` 增加：
    - `confidence_score`
    - `confidence_level`
    - `evidence_json`
    - `data_gaps_json`
    - `recipe_needs_json`
    - `ai_review_json`
    - `nutrition_totals_json`
  - 增加幂等 `ALTER TABLE`，旧数据库也可自动补列。

### 保存复盘

- `lib/health_diet/repositories/daily_diet_entry_repository.dart`
  - 保存营养总量、可信度、证据链、数据缺口、菜谱需求、AI 复盘 JSON。

## 可靠性原则

1. 用户没有确认食物时，不做伪分析。
2. 没有克数时，不伪装精确热量。
3. 没有营养数据库匹配时，高盐/高糖判断主要标记为关键词证据。
4. AI 只做二次审查，不作为唯一事实来源。
5. 所有复盘问题都应能看到来源和置信度。
6. 菜谱推荐不再只靠健康目标，而是由复盘问题生成菜谱需求。

## 注意

本补丁仍然是手机 App 内置 Agent 方案，不是后端 Agent 网关。它依赖用户在设置中配置的全局 AI Provider 和健康平台 API Key。
