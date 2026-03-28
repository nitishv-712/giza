pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
        maven { url = uri("https://chaquo.com/maven") }
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // UPGRADE AGP to at least 8.6.0 (or 8.7.0)
    id("com.android.application") version "8.6.0" apply false
    // UPGRADE Kotlin to 2.1.0
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    // UPGRADE Chaquopy to 17.0.0 (Supports AGP 8.6+)
    id("com.chaquo.python") version "17.0.0" apply false
}

include(":app")
