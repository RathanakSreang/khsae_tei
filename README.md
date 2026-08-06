<img src="branding/khsae_tei_logo.png" alt="KHSAE TEI logo" width="160" />

# ខ្សែតី (KHSAE TEI)

A "whip-app": swing your phone, it plays a whip sound and tells your desktop to press **Enter** — handy for approving an AI confirmation prompt without reaching for the keyboard.

## Status: MVP (Linux desktop only)

- **mobile app** (Flutter) — detects the whip gesture via accelerometer, plays a sound, sends the signal.
- **desktop app** (Python) — runs the WebSocket server the phone connects to over LAN, and simulates the Enter keypress.
- **relay** (Node) — optional rendezvous server so the phone and desktop can pair over the internet when they're not on the same WiFi. Built and tested locally; not deployed anywhere public yet.

Bluetooth and other desktop OSes are not built yet — see `docs/protocol.md` for the full wire protocol and `CHECKLIST.md` for what's done vs. outstanding.

## Running it

### Desktop (`desktop/`)

Requires Python 3.10+ and [uv](https://docs.astral.sh/uv/).

```
cd desktop
uv venv
uv pip install -r requirements.txt
uv run main.py
```

On Linux, key simulation uses `pynput`, which needs an X11 session (or, on Wayland, access to `/dev/uinput` — typically means being in the `input` group or running as root).

The terminal prints the desktop's LAN IP, port, a 6-digit pairing code, and an ASCII QR code encoding both. Type `h` for the list of commands (regenerate the pairing code, connect/disconnect an internet relay, quit). There's also an optional relay connection — see below.

### Mobile (`mobile/`)

Requires Flutter >= 3.44.0 (Dart >= 3.12.0) — check with `flutter --version`, and run `flutter doctor` if anything's missing.

```
cd mobile
flutter pub get
flutter devices     # confirm your phone shows up
flutter run         # on a physical Android device, same WiFi network as the desktop
```

Connect the phone over USB with developer mode / USB debugging enabled (or use `flutter run -d <device-id>` with wireless debugging already paired via `adb pair`). The app needs camera access for QR scanning — accept the permission prompt on first launch.

In the app, pick **LAN** or **Internet** mode:
- **LAN**: tap **Discover** (mDNS) or **Scan QR**, or type the IP/port/code shown on the desktop, then **Connect**.
- **Internet**: enter the relay URL and the same pairing code, then **Connect**.

Once paired, tap **Test Whip** to confirm the round trip, or physically whip the phone.

### Relay (`relay/`) — optional, for pairing over the internet

```
cd relay
nvm use
npm install
npm start   # listens on port 9090 by default (PORT env var to override)
```

Then in the desktop terminal, type `c ws://<relay-host>:9090` (e.g. `c ws://localhost:9090` for local testing) — the desktop registers under its existing pairing code, and a phone can now reach it via that relay using the same code from anywhere, not just the same WiFi. Type `d` to disconnect. Not deployed anywhere public yet: this has only been run and tested on localhost so far. If you do deploy it publicly, put it behind TLS (`wss://`) — most hosting platforms do this for you automatically.

## Repo layout

```
desktop/   Python app (WebSocket server + keypress simulation + relay client)
mobile/    Flutter app (gesture detection + WebSocket client, LAN or relay)
relay/     Rendezvous server for pairing over the internet
docs/      Wire protocol spec
branding/  Logo / app icon source
```
