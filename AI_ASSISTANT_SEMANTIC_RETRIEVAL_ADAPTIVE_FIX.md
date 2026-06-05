# AI Assistant Semantic Retrieval Adaptive Fix

本补丁针对“Embedding 有请求和响应，但聊天请求没有带入相关历史”的问题，重做了语义检索选择逻辑。

## 改动摘要

1. **继续只保留两种上下文模式**
   - 拼接全部历史
   - Eden AI OpenAI Embedding 语义检索

2. **Embedding 模型**
   - Eden AI `/v3/embeddings`
   - `openai/text-embedding-3-large`
   - 3072 维

3. **索引方式**
   - 不再把“用于检索……”这类说明文字加入 embedding 文本。
   - query embedding 使用用户当前输入原文。
   - document embedding 使用真实历史对话片段文本：`用户：... / 助手：...`。
   - 新增 `chunk_version = semantic_turn_v3_raw_adaptive`，旧版本缓存 chunk 不参与新检索。

4. **选择逻辑**
   - 不再使用固定高阈值 `0.62`。
   - 改为自适应规则：
     - top score 足够强；或
     - top score 明显高于候选池 p75；或
     - 候选极少时适当放宽。
   - 再根据 top score window 选择 topK。

5. **数据库**
   - 版本升级到 `25`。
   - `ai_assistant_context_chunks` 新增 `chunk_version` 字段。

6. **日志**
   - `ai_assistant.embedding.selection` 会写入：
     - candidate chunk 数量
     - selected 数量
     - best score
     - p50 / p75
     - top scores 和 preview

## 预期效果

- 与历史相关的问题会更容易带入相关历史片段。
- 明显无关的问题不会因为弱相似度而带入大量旧历史。
- 旧版 embedding chunk 缓存不会和新版检索逻辑混用。
