# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Geolocator
-keep class com.baseflow.geolocator.** { *; }

# Local notifications
-keep class com.dexterous.** { *; }

# Background service
-keep class id.flutter.flutter_background_service.** { *; }

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}

# Suppress warnings
-dontwarn okhttp3.**
-dontwarn okio.**
