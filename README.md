# SillDisplay

SillDisplay is a small Raspberry Pi-powered departure board for Austrian stations.
It uses the ÖBB API to search for stations and display live departures – perfect for
running on a monitor or TV via a Raspberry Pi.

The frontend consists of two pages: a **homepage** with station search and a **station page**
showing departures. The backend is a minimal Node.js/Express server that uses
[`oebb-api`](https://github.com/mymro/oebb-api) to fetch live data.

---

## Features

- 🔍 **Station search** – Search all ÖBB stations by name (e.g. Innsbruck, Wien Hbf)
- 📡 **Live departures** – Any station’s upcoming trams/buses/trains
- ⏱ Shows **planned time** and **real-time (delayed) time**
- 🚌🚋 Badge indicating **Bus** or **Tram**
- 🔁 Automatic data refresh (backend polling + frontend refresh)
- ❄️ Optional winter mode: **falling snowflakes** for Christmas vibes
- 🎛 Designed to run in **Chromium kiosk mode** on a Raspberry Pi
- 🐳 **Docker deployment** with automatic updates via Watchtower

---

## Project Structure

```text
silldisplay/
├── package.json
├── server.mjs
├── Dockerfile
├── docker-compose.yml
├── .github/workflows/docker-build.yml
└── public/
    ├── index.html      # Homepage: station search
    └── station.html    # Station page: departure board
```

- **`server.mjs`** – Node.js server; exposes `/api/stations/search`, `/api/journeys`, and serves the frontend
- **`public/index.html`** – Homepage with search bar; searches ÖBB stations and links to `/station/:evaId`
- **`public/station.html`** – Station departure board; loads journeys for the station ID in the URL path
- **`Dockerfile`** – Container definition for the application
- **`docker-compose.yml`** – Docker Compose configuration with Watchtower for auto-updates

---

## Deployment Options

This project supports two deployment methods:

1. **[Docker Deployment (Recommended)](#docker-deployment)** – Easy setup with automatic updates via Watchtower
2. **[Manual Deployment](#manual-deployment)** – Traditional systemd service setup

---

## Docker Deployment

This is the recommended method for Raspberry Pi 5. It uses Docker and Watchtower to automatically update the application when new versions are pushed to GitHub.

### Prerequisites

- Raspberry Pi 5 with **Raspberry Pi OS** (64-bit recommended)
- Internet connection
- Docker and Docker Compose installed
- GitHub repository with GitHub Actions enabled

### Step 1: Install Docker on Raspberry Pi

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add your user to docker group (replace 'pi' with your username)
sudo usermod -aG docker pi

# Install Docker Compose
sudo apt install -y docker-compose-plugin

# Log out and back in, or run:
newgrp docker

# Verify installation
docker --version
docker compose version
```

### Step 2: Configure GitHub Container Registry Access

The Docker image will be built and pushed to GitHub Container Registry (GHCR) automatically via GitHub Actions. On your Raspberry Pi, you need to authenticate to pull the image.

1. **Create a GitHub Personal Access Token (PAT)**:
   - Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
   - Generate a new token with `read:packages` permission
   - Copy the token

2. **Login to GHCR on your Raspberry Pi**:

```bash
echo "YOUR_GITHUB_TOKEN" | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
```

Replace:

- `YOUR_GITHUB_TOKEN` with your PAT
- `YOUR_GITHUB_USERNAME` with your GitHub username

### Step 3: Set Up the Application

```bash
# Clone the repository
cd ~
git clone https://github.com/YOUR_USERNAME/silldisplay.git
cd silldisplay

# Edit docker-compose.yml and replace GITHUB_USERNAME with your GitHub username
nano docker-compose.yml
# Change: image: ghcr.io/${GITHUB_USERNAME}/silldisplay:latest
# To: image: ghcr.io/YOUR_ACTUAL_USERNAME/silldisplay:latest
```

### Step 4: Start the Application

```bash
# Start the containers
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f silldisplay
```

The application will be available at `http://localhost:3000`.

### Step 5: Set Up Auto-Start Chromium in Kiosk Mode

Create/edit the autostart file:

```bash
mkdir -p ~/.config/lxsession/LXDE-pi
nano ~/.config/lxsession/LXDE-pi/autostart
```

Add this line:

```text
@chromium-browser --kiosk http://localhost:3000 --incognito --noerrdialogs --disable-infobars
```

### Step 6: Configure Watchtower (Automatic Updates)

Watchtower is already configured in `docker-compose.yml` and will:

- Check for new images every 5 minutes (300 seconds)
- Automatically pull and restart containers when updates are available
- Clean up old images to save space

The Watchtower container monitors the `silldisplay` container and will automatically update it when you push changes to the `main` or `master` branch, or when you create a new release tag.

### Step 7: Verify Everything Works

```bash
# Reboot the Pi
sudo reboot
```

After reboot:

1. Docker containers should start automatically
2. Chromium should open in kiosk mode
3. Watchtower will check for updates every 5 minutes

### Updating the Application

**Automatic Updates**: Watchtower will automatically detect and apply updates when you push **any changes** to GitHub (including changes to `server.mjs`, `public/index.html`, or any other files). The update process works as follows:

1. **You push changes** to the `main` or `master` branch (or create a release tag)
2. **GitHub Actions** automatically builds a new Docker image that includes all your changes
3. **The new image** is pushed to GitHub Container Registry (GHCR)
4. **Watchtower** detects the new image (checks every 5 minutes)
5. **Watchtower** automatically pulls the new image and restarts the container
6. **Your Raspberry Pi** now runs the updated code - no manual intervention needed!

**Note**: Changes to `public/index.html`, `server.mjs`, `package.json`, or any other files will all be included in the new Docker image and automatically deployed.

**Manual Update** (if needed):

```bash
cd ~/silldisplay
docker compose pull
docker compose up -d
```

### Troubleshooting

- **Check container status**: `docker compose ps`
- **View application logs**: `docker compose logs -f silldisplay`
- **View Watchtower logs**: `docker compose logs -f watchtower`
- **Restart containers**: `docker compose restart`
- **Check if image is accessible**: `docker pull ghcr.io/YOUR_USERNAME/silldisplay:latest`

---

## Manual Deployment

This is the traditional method using systemd. Use this if you prefer not to use Docker.

### Requirements

- Raspberry Pi with **Raspberry Pi OS with Desktop**
- Internet connection (for reaching the ÖBB API)
- Monitor/TV connected via HDMI
- Node.js (from Debian/Raspberry Pi OS repos is usually fine)
- Chromium browser (installed from apt)

On the Raspberry Pi, install basics:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git nodejs npm chromium-browser
```

You can check your Node/npm versions with:

```bash
node -v
npm -v
```

### Step 1: Clone the Repository

```bash
cd ~
git clone <YOUR_GITHUB_URL> silldisplay
cd silldisplay
```

### Step 2: Install Dependencies

```bash
cd ~/silldisplay
npm install
```

### Step 3: Test Locally

```bash
cd ~/silldisplay
npm start
```

Open Chromium manually and go to `http://localhost:3000`. If it works, stop the server with `Ctrl + C`.

### Step 4: Run as a Service (systemd)

Create a new service file:

```bash
sudo nano /etc/systemd/system/silldisplay.service
```

Paste the following (adjust paths if needed):

```ini
[Unit]
Description=SillDisplay – Sillpark Departures
After=network-online.target

[Service]
User=pi
WorkingDirectory=/home/pi/silldisplay
ExecStart=/usr/bin/node /home/pi/silldisplay/server.mjs
Restart=always
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
```

Then enable and start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable silldisplay.service
sudo systemctl start silldisplay.service
```

Check if it's running:

```bash
sudo systemctl status silldisplay.service
```

### Step 5: Auto-Start Chromium in Kiosk Mode

```bash
mkdir -p ~/.config/lxsession/LXDE-pi
nano ~/.config/lxsession/LXDE-pi/autostart
```

Add this line:

```text
@chromium-browser --kiosk http://localhost:3000 --incognito --noerrdialogs --disable-infobars
```

### Step 6: Reboot and Verify

```bash
sudo reboot
```

### Updating the Application (Manual Method)

When you change the code in the GitHub repo:

```bash
cd ~/silldisplay
git pull
npm install               # only if you changed dependencies
sudo systemctl restart silldisplay.service
```

---

## Development Notes

- **Backend** serves:
  - `/api/stations/search?q=…` → JSON with matching stations from ÖBB
  - `/api/journeys?evaId=…` → JSON with departures for a station
  - `/` → Homepage (station search)
  - `/station/:evaId` → Station departure board
- **Homepage**: Search bar, debounced API calls, click a result → redirect to `/station/{evaId}`
- **Station page**: Reads `evaId` from the URL path, fetches journeys, auto-refreshes every 15 seconds

You can run and debug the project on any machine with Node installed:

```bash
npm install
npm start
```

Then open `http://localhost:3000` in a browser.

---

## Customization Ideas

- Change the station (different `evaId` in `server.mjs`)
- Filter only specific lines (e.g. Tram 2 / Tram 5)
- Turn snow on/off via configuration flag
- Add day/night themes
- Add a small clock in the header

Enjoy your **SillDisplay** 🎄🚌🚋  
Ideal for entrances, lounges or info corners in/around Sillpark.
