# AI Assistant memory schema runtime fix

Fixes runtime SQLite errors on devices that already had an older
`ai_assistant_memories` table without the newer `created_at_ms` column.

Changes:

- Database version bumped from 27 to 28.
- `ensureAiAssistantTables()` now idempotently adds missing columns to existing
  `ai_assistant_memories` tables:
  - `created_at_ms INTEGER NOT NULL DEFAULT 0`
  - `updated_at_ms INTEGER NOT NULL DEFAULT 0`
- `ensureAiAssistantTables()` also idempotently protects
  `ai_assistant_summaries` columns.

This means existing installed apps do not need the user to clear app data.
