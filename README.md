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
- 📡 **Live departures** – Any station's upcoming trams/buses/trains
- ⏱ Shows **planned time** and **real-time (delayed) time**
- 🚌🚋 Badge indicating **Bus** or **Tram**
- 🔁 Automatic data refresh (backend polling + frontend refresh)
- 🎛 Designed to run in **Chromium kiosk mode** on a Raspberry Pi

---

## Project Structure

```text
silldisplay/
├── package.json
├── server.mjs
├── setup-raspberry-pi.sh   # One-command Raspberry Pi setup
└── public/
    ├── index.html      # Homepage: station search
    └── station.html    # Station page: departure board
```

---

## Raspberry Pi Setup

**Requirements:** Raspberry Pi OS with Desktop, internet connection.

Clone the repo and run the setup script:

```bash
cd ~
git clone https://github.com/YOUR_USERNAME/silldisplay.git
cd silldisplay
chmod +x setup-raspberry-pi.sh
./setup-raspberry-pi.sh <STATION_ID>
```

Example: `./setup-raspberry-pi.sh 8100108` opens Innsbruck Hauptbahnhof on boot.

The script will:
- Install Node.js and Chromium if needed
- Install npm dependencies
- Create a systemd service (starts on boot)
- Configure Chromium kiosk mode to open `http://localhost:3000/station/<STATION_ID>`
- Disable screen blanking

Reboot when done: `sudo reboot`

### Updating

```bash
cd ~/silldisplay
git pull
npm install
sudo systemctl restart silldisplay
```

### Troubleshooting

- **Check service status**: `sudo systemctl status silldisplay`
- **View logs**: `sudo journalctl -u silldisplay -f`
- **Restart service**: `sudo systemctl restart silldisplay`

---

## Local Development

```bash
npm install
npm start
```

Open `http://localhost:3000` in a browser.

---

## API

- `GET /api/stations/search?q=…` – Search ÖBB stations
- `GET /api/journeys?evaId=…` – Departures for a station
- `GET /` – Homepage (station search)
- `GET /station/:evaId` – Station departure board
