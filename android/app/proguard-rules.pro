# Flutter wrapper — keep Flutter embedding + plugin entry points.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# record / audio plugin
-keep class com.llfbandit.record.** { *; }

# Keep annotations used by reflection.
-keepattributes *Annotation*

# Suppress notes about missing optional classes.
-dontwarn io.flutter.embedding.**
