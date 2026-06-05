# 健康饮食模块：外部健康平台英文返回中文化 + USDA FoodData Central 400 修复

## 修复背景

用户反馈：

1. Spoonacular / Edamam / USDA / Open Food Facts 等健康平台返回的食物、配料、菜谱标题、制作步骤可能是英文，需要拿到返回数据后再调用 AI 翻译成中文。
2. 食物利弊查询中 USDA FoodData Central 返回 400，导致无数据：
   `dataType=Foundation,SR Legacy,Survey (FNDDS),Branded` 经 GET 查询被网关判定为 Bad Request。

## 本次改造文件

- `lib/health_diet/services/health_diet_external_api_service.dart`
- `lib/health_diet/pages/food_benefit_search_page.dart`

## 主要改造

### 1. USDA 查询从 GET + dataType 字符串改为 POST JSON 优先

原逻辑：

```text
GET /fdc/v1/foods/search?api_key=xxx&query=milk&pageSize=8&dataType=Foundation,SR Legacy,Survey (FNDDS),Branded
```

部分网关会对包含空格、括号、逗号的 `dataType` 查询参数返回 nginx 400。

新逻辑：

```text
POST /fdc/v1/foods/search?api_key=xxx
Content-Type: application/json

{
  "query": "milk",
  "pageSize": 8,
  "dataType": ["Foundation", "SR Legacy", "Survey (FNDDS)", "Branded"]
}
```

如果 POST 仍然失败或无结果，自动降级为：

```text
GET /fdc/v1/foods/search?api_key=xxx&query=milk&pageSize=8
```

即不再携带 `dataType`，避免用户 API Key 有效但页面无数据。

### 2. 外部平台英文展示字段自动调用全局 AI 翻译为中文

新增逻辑：

- USDA 食物名称、品牌、类别中文化。
- Open Food Facts 食物名称、品牌、类别、配料中文化。
- Spoonacular 菜谱标题、食材、步骤、谨慎提示中文化。
- Edamam 菜谱标题、食材、谨慎提示中文化。

翻译走已有 `TranslationService`，即继续使用 App 全局 AI Provider / Model / API Key 配置。

### 3. 尊重“AI 饮食建议”开关

如果设置中的：

```text
health_diet_ai_advice_enabled = 1
```

则外部英文字段会尽量 AI 中文化。

如果关闭该开关，则保留平台原文，避免自动增加 AI token 消耗。

### 4. 日志增强

外部 API 请求日志现在会提示：

```text
英文返回数据会在解析后尽量调用全局 AI 翻译为中文展示。
```

USDA POST 与 fallback GET 分别记录日志，方便判断到底是哪一步拿到数据。

### 5. 食物利弊查询页面提示优化

空结果不再简单提示“检查密钥或网络”，而是提示系统已经尝试：

- USDA POST 查询
- USDA 降级 GET 查询
- Open Food Facts 查询

成功结果提示英文字段会尽量 AI 翻译成中文。

## 注意

- AI 翻译只处理用户可见字段，不修改 `raw` 原始 JSON。
- 健康标签、营养数值、sourceId、barcode、URL 不翻译。
- 如果全局 AI Provider 未配置或翻译失败，会自动保留原文，不阻断 API 数据展示。
- 这次仍是源码级修改，未在当前环境运行 Flutter 编译。
