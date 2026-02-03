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

if [[ ! -f docker-compose.yml ]]; then
  echo "Error: docker-compose.yml not found. Run this script from the silldisplay repo directory."
  exit 1
fi

DISPLAY_URL="http://localhost:3000/station/${STATION_ID}"
AUTOSTART_DIR="${HOME}/.config/lxsession/LXDE-pi"
AUTOSTART_FILE="${AUTOSTART_DIR}/autostart"

echo "=============================================="
echo "  Sill Display – Raspberry Pi Setup"
echo "=============================================="
echo "  Station ID:  ${STATION_ID}"
echo "  Display URL: ${DISPLAY_URL}"
echo "=============================================="
echo ""

# --- Install Docker if needed ---
if ! command -v docker &>/dev/null; then
  echo "Docker not found. Installing Docker..."
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  sudo sh /tmp/get-docker.sh
  sudo usermod -aG docker "${USER}"
  echo "Docker installed. You may need to log out and back in for group changes."
  echo "Re-run this script after logging back in."
  rm -f /tmp/get-docker.sh
  exit 0
fi

# --- Install Docker Compose plugin if needed ---
if ! docker compose version &>/dev/null; then
  echo "Docker Compose not found. Installing..."
  sudo apt-get update
  sudo apt-get install -y docker-compose-plugin
fi

# --- Pull or build and start the application ---
echo "Starting Sill Display..."
if docker compose pull 2>/dev/null; then
  echo "Image pulled from registry."
else
  echo "Could not pull from registry, building from source..."
  docker compose build
fi

docker compose up -d

echo "Waiting for application to be ready..."
for i in {1..30}; do
  if curl -s -o /dev/null -w "%{http_code}" "http://localhost:3000/station/${STATION_ID}" | grep -q "200"; then
    echo "Application is ready."
    break
  fi
  sleep 2
  if [[ $i -eq 30 ]]; then
    echo "Warning: Application may not be ready yet. Check with: docker compose logs -f silldisplay"
  fi
done

# --- Configure Chromium kiosk autostart ---
echo "Configuring Chromium kiosk autostart..."
mkdir -p "$AUTOSTART_DIR"

# Remove any existing Sill Display / chromium-browser autostart lines
if [[ -f "$AUTOSTART_FILE" ]]; then
  grep -v "chromium-browser.*localhost:3000" "$AUTOSTART_FILE" | grep -v "silldisplay" > "${AUTOSTART_FILE}.tmp" 2>/dev/null || true
  mv "${AUTOSTART_FILE}.tmp" "$AUTOSTART_FILE" 2>/dev/null || true
fi

# Add our autostart line
AUTOSTART_LINE="@chromium-browser --kiosk ${DISPLAY_URL} --incognito --noerrdialogs --disable-infobars --autoplay-policy=no-user-gesture-required"
echo "$AUTOSTART_LINE" >> "$AUTOSTART_FILE"
echo "  Added to ${AUTOSTART_FILE}"

# --- Disable screen blanking for kiosk ---
echo "Disabling screen blanking..."
if command -v xset &>/dev/null; then
  (
    sleep 5
    xset s off 2>/dev/null || true
    xset -dpms 2>/dev/null || true
    xset s noblank 2>/dev/null || true
  ) &
fi

# Add xset to autostart so it runs after desktop loads (disable screen blanking)
if [[ -f "$AUTOSTART_FILE" ]] && ! grep -q "xset s off" "$AUTOSTART_FILE"; then
  echo "@xset s off -dpms s noblank 2>/dev/null || true" >> "$AUTOSTART_FILE"
fi

# --- Enable Docker to start on boot (usually already enabled) ---
if systemctl is-enabled docker &>/dev/null; then
  echo "Docker is enabled to start on boot."
else
  sudo systemctl enable docker 2>/dev/null || true
fi

echo ""
echo "=============================================="
echo "  Setup complete!"
echo "=============================================="
echo ""
echo "  On each reboot:"
echo "    1. Docker starts the Sill Display app"
echo "    2. Chromium opens in kiosk mode to ${DISPLAY_URL}"
echo ""
echo "  To test now, open: ${DISPLAY_URL}"
echo ""
echo "  Reboot to apply:  sudo reboot"
echo ""
