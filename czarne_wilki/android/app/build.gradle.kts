plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.czarnewilki"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "app.czarnewilki"
        minSdk = maxOf(28, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Lokalne wnioskowanie (llama.cpp) jest budowane dla arm64-v8a.
        // Aby dodać inne ABI, dopisz je poniżej i przebuduj libllama.so
        // (patrz tools/build_llama_android.sh).
        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }

    buildTypes {
        release {
            // Debug signing dla wygody testów; przed dystrybucją podmień
            // na własny keystore (patrz README, sekcja "Podpisywanie").
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    sourceSets {
        getByName("main") {
            // libllama.so umieszczamy w src/main/jniLibs/arm64-v8a/
            jniLibs.srcDirs("src/main/jniLibs")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Wyłącznie platformowe zależności; logika w Kotlinie opiera się
    // na android.* (usługi dostępności) bez dodatkowych bibliotek.
}
