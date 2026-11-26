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

    buildTypes {
        release {
            // Lots A à C : les builds release ne servent qu'aux contrôles
            // automatiques (permissions, taille) et sont signés avec la clé
            // de débogage. Ils ne doivent jamais être distribués.
            // La signature de distribution arrive au lot D (release.yml),
            // à partir de secrets GitHub ; voir docs/BUILD.md.
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
