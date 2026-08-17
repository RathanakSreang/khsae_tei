<img src="branding/khsae_tei_logo.png" alt="KHSAE TEI logo" width="160" />

# ខ្សែតី (KHSAE TEI)

A "whip-app": swing your phone, it plays a whip sound and tells your desktop to press **Enter** — handy for approving an AI confirmation prompt without reaching for the keyboard.

[<img src="https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png" alt="Get it on Google Play" height="60">](https://play.google.com/store/apps/details?id=com.khsaetei.khsae_tei)

The mobile app above is the whip-detector; you still need the desktop app running on the machine you want to control (see [Install the desktop app](#install-the-desktop-app) below — it isn't packaged yet, so it's run from source).

## Status: MVP (Linux desktop only)

- **mobile app** (Flutter) — detects the whip gesture via accelerometer, plays a sound, sends the signal. Published on Google Play (link above).
- **desktop app** (Python) — runs the WebSocket server the phone connects to over LAN, and simulates the Enter keypress.

Other desktop OSes are not built yet — see `docs/protocol.md` for the full wire protocol and `CHECKLIST.md` for what's done vs. outstanding.

## Install the desktop app

The desktop side is a plain Python terminal script — no GUI, no installer, just its dependencies. It only runs on Linux for now.

**1. Prerequisites**

- **Linux**, X11 or Wayland desktop session.
- **Python 3.10+** — check with `python3 --version`.
- **[uv](https://docs.astral.sh/uv/)** — the Python package/venv manager this project uses:
  ```
  curl -LsSf https://astral.sh/uv/install.sh | sh
  ```

**2. Get the code**

```
git clone git@github.com:RathanakSreang/khsae_tei.git
cd khsae_tei
```

(Use `https://github.com/RathanakSreang/khsae_tei.git` instead if you haven't got an SSH key set up with GitHub.)

**3. Set up and run**

```
cd desktop
uv venv
uv pip install -r requirements.txt
uv run main.py
```

`uv venv` creates an isolated `.venv/` for this project only (it won't touch any Python packages installed elsewhere on your system). `uv run main.py` starts the server inside that environment.

**4. Grant key-simulation access**

Key simulation uses `pynput`, which needs permission to inject input:
- **X11**: works out of the box in a normal desktop session.
- **Wayland**: `pynput` needs access to `/dev/uinput` — either run the script as a user in the `input` group (`sudo usermod -aG input $USER`, then log out/in) or run it as root.

**5. Read the terminal output**

Once running, the terminal prints:
- the desktop's LAN IP and port (default `8787`)
- a 6-digit pairing code
- an ASCII QR code encoding both, for the mobile app's **Scan QR** button

Type `h` at any time for the list of in-terminal commands (regenerate the pairing code, quit). Keep this terminal open — the app only works while it's running.

**6. Pair the mobile app**

In the mobile app's Settings tab, tap **Discover** (mDNS) or **Scan QR**, or type the IP/port/code shown on the desktop, then **Connect**. Once paired, tap **Test Whip** to confirm the round trip, or physically whip the phone.

**7. Troubleshooting**

- *Nothing happens when the desktop receives a whip* — confirm the terminal shows a `paired` event when the phone connects (not just `hello`); if the pairing code was wrong you'll see an `invalid_code` error instead.
- *Enter doesn't get pressed* — you're most likely on Wayland without `/dev/uinput` access; see step 4.

## Developing

### Repo layout

```
desktop/   Python app (WebSocket server + keypress simulation)
mobile/    Flutter app (gesture detection + WebSocket client)
docs/      Wire protocol spec
branding/  Logo / app icon source
```

- `docs/protocol.md` — the wire protocol (handshake, whip signal, discovery, agent-monitoring events). Read this first if you're touching either app's networking code, since desktop and mobile must agree on it.
- `CHECKLIST.md` — running status of what's implemented vs. outstanding.

### Desktop (`desktop/`)

Follow [Install the desktop app](#install-the-desktop-app) above to get a working `.venv`; from there:

```
cd desktop
uv run main.py        # run against your local changes
```

Key files: `server.py` (WebSocket server + protocol handling), `keypress.py` (`pynput` Enter simulation), `discovery.py` (mDNS advertisement), `agent_monitor/` (detects a paired coding agent waiting on a prompt and pushes `agent_waiting` events — see `docs/protocol.md` §5).

### Mobile (`mobile/`)

Requires Flutter >= 3.44.0 (Dart >= 3.12.0) — check with `flutter --version`, and run `flutter doctor` if anything's missing.

```
cd mobile
flutter pub get
flutter devices     # confirm your phone shows up
flutter run         # on a physical Android device, same WiFi network as the desktop
```

Connect the phone over USB with developer mode / USB debugging enabled (or use `flutter run -d <device-id>` with wireless debugging already paired via `adb pair`). The app needs camera access for QR scanning — accept the permission prompt on first launch.

Whip detection and the connection only run while the app is open (foreground) — there's no background service, so backgrounding or closing the app stops both.

Before pushing changes, run:

```
flutter analyze
flutter test
```

See `mobile/RELEASE.md` for the Play Store / App Store release process (signing, store listing, checklist).
