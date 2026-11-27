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
        // Signature de distribution : seulement dans release.yml, depuis les
        // secrets de l'environnement protégé « release » (clé créée et
        // gardée par le mainteneur, docs/RELEASE.md). Format PKCS12 : le mot
        // de passe de la clé est celui du fichier.
        create("distribution") {
            val keystore = System.getenv("SAFELINK_RELEASE_KEYSTORE")
            if (!keystore.isNullOrEmpty()) {
                storeFile = file(keystore)
                storeType = "PKCS12"
                storePassword = System.getenv("SAFELINK_RELEASE_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("SAFELINK_RELEASE_KEY_ALIAS")
                keyPassword = System.getenv("SAFELINK_RELEASE_KEYSTORE_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // Versions publiques (release.yml) : clé de distribution. Partout
            // ailleurs (contrôles, pré-versions de développement, builds
            // locaux) : clé de développement, ou clé de débogage de la
            // machine sans les secrets ; ces APK ne sont jamais des versions
            // publiques.
            val distribution =
                !System.getenv("SAFELINK_RELEASE_KEYSTORE").isNullOrEmpty()
            signingConfig =
                signingConfigs.getByName(if (distribution) "distribution" else "debug")
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
