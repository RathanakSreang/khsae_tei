# ខ្សែតី (KHSAE TEI)

A "whip-app": swing your phone, it plays a whip sound and tells your desktop to press **Enter** — handy for approving an AI confirmation prompt without reaching for the keyboard.

## Status: MVP (WiFi/LAN only, Linux desktop only)

- **mobile app** (Flutter) — detects the whip gesture via accelerometer, plays a sound, sends the signal.
- **desktop app** (Electron) — runs the WebSocket server the phone connects to over LAN, and simulates the Enter keypress.

Bluetooth, an internet relay server, and other desktop OSes are not built yet — see `docs/protocol.md` for the wire protocol and the plan this was built from.

## Running it

### Desktop (`desktop/`)

```
cd desktop
nvm use   # picks up .nvmrc (Node 22)
npm install
npm start
```

The window shows the desktop's LAN IP, port, a 6-digit pairing code, and a QR code encoding both.

### Mobile (`mobile/`)

```
cd mobile
flutter pub get
flutter run   # on a physical Android device, same WiFi network as the desktop
```

In the app: tap **Discover** (mDNS) or **Scan QR**, or type the IP/port/code shown on the desktop, then **Connect**. Once paired, tap **Test Whip** to confirm the round trip, or physically whip the phone.

## Repo layout

```
desktop/   Electron app (WebSocket server + keypress simulation)
mobile/    Flutter app (gesture detection + WebSocket client)
docs/      Wire protocol spec
```
