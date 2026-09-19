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
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        buildConfigField("String", "SUPABASE_URL", "\"${propOrEnv("SUPABASE_URL")}\"")
        buildConfigField("String", "SUPABASE_ANON_KEY", "\"${propOrEnv("SUPABASE_ANON_KEY")}\"")
    }

    buildFeatures {
        buildConfig = true
    }

    // Component tests only: its manifest has no permissions or app components.
    // It cannot collect SMS, start the bridge UI or contact the backend.
    buildTypes {
        create("qa") {
            initWith(getByName("debug"))
            applicationIdSuffix = ".qa"
            matchingFallbacks += "debug"
            buildConfigField("String", "SUPABASE_URL", "\"\"")
            buildConfigField("String", "SUPABASE_ANON_KEY", "\"\"")
        }
    }
    testBuildType = "qa"

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
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20250517")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
    androidTestImplementation("androidx.test:runner:1.7.0")
}
