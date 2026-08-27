plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase wiring, activated by dropping in google-services.json.
//
// The google-services plugin hard-fails the build when that file is missing, so
// it is applied conditionally: no Firebase config means the app still builds and
// runs (in offline practice mode), and the moment the file lands the Firebase
// resource generation kicks in with no further edits.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.lifecycle(
        "TWIN: android/app/google-services.json not found - building " +
            "without Firebase. Multiplayer will be unavailable. See README.md."
    )
}

android {
    namespace = "com.twinnn.twin"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Registered in Firebase as "TWIN Android". Permanent once published to
        // Play, so it must not change after the first release.
        applicationId = "com.twinnn.twin"
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
        }
    }
}

flutter {
    source = "../.."
}
