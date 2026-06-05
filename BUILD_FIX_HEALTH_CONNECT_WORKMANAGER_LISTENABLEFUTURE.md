# Health Diet Stage4 Build Fix 2 - WorkManager ListenableFuture

## Error from uploaded GitHub Actions log

```text
NormalWorker.java:16: error: cannot access ListenableFuture
class file for com.google.common.util.concurrent.ListenableFuture not found
Execution failed for task ':app:compileReleaseJavaWithJavac'.
```

## Cause

The app uses AndroidX WorkManager Java worker classes. WorkManager references
`com.google.common.util.concurrent.ListenableFuture`, but the release compile
classpath did not contain the Guava `listenablefuture` artifact. This is a Gradle
dependency graph/classpath issue, not a Dart syntax error.

## Fix

Added direct dependencies in `android/app/build.gradle`:

```gradle
implementation "com.google.guava:listenablefuture:1.0"
implementation "androidx.concurrent:concurrent-futures:1.1.0"
```

This keeps the existing WorkManager version unchanged and only supplies the
missing compile-time classes needed by the existing Java workers.
