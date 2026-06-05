# Build Fix: Health Connect Kotlin suspend readRecords

## Problem
GitHub Actions failed during `:app:compileReleaseKotlin` with errors like:

```text
HealthDietHealthConnectChannel.kt:258:42 Suspension functions can only be called within coroutine body.
```

## Cause
`HealthConnectClient.readRecords(...)` is a Kotlin `suspend` function. The helper `readSafely(...)` accepted a normal lambda `block: () -> Unit`, so calls to `readRecords(...)` inside that lambda were not considered to be inside a suspend context by the Kotlin compiler.

## Fix
Changed `readSafely` to accept a suspend lambda:

```kotlin
private suspend fun readSafely(
    map: MutableMap<String, Any?>,
    key: String,
    block: suspend () -> Unit
)
```

`handleReadToday(...)` is already a suspend function and is called inside `scope.launch`, so all Health Connect reads now compile inside a coroutine context.
