# iOS source and downloadable app builds

The complete iOS runner is included in [apps/mobile/ios](../../apps/mobile/ios/), including an iOS 15.5+ Podfile, usage descriptions, Xcode project, and shared scheme. Flutter sources and lockfiles are included in the repository.

Apple builds use the repository's project-scoped CocoaPods configuration. The locked picker/cropper Swift packages require incompatible cropper versions; SwiftPM is disabled and its Xcode integration removed for this project. The unused file-picker media/audio modules are excluded, while custom document/image-file import and the separate gallery/camera picker remain configured. App and Pod simulator architectures explicitly match ML Kit's x86_64 slices; physical-device builds retain ARM64.

The handoff machine has Command Line Tools but **no full Xcode/iOS SDK**. Both Apple archives were instead compiled successfully by [the cloud Apple job for source commit `5db3bae`](https://github.com/asjadyousaf05/Medi-Term-Explainer/actions/runs/38287784253/job/114940191444), using Xcode 26.2 and Flutter 3.44.5. Download binaries from the [mobile demo release](https://github.com/asjadyousaf05/Medi-Term-Explainer/releases/tag/v1.0.1-demo), or the successful Apple job's `MediExplain-iOS` artifact. The [Downloadable mobile builds workflow](https://github.com/asjadyousaf05/Medi-Term-Explainer/actions/workflows/mobile-builds.yml) can rebuild them.

| Output | Purpose | Installation boundary |
| --- | --- | --- |
| [MediExplain-ios-simulator-x86_64.zip](https://github.com/asjadyousaf05/Medi-Term-Explainer/releases/download/v1.0.1-demo/MediExplain-ios-simulator-x86_64.zip) | Zipped `Runner.app` built for an Intel iOS Simulator | Not an iPhone app; architecture/runtime must match |
| [MediExplain-ios-device-arm64-unsigned.zip](https://github.com/asjadyousaf05/Medi-Term-Explainer/releases/download/v1.0.1-demo/MediExplain-ios-device-arm64-unsigned.zip) | Unsigned ARM64 iPhone app bundle | Requires Apple signing before installation |
| Signed `.ipa` | Device/TestFlight/App Store distribution | Must be built with your Apple signing/provisioning configuration; not supplied unsigned |

Apple archives are release assets rather than Git-tracked generated directories. Downloads preserve app-bundle metadata through `ditto`, and include checksums/build metadata. The output's API URL is printed in its accompanying `build-info` JSON.

Verified download sizes are approximately 65.0 MiB (Simulator) and 27.2 MiB (device). [Simulator checksums](SHA256SUMS-ios-simulator.txt), [device checksums](SHA256SUMS-ios-device.txt), [Simulator build metadata](build-info-ios-simulator.json), and [device build metadata](build-info-ios-device.json) are included here. Both archives passed ZIP integrity, checksum, bundle identifier, CPU/platform, and minimum-OS checks. They contain bundled reference content and no personal database.

## Run from source on a Mac

Install full **Xcode 26.1.1+ (26.2 used in CI)**, required iOS platform/Simulator components, CocoaPods, and Flutter 3.44.5. The locked connectivity plugin uses APIs absent from older Xcode SDKs, even when deploying to an older supported iOS release. Follow the official [Flutter iOS setup](https://docs.flutter.dev/platform-integration/ios/setup). Select the installed Xcode developer directory and complete its setup/licenses yourself. The app and OCR dependency require iOS 15.5 or newer.

From the repository root, start the backend:

```sh
python3 scripts/dev.py start
```

Open a compatible iOS Simulator through Xcode, find its ID using `flutter devices`, then:

```sh
python3 scripts/dev.py run-mobile --platform ios --device SIMULATOR_ID
```

Alternatively build the Simulator archive:

```sh
python3 scripts/build_mobile.py ios-simulator
```

The simulator uses the laptop's loopback API address, so no Android-style ADB forwarding is needed. The source helper reads alternate host API ports. A physical iPhone needs a reachable laptop LAN/HTTPS API URL rather than the phone's own `localhost`.

## Install a downloaded Simulator app

Unzip the **Simulator** download on a compatible Mac, boot the appropriate simulator, and run:

```sh
xcrun simctl install booted /path/to/Runner.app
xcrun simctl launch booted com.mediexplain.mediexplain
```

Start the API at the address recorded in the build metadata before using authenticated/network features. Guest/local features do not require it.

**Architecture boundary:** the current Google ML Kit 9 CocoaPods dependency includes `x86_64` simulator binaries. The cloud job therefore uses `macos-15-intel`. Apple Silicon ARM64 Simulator compatibility is not claimed; some older simulator/Rosetta combinations may work, but a device binary must not be relabeled as a simulator binary. A future native ARM64 Simulator dependency upgrade requires separate verification. See the [upstream ML Kit plugin documentation](https://github.com/flutter-ml/google_ml_kit_flutter/tree/master/packages/google_mlkit_commons).

## Run on a real iPhone / create a signed IPA

1. Prepare the Flutter/Xcode/CocoaPods toolchain and run `flutter pub get --enforce-lockfile` in `apps/mobile`.
2. Open `apps/mobile/ios/Runner.xcworkspace` in Xcode.
3. Select your Apple development team and a bundle identifier available to that team. Connect/trust the device and enable its Developer Mode as required by Apple.
4. Use a reachable API address with `API_BASE_URL`; the default loopback archive does not reach a separate laptop from an iPhone.
5. Run on the selected device through Flutter/Xcode, or configure valid distribution signing and run `flutter build ipa` for your chosen distribution method.

The build helper can produce an unsigned device archive with `python3 scripts/build_mobile.py ios-device`. That verifies compilation when it succeeds; it is **not** a directly installable signed IPA. Apple credentials, certificates, private keys, and provisioning profiles are excluded from Git. See the official [Flutter iOS release guide](https://docs.flutter.dev/deployment/ios).

The recorded application smoke tests are Android-based. A successful cloud iOS compile does not establish physical iPhone OCR, notification delivery, microphone, biometrics, sharing, or accessibility behavior. Those device checks remain necessary.
