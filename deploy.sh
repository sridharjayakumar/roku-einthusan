#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHANNEL_DIR="$SCRIPT_DIR/channel"
PROXY_DIR="$SCRIPT_DIR/proxy"
ZIP_FILE="$CHANNEL_DIR/einthusan.zip"

# Load env vars from proxy/.env
if [ -f "$PROXY_DIR/.env" ]; then
    export $(grep -v '^#' "$PROXY_DIR/.env" | xargs)
fi

if [ -z "$ROKU_IP" ] || [ -z "$ROKU_DEV_PASSWORD" ]; then
    echo "Error: ROKU_IP and ROKU_DEV_PASSWORD must be set in proxy/.env"
    exit 1
fi

if [ -z "$NAS_IP" ]; then
    echo "Error: NAS_IP must be set in proxy/.env"
    exit 1
fi

# Build the proxy URL the channel talks to. PORT defaults to 3000 if unset.
NAS_URL="http://$NAS_IP:${PORT:-3000}"

echo "Packaging Roku channel (proxy at $NAS_URL)..."
rm -f "$ZIP_FILE"

# Stage a copy so we can inject the proxy URL without touching source files.
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT
cp -R "$CHANNEL_DIR/." "$BUILD_DIR/"

# Substitute the {{NAS_URL}} placeholder in the channel's BrightScript.
grep -rl "{{NAS_URL}}" "$BUILD_DIR/components" | while read -r f; do
    sed -i.bak "s|{{NAS_URL}}|$NAS_URL|g" "$f" && rm -f "$f.bak"
done

cd "$BUILD_DIR"
zip -r "$ZIP_FILE" manifest source/ components/ images/ -x "*.DS_Store" "Makefile" "images/generate_placeholders.sh"
echo "Created $ZIP_FILE"

echo "Deploying to Roku at $ROKU_IP..."
curl --user "rokudev:$ROKU_DEV_PASSWORD" --digest \
    -F "mysubmit=Install" \
    -F "archive=@$ZIP_FILE" \
    "http://$ROKU_IP/plugin_install"

echo ""
echo "Deploy complete! Channel should appear on your Roku."
