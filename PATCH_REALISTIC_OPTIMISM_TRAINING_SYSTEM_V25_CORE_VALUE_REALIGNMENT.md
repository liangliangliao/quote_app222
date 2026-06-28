# PATCH_REALISTIC_OPTIMISM_TRAINING_SYSTEM_V25_CORE_VALUE_REALIGNMENT

## 背景
用户指出 v24 后系统逐步被“日常状态机、提醒、待办同步、周报、产物库”牵引，偏离了 Lecture 7–9 前半段的中心思想和核心价值体系。

本次修复把系统重新拉回以下中心思想：

> 人不能控制所有外部事件，但可以通过解释方式、注意焦点、行动实践、环境启动和感恩训练，参与共同创造自己的心理现实。

核心主轴：

> 解释塑造感受，注意塑造现实，行动塑造自我，感恩塑造世界观。

## 已修正的问题

### 1. 移除不属于用户指定范围的锚点
此前默认 Prompt 和价值锚点混入了 Seligman/Biondi/Reivich/Langer/VIA/Edison/Simonton/Babe Ruth 等外部或扩展锚点。虽然它们在广义积极心理学中相关，但并不符合本次用户指定的主范围：Lecture 7 从“如何成为更乐观的人”开始，到 Lecture 8，再到 Lecture 9 前半段感恩/benefit finding 结束、进入 change 之前。

现在内置 Prompt 和价值源表只围绕：
- 幸福基线：Gilbert / Brickman
- Bandura 自我效能
- 心理免疫系统
- 过程模拟 vs 结果模拟
- Tal 自己的失败故事：same reality, different interpretations
- Suzanne Thompson 火灾研究
- Bargh 启动实验
- professor / secretary / hooligan 角色启动实验
- 祖母故事
- 感恩 time-in

### 2. 重写全局价值 Prompt
`realistic_optimism_training_prompt_config.dart` 中的 `globalValuePrompt` 已重新对齐：
- 明确系统不是鸡汤、不是积极日记、不是任务管理器。
- 明确现实主义乐观不是 Pollyanna 式盲目正能量。
- 明确资源发现不是“坏事都是好事”。
- 明确日常闭环只是实践层，不是中心思想本身。
- 明确任何提醒、待办、周报、状态机都必须服务解释、行动、注意、感恩这条主线。

### 3. 重写运行时强制价值层
`runtimeGlobalValueEvidencePrompt` 现在只注入 Lecture 7–9 前半段锚点，不再要求 AI 使用偏离范围的外部研究/案例。

### 4. 修正输出契约
`runtimeOutputDetailPrompt` 与 `outputFormatPrompt` 已改为：
- core_value_reference 只能来自 Lecture 7–9 前半段锚点。
- 每次输出必须回答：发生了什么、我如何解释、我还能做什么、我被什么启动、我仍能珍惜什么。
- 禁止把功能名、状态机、待办同步、周报指标当成核心价值。

### 5. 修正本地 fallback 的锚点
`realistic_optimism_training_ai_service.dart` 中本地生成策略不再使用外部锚点：
- 失败场景：Lecture 7 心理免疫系统 + Tal 失败故事
- 永久化/自责场景：Lecture 7 同一现实，不同解释
- 行动场景：Bandura 自我效能 + 行动证据
- 过程行动：Lecture 7 过程模拟优于结果幻想 + Bandura 自我效能

### 6. 修正价值源数据库种子
`seedValueSourceAnchors()` 已重写为四类核心源：
1. 解释风格与 Tal 失败故事
2. 行动证据、自我效能与心理免疫
3. 注意力创造现实 / 环境启动
4. 感恩是完整现实感

### 7. 修正用户界面里的中心文案
已更新：
- 首页 Hero
- “为什么这样训练”说明
- 今日训练驾驶舱
- 日常实践层说明
- 蓝图页标题与说明
- `RotCoreValueCopy` 中心思想和研究锚点

现在页面不再把“日常闭环、状态机、产物库”表述为中心价值，而是把它们明确降级为实践层。

### 8. 清理用户可见英文与旧锚点
用户可见文案中清理：
- `Fault / Benefit 双镜头` → `问题放大视角 / 资源发现视角`
- `P2 / 日常延伸` → `日常实践层 / 日常实践产物`
- 旧研究锚点：Seligman、Biondi、Reivich、Edison、Simonton、Babe Ruth、VIA、Langer

## 仍保留的工程结构
为了不破坏既有数据迁移和功能调用，以下内部命名暂时保留在代码层：
- `p2_delivery`
- `listP2Artifacts`
- `anti_prime_cleanup`
- `savoringPrompt`

这些属于内部字段或函数名，不应直接显示给普通用户。后续如果要彻底清理，需要做数据库迁移和兼容层。

## 本次修复后的设计原则

所有模块必须通过以下检查：

1. 是否帮助用户把事实与解释分开？
2. 是否避免把痛苦说成好事？
3. 是否让用户从被动受害者回到主动创造者？
4. 是否用过程行动替代结果幻想？
5. 是否用行动证据替代口号式自尊？
6. 是否用失败恢复训练心理免疫？
7. 是否用环境启动支持注意力？
8. 是否用具体感恩保持完整现实感？
9. 是否避免让日常状态机喧宾夺主？
10. 是否在 L3/L4 时停止普通积极训练？

## 版本
v25_core_value_realignment

### 9. 清理旧价值源数据库锚点
`seedValueSourceAnchors()` 现在会删除旧锚点 ID：
- `ROT_EXPLAIN_SELIGMAN_BIONDI`
- `ROT_FAILURE_IMMUNITY`
- `ROT_PRIME_ENVIRONMENT`
- `ROT_GRATITUDE_IDENTITY`

然后写入 Lecture 7–9 前半段的新锚点，避免用户已有数据库继续显示旧价值体系。
