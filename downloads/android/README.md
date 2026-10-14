# Android demo APKs

These installable, release-optimized **local-demo** builds use `http://127.0.0.1:8000/api/v1/`. The project helper supplies ADB port forwarding to whichever laptop hosts the backend.

| File | Device |
| --- | --- |
| [MediExplain-arm64-v8a.apk](MediExplain-arm64-v8a.apk) | Most modern Android phones; ARM64 emulators |
| [MediExplain-armeabi-v7a.apk](MediExplain-armeabi-v7a.apk) | Supported 32-bit ARM devices |
| [MediExplain-x86_64.apk](MediExplain-x86_64.apk) | Intel/AMD Android emulators |

Minimum Android API is 24 (Android 7). Build/install compatibility on every device is not established. Each APK is inspected for Flutter, JNI, and SQLite native libraries. [SHA-256 checksums](SHA256SUMS-android.txt) and [build metadata](build-info-android.json) identify the files/configuration.

After starting Docker services and connecting an authorized device:

```sh
python3 scripts/dev.py install-android
```

On Windows use `py -3`. See [the complete laptop guide](../../docs/RUN_ON_ANOTHER_LAPTOP.md). The helper selects the APK automatically. No Flutter installation is needed to install these binaries.

These APKs use a development signer and are not Play Store production releases. Rebuilding elsewhere can change the signer. They include bundled reference content but no operator credentials or personal database. For authenticated features, register/sign in to your laptop's API; guest/local features work without a backend.

Rebuild with `python3 scripts/build_mobile.py android`. Larger and future binaries are also available through [GitHub Releases](https://github.com/asjadyousaf05/Medi-Term-Explainer/releases) and the [mobile build workflow](https://github.com/asjadyousaf05/Medi-Term-Explainer/actions/workflows/mobile-builds.yml).
