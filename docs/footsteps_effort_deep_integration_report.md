# 足下努力 × Todo 目标价值系统深度融合升级报告

## 升级目标

本次升级不再把“足下努力”作为一个独立子模块，而是把它改造成 Todo 目标价值系统的执行证据层：目标、问题树节点、行动树步骤、每日行动、复盘、周报都共享同一套努力账本。

核心原则：每一次执行都必须能回答三件事：

1. 它属于哪个目标 / 问题节点 / 行动步骤？
2. 它产生了什么 Pain-Gain、回归、正念专注与可见证据？
3. 这些证据如何反向校准目标、节点和下一步行动？

## 数据层改造

### goal_action_steps

新增：

- `source_node_id`：每日行动与问题树节点直接绑定。

每条从问题树节点生成的每日行动都会保存来源节点，因此行动完成、失败、足下努力记录都能反向汇总到问题树。

### goal_effort_entries

新增：

- `node_id`
- `ritual_id`
- `source_object_type`
- `pain_score`
- `gain_score`
- `pain_type`
- `pain_reframe`
- `return_kind`
- `return_trigger`
- `attention_return_count`
- `mindful_minutes`
- `recovery_minutes`

努力账本现在可以明确区分来源：

- `daily_action`
- `problem_node_daily_action`
- `problem_node`
- `ritual`
- `goal`

## DAO 层改造

### 新增统一记录入口

- `recordActionEffort(...)`
- `recordProblemNodeEffort(...)`

这些方法会同时写入 effort ledger，并同步更新：

- 行动状态
- 问题树节点状态
- 目标周报证据
- Pain-Gain 汇总
- Return Count 汇总

### 查询聚合

`listActionSteps / listTodaySteps / getActionStep` 现在会为每条行动返回：

- 努力次数
- 努力分钟
- 回归次数
- 平均 Pain
- 平均 Gain
- 最近努力时间

`listProblemNodes` 现在会为每个问题树节点返回：

- 已关联每日行动数量
- 节点与关联行动的努力次数
- 努力分钟
- 回归次数
- 平均 Pain
- 平均 Gain

## UI 层融合

### 目标详情页 / 行动树

每个行动树节点现在不仅能复盘，还能直接：

- 记录努力
- 回到此步
- 正念专注

每条行动显示“足下证据”：

- Effort Count
- Effort Minutes
- Return Count
- Pain / Gain

### 今日行动页

每日行动卡片直接嵌入：

- 记录足下努力
- 带我回来
- 正念专注
- 行动与问题树/目标的连接说明

### 问题树

每个可执行问题节点可以直接记录节点努力。节点上显示：

- 已生成的今日行动数
- 节点努力记录数
- 节点努力分钟
- 节点回归次数
- 节点 Pain / Gain

### 足下努力页

足下努力页新增“今日行动 × 足下努力桥接”区块。它直接读取今日行动树，而不是让用户脱离目标系统另记一条努力。

## 复盘与 AI 周报

每日复盘会自动写入对应行动的努力账本，并继承问题树节点关系。

AI Response Paper 的输入已经包含：

- 目标
- 每日行动
- 问题树节点
- Pain-Gain
- 回归事件
- 分心后回来次数
- 正念分钟
- 仪式信息

周报会明确指出：哪些具体行动 / 问题树节点产生了真实证据。

## 完整闭环

```text
目标
→ 方案
→ 问题树
→ 可执行节点
→ 加入今日行动
→ 行动树 / 每日行动
→ 记录足下努力 / Bring It Back / 正念专注
→ Effort Ledger
→ 节点与目标聚合
→ 每日复盘
→ Weekly Response Paper
→ 调整目标、节点或下一步行动
```

## 本次改动文件

- `lib/external_data/todo_goal_models.dart`
- `lib/external_data/todo_goal_dao.dart`
- `lib/external_data/todo_goal_pages.dart`
- `lib/external_data/todo_goal_ai_service.dart`
- `lib/external_data/todo_goal_value_system.dart`

## 验证说明

当前环境未安装 Flutter / Dart SDK，因此无法执行 `dart format` 或 `flutter analyze`。已完成：

- Dart 文件括号 / 字符串感知静态平衡检查
- 关键调用点检查
- ZIP 完整性测试

