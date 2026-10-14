#!/usr/bin/env python3
"""Build redistributable local-demo APKs or Apple app archives."""

import argparse
import hashlib
import json
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
MOBILE = ROOT / "apps/mobile"


def run(*command):
    subprocess.run([str(part) for part in command], cwd=MOBILE, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("platform", choices=("android", "ios-simulator", "ios-device"))
    parser.add_argument("--api-base-url", default="http://127.0.0.1:8000/api/v1/")
    parser.add_argument(
        "--verbose", action="store_true", help="Print native build diagnostics"
    )
    args = parser.parse_args()
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
            "Use an http(s) URL ending /api/v1/, without credentials/query/fragment."
        )
    flutter = shutil.which("flutter")
    if not flutter:
        parser.error("Install Flutter 3.44.5 and add it to PATH.")
    if args.platform != "android":
        if sys.platform != "darwin":
            parser.error("iOS builds require macOS, full Xcode, and CocoaPods.")
        xcode_version = subprocess.check_output(["xcodebuild", "-version"], text=True)
        print(xcode_version, end="")
        version = tuple(
            int(part) for part in xcode_version.splitlines()[0].split()[1].split(".")
        )
        if version < (26, 1, 1):
            parser.error(
                "The locked connectivity plugin requires Xcode 26.1.1+ (26.2 used in CI)."
            )
    run(flutter, "pub", "get", "--enforce-lockfile")
    defines = [
        "--dart-define=APP_ENV=development",
        f"--dart-define=API_BASE_URL={args.api_base_url}",
    ]
    if args.verbose:
        defines.append("--verbose")
    files = []
    if args.platform == "android":
        run(
            flutter,
            "build",
            "apk",
            "--release",
            "--split-per-abi",
            "--no-pub",
            *defines,
        )
        output = ROOT / "downloads/android"
        output.mkdir(parents=True, exist_ok=True)
        for abi in ("arm64-v8a", "armeabi-v7a", "x86_64"):
            source = MOBILE / "build/app/outputs/flutter-apk" / f"app-{abi}-release.apk"
            run(sys.executable, ROOT / "scripts/check-android-apk.py", source)
            target = output / f"MediExplain-{abi}.apk"
            shutil.copy2(source, target)
            files.append(target)
        notes = "Local demo; release-optimized; development environment; not a store-signed production release."
    else:
        simulator = args.platform == "ios-simulator"
        mode = "--debug" if simulator else "--release"
        run(
            flutter,
            "build",
            "ios",
            mode,
            "--no-codesign",
            "--no-pub",
            *(["--simulator"] if simulator else []),
            *defines,
        )
        source = (
            MOBILE
            / "build/ios"
            / ("iphonesimulator" if simulator else "iphoneos")
            / "Runner.app"
        )
        if not source.is_dir():
            raise RuntimeError(f"Expected Apple app bundle was not produced: {source}")
        output = ROOT / "downloads/ios"
        output.mkdir(parents=True, exist_ok=True)
        suffix = platform.machine() if simulator else "arm64-unsigned"
        archive = output / f"MediExplain-{args.platform}-{suffix}.zip"
        run("ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", source, archive)
        files.append(archive)
        notes = (
            "iOS Simulator only; architecture matches build host; not installable on an iPhone."
            if simulator
            else "Unsigned iPhone app bundle for developers; requires Apple signing before installation."
        )
    version_output = subprocess.check_output(
        [flutter, "--version", "--machine"], cwd=MOBILE, text=True
    )
    flutter_version = json.loads(version_output)["frameworkVersion"]
    sums = []
    for path in files:
        digest = hashlib.sha256()
        with path.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
        sums.append(f"{digest.hexdigest()}  {path.name}")
    manifest_name = "android" if args.platform == "android" else args.platform
    (output / f"SHA256SUMS-{manifest_name}.txt").write_text("\n".join(sums) + "\n")
    (output / f"build-info-{manifest_name}.json").write_text(
        json.dumps(
            {
                "platform": args.platform,
                "api_base_url": args.api_base_url,
                "app_environment": "development",
                "flutter_version": flutter_version,
                "source_commit": os.environ.get("GITHUB_SHA"),
                "notes": notes,
                "files": [path.name for path in files],
            },
            indent=2,
        )
        + "\n"
    )
    print(f"Built {len(files)} file(s) in {output}. {notes}")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, subprocess.CalledProcessError) as error:
        print(f"Build failed: {error}", file=sys.stderr)
        sys.exit(1)
