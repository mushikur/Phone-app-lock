import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/**
 * Release signing details, kept out of the repository.
 *
 * Create `android/key.properties` from `key.properties.example` and point it at
 * your keystore. Without it the release build falls back to the debug key so the
 * project still builds and can be tested — but such a build must never be
 * published, and the build prints a warning saying so.
 */
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) {
        file.inputStream().use(::load)
    }
}
val hasReleaseKeystore = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.samirlock.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.samirlock.app"
        // Pinned rather than following the Flutter SDK: this app depends closely
        // on foreground service and background-start behaviour, and those rules
        // change with the target SDK. Moving them should be a deliberate act
        // followed by testing, not a side effect of upgrading Flutter.
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "Samir Lock: no android/key.properties found, signing the " +
                        "release build with the debug key. Do not publish this build.",
                )
                signingConfigs.getByName("debug")
            }

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

dependencies {
    // AndroidX BiometricPrompt: the official biometric API, and the only one that
    // covers fingerprint below API 28 as well as the modern prompt above it.
    // It brings androidx.fragment, which BiometricPrompt requires its host to be.
    implementation("androidx.biometric:biometric:1.1.0")

    // Test only, never shipped: covers the lock decision rules and the lockout
    // backoff, which decide whether apps stay protected and whether the owner
    // can get back in.
    testImplementation("junit:junit:4.13.2")
}

flutter {
    source = "../.."
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
