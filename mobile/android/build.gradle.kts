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
}

subprojects {
    afterEvaluate {
        if (plugins.hasPlugin("com.android.application") ||
            plugins.hasPlugin("com.android.library")
        ) {
            (extensions.getByName("android") as com.android.build.gradle.BaseExtension).apply {
                compileSdkVersion(36)
                buildToolsVersion = "36.0.0"
            }
        }
        extensions.findByName("android")?.let { ext ->
            val android = ext as com.android.build.gradle.BaseExtension
            if (android.namespace == null) {
                android.namespace = project.group.toString()
            }
            // 自带 KGP 的插件（photo_manager 等）若没设 jvmTarget，Kotlin 默认随 JDK(21)，
            // 与其 Java 编译项(17)冲突；统一按各模块 Java targetCompatibility 对齐。
            // provider 惰性读取——targetCompatibility 在 afterEvaluate 时尚未定稿。
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                compilerOptions.jvmTarget.set(
                    project.provider {
                        org.jetbrains.kotlin.gradle.dsl.JvmTarget.fromTarget(
                            android.compileOptions.targetCompatibility.toString(),
                        )
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
