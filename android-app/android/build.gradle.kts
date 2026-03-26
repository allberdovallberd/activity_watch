import com.android.build.api.dsl.ApplicationExtension
import com.android.build.api.dsl.LibraryExtension

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
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Compatibility workaround for older Flutter plugins that don't define
// `android.namespace` (required by AGP 8+).
subprojects {
    pluginManager.withPlugin("com.android.library") {
        extensions.configure<LibraryExtension> {
            compileSdk = 36
        }
        val androidExt = extensions.findByName("android") ?: return@withPlugin
        val getNamespace =
            androidExt.javaClass.methods.firstOrNull {
                it.name == "getNamespace" && it.parameterCount == 0
            } ?: return@withPlugin
        val setNamespace =
            androidExt.javaClass.methods.firstOrNull {
                it.name == "setNamespace" && it.parameterCount == 1
            } ?: return@withPlugin

        val currentNamespace = getNamespace.invoke(androidExt) as? String
        if (!currentNamespace.isNullOrBlank()) {
            return@withPlugin
        }

        val manifestFile = file("src/main/AndroidManifest.xml")
        if (!manifestFile.exists()) {
            return@withPlugin
        }

        val manifestText = manifestFile.readText()
        val packageMatch = Regex("package=\"([^\"]+)\"").find(manifestText)
        val manifestPackage = packageMatch?.groupValues?.getOrNull(1)
        if (!manifestPackage.isNullOrBlank()) {
            setNamespace.invoke(androidExt, manifestPackage)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
