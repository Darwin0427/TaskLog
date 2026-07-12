# =========================================================================
# ProGuard / R8 rules for TaskLog release builds.
# =========================================================================

# --- Preservar información necesaria para reflection (usada por Gson) ----
# El plugin flutter_local_notifications persiste notificaciones programadas
# usando Gson internamente. Gson usa TypeToken<T> con reflection, que
# requiere que las firmas genéricas se conserven después del minificado.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# --- Gson / TypeToken --------------------------------------------------
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep public class * implements java.lang.reflect.Type
-keep class sun.misc.Unsafe { *; }
-dontwarn com.google.gson.**

# --- awesome_notifications --------------------------------------------
# El plugin usa reflection sobre sus clases internas al programar
# notificaciones con WorkManager.
-keep class me.carda.awesome_notifications.** { *; }
-keep enum me.carda.awesome_notifications.** { *; }
-dontwarn me.carda.awesome_notifications.**

# --- Firebase ---------------------------------------------------------
# Buenas prácticas defensivas para no romper Firebase con minificado.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
