---
name: flutter-apk-build
description: >-
  Build, package, optimize, and verify Android APKs (release or debug) for pulse-assistant and Flutter projects.
  Use when the user requests building an APK, generating an Android installation package, or speeding up the APK build workflow.
---

# Flutter APK Build & Packaging Skill

This skill streamlines and accelerates building Android APKs for **pulse-assistant** and Flutter projects on Windows. It includes automated execution scripts, fast-build optimization strategies, and artifact verification.

---

## Quick Reference / Commands

### 1. Automated Script (Recommended)
Run the PowerShell helper script located at [build-apk.ps1](./scripts/build-apk.ps1):

```powershell
# Standard universal release APK (with verification & SHA-256)
powershell -ExecutionPolicy Bypass -File "./.agents/skills/flutter-apk-build/scripts/build-apk.ps1"

# Fast release build (skips redundant 'flutter pub get' if dependencies unchanged)
powershell -ExecutionPolicy Bypass -File "./.agents/skills/flutter-apk-build/scripts/build-apk.ps1" -NoPub

# Optimized for modern phones (ARM64 only: smaller download, faster compilation)
powershell -ExecutionPolicy Bypass -File "./.agents/skills/flutter-apk-build/scripts/build-apk.ps1" -TargetPlatform android-arm64 -NoPub

# Split per ABI (produces separate lean APKs for arm64-v8a, armeabi-v7a, x86_64)
powershell -ExecutionPolicy Bypass -File "./.agents/skills/flutter-apk-build/scripts/build-apk.ps1" -SplitPerAbi -NoPub
```

### 2. Direct Flutter Commands

From `pulse-assistant`:

| Goal | Command | Benefit |
| :--- | :--- | :--- |
| **Standard Universal Release** | `flutter build apk --release` | Compatible with all Android architectures. |
| **Fast Build (Skip Pub)** | `flutter build apk --release --no-pub` | Shaves off dependency re-resolution time. |
| **Target Modern Devices (ARM64)** | `flutter build apk --release --target-platform android-arm64 --no-pub` | Fastest compile time; reduced binary size. |
| **Split Per ABI** | `flutter build apk --release --split-per-abi --no-pub` | Produces individual lean APKs per CPU architecture. |
| **Debug Build** | `flutter build apk --debug` | Rapid build for local device testing. |

---

## Build Execution Workflow

When a build is requested:

1. **Working Directory**: Ensure the command runs inside the target Flutter root (`pulse-assistant`).
2. **Execute Build**:
   - For interactive commands, specify `WaitMsBeforeAsync: 10000` as Gradle task `assembleRelease` typically takes 30–120 seconds.
   - If the task runs in the background, promptly notify the user that Gradle has started and await completion.
3. **Locate Generated Artifact**:
   - The compiled APK is generated at:
     `build/app/outputs/flutter-apk/app-release.apk`
   - For split builds, check:
     `app-arm64-v8a-release.apk`, `app-armeabi-v7a-release.apk`, `app-x86_64-release.apk`.
4. **Inspect & Verify Output**:
   Run PowerShell to extract artifact metadata:
   ```powershell
   Get-Item "build/app/outputs/flutter-apk/app-release.apk" | Select-Object FullName, Length, LastWriteTime
   Get-FileHash "build/app/outputs/flutter-apk/app-release.apk" -Algorithm SHA256
   ```
5. **Report to User**:
   Always provide a clickable link using `file:///` forward-slash format, exact file size in MB, timestamp, and SHA-256 hash.

---

## Performance & Build Speed Optimizations

1. **Use `--no-pub`**:
   If packages were already resolved (`.dart_tool` is present and `pubspec.yaml` was not modified), passing `--no-pub` avoids unnecessary network and pub cache queries.
2. **Target Specific ABI**:
   Unless distributing to unknown legacy hardware, building with `--target-platform android-arm64` compiles native code only for modern 64-bit devices, cutting build time significantly.
3. **Gradle Daemon Persistence**:
   The Gradle daemon stays warm in memory across builds. Avoid using `--no-daemon` or running `flutter clean` unless troubleshooting corrupted caches.
4. **Skip Tests during Binary Packaging**:
   `flutter build apk` compiles the application directly without running unit tests, keeping builds rapid. Run `flutter test` separately when verifying regressions.

---

## Troubleshooting Guide

- **Gradle Lock Contention**: If a previous build was aborted unexpectedly and locked `.gradle`, check running Java processes (`Get-Process java -ErrorAction SilentlyContinue`) and terminate orphaned daemons if necessary.
- **Java / SDK Path Verification**:
  - JDK binary: `C:\Users\XMART\jdk-17\bin\java`
  - Android SDK: `C:\Users\XMART\AppData\Local\Android\Sdk`
  - Run `flutter doctor -v` if environment issues arise.
