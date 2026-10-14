# Run MediExplain on another laptop

This repository contains the mobile, API, admin, reference dataset, migrations, lockfiles, local service configuration, presentation guide, and Android demo APKs. Your laptop creates its own database and named accounts. Python helpers use only the standard library.

## Choose a path

| Goal | Requirements | Starting point |
| --- | --- | --- |
| Admin and API | Git, Docker/Compose v2, Python 3.10+ | `python3 scripts/dev.py start` |
| Install Android APK | Above, Android SDK Platform-Tools, Android phone/emulator | `python3 scripts/dev.py install-android` |
| Develop Android app | Above, Flutter 3.44.5, Android SDK, complete NDK, JDK 17 | `python3 scripts/dev.py run-mobile` |
| Run iOS Simulator | Mac, full Xcode 26.1.1+, compatible simulator, CocoaPods; Flutter for source builds | [iOS instructions](../downloads/ios/README.md) |
| Install on real iPhone | Mac/Xcode, Apple account and development signing, connected trusted device | Build/sign the source in Xcode |
| Enable AI explanations | Running API, host Ollama and downloaded model, enabled admin flag | [AI setup](AI_FEATURES.md) |

Windows/Linux laptops can run the API/admin and Android workflow. iOS requires Apple tooling on a Mac. This project does not have a verified Windows desktop, browser-mobile, or macOS desktop build.

## 1. Clone and start

Install and start Docker Desktop, or Docker Engine with Compose v2 on Linux. Ensure `docker compose version` works. The first start downloads images/packages and builds services; later starts reuse caches. Install Git and Python 3.10 or newer.

macOS/Linux:

```sh
git clone https://github.com/asjadyousaf05/Medi-Term-Explainer.git
cd Medi-Term-Explainer
python3 scripts/dev.py start
```

Windows PowerShell:

```powershell
git clone https://github.com/asjadyousaf05/Medi-Term-Explainer.git
Set-Location Medi-Term-Explainer
py -3 scripts/dev.py start
```

Use `py -3` for all subsequent Python commands on Windows. The helper builds services, waits for readiness, and prints actual URLs. Defaults:

| Service | Address |
| --- | --- |
| Admin | http://localhost:3000 |
| API documentation | http://localhost:8000/docs |
| API readiness | http://localhost:8000/api/v1/ready |
| Local password-reset inbox | http://localhost:8025 |

Start without Python if preferred: `docker compose up -d --build --wait`. The helper's default Compose project name is `mediexplain`. If you use `--project my-demo`, supply it before the command on every invocation, for example `python3 scripts/dev.py --project my-demo status`.

## 2. Create accounts and dashboard examples

```sh
python3 scripts/dev.py admin
```

Enter your own email, display name, and password when prompted. The password must satisfy the application's rules (12–128 characters, upper/lowercase, number, symbol). It is entered privately inside the provisioning CLI. Local development allows a named admin without MFA; use `admin --mfa` to enroll an authenticator. Production configuration requires MFA.

There is no universal/default administrator password. Existing passwords, private operator notes, sessions, and local databases are excluded from GitHub. Sign in at the printed admin URL with the account you just created.

Optional dashboard examples:

```sh
python3 scripts/dev.py demo --email YOUR_ADMIN_EMAIL
```

This adds labeled synthetic editorial records/reports/import examples; repeat runs preserve edits. Register a mobile account in the mobile app for authenticated medicine/AI features. Offline learning and local records can use guest mode.

Mailpit captures password-reset messages on this laptop; it does not deliver to an external email inbox.

## 3. Install the included Android APK

1. Install [Android SDK Platform-Tools](https://developer.android.com/tools/releases/platform-tools), or use Android Studio's SDK Manager. Make `adb` available on PATH; the helper also checks standard SDK locations and `ANDROID_HOME`/`ANDROID_SDK_ROOT`.
2. Connect a phone by USB, enable Developer options/USB debugging, and accept its computer authorization prompt. Alternatively start an Android Emulator. `adb devices` should show one device with state `device`.
3. Start the backend with the command above.
4. Run:

```sh
python3 scripts/dev.py install-android
```

The command detects the device architecture, selects the bundled APK, forwards the device's port 8000 to this project's actual API port, installs the app, and launches it. With multiple devices, use `--device SERIAL` from `adb devices`.

The APK is release-optimized, configured for a **local development** API, and signed with a development/debug key. It is for an FYP demonstration, not a store or production release. Android minimum SDK is 24 (Android 7). See [APK files and checksums](../downloads/android/README.md).

The APK deliberately uses `http://127.0.0.1:8000/api/v1/` so a different laptop's IP does not require rebuilding. ADB supplies the connection:

```sh
python3 scripts/dev.py connect-android
```

Repeat that command after a device/emulator reconnect or reboot. It also supports alternate host API ports. `10.0.2.2` is only for Android Emulator source builds, not a universal physical-phone address. Without USB/ADB forwarding, guest/local features work but server requests cannot reach the laptop.

For a LAN-only setup, rebuild for the laptop's reachable LAN address, for example:

```sh
python3 scripts/build_mobile.py android --api-base-url http://192.168.1.10:8000/api/v1/
```

Use your actual address. Keep the phone and laptop on a network that permits the connection. The development API listens on its published port; production requires HTTPS.

## 4. Run or rebuild from Flutter source

The validated SDK is **Flutter 3.44.5 / Dart 3.12.2**. CI pins this Flutter version; dependency lockfiles are included. Install its Android SDK/toolchain and a complete NDK, then inspect `flutter doctor -v`. Do not copy another laptop's `local.properties` or Flutter cache.

To run on an attached Android device/emulator with the helper's port forwarding:

```sh
python3 scripts/dev.py run-mobile --platform android
```

To build all three Android APK architectures and verify native libraries:

```sh
python3 scripts/build_mobile.py android
```

Outputs are written to `downloads/android/` with SHA-256 checksums and build metadata. The release configuration uses a local debug key when no private release keystore is configured. Signing keys are ignored by Git. Regenerated demo APKs on another laptop can have a different development signer.

For standard Flutter commands:

```sh
cd apps/mobile
flutter pub get --enforce-lockfile
flutter devices
flutter run --dart-define=APP_ENV=development --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1/
```

That last URL is for Android Emulator against the default port; adjust it for your device. The prebuilt APK uses loopback/ADB as described above.

## 5. iOS build and download

See [the iOS guide](../downloads/ios/README.md) for full requirements, Simulator installation, Apple signing, and the current ML Kit simulator architecture boundary.

On a compatible Mac:

```sh
python3 scripts/build_mobile.py ios-simulator
python3 scripts/build_mobile.py ios-device
```

The first packages an iOS Simulator `.app`; the second packages an **unsigned** ARM64 device `.app`. Unsigned device output is a build artifact for developers and cannot be directly installed on an iPhone. A signed `.ipa` needs your Apple signing/provisioning configuration; those private files are not supplied.

GitHub's [Downloadable mobile builds workflow](https://github.com/asjadyousaf05/Medi-Term-Explainer/actions/workflows/mobile-builds.yml) builds Android plus Intel/x86_64 iOS Simulator and unsigned iPhone archives. A successful run exposes downloadable artifacts. To retain them as repository releases, run it manually with an existing `release_tag`. Artifact checksums and API URL metadata accompany the binaries.

## 6. Optional local AI

Install [Ollama](https://docs.ollama.com/quickstart), download `qwen3:8b`, and start its service. On a laptop with Docker Desktop:

```sh
ollama pull qwen3:8b
python3 scripts/dev.py start --ai
```

If the Ollama service is not already running, start it with `ollama serve` in another terminal. Model downloads and inference need substantial disk/RAM; the base application does not require the model. Use the admin **Feature flags** page to enable `ai_assistant`, confirming its current revision/key. Both provider configuration and the flag are required. Follow [AI_FEATURES.md](AI_FEATURES.md) for source-backed behavior, Linux host connectivity, setup, and limitations.

Keep `--ai` on later `start` commands to retain the override. Existing source facts/caches and model output labels remain distinguishable. RxNorm/DailyMed/MedlinePlus retrieval still needs access to its external services.

## Daily commands

```sh
python3 scripts/dev.py status
python3 scripts/dev.py logs
python3 scripts/dev.py stop
python3 scripts/dev.py start
git pull --ff-only
```

`stop` retains the named database volume. After pulling source changes, run `start` to rebuild/migrate services and reinstall a changed APK if needed. Do not remove the Docker volume unless you intentionally want to discard that laptop's accounts and personal data.

## Troubleshooting

| Symptom | Action |
| --- | --- |
| Port already allocated | Copy root `.env.example` to `.env`, choose free host ports, then start again. The helper reads actual Compose port mappings. |
| Docker daemon unavailable | Start Docker Desktop/Engine and retry. |
| First build is slow | Inspect `logs`; images/packages/model downloads need connectivity and disk space. |
| Sign-in rejected | Use the named account created on this laptop. Previous laptop credentials were not copied. Admin/mobile sign-in are separate session contexts. |
| Phone has local content but login fails | Check backend `status`, device authorization, and repeat `connect-android`. |
| `adb` says unauthorized | Unlock the phone and accept its debugging authorization prompt. |
| Multiple Android devices | Supply `--device SERIAL`. |
| APK update has incompatible signature | A previous installation used another development key. Back up needed app data before deciding whether to uninstall it; the helper does not uninstall automatically. |
| AI shows Original source | Configure/reach Ollama, download the selected model, enable the audited flag, and check API logs. |
| iOS build reports no Xcode | Install full Xcode and select its developer directory; Command Line Tools alone are insufficient. |
| iOS Simulator architecture error | The bundled ML Kit version ships x86_64 simulator support. Use the Intel build/compatible simulator or a signed physical-device source build; do not rename a device bundle into a Simulator build. |

The main [local development](LOCAL_DEVELOPMENT.md), [smoke report](SMOKE_TEST_REPORT.md), [release verification](RELEASE_VERIFICATION.md), and [production checklist](PRODUCTION_CHECKLIST.md) explain deeper setup and the boundaries of recorded verification.
