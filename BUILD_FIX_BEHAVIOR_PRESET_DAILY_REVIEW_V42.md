# V42 编译修复说明

## 修复点

GitHub Actions 报错：

```text
lib/behavior_tracking/behavior_tracking_home_page.dart:175:44: Error: The argument type 'String?' can't be assigned to the parameter type 'String'.
_openEditor(template: _templateByKey(key), ...)
```

原因是通知 payload 新增了 `type = behavior_preset_daily_review` 后，`key` 可能为 `null`，而 `_templateByKey` 参数要求非空 `String`。虽然前面做了 `key/type` 联合判断，但 Dart 不能在闭包内把 `key` 自动收窄为非空。

## 处理方式

在打开普通行为观察编辑器前新增非空安全变量：

```dart
final safeTemplateKey = key;
if (safeTemplateKey == null || safeTemplateKey.isEmpty) return;
_openEditor(template: _templateByKey(safeTemplateKey), layer: safeLayer);
```

同时复用 `safeLayer`，避免重复写 nullable 判断。

## 影响

- 修复 release 编译失败。
- 不改变每日预设行为复盘通知逻辑。
- 当 payload 只有 `type` 但没有有效 `templateKey`，且不是已识别的复盘通知时，直接忽略，避免再次触发空参数错误。
