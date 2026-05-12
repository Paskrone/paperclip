#!/bin/sh
set -e

# Capture runtime UID/GID from environment variables, defaulting to 1000
PUID=${USER_UID:-1000}
PGID=${USER_GID:-1000}

# Adjust the node user's UID/GID if they differ from the runtime request
# and fix volume ownership only when a remap is needed
changed=0

if [ "$(id -u node)" -ne "$PUID" ]; then
    echo "Updating node UID to $PUID"
    usermod -o -u "$PUID" node
    changed=1
fi

if [ "$(id -g node)" -ne "$PGID" ]; then
    echo "Updating node GID to $PGID"
    groupmod -o -g "$PGID" node
    usermod -g "$PGID" node
    changed=1
fi

if [ "$changed" = "1" ]; then
    chown -R node:node /paperclip
fi

# Railway-Kompatibilität: gemountete Volumes kommen mit root:root-Ownership
# unabhängig vom Dockerfile-build-chown. Wir prüfen + korrigieren das hier
# zur Laufzeit. Idempotent — wenn das Volume bereits dem node-User gehört,
# ist das ein No-Op.
if [ ! -w /paperclip ] || [ "$(stat -c '%u' /paperclip)" != "$(id -u node)" ]; then
    echo "Fixing /paperclip ownership (Railway-volume root → node)"
    chown -R node:node /paperclip
fi

exec gosu node "$@"
