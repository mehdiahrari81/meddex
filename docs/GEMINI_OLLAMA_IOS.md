# Gemini, Ollama fallback, and iOS

**22 October connection update:** automatic local routing now has a signed fallback to previously verified Mac addresses when Bonjour is blocked. The owner verified scanning and explanations on the original Wi-Fi with USB unplugged. The [presentation setup guide](PRESENTATION_WIFI_SETUP.md) includes the one-click backend/sleep guard, pairing-key location, tests, and network limits.

**20 October speed update:** scanning and medicine separation now start with `gemini-3.5-flash-lite`, with `gemini-3.5-flash` for temporary outages and a bounded higher-detail review of uncertain handwriting. Explanations load two at a time with a short account-scoped preview cache. See [scan performance measurements](PRESCRIPTION_SCAN_SPEED_2026-10-20.md). This supersedes earlier model/timeout notes below.

**20 October automatic Wi-Fi update:** local iPhone installs now use the Mac’s stable Bonjour hostname by default, rather than its numeric Wi-Fi address. The app resolves fresh LAN addresses per request, ignores USB/link-local advertisements, and offers an automatic/manual switch in Server connection. Older numeric settings adopt automatic mode. See [automatic Wi-Fi connection](AUTOMATIC_WIFI_CONNECTION_2026-10-20.md).

**20 October connection/timeout update:** the Mac's Wi-Fi address changed again. The app now has a development-only **Settings → Server connection** readiness check and persistent address override, and scan timeout recovery can use an alternate Gemini model within a bounded budget. See [the timeout fix and live verification](PRESCRIPTION_TIMEOUT_FIX_2026-10-20.md). Historical addresses below describe earlier installations.

**20 October Gemini availability update:** Google returned high-demand HTTP 503 errors for the image reader. Scan image reading and medicine separation now have a third cloud recovery model, bounded backoff, and a two-minute per-model availability cooldown. See [availability fix](PRESCRIPTION_AVAILABILITY_FIX_2026-10-20.md).

Configuration and implementation update: 18 October 2026. Gemini and Ollama serve the medical assistant. Gemini also separates **recognized prescription text** into medicine entries; see [prescription workflow](PRESCRIPTION_GEMINI_STRUCTURING.md). At the user's request, **Use this image** now directly sends the selected prescription to Gemini for handwriting recognition, then separates the recognized medicine fields. No extra method chooser is shown. Existing raw-text review tools remain available for saved scans. Ollama remains the assistant fallback and receives no prescription images.

## API key location

Put your key in **`services/api/.env`**:

```dotenv
MEDIEXPLAIN_AI_PROVIDER=gemini_ollama
MEDIEXPLAIN_GEMINI_API_KEY=your_actual_key
MEDIEXPLAIN_GEMINI_MODEL=gemini-3.5-flash-lite
MEDIEXPLAIN_GEMINI_PRESCRIPTION_MODEL=gemini-3.5-flash-lite
MEDIEXPLAIN_GEMINI_HANDWRITING_MODEL=gemini-3.5-flash-lite
MEDIEXPLAIN_GEMINI_HANDWRITING_FALLBACK_MODEL=gemini-3.5-flash
MEDIEXPLAIN_GEMINI_PRESCRIPTION_FALLBACK_MODEL=gemini-3.5-flash
MEDIEXPLAIN_GEMINI_SCAN_RECOVERY_MODEL=gemini-3.5-flash-lite
MEDIEXPLAIN_GEMINI_TIMEOUT_SECONDS=20
MEDIEXPLAIN_GEMINI_COOLDOWN_SECONDS=300
MEDIEXPLAIN_OLLAMA_BASE_URL=http://127.0.0.1:11434
MEDIEXPLAIN_OLLAMA_MODEL=qwen3:1.7b
MEDIEXPLAIN_AI_TIMEOUT_SECONDS=60
```

The actual file is ignored by Git and has private filesystem permissions. The committed template is **`services/api/.env.example`**. Keep the existing database/password/email settings in the actual file. The same file supplies AI settings to both a local API and Docker's AI overlay. Do not put a Gemini key in Flutter, Dart defines, an iOS plist, or Android resources. Do not commit the actual `.env` file. Keys are sent in an HTTP header, not a URL.

Create a key through [Google AI Studio](https://aistudio.google.com/apikey). The default model is configurable; check your account's model availability and quota. Google currently recommends recent Flash models for new projects in its [model catalogue](https://ai.google.dev/gemini-api/docs/models).

## Start or restart this workspace

Ollama runs on the Mac hosting Docker. The downloaded fallback is `qwen3:1.7b`, a roughly 1.4 GB quantized model selected for this Mac's 8 GB RAM. The existing `qwen3:8b` model is preserved; set `MEDIEXPLAIN_OLLAMA_MODEL=qwen3:8b` to use it on a host with enough free memory.

```sh
# Start the installed Ollama app on macOS, or run ollama serve.
open -a Ollama
ollama pull qwen3:1.7b
python3 scripts/dev.py --project meddex start --ai --ocr
```

Equivalent Compose configuration:

```sh
docker compose -f docker-compose.yml -f docker-compose.ai.yml -f docker-compose.ocr.yml up -d --build
docker compose -f docker-compose.yml -f docker-compose.ai.yml exec -T api python -m app.cli enable-ai
```

`--ai` enables the assistant flag with an operator audit event. The CLI never creates a fake administrator or disables medical-source validation. The existing database volume is retained. Re-run the start command after changing the key so the API process receives the new value. `--ocr` independently retains the CPU handwriting service.

Docker overrides only the Ollama connection address to `http://host.docker.internal:11434`. For a different Docker host address, set `MEDIEXPLAIN_OLLAMA_DOCKER_BASE_URL` in the shell before Compose startup. The local API uses the loopback URL in `services/api/.env`.

## Routing behavior

1. With a configured key, safe and source-backed assistant questions go to Gemini first using structured JSON output.
2. Quota/rate-limit errors (`429`) or exhausted prepaid credits (`402`) immediately use local Ollama. A thread-safe, bounded process-local cooldown is shared across requests. Retry-After headers and Google's RetryInfo are respected; otherwise the configurable 300-second cooldown applies, capped at one day.
3. During cooldown, new requests use Ollama without repeatedly consuming Gemini attempts. Once cooldown expires, the next request tries Gemini again. If quota remains exhausted, local fallback resumes.
4. Network failures, timeouts, and transient server errors also permit local fallback, with a short cooldown for network failures. Invalid keys, invalid model configuration, safety-blocked output, and truncated output are not disguised as exhausted quota.
5. Without a key, Ollama is used immediately and the response identifies that Gemini is not configured. If both providers fail, the existing labeled original-source fallback remains.

The API response includes the actual generation provider/model and fallback reason. The assistant shows the reason when it uses local generation. Source IDs, medicine names, numbers, English/Urdu output, and unsafe requests still pass through the existing RAG validation. Neither model is a medical source. A cloud-processing disclosure appears beside assistant input. Questions may contain health information; avoid patient identifiers.

A separate API worker has its own cooldown. Use a shared gateway/provider limiter when scaling to multiple workers. A cooldown is a retry schedule, not a promise that Google will reset a quota at that instant. See [Google's error handling guidance](https://ai.google.dev/gemini-api/docs/troubleshooting) and [Ollama's structured output API](https://docs.ollama.com/api/chat).

## iOS improvements

- Apple Vision performs accurate on-device text recognition with language autocorrection disabled for medication text. Android retains the same ML Kit SDK via a small native bridge. Removing the cross-platform Google OCR wrapper eliminates its unsupported Apple Silicon simulator binaries from the iOS app.
- VisionKit document scanning provides page edges and perspective correction on physical iPhone/iPad cameras. Scanner cancellation and temporary-file cleanup are handled. Android retains the same Google document scanner SDK.
- HEIC/HEIF imports are decoded by Apple's ImageIO into orientation-correct JPEGs before entering Dart preprocessing. Conversion removes image metadata, bounds image dimensions, protects temporary files, and removes temporary conversion files afterward.
- Session Keychain entitlements are configured for Debug, Profile, and Release. Native notification callbacks are connected to the application delegate.
- iOS defaults to the Mac's loopback API address in the simulator; Android retains `10.0.2.2`. Physical iPhones require an explicit reachable LAN or HTTPS API address.
- Local HTTP and Dart debugging service exceptions exist only in the Debug plist. Release/Profile retain normal transport security; production Dart configuration requires HTTPS.
- iPad share sheets receive a source rectangle, avoiding the missing-popover-anchor failure for medication exports.
- App privacy manifests declare app functionality data and the file-timestamp/user-defaults API reasons. Third-party manifests remain bundled. App Store privacy labels and disclosures must be checked against the final deployed services.
- The project uses CocoaPods explicitly to avoid conflicting Swift Package Manager crop-controller versions. Unused file-picker media/audio support is disabled; the dedicated image picker and document import remain available.

## iOS build and device setup

```sh
cd apps/mobile
flutter pub get
# Simulator on this Mac:
flutter run -d YOUR_SIMULATOR_ID \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1/
# Physical iPhone development: use this Mac's reachable LAN address instead of loopback.
# Store/release build: use your actual HTTPS API, and configure an Apple signing team.
flutter build ios --release --no-codesign \
  --dart-define=APP_ENV=production \
  --dart-define=API_BASE_URL=https://YOUR_API_HOST/api/v1/
```

The release command produces an unsigned developer bundle, not an installable signed IPA. Apple Developer signing, provisioning, physical-camera/Face ID testing, and App Store submission require the owner's Apple setup and devices. No Gemini credential is part of either mobile build.

For a connected physical iPhone that must reopen from its home screen, use the signed Release installer from the repository root:

```sh
python3 scripts/install-ios-device.py \
  --device "$IOS_DEVICE_ID" \
  --team "$APPLE_TEAM_ID" \
  --api-base-url http://mahdis-MacBook-Air.local:8000/api/v1/
```

Set `IOS_DEVICE_ID` to the connected phone's UDID (`xcrun devicectl list devices`) and `APPLE_TEAM_ID` to the existing development signing team's identifier. The helper builds with Flutter `--release`, signs through Xcode, updates the installed app in place, and launches normally without a debugger. It preserves the app's bundle ID and installed data. For this local build, it generates an ignored plist under `apps/mobile/build/ios/local-device/`, allowing HTTP only through a local networking declaration and an exception for the configured LAN host. Standard Release builds continue using the normal plist. Public HTTP hosts and production HTTP configuration are rejected.

`APP_ENV=development` selects the local backend configuration; it does **not** mean Flutter debug mode. The initial installation used Flutter debug mode, which requires Flutter/Xcode for subsequent launches on iOS 14+. A Release binary avoids that restriction. See [Flutter build modes](https://docs.flutter.dev/testing/build-modes) and [Apple's local networking policy](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking).

### Connected iPhone verification

On 18 October 2026, the connected **iPhone 12 running iOS 26.6.2** was prepared with its compatible developer disk image, using the owner's existing Apple Development certificate and provisioning profile. The initial Debug installation was subsequently replaced in place with a **signed Release build** through `scripts/install-ios-device.py`, after the owner reported the iOS debug home-screen launch restriction. CoreDevice launched the Release app normally, then terminated/relaunched it without Flutter tooling or debugger attachment. A subsequent process check confirmed that the app remained running. The Release bundle contains no debug kernel; its signature and generated host-specific local API transport settings were verified. The signing team was passed to `xcodebuild` for this local build, without adding personal signing settings to the project.

The latest phone build targets `http://mahdis-MacBook-Air.local:8000/api/v1/`. This is the Mac's Bonjour hostname (`scutil --get LocalHostName`), so ordinary DHCP address changes no longer require rebuilding. Both devices must use the same reachable local network, with MediExplain allowed Local Network access. Keep Docker/API and the Mac awake. Some guest networks block peer connections or Bonjour; use a network that allows them. Public deployment still requires a hosted HTTPS API.

The reported simultaneous extraction/explanation failures were reproduced as a device connection failure: the Mac and iPhone used different Wi-Fi networks. Moving them onto the same network also changed the Mac's IP, invalidating the previous hardcoded URL. After switching the device test to the `.local` hostname, authenticated Gemini extraction and a sourced medicine explanation passed on the physical iPhone in 3.93 seconds. All five native device checks passed, including Vision OCR, image processing and Keychain. This does not establish every physical camera/Face ID scenario or clinical handwriting accuracy.

## Verification

Final local results on 18 October 2026:

- **121 API tests passed**; Ruff formatting/lint and strict mypy passed.
- **141 Flutter tests passed**; Flutter analysis reported no issues.
- **4 native XCTest tests passed**, with no skips, on the arm64 iPhone 17 Pro / iOS 26.0.1 simulator.
- The universal arm64/x86_64 simulator app compiled and launched successfully. An unsigned arm64 device Release bundle also compiled (29.9 MB). The device compile used development configuration solely to validate compilation; use the production HTTPS configuration above for deployment.
- The Android debug APK compiled, including the native ML Kit bridge, and its required native-library packaging check passed.
- API, PostgreSQL, and Mailpit are healthy. Database verification found all **78 medicine identities and 34 existing terminology records**, with no remaining QA users or fabricated prescriptions.

The API regression suite includes Gemini-first routing, quota/credit failover, cooldown across request instances, recovery to Gemini, RetryInfo parsing, invalid credentials, blocked/truncated content, both providers failing, and preservation of actual-provider attribution through medical RAG. Existing authentication, owner isolation, reference data, and medical safety tests remain in the suite.

Flutter tests cover iOS host selection, native scan persistence/cancellation/cleanup, HEIC conversion through the channel, and raw OCR text/provenance/confidence preservation. Native XCTest checks the real Apple Vision recognizer, image normalization/metadata handling, invalid-image rejection, and Keychain persistence/read/delete.

A real Ollama call through the running Docker API environment with the new fallback model returned a valid referenced explanation, identified as `ollama` / `qwen3:1.7b` / `gemini_not_configured` before the Gemini key was supplied. `ollama list` subsequently reconfirmed that `qwen3:1.7b` is installed (1.4 GB); the existing 8B model is also preserved.

After the owner supplied a key, live Gemini generation succeeded in approximately 1.5 seconds. The running Docker API's provider factory also selected Gemini successfully (approximately 1.1 seconds). A real authenticated HTTP request to `/api/v1/medication-intelligence/ai/answer` returned HTTP 200, `source_explanation`, `grounded`, `gemini-3.5-flash-lite`, and four official-source citations for an existing verified RxNorm identity. Real MedlinePlus/DailyMed reference retrieval added nine attributed medical facts; no patient data was supplied. The temporary QA account was deleted afterward. Live testing caught and corrected the REST response-format enum to `APPLICATION_JSON`; the regression test now checks that exact value, as specified by the [GenerateContent API](https://ai.google.dev/api/generate-content#TextResponseFormat).

The key is stored only in the ignored backend `.env`, with mode 0600; it is not in the app or this report. Quota exhaustion/recovery remains covered by simulated HTTP errors rather than deliberately exhausting the owner's quota. Physical camera, Face ID, iPad hardware, and App Store validation remain device/owner checks.

## Historical Wi-Fi checks — 19 October 2026

The connected Mac advertised both its Wi-Fi IPv4 address and a USB link-local address through its `.local` name. A native iPhone check restricted to `NWParameters.requiredInterfaceType = .wifi` timed out with that Bonjour name, while the same check against the Mac's Wi-Fi IPv4 address passed in 0.115 seconds. The cable could not supply the network route for that test.

At that stage, the device installer’s `--api-base-url auto` read the Mac’s current Wi-Fi interface/address and built a signed Release app targeting that address. The automatic Wi-Fi update above supersedes this behavior with a stable Bonjour name; `--api-base-url wifi` retains explicit fixed-IP deployment for troubleshooting. An explicit HTTPS or LAN API URL is still supported. The current local installation uses `http://10.141.216.118:8000/api/v1/`. API port 8000 is exposed on LAN interfaces; the database remains bound to loopback. When a `.local` URL is explicitly configured, the Dart transport resolves it afresh and chooses an RFC1918 LAN address instead of loopback or USB link-local advertisements, for both normal requests and session refresh.

To update after the Mac's Wi-Fi address changes:

```sh
python3 scripts/install-ios-device.py \
  --device 00008101-001635EA1A3A001E --team 8T5P24CUF3
```

The phone and Mac must share a network that permits device-to-device traffic, MediExplain must have Local Network permission, and Docker/API plus the Mac must remain awake. A USB cable is needed for this installation command when wireless device development is not configured; it is not needed for the app's HTTP connection afterward. A hosted HTTPS API is required for use away from the Mac's LAN.

Google rejected the configured Gemini credential during the 19 October check: HTTP 401, `API key not valid`. Replace `MEDIEXPLAIN_GEMINI_API_KEY` in the ignored `services/api/.env`, then recreate the API service with the AI overlay. The 1.7B Ollama fallback remains installed/configured; an invalid Gemini credential is surfaced rather than mislabeled as exhausted quota.

### Replacement Gemini credential verified — 19 October 2026

The owner supplied a replacement key. It was saved only to the ignored `services/api/.env` with mode 600, and the API container was recreated to load it. Live Gemini generation returned HTTP 200. The full mobile-to-API smoke test then passed on retry in 79 seconds: authenticated medicine separation, sourced medicine explanations, synthetic-image recognition, reviewed medicine saving, offline save/delete synchronization, and logout/login. The first extraction attempt hit the existing 30-second upstream timeout; the successful retry confirms the credential problem is resolved but does not eliminate transient cloud latency. Both temporary QA accounts and their synthetic records were deleted after verification. The installed iPhone Release app requires no rebuild for a backend key change.
