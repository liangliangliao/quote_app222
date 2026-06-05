# 健康饮食调理模块第一阶段落地说明

## 入口

- 入口路径：发现之旅 / 生理赋能 / 饮食
- 已将原来的“饮食模块即将上线”占位页替换为 `HealthDietHomePage`。

## 第一阶段已完成

1. 模块首页
   - 营养膳食调理介绍
   - 我的健康档案入口
   - 健康饮食配置入口
   - 今日饮食调理、食物利弊查询、健康菜谱制作、扫码识别食品、健康饮食知识库等后续入口预留

2. 我的健康档案
   - 性别、年龄、身高、体重、活动量
   - 饮食调理目标
   - 健康状况
   - 忌口 / 过敏 / 饮食限制
   - 口味与烹饪偏好
   - 保存到本地 SQLite

3. 健康饮食配置
   - USDA API Key
   - Open Food Facts User-Agent
   - 薄荷健康 API Key
   - Edamam App ID / App Key
   - Spoonacular API Key
   - 默认食物数据源
   - 默认菜谱数据源
   - AI 饮食建议开关
   - 医学风险提示开关
   - Health Connect 预留开关

4. 数据库表
   - health_profiles
   - health_conditions
   - diet_restrictions
   - diet_preferences
   - food_items
   - healthy_recipes
   - recipe_steps
   - meal_plans
   - meal_plan_items
   - health_recommendation_logs

5. 服务骨架
   - HealthProfileRepository
   - HealthDietSettingsService
   - HealthRuleEngine
   - HealthDietOptions
   - HealthDietPrompts
   - NormalizedFoodItem / NormalizedRecipe
   - FoodDataSource / RecipeDataSource 抽象接口
   - FoodDataNormalizer

6. 日志
   - 打开模块会写入 `health_diet.home` 日志
   - 保存健康档案会写入 `health_diet.profile` 日志

## 后续阶段建议

第二阶段优先接入：USDA + Open Food Facts + 薄荷健康。
第三阶段接入：规则过滤 + AI 解释。
第四阶段接入：Spoonacular / Edamam 菜谱与 meal plan。
