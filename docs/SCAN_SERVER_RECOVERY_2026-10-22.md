# Scan server recovery — 22 October 2026

## Cause and fix

The iPhone reported “Cannot reach the app server” because Docker Desktop was not running. The existing `meddex` API, PostgreSQL, and Mailpit containers were stopped. Being on the same Wi-Fi does not make a stopped API reachable.

Docker Desktop and those existing containers were started again. No database volume was replaced. `restart: unless-stopped` is now configured for these three services and was applied to the running containers. This lets Docker restart them after failures or when its engine starts again, unless they were explicitly stopped. It does not start Docker Desktop itself or keep the Mac awake.

## Verified

- Readiness returned HTTP 200 through both loopback and `http://mahdis-MacBook-Air.local:8000/api/v1/ready`.
- All three containers reported healthy; Compose configuration validation passed.
- A live, explicitly synthetic two-medicine image was read by Gemini in 2.20 seconds, separated into the two expected medicines in 1.53 seconds, and explained together with reference sources in 1.55 seconds. These measurements describe this test, not a latency guarantee for handwriting or cloud requests.
- The disposable test account was deleted after verification.

The owner's first iPhone retries still failed. A temporary host service confirmed that the iPhone (`10.141.2.210`) could connect to the Mac (`10.141.27.28`), and ICMP replies also succeeded. The API container was then recreated using the same image, configuration overlays, and database. A readiness URL launched in Safari on the iPhone reached the API on port 8000 with HTTP 200, including a second check after restoring the original port mapping.

The temporary port 8001 mapping and test server were removed. The API remains on port 8000. The app's connection was changed to the direct LAN address with automatic discovery disabled. The owner reapplied iOS Local Network permission and saved `http://10.141.27.28:8000/api/v1/` through **Settings → Server connection → Test and save**. The check succeeded, and the owner then confirmed that scanning displayed the medicines on the iPhone. Both the backend workflow and the phone's scan were therefore verified.

The current connection uses a numeric LAN address. If the Mac receives a different IP address, update it in **Server connection** and run **Test and save** again. Automatic `.local` discovery depends on the network allowing Bonjour traffic; it was not verified across the different subnets used in this incident. A server hosted over HTTPS is needed for access independently of the Mac's LAN.

## If the server is stopped again

For this existing installation, start Docker Desktop and wait until its engine is ready, then run from the repository root:

```sh
open -a Docker
docker start meddex-postgres-1 meddex-mailpit-1
docker start meddex-api-1
docker ps
curl --fail http://mahdis-MacBook-Air.local:8000/api/v1/ready
```

The API may take a short time to become ready. Keep the Mac awake, Docker running, and both devices on a network that permits device-to-device traffic. MediExplain needs Local Network access on the iPhone. A USB cable is not required for this HTTP connection.

To recreate/update services rather than restart the existing containers, preserve the project name and AI/OCR overlays:

```sh
python3 scripts/dev.py --project meddex start --ai --ocr
```

Do not delete database volumes to resolve a connection error.
