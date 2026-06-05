# Build fix: IntimacyWallpaperChannel Kotlin type mismatch

## Error

`android/app/src/main/kotlin/com/example/quote_app/IntimacyWallpaperChannel.kt:24:73`

Kotlin compile failed because `numberArg(...)` declares its fallback parameter as `Double`, but the `style` fallback was passed as integer literal `0`.

## Fix

Changed:

```kotlin
numberArg(call, "style", 0).toInt()
```

To:

```kotlin
numberArg(call, "style", 0.0).toInt()
```

This removes the Kotlin compile-time type mismatch while preserving the saved `style` value as an `Int` in SharedPreferences.
