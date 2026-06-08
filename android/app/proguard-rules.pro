# ── MOBI ProGuard / R8 Keep Rules ──────────────────────────────────

# ── Flutter ──
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── Supabase / OkHttp / Retrofit ──
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }

# ── Gson (used by some plugins) ──
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# ── General ──
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ── Play Core deferred components (not used, but Flutter engine references them) ──
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# ── Flutter Local Notifications ──
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# ── Firebase Messaging ──
-keep class com.google.firebase.messaging.** { *; }
-dontwarn com.google.firebase.messaging.**
