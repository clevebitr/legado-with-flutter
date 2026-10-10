plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.flutter_reader"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // 发布前必须替换为真实 applicationId（见 docs/dev/platform.md §8「已知待办」）。
        applicationId = "com.example.flutter_reader"
        // minSdk 显式固定为 26（Android 8.0）：flutter_js_plus 要求 Android 8+，
        // 而 Flutter 3.47 的默认值为 24，依赖默认值会造成文档与构建不一致。
        // 见 docs/dev/platform.md §1（C-PLT-5）。
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // 发布前必须配置真实签名（见 docs/dev/platform.md §8「已知待办」）。
            // 当前使用 debug 签名，使 `flutter run --release` 可运行。
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
