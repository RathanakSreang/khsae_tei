<img src="branding/khsae_tei_logo.png" alt="KHSAE TEI logo" width="160" />

# ខ្សែតី (KHSAE TEI)

A "whip-app": swing your phone, it plays a whip sound and tells your desktop to press **Enter** — handy for approving an AI confirmation prompt without reaching for the keyboard.

## Status: MVP (Linux desktop only)

- **mobile app** (Flutter) — detects the whip gesture via accelerometer, plays a sound, sends the signal.
- **desktop app** (Python) — runs the WebSocket server the phone connects to over LAN, registers a Bluetooth SPP service via BlueZ, and simulates the Enter keypress.

Other desktop OSes are not built yet — see `docs/protocol.md` for the full wire protocol and `CHECKLIST.md` for what's done vs. outstanding.

## Running it

### Desktop (`desktop/`)

Requires Python 3.10+ and [uv](https://docs.astral.sh/uv/).

```
cd desktop
uv venv
uv pip install -r requirements.txt
uv run main.py
```

On Linux, key simulation uses `pynput`, which needs an X11 session (or, on Wayland, access to `/dev/uinput` — typically means being in the `input` group or running as root). Bluetooth uses BlueZ over D-Bus (`dbus-next`), so a running `bluetoothd` is required for the Bluetooth path — the LAN path works fine without it.

The terminal prints the desktop's LAN IP, port, a 6-digit pairing code, and an ASCII QR code encoding both, plus the Bluetooth adapter address once the SPP service is registered. Type `h` for the list of commands (regenerate the pairing code, quit).

### Mobile (`mobile/`)

Requires Flutter >= 3.44.0 (Dart >= 3.12.0) — check with `flutter --version`, and run `flutter doctor` if anything's missing.

```
cd mobile
flutter pub get
flutter devices     # confirm your phone shows up
flutter run         # on a physical Android device, same WiFi network as the desktop
```

Connect the phone over USB with developer mode / USB debugging enabled (or use `flutter run -d <device-id>` with wireless debugging already paired via `adb pair`). The app needs camera access for QR scanning — accept the permission prompt on first launch.

In the app, pick **LAN** or **Bluetooth** mode:
- **LAN**: tap **Discover** (mDNS) or **Scan QR**, or type the IP/port/code shown on the desktop, then **Connect**.
- **Bluetooth**: pair the phone with the desktop from the phone's system Bluetooth settings first (like pairing a Bluetooth keyboard), then in-app tap **Refresh paired devices**, pick the desktop from the list, enter the pairing code shown on the desktop, then **Connect**.

Once paired, tap **Test Whip** to confirm the round trip, or physically whip the phone.

## Repo layout

```
desktop/   Python app (WebSocket server + Bluetooth SPP service + keypress simulation)
mobile/    Flutter app (gesture detection + WebSocket/Bluetooth client)
docs/      Wire protocol spec
branding/  Logo / app icon source
```
