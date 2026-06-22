# PATCH_REALISTIC_OPTIMISM_TRAINING_SYSTEM_V1

## 目标
基于最终产品设计方案，在首页左侧菜单栏新增一个完全独立模块：`现实主义乐观训练系统`。

## 关键说明
- 保留旧模块 `现实乐观信念行动系统` 不动。
- 新模块独立目录：`lib/realistic_optimism_training/`。
- 新模块独立数据库表前缀：`realistic_optimism_training_*`。
- 新模块独立 AI Prompt、DAO、Models、HomePage，不复用旧模块业务闭环。

## 已实现
1. 首页左侧菜单新增独立入口：现实主义乐观训练系统。
2. 训练仪表盘：统计事件重构、行动证据、感恩、Prime、身份沉淀、基线。
3. 10 个训练入口：今日事件重构、解释风格雷达、双镜头训练、允许自己为人、失败免疫、可控失败挑战、过程模拟、Prime、Anti-Prime、感恩品味。
4. AI 三层 Prompt：全局价值层、场景层、JSON 输出格式层。
5. 完整 JSON 闭环字段：强度分级、情绪允许、事实层、解释风格、Fault/Benefit、主动性、过程行动、失败免疫、感恩品味、Prime、身份沉淀。
6. 本地兜底生成策略：即使未配置 AI，也能生成可用训练闭环。
7. 独立数据表：records/actions/baselines/gratitude_entries/primes/identity_evidence。
8. 详情页：完整展示 0-10 步训练闭环，并支持记录行动证据。
9. 幸福基线：支持每周记录幸福感、恢复能力、可影响感、永久化频率、感恩敏感度、小行动稳定性。
10. 模块级清空：只清空本独立模块数据，不影响旧模块。

## 修改文件
- lib/main.dart
- lib/realistic_optimism_training/realistic_optimism_training_home_page.dart
- lib/realistic_optimism_training/realistic_optimism_training_models.dart
- lib/realistic_optimism_training/realistic_optimism_training_dao.dart
- lib/realistic_optimism_training/realistic_optimism_training_ai_service.dart
- lib/realistic_optimism_training/realistic_optimism_training_prompt_config.dart
