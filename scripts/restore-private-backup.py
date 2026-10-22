#!/usr/bin/env python3
"""Decrypt and extract a private project backup using its separately saved key."""

import argparse
import io
from pathlib import Path
import tarfile

from cryptography.fernet import Fernet, InvalidToken


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--key-file", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        parser.error("Choose a new output directory; existing files are never overwritten.")
    try:
        decrypted = Fernet(args.key_file.read_bytes().strip()).decrypt(
            args.archive.read_bytes()
        )
    except (InvalidToken, ValueError):
        parser.error("The recovery key is incorrect or the encrypted archive was modified.")
    with tarfile.open(fileobj=io.BytesIO(decrypted), mode="r:gz") as archive:
        args.output.mkdir(mode=0o700, parents=True)
        archive.extractall(args.output, filter="data")
    print(f"Private backup restored to {args.output.resolve()}")


if __name__ == "__main__":
    main()
