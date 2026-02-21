# Hotwire Native ProGuard Rules

# Keep Hotwire Native classes
-keep class dev.hotwire.** { *; }
-keepclassmembers class dev.hotwire.** { *; }

# Keep Bridge Components
-keep class * extends dev.hotwire.core.bridge.BridgeComponent { *; }

# Keep app Hotwire destinations and their annotations for runtime fragment routing.
-keep class com.nurio.android.fragments.** { *; }
-keep @dev.hotwire.navigation.destinations.HotwireDestinationDeepLink class com.nurio.android.fragments.** { *; }

# Keep WebView JavaScript interfaces
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Kotlin coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

# Kotlin serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt

# Suppress warnings for missing classes
-dontwarn javax.lang.model.element.Modifier
