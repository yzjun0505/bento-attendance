allprojects {
    repositories {
        google()
        mavenCentral()
        maven(url = "https://mvn.getui.com/nexus/content/repositories/releases/")
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val project = this
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    project.evaluationDependsOn(":app")

    pluginManager.withPlugin("com.android.library") {
        val android = project.extensions.getByName("android")
        if (android is com.android.build.gradle.BaseExtension) {
            // Override to 36 as it's installed and required by some plugins
            android.compileSdkVersion("android-36")
            if (android.namespace == null) {
                android.namespace = "com.example.missingnamespace.${project.name.replace("-", "_")}"
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
