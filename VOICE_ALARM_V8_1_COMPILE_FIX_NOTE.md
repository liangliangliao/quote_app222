# Voice Alarm V8.1 Compile Fix

## Fixed

GitHub Actions failed at:

- `VoiceAlarmActivity.kt:978:30 No value passed for parameter 'sources'`
- `VoiceAlarmActivity.kt:1050:32 No value passed for parameter 'sources'`

Root cause: V8 introduced `isLikelyPlaybackEcho(text: String, sources: List<String>)`, but two call sites still used the legacy one-argument form `isLikelyPlaybackEcho(text)`. The zipped source did not include the compatibility overload, so Kotlin resolved only the two-argument function and failed compilation.

Fix: Added a one-argument overload:

```kotlin
private fun isLikelyPlaybackEcho(text: String): Boolean {
  val alarmText = try { JSONObject(payload).optString("text", "") } catch (_: Throwable) { "" }
  return isLikelyPlaybackEcho(text, listOf(alarmText, lastAssistantSpokenText))
}
```

This keeps the existing call sites valid and routes them through the new playback echo classifier using both alarm text and last AI spoken text as echo sources.

## Verification

- Confirmed both call sites now resolve to the one-argument overload.
- Confirmed zip root is not nested.
- Full Gradle compilation was not run locally because this source package still lacks `android/gradle/wrapper/gradle-wrapper.jar` in the sandbox.
