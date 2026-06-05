# AI Assistant Semantic Retrieval Rework

本补丁重新实现 AI 聊天助手的历史上下文传送规则，只保留两种模式：

1. **拼接全部历史**
   - 当前会话内所有 `user/assistant` 消息按时间正序发送给聊天模型。

2. **Eden AI OpenAI Embedding 语义检索**
   - 使用 Eden AI `/v3/embeddings`。
   - Embedding 模型升级为 `openai/text-embedding-3-large`。
   - 向量维度使用 `3072`。
   - 不再使用最近消息窗口、关键词检索、本地记忆或摘要压缩。

## 关键修复

旧版本按单条消息做 embedding，相似度阈值也偏宽松，容易把无关的长回复带入聊天请求。

新版改为更接近 RAG 的检索结构：

- 先把历史对话按 **用户消息 + 对应助手回复** 组成“历史对话片段”。
- 超长助手回复会切成上下文片段，保留对应用户问题作为片段前缀。
- 对“历史片段”而不是孤立单条消息生成 embedding。
- 当前问题生成 query embedding。
- 用 cosine similarity 对历史片段排序。
- 只有超过严格阈值的片段才进入聊天请求。
- 没有强相关历史时，只发送当前用户问题。

## 新增数据库表

```sql
ai_assistant_context_chunks
```

用于保存历史对话片段和片段 embedding，避免重复对旧消息生成 embedding。

## 日志

Eden AI embedding 请求、响应、批量补齐、向量选择摘要和错误仍统一写入 App 日志表。
完整向量不会写入日志，只保存到本地 SQLite。
