#!/usr/bin/env python3
"""Reject Android builds that omit native libraries required at runtime."""

import argparse
from pathlib import Path
from zipfile import ZipFile


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    args = parser.parse_args()
    with ZipFile(args.apk) as archive:
        entries = set(archive.namelist())
    architectures = sorted(
        entry.split("/")[1]
        for entry in entries
        if entry.startswith("lib/") and entry.endswith("/libflutter.so")
    )
    if not architectures:
        parser.exit(1, "FAIL: APK contains no Flutter native libraries.\n")
    missing = [
        f"lib/{architecture}/{library}"
        for architecture in architectures
        for library in ("libdartjni.so", "libsqlite3.so")
        if f"lib/{architecture}/{library}" not in entries
    ]
    if missing:
        parser.exit(
            1,
            "FAIL: APK is missing required native libraries:\n"
            + "\n".join(missing)
            + "\nInstall a complete Android NDK, clean the native build, and rebuild.\n",
        )
    print(
        f"PASS: Required Android native libraries packaged for {', '.join(architectures)}."
    )


if __name__ == "__main__":
    main()
