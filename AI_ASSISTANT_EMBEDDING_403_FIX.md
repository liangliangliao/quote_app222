# AI Assistant OpenRouter Embedding 403 Fix

修复内容：

1. OpenRouter Embedding 模式不再只绑定 `openai/text-embedding-3-small`。
2. 默认优先使用 `qwen/qwen3-embedding-8b`，并按顺序尝试备用模型：
   - `qwen/qwen3-embedding-8b`
   - `baai/bge-m3`
   - `openai/text-embedding-3-small`
   - `perplexity/pplx-embed-v1-0.6b`
3. Embedding 请求加入 OpenRouter provider fallback 参数。
4. 如果某条历史消息 embedding 失败，会跳过该条，不影响整体聊天。
5. 如果本次 embedding 检索整体失败，例如 OpenRouter 返回 HTTP 403 / 429 / 上游 provider 拒绝请求，聊天不会再失败；系统会自动回退到“拼接全部历史”完成本次请求。
6. 已保存的旧 embedding 如果模型不同，会按当前可用 embedding 模型重新生成，避免不同维度向量比较导致检索失效。

说明：

截图里的 HTTP 403 来自 OpenRouter 路由到的上游 embedding provider 拒绝请求，不是聊天模型本身的错误，也不是 Flutter 页面渲染错误。本补丁让 Embedding 模式具备模型 fallback 和全历史兜底，避免用户在聊天界面直接看到 embedding provider 错误。

## Superseded note

This OpenRouter 403 fallback patch was superseded by `AI_ASSISTANT_EDENAI_EMBEDDING_AND_LOGS_PATCH.md`. The active embedding mode now uses Eden AI `/v3/embeddings` with `openai/text-embedding-3-small`.
