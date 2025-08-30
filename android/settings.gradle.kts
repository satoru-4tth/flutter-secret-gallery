import java.util.Properties
import java.io.File

// --- Flutter SDK パスの解決 ---
val localProps = Properties().apply {
    val f = File(rootDir, "local.properties")
    require(f.exists()) { "local.properties が見つかりません。flutter.sdk を設定してください。" }
    f.inputStream().use { load(it) }
}
val flutterSdkPath = localProps.getProperty("flutter.sdk")
    ?: error("local.properties に flutter.sdk がありません。")

pluginManagement {
    repositories {
        // この順序を厳守：google -> mavenCentral -> portal
        google()
        mavenCentral()
        gradlePluginPortal()
    }

    // バージョン管理のみ（ここでは apply しない）
    plugins {
        // Gradle 8.7 を使っているなら AGP は 8.7 系に合わせるのが堅い
        id("com.android.application") version "8.7.2"
        id("com.android.library")    version "8.7.2"
        id("org.jetbrains.kotlin.android") version "2.0.20"
    }

    resolutionStrategy {
        eachPlugin {
            val pid = requested.id.id
            if (pid.startsWith("org.jetbrains.kotlin")) {
                useVersion("2.0.20")
            }
            if (pid == "com.android.application" || pid == "com.android.library") {
                useVersion("8.7.2")
            }
        }
    }

    // Flutter の Gradle を取り込む（必ず flutterSdkPath を使う）
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
}

dependencyResolutionManagement {
    // settings のリポを優先して使う
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
    }
}

include(":app")
