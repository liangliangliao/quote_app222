# Semantic Embedding Native Cosine Fix

本补丁修复“快速相似度 / Embedding-only”模式：

- 最终分数只使用真实 Embedding API 返回的两个原生向量计算 cosine similarity。
- 不调用 LLM。
- 不使用关键词相似度、字符相似度、本地同义词表、上下位词典、短词校准。
- 不使用 API 失败 fallback；Embedding API 失败会直接显示错误。
- 缓存版本升级为 `semantic_embedding_native_cosine_v8`，避免旧错误缓存污染。
- 页面显示向量维度、LLM=false、本地规则=false、Fallback=false。
- 默认 embedding 模型改为 `openai/text-embedding-3-large`，默认维度 3072。

需要验证日志：

- module = semantic_consistency.embedding
- endpoint 包含 `/embeddings`
- response 中有 vector_dims
- model 是 embedding 模型，不是 chat 模型
