# PATCH_REALISTIC_POSITIVITY_OS_V1

本补丁基于上传源码新增独立模块：`真实积极行动系统 · Realistic Positivity OS`。

## 独立模块边界

- 新增目录：`lib/realistic_positivity_os/`
- 新增数据表均以 `realistic_positivity_os_*` 命名。
- 新增 KV Key：`realistic_positivity_os_profile_v1`。
- 未改造、未融合、未复用其他模块的领域模型与业务流程。
- 仅在 `lib/main.dart` 侧栏入口新增一个独立导航项。

## 新增文件

- `realistic_positivity_os_prompt_config.dart`
  - 全局价值层 Prompt
  - 场景层 Prompt
  - 输出格式 Prompt
  - 12 模块矩阵
- `realistic_positivity_os_models.dart`
  - 行动卡、状态诊断、ABC、价值绑定、Stretch Zone、用户档案与统计模型
- `realistic_positivity_os_dao.dart`
  - 独立 DAO、训练卡、成长资产、行动证据、人格地图存储
- `realistic_positivity_os_ai_service.dart`
  - AI 生成服务
  - 本地 fallback 价值引擎
  - 危机/高风险安全分流
- `realistic_positivity_os_home_page.dart`
  - 今日训练
  - 最新行动卡
  - 12 模块说明
  - 成长档案
  - 历史记录
  - Prompt 查看

## 覆盖的产品设计核心

- Reality Lens 真实看见
- Question Reframing 问题重构
- Gratitude Practice 感恩训练
- Relational Gratitude 关系感恩
- Emotional Processing 允许为人
- Meaning-Making 痛苦整合
- Savoring & Peak Experience 积极经验
- Change Lab 价值绑定拆解
- ABC Change 情绪/行为/认知改变计划
- Behavior First 行为优先
- Stretch Zone 成长挑战
- Weekly Integration 每周整合

## AI 三层 Prompt

模块已内置：

1. 全局价值层 Prompt：明确书籍/课程来源为《哈佛积极心理学》Lecture 9–10，并浓缩完整价值体系。
2. 场景层 Prompt：按用户状态进入不同干预路径。
3. 输出格式 Prompt：统一输出结构化行动卡 JSON。

## 入口

主抽屉新增：

`真实积极行动系统 · Realistic Positivity OS`

