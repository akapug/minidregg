"""Start the read-only Datasette grain service."""

import os
from pathlib import Path


PYTHON = "/opt/app/venv/bin/python"
PORT = os.environ.get("DATASETTE_PORT", "8001")

Path("/var/databases").mkdir(parents=True, exist_ok=True)
Path("/var/tmpfs").mkdir(parents=True, exist_ok=True)
os.chdir("/opt/app")
os.execv(
    PYTHON,
    [
        PYTHON,
        "-m",
        "datasette",
        "/var/databases",
        "--metadata",
        "/opt/app/metadata.yml",
        "--host",
        "127.0.0.1",
        "--port",
        PORT,
        "--root",
    ],
)
