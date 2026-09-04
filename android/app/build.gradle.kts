plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.gestor_tareas"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Requerido por flutter_local_notifications 17.x — traduce APIs
        // modernas de Java (java.time) para funcionar en Android antiguos.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.gestor_tareas"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")

            // DIAGNÓSTICO TEMPORAL: deshabilitamos la minificación de R8
            // para descartar completamente que sea culpable de que las
            // notificaciones programadas no lleguen. Si con esto funciona,
            // afinamos las reglas de proguard. Si no funciona, es otro
            // problema y podemos re-habilitar.
            isMinifyEnabled = false
            isShrinkResources = false

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

// Excluye la vieja Android Support Library. El paquete
// `disable_battery_optimization` la arrastra transitivamente y choca
// con `androidx.core` (duplicate classes en INotificationSideChannel,
// ResultReceiver, etc.). Todo el ecosistema moderno usa AndroidX, así
// que esta exclusión es segura y estándar.
configurations.all {
    exclude(group = "com.android.support")
}

dependencies {
    // Necesario junto con `isCoreLibraryDesugaringEnabled = true`.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
