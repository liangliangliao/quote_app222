# Yangming V41 - Auto Reflow Navigator

## What changed
- Persisted latest growth navigator result and latest next-cycle recommendation in `YangmingDao`.
- Home page now auto-loads the latest reflowed navigator before falling back to heuristic recommendations.
- AI growth navigator refresh now saves its result for future home re-entry.
- Training workbench now publishes:
  - weekly-summary-based navigator reflow
  - next-cycle-based navigator reflow
- After creating a new plan from recommendation, home navigator is updated to point back to the newly created plan.
- Fixed lingering multiline single-quoted string issue in training trace persistence.
- Growth navigator badge now distinguishes `AI 推荐` / `自动回流` / `本地推荐`.

## Intent
This version advances the PRD path from a manually refreshed dashboard to an automatically reflowing growth navigator that reflects weekly summaries and next-cycle planning.
