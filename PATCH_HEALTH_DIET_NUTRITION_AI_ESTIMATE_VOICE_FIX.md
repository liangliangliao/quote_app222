# 健康饮食模块补丁：外部营养源 + AI 营养粗估 + 语音输入容错优化

## 解决的问题

1. 图片识别后确认页出现 0 kcal、0g 蛋白质等问题。
2. 外部营养数据源未命中时，没有借助 AI 估算能量明细。
3. 页面没有清楚区分“外部营养源”和“AI 粗估”。
4. 语音连续输入时容易漏掉前半句或只保留最后一段。

## 主要改动

### 1. 外部营养搜索增强

修改：`lib/health_diet/services/health_diet_external_api_service.dart`

- 新增中文食物到英文营养数据库关键词映射，例如：
  - 大白菜 -> napa cabbage / chinese cabbage
  - 方便面/泡面 -> instant noodles
  - 抹茶味冰淇淋 -> matcha ice cream / green tea ice cream
  - 面粉 -> wheat flour
  - 米饭 -> cooked white rice
- `searchFood()` 会对原始词和别名多轮查询 USDA / Open Food Facts。

### 2. AI 营养粗估兜底

修改：`lib/health_diet/services/health_diet_ai_bridge_service.dart`

- 新增 `estimateNutritionForFoods()`。
- 当 USDA / Open Food Facts / 国内条码接口没有命中时，AI 会基于：
  - 食物名称
  - 份量描述
  - 图片
  - 餐次
  做保守营养粗估。
- 输出热量、蛋白质、脂肪、碳水、纤维、糖、钠和可信度。
- AI 估算会保存为 `ai_nutrition_estimate`，不会伪装成权威数据库。

### 3. 核心解析链路增强

修改：`lib/health_diet/services/health_diet_core_orchestrator.dart`

- 优先调用外部营养数据库。
- 外部营养源未命中时，再调用 AI 营养粗估。
- AI 粗估结果会写入 `food_items`，供确认页、复盘、健康目标差距和下一餐动态安排使用。

### 4. 确认页展示增强

修改：`lib/health_diet/daily_share/diet_food_confirm_page.dart`

- 总计卡片新增来源区分：
  - 外部营养源
  - AI 粗估
  - 仍无数据
- 每个食物明细会显示：
  - 外部营养粗估 / AI 营养粗估
  - 估算克数
  - 热量、蛋白质、碳水、脂肪、钠
  - AI 粗估可信度和原因

### 5. 语音输入容错优化

修改：`lib/health_diet/daily_share/diet_voice_input_page.dart`

- 新增“软提交”机制：连续语音识别时，短暂停稳后先保存当前已识别内容。
- finalResult 返回后通过重叠合并去重，减少重复和漏句。
- pauseFor 从 8 秒增加到 12 秒。
- UI 文案提示用户按“早餐…中午…晚上…”分段停顿 1 秒。

## 注意

AI 营养粗估不是权威营养数据库，只用于在外部源没有命中时避免复盘全部显示 0。涉及疾病、肾脏、脂肪肝、贫血等情况时仍应提示用户遵循医生或注册营养师建议。
