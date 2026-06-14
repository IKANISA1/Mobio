plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

fun propOrEnv(name: String): String =
    (project.findProperty(name) as String?)
        ?: System.getenv(name)
        ?: ""

android {
    namespace = "com.momobio.app"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.momobio.app"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"

        buildConfigField("String", "SUPABASE_URL", "\"${propOrEnv("SUPABASE_URL")}\"")
        buildConfigField("String", "SUPABASE_ANON_KEY", "\"${propOrEnv("SUPABASE_ANON_KEY")}\"")
    }

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("androidx.work:work-runtime-ktx:2.11.0")
}
