# PATCH_SUSTAINABLE_EXCELLENCE_MODULE_V2_P0_P1_P2

本补丁基于 `v28_sustainable_excellence_lab_module.zip` 继续升级“可持续卓越实验室”，重点把上一轮审查发现的 P0/P1/P2 问题落地为源码能力。

## P0 已落地

1. 真正 Todo 写回
- 新增 `lib/sustainable_excellence/sustainable_excellence_todo_bridge.dart`
- 支持把实验方案、单个行动实验、失败复盘后的下一轮更小实验写入 Microsoft Todo 本地任务表。
- 写入时会创建 checklist 步骤、分类标签，并关联 `linkedTodoTaskId`。

2. Todo 详情页入口
- 修改 `lib/external_data/todo_pages.dart`
- 在 Todo 任务详情页新增“转入可持续卓越实验室”入口。
- 会把当前 Todo 标题、正文、source_task_id、source_list_id 传入可持续卓越模块。

3. 行动执行页
- 新增 `SustainableExperimentRunnerPage`
- 支持选择行动实验后进入执行页。
- 支持倒计时、开始/暂停、行动前恢复、过程锚点、行动后恢复、完成复盘、失败学习复盘。

4. 失败复盘 AI
- 扩展 `SustainableExcellenceAiService.generateFailureReview`
- 新增失败类型识别、重复失败判断、策略变量调整、下一轮更小实验、Todo 写回标题和步骤。
- AI 不可用时使用本地兜底分析。

5. 卓越螺旋状态机
- 扩展 `SustainableExcellenceCase`：`spiralStage`、`spiralCycleCount`、`lastFailureType`、`lastRecoveryAtMs`、`lastActionAtMs`、`nextRecommendedStage`。
- DAO 在新增行动证据、失败学习、恢复、过程体验、重新开始时自动推进螺旋状态。

6. 多场景 Prompt 拆分
- 扩展 `SustainableExcellencePromptConfig`
- 新增：完美主义识别、压力恢复规划、失败学习复盘、过程享受重构、每日/周度复盘 Prompt。

## P1 已落地

1. 完美主义训练器
- 新增 `SustainablePerfectionismTrainingPage`
- 包含：提交不完美版本、5分钟粗糙开始、失败预演与复盘。

2. 过程享受训练
- 新增 `SustainableProcessTrainingPage`
- 强调“不强迫快乐，只寻找 1% 的掌控/能力/意义体验”。

3. 每日复盘 / 周度报告
- 新增 `SustainableReviewPage`
- 支持生成并保存每日/周度复盘，围绕行动证据、失败模式、恢复洞察、过程体验和下一轮变量展开。

4. 单条证据删除、实验归档/删除
- 详情页支持删除单条成长证据。
- 支持归档或删除整个卓越实验。

5. 压力恢复统计扩展
- DAO 统计中新增高压力、高完美主义、活跃螺旋等数据。

## P2 已落地

1. 与现实乐观模块联动
- 在详情工具栏新增“现实乐观联动”。
- 适合用户从“我不相信自己能做到”切换到现实乐观信念行动系统。

2. 与 Todo 模块形成双向连接
- Todo 详情页可进入可持续卓越实验室。
- 可持续卓越实验室可反向写回 Todo。

3. 成长档案结构扩展
- 新增 `SustainableDailyReview`
- 证据日志扩展 `spiralStage`、`aiSummary`、`generatedTodoId`，为后续跨模块成长档案与数据导出提供基础。

## 仍需注意

当前环境未提供 flutter/dart 命令，无法执行 `flutter analyze` 或实际编译。已完成源码结构、括号配对、模块引用和压缩包完整性检查。
