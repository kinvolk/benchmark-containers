set -eu

SYSTEM=$(/usr/local/bin/cpu.sh system)
echo "$SYSTEM"

printf '#!/bin/sh\necho "%s"' "$SYSTEM" > /tmp/system
chmod +x /tmp/system
nc -lk -p 9999 -e /tmp/system &

fortio server -ui-path ''
