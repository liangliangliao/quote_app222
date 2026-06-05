# Semantic Embedding Fix Notes

本次修复针对“快速相似度 / Embedding-only”模式中短中文词语/短语的语义相似度异常问题：

- 保留 LLM Judge 为独立模式，不把 LLM 作为 Embedding 模式的兜底。
- 快速相似度模式仍然不调用 LLM，只调用 Embedding API。
- Embedding-only 模式从单一原文向量余弦改为：
  - 原始向量余弦 `raw_vector_cosine`
  - 语义化输入向量余弦 `semantic_prompt_vector_cosine`
  - 词面相似度 `lexical_surface_similarity`
  - 稳定短概念关系校准 `local_concept_prior`
  - 最终 Embedding 语义分数 `final_embedding_semantic_score`
- 修复短文本词面虚高问题，例如“各行其是 / 各行其上”这类一字之差、词面很像但语义未必成立的情况，不再只因字符接近而得到虚高结论。
- 对常见稳定的中文上下位概念做无 LLM 校准，例如“动物 / 牛”会被识别为上下位概念语义高度相关，不应低于明显错别字式短语。
- 结果页新增显示：原始余弦、语义化余弦、词面相似、概念校准、是否已降低词面虚高。
- 快速相似度模式的关系标签从“完全等价/大体一致”改为“高语义相似/中等语义相似/低语义相似”，避免把 embedding 相似度误读成严格事实等价。

注意：Embedding-only 仍然不是严格事实推理，不判断主客体、否定、条件等严格一致性；这些仍由标准精判/严格事实一致模式处理。
