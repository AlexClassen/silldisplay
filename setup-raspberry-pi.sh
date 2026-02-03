#!/bin/bash
#
# Sill Display – Raspberry Pi Setup Script
#
# Usage: ./setup-raspberry-pi.sh <STATION_ID>
#
# Example: ./setup-raspberry-pi.sh 8100108
#   Opens http://localhost:3000/station/8100108 (Innsbruck Hauptbahnhof) on boot.
#
# Run this script from the silldisplay repo directory.
# Requires: Raspberry Pi OS with Desktop, internet connection.
#

set -e

STATION_ID="${1:-}"

if [[ -z "$STATION_ID" ]]; then
  echo "Usage: $0 <STATION_ID>"
  echo ""
  echo "Station ID is the ÖBB EVA ID (e.g. 8100108 for Innsbruck Hbf, 1370165 for Innsbruck Sillpark)."
  echo "Find IDs by searching at https://www.oebb.at or in the Sill Display web app."
  exit 1
fi

if ! [[ "$STATION_ID" =~ ^[0-9]+$ ]]; then
  echo "Error: STATION_ID must be a number (e.g. 8100108)"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ ! -f server.mjs ]]; then
  echo "Error: server.mjs not found. Run this script from the silldisplay repo directory."
  exit 1
fi

DISPLAY_URL="http://localhost:3000/station/${STATION_ID}"
AUTOSTART_DIR="${HOME}/.config/lxsession/LXDE-pi"
AUTOSTART_FILE="${AUTOSTART_DIR}/autostart"
SERVICE_FILE="/etc/systemd/system/silldisplay.service"

echo "=============================================="
echo "  Sill Display – Raspberry Pi Setup"
echo "=============================================="
echo "  Station ID:  ${STATION_ID}"
echo "  Display URL: ${DISPLAY_URL}"
echo "=============================================="
echo ""

# --- Install Node.js and Chromium if needed ---
if ! command -v node &>/dev/null; then
  echo "Node.js not found. Installing..."
  sudo apt-get update
  sudo apt-get install -y nodejs npm
fi

if ! command -v chromium-browser &>/dev/null && ! command -v chromium &>/dev/null; then
  echo "Chromium not found. Installing..."
  sudo apt-get update
  sudo apt-get install -y chromium-browser || sudo apt-get install -y chromium
fi

# --- Install dependencies ---
echo "Installing dependencies..."
npm install

# --- Create systemd service ---
echo "Creating systemd service..."
NODE_PATH="$(command -v node)"
sudo tee "$SERVICE_FILE" >/dev/null <<EOF
[Unit]
Description=Sill Display
After=network-online.target

[Service]
User=${USER}
WorkingDirectory=${SCRIPT_DIR}
ExecStart=${NODE_PATH} server.mjs
Restart=always
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable silldisplay.service
sudo systemctl restart silldisplay.service

echo "Waiting for application to be ready..."
for i in {1..30}; do
  if curl -s -o /dev/null -w "%{http_code}" "http://localhost:3000/station/${STATION_ID}" 2>/dev/null | grep -q "200"; then
    echo "Application is ready."
    break
  fi
  sleep 1
  if [[ $i -eq 30 ]]; then
    echo "Warning: Application may not be ready yet. Check with: sudo systemctl status silldisplay"
  fi
done

# --- Configure Chromium kiosk autostart ---
echo "Configuring Chromium kiosk autostart..."
mkdir -p "$AUTOSTART_DIR"

CHROMIUM_CMD="chromium-browser"
command -v chromium &>/dev/null && CHROMIUM_CMD="chromium"

if [[ -f "$AUTOSTART_FILE" ]]; then
  grep -v "chromium-browser.*localhost:3000" "$AUTOSTART_FILE" | grep -v "chromium.*localhost:3000" > "${AUTOSTART_FILE}.tmp" 2>/dev/null || true
  mv "${AUTOSTART_FILE}.tmp" "$AUTOSTART_FILE" 2>/dev/null || true
fi

AUTOSTART_LINE="@${CHROMIUM_CMD} --kiosk ${DISPLAY_URL} --incognito --noerrdialogs --disable-infobars --autoplay-policy=no-user-gesture-required"
echo "$AUTOSTART_LINE" >> "$AUTOSTART_FILE"
echo "  Added to ${AUTOSTART_FILE}"

# --- Disable screen blanking ---
if [[ -f "$AUTOSTART_FILE" ]] && ! grep -q "xset s off" "$AUTOSTART_FILE"; then
  echo "@xset s off -dpms s noblank 2>/dev/null || true" >> "$AUTOSTART_FILE"
fi

echo ""
echo "=============================================="
echo "  Setup complete!"
echo "=============================================="
echo ""
echo "  On each reboot:"
echo "    1. Sill Display starts automatically"
echo "    2. Chromium opens in kiosk mode to ${DISPLAY_URL}"
echo ""
echo "  To test now, open: ${DISPLAY_URL}"
echo ""
echo "  Reboot to apply:  sudo reboot"
echo ""
