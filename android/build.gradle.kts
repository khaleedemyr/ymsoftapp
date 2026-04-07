allprojects {
    repositories {
        google()
        mavenCentral()
        // Tambahkan repository alternatif untuk Flutter native libraries
        maven {
            url = uri("https://storage.googleapis.com/download.flutter.io")
        }
        // Repository tambahan jika Maven Central down
        maven {
            url = uri("https://repo1.maven.org/maven2")
        }
        // JitPack sebagai fallback
        maven {
            url = uri("https://www.jitpack.io")
        }
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
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
