# 足下努力深度融合版编译修复说明

## 报错现象

GitHub Actions / Flutter release 构建在 `lib/external_data/todo_goal_models.dart` 报错：

```text
Error: No named parameter with the name 'nodeId'.
Context: Found this candidate, but the arguments don't match.
const TodoGoalRitual({ ... })
```

## 原因

`TodoGoalRitual.fromMap` 中误混入了 `TodoGoalEffortEntry.fromMap` 才需要的字段映射：

- `nodeId`
- 重复的 `ritualId`
- `sourceObjectType`
- `stepTitle`
- `nodeTitle`

但 `TodoGoalRitual` 的构造函数本身没有这些命名参数；同时 `goal_rituals` 表也没有这些列。因此 Dart 编译器在构造 `TodoGoalRitual` 时直接失败。

## 修复

已将 `TodoGoalRitual.fromMap` 恢复为只映射 ritual 本身字段：

- `ritualId`
- `goalId`
- `triggerText`
- `minimumAction`
- `minimumMinutes`
- `rewardOrRecord`
- `environmentDesign`
- `frictionPlan`
- `stabilityScore`
- `status`
- `createdAtMs`
- `updatedAtMs`
- `goalTitle`

同时保留 `TodoGoalEffortEntry.fromMap` 的深度融合字段映射，确保足下努力记录仍然能绑定：

- 每日行动 `stepId`
- 问题树节点 `nodeId`
- 仪式 `ritualId`
- 来源类型 `sourceObjectType`
- 行动标题 `stepTitle`
- 节点标题 `nodeTitle`

## 验证

已做静态结构检查：

- 关键 Dart 文件括号/字符串闭合正常
- `TodoGoalRitual.fromMap` 不再传入未声明命名参数
- 努力账本深度融合字段未被移除

当前沙箱环境仍未安装 `dart` / `flutter`，无法本地执行 `flutter analyze` 或 release build。
