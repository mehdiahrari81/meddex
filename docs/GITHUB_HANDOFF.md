# GitHub handoff verification

Repository: [asjadyousaf05/Medi-Term-Explainer](https://github.com/asjadyousaf05/Medi-Term-Explainer). The complete project is on `main`; no existing remote history was overwritten. The target was empty when initialized.

Start with [Run on another laptop](RUN_ON_ANOTHER_LAPTOP.md), the [Android downloads](../downloads/android/README.md), or the [iOS guide](../downloads/ios/README.md).

## Handoff checks performed on 12 October 2026

| Check | Result |
| --- | --- |
| Clean clone without existing environment files/caches/databases | Cloned the committed source into a separate temporary directory |
| Documented Python startup helper | Built and started API, PostgreSQL, admin, and Mailpit; all healthy |
| Fresh database | Migrations and bundled reference import succeeded automatically |
| Live API input/output | 26/26 scenarios passed against the fresh PostgreSQL/API |
| Named administrator provisioning | Interactive CLI completed; local password-only login accepted |
| Synthetic dashboard data | Helper added 24 editorial records, 6 reports, and 2 invalid-import examples |
| Admin access | Login, dashboard API, seeded content, and admin login page verified |
| Android release packaging | Three optimized APKs built; required Flutter/JNI/SQLite native libraries present |
| Android portable connection | Helper mapped device port 8000 to an alternate laptop API port |
| Actual APK | ARM64 APK installed, opened Home, signed in to the fresh backend, and signed out |
| APK contents | Bundled reference asset present; no personal SQLite database packaged |
| Artifact checksums | SHA-256 checksums verified for all three APKs |
| Apple compilation | Intel/x86_64 iOS Simulator and unsigned ARM64 iPhone builds both passed on Xcode 26.2 |
| Apple archive integrity | Both ZIPs passed CRC and SHA-256 checks; app identifier, iOS 15.5 minimum, executable permissions, bundled reference, CPU architecture, and Mach-O platform verified |
| Apple archive privacy | No personal SQLite database or provisioning profile packaged |
| Private files | Operator credentials, local environment files/databases, dependency caches, and signing keys excluded from Git |
| Cleanup | Disposable containers/database removed; original local stack/data retained; emulator connection restored |

The packaged APK uses a development signer and a local development API configuration. It is release-optimized, but it is not a Play Store production build. The three APKs are approximately 45.3 MiB (ARM64), 37.9 MiB (ARMv7), and 48.2 MiB (x86_64).

## GitHub verification

The [CI workflow](https://github.com/asjadyousaf05/Medi-Term-Explainer/actions/workflows/ci.yml) runs API tests/typing/lint/migrations, admin checks/build, real browser workflows, Flutter tests/analysis, native APK inspection, and an Android app-bundle build. [The complete run for source commit `5db3bae`](https://github.com/asjadyousaf05/Medi-Term-Explainer/actions/runs/38287784309) passed, including backend, PostgreSQL schema, admin, browser, and Flutter jobs. The final documentation-only handoff commit refers to those verified application sources.

The separate [Downloadable mobile builds workflow](https://github.com/asjadyousaf05/Medi-Term-Explainer/actions/workflows/mobile-builds.yml) builds Android and Apple downloads. Apple builds use project-scoped CocoaPods with unused file-picker media/audio modules excluded. App and Pod simulator architectures match ML Kit's x86_64 slices, and unused Swift package integration is removed. Xcode 26.2 is explicitly selected because the locked connectivity plugin requires an Xcode 26 SDK.

The [Apple job for source commit `5db3bae`](https://github.com/asjadyousaf05/Medi-Term-Explainer/actions/runs/38287784253/job/114940191444) passed both builds and uploaded the archives. Downloads are distributed through [GitHub Releases](https://github.com/asjadyousaf05/Medi-Term-Explainer/releases). The Simulator archive targets Intel/x86_64. The device archive is unsigned ARM64 and requires Apple signing before installation. A compile result does not establish physical-device OCR, notifications, speech, biometrics, or accessibility behavior.

The [mobile demo release](https://github.com/asjadyousaf05/Medi-Term-Explainer/releases/tag/v1.0.1-demo) includes all three APKs, the 65.0 MiB Simulator archive, the 27.2 MiB unsigned device archive, checksums, and build metadata. Apple manifests identify their exact source commit. The [iOS checksum and metadata files](../downloads/ios/) are also committed beside the installation guide; the generated ZIPs are release assets.

The [application smoke report](SMOKE_TEST_REPORT.md) and [release verification](RELEASE_VERIFICATION.md) cover the earlier feature-level checks. These handoff checks additionally verify that a clean checkout can initialize its own services and that the distributed Android binary can authenticate to them.
