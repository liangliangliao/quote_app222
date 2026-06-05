# Yangming Module v40 - Growth Navigator

## What changed
- Added a proactive growth navigator card to the Yangming overview page.
- The navigator now recommends:
  - the next lesson to open
  - the next mission to enter
  - a suggested 3/7 day training duration
  - the next concrete action
  - the next review question
- Added AI-powered structured growth navigation generation.
- Added heuristic local recommendation as a stable fallback so the home page can recommend even without AI.

## Files changed
- `lib/yangming_module/yangming_models.dart`
- `lib/yangming_module/yangming_ai_service.dart`
- `lib/yangming_module/yangming_module_home_page.dart`
