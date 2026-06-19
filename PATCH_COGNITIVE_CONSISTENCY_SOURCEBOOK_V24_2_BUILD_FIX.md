# PATCH_COGNITIVE_CONSISTENCY_SOURCEBOOK_V24.2_BUILD_FIX

## 修复目标
根据构建日志修复：

```text
lib/cognitive_consistency/cognitive_consistency_models.dart:754:92: Error: Method not found: '_sourcebookFromRaw'.
```

## 根因
v23/v24 将 `CcPlanResult` 接入 `CcSourcebookAnalysis` 后，在 `CcPlanResult.fromJson()` 中调用了 `_sourcebookFromRaw(json['rawResponse'])`，但 `cognitive_consistency_models.dart` 内没有定义该顶层 helper，导致 release 编译失败。

## 修改内容
- 在 `lib/cognitive_consistency/cognitive_consistency_models.dart` 顶部补充：
  - `Map<String, dynamic> _sourcebookFromRaw(dynamic raw)`
- 支持解析：
  - 原始 JSON 字符串
  - ```json fenced block
  - 外层 JSON 中的 `sourcebookAnalysis` / `sourcebook_analysis` / `sourcebook` / `sourcebookCase`
- 增强 `CcSourcebookAnalysis.fromUnknown()`：
  - 传入 Map 时按原逻辑解析
  - 传入 String 时自动调用 `_sourcebookFromRaw()`，提升历史 rawResponse 兼容性

## 静态检查
已检查主要修改文件括号结构：
- `cognitive_consistency_models.dart`：圆括号/大括号/中括号平衡
- `cognitive_consistency_ai_service.dart`：圆括号/大括号/中括号平衡
- `cognitive_consistency_home_page.dart`：圆括号/大括号/中括号平衡

当前容器没有 `dart` / `flutter` 命令，无法执行真实 `flutter analyze` 或 release 编译。
