import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.app_financeiro_casal"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.app_financeiro_casal"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ---------------- CONFIGURAÇÃO DE ASSINATURA ----------------
    val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("app/keystore/key.properties")

if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { stream ->
        keystoreProperties.load(stream)
    }
} else {
    println("❌ key.properties não encontrado em: ${keystorePropertiesFile.absolutePath}")
}

signingConfigs {
    maybeCreate("release").apply {
        keyAlias = keystoreProperties["keyAlias"] as String?
        keyPassword = keystoreProperties["keyPassword"] as String?

        val storeFilePath = keystoreProperties["storeFile"]?.toString()
        if (storeFilePath != null && rootProject.file(storeFilePath).exists()) {
            storeFile = rootProject.file(storeFilePath)
        } else {
            println("❌ ARQUIVO DE KEYSTORE NÃO ENCONTRADO EM: $storeFilePath")
        }

        storePassword = keystoreProperties["storePassword"] as String?
    }
}

    // ------------------------------------------------------------

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                file("proguard-rules.pro")
            )
        }
    }
}

flutter {
    source = "../.."
}
