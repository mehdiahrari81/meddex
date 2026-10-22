"""Run with services/api/.venv/bin/python; provision a persistent development identity."""

import os
from pathlib import Path

from cryptography.hazmat.primitives.asymmetric import ec

path = Path(__file__).resolve().parents[1] / "services/api/.env"
content = path.read_text() if path.exists() else ""
name = "MEDIEXPLAIN_LOCAL_SERVER_PRIVATE_KEY"
existing = next(
    (
        line.split("=", 1)[1].strip()
        for line in content.splitlines()
        if line.strip().startswith(name + "=")
    ),
    None,
)
if existing:
    print("Existing local-server identity preserved.")
else:
    private = ec.generate_private_key(ec.SECP256R1()).private_numbers().private_value
    if existing is not None:
        raise SystemExit(
            "An empty identity setting exists; remove that empty line and rerun."
        )
    with path.open("a") as file:
        file.write(f"\n{name}={private:064x}\n")
    print(
        "Local-server identity provisioned. Restart the API before installing the app."
    )
os.chmod(path, 0o600)
