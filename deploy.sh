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

echo "Packaging Roku channel..."
rm -f "$ZIP_FILE"
cd "$CHANNEL_DIR"
zip -r "$ZIP_FILE" manifest source/ components/ images/ -x "*.DS_Store" "Makefile" "images/generate_placeholders.sh"
echo "Created $ZIP_FILE"

echo "Deploying to Roku at $ROKU_IP..."
curl --user "rokudev:$ROKU_DEV_PASSWORD" --digest \
    -F "mysubmit=Install" \
    -F "archive=@$ZIP_FILE" \
    "http://$ROKU_IP/plugin_install"

echo ""
echo "Deploy complete! Channel should appear on your Roku."
