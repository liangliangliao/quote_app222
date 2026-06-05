# Build fix: WorkManager ListenableFuture classpath

## Error from GitHub Actions

```text
NormalWorker.java:16: error: cannot access ListenableFuture
class file for com.google.common.util.concurrent.ListenableFuture not found
Execution failed for task ':app:compileReleaseJavaWithJavac'.
```

## Cause

WorkManager's Java API references `com.google.common.util.concurrent.ListenableFuture` through `ListenableWorker`/`Worker`.

The previous fix added `com.google.guava:listenablefuture:1.0`, but Gradle can still resolve the standalone artifact to the empty placeholder:

```text
com.google.guava:listenablefuture:9999.0-empty-to-avoid-conflict-with-guava
```

That placeholder intentionally contains no classes, so release Java compilation still cannot find `ListenableFuture`.

## Fix

Updated `android/app/build.gradle`:

```gradle
configurations.configureEach {
    exclude group: "com.google.guava", module: "listenablefuture"
    ...
}

dependencies {
    implementation "com.google.guava:guava:32.1.3-android"
    implementation "androidx.concurrent:concurrent-futures:1.1.0"
}
```

The full Guava Android artifact provides the missing `ListenableFuture` class, while excluding the standalone artifact avoids the empty-placeholder conflict.
