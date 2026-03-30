plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.chaquo.python")
}

android {
    namespace = "com.example.giza"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17 // Updated for AGP 8.5
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.giza"
        
        // Chaquopy 16+ usually requires minSdk 24. 
        // If your flutter.minSdkVersion is lower, hardcode 24 here.
        minSdk = 24 
        
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Correct Kotlin DSL syntax for ndk
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// In Kotlin DSL, the Chaquopy config is usually a top-level block
chaquopy {
    defaultConfig {
        // version = "3.11"
        pip {
            install("yt-dlp")
            install ("requests")
        }
    }
}

flutter {
    source = "../.."
}