import java.util.Properties
import java.io.FileInputStream

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.serialization)
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
            buildConfigField("Boolean", "DEBUG_LOGGING", "true")
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

    testImplementation(libs.junit)
}
