# R8 / ProGuard rules for the release build.
#
# AGP's default proguard-android-optimize.txt covers the Android SDK
# itself. This file holds the rules that are specific to Flutter,
# Shorebird, and the third-party plugins we pull in via pubspec.
# Re-test the release build (`flutter build appbundle --release`)
# after touching this file — R8 errors only surface at minification
# time, not during `flutter analyze`.

# ── Flutter engine ──────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── Shorebird OTA engine ────────────────────────────────────────────
# Shorebird's native bridge is invoked via JNI — strip nothing.
-keep class dev.shorebird.** { *; }
-keep class shorebird.** { *; }

# ── Kotlin coroutines (used by several plugins) ─────────────────────
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

# ── flutter_local_notifications + receivers ─────────────────────────
-keep class com.dexterous.** { *; }

# ── GMS / Firebase (FCM, Crashlytics if added later) ────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ── Reflection-driven JSON (json_annotation/freezed generated) ──────
# The model classes themselves are reachable via the generated *.g.dart
# code paths, but R8 occasionally trims their `<init>` when only
# reflection holds them. Keep model constructors defensively.
-keepclassmembers class * {
    @kotlinx.serialization.Serializable <fields>;
}

# ── flutter_secure_storage (uses Tink under the hood on min < 23) ───
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# ── Razorpay / payment SDKs (if added later) ────────────────────────
# (none right now — leave block for future drop-in)

# ── Flutter deferred-components (Play Core SplitInstall) ────────────
# FlutterPlayStoreSplitApplication references com.google.android.play
# .core.splitinstall.*, but we don't use deferred components. Tell R8
# these missing classes are intentional, otherwise minifyRelease fails
# with "Missing classes detected while running R8".
-dontwarn com.google.android.play.core.**
-keep class io.flutter.embedding.android.FlutterPlayStoreSplitApplication { *; }
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

# ── Suppress noisy warnings from optional deps ──────────────────────
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
