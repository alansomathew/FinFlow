allprojects {
    repositories {
        google()
        mavenCentral()
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

    project.evaluationDependsOn(":app")

    // Some plugins (e.g. another_telephony) ship with older default
    // Java/Kotlin compile targets that don't match this app's JVM 17 (see
    // android/app/build.gradle.kts) and fail the build with "Inconsistent
    // JVM Target Compatibility". Force every OTHER subproject's Java/Kotlin
    // compile tasks to the same target rather than downgrading the app's
    // own toolchain. Skip :app itself -- the evaluationDependsOn above
    // forces it to evaluate early, so by the time this loop reaches :app
    // it's already evaluated and afterEvaluate would throw; :app also
    // already sets JVM 17 directly in its own build.gradle.kts.
    if (project.name != "app") {
        afterEvaluate {
            extensions.findByType<com.android.build.gradle.BaseExtension>()?.apply {
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                compilerOptions {
                    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
