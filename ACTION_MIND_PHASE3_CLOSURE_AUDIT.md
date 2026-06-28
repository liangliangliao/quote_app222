# ActionMind Phase 3 完整度补强说明

本轮针对用户指出的“源码开发实际情况并未完整实现产品设计方案，差距仍大”进行缺口审计与补强。结论：Phase 2 主要是 MVP + Prompt 配置接入，本轮开始补真实业务闭环。

## 1. 本轮承认的 Phase 2 主要缺口

- 12 个工具多数只是样例按钮，缺少用户自定义工作流记录。
- 今日驾驶舱生成结果没有成为可追踪的“今日行动卡”。
- 生活系统整合没有形成独立快照，后续 AI 难以持续读取。
- 工具运行结果没有独立表，无法统计每个核心能力是否真实使用。
- 执行意图缺少手动创建入口，过度依赖 AI 输出。
- 目标画像缺少状态流转，无法暂停、完成、归档、删除。
- 功能入口多，但行动闭环弱：生成 → 保存 → 复盘 → 上下文再利用不充分。

## 2. 新增独立数据表

仍保持模块隔离，所有新表均使用 `action_mind_*` 前缀：

- `action_mind_tool_runs`
  - 保存 12 类功能工具箱每次真实运行记录。
  - 字段包括 tool_id、scene、title、user_input、ai_response、extracted_goal、extracted_plan、next_action、status。

- `action_mind_daily_cards`
  - 保存今日行动驾驶舱生成的每日行动卡。
  - 字段包括 date_key、main_goal、emotion、energy、obstacle、if_then、minimum_action、standard_action、challenge_action、recovery_action、ai_response。

- `action_mind_life_snapshots`
  - 保存生活系统/周目标系统/目标冲突分析快照。
  - 字段包括 period_key、identity_direction、primary_goal、supporting_goals、conflict_goals、paused_goals、low_maintenance_goals、weekly_focus、ai_response。

## 3. 新增 DAO 能力

`lib/action_mind/action_mind_dao.dart` 新增：

- `insertToolRun`
- `listToolRuns`
- `insertDailyCard`
- `listDailyCards`
- `insertLifeSnapshot`
- `listLifeSnapshots`
- `updateGoalStatus`
- `deleteGoal`
- `deletePlan`

并将 tool_runs、daily_cards、life_snapshots 纳入 `recentContextJson()`，用于后续 AI 分析上下文。

## 4. 新增 UI / 交互闭环

`lib/action_mind/action_mind_home_page.dart` 新增/补强：

### 4.1 今日行动卡闭环

- 今日驾驶舱不再只生成 AI session。
- 现在会同步写入 `action_mind_daily_cards`。
- 首页展示最近一次今日行动卡，包括：
  - 主目标
  - 情绪信号
  - 能量/时间
  - 最大障碍
  - if–then
  - 最低/标准/挑战行动
  - 恢复动作

### 4.2 12 类工具真实工作流

- 工具箱按钮不再直接用固定样例跑 AI。
- 现在点击后会弹出“真实情况/补充上下文/输出深度”对话框。
- 每次生成都会保存到 `action_mind_tool_runs`。
- 工具结果会进入后续 AI 上下文。

### 4.3 功能覆盖统计

- 工具箱新增“功能覆盖与真实使用状态”。
- 12 个核心工具逐项显示使用次数。
- 用于区分“只是有入口”与“用户真实跑过工作流”。

### 4.4 执行意图手动创建

- 执行意图库新增“手动新建执行意图”。
- 支持输入：
  - 情境触发 X
  - 行为 Y
  - 障碍应对
  - 诱惑替代
  - 最低行动
  - 标准行动
  - 挑战行动
  - 环境线索

### 4.5 目标状态流转

目标卡片新增操作：

- 补执行意图
- 激活
- 暂停
- 完成
- 归档
- 删除

### 4.6 生活系统快照

- 周目标系统图、目标冲突检测现在会保存 `action_mind_life_snapshots`。
- 生活系统页展示最近一次系统快照。
- 快照包括主线目标、支持目标、冲突目标、暂停目标、低维护目标、本周焦点。

## 5. Prompt 配置状态

ActionMind 全部 Prompt 仍接入统一配置中心：

`设置 → AI 提示词统一配置中心 → ActionMind · 行动心理学引擎`

包括：

- 全局价值层 Prompt
- 12 个场景层 Prompt
- 4 个输出格式 Prompt

## 6. 仍未声称已完全等同最终商业版

本轮补强后，模块从“入口 + MVP”推进到“独立业务闭环版本”。
但仍建议后续继续补：

- 更精细的目标编辑页面，而不是仅状态按钮。
- 每个工具的专属表单字段。
- 图形化目标网络图/冲突图。
- 更完善的 AI JSON 解析与字段回填。
- 行动提醒/通知与日历联动。
- 本地统计图表与长期趋势。

