# 足下一致行动 V11 全闭环增强说明

本版针对上一轮审查提出的 1-8 项系统级缺口做落地增强，重点从“有入口/有方法”推进到“来源可持久化、历史可继续、报告可落入 Todo、证据可复盘、行动树可接入、AI Prompt 可配置、触发提示可见、批量状态查询可用”。

## 1. session 来源持久化
- `cc_sessions` 新增：`source_type`、`source_id`、`reward_source`、`origin_scene`。
- AI 生成方案时保存来源链路。
- 从历史 session 继续执行时，会恢复原始 Todo / 问题树 / 报告 / 行动树来源，而不是退化为 `cc_session`。
- session 也会建立 `cc_source_value_links`，支持 session ↔ value 关联。

## 2. 报告行动写入 Todo
- 行动陪伴页的“写入 Todo 行动”不再只限 Todo 来源。
- 可弹窗选择写入哪个 Todo 目标，以及写入今天/明天。
- 如果来自原 Todo step，会尽量作为其子行动写入。
- 报告生成下一步行动后会记录 `suggested_action`，执行后可记录 `adopted_evidence_id`。

## 3. 返回刷新机制增强
- `CognitiveConsistencyHomePage` 使用返回结果标记 `_changed`。
- 保存证据、写入 Todo 行动后会把 `_changed` 置为 true。
- Todo / 问题树入口使用 `Navigator.push<bool>` 接收返回结果，返回后触发重建。

## 4. 证据详情页升级为复盘页
- Todo / 问题树证据状态点击后进入“证据复盘”。
- 展示行动、分钟、难度、价值、旧解释、新解释、行动反思。
- 若有关联 AI session，会显示 AI 场景、失调点、修复动作。
- 支持继续生成下一步行动、生成复盘报告。

## 5. 多价值协同 / 冲突 AI 化
- 新增 Prompt：`cc_scene_value_relation`。
- 设置页 AI 提示词配置中心可自由编辑。
- 价值罗盘“扫描协同/冲突”优先调用 AI，失败时回退本地规则。

## 6. 行动树全域融合增强
- `concept_engine/action_engine/pages/action_execution_page.dart` 当前步骤加入：一致行动、奖励降噪、诚实校验。
- `goal_module/goal_action_runner_page.dart` 加入“一致行动辅助”卡片，支持进入一致行动、奖励降噪、诚实校验。
- 保存证据时使用 `concept_action_step` / `goal_module_action` 来源，便于证据回流和后续统计。

## 7. 智能触发提示显性化
- Todo / 问题树证据状态卡片在没有证据时提示：优先使用一致行动；反复拖延用诚实校验；过度依赖打卡/压力用奖励降噪。
- 已有多条证据时提示进入复盘，继续生成下一步或报告。

## 8. 批量证据状态查询接口
- DAO 新增 `evidenceStatusForSources()`，为页面级批量加载 source evidence 状态提供基础。
- 当前状态卡已改用统一状态查询接口；后续列表页面可进一步把多个来源一次性传入，减少 N+1 查询。

## 编译说明
当前环境没有 `flutter` / `dart` 命令，未能执行真实 Flutter 编译。已做关键文件括号平衡检查和源码级一致性检查。建议本地继续执行：

```bash
flutter pub get
flutter analyze
flutter build apk --debug
```
