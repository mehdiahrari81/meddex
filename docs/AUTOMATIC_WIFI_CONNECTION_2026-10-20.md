# Automatic local connection after a Wi-Fi change — 20 October 2026

**22 October update:** the original network was found to block Wi-Fi Bonjour lookup while allowing direct LAN connections. Automatic mode now supports recently verified address fallback, authenticated by a fresh P-256 server-identity proof before the session/data connection. The signed Release app was installed and the owner confirmed scanning and explanations work on the original Wi-Fi with USB unplugged. See [current presentation setup and limits](PRESENTATION_WIFI_SETUP.md). The original DNS-only behavior below is historical.

The previous iPhone Release build used the Mac's numeric Wi-Fi address. DHCP changes could invalidate it. Local device installations now use the Mac's stable Bonjour hostname: `http://mahdis-MacBook-Air.local:8000/api/v1/` on this machine.

## Behavior

- The installer defaults to the Mac's `LocalHostName` (`scutil --get LocalHostName`), preserving it across Wi-Fi/IP changes. An explicitly supplied HTTPS/local URL still works; `--api-base-url wifi` selects a numeric address for troubleshooting.
- **Settings → Server connection → Find my Mac automatically** is enabled for the local hostname configuration. Old numeric server preferences adopt automatic mode on upgrade. Existing hosted/manual hostname configurations remain manual; an explicit manual choice is persisted. No account or medication data is erased.
- API calls and authentication refresh use the same configured hostname. Each new connection resolves its current IPv4 addresses and accepts only private LAN addresses. Loopback, public, IPv6 and USB/link-local addresses cannot become a local API route.
- Idle sockets close immediately so a connection from the previous Wi-Fi is not reused. A stale/unreachable advertised LAN address is cancelled after two seconds and the next is tried, up to three distinct advertised addresses. DNS resolution has a three-second bound. Cancellation stops fallback and closes pending sockets.
- Address fallback happens before sending HTTP bytes. The app does not repeat a medicine scan/upload or other mutation after it may already have reached the server. It does not scan subnets or forward credentials to a discovered unrelated hostname.
- Server verification is anonymous, refuses redirects, and must succeed before saving a changed connection. Production builds still require HTTPS and ignore development server overrides.

## Verification

- 228 mobile tests passed, including simulated Wi-Fi/DNS address changes, stale-address fallback, USB/public-address exclusion, timeout/cancellation, old-setting migration, explicit manual settings, and the automatic-connection dialog. Flutter analysis and formatting passed.
- Three installer regression tests passed. Backend quality checks, 192 API tests and migration checks passed; backend behavior was unchanged for this feature.
- A real Flutter networking test against the Bonjour URL passed: registration, persisted-session restoration, token refresh, prescription/medication save and delete synchronization, logout/login and temporary-account deletion. It used an isolated engineering account, invoked no cloud AI, and added no records to the owner's account.
- Signed Release installed and launched on the connected iPhone 12 with the Bonjour URL compiled in, preserving its bundle ID and data. After launch, the backend observed the phone's readiness check and authenticated token refresh returning HTTP 200. This confirms the actual phone reached the API with the new configuration. Installation is recorded in `/tmp/meddex-auto-wifi-iphone-install.log`.

## Network requirements

Both devices must be on the same reachable Wi-Fi/LAN, with the Mac awake, the API running and Local Network permission enabled on iOS. A guest network that isolates clients or blocks Bonjour can prevent automatic local discovery; manual server configuration remains available where direct LAN traffic is allowed. Different networks/mobile data require a hosted HTTPS backend or separately configured secure networking. No public tunnel or cloud service was created.

Changing the actual Wi-Fi access point was simulated in automated tests; no network credentials or system Wi-Fi settings were changed during verification. An in-progress upload interrupted while switching Wi-Fi may still need Retry; its saved image remains available.
