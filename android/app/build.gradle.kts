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
    namespace = "community.momento.app"
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
        applicationId = "community.momento.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Google Maps Android SDK key. Resolution order:
        //   1. GOOGLE_MAPS_KEY_ANDROID env var (CI / local shell)
        //   2. `googleMapsKeyAndroid` in android/local.properties (gitignored)
        //   3. empty string — map renders watermarked / blank.
        val mapsKey = System.getenv("GOOGLE_MAPS_KEY_ANDROID")
            ?: run {
                val props = java.util.Properties()
                val f = rootProject.file("local.properties")
                if (f.exists()) f.inputStream().use { props.load(it) }
                props.getProperty("googleMapsKeyAndroid", "")
            }
        manifestPlaceholders["GOOGLE_MAPS_KEY_ANDROID"] = mapsKey
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
