#!/bin/bash
set -euo pipefail
export HOME=/var PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
mkdir -p /var/sudoku
if [[ ! -f /var/sudoku/secret-key ]]; then
  head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' > /var/sudoku/secret-key
fi
export SECRET_KEY
SECRET_KEY=$(</var/sudoku/secret-key)
cd /opt/app
exec /usr/bin/python3 /opt/app/serve.py
