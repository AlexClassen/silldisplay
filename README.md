# SillDisplay

SillDisplay is a small Raspberry Pi-powered departure board for **Innsbruck Sillpark**.
It polls the ÖBB API regularly and shows upcoming trams/buses on a fullscreen web
display – perfect for running on a monitor or TV via a Raspberry Pi.

The frontend is a single static `index.html` file (HTML/JS/CSS) and the backend is a
minimal Node.js/Express server that uses [`oebb-api`](https://github.com/mymro/oebb-api)
to fetch live data.

---

## Features

- 📡 Live departures from **Innsbruck Sillpark** (using ÖBB station board)
- ⏱ Shows **planned time** and **real-time (delayed) time**
- 🚌🚋 Badge indicating **Bus** or **Tram**
- 🔁 Automatic data refresh (backend polling + frontend refresh)
- 📜 Smooth auto-scrolling departure list for longer boards
- ❄️ Optional winter mode: **falling snowflakes** for Christmas vibes
- 🎛 Designed to run in **Chromium kiosk mode** on a Raspberry Pi

---

## Project Structure

Typical repo structure:

```text
silldisplay/
├── package.json
├── server.mjs
└── public/
    └── index.html
```

- **`server.mjs`** – Node.js server, uses `oebb-api` to fetch departures and exposes `/api/journeys`
- **`public/index.html`** – Frontend, fetches `/api/journeys` and renders the display

Your repository should already contain these files.

---

## 1. Requirements

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

---

## 2. Clone the Repository on the Raspberry Pi

Pick a folder (e.g. your home directory) and clone your repo.

> 🔁 Replace `<YOUR_GITHUB_URL>` with your actual repository URL.

```bash
cd ~
git clone <YOUR_GITHUB_URL> silldisplay
cd silldisplay
```

If your repo is already named `silldisplay`, you can skip the second argument to `git clone`.

---

## 3. Install Dependencies

Inside the project folder:

```bash
cd ~/silldisplay
npm install
```

Make sure your `package.json` has at least:

```jsonc
{
  "name": "silldisplay",
  "version": "1.0.0",
  "type": "module",
  "main": "server.mjs",
  "scripts": {
    "start": "node server.mjs"
  },
  "dependencies": {
    "express": "^4.x",
    "oebb-api": "^5.x"
  }
}
```

> Adjust versions as needed – `npm install express oebb-api` will fill them in automatically.

If needed, you can (re)install dependencies like this:

```bash
npm install express oebb-api
```

---

## 4. Test Locally on the Pi

Before automating anything, test that it runs:

```bash
cd ~/silldisplay
npm start
# or: node server.mjs
```

Open Chromium manually and go to:

```text
http://localhost:3000
```

You should see the SillDisplay board (with times, line, destination and snowflakes).  
If that works, stop the server with `Ctrl + C` in the terminal and continue.

---

## 5. Run as a Service (systemd)

We’ll use `systemd` so the backend starts automatically on boot.

Create a new service file:

```bash
sudo nano /etc/systemd/system/silldisplay.service
```

Paste the following (adjust paths if your home directory or folder name is different):

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

Check if it’s running:

```bash
sudo systemctl status silldisplay.service
```

You should see something like “active (running)” and log output from your server.

If you change `server.mjs` later, just restart:

```bash
sudo systemctl restart silldisplay.service
```

---

## 6. Auto-Start Chromium in Kiosk Mode

To turn your Pi into a dedicated display, we start Chromium in **kiosk mode** on login.

Create/edit the autostart file:

```bash
mkdir -p ~/.config/lxsession/LXDE-pi
nano ~/.config/lxsession/LXDE-pi/autostart
```

Add this line (replace any existing Chromium lines if needed):

```text
@chromium-browser --kiosk http://localhost:3000 --incognito --noerrdialogs --disable-infobars
```

This will:

- Open Chromium
- Load `http://localhost:3000`
- Hide toolbars and dialogs
- Run fullscreen

---

## 7. Reboot and Verify

Now reboot the Pi:

```bash
sudo reboot
```

On boot, the Pi should:

1. Start the desktop
2. Start `silldisplay.service` (Node backend)
3. Launch Chromium in fullscreen, showing your departure board

If anything doesn’t show up:

- Check the service logs:

  ```bash
  sudo systemctl status silldisplay.service
  ```

- And view detailed logs:

  ```bash
  journalctl -u silldisplay.service -e
  ```

---

## 8. Updating the Display Code Later

When you change the code in the GitHub repo and want to update the Pi:

```bash
cd ~/silldisplay
git pull
npm install               # only if you changed dependencies
sudo systemctl restart silldisplay.service
```

The browser will automatically pick up the changes when it reloads or on the next data fetch.

---

## 9. Development Notes

- The backend serves:
  - `/api/journeys` → JSON with departures
  - `/` → `public/index.html`
- The frontend:
  - Fetches `/api/journeys` every few seconds
  - Renders each departure as a row/card
  - Smoothly auto-scrolls the list
  - Shows falling snowflakes for a Christmas mood

You can run and debug the project on any machine with Node installed by doing:

```bash
npm install
npm start
```

and then open `http://localhost:3000` in a browser.

---

## 10. Customization Ideas

- Change the station (different `evaId` in `server.mjs`)
- Filter only specific lines (e.g. Tram 2 / Tram 5)
- Turn snow on/off via configuration flag
- Add day/night themes
- Add a small clock in the header

Enjoy your **SillDisplay** 🎄🚌🚋  
Ideal for entrances, lounges or info corners in/around Sillpark.
