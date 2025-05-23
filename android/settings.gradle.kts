pluginManagement {
    // ✅ flutter.sdk 경로 로드
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val path = properties.getProperty("flutter.sdk")
        requireNotNull(path) { "flutter.sdk not set in local.properties" }
    }

    // ✅ Flutter tools include
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// ✅ 플러그인 선언 (불러오기만 하고 실제 적용은 app/build.gradle.kts)
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.0" apply false
    id("org.jetbrains.kotlin.android") version "1.8.22" apply false
}

// ✅ 앱 모듈 포함
include(":app")

// ✅ .aar 파일을 인식하기 위한 설정
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_PROJECT)
    repositories {
        google()
        mavenCentral()

        // ✅ app/libs 안의 .aar 파일을 인식
        flatDir {
            dirs("app/libs")
        }
    }
}
