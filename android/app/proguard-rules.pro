-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable,InnerClasses,EnclosingMethod

# Kotlin
#https://stackoverflow.com/questions/33547643/how-to-use-kotlin-with-proguard
#https://medium.com/@AthorNZ/kotlin-metadata-jackson-and-proguard-f64f51e5ed32
-keepclassmembers class **$WhenMappings {
    <fields>;
}
-keep class kotlin.Metadata { *; }
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}

# Android X
-dontwarn androidx.**
-dontwarn com.google.android.material.**
-keep interface androidx.* { *; }
-keep class androidx.** { *; }
-keep class com.google.android.material.** { *; }

# Conservative optimization settings for compatibility
-optimizations !code/simplification/arithmetic,!code/simplification/cast
-optimizationpasses 3
-dontpreverify

# Remove unused code aggressively
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# Dio HTTP client (thay thế RxJava không dùng)
-keep class dio.** { *; }
-dontwarn dio.**

# Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

### Gson uses generic type information stored in a class file when working with fields. Proguard
# removes such information by default, so configure it to keep all of it.
-keepattributes Signature

# For using GSON @Expose annotation
-keepattributes *Annotation*

# Gson specific classes
-keep class sun.misc.Unsafe { *; }
-keep class com.google.gson.stream.** { *; }

# Application classes that will be serialized/deserialized over Gson
-keep class com.google.gson.examples.android.model.** { *; }
-keep class com.google.gson.mckimquyen.android.model.** { *; }

# Prevent proguard from stripping interface information from TypeAdapterFactory,
# JsonSerializer, JsonDeserializer instances (so they can be used in @JsonAdapter)
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Flutter specific optimizations
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }

# GetX state management
-keep class dev.flutter.pigeon.** { *; }

# Essential JSON parsing only (no more unused eKYC/Room)
-keep class org.json.* { *; }

# AppLovin mediation
-keep class com.applovin.** { *; }
-dontwarn com.applovin.**

# Google Play Core (for deferred components)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**
