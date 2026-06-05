# 健康饮食核心管线升级版编译修复

## 日志错误

GitHub Actions 日志 `logs_69626470650.zip` 中的真实错误为：

```text
lib/health_diet/recipe/healthy_recipe_search_page.dart:201:19: Error: 'await' can only be used in 'async' or 'async*' methods.
lib/health_diet/recipe/healthy_recipe_search_page.dart:222:17: Error: 'await' can only be used in 'async' or 'async*' methods.
lib/health_diet/services/diet_food_analysis_service.dart:74:45: Error: Local variable 'goodTags' can't be referenced before it is declared.
```

## 修复内容

1. `healthy_recipe_search_page.dart`
   - 将清空搜索框按钮的 `onPressed` 回调改为 `async`。
   - 将健康目标 `ChoiceChip.onSelected` 回调改为 `async`。

2. `diet_food_analysis_service.dart`
   - 将 `goodTags` 声明提前到使用前，避免先引用后声明导致 Dart 编译失败。

## 备注

当前沙盒环境没有 Flutter/Dart CLI，因此未在沙盒内运行 `flutter build`。请在 GitHub Actions 或本地重新执行：

```bash
flutter clean
flutter pub get
flutter build apk --release
```
