#!/bin/bash
set -euo pipefail

################################################################################
#
# create_proxy.sh
# Initialize a CMS VOMS proxy and store it inside this repo.
# Jiashu Huang (2026-01-27)
#
################################################################################

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
USER_ID=$(id -u)
PROXY_SOURCE="/tmp/x509up_u${USER_ID}"
PROXY_DEST="${SCRIPT_DIR}/x509up_u${USER_ID}"
PROXY_PATH_FILE="${SCRIPT_DIR}/proxy_path.txt"

# Initialize VOMS proxy with CMS credentials (168 hours validity)
voms-proxy-init -voms cms -valid 168:00

if [ ! -f "$PROXY_SOURCE" ]; then
  echo "ERROR: Proxy not found at ${PROXY_SOURCE}" >&2
  exit 1
fi

# Copy proxy into repo and lock permissions
cp "$PROXY_SOURCE" "$PROXY_DEST"
chmod 600 "$PROXY_DEST"

# Store proxy path for later use (e.g. condor delegation)
echo "$PROXY_DEST" > "$PROXY_PATH_FILE"

# Show a quick status
voms-proxy-info -file "$PROXY_DEST" -timeleft

echo ""
echo "Proxy initialized and copied to: $PROXY_DEST"
echo "Proxy path saved to: $PROXY_PATH_FILE"
echo ""
echo "To export in your shell:"
echo "  export X509_USER_PROXY=\"$(cat "$PROXY_PATH_FILE")\""
