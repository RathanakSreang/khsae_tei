# mobile_scanner relies on Google ML Kit's barcode scanning, which is loaded
# reflectively/dynamically — keep it from being stripped or renamed by R8.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-dontwarn com.google.mlkit.**
