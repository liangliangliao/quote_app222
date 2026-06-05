# AI Assistant Mainstream Semantic Context Patch

This patch changes the second chat context mode to a mainstream conversational RAG-style design.

## Modes

1. Full history
   - Sends the full local user/assistant message history.

2. Eden AI semantic context retrieval
   - Uses Eden AI `/v3/embeddings` with `openai/text-embedding-3-large`.
   - Builds local overlapping conversation chunks from older chat history.
   - Embeds chunks in batch and stores them in SQLite.
   - Uses a history-aware retrieval query built from the latest user message plus a small recent chat window.
   - Sends three parts to the chat model:
     1. semantic retrieved older history chunks, if any;
     2. the recent 8 user/assistant messages as normal chat turns;
     3. the current user message.

## Important behavioral change

The previous implementation used only semantic retrieval. If retrieval returned no chunk, the chat model received only the current message. That could lose context for short follow-up messages.

This version always includes recent chat turns in semantic mode, which is closer to mainstream conversational RAG/chat-memory behavior.

## Files changed

- `lib/ai_assistant/ai_assistant_service.dart`
- `lib/ai_assistant/ai_assistant_embedding_service.dart`
- `lib/ai_assistant/ai_assistant_models.dart`
- `lib/ai_assistant/ai_assistant_page.dart`
- `lib/data/db.dart`

## Database

Database version bumped to 26. Existing chunk rows are not reused because `chunk_version` changed to:

`semantic_turn_v4_mainstream_recent_retrieval`

This avoids mixing old retrieval chunks with the new retrieval design.
