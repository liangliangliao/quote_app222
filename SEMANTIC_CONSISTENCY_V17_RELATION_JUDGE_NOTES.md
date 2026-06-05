# 语义一致性精判 v17 改造说明

本版基于 v16 诊断版继续升级，核心目标是：不再让 Embedding-only 承担精准语义判断，而是把模块拆成更清晰的三层。

## 主要改动

1. 新增“概念/语义关系精判”模式
   - 直接调用 LLM Judge。
   - 不依赖 Embedding 分数做最终结论。
   - 用于判断：完全等价、高度近义、上下位、同类并列、互斥、因果、蕴含、前提、反义、相关但不等价、无关、歧义等。

2. “短句语义精判”不再被 Embedding 分数提前拦截
   - 旧逻辑中，如果 Embedding 分数低于阈值，会直接判无关，不调用 LLM。
   - 新逻辑中，Embedding 只作为诊断参考；即使 Embedding 失败或分数低，也继续调用 LLM Judge。

3. “严格事实一致”不再依赖 Embedding 成功
   - 旧逻辑中严格事实一致会先调用 Embedding，失败则整个模式失败。
   - 新逻辑中 Embedding 只作为诊断，最终仍依赖事件结构抽取 + LLM Judge。

4. 强化 LLM Judge 关系分类
   - 新增 relation：near_equivalent、hypernym、hyponym、co_hyponym、mutually_exclusive、causal_relation、entailment、prerequisite、antonym。
   - Prompt 明确要求不要把 Embedding 分数当成最终语义关系。
   - Prompt 明确示例：动物/牛=上下位，鸟/鱼=同类并列，直角三角形/锐角三角形=互斥，我打了小明/小明被我打了=等价。

5. UI 更新
   - 模式列表新增“概念/语义关系精判”。
   - 按钮从“开始精判”改为“开始分析”。
   - 示例新增：同类并列、互斥概念、哲学概念。
   - 概念关系类结果使用提示色，不再一律显示为红色错误。

6. 修复 Reranker 中重复 `.timeout(...)` 的潜在编译错误。

## 推荐使用方式

- 向量相关度诊断：只看 Embedding 调用、向量维度、dot、norm、cosine、缓存是否污染。
- 概念/语义关系精判：用于“动物/牛”“鸟/鱼”“必然性/原因推出果”“直角三角形/锐角三角形”。
- 短句语义精判：用于“我打了小明/小明被我打了”“如何行动起来/提高执行力”。
- 严格事实一致：用于主客体、否定、条件、时间、事实性差异判断。
