# 足下努力 / Todo 目标价值系统升级报告

## 已核对出的主要缺口

1. `足下努力`已有努力账本、Ritual Builder、关系投入、深度工作、恢复记录、AI 努力语言与 Response Paper，但 Pain-Gain、No Pain No Gain 校准、正念回归、正念专注钟还没有成为统一数据模型。
2. 原回归指标主要依赖 `returned_after_break`，不能区分分心后回来、情绪后回来、中断后回来、合理痛感中继续等不同 Return 类型。
3. 努力记录只有 zone/joy/reflection，不能区分“成长性不适”和“无意义消耗”，容易把 No Pain No Gain 误解成越痛越好。
4. 正念/冥想式努力没有和 Todo 目标、今日行动、仪式、关系投入、周复盘共用同一条努力账本。
5. AI Response Paper 没有显式读取 Pain-Gain 与 mindful return 证据。
6. `todo_goal_value_system.dart` 的中心主题与 prompt 仍偏“目标/行动/复盘”，没有把 No Pain No Gain、Pain-Gain、Return Count、Bring It Back 提升为系统价值。

## 本次改造完成内容

### 数据层

- 扩展 `goal_effort_entries`：新增 `pain_score`、`gain_score`、`pain_type`、`pain_reframe`、`return_kind`、`return_trigger`、`attention_return_count`、`mindful_minutes`、`recovery_minutes`。
- 为旧安装增加幂等迁移：`_addColumnIfMissing` 会自动补齐上述字段。
- `TodoGoalEffortEntry` 新增：Pain-Gain 象限、痛感标签、是否回归事件、是否正念练习、是否明智调整等计算属性。
- `TodoGoalEffortSummary` 新增：平均 Pain/Gain、分心后回来次数、正念练习次数、正念分钟、恢复分钟、明智调整次数、四象限计数、系统建议。

### DAO/计算层

- `addEffortEntry` 支持 Pain-Gain、痛感重构、Return 类型、正念分钟、恢复分钟。
- `getEffortSummary` 统一从努力账本计算：Return Count、Attention Return、Mindful Practice、Recovery、Pain-Gain 四象限。
- 回归不再只等于“24 小时后回来”，也包括用户显式记录的 attention/emotion/break/pain return。

### UI/交互层

- 足下努力页标题升级为：`No Pain, No Gain；No Return, No Growth`。
- 新增 `Pain-Gain Map` 卡片：展示高痛低成长、高痛高成长、低痛高成长、低痛低成长，并给出继续/降级/恢复/重查意义建议。
- 努力记录弹窗新增：Pain 分数、Gain 分数、痛感类型、Pain Reframe、Return 类型、回归触发、分心后回来次数。
- 新增 `带我回来` 按钮：将正念回归作为 effort_type=`mindful_return` 写入同一个努力账本。
- 新增 `正念专注钟` 入口：将分心后的觉察和回来作为 effort_type=`mindful_focus` 写入努力账本。
- 努力资产卡新增：分心后回来、正念练习、正念分钟、恢复分钟、明智调整。
- 历史努力列表显示 Pain/Gain 与象限，避免只看完成/未完成。

### AI/价值系统层

- `generateEffortResponsePaper` 的证据输入加入 Pain/Gain、痛感类型、象限、Pain Reframe、回归触发、分心后回来次数。
- Response Paper prompt 明确要求融合：No Pain No Gain、Pain-Gain 校准、正念式回来、仪式化行动、恢复节奏。
- `todo_goal_value_system.dart` 中心主题升级为：进入有意义的拉伸；在分心、痛苦和中断后正念回归。
- 核心价值新增：No Pain No Gain 但不迷恋痛苦、正念式回归、Pain-Gain 校准。
- 实践地图新增：带我回来、记录 Pain-Gain。
- 课程金句/产品使用新增：没有有意义的拉伸就没有真正成长；走神后回来就是练习。

## 形成的新系统闭环

Todo 任务 / 目标 → 自我一致目标 → 今日行动 → Ritual → Pain-Gain 记录 → Bring It Back / Mindful Focus → Effort Ledger → Weekly Response Paper → 下一步目标/仪式调整。

这使“足下努力”不再是孤立 Tab，而成为 Todo 目标价值系统的统一努力底层：目标、行动、仪式、关系、恢复、正念与复盘共享同一套证据和指标。
