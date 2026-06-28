# PATCH_REALISTIC_POSITIVITY_OS_V4_LIFECYCLE_AND_AUDIT

本补丁继续承认并修复 V1–V3 与终极产品方案之间的差距。V3 已完成深度训练工作台，但仍然缺少真正的行动实验生命周期、逐项产品覆盖审计和对应 Prompt 配置项。本次 V4 重点补齐“行动卡之后发生什么”和“如何验证终极方案是否逐项落地”。

## 新增源码

- `lib/realistic_positivity_os/realistic_positivity_os_lifecycle_page.dart`
- `lib/realistic_positivity_os/realistic_positivity_os_coverage_audit_page.dart`

## 新增独立数据表

仍然只使用 `realistic_positivity_os_*` 命名空间，不融合其他模块。

- `realistic_positivity_os_experiments`
  - 行动卡转 7/14 天实验
  - 支持 `planned / active / needs_support / ready_review / completed / paused / recovered`
  - 保存来源行动卡、场景、ABC、价值绑定、micro action、反思问题等 plan JSON

- `realistic_positivity_os_checkins`
  - 每日行动实验 check-in
  - 记录完成动作、情绪/身体变化、comfort/stretch/panic 区间、复盘和下一步调整
  - panic 自动建议进入支持/降级状态

## DAO 新增能力

- `createExperimentFromRecord`
- `listExperiments`
- `updateExperiment`
- `addCheckIn`
- `listCheckIns`
- `coverageCounts`

## 首页新增入口

在 RPO 首页增加：

- `V4 闭环入口`
- `行动实验生命周期`
- `产品覆盖审计`

在 `12模块` 页增加：

- `V4 闭环补全：行动实验生命周期 + 产品覆盖审计`

## Prompt 配置中心新增项

已新增到 `RealisticPositivityOsPromptConfig.allIds`，可在设置页统一配置中心自由配置：

- `rpo_lifecycle_experiment_coach`：行动实验生命周期 Coach
- `rpo_coverage_audit_report`：产品设计覆盖报告

导出版本提升到 version 4。

## 产品差距修复点

- 行动卡不再是终点，可转成 7/14 天实验。
- 每个实验支持每日 check-in，而不只是记录“建议”。
- Check-in 包含区间判断，区分 comfort / stretch / panic。
- Panic Zone 会推动 `needs_support`，避免继续加压。
- 新增覆盖审计页，逐项核验终极产品方案中的功能是否有数据激活。
- 覆盖审计不再口头声称“全部完成”，而是显示：已有源码入口但待激活 / 已有数据沉淀。

## 仍需本地验证

当前 ChatGPT 容器没有 Flutter / Dart SDK，无法运行：

```bash
flutter analyze
flutter build apk
```

请本地编译，如有报错日志，继续按日志修复。
