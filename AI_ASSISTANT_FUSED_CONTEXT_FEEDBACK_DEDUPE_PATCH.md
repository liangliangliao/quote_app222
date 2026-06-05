# AI Assistant fused context mode: feedback weighting and dedupe upgrade

This patch upgrades the second context mode `Eden AI 语义上下文检索`.

## Added

- Assistant reply feedback buttons in chat UI:
  - thumbs up: marks an answer as useful
  - thumbs down: opens feedback reasons
- Feedback is persisted locally on `ai_assistant_messages`:
  - `feedback_rating`
  - `feedback_reason`
  - `feedback_comment`
  - `context_weight`
  - `exclude_from_context`
- Feedback event history table:
  - `ai_assistant_message_feedback_events`
- Fused context ranking now considers user feedback:
  - positively rated replies raise historical context weight
  - negatively rated / irrelevant replies are penalized or excluded
- Context block deduplication:
  - exact content hash dedupe
  - source `message_id` overlap dedupe
  - recent messages are protected and not duplicated in semantic/keyword blocks
- Context budget control:
  - selected context blocks are clipped by a fixed character budget before being sent to the chat model
- Enhanced context-selection logging:
  - candidate block count
  - selected block count
  - selected block type / priority / score / preview

## Modes still available

- `拼接全部历史`
- `Eden AI 语义上下文检索`

The second mode remains a fused context strategy: memory + summary + keyword + embedding + recent messages + current user request, now with feedback weighting and duplicate context removal.
