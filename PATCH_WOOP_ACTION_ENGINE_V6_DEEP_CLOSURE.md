# WOOP Action Engine V6 Deep Closure Patch

本补丁承认 V5 仍未完全覆盖最初产品设计方案，继续补齐以下缺口：

## 1. 首次引导 / Onboarding
新增 `WoopActionOnboardingPage`：
- 引导用户填写长期价值、主要生活领域、常见内在障碍。
- 保存为 WOOP 模块独立 Profile。
- 同时创建第一张 24 小时 WOOP 行动卡。
- 解决此前只有功能入口、没有真实首次体验的问题。

## 2. 行动实验室
新增 `woop_action_experiments` 数据表与 `WoopActionExperiment` 模型。
新增 `WoopActionExperimentLabPage`：
- 将 if–then 计划转化为可验证实验。
- 每个实验包含：假设、触发条件、最小行动、预期困难、状态、结果、学习。
- 支持标记“实验有效 / 未通过”。
- 实验结果会同步写入 `woop_action_plan_logs`，形成触发验证数据。

## 3. 价值校准审计
新增 `WoopActionValueAlignmentAuditPage`：
- 以用户长期价值和历史 WOOP 卡为背景，审计愿望是否仍属于用户、是否代价过高。
- 可手动将卡片标记为继续、调整、暂存、放下。
- 可生成 AI 价值校准审计卡。

## 4. 数据闭环导出
新增 `WoopActionDataExportPage` 与 DAO `fullExportJson()`：
- 导出 Profile、Cards、Reviews、Plan Logs、Daily Check-ins、Experiments。
- 只导出 `woop_action_*` 独立模块数据，不混入其他模块。

## 5. Prompt 中心继续补齐
新增并注册以下 Prompt：
- `woop_scene_onboarding`
- `woop_scene_experiment_lab`
- `woop_scene_value_alignment_audit`
- `woop_output_experiment`

这些 Prompt 已接入设置页 AI 提示词统一配置中心。

## 6. 首页集成
新增 `WoopActionDeepClosurePanel`，作为 V6 深度闭环工作台：
- 首次引导
- 行动实验室
- 价值校准审计
- 数据闭环导出

## 7. 独立模块边界
所有新增数据表、模型、DAO、Prompt ID 均使用 `woop_action_*` 或 `woop_*` 命名空间，未与已有模块融合。

## 仍未承诺 100% 完成
该版本进一步接近最初设计，但仍建议继续通过真实使用与构建日志发现缺口。请执行：

```bash
flutter analyze
flutter build apk --release
```

如出现新错误，请继续提交完整日志。
