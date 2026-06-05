# 健康饮食模块编译修复：AI 中文化异步返回类型

## 修复原因

Flutter release 编译日志显示：

- `health_diet_external_api_service.dart:59:92`
- `health_diet_external_api_service.dart:153:21`
- `health_diet_external_api_service.dart:175:92`
- `health_diet_external_api_service.dart:206:92`
- `health_diet_external_api_service.dart:241:92`

错误均为：

```text
A value of type 'Object' can't be returned from an async function with return type ...
```

原因是上一版为外部健康 API 英文结果增加 AI 中文化后，在三目表达式中混用了：

```dart
Future<T>
```

和：

```dart
T
```

例如：

```dart
return enabled ? _localizeFoodItems(items) : items;
```

Dart 会把该表达式推断成 `Object`，与函数声明的 `Future<List<NormalizedFoodItem>>` / `Future<List<NormalizedRecipe>>` 不匹配。

## 修复方式

已将相关三目表达式改为显式 `if + await + return`：

```dart
if (enabled) {
  return await _localizeFoodItems(items);
}
return items;
```

涉及：

- 条码查询结果中文化
- USDA 查询结果中文化
- Open Food Facts 查询结果中文化
- Spoonacular 菜谱中文化
- Edamam 菜谱中文化

## 修改文件

```text
lib/health_diet/services/health_diet_external_api_service.dart
```
