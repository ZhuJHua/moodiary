import groovy.json.JsonOutput
import groovy.json.JsonSlurper
import java.util.Properties
import java.util.TreeMap

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

val releaseKeystore = localProperties.getProperty("storeFile")
    ?.takeIf { it.isNotBlank() }
    ?.let { rootProject.file(it) }
    ?: file("key.jks")
val releaseKeyAlias = localProperties.getProperty("keyAlias")
    ?.takeIf { it.isNotBlank() }
    ?: "key0"
val releaseStorePassword = localProperties.getProperty("storePassword")
val releaseKeyPassword = localProperties.getProperty("keyPassword")
val hasReleaseSigning = releaseKeystore.isFile &&
    !releaseStorePassword.isNullOrBlank() && !releaseKeyPassword.isNullOrBlank()

android {
    namespace = "cn.yooss.moodiary"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    // Omit Google Play's DependencyInfoBlock (0x504B4453) for F-Droid.
    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("config") {
                storeFile = releaseKeystore
                storePassword = releaseStorePassword
                keyPassword = releaseKeyPassword
                keyAlias = releaseKeyAlias
                enableV3Signing = true
            }
        }
    }

    val appSigningConfig = signingConfigs.getByName(
        if (hasReleaseSigning) "config" else "debug",
    )
    if (!hasReleaseSigning) {
        logger.lifecycle("Local signing is unavailable; using the default Android debug keystore.")
    }

    defaultConfig {
        applicationId = "cn.yooss.moodiary"
        minSdk = 28
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

    flavorDimensions += "channel"
    productFlavors {
        create("production") {
            dimension = "channel"
        }
        create("alpha") {
            dimension = "channel"
            applicationIdSuffix = ".alpha"
        }
    }

    buildTypes {
        release {
            signingConfig = appSigningConfig
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
        debug {
            signingConfig = appSigningConfig
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
        maybeCreate("profile").apply {
            signingConfig = appSigningConfig
            applicationIdSuffix = ".profile"
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

tasks.configureEach {
    if (name.startsWith("copyFlutterAssets")) {
        doLast {
            fun canonicalizeJson(value: Any?): Any? = when (value) {
                is Map<*, *> -> TreeMap<String, Any?>().apply {
                    for ((k, v) in value) {
                        put(k.toString(), canonicalizeJson(v))
                    }
                }
                is List<*> -> value.map(::canonicalizeJson)
                else -> value
            }
            val manifest = outputs.files.singleFile.resolve("flutter_assets/NativeAssetsManifest.json")
            if (manifest.isFile) {
                val parsed = JsonSlurper().parse(manifest)
                manifest.writeText(JsonOutput.toJson(canonicalizeJson(parsed)), Charsets.UTF_8)
            }
        }
    }
}
