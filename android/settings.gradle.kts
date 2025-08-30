pluginManagement {
    // Read flutter.sdk from local.properties
    val props = java.util.Properties()
    file("local.properties").inputStream().use { props.load(it) }
    val flutterSdk: String = props.getProperty("flutter.sdk")
        ?: error("flutter.sdk not set in local.properties")

    // Bring in Flutter's Gradle build
    includeBuild("$flutterSdk/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }

    // Manage versions here (do not apply here)
    plugins {
        id("com.android.application") version "8.5.2" apply false
        id("com.android.library")    version "8.5.2" apply false
        id("org.jetbrains.kotlin.android") version "1.9.24" apply false
        // dev.flutter.flutter-gradle-plugin は includeBuild から提供されるのでここに書かない
    }
}

// Flutter loader is applied in settings
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
}

include(":app")
