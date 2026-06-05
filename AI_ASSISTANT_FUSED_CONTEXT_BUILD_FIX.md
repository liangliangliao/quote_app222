# AI Assistant fused context build fix

Fixed Flutter build error:

```text
lib/ai_assistant/ai_assistant_service.dart:84:13
Error: The method '_upsertLocalMemoriesFromText' isn't defined for the type 'AiAssistantService'.
```

## Cause

The fused-context service contained a leftover call to `_upsertLocalMemoriesFromText`, but the actual memory extraction/upsert logic had been consolidated into `_loadAndBackfillMemories(...)` inside `_buildFusedSemanticMessages(...)`.

## Fix

Removed the obsolete pre-call. Memory extraction still runs in fused semantic mode through `_loadAndBackfillMemories(...)`, which receives the current user message and previous conversation history.

## Scope

Only `lib/ai_assistant/ai_assistant_service.dart` was changed.
