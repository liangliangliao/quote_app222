# AI Assistant Context Request Cleanup Patch

This patch tightens the second context mode (`Eden AI 语义上下文检索`) to reduce duplicated and irrelevant context in chat model requests.

## Key fixes

1. **Bad memory filtering**
   - Prevents questions like `我是谁` from being stored as `用户称呼: 谁`.
   - Existing invalid stored name memories such as `谁 / 什么 / 哪里` are filtered out at request time.

2. **Do not send failed assistant messages as context**
   - Messages like `AI 调用失败：...` and messages with error metadata are excluded from:
     - full-history mode
     - recent window
     - summary
     - keyword search
     - semantic indexing

3. **Compact request context**
   - System context budget reduced.
   - Keyword hits are compacted instead of sending full long assistant replies.
   - Summary is now short extractive context, not a large raw transcript.
   - Recent long assistant replies are capped.

4. **Cleaner embedding retrieval query**
   - Query embedding now uses recent real dialogue + current request, instead of mixing in already-selected summary/keyword/memory blocks that can pollute retrieval.

5. **Smaller continuous semantic windows**
   - Chunk size reduced from 7200 chars to 2600 chars.
   - Overlap reduced from 4 messages to 2 messages.
   - Chunk cache version bumped to `semantic_fused_context_v7_compact_weighted_dedupe` so old large chunks are ignored.

6. **No misleading message embedding save**
   - Query embedding is no longer saved as the current user message embedding, because the query may include recent dialogue context and is not the same as the raw user message.

## Expected behavior

For a follow-up request like `需要具体的目标实现方案以及具体的行动步骤`, the model request should now include:

- a small system context containing only compact selected context;
- recent real dialogue with capped long replies;
- the current user request once, at the end.

It should not include huge repeated blocks from keyword hits, early summary, and recent messages at the same time.
