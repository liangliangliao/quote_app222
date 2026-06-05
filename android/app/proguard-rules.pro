-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

-keep class androidx.work.** { *; }
-keepclassmembers class * {
    @androidx.work.WorkerParameters *;
}

-keep class **.services.** { *; }
-keep class **.wm_dispatcher { *; }
-keep class **.background_tasks { *; }

-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }

-keep class dev.fluttercommunity.plus.androidalarmmanager.** { *; }
-keep class io.flutter.plugins.androidalarmmanager.** { *; }
-keep class **.AlarmService { *; }
-keep class **.AlarmBroadcastReceiver { *; }

-keepnames class * {
    @androidx.annotation.Keep *;
}
-keep class **.MainActivity { *; }
-keep class **.Application { *; }
-keep class **.MyApplication { *; }

-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-dontwarn androidx.**
-dontwarn okio.**
-dontwarn org.jetbrains.**

# Suppress missing class warnings for Google Play Core (deferred components)
-dontwarn com.google.android.play.**
-dontwarn com.google.android.play.core.**
# Keep all app classes to prevent startup stripping issues
-keep class com.example.quote_app.** { *; }

# Added for Baidu / GMS
-keep class com.baidu.location.** { *; }
-dontwarn com.baidu.**
-dontwarn com.google.android.gms.**

# ---- Baidu Map SDK (Map/Search) ----
-dontwarn com.baidu.**
-keep class com.baidu.** { *; }
-keep class vi.com.** { *; }
-keep class com.baidu.vi.** { *; }
# Some Baidu Map releases rely on bgl engine packages; keep them in release builds.
-keep class vi.com.gdi.bgl.android.** { *; }

