import java.io.FileInputStream
import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    id("com.google.devtools.ksp")
    id("org.jetbrains.kotlin.plugin.serialization")
}

// Load signing properties from key.properties (not committed to git)
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val isReleaseTaskRequested = gradle.startParameter.taskNames.any { taskName ->
    taskName.contains("Release", ignoreCase = true)
}
if (isReleaseTaskRequested && !keystorePropertiesFile.exists()) {
    throw GradleException(
        "Missing android/key.properties. Release builds must use the production signing config.",
    )
}

val localPropertiesFile = rootProject.file("local.properties")
val localProperties = Properties()
if (localPropertiesFile.exists()) {
    localProperties.load(FileInputStream(localPropertiesFile))
}
android {
    namespace = "rw.mobi.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "rw.mobi.app"
        minSdk = 24
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true

        // TensorFlow Lite's bundled x86_64 binaries are not 16 KB-page compatible.
        // Ship only Android device ABIs in production bundles until upstream x86_64
        // artifacts are rebuilt for the Play requirement.
        ndk {
            abiFilters += setOf("armeabi-v7a", "arm64-v8a")
        }
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // 16 KB page size compatibility (required by Google Play for targetSdk 35+)
    packaging {
        jniLibs {
            useLegacyPackaging = false
            // Strip x86_64 native libs bundled by plugins (ML Kit, TFLite).
            // abiFilters only controls the app module's own NDK output — plugin
            // pre-built .so files bypass it. These x86_64 binaries are NOT
            // 16-KB page aligned and will be rejected by Google Play.
            excludes += setOf("lib/x86_64/**", "lib/x86/**")
        }
    }

}

flutter {
    source = "../.."
}

kotlin {
    sourceSets {
        getByName("main") {
            kotlin.exclude("rw/mobi/app/ledger/**")
        }
    }
}

tasks.withType<org.gradle.api.tasks.SourceTask>().configureEach {
    exclude("rw/mobi/app/ledger/**")
}

ksp {
    arg("room.generateKotlin", "false")
}

dependencies {
    // Core library desugaring (required by flutter_local_notifications for java.time APIs)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Modular Play libraries
    implementation("com.google.android.play:feature-delivery:2.1.0")
    implementation("com.google.android.play:app-update:2.1.0")
    implementation("com.google.android.play:review:2.0.2")

    // Room (offline queue)
    val room = "2.8.4"
    implementation("androidx.room:room-runtime:$room")
    implementation("androidx.room:room-ktx:$room")
    ksp("androidx.room:room-compiler:$room")

    // WorkManager (sync job)
    implementation("androidx.work:work-runtime-ktx:2.10.0")

    // Supabase
    val supabaseBom = "3.0.3"
    implementation(platform("io.github.jan-tennert.supabase:bom:$supabaseBom"))
    implementation("io.github.jan-tennert.supabase:postgrest-kt")
    implementation("io.github.jan-tennert.supabase:realtime-kt")
    implementation("io.github.jan-tennert.supabase:auth-kt")
    implementation("io.github.jan-tennert.supabase:functions-kt")
    implementation("io.ktor:ktor-client-okhttp:3.0.3")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")

    // Security & Encryption
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    implementation("net.zetetic:sqlcipher-android:4.6.1")
    implementation("androidx.sqlite:sqlite-ktx:2.4.0")

    // Export - Excel
    implementation("org.apache.poi:poi:5.3.0")
    implementation("org.apache.poi:poi-ooxml:5.3.0")
}
