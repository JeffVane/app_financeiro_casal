# Correção para Google Tink (usado pelo Supabase)
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

-keep class com.google.errorprone.annotations.** { *; }
-dontwarn com.google.errorprone.annotations.**

-keep class javax.annotation.** { *; }
-dontwarn javax.annotation.**
