# Semantic Embedding v16 Diagnostic Fix

本次修复目标：不再继续调阈值或包装结论，而是把 Embedding-only 模式改成可验证的“原生向量诊断模式”，用于确认到底是调用错误、解析错误、缓存污染，还是模型本身不适合中文语义相似判断。

## 核心修复

1. Embedding-only 模式只做：真实 Embedding API → 原生向量 → App 本地标准 cosine。
2. 不调用 LLM，不使用本地词典/上下位规则，不使用关键词相似度，不做归一化，不 fallback。
3. 缓存版本升级为 `semantic_embedding_native_v16`，旧缓存不会继续污染。
4. 缓存 key 增加 endpoint、model、provider、dimensions 是否真实发送等信息；对不发送 dimensions 的模型，缓存维度统一使用 0，避免配置框数字误当真实向量维度。
5. Embedding 响应解析增加路径诊断：`data[0].embedding` / `embedding` / `vector` / `embeddings[0]` / 递归路径。
6. 日志新增 `semantic_consistency.embedding_cosine`，记录 dot、normA、normB、cosine、向量 checksum、head_12、cacheHit。
7. 页面新增“清空向量缓存”按钮，重新测试时可强制下一次调用真实 API。
8. 页面新增向量诊断展开项，显示向量维度、范数、head_12、checksum、endpoint、向量解析路径、是否缓存命中。
9. 删除未使用的本地同义词/上下位概念先验方法，避免源码中出现隐藏本地规则的误解。

## 验证方式

进入“语义一致性精判” → 选择“向量相关度诊断” → 点击“清空向量缓存” → 再测试。

结果页应显示：

- LLM: false
- 本地规则: false
- Fallback: false
- A/B 缓存: false（首次真实调用时）
- A/B 向量路径，例如 `data[0].embedding`
- A/B 向量维度
- dot / A范数 / B范数 / 原生Embedding余弦
- 查看向量诊断：head_12 与 checksum

日志页可搜索：

- `semantic_consistency.embedding`
- `semantic_consistency.embedding_cosine`

## 注意

Embedding API 返回的是向量，不返回“语义是否一致”。App 中的 cosine 分数由本地标准公式计算：

`cosine = dot(vectorA, vectorB) / (l2Norm(vectorA) * l2Norm(vectorB))`

该模式用于验证向量调用与计算，不代表同义、等价、上下位、互斥或事实一致。真正语义关系精判仍应使用 LLM Judge / NLI / Reranker / 结构化抽取。
