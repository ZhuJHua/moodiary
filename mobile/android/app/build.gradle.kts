import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.reader(Charsets.UTF_8).use { localProperties.load(it) }
}

android {
    namespace = "cn.yooss.moodiary"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    signingConfigs {
        create("config") {
            storeFile = file("key.jks")
            storePassword = localProperties.getProperty("storePassword")
            keyPassword = localProperties.getProperty("keyPassword")
            keyAlias = "key0"
            enableV3Signing = true
        }
    }

    defaultConfig {
        applicationId = "cn.yooss.moodiary"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            abiFilters.clear()
            abiFilters.add("arm64-v8a")
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("config")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
        debug {
            signingConfig = signingConfigs.getByName("config")
            resValue("string", "app_name", "Moodiary Debug")
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
        maybeCreate("profile").apply {
            signingConfig = signingConfigs.getByName("config")
        }
    }

    flavorDimensions += "env"

    productFlavors {
        // 正式包：cn.yooss.moodiary / Moodiary。
        create("prod") {
            dimension = "env"
            isDefault = true
        }
        // 测试包：cn.yooss.moodiary.beta / Moodiary Beta —— 与正式包不同包名，可并存安装。
        create("beta") {
            dimension = "env"
            applicationIdSuffix = ".beta"
            versionNameSuffix = "-beta"
            resValue("string", "app_name", "Moodiary Beta")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.google.android.material:material:1.14.0")
}
