# Reliable Wi-Fi setup for the presentation

Your **original Wi-Fi was verified on 22 October 2026**, with USB unplugged: scanning and medicine explanations both worked after the signed address fallback was installed. You can use that network for the presentation. Connect both devices to it and keep internet access available for cloud prescription reading.

Keep both devices on the same network during a scan. During testing the Mac returned from the hotspot address to its original network address, separating it from the iPhone. A network switch during upload can interrupt a scan even when both networks individually work. No Wi-Fi auto-join preferences were changed by the implementation.

## Start the Mac backend

Double-click **Start-MediExplain.command** in the project folder. Alternatively, open Terminal in this project folder and run:

```sh
python3 scripts/presentation.py
```

The command starts Docker Desktop if necessary, starts the **existing `meddex` containers** (including the admin portal when installed), waits for PostgreSQL and API readiness, and keeps the Mac awake while the command runs. It never creates or replaces the database. It prints the current Wi-Fi address and reports address changes. Keep the terminal and Mac lid open. Press Ctrl+C after the presentation to stop the sleep guard; the backend stays running. The admin portal is **http://localhost:3000**; see [the publication demonstration steps](ADMIN_MOBILE_DATA_FLOW.md).

For a quick check without starting anything or holding the Mac awake:

```sh
python3 scripts/presentation.py --check-only
```

## Configure the iPhone once

1. Enable iPhone **Settings → Apps → MediExplain → Local Network**.
2. In MediExplain, open **Settings → Server connection**.
3. Enable **Find my Mac automatically** and tap **Test and save**.
4. Scan a prescription and check the medicine list. Confirm the medicines before asking for explanations.

The automatic URL on this Mac is `http://mahdis-MacBook-Air.local:8000/api/v1/`. New API connections resolve that name again, including authentication refresh. If name lookup fails, the app can use remembered, verified Mac addresses. The installer seeds the current Wi-Fi address; the app remembers up to five addresses that pass its identity check. This avoids requiring the numeric IP in the app's main API URL.

Before using these automatic routes, the app sends an anonymous random challenge. The Mac signs it using a private P-256 key kept in the ignored `services/api/.env`. Apple CryptoKit or Android's built-in signature verifier checks the proof against the public key paired during installation. Invalid/replayed proofs are rejected. Only after verification does the ordinary API client connect with its session and prescription data. There is no network scanning and no new package or model dependency. This is development LAN routing; production HTTPS remains required and unchanged.

Switch Wi-Fi between scans. If a network switch interrupts an upload, use Retry on the saved scan after reconnecting.

## Why the earlier Wi-Fi failed

The previous network allowed the iPhone to connect to the Mac's numeric address, but the Mac's name did not resolve/connect when the native iPhone test required **Wi-Fi only**. Safari working while USB was connected did not establish Wi-Fi discovery. A shared network name does not guarantee that a campus or guest network permits Bonjour multicast between devices.

The available hotspot passed the same Wi-Fi-only test after the Mac's IP changed from `10.141.27.28` to `10.34.116.118`. The test used the unchanged `.local` hostname and explicitly required the Wi-Fi interface, excluding a USB networking route.

A previously unseen network that blocks Bonjour and assigns an address the phone has never learned can still require one-time pairing or a manual **Server connection** check. If the router blocks all device-to-device traffic, a local backend cannot be reached at all. Access independent of those restrictions requires a separately configured hosted HTTPS backend or private VPN. The original network now works using the verified address fallback; switching to a hotspot is not required.

## Preserve the server pairing

Keep `MEDIEXPLAIN_LOCAL_SERVER_PRIVATE_KEY` in the private server `.env`; do not regenerate it on every restart or put it in Flutter. The app contains only the public key. For a fresh Mac/backend installation, provision it once, restart the API with the AI overlay, then run the iOS installer:

```sh
services/api/.venv/bin/python scripts/prepare_local_server_identity.py
```

The setup command preserves an existing identity. Changing that identity requires pairing/reinstalling the local development app again. Hosted HTTPS and explicitly selected manual numeric URLs do not receive this automatic fallback configuration.

## Verification evidence

- Native iPhone Wi-Fi-only hostname test: previous network timed out; hotspot passed in 0.416 seconds.
- Native iPhone Wi-Fi-only direct-IP check on the previous network: passed in 0.111 seconds.
- A native one-megabyte synthetic upload over Wi-Fi passed in 15.296 seconds. It used whitespace and a deliberately invalid refresh token, accessed no patient data, and changed no account records.
- 30 targeted Flutter tests passed, covering changed DNS addresses, blocked-Bonjour fallback, rejected unverified servers, excluded USB addresses, cancellation, session-client configuration, automatic settings, image preservation/compression, and distinct upload/response timeouts. Flutter analysis found no issues.
- 12 presentation startup/installer regression tests and 11 backend identity/upload/OCR tests passed. The production CryptoKit verifier accepted a valid fixture and rejected a changed challenge and malformed proof.
- A live synthetic scan on the original network completed image reading (2.52 seconds), separation (1.61 seconds), and batch sourced explanations (1.40 seconds). Its temporary account was deleted.
- The owner confirmed **wireless scanning and explanations work** on the original Wi-Fi with automatic mode enabled and USB unplugged.

The first USB-free scan exposed an upload timeout before Gemini received the image. Large scan uploads now use a smaller JPEG copy at unchanged pixel dimensions; saved images are preserved. The upload timeout is bounded at 60 seconds and is distinguished from the response timeout. Interrupted uploads now receive an expected error instead of an internal server exception. The backend was updated using the existing image plus the tested router change, without downloading replacement dependencies or altering the database.

The timings describe a controlled printed fixture, not a guarantee for difficult handwriting or cloud-provider availability.
