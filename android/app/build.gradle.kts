import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.khata_finance"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    packaging {
        jniLibs {
            // Arm64-only builds drop the other ABIs' plugin .so files (the
            // Flutter engine already follows --target-platform, but plugin
            // AARs merge .so files for every ABI unless excluded). Pass
            // ORG_GRADLE_PROJECT_khataAbiFilters=arm64-v8a for arm64-only.
            if ((project.findProperty("khataAbiFilters") as? String) == "arm64-v8a") {
                excludes += "lib/armeabi-v7a/**"
                excludes += "lib/x86_64/**"
            }
        }
        resources {
            // Kotlin multiplatform jars (collection, okio, atomicfu) all ship
            // native source-set metadata at colliding paths; it is build
            // metadata, safe to drop from the APK.
            excludes += "nativeMain/**"
            excludes += "nonJvmMain/**"
            excludes += "commonMain/**"
            excludes += "jsMain/**"
            excludes += "wasmJsMain/**"
            excludes += "wasmWasiMain/**"
            excludes += "appleMain/**"
            excludes += "META-INF/kotlin-project-structure-metadata.json"
            excludes += "META-INF/androidx/annotation/annotation/LICENSE.txt"
            excludes += "META-INF/**/LICENSE.txt"
            excludes += "META-INF/**/LICENSE"
            excludes += "META-INF/**/NOTICE.txt"
            excludes += "META-INF/**/NOTICE"
            excludes += "META-INF/LICENSE"
            excludes += "META-INF/LICENSE.txt"
            excludes += "META-INF/NOTICE"
            excludes += "META-INF/NOTICE.txt"
            excludes += "META-INF/DEPENDENCIES"
            excludes += "linuxMain/**"
            excludes += "mingwMain/**"
            excludes += "iosMain/**"
            excludes += "macosMain/**"
            excludes += "tvosMain/**"
            excludes += "watchosMain/**"
            excludes += "androidNativeMain/**"
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.khata_finance"
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
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Use the release keystore when android/key.properties exists;
            // otherwise fall back to debug signing so other machines can build.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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

// Align activity-ktx with activity 1.13.0: older activity-ktx (1.8.1, pulled
// in via fragment-ktx) bundles classes that now live in activity itself,
// which fails checkReleaseDuplicateClasses. Forcing 1.13.0 removes the clash.
configurations.all {
    resolutionStrategy {
        force("androidx.activity:activity-ktx:1.13.0")
        force("androidx.collection:collection-ktx:1.4.2")
    }
    // runtime-annotation ships both -android and -jvm variants with identical
    // classes; keep only the Android one or duplicate-classes fails the build.
    exclude(group = "androidx.compose.runtime", module = "runtime-annotation-jvm")
    exclude(group = "androidx.datastore", module = "datastore-core-jvm")
    exclude(group = "androidx.datastore", module = "datastore-preferences-core-jvm")
}
