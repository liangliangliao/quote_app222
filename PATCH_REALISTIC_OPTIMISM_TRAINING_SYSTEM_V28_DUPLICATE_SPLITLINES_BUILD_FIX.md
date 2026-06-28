# v28 Duplicate `_splitLines` Build Fix

## 背景
用户上传的 Flutter release 构建日志截图显示：

- 文件：`lib/realistic_optimism_training/realistic_optimism_training_experience_pages.dart`
- 错误：`'_splitLines' is already declared in this scope.`
- 位置：约第 2352 行
- 之前声明：约第 2024 行

## 根因
v27 主流程重构时，在 `_RotCoreBusinessFlowPageState` 同一个类作用域内保留了两份同名私有方法：

```dart
List<String> _splitLines(String text) => ...
```

Dart 不允许同一作用域重复声明同名方法，因此 release 编译失败。

## 修复
1. 保留第一个 `_splitLines` 方法作为该类唯一实现。
2. 将保留版本的分隔规则统一为：换行、中文分号、英文分号、中文句号。
3. 删除后面重复声明的 `_splitLines`。
4. 确认该文件中其他 `_splitLines` 分别属于不同 State 类，不属于重复声明。

## 验证
已执行源码级检查：

```bash
grep -n "List<String> _splitLines" lib/realistic_optimism_training/realistic_optimism_training_experience_pages.dart
```

结果显示 `_RotCoreBusinessFlowPageState` 中仅剩一个 `_splitLines`。当前环境没有 `flutter` / `dart` 命令，无法执行真实 release 编译；请在本地或 CI 继续运行：

```bash
flutter clean
flutter pub get
flutter analyze
flutter build apk --release
```
