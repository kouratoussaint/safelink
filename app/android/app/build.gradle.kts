plugins {
    id("com.android.application")
    // Le plugin Flutter doit être appliqué après les plugins Android et Kotlin.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // Identifiant définitif de l'application (décision du 26/11/2026, nom
    // de domaine inversé de FasoSoft) : ne jamais le modifier après la
    // première publication, sinon les mises à jour deviennent impossibles.
    namespace = "com.fasosoft.safelink"

    // Versions explicites plutôt que les valeurs par défaut de Flutter, pour
    // qu'une mise à jour du SDK ne les change pas à notre insu.
    // targetSdk 36 : exigence Google Play depuis le 31 août 2026.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.fasosoft.safelink"
        minSdk = 24
        targetSdk = 36
        // Repris de pubspec.yaml. Pour les APK par architecture, Flutter
        // ajoute automatiquement 1000 × l'identifiant de l'ABI.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Signature de développement stable : les APK publiés par
        // dev-apk.yml sont tous signés avec la même clé, pour qu'une mise à
        // jour s'installe par-dessus la précédente. La clé vient des secrets
        // GitHub, via ces variables d'environnement ; sans elles (build
        // local, CI des pull requests), Android utilise la clé de débogage
        // de la machine. Ce n'est pas la clé de distribution (lot D).
        getByName("debug") {
            val devKeystore = System.getenv("SAFELINK_DEV_KEYSTORE")
            if (!devKeystore.isNullOrEmpty()) {
                storeFile = file(devKeystore)
                storeType = "PKCS12"
                storePassword = System.getenv("SAFELINK_DEV_KEYSTORE_PASSWORD")
                keyAlias = "safelink-dev"
                keyPassword = System.getenv("SAFELINK_DEV_KEYSTORE_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // Jusqu'au lot D, les builds release servent aux contrôles
            // automatiques et aux pré-versions de développement : ils sont
            // signés avec la clé de développement (ou la clé de débogage de
            // la machine sans les secrets) et ne doivent jamais être diffusés
            // au public. La signature de distribution arrive au lot D
            // (release.yml), à partir de secrets GitHub ; voir docs/BUILD.md.
            signingConfig = signingConfigs.getByName("debug")
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
