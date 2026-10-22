#!/usr/bin/env python3
"""Install a signed, home-screen-launchable iPhone build using an existing Apple team."""

import argparse
import ipaddress
import json
import plistlib
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlsplit
from urllib.request import HTTPRedirectHandler, ProxyHandler, build_opener

ROOT = Path(__file__).resolve().parents[1]
MOBILE = ROOT / "apps/mobile"


def run(*command, cwd=MOBILE):
    subprocess.run([str(value) for value in command], cwd=cwd, check=True)


def wifi_api_base_url():
    ports = subprocess.check_output(
        ["networksetup", "-listallhardwareports"], text=True
    )
    match = re.search(r"Hardware Port: Wi-Fi\nDevice: (\S+)", ports)
    if not match:
        raise RuntimeError(
            "No Wi-Fi interface found. Supply --api-base-url explicitly."
        )
    address = subprocess.check_output(
        ["ipconfig", "getifaddr", match.group(1)], text=True
    ).strip()
    if not ipaddress.ip_address(address).is_private:
        raise RuntimeError("Wi-Fi has no private LAN address. Supply --api-base-url.")
    return f"http://{address}:8000/api/v1/"


def automatic_api_base_url():
    """Bonjour follows this Mac across DHCP/Wi-Fi changes; never pin its IP."""
    hostname = subprocess.check_output(
        ["scutil", "--get", "LocalHostName"], text=True
    ).strip()
    if not re.fullmatch(r"[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?", hostname):
        raise RuntimeError(
            "No valid Mac local hostname. Supply --api-base-url explicitly."
        )
    return f"http://{hostname}.local:8000/api/v1/"


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def local_server_defines(api_url):
    """Pin only the operator's running loopback backend; never fetch an API key."""
    parsed = urlsplit(api_url)
    if parsed.scheme != "http" or not parsed.hostname.endswith(".local"):
        return []
    opener = build_opener(ProxyHandler({}), NoRedirect())
    endpoint = f"http://127.0.0.1:{parsed.port or 8000}/api/v1/local-server-identity?challenge={'0' * 64}"
    with opener.open(endpoint, timeout=5) as response:
        identity = json.loads(response.read(4096))
    public_key = identity.get("public_key")
    if not isinstance(public_key, str) or not re.fullmatch(
        r"[A-Za-z0-9+/=]{100,200}", public_key
    ):
        raise RuntimeError(
            "The local backend has no valid server identity. Start the updated API first."
        )
    address = urlsplit(wifi_api_base_url()).hostname
    return [
        f"--dart-define=LOCAL_SERVER_PUBLIC_KEY={public_key}",
        f"--dart-define=LOCAL_SERVER_ADDRESSES={address}",
    ]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", required=True, help="Connected iPhone/iPad UDID")
    parser.add_argument(
        "--team", required=True, help="Apple Development team identifier"
    )
    parser.add_argument(
        "--api-base-url",
        default="auto",
        help="API URL, auto for this Mac's stable Bonjour name (default), or wifi for a fixed current Wi-Fi IP.",
    )
    parser.add_argument(
        "--environment", choices=("development", "production"), default="development"
    )
    args = parser.parse_args()
    if sys.platform != "darwin":
        parser.error("iPhone signing and installation require macOS and Xcode.")
    if args.api_base_url in {"auto", "wifi"}:
        if args.environment == "production":
            parser.error("Supply your HTTPS --api-base-url for production.")
        args.api_base_url = (
            automatic_api_base_url()
            if args.api_base_url == "auto"
            else wifi_api_base_url()
        )
    url = urlsplit(args.api_base_url)
    if (
        url.scheme not in ("http", "https")
        or not url.hostname
        or url.username
        or url.password
        or url.query
        or url.fragment
        or not url.path.endswith("/api/v1/")
    ):
        parser.error(
            "Use an HTTP(S) API URL ending /api/v1/, without credentials/query/fragment."
        )
    if args.environment == "production" and url.scheme != "https":
        parser.error("Production API connections require HTTPS.")
    if url.scheme == "http":
        try:
            address = ipaddress.ip_address(url.hostname)
            local = (
                address.is_private
                and not address.is_loopback
                and not address.is_unspecified
            )
        except ValueError:
            local = url.hostname.endswith(".local")
        if not local:
            parser.error(
                "Development HTTP must use a reachable private LAN address or .local hostname."
            )

    run(
        "flutter",
        "build",
        "ios",
        "--release",
        "--no-codesign",
        f"--dart-define=APP_ENV={args.environment}",
        f"--dart-define=API_BASE_URL={args.api_base_url}",
        *local_server_defines(args.api_base_url),
    )
    plist = plistlib.loads((MOBILE / "ios/Runner/Info.plist").read_bytes())
    if url.scheme == "http":
        # Generated local build only. The normal Release plist retains ATS defaults.
        plist["NSAppTransportSecurity"] = {
            "NSAllowsLocalNetworking": True,
            # Development builds can change their trusted LAN server in Settings.
            # Public HTTP URLs are rejected by the app; production still requires HTTPS.
            "NSAllowsArbitraryLoads": args.environment == "development",
            "NSExceptionDomains": {
                url.hostname: {"NSExceptionAllowsInsecureHTTPLoads": True},
            },
        }
    generated = MOBILE / "build/ios/local-device/Info.plist"
    generated.parent.mkdir(parents=True, exist_ok=True)
    generated.write_bytes(plistlib.dumps(plist))
    run(
        "xcodebuild",
        "-workspace",
        "Runner.xcworkspace",
        "-scheme",
        "Runner",
        "-configuration",
        "Release",
        "-sdk",
        "iphoneos",
        "-destination",
        "generic/platform=iOS",
        f"BUILD_DIR={MOBILE / 'build/ios'}",
        f"DEVELOPMENT_TEAM={args.team}",
        "CODE_SIGN_STYLE=Automatic",
        f"MEDIEXPLAIN_IOS_INFO_PLIST={generated}",
        "-allowProvisioningUpdates",
        "build",
        cwd=MOBILE / "ios",
    )
    app = MOBILE / "build/ios/Release-iphoneos/Runner.app"
    run("codesign", "--verify", "--deep", "--strict", app)
    run("xcrun", "devicectl", "device", "install", "app", "--device", args.device, app)
    # Launch normally: no Flutter tooling, debugger, --start-stopped, or Dart VM attachment.
    run(
        "xcrun",
        "devicectl",
        "device",
        "process",
        "launch",
        "--device",
        args.device,
        "--terminate-existing",
        "com.mediexplain.mediexplain",
    )
    print(f"API server: {args.api_base_url}")
    print(
        "Signed Release app installed and launched without a debugger. It can reopen from the home screen."
    )


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"iPhone deployment failed: {error}", file=sys.stderr)
        sys.exit(1)
