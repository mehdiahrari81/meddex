#!/usr/bin/env python3
"""Start this Mac's existing presentation backend and keep it awake; no rebuilds."""

import argparse
import ipaddress
import json
import os
import re
import shutil
import subprocess
import sys
import time
from urllib.error import URLError
from urllib.request import HTTPRedirectHandler, ProxyHandler, build_opener


def command(*parts, timeout=15):
    return subprocess.run(
        parts, check=True, capture_output=True, text=True, timeout=timeout
    ).stdout.strip()


def docker_ready():
    try:
        command("docker", "info", "--format", "{{.ServerVersion}}", timeout=5)
        return True
    except (subprocess.SubprocessError, OSError):
        return False


def wait_until(check, description, timeout=120):
    deadline = time.monotonic() + timeout
    while not check():
        if time.monotonic() >= deadline:
            raise RuntimeError(f"Timed out waiting for {description}.")
        time.sleep(2)


def existing_services(project):
    rows = command(
        "docker",
        "ps",
        "-a",
        "--filter",
        f"label=com.docker.compose.project={project}",
        "--format",
        '{{.ID}}\t{{.Label "com.docker.compose.service"}}\t{{.State}}',
    )
    services = {}
    for row in rows.splitlines():
        identifier, service, state = row.split("\t")
        if service not in {"postgres", "api", "mailpit", "admin"}:
            continue
        if service in services:
            raise RuntimeError(
                f"Multiple {service} containers; select the correct --project."
            )
        services[service] = (identifier, state)
    if not {"postgres", "api"}.issubset(services):
        raise RuntimeError(
            f"No complete existing backend for project {project!r}. "
            f"Use python3 scripts/dev.py --project {project} start --ai --ocr "
            "for initial setup. This helper never creates or replaces a database."
        )
    return services


def healthy(identifier):
    return (
        command(
            "docker",
            "inspect",
            "--format",
            "{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}",
            identifier,
        )
        == "healthy"
    )


def start_existing(services, check_only=False):
    for service in ("postgres", "mailpit", "api", "admin"):
        if service not in services:
            continue
        identifier, state = services[service]
        if state != "running":
            if check_only:
                raise RuntimeError(
                    f"{service} is stopped. Run this command without --check-only."
                )
            print(f"Starting existing {service} container…", flush=True)
            command("docker", "start", identifier, timeout=30)
        if service in {"postgres", "api"}:
            if check_only:
                if not healthy(identifier):
                    raise RuntimeError(f"{service} is not healthy yet.")
            else:
                print(f"Waiting for {service} readiness…", flush=True)
                wait_until(lambda identifier=identifier: healthy(identifier), service)


def api_port(identifier):
    bindings = command("docker", "port", identifier, "8000/tcp").splitlines()
    for binding in bindings:
        host, port = binding.rsplit(":", 1)
        if host == "0.0.0.0":
            return int(port)
    raise RuntimeError(
        "The API has no IPv4 LAN port binding; check docker-compose.yml."
    )


def automatic_url(port):
    hostname = command("scutil", "--get", "LocalHostName")
    if not re.fullmatch(r"[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?", hostname):
        raise RuntimeError("This Mac has no valid Bonjour LocalHostName.")
    return f"http://{hostname}.local:{port}/api/v1/"


def current_wifi_ip():
    try:
        ports = command("networksetup", "-listallhardwareports")
        match = re.search(r"Hardware Port: Wi-Fi\nDevice: (\S+)", ports)
        if match is None:
            return None
        value = command("ipconfig", "getifaddr", match.group(1))
        address = ipaddress.IPv4Address(value)
        if any(
            address in ipaddress.IPv4Network(block)
            for block in ("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16")
        ):
            return value
    except (OSError, subprocess.SubprocessError, ValueError):
        pass
    return None


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def check_ready(base_url):
    # No environment proxy, credentials, cookies, uploads or redirects.
    opener = build_opener(ProxyHandler({}), NoRedirect())
    with opener.open(base_url + "ready", timeout=5) as response:
        return response.status == 200 and json.loads(response.read(4096)) == {
            "status": "ready"
        }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--project", default="meddex", help="Existing Compose project (default: meddex)"
    )
    parser.add_argument(
        "--check-only",
        action="store_true",
        help="Check once without starting services or keeping the Mac awake",
    )
    args = parser.parse_args()
    if sys.platform != "darwin":
        raise RuntimeError(
            "This presentation helper is for the Mac hosting the iPhone backend."
        )
    if not shutil.which("docker"):
        raise RuntimeError("Install Docker Desktop first.")
    if not docker_ready():
        if args.check_only:
            raise RuntimeError("Docker Desktop is stopped.")
        print("Starting Docker Desktop; waiting for its engine…", flush=True)
        command("open", "-a", "Docker")
        wait_until(docker_ready, "Docker Desktop", timeout=180)
    services = existing_services(args.project)
    start_existing(services, check_only=args.check_only)
    base = automatic_url(api_port(services["api"][0]))
    if not check_ready(base):
        raise RuntimeError("The API did not return its readiness response.")
    print(f"Automatic server: {base}")
    if "admin" in services:
        print("Admin portal: http://localhost:3000")
    wifi_ip = current_wifi_ip()
    print(f"Current Wi-Fi address: {wifi_ip or 'no private IPv4 Wi-Fi address'}")
    print("Backend readiness passed on the Mac. Verify a scan on the iPhone too.")
    print(
        "In MediExplain: Settings → Server connection → Find my Mac automatically → Test and save."
    )
    print(
        "Keep both devices on a LAN that allows device-to-device traffic. "
        "Automatic connection uses the Mac's name and its verified address cache."
    )
    if args.check_only:
        return
    guard = subprocess.Popen(["caffeinate", "-is", "-w", str(os.getpid())])
    try:
        print(
            "Presentation mode is active. Keep this terminal open and the Mac lid open.",
            flush=True,
        )
        print(
            "Press Ctrl+C when finished; the backend and saved data stay in place.",
            flush=True,
        )
        last_ready = True
        while True:
            time.sleep(10)
            new_ip = current_wifi_ip()
            if new_ip != wifi_ip:
                print(
                    f"Wi-Fi address changed: {new_ip or 'disconnected'}. "
                    "Check that the iPhone joined the same Wi-Fi; retry any interrupted scan. "
                    "The automatic server name stays the same.",
                    flush=True,
                )
                wifi_ip = new_ip
            try:
                ready = check_ready(base)
            except (URLError, OSError, ValueError):
                ready = False
            if ready != last_ready:
                print(
                    "Backend is ready again."
                    if ready
                    else "Backend is unreachable; check Docker and Wi-Fi.",
                    flush=True,
                )
                last_ready = ready
    except KeyboardInterrupt:
        print("\nPresentation sleep guard stopped; backend left running.")
    finally:
        guard.terminate()
        try:
            guard.wait(timeout=3)
        except subprocess.TimeoutExpired:
            guard.kill()
            guard.wait()


if __name__ == "__main__":
    try:
        main()
    except (OSError, subprocess.SubprocessError, RuntimeError, ValueError) as error:
        print(f"Presentation setup failed: {error}", file=sys.stderr)
        sys.exit(1)
