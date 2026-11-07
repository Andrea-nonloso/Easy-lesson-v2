import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 3.8: notifiche push dei messaggi ad app chiusa (Firebase Cloud Messaging). Solo se c'è android/app/google-services.json:
// non è nel repository pubblico (.gitignore); in GitHub Actions lo scrive il segreto GOOGLE_SERVICES_JSON.
// Senza, l'app si costruisce e funziona uguale: Push.kt vede che Firebase non c'è e non fa niente.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Chiave di firma per le release (android/key.properties, mai nel repository).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "it.easylesson.easy_lesson"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "it.easylesson.easy_lesson"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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
        release {
            // Con key.properties la firma e' sempre la stessa e gli aggiornamenti si
            // installano sopra; senza, si usa la chiave di debug (solo per prove sul PC).
            // In CI (GitHub Actions) senza chiave la build si ferma: mai una release con la chiave di debug.
            if (!keystorePropertiesFile.exists() && System.getenv("CI") == "true") {
                throw GradleException("Manca android/key.properties: release Android senza firma vera bloccata")
            }
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 2.7.0: Block Store di Google, per ritrovare il codice Easy Lesson su un telefono nuovo (CodeVault.kt).
    implementation("com.google.android.gms:play-services-auth-blockstore:16.4.0")
    // 3.8: notifiche push (Push.kt). Senza google-services.json Firebase non parte.
    implementation(platform("com.google.firebase:firebase-bom:35.0.2"))
    implementation("com.google.firebase:firebase-messaging")
}
