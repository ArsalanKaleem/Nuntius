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

// Kept as its own block, separate from evaluationDependsOn below: combining
// them in one subprojects{} block changes evaluation order so that by the
// time this loop reaches :app, evaluationDependsOn(":app") has already
// forced :app to evaluate, and afterEvaluate on an already-evaluated project
// throws "Cannot run Project.afterEvaluate(Action) when the project is
// already evaluated."
subprojects {
    afterEvaluate {
        if (this.hasProperty("android")) {
            configure<com.android.build.gradle.BaseExtension> {
                compileSdkVersion(36)
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