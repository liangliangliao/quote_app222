# PATCH_SUSTAINABLE_EXCELLENCE_V33_BUILD_FIX_TODO_CHECKLIST

## 修复目标

修复 Flutter release 编译错误：

```text
lib/sustainable_excellence/sustainable_excellence_todo_bridge.dart:268:82
Error: The method '_experimentsFromChecklist' isn't defined for the type 'SustainableExcellenceTodoBridge'.
```

## 原因

v32 中 `buildCaseSeedFromTodo()` 已经在 Todo 导入流程里调用：

```dart
actionExperiments: checklistSteps.isEmpty
    ? _fallbackBridgeExperiments()
    : _experimentsFromChecklist(task.title, checklistSteps),
```

但 `_experimentsFromChecklist(...)` 辅助函数没有实际定义，导致 Dart 编译失败。

## 修复内容

新增 `_experimentsFromChecklist(String goalTitle, List<String> checklistSteps)`，把 Todo checklist 转换为三类可持续卓越行动实验：

1. `todo_checklist_minimum_action`：先完成清单第一步，解决启动困难。
2. `todo_checklist_sequence_action`：按顺序推进前若干个检查项，形成节律。
3. `todo_checklist_feedback_action`：完成一个可反馈版本，避免完美主义卡住。

## 影响范围

修改文件：

```text
lib/sustainable_excellence/sustainable_excellence_todo_bridge.dart
```

该修复不改变已有数据结构，只补齐缺失函数，保证 Todo checklist 导入功能能够编译并正常生成行动实验。
