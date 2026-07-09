# mobile_scanner (ML Kit barcode + CameraX) breaks under R8 shrinking in
# release builds — the scanner throws a NullPointerException on startup and
# the camera never opens. Keep the ML Kit / Play Services vision classes.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.vision.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-keep class dev.steenbakker.mobile_scanner.** { *; }
-dontwarn com.google.mlkit.**
