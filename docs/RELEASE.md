# Release

Android application ID is `com.mediexplain.mediexplain`, version `1.0.0+1`, min SDK 24. Debug APK and release artifacts are built by documented commands. `android/app/build.gradle.kts` loads a protected, uncommitted `android/key.properties` file when present and otherwise uses debug signing solely for a local/FYP artifact. The fallback is not suitable for store distribution and its output must never be represented as store-signed.

The protected file supplies `storeFile`, `storePassword`, `keyAlias`, and `keyPassword`; its referenced keystore and all credentials belong in the release secret store. CI should materialize both files only for the signing step, verify the signing certificate, and remove them afterward. Neither file is committed.

Release gate: format/analyze/test Flutter; API lint/type/test/migrate/check/start; admin lint/type/test/build; build Docker images; build debug APK and release APK/AAB with production HTTPS URL; inspect artifacts; install on emulator/device where available; verify Urdu/RTL/large text; run trusted/unsafe medication workflows; record provider/backup/restore state. iOS needs full Xcode/CocoaPods and external signing credentials.
