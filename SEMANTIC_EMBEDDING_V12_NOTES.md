# Semantic Embedding v12

修复点：Embedding-only 模式仍然只使用真实 Embedding API + 原生向量 cosine，不调用 LLM、不使用本地规则、不使用关键词/词面分数、不 fallback。

本版只修复页面判定阈值问题：旧配置中 highThreshold 可能仍是 0.85 或更高，导致 OpenAI text-embedding-3-large 这类模型在中文短词/上下位概念上的原生 cosine 经过归一化后仍被误显示为“低语义相似”。v12 在 fastEmbedding 模式中使用归一化语义分数，并将高相似阈值保守限制为 0.70、中等阈值限制为 0.45；用户仍可把阈值调低，但旧高阈值不会继续误伤。

页面新增显示：原生余弦、归一化语义分数、中等阈值、高相似阈值、向量维度、LLM=false、本地规则=false、Fallback=false。
