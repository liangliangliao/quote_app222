# V11 compile buildfix

本次根据 `logs_74560652474.zip` 修复 Flutter release 编译失败。

## 根因

`lib/cognitive_consistency/cognitive_consistency_ai_service.dart` 的 `_localValueRelationInsight()` 中使用普通单引号字符串直接跨行：

```dart
return '【多价值协同 / 冲突扫描】
多价值组合：$values
...
${recentEvidence.trim().isEmpty ? '暂无。' : recentEvidence.trim()}';
```

Dart 普通单引号字符串不能跨行，导致编译器从第 406 行开始把后续中文内容当成代码标识符解析，于是产生大量级联错误：

- `String starting with ' must end with '`
- `The non-ASCII character ... can't be used in identifiers`
- `Expected ';' after this`
- `... isn't a type`

## 修复

改为三引号多行字符串，并提前计算 `goal` 与 `evidence` 变量，避免在多行字符串中嵌套复杂三元表达式：

```dart
final goal = userGoal.trim().isEmpty ? '当前目标' : userGoal.trim();
final evidence = recentEvidence.trim().isEmpty ? '暂无。' : recentEvidence.trim();
return '''... $goal ... $evidence''';
```

## 检查

已完成源码级检查：

- 日志中明确的直接语法根因已修复。
- 扫描 `lib/**/*.dart` 中普通单/双引号换行问题，未再发现同类未闭合字符串。
- 扫描括号 `{}`、`()`、`[]` 平衡，未发现明显不平衡。

当前容器没有 `flutter` / `dart` 命令，仍需在 CI 或本地重新执行真实构建验证。
