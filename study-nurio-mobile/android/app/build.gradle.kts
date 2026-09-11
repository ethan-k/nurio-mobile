import java.util.Properties
import java.io.FileInputStream
import groovy.json.JsonSlurper

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.serialization)
}

val firebaseSourceFile = rootProject.file(
    "../../../nurio_study/mobile_certs/nurio-study-google-services.json"
)
val firebaseStagedFile = file("google-services.json")
val firebaseConfigured = firebaseSourceFile.isFile

val firebaseConfig = firebaseSourceFile.takeIf { it.isFile }?.let { source ->
    runCatching { JsonSlurper().parse(source) as? Map<*, *> }.getOrNull()
}
val firebaseProjectInfo = firebaseConfig?.get("project_info") as? Map<*, *>
val firebaseProjectId = firebaseProjectInfo?.get("project_id") as? String
val firebaseClients = firebaseConfig?.get("client") as? List<*>
val firebasePackageNames = firebaseClients.orEmpty().mapNotNull { client ->
    val clientInfo = (client as? Map<*, *>)?.get("client_info") as? Map<*, *>
    val androidClientInfo = clientInfo?.get("android_client_info") as? Map<*, *>
    androidClientInfo?.get("package_name") as? String
}

if (firebaseConfigured &&
    (firebaseProjectId != "nurio-prod" || "com.nurio.study.android" !in firebasePackageNames)
) {
    throw GradleException(
        "Study Firebase configuration must target nurio-prod and com.nurio.study.android"
    )
}

val prepareStudyFirebaseConfig = tasks.register("prepareStudyFirebaseConfig") {
    if (firebaseConfigured) inputs.file(firebaseSourceFile)
    outputs.file(firebaseStagedFile)
    doLast {
        if (!firebaseConfigured) {
            throw GradleException("Study production Firebase configuration is missing")
        }
        firebaseSourceFile.copyTo(firebaseStagedFile, overwrite = true)
    }
}

if (firebaseConfigured) {
    apply(plugin = "com.google.gms.google-services")
    apply(plugin = "com.google.firebase.crashlytics")

    tasks.matching {
        it.name.startsWith("process") && it.name.endsWith("GoogleServices")
    }.configureEach {
        dependsOn(prepareStudyFirebaseConfig)
    }
}

val verifyStudyFirebaseConfig = tasks.register("verifyStudyFirebaseConfig") {
    doLast {
        if (!firebaseConfigured) {
            throw GradleException("Study production Firebase configuration is missing")
        }
    }
}

tasks.matching {
    it.name == "preProductionDebugBuild" || it.name == "preReleaseBuild"
}.configureEach {
    dependsOn(verifyStudyFirebaseConfig)
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

val verifyKakaoNativeAppKey = tasks.register("verifyKakaoNativeAppKey") {
    doLast {
        if (!kakaoAuthEnabled) {
            throw GradleException(
                "NURIO_STUDY_KAKAO_NATIVE_APP_KEY is required for production and release builds"
            )
        }
    }
}

tasks.matching {
    it.name == "preProductionDebugBuild" || it.name == "preReleaseBuild"
}.configureEach {
    dependsOn(verifyKakaoNativeAppKey)
}

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
    compileSdk = 36

    defaultConfig {
        applicationId = "com.nurio.study.android"
        minSdk = 28
        targetSdk = 36
        versionCode = 7
        versionName = "1.0.2"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        manifestPlaceholders["crashlyticsCollectionEnabled"] = true
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
            manifestPlaceholders["crashlyticsCollectionEnabled"] = false
            buildConfigField("String", "BASE_URL", "\"https://study.nurio.kr\"")
            buildConfigField("Boolean", "DEBUG_LOGGING", "false")
        }
        create("productionDebug") {
            initWith(getByName("debug"))
            manifestPlaceholders["crashlyticsCollectionEnabled"] = false
            buildConfigField("String", "BASE_URL", "\"https://study.nurio.kr\"")
            isDebuggable = true
            signingConfig = signingConfigs.getByName("debug")
        }
        release {
            manifestPlaceholders["crashlyticsCollectionEnabled"] = true
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
    implementation(libs.firebase.crashlytics)

    testImplementation(libs.junit)
}
