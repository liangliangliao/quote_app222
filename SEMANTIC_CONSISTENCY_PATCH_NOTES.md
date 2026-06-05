# Semantic Consistency Engine Patch

新增“语义一致性精判”全局模块，支持不同精准性：

1. 快速相似度：仅 Embedding + cosine similarity。
2. 标准精判：Embedding 粗筛 + LLM Judge JSON 精判。
3. 严格事实一致：Embedding + 事件结构抽取 + LLM Judge。
4. 标题/摘要忠实性：长文切片 + Embedding 证据检索 + LLM Judge。
5. 高精度候选精排：Embedding TopK + 可选 Cohere Reranker + LLM Judge。

主要新增文件：

- `lib/semantic_consistency/semantic_consistency_models.dart`
- `lib/semantic_consistency/semantic_consistency_dao.dart`
- `lib/semantic_consistency/semantic_consistency_service.dart`
- `lib/semantic_consistency/semantic_consistency_page.dart`
- `lib/semantic_consistency/semantic_consistency_settings_page.dart`

集成点：

- 首页左侧菜单新增“语义一致性精判”入口。
- 设置页新增“语义一致性精判配置”入口。
- SQLite 新增 `semantic_consistency_records` 和 `semantic_embedding_cache`。
- 数据库版本从 31 升级到 32。
- 所有 Embedding / Judge / Rerank 请求接入 `DeepSeekLogger` 日志。

默认配置：

- Embedding Provider：OpenRouter
- Embedding Model：`openai/text-embedding-3-small`
- Dimensions：1536
- 默认模式：标准精判
- Reranker：默认关闭
- Reranker 默认服务：Cohere `rerank-v3.5`

注意：

- Embedding 默认复用设置页中的 OpenRouter Key。
- LLM Judge 默认复用全局 AI Provider / Model。
- Reranker 需要在语义精判配置页单独填写 API Key，未配置时会自动跳过精排。
