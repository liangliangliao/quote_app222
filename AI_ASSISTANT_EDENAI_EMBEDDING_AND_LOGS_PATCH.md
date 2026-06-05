# AI Assistant Eden AI Embedding + Unified Error Logs Patch

This patch changes the AI Assistant semantic-history mode from OpenRouter Embedding to Eden AI Embedding.

## Context modes

The chat page now exposes only two context modes:

1. `拼接全部历史`
   - Sends all local `user` / `assistant` messages in the current conversation to the selected chat model.

2. `Eden AI Embedding 语义检索`
   - Uses Eden AI V3 Embeddings endpoint:
     - Endpoint: `https://api.edenai.run/v3/embeddings`
     - Model: `openai/text-embedding-3-small`
   - Generates an embedding for the current user message.
   - Generates missing embeddings for older messages in the same conversation.
   - Uses cosine similarity to select relevant old history.
   - Sends selected relevant history + current user message to the selected chat model.

No recent-message window, keyword retrieval, local memory, summary compression, remote conversation id, or previous_response_id is used.

## Logging

AI chat related errors are now written to the app's unified `logs` table through `DeepSeekLogger` / `LogDao`.

Logged error points:

- Eden AI embedding API failures.
- Historical-message embedding failures.
- Context builder fallback errors.
- Final chat generation failures.

For embedding requests, success logs summarize the response without storing the full vector payload in the logs table.

## Backward compatibility

Existing conversations saved with the legacy `openrouter_embedding` context mode are normalized to `edenai_embedding` when loaded.
