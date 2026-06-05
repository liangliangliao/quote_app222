# AI Assistant Fused Context Mode Patch

This patch updates the second chat context mode from pure embedding retrieval to a fused mainstream-style chat context strategy.

## Context modes

The chat UI still exposes two modes:

1. `拼接全部历史`
   - Sends all local user/assistant messages in the current conversation.

2. `Eden AI 语义上下文检索`
   - Builds a fused context with:
     - remote conversation metadata fields when present
     - local memories extracted from user statements
     - compressed summary of older messages
     - keyword search hits from older messages
     - Eden AI / OpenAI embedding semantic retrieval over continuous conversation windows
     - recent real user/assistant messages
     - current user request

## Embedding

The embedding provider remains Eden AI `/v3/embeddings` with:

`openai/text-embedding-3-large`

The embedding index version is now:

`semantic_fused_context_v6_memory_summary_recent_keyword_remote`

Old cached chunks from earlier retrieval strategies are ignored.

## Database migration

Database version is bumped to `27`.

Added columns:

- `ai_assistant_conversations.provider_conversation_id`
- `ai_assistant_conversations.provider_previous_response_id`

Added tables:

- `ai_assistant_memories`
- `ai_assistant_summaries`

## Notes

Remote conversation metadata is now schema-compatible. For DeepSeek, OpenRouter, and Eden AI chat-completions style calls, the app still uses local context as the source of truth because those routes do not provide a reliable provider-side conversation state equivalent.

All context-builder and embedding errors continue to be logged through the app logging pipeline.
