#!/usr/bin/python3.12
"""Run inside the proposed Linux rootfs before reviewing its byte inventory."""
import ctypes
import importlib
import importlib.metadata
import json
import platform
import sqlite3
import sys

required = {
    "sympy": ("sympy", "1.14.0"), "mpmath": ("mpmath", "1.3.0"),
    "numpy": ("numpy", "2.4.6"), "scipy": ("scipy", "1.17.1"),
    "scikit-learn": ("sklearn", "1.8.0"), "nltk": ("nltk", "3.9.4"),
    "regex": ("regex", "2026.5.9"), "zstandard": ("zstandard", "0.25.0"),
}
if sys.platform != "linux" or platform.machine() != "x86_64" or sys.version_info[:2] != (3, 12):
    raise SystemExit("requires Linux x86-64 Python 3.12")
versions = {}
for package, (module, version) in required.items():
    actual = importlib.metadata.version(package)
    if actual != version:
        raise SystemExit(f"{package}: expected {version}, found {actual}")
    importlib.import_module(module)
    versions[package] = actual
ctypes.CDLL("libgmp.so.10")
libc = ctypes.CDLL("libc.so.6")
libc.gnu_get_libc_version.restype = ctypes.c_char_p
glibc = libc.gnu_get_libc_version().decode()
if tuple(map(int, glibc.split("."))) < (2, 34):
    raise SystemExit("Earth kernel requires glibc >=2.34")
with sqlite3.connect(":memory:") as connection:
    if connection.execute("select 1").fetchone() != (1,):
        raise SystemExit("SQLite probe failed")
print(json.dumps({"python": platform.python_version(), "platform": "linux-x86_64",
                  "glibc": glibc, "sqlite": sqlite3.sqlite_version, "dependencies": versions,
                  "scope": "Runtime imports only; no Oracle queries or specialist qualification."}, sort_keys=True))
