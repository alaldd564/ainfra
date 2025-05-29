buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
    classpath("com.android.tools.build:gradle:8.2.0")
    classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.10") // ✅ 이 줄 추가
    classpath("com.google.gms:google-services:4.3.15")
}

}

// ✅ 전체 프로젝트용 리포지토리 설정
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ✅ 루트 빌드 디렉토리 변경
val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    // ✅ 하위 모듈 빌드 디렉토리도 재설정
    val newSubprojectBuildDir = newBuildDir.dir(name)
    layout.buildDirectory.set(newSubprojectBuildDir)

    // ✅ app 모듈을 항상 평가
    evaluationDependsOn(":app")

    // ✅ 각 서브모듈에서도 리포지토리 사용 가능하도록 설정
    repositories {
        google()
        mavenCentral()
        flatDir {
            dirs("libs") // .aar 등 수동 의존성 파일 있을 경우
        }
    }
}

// ✅ clean 작업
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
