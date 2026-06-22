# V13 - 全局价值层 Prompt 强化与 AI 输出详细度升级

## 背景
用户明确要求：所有开发必须围绕前面从书籍/课程/文档原文中总结归纳出的中心思想和核心价值体系，不能中途无中生有；同时所有 AI 请求都必须携带这套全局价值层作为背景，并且 AI 返回内容要更详细、更具体、更能帮助用户解决实际问题。

## 本次改造目标
1. 完善 `rot_global` 全局价值层 Prompt。
2. 将之前沉淀的课程/书籍案例与研究锚点加入全局价值层。
3. 确保所有 realistic_optimism_training AI 请求都强制携带全局价值层。
4. 强化 AI 输出质量要求，让返回内容更具体、更详细、更可执行。
5. 在用户可见界面中进一步凸显中心思想、核心价值体系和研究/案例锚点。

## 已加入全局价值层的研究与案例锚点
- Seligman 解释风格：永久化 / 普遍化 / 人格化与暂时 / 特定 / 可调整解释。
- Matt Biondi 1988 首尔奥运案例：前两项失利后仍赢下后面 5 金，用来说明解释风格对恢复和后续表现的影响。
- Karen Reivich / The Resilience Factor：解释风格可以训练，乐观不是天生口号，而是可练习能力。
- 3Ms / Burns / Beck / Seligman / Reivich：识别 Magnifying、Minimizing、隧道视野，把现实比例拉回来。
- Jon Stewart 反刍案例：允许后悔，但不让一个负面细节吞掉全部事实。
- Edison、Dean Simonton、Babe Ruth：高产出和大量失败常相伴，失败用于复盘、恢复、再行动，而不是人格判决。
- Bargh、Dijksterhuis & van Knippenberg、Ellen Langer：环境、词语、角色和选择权会影响表现，Prime / Anti-Prime 必须落地为环境线索。
- Peterson & Seligman VIA 优势视角：不是只识别缺陷，而是从行动、恢复、感恩中提炼优势与身份。
- 感恩与品味：不是否认痛苦，而是完整现实感；具体到人、物、画面、关系和行动。

## 代码改动

### 1. `realistic_optimism_training_prompt_config.dart`
- 大幅扩展 `globalValuePrompt`：加入中心思想、13 条核心价值体系、研究/案例锚点、输出底线。
- 新增 `runtimeGlobalValueEvidencePrompt`：作为运行时强制价值层，防止用户本地覆盖旧 Prompt 后丢失核心价值背景。
- 新增 `runtimeOutputDetailPrompt`：作为运行时强制输出质量层。
- 新增 `getRuntimeGlobalPrompt()`：返回本地/默认全局 Prompt + 强制价值层。
- 新增 `getRuntimeOutputPrompt()`：返回强制输出质量层 + 当前输出格式 Prompt。
- 强化 `outputFormatPrompt`：要求每个字段更详细、具体、可执行；列表优先 3-5 条；行动要写清做什么、在哪里/用什么、多久、完成标准。
- JSON 结构新增 `core_value_reference`：要求 AI 返回本次最贴合的研究/案例锚点，以及它如何应用到当前事件。

### 2. `realistic_optimism_training_ai_service.dart`
- 所有 AI 调用从 `getGlobalPrompt()` 改为 `getRuntimeGlobalPrompt()`。
- 所有输出格式从 `getOutputPrompt()` 改为 `getRuntimeOutputPrompt()`。
- AI 请求正文中显式拼入：全局价值层背景 + 当前场景任务 + 输出格式与详细度要求。
- `maxTokens` 从 3200 提升到 5200，避免更详细输出被截断。
- 本地 fallback payload 新增 `core_value_reference`，即使 AI 不可用也能显示价值锚点。

### 3. `realistic_optimism_training_experience_pages.dart`
- `RotCoreValueCopy` 新增：
  - `researchAnchorsTitle`
  - `researchAnchorsBody`
- 主业务流 `RotCoreBusinessFlowPage` 顶部新增研究与案例锚点环境卡，让用户知道模块训练不是随意建议，而是来自前面总结的核心价值体系与研究/案例。

### 4. `realistic_optimism_training_home_page.dart`
- 首页核心价值环境下方新增“研究与案例锚点”卡。
- 训练详情页新增“价值体系与研究锚点”章节。
- 若 AI 返回 `core_value_reference`，详情页会展示：
  - 本次使用锚点
  - 如何应用到本次事件

## 当前限制
容器内仍没有 `flutter` 或 `dart` 命令，因此无法执行真实 `flutter analyze` 或编译。已做源码级括号、括号配对、关键引用和打包检查。
