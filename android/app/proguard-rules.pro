# ── MOBI ProGuard / R8 Keep Rules ──────────────────────────────────

# ── Flutter ──
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── TFLite Flutter (BioPay ML) ──
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**

# ── Google ML Kit (Face Detection) ──
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
-keep class com.google.android.gms.internal.mlkit_vision_face.** { *; }

# ── Camera Plugin ──
-keep class io.flutter.plugins.camera.** { *; }

# ── Mobile Scanner (QR) ──
-keep class com.google.zxing.** { *; }
-dontwarn com.google.zxing.**

# ── Google Maps ──
-keep class com.google.android.gms.maps.** { *; }

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
