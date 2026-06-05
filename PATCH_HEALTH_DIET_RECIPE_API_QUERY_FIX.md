# Health Diet Recipe API Query Fix

## Problem
The "根据复盘找菜谱" page used the Chinese goal label such as `普通健康均衡饮食` as the online recipe API keyword. Spoonacular and Edamam returned HTTP 200 but `results: []` / `hits: []` because the query was an abstract Chinese diet-goal label, not a concrete recipe/ingredient keyword.

## Fix
1. Added recipe API query normalization in `HealthDietExternalApiService.searchRecipes()`.
   - Chinese goal labels and meal suggestions are converted into concrete English recipe keywords.
   - The service fans out to up to three API-friendly queries, then deduplicates results.
2. Added `initialQuery` to `HealthyRecipeSearchPage`.
3. The daily review page now derives an initial recipe query from `DailyDietReview.nextDayAdvice` and `mainProblems`, so "根据复盘找菜谱" uses the actual review problem instead of only the broad profile goal.

## Main files changed
- `lib/health_diet/services/health_diet_external_api_service.dart`
- `lib/health_diet/recipe/healthy_recipe_search_page.dart`
- `lib/health_diet/daily_share/daily_diet_review_page.dart`
