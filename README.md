<img src="branding/khsae_tei_logo.png" alt="KHSAE TEI logo" width="160" />

# ខ្សែតី (KHSAE TEI)

A "whip-app": swing your phone, it plays a whip sound and tells your desktop to press **Enter** — handy for approving an AI confirmation prompt without reaching for the keyboard.

## Status: MVP (Linux desktop only)

- **mobile app** (Flutter) — detects the whip gesture via accelerometer, plays a sound, sends the signal.
- **desktop app** (Electron) — runs the WebSocket server the phone connects to over LAN, and simulates the Enter keypress.
- **relay** (Node) — optional rendezvous server so the phone and desktop can pair over the internet when they're not on the same WiFi. Built and tested locally; not deployed anywhere public yet.

Bluetooth and other desktop OSes are not built yet — see `docs/protocol.md` for the full wire protocol and `CHECKLIST.md` for what's done vs. outstanding.

## Running it

### Desktop (`desktop/`)

```
cd desktop
nvm use   # picks up .nvmrc (Node 22)
npm install
npm start
```

The window shows the desktop's LAN IP, port, a 6-digit pairing code, and a QR code encoding both. There's also an optional "Internet relay" field — see below.

### Mobile (`mobile/`)

```
cd mobile
flutter pub get
flutter run   # on a physical Android device, same WiFi network as the desktop
```

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

Then in the desktop app, enter the relay's address (e.g. `ws://<relay-host>:9090` for local testing) in the "Internet relay" field and hit Connect — the desktop registers under its existing pairing code, and a phone can now reach it via that relay using the same code from anywhere, not just the same WiFi. Not deployed anywhere public yet: this has only been run and tested on localhost so far. If you do deploy it publicly, put it behind TLS (`wss://`) — most hosting platforms do this for you automatically.

## Repo layout

```
desktop/   Electron app (WebSocket server + keypress simulation + relay client)
mobile/    Flutter app (gesture detection + WebSocket client, LAN or relay)
relay/     Rendezvous server for pairing over the internet
docs/      Wire protocol spec
branding/  Logo / app icon source
```
