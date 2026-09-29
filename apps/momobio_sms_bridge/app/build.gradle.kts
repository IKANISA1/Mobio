import java.net.URI

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

fun propOrEnv(name: String): String =
    (project.findProperty(name) as String?)
        ?: System.getenv(name)
        ?: ""

// Never embed unescaped configuration into generated Java source.
fun configLiteral(value: String): String = "\"" + value.replace("\\", "\\\\")
    .replace("\"", "\\\"").replace("\r", "\\r").replace("\n", "\\n") + "\""
val releaseRequested = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true) || it.substringAfterLast(':') in setOf("assemble", "build", "bundle")
}
val signingPath = propOrEnv("COLLECTOR_KEYSTORE_PATH")
val keyAliasValue = propOrEnv("COLLECTOR_KEY_ALIAS")
val storePass = propOrEnv("COLLECTOR_KEYSTORE_PASSWORD")
val keyPass = propOrEnv("COLLECTOR_KEY_PASSWORD")
val policyVersion = propOrEnv("COLLECTOR_POLICY_VERSION")
val senderAllowlist = propOrEnv("COLLECTOR_ALLOWED_SENDERS")
val receiptMarkers = propOrEnv("COLLECTOR_RECEIPT_MARKERS")
if (releaseRequested) {
    require(signingPath.isNotBlank() && file(signingPath).isFile && keyAliasValue.isNotBlank() &&
        storePass.isNotBlank() && keyPass.isNotBlank()) { "Managed collector release signing is required; no debug signing fallback" }
    val senders = senderAllowlist.split(',').map { it.trim() }.filter { it.isNotBlank() }.toSet()
    val markers = receiptMarkers.split(',').map { it.trim() }.filter { it.isNotBlank() }.toSet()
    require(policyVersion.matches(Regex("[A-Za-z0-9._-]{1,64}")) && senders.size in 1..20 && markers.size in 1..20 &&
        senders.all { it.length in 1..64 && it.none { c -> c < ' ' } } &&
        markers.all { it.length in 3..100 && it.none { c -> c < ' ' } }) {
        "Approved collector receipt-filter configuration is required"
    }
    val endpoint = URI(propOrEnv("SUPABASE_URL"))
    require(endpoint.scheme == "https" && !endpoint.host.isNullOrBlank() && endpoint.rawUserInfo == null &&
        endpoint.rawQuery == null && endpoint.rawFragment == null && endpoint.port in setOf(-1, 443) &&
        endpoint.rawPath.orEmpty() in setOf("", "/") && propOrEnv("SUPABASE_ANON_KEY").isNotBlank()) {
        "Public backend configuration is required for an operational release"
    }
}

android {
    namespace = "com.momobio.app"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.momobio.app"
        minSdk = 26
        targetSdk = 36
        versionCode = 2
        versionName = "1.0.1"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        buildConfigField("String", "COLLECTOR_POLICY_VERSION", configLiteral(policyVersion))
        buildConfigField("String", "COLLECTOR_ALLOWED_SENDERS", configLiteral(senderAllowlist))
        buildConfigField("String", "COLLECTOR_RECEIPT_MARKERS", configLiteral(receiptMarkers))

        buildConfigField("String", "SUPABASE_URL", configLiteral(propOrEnv("SUPABASE_URL")))
        buildConfigField("String", "SUPABASE_ANON_KEY", configLiteral(propOrEnv("SUPABASE_ANON_KEY")))
    }

    signingConfigs {
        if (releaseRequested) {
            create("collectorRelease") {
                storeFile = file(signingPath)
                storePassword = storePass
                keyAlias = keyAliasValue
                keyPassword = keyPass
            }
        }
    }

    buildFeatures {
        buildConfig = true
    }

    // Component tests only: its manifest has no permissions or app components.
    // It cannot collect SMS, start the bridge UI or contact the backend.
    buildTypes {
        getByName("release") {
            if (releaseRequested) signingConfig = signingConfigs.getByName("collectorRelease")
        }
        create("qa") {
            initWith(getByName("debug"))
            applicationIdSuffix = ".qa"
            buildConfigField("String", "COLLECTOR_POLICY_VERSION", "\"\"")
            buildConfigField("String", "COLLECTOR_ALLOWED_SENDERS", "\"\"")
            buildConfigField("String", "COLLECTOR_RECEIPT_MARKERS", "\"\"")
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
