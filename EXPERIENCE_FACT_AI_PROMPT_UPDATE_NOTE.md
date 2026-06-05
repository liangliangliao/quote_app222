# 本次更新

这次继续把“概念一路下沉到经验事实”的理解真正落到了 **AI 生成结构 + 解析结构 + 概览页展示** 上，而不是只改本地页面文案。

## 主要变更

1. `ActionDirection` 新增：
   - `realityMeaning`
   - `observableChanges`
   - `experienceFact`
   - `factDoneSignal`

2. AI Prompt 结构改成经验事实驱动：
   - 概览生成时，每个方向就要求输出：
     - 现实含义
     - 可观察变化
     - 经验事实
     - 完成标志
   - 方向展开/更多路径/自定义步骤扩展时，也要求对模块先输出这四层。

3. Repository 归一化时会自动补全：
   - 方向级 realityMeaning / observableChanges / experienceFact / factDoneSignal
   - 模块级 realityMeaning / observableChanges / experienceFact / factDoneSignal

4. 概念行动树页改成“方案卡”视图：
   - 标题
   - 现实含义
   - 可观察变化
   - 经验事实
   - 完成标志
   - 再进入拆解页

## 目的

让用户先看到“这个概念在现实里最终长成什么样”，再去看动作，而不是先被一堆解释或抽象步骤淹没。
