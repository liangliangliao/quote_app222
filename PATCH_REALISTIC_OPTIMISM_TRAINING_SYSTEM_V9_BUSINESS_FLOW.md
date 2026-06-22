# PATCH_REALISTIC_OPTIMISM_TRAINING_SYSTEM_V9_BUSINESS_FLOW

## 背景
V8 虽然降低了入口门槛，但各子功能仍然像彼此分散的页面：事件重构、过程行动、失败免疫、Prime、身份沉淀之间缺少一条强业务主线。用户完成一个功能后，仍不知道下一步应该做什么。

## V9 目标
将“现实主义乐观训练系统”从多个孤立子功能，改造成一次完整训练会话：

事件强度 → 情绪允许 → 事实/解释 → Fault/Benefit 双镜头 → 可控点 → 5 分钟行动 → 执行/复盘 → 感恩/Prime/身份沉淀

## 主要改动

### 1. 新增串联式训练会话页
新增 `RotConnectedTrainingSessionPage`。

该页把最终产品设计方案的核心闭环做成同一个 Stepper：
- 从今天一件事开始
- Permission to Be Human
- 事实 ≠ 解释
- 双镜头 + 主动性
- 过程行动计划
- 执行 / 复盘
- 感恩 / Prime / 身份整合

### 2. 子功能变成同一会话中的阶段
事件强度分级、情绪容器、事实解释分离、解释风格、Fault/Benefit、过程行动、行动复盘、身份沉淀不再只是孤立入口，而是在一个训练会话中自然流转。

### 3. 加入执行复盘强制节点
V9 不再允许用户只停在 AI 分析结果。生成训练记录后，会进入“执行/复盘”步骤：
- 已完成 5 分钟行动：保存行动证据。
- 未完成：记录卡点，并进入失败免疫/恢复复盘。

### 4. 首页主入口改为完整会话
首页、事件入口、过程行动入口默认进入 `RotConnectedTrainingSessionPage`，而不是旧的单场景生成器。

### 5. 更强地体现中心思想
V9 在交互上明确体现：
- 不否认痛苦：先做情绪允许。
- 不让痛苦垄断解释权：拆事实与脑中故事。
- 行动建立自我效能：必须生成并复盘 5 分钟行动。
- Focus creates reality：会话末尾设置 Prime。
- 感恩是完整现实感：会话末尾保留仍值得珍惜的一点。
- 身份由证据积累：会话结束前生成身份句，并保存行动证据。

## 修改文件
- `lib/realistic_optimism_training/realistic_optimism_training_experience_pages.dart`
- `lib/realistic_optimism_training/realistic_optimism_training_home_page.dart`

## 说明
旧的单场景页面仍保留作为兼容入口，但主体验已转向串联业务流程。
