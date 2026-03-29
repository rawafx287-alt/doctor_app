import java.io.File

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

<<<<<<< HEAD
// Keep main Flutter APK output at <project>/build/app (Flutter tooling expects this).
// Move *plugin* module intermediates to LOCALAPPDATA so OneDrive does not lock
// build/firebase_auth, build/cloud_firestore, etc. during Gradle deletes.
=======
// Keep Flutter APK output at <project>/build/app/outputs/...
// Move plugin modules (firebase_auth, cloud_firestore, etc.) to LOCALAPPDATA
// so OneDrive/antivirus do not lock build/firebase_auth/... during Gradle deletes.
>>>>>>> 4d879aa05e50f5d2db3a2e7c6a92215aa64c62e6
val androidDir: File = rootProject.layout.projectDirectory.asFile
val flutterProjectBuild: File = File(androidDir.parentFile, "build").apply { mkdirs() }
val pluginBuildRoot: File =
    File(
        System.getenv("LOCALAPPDATA")
            ?: File(System.getProperty("user.home"), "AppData${File.separator}Local").absolutePath,
        "doctor_app_flutter_plugins_build",
    ).apply { mkdirs() }

rootProject.layout.buildDirectory.set(flutterProjectBuild)

subprojects {
    val target: File =
        if (project.name == "app") {
            File(flutterProjectBuild, "app")
        } else {
            File(pluginBuildRoot, project.name)
        }
    target.mkdirs()
    project.layout.buildDirectory.set(target)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
    delete(pluginBuildRoot)
}
