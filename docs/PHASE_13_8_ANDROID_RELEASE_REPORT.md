# TOURMATE — PHASE 13.8 ANDROID PRODUCTION RELEASE REPORT

**Project:** TourMate — Smart Tourism Guide App  
**Application ID:** `com.example.tourmate`  
**Toolchain:** Android SDK 36.0.0, Gradle 9.3.1, Kotlin 1.9+  
**Target Architecture:** Google Play Store App Bundle (`.aab`)  
**Status:** **READY FOR RELEASE KEYSTORE CONFIGURATION**  

---

## 1. Android Configuration Audit

| Configuration Field | Current Value | Assessment |
|---|---|:---:|
| **Namespace / Application ID** | `com.example.tourmate` | Valid; recommend updating to custom domain before Play Console registration |
| **Compile SDK** | `flutter.compileSdkVersion` | **PASS** (SDK 36.0.0) |
| **Minimum SDK** | `flutter.minSdkVersion` (21+) | **PASS** (Android 5.0+) |
| **Target SDK** | `flutter.targetSdkVersion` (34+) | **PASS** (Complies with Play Store requirement) |
| **Permissions Requested** | `INTERNET`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | **PASS** (Strictly minimal; zero sensitive permissions) |
| **Java / JVM Compatibility** | Java 17 | **PASS** |

---

## 2. APK Size Analysis: Debug vs. Release

In Phase 12, the generated debug APK was measured at **236.2 MB**.  
**Root Cause:**
- Debug builds bundle unstripped JIT runtimes, debugger hooks, observatory endpoints, and uncompressed native binaries across all 4 target ABIs simultaneously (`armeabi-v7a`, `arm64-v8a`, `x86`, `x86_64`).
- Release builds compile Ahead-Of-Time (AOT), tree-shake icon fonts (99.4% reduction for CupertinoIcons, 98.4% for MaterialIcons), strip symbols, and with Android App Bundles (`.aab`), Google Play dynamically generates device-specific split APKs.
- Typical distribution download size for the optimized release build is **15 MB – 25 MB** (over an 85% size reduction).

---

## 3. Production Release Signing Guide

Per prompt instructions, unauthorized self-signed production keys and debug-signed release bundles are forbidden. To generate the final release bundle (`build/app/outputs/bundle/release/app-release.aab`):

### Step 1: Generate Release Keystore
Run in terminal (replace placeholder with your company name/alias):
```bash
keytool -genkey -v -keystore android/app/upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### Step 2: Configure `android/key.properties`
Create `android/key.properties` (this file is excluded by `.gitignore`):
```properties
storePassword=<YOUR_STORE_PASSWORD>
keyPassword=<YOUR_KEY_PASSWORD>
keyAlias=upload
storeFile=upload-keystore.jks
```

### Step 3: Wire Keystore in `android/app/build.gradle.kts`
```kotlin
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = java.util.Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

### Step 4: Build Release App Bundle
```bash
flutter build appbundle --release
```
Artifact location: `build/app/outputs/bundle/release/app-release.aab`.
