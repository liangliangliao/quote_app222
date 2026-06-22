# PATCH_REALISTIC_OPTIMISM_TRAINING_SYSTEM_V5

## 目标
继续按最终版产品设计方案做第五轮完整性核对，补齐 V4 中仍偏“生成式落地”或“缺少独立沉淀/管理视图”的部分。

## 本轮核对结论
V4 已覆盖独立模块、入口、Prompt 配置、基础数据和生成后复盘，但仍有以下缺口：

1. 事件强度分级只存在于主记录与 payload 中，缺少独立强度分级表。
2. 过程模拟行动器只展示在详情中，缺少独立过程计划表，无法独立统计/审计。
3. Prime、Anti-Prime、关系感恩缺少集中管理视图与复用入口。
4. L3/L4 高强度/安全风险事件缺少显式详情安全支持卡，容易被误解为仍可继续普通训练。
5. 关系感恩表达生成后缺少复制复用操作。

## 新增/完善

### 1. 独立事件强度分级表
新增表：
- `realistic_optimism_training_event_intensity`

字段：
- `record_id`
- `level`
- `reason`
- `allowed_interventions_json`
- `blocked_interventions_json`
- `created_at_ms`

每次生成训练记录后自动沉淀。

### 2. 独立过程行动计划表
新增表：
- `realistic_optimism_training_process_plans`

字段：
- `record_id`
- `five_minute_action`
- `next_three_steps_json`
- `if_then_plan_json`
- `created_at_ms`

用于把“过程模拟行动器”从详情展示升级为可统计的长期训练资产。

### 3. 新增“环境/表达”Tab
新增集中管理视图：
- Prime 启动线索库
- Anti-Prime 清理记录
- 关系感恩表达库
- 事件强度分级沉淀
- 过程行动计划沉淀

支持从该 Tab 快速进入：
- AI 设计 Prime
- AI 清理 Anti-Prime
- 新增关系感恩表达

### 4. 关系感恩表达可复制
关系表达库中三类文案支持复制：
- 轻量版
- 具体版
- 深度版

### 5. L3/L4 安全支持卡
训练详情页新增安全分流卡：
- L3：高强度痛苦，先稳定，不强行找好处。
- L4：安全优先，暂停普通训练流程，提示寻求现实紧急支持。

### 6. 统计与审计增强
`RealisticOptimismTrainingStats` 新增：
- `eventIntensity`
- `processPlans`

首页指标和功能完整度审计卡同步展示。

## 修改文件
- `lib/realistic_optimism_training/realistic_optimism_training_home_page.dart`
- `lib/realistic_optimism_training/realistic_optimism_training_dao.dart`
- `lib/realistic_optimism_training/realistic_optimism_training_models.dart`

## 注意
当前容器环境没有 dart/flutter 命令，无法执行真实 `flutter analyze` 或编译。已做源码级括号/引用/基础一致性检查。
