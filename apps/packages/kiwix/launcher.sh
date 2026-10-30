#!/bin/bash
set -euo pipefail
export HOME=/var PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
mkdir -p /var/data/chunking /var/tmp
cd /var/data
exec /usr/bin/python3 /opt/app/adapter.py
