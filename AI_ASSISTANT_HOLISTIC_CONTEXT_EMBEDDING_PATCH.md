# AI Assistant Holistic Context Embedding Patch

This patch updates the second chat context mode to use holistic contextual semantic retrieval.

## Modes kept

1. 拼接全部历史
2. Eden AI 语义上下文检索

No recent-message-only strategy, keyword retrieval, memory table, summary compression, or remote conversation id is used.

## Eden AI semantic mode behavior

- Embedding model: `openai/text-embedding-3-large`
- Endpoint: `https://api.edenai.run/v3/embeddings`
- Query embedding input is built from:
  - current user request
  - continuous chat-window context in original order
  - current user request repeated as retrieval focus
- History embedding index is built from large continuous conversation windows, not isolated messages or one-turn snippets.
- Each selected context item sent to the chat model is a continuous user/assistant window preserving original order.
- Old chunk cache is isolated with chunk version: `semantic_holistic_window_v5_contextual_query`.

## Chat request in Eden AI semantic mode

When relevant context windows are found, the chat model receives:

```text
system: selected continuous context windows
user: current user request
```

When no reliable context window is found, the chat model receives:

```text
user: current user request
```

## Notes

Embedding APIs have input length limits. If the visible chat transcript becomes too long, the embedding query keeps one continuous tail window rather than stitching unrelated snippets together.
