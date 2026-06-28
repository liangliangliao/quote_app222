# V17 日常延伸闭环补全

本次基于 V16 继续修复 P2/日常延伸的关键缺口，目标不是增加更多按钮，而是让“训练结果进入日常”形成真实闭环。

## 1. Todo 桥接关系补全

`realistic_optimism_training_p2_artifacts` 增加闭环字段：

- `source_type` / `source_id`：来源类型与来源 ID，例如原 Todo。
- `target_type` / `target_id`：生成目标，例如新 Todo。
- `status`：draft / active / scheduled / completed / failed / archived。
- `scheduled_at_ms` / `completed_at_ms`。
- `dismissed_count` / `last_triggered_at_ms`。
- `linked_session_id` / `linked_record_id`。
- `safety_level` / `timezone`。

新增索引：

- `idx_rot_p2_source`
- `idx_rot_p2_target`

新增 DAO 方法：

- `findOpenDailyExtensionBySource(...)`
- `updateDailyExtensionArtifactStatus(...)`

## 2. Todo 转行动真实桥接

“把未完成 Todo 转成明日 5 分钟行动”现在会：

1. 让用户选择一个具体未完成 Todo。
2. 检查该 Todo 是否已被转化，防止重复创建。
3. 创建新的“明日 5 分钟行动”Todo。
4. 保存原 Todo ID 与新 Todo ID。
5. 保存计划时间、时区、安全等级和闭环状态。
6. 明确提示：完成后回流为行动证据，未完成进入失败免疫。

## 3. 执行结果回流

新增“同步 Todo 执行结果”：

- 如果目标 Todo 已完成：
  - P2 产物状态改为 completed。
  - 自动写入行动证据。
- 如果目标 Todo 超过计划时间仍未完成：
  - P2 产物状态改为 failed。
  - 自动写入失败免疫复盘。
  - 使用“缩小到 2 分钟”的恢复策略。

## 4. 晚间复盘真实化

“创建今晚 8 分钟复盘”现在：

- 创建带提醒的 Todo。
- 保存 target task ID、计划时间、时区。
- 提醒用户回到模块打开“真实复盘流程”。

新增按钮：

- `打开真实复盘流程`

它会进入核心 4 步训练会话，把晚间复盘真正写回事件、行动、感恩、Prime 和身份沉淀，而不是只创建提醒。

## 5. Prime 提醒环境化

“设置明日 Prime 提醒”现在：

- 使用 Todo 首选时区。
- 保存目标 Todo ID。
- 保存计划时间、时区、安全等级。
- 记录 Anti-Prime 后续策略：连续忽略后缩小行动或降低频率。

## 6. L3/L4 安全分流接入日常延伸

日常延伸按钮现在读取最近会话/记录强度：

- L3：转为稳定支持，不强行积极、不强行感恩。
- L4：暂停普通行动、Prime、感恩与失败挑战，只创建安全支持 Todo。

新增安全支持日常产物：`safety_support`。

## 7. 真实数据周报

新增“生成真实数据周报”：

- 聚合 Todo 转行动数量。
- 聚合完成回流数量。
- 聚合失败免疫数量。
- 聚合 Prime 提醒数量。
- 聚合晚间复盘数量。

周报不再只依赖 AI 生成，而是先基于真实 P2 数据聚合，再保存为 `monthly_report` 日常延伸产物。

## 8. 日常闭环状态增强

日常闭环卡新增：

- 待执行
- 已回流
- 失败免疫

并明确说明：

Todo 完成后回流为行动证据；超过计划时间仍未完成，会转入失败免疫，而不是人格失败。

## 仍需真实环境验证

当前环境没有 Flutter / Dart SDK，无法执行：

- `flutter analyze`
- `flutter test`
- `flutter build apk`

已完成源码级括号、引用和打包检查。
