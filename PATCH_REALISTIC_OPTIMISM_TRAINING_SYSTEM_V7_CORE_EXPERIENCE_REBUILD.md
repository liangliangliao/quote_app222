# PATCH_REALISTIC_OPTIMISM_TRAINING_SYSTEM_V7_CORE_EXPERIENCE_REBUILD

## 核心诊断

此前 V1-V6 虽然新增了独立模块、数据表、Prompt 配置中心和多个入口，但实际产品体验仍偏向“AI 内容生成器”：

- 用户填一段文本；
- AI 一次性生成结果；
- App 保存并展示卡片。

这没有真正体现最终版产品设计方案的中心思想：

> 现实主义乐观不是一次 AI 分析，而是用户逐步完成的心理训练流程。

V7 因此进行核心体验重构，不再继续堆入口，而是新增真正的产品子系统。

## 新增文件

- `lib/realistic_optimism_training/realistic_optimism_training_experience_pages.dart`

## 新增产品子系统

### 1. 今日事件重构 Wizard

新增 `RealisticOptimismEventWizardPage`。

它将“今日事件重构”拆成真实多步骤训练：

1. 事件强度分级；
2. Permission to Be Human；
3. 事实-解释分离；
4. 自动解释与解释风格；
5. 主动性层；
6. 5 分钟行动与身份证据。

关键变化：

- 不再是一个大输入框；
- 用户必须逐步参与训练；
- L3/L4 会在流程中显式提醒安全优先；
- AI 最终基于用户每一步的训练材料生成结果。

### 2. 过程模拟行动器

新增 `ProcessActionPlannerPage`。

独立收集：

- 目标/任务；
- 为什么重要；
- 最容易卡住的地方；
- 今天可投入时间；
- 当前环境干扰。

输出目标：

- 结果画面；
- 过程路径；
- 障碍预演；
- If-Then；
- 5 分钟启动动作；
- 行动证据问题。

### 3. 失败免疫实验室

新增 `FailureImmunityLabPage`，采用 3 个 Tab：

- 失败前预测；
- 失败后复盘；
- 心理抗体库。

关键变化：

- 用户不只是生成失败复盘，而是能先预测痛苦，再记录实际痛苦和恢复；
- 心理抗体形成独立可见库；
- 更贴近最终方案中的“失败前 / 失败后 / 心理抗体”结构。

### 4. Prime / Anti-Prime 环境墙

新增 `EnvironmentWallPage`，采用 2 个 Tab：

- 今日 Prime；
- Anti-Prime 清理。

关键变化：

- Prime 不再只是记录字段，而是每日环境设计；
- Anti-Prime 不再只是 AI 输出文本，而是可管理的清理对象。

### 5. 身份与能力证据墙

新增 `IdentityEvidenceWallPage`。

它按身份类型聚合记录：

- 现实主义乐观者；
- 行动证据积累者；
- 失败后恢复者；
- Benefit Finder；
- 感恩与珍惜者；
- 其他自定义身份。

核心变化：

> 身份不是口号，而是事件、行动和复盘形成的证据链。

## 首页重构

`RealisticOptimismTrainingHomePage` 修改：

- 新增“今日训练驾驶舱”；
- 顶部直接展示：
  - 最近 5 分钟行动；
  - 最近锁屏 Prime；
  - 最近身份句；
- 核心按钮直接进入真实训练子系统：
  - 重构一个事件；
  - 设计 5 分钟行动；
  - 失败免疫；
  - 设计 Prime；
  - 查看身份墙。

## 入口路由重构

`_openGuidedFlow()` 已从单一 `RotGuidedTrainingFlowPage` 改为按场景路由：

- `event_reframe/intensity_check/emotion_container/explanation_radar/dual_lens` → `RealisticOptimismEventWizardPage`
- `process_action` → `ProcessActionPlannerPage`
- `failure_immunity/controlled_failure_challenge` → `FailureImmunityLabPage`
- `prime_design/anti_prime_cleanup` → `EnvironmentWallPage`
- `identity_evidence` → `IdentityEvidenceWallPage`
- 其他低频场景仍 fallback 到旧的通用引导页

## 修复

- 修复 `realistic_optimism_training_ai_service.dart` 中重复 `final medium` 声明造成的潜在编译错误；
- 修复 `realistic_optimism_training_dao.dart` 中重复 map key；
- 更新首页文案，从 V6 调整为 V7 核心体验重构。

## 重要说明

V7 不是最终所有细节的完美实现，但它修正了最关键的方向性错误：

> 从“AI 生成分析”转向“用户逐步完成训练”。

这才更接近最终版产品设计方案的中心思想和核心价值体系。
