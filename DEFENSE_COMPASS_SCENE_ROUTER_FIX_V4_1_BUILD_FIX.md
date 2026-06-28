# Defense Compass Scene Router V4.1 Build Fix

## Fixed

- Flutter release build failed at `lib/defense_compass/defense_compass_home_page.dart:704` with:
  - `Error: Not a constant expression.`
- Root cause: `TextField.decoration` was declared as `const InputDecoration(...)`, but `labelText` used runtime scene routing expression `_specFor(_scene).inputLabel`.
- Fix: removed `const` from that `InputDecoration` so the selected scene can dynamically update the input label.

## Changed file

- `lib/defense_compass/defense_compass_home_page.dart`

## Local verification recommendation

```bash
flutter pub get
dart format lib/defense_compass lib/pages/ai_prompt_settings_page.dart lib/main.dart
flutter analyze
flutter build apk --release
```
