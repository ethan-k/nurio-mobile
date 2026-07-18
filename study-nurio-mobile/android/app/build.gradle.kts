import java.util.Properties
import java.io.FileInputStream
import groovy.json.JsonSlurper

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.serialization)
}

val firebaseConfigFile = file("google-services.json")
val firebaseConfigured = firebaseConfigFile.isFile
if (firebaseConfigured) {
    val config = runCatching {
        JsonSlurper().parse(firebaseConfigFile) as? Map<*, *>
    }.getOrNull()
    val projectInfo = config?.get("project_info") as? Map<*, *>
    val projectId = projectInfo?.get("project_id") as? String
    val clients = config?.get("client") as? List<*>
    val packageNames = clients.orEmpty().mapNotNull { client ->
        val clientInfo = (client as? Map<*, *>)?.get("client_info") as? Map<*, *>
        val androidClientInfo = clientInfo?.get("android_client_info") as? Map<*, *>
        androidClientInfo?.get("package_name") as? String
    }

    if (projectId != "nurio-prod" || "com.nurio.study.android" !in packageNames) {
        throw GradleException(
            "Study Firebase configuration must target nurio-prod and com.nurio.study.android"
        )
    }

    apply(plugin = "com.google.gms.google-services")
}

val keystorePropertiesFile = rootProject.file("keystore.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val kakaoNativeAppKey = providers
    .gradleProperty("NURIO_STUDY_KAKAO_NATIVE_APP_KEY")
    .orElse(providers.environmentVariable("NURIO_STUDY_KAKAO_NATIVE_APP_KEY"))
    .orElse("")
    .get()
    .trim()
val kakaoManifestAppKey = kakaoNativeAppKey.ifBlank { "not_configured" }
val kakaoAuthEnabled = kakaoNativeAppKey.isNotBlank()

fun String.asBuildConfigString(): String =
    "\"" +
        replace("\\", "\\\\")
            .replace("\"", "\\\"")
            .replace("\n", "\\n")
            .replace("\r", "\\r")
            .replace("\t", "\\t") +
        "\""

android {
    namespace = "com.nurio.study.android"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.nurio.study.android"
        minSdk = 28
        targetSdk = 35
        versionCode = 2
        versionName = "1.0.1"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        buildConfigField(
            "String",
            "KAKAO_NATIVE_APP_KEY",
            kakaoNativeAppKey.asBuildConfigString()
        )
        buildConfigField("Boolean", "FIREBASE_CONFIGURED", firebaseConfigured.toString())
        manifestPlaceholders["KAKAO_NATIVE_APP_KEY"] = kakaoManifestAppKey
        manifestPlaceholders["KAKAO_AUTH_ENABLED"] = kakaoAuthEnabled.toString()
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        debug {
            buildConfigField("String", "BASE_URL", "\"https://study.nurio.kr\"")
            buildConfigField("Boolean", "DEBUG_LOGGING", "false")
        }
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            buildConfigField("String", "BASE_URL", "\"https://study.nurio.kr\"")
            buildConfigField("Boolean", "DEBUG_LOGGING", "false")
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    buildFeatures {
        buildConfig = true
    }
}

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(17)
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.appcompat)
    implementation(libs.material)
    implementation(libs.androidx.activity)
    implementation(libs.androidx.constraintlayout)
    implementation(libs.androidx.splashscreen)
    implementation(libs.androidx.browser)
    implementation(libs.kakao.user)
    implementation(libs.kotlinx.serialization.json)

    implementation(libs.hotwire.core)
    implementation(libs.hotwire.navigation.fragments)

    implementation(platform(libs.firebase.bom))
    implementation(libs.firebase.messaging)

    testImplementation(libs.junit)
}
