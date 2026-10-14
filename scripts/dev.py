#!/usr/bin/env python3
"""Cross-platform local handoff commands; Python standard library only."""

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]


def executable(name):
    resolved = shutil.which(name)
    if not resolved:
        raise RuntimeError(
            f"Install {name} and add it to PATH. See docs/RUN_ON_ANOTHER_LAPTOP.md."
        )
    return resolved


def run(command, capture=False, cwd=ROOT):
    return subprocess.run(
        [str(part) for part in command],
        cwd=cwd,
        check=True,
        text=True,
        stdout=subprocess.PIPE if capture else None,
    )


def compose(args, *command, ai=False, capture=False):
    base = [
        executable("docker"),
        "compose",
        "--project-name",
        args.project,
        "--project-directory",
        ROOT,
        "-f",
        ROOT / "docker-compose.yml",
    ]
    if ai:
        base += ["-f", ROOT / "docker-compose.ai.yml"]
    return run(base + list(command), capture=capture)


def service_port(args, service, internal_port):
    output = compose(
        args, "port", service, str(internal_port), capture=True
    ).stdout.strip()
    if not output:
        raise RuntimeError(f"{service} is not running. Start the stack first.")
    return int(output.splitlines()[0].rsplit(":", 1)[1])


def show_urls(args):
    api = service_port(args, "api", 8000)
    admin = service_port(args, "admin", 3000)
    mail = service_port(args, "mailpit", 8025)
    with urlopen(f"http://127.0.0.1:{api}/api/v1/ready", timeout=10) as response:
        if response.status != 200:
            raise RuntimeError("The API is not ready; use the logs command.")
    print(f"Admin:    http://localhost:{admin}")
    print(f"API docs: http://localhost:{api}/docs")
    print(f"Mailpit:  http://localhost:{mail}")
    print(f"Create your admin: python3 scripts/dev.py --project {args.project} admin")


def adb_executable():
    available = shutil.which("adb")
    if available:
        return available
    candidates = [os.environ.get("ANDROID_HOME"), os.environ.get("ANDROID_SDK_ROOT")]
    if sys.platform == "darwin":
        candidates.append(str(Path.home() / "Library/Android/sdk"))
    elif sys.platform == "win32":
        candidates.append(str(Path(os.environ.get("LOCALAPPDATA", "")) / "Android/Sdk"))
    else:
        candidates.append(str(Path.home() / "Android/Sdk"))
    for candidate in candidates:
        if candidate:
            path = (
                Path(candidate)
                / "platform-tools"
                / ("adb.exe" if os.name == "nt" else "adb")
            )
            if path.is_file():
                return str(path)
    raise RuntimeError("Install Android SDK Platform-Tools (adb), or set ANDROID_HOME.")


def android_device(args):
    adb = adb_executable()
    lines = run([adb, "devices"], capture=True).stdout.splitlines()
    devices = [
        line.split()[0]
        for line in lines[1:]
        if len(line.split()) >= 2 and line.split()[1] == "device"
    ]
    if args.device:
        if args.device not in devices:
            raise RuntimeError(
                "Selected Android device is unavailable or not authorized."
            )
        serial = args.device
    elif len(devices) == 1:
        serial = devices[0]
    else:
        raise RuntimeError(
            "Connect/authorize one Android device, or select it with --device SERIAL."
        )
    return adb, serial


def connect_android(args):
    adb, serial = android_device(args)
    port = service_port(args, "api", 8000)
    run([adb, "-s", serial, "reverse", "tcp:8000", f"tcp:{port}"])
    print(f"Connected {serial}: app port 8000 -> laptop API port {port}.")
    return adb, serial


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--project",
        default=os.environ.get("MEDIEXPLAIN_COMPOSE_PROJECT", "mediexplain"),
        help="Compose project name; reuse the same value on every command",
    )
    commands = parser.add_subparsers(dest="command", required=True)
    start = commands.add_parser(
        "start", help="Build/start services and wait for readiness"
    )
    start.add_argument(
        "--ai",
        action="store_true",
        help="Connect API to host Ollama; see AI_FEATURES.md",
    )
    commands.add_parser(
        "stop", help="Stop containers while retaining the database volume"
    )
    commands.add_parser("status")
    commands.add_parser("logs")
    admin = commands.add_parser(
        "admin", help="Interactively provision a named local administrator"
    )
    admin.add_argument("--email")
    admin.add_argument("--name")
    admin.add_argument("--mfa", action="store_true")
    demo = commands.add_parser("demo", help="Add labeled synthetic dashboard examples")
    demo.add_argument("--email", required=True, help="Existing administrator email")
    for name in ("connect-android", "install-android"):
        command = commands.add_parser(name)
        command.add_argument("--device", help="adb device serial")
    mobile = commands.add_parser(
        "run-mobile", help="Run the Flutter source on a selected device"
    )
    mobile.add_argument("--platform", choices=("android", "ios"), default="android")
    mobile.add_argument(
        "--device", help="adb serial on Android; Flutter device ID on iOS"
    )
    args = parser.parse_args()

    if args.command == "start":
        compose(
            args, "up", "-d", "--build", "--wait", "--wait-timeout", "300", ai=args.ai
        )
        show_urls(args)
    elif args.command == "stop":
        compose(args, "down")
        print("Stopped. Your database volume is retained.")
    elif args.command == "status":
        compose(args, "ps")
        show_urls(args)
    elif args.command == "logs":
        compose(args, "logs", "--tail", "100", "-f", "api", "admin")
    elif args.command == "admin":
        email = args.email or input("Admin email: ").strip()
        name = args.name or input("Display name: ").strip()
        command = [
            "exec",
            "api",
            "python",
            "-m",
            "app.cli",
            "provision-admin",
            "--email",
            email,
            "--name",
            name,
            "--role",
            "SUPER_ADMIN",
        ]
        if args.mfa:
            command.append("--mfa")
        compose(args, *command)
    elif args.command == "demo":
        compose(
            args,
            "exec",
            "-T",
            "api",
            "python",
            "-m",
            "app.cli",
            "seed-demo",
            "--actor-email",
            args.email,
            "--path",
            "/opt/mediexplain/reference/starter_dataset_v1.json",
        )
    elif args.command in ("connect-android", "install-android"):
        adb, serial = connect_android(args)
        if args.command == "install-android":
            abi = run(
                [adb, "-s", serial, "shell", "getprop", "ro.product.cpu.abi"],
                capture=True,
            ).stdout.strip()
            apk = ROOT / "downloads/android" / f"MediExplain-{abi}.apk"
            if not apk.is_file():
                raise RuntimeError(
                    f"No bundled APK for {abi}; see downloads/android/README.md."
                )
            run([adb, "-s", serial, "install", "-r", apk])
            run(
                [
                    adb,
                    "-s",
                    serial,
                    "shell",
                    "am",
                    "start",
                    "-W",
                    "-a",
                    "android.intent.action.MAIN",
                    "-c",
                    "android.intent.category.LAUNCHER",
                    "-n",
                    "com.mediexplain.mediexplain/.MainActivity",
                ]
            )
    elif args.command == "run-mobile":
        flutter = executable("flutter")
        if args.platform == "android":
            _, device = connect_android(args)
            url = "http://127.0.0.1:8000/api/v1/"
        else:
            if sys.platform != "darwin":
                raise RuntimeError("iOS development requires a Mac with full Xcode.")
            run([executable("xcodebuild"), "-version"], capture=True)
            device = args.device
            if not device:
                raise RuntimeError(
                    "Select an iOS Simulator with --device ID (flutter devices)."
                )
            url = f"http://localhost:{service_port(args, 'api', 8000)}/api/v1/"
        run([flutter, "pub", "get", "--enforce-lockfile"], cwd=ROOT / "apps/mobile")
        run(
            [
                flutter,
                "run",
                "-d",
                device,
                "--dart-define=APP_ENV=development",
                f"--dart-define=API_BASE_URL={url}",
            ],
            cwd=ROOT / "apps/mobile",
        )


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError) as error:
        print(f"Error: {error}", file=sys.stderr)
        sys.exit(1)
    except subprocess.CalledProcessError as error:
        print(
            f"Command failed (exit {error.returncode}). See the message above and the setup guide.",
            file=sys.stderr,
        )
        sys.exit(error.returncode)
    except KeyboardInterrupt:
        sys.exit(130)
