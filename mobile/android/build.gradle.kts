allprojects {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    // Pin mmkv_android's dynamic [2.4.3, 2.5) range for reproducible builds.
    configurations.configureEach {
        resolutionStrategy.force("com.tencent:mmkv:2.4.3")
    }
}

subprojects {
    afterEvaluate {
        val targetCompat: (() -> String)? = when (val ext = extensions.findByName("android")) {
            is com.android.build.api.dsl.ApplicationExtension -> {
                ext.compileSdk = 36
                ext.buildToolsVersion = "36.0.0"
                if (ext.namespace == null) {
                    ext.namespace = project.group.toString()
                }
                ({ ext.compileOptions.targetCompatibility.toString() })
            }
            is com.android.build.api.dsl.LibraryExtension -> {
                ext.compileSdk = 36
                ext.buildToolsVersion = "36.0.0"
                if (ext.namespace == null) {
                    ext.namespace = project.group.toString()
                }
                if (project.name == "jni") {
                    ext.defaultConfig.externalNativeBuild.cmake {
                        cFlags.add("-g0")
                        arguments.add("-DCMAKE_SHARED_LINKER_FLAGS=-Wl,--build-id=none")
                    }
                }
                ({ ext.compileOptions.targetCompatibility.toString() })
            }
            else -> null
        }
        if (targetCompat != null) {
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                compilerOptions.jvmTarget.set(
                    project.provider {
                        org.jetbrains.kotlin.gradle.dsl.JvmTarget.fromTarget(targetCompat())
                    },
                )
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
