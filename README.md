<img src="branding/khsae_tei_logo.png" alt="KHSAE TEI logo" width="160" />

# ខ្សែតី (KHSAE TEI)

A "whip-app": swing your phone, it plays a whip sound and tells your desktop to press **Enter** — handy for approving an AI confirmation prompt without reaching for the keyboard.

## Status: MVP (Linux desktop only)

- **mobile app** (Flutter) — detects the whip gesture via accelerometer, plays a sound, sends the signal.
- **desktop app** (Python) — runs the WebSocket server the phone connects to over LAN, registers a Bluetooth SPP service via BlueZ, and simulates the Enter keypress.

Other desktop OSes are not built yet — see `docs/protocol.md` for the full wire protocol and `CHECKLIST.md` for what's done vs. outstanding.

## Get the code

```
git clone git@github.com:RathanakSreang/khsae_tei.git
cd khsae_tei
```

(Use `https://github.com/RathanakSreang/khsae_tei.git` instead if you haven't got an SSH key set up with GitHub.) Everything below assumes you're in this cloned `khsae_tei/` directory.

## Running it

### Desktop (`desktop/`) — full setup walkthrough

The desktop app is the part that receives the whip signal and presses Enter. It's a plain Python terminal script — no GUI, no install step beyond its dependencies.

**1. Prerequisites**

- **Linux** (the only OS currently supported — see the status note above). Tested against a standard X11 or Wayland desktop session.
- **Python 3.10+** — check with `python3 --version`.
- **[uv](https://docs.astral.sh/uv/)** — the Python package/venv manager this project uses. Install it with:
  ```
  curl -LsSf https://astral.sh/uv/install.sh | sh
  ```
- **A running Bluetooth daemon (`bluetoothd`)** if you want the Bluetooth pairing path — optional, the LAN path works without it.

**2. Set up and run**

```
cd desktop
uv venv
uv pip install -r requirements.txt
uv run main.py
```

`uv venv` creates an isolated `.venv/` for this project only (it won't touch any Python packages installed elsewhere on your system). `uv run main.py` starts the server inside that environment.

**3. Grant key-simulation access**

Key simulation uses `pynput`, which needs permission to inject input:
- **X11**: works out of the box in a normal desktop session.
- **Wayland**: `pynput` needs access to `/dev/uinput` — either run the script as a user in the `input` group (`sudo usermod -aG input $USER`, then log out/in) or run it as root.

**4. Read the terminal output**

Once running, the terminal prints:
- the desktop's LAN IP and port (default `8787`)
- a 6-digit pairing code
- an ASCII QR code encoding both, for the mobile app's **Scan QR** button
- the Bluetooth adapter address, once the SPP service registers (Bluetooth path only)

Type `h` at any time for the list of in-terminal commands (regenerate the pairing code, quit). Keep this terminal open — the app only works while it's running.

**5. Troubleshooting**

- *Nothing happens when the desktop receives a whip* — confirm the terminal shows a `paired` event when the phone connects (not just `hello`); if the pairing code was wrong you'll see an `invalid_code` error instead.
- *Bluetooth path never shows a device address* — check `bluetoothd` is actually running (`systemctl status bluetooth`); the LAN path is independent and doesn't need this.
- *Enter doesn't get pressed* — you're most likely on Wayland without `/dev/uinput` access; see step 3.

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
