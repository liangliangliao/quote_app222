# 健康饮食模块第五阶段实现说明

本阶段在第四阶段 Health Connect 身体状态联动基础上，继续落地“健康菜谱与购物清单”能力，让饮食建议不再停留在文字复盘，而是可以转化为用户可执行的一餐。

## 已完成能力

### 1. 健康菜谱制作入口

入口路径：

```text
发现之旅 / 生理赋能 / 饮食 / 健康菜谱制作
```

新增页面：

```text
lib/health_diet/recipe/healthy_recipe_search_page.dart
```

能力：

- 根据用户健康档案中的目标自动优先推荐菜谱。
- 支持按目标筛选：恢复体力、调理肠胃、控糖、低盐、增肌、减脂、睡眠支持等。
- 支持关键词搜索：山药、低盐、高蛋白、粥、豆腐等。
- 支持展示已保存菜谱。
- 当前使用本地健康菜谱库作为可运行 MVP，后续可接入 Spoonacular、Edamam、薄荷健康或自建菜谱服务。

### 2. 菜谱详情页

新增页面：

```text
lib/health_diet/recipe/healthy_recipe_detail_page.dart
```

能力：

- 展示菜谱标题、适合目标、预计时间、人份。
- 展示营养估算：热量、蛋白质、脂肪、碳水、钠。
- 展示食材清单。
- 展示详细制作步骤。
- 根据用户健康档案生成健康改造建议：
  - 低盐改造
  - 控糖改造
  - 高蛋白改造
  - 肠胃友好改造
  - 控重改造
  - 恢复体力改造
- 展示谨慎提示，避免把饮食建议误写成治疗方案。
- 支持保存菜谱到本地数据库。
- 支持一键生成购物清单。
- 支持将菜谱加入今日饮食记录。

### 3. 购物清单

新增页面：

```text
lib/health_diet/recipe/grocery_list_page.dart
```

新增模型：

```text
lib/health_diet/models/grocery_list.dart
```

新增仓库：

```text
lib/health_diet/repositories/grocery_list_repository.dart
```

能力：

- 从菜谱食材一键生成购物清单。
- 支持勾选已购买食材。
- 支持本地保存购物清单。
- 支持查看最近购物清单。
- 支持复制购物清单文本。
- 支持删除购物清单。

### 4. 菜谱本地持久化

新增仓库：

```text
lib/health_diet/repositories/healthy_recipe_repository.dart
```

能力：

- 保存菜谱到 `healthy_recipes` 表。
- 保存步骤到 `recipe_steps` 表。
- 支持读取最近保存菜谱。
- 当前把食材、步骤、谨慎提示存入 `raw_json`，便于不破坏原有表结构。

### 5. 本地菜谱推荐服务

新增服务：

```text
lib/health_diet/services/healthy_recipe_recommendation_service.dart
```

能力：

- 按健康目标推荐菜谱。
- 根据用户忌口做基础过滤：鸡蛋、牛奶/乳糖、海鲜、花生、素食、不吃辣等。
- 根据健康状况调整推荐权重：血压、血糖、胃肠敏感、疲劳、便秘等。
- 提供健康改造建议。
- 生成购物清单食材项。

### 6. 今日饮食复盘联动菜谱

在 `今日饮食复盘` 页面新增“根据今日复盘推荐菜谱”卡片。

用户查看复盘后，可以直接进入菜谱推荐页面，把“明天只改这一点”转化为实际可做的一餐。

### 7. 数据库新增表

在 `AppDatabase.ensureHealthDietTables()` 中新增：

```sql
CREATE TABLE IF NOT EXISTS grocery_lists (...)
CREATE TABLE IF NOT EXISTS grocery_list_items (...)
```

新增索引：

```sql
idx_grocery_lists_user
idx_grocery_list_items_list
```

## 本阶段新增文件

```text
lib/health_diet/models/grocery_list.dart
lib/health_diet/repositories/healthy_recipe_repository.dart
lib/health_diet/repositories/grocery_list_repository.dart
lib/health_diet/services/healthy_recipe_recommendation_service.dart
lib/health_diet/recipe/healthy_recipe_search_page.dart
lib/health_diet/recipe/healthy_recipe_detail_page.dart
lib/health_diet/recipe/grocery_list_page.dart
HEALTH_DIET_STAGE5_IMPLEMENTATION.md
```

## 本阶段修改文件

```text
lib/data/db.dart
lib/health_diet/pages/health_diet_home_page.dart
lib/health_diet/daily_share/daily_diet_review_page.dart
```

## 当前限制

1. 当前菜谱库为本地 MVP 示例，不依赖外部 API，因此可离线运行。
2. 营养数据为指导性估算，后续可用 USDA、薄荷健康、Edamam 或 Spoonacular 替换。
3. 当前购物清单按菜谱食材生成，不包含价格、库存和门店采购能力。
4. 当前“加入今日饮食”会把整道菜作为一条饮食记录，后续可拆成具体食材并接入营养数据库计算。

## 下一阶段建议

第六阶段建议继续开发：

- 7 天饮食习惯周报；
- 微行动任务系统；
- 饮食趋势图；
- 高糖、高盐、低蛋白、低蔬菜频率统计；
- 将微行动与菜谱推荐联动。
