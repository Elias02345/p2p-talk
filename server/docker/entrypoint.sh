#!/bin/sh
# Ensure the mounted data volume is writable by the non-root app user, then drop
# privileges. Fixes the common "named volume owned by root -> SQLite can't open"
# failure that otherwise crash-loops the signaling container.
set -e
mkdir -p /app/data
chown -R p2ptalk:p2ptalk /app/data 2>/dev/null || true
exec su-exec p2ptalk "$@"
