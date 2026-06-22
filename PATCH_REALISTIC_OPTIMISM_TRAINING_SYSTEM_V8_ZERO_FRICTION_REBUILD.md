# PATCH_REALISTIC_OPTIMISM_TRAINING_SYSTEM_V8_ZERO_FRICTION_REBUILD

## 背景
V7 相比前版已经从单一 AI 生成器过渡到多个训练子系统，但用户实际使用后仍反馈：
- 和最终版产品设计方案仍不吻合；
- 中心思想和核心价值体系不够明显；
- 用户体验不佳，打开后不知道从哪里开始。

本轮 V8 重点不是继续增加入口，而是降低启动门槛，让用户无需理解复杂产品设计，也能从“今天一件事”完成现实主义乐观训练闭环。

## 核心问题定位
V7 的 Stepper/Wizard 仍然要求用户自己知道要填写什么：
- 没有足够的场景选择；
- 没有默认示例；
- 没有“我不知道怎么写”的救援；
- 中心思想主要在文案和 Prompt 中，未充分进入每一步交互；
- 用户仍会感觉像在填一张复杂心理表单。

## V8 主要改动

### 1. 新增零门槛主入口：RotTodayOneThingPage
文件：
- `lib/realistic_optimism_training/realistic_optimism_training_experience_pages.dart`

新增页面：
- `RotTodayOneThingPage`

用户进入后无需先理解模块结构，只需选择一个最像当前状态的场景：
- 拖延/没开始
- 失败/没做好
- 被批评/被否定
- 关系不舒服
- 情绪低落
- 不知道从哪开始

系统会自动填充可修改示例，帮助用户直接开始。

### 2. 把中心思想做成每一步交互
V8 页面按最终方案核心价值重新组织：
1. 先选场景，而不是先写复杂输入；
2. 一句话写现实事件；
3. 允许自己为人：情绪芯片、身体感受芯片、强度滑块；
4. 事实 ≠ 解释：事实层与脑中故事分开写；
5. Fault Finder / Benefit Finder 双镜头即时预览；
6. 选择一个小到能开始的 5 分钟行动；
7. 保留一个今日感恩/品味点和今日 Prime；
8. 最后生成完整训练结果与身份沉淀。

### 3. 增加默认示例与候选项
用户不再面对空白输入框。系统提供：
- 场景示例事件；
- 自动解释示例；
- 5 分钟行动候选；
- 情绪候选；
- 身体感受候选；
- 默认 Prime；
- 默认感恩/品味点。

### 4. 首页主入口改为“从今天一件事开始”
修改文件：
- `lib/realistic_optimism_training/realistic_optimism_training_home_page.dart`

原“进入引导式训练”改为：
- “从今天一件事开始”

事件相关入口默认进入 `RotTodayOneThingPage`，而不是原来的复杂 Stepper Wizard。

### 5. Workbench 文案更新
兼容旧快速输入保留，但推荐入口调整为：
- “打开 V8 今日一件事训练”

强调旧文本框只是兼容入口，不再作为核心体验。

## 设计意图
V8 的目标是让用户进入模块后立刻明白：
- 我不需要懂积极心理学；
- 我不需要一次讲清楚所有问题；
- 我只需要选一个最像的场景；
- 系统会帮我完成：承认情绪、拆事实和解释、识别 Fault Finder、保留 Benefit Finder、选一个 5 分钟行动、沉淀身份证据。

## 本轮修改文件
- `lib/realistic_optimism_training/realistic_optimism_training_home_page.dart`
- `lib/realistic_optimism_training/realistic_optimism_training_experience_pages.dart`

## 备注
当前环境没有 Flutter/Dart SDK，无法执行真实 `flutter analyze`。已做源码级括号、引用和基本一致性检查。
