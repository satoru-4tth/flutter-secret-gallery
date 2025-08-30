println(">>> Gradle=" + gradle.gradleVersion)
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ✅ projectDirectory を基準にする（自己参照しない）
val rootBuildDirProvider = layout.projectDirectory.dir("../../build")
layout.buildDirectory.set(rootBuildDirProvider)

subprojects {
    layout.buildDirectory.set(rootProject.layout.buildDirectory.dir(name))
}

tasks.register<Delete>("clean") {
    delete(layout.buildDirectory)
}
