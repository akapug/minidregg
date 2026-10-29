#!/bin/sh
set -eu

# The append redirection is a shell builtin: it creates a fresh grain journal
# without requiring coreutils in the otherwise static runtime.
: >> /var/journal
exec /opt/app/hledger-web --serve --allow=sandstorm --base-url= \
    --host=127.0.0.1 --port=8000 -f /var/journal
