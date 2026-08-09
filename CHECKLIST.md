# KHSAE TEI — Progress Checklist

Status snapshot of the MVP (LAN or Bluetooth, Linux desktop only) described in `docs/protocol.md`.

## Done

- [x] Repo scaffolded as two packages: `desktop/` (Python) and `mobile/` (Flutter)
- [x] `docs/protocol.md` — wire protocol spec (handshake, whip signal, discovery)
- [x] Desktop: WebSocket server (`websockets`) on port 8787
- [x] Desktop: pairing-code handshake (`hello` → `paired`/`error`) required before whip messages are accepted
- [x] Desktop: Enter-key simulation via `pynput`, triggered on whip messages
- [x] Desktop: mDNS advertisement (`_khsaetei._tcp.local`) via `zeroconf` (backgrounded so a slow/blocked network can't stall startup)
- [x] Desktop: terminal UI — IP/port, pairing code (regenerable via `r` command), ASCII QR code, live connection/whip event log
- [x] Desktop: migrated from the original Electron/Node implementation to a plain Python script (2026-08-06) — same wire protocol, no GUI window, run with `uv run main.py`
- [x] Desktop↔protocol verified end-to-end with a scripted WS client: wrong code rejected, correct code → `paired` → `whip` → `ack`, keypress simulation runs without error
- [x] Mobile: Flutter project scaffolded (Android)
- [x] Mobile: Settings screen — manual IP/port/code entry + Connect (moved out of a single combined screen, see two-screen architecture below)
- [x] Mobile: WebSocket client with handshake and reconnect-with-backoff
- [x] Mobile: "Test Whip" manual trigger button
- [x] Mobile: accelerometer-based whip detection (acceleration magnitude spike + refractory debounce), sampled at ~50Hz (`SensorInterval.gameInterval` — the default ~5Hz was too slow to catch a whip-crack transient) and tuned from real on-device data (threshold 15.0 m/s², see below)
- [x] Mobile: local whip sound playback on trigger — real recorded whip-crack clips, randomly picked from a 5-clip pool each trigger
- [x] Mobile: success sound (cow moo, randomly picked from 3 clips) plays when the desktop actually acks the whip — i.e. confirms the command landed, not just that it was sent; plays on its own audio player so it doesn't cut off an in-flight whip-crack sound
- [x] Mobile: mDNS auto-discovery ("Discover" button)
- [x] Mobile: QR-code scan-to-pair flow
- [x] Mobile: AndroidManifest permissions wired (INTERNET, CAMERA, CHANGE_WIFI_MULTICAST_STATE, cleartext traffic for `ws://`, plus the Bluetooth scan/connect permissions listed below)
- [x] `flutter analyze` clean, `flutter test` passing (widget smoke test)
- [x] Initial commit pushed to `origin/master`
- [x] **Bluetooth Classic (RFCOMM/SPP) transport** — replaces the internet relay as the second way to reach the desktop when not on the same LAN, using the exact same pairing code as LAN mode
  - [x] Desktop: `bluetooth_server.py` — registers a standard Serial Port Profile with BlueZ over D-Bus (`dbus-next`, `org.bluez.ProfileManager1.RegisterProfile`), so the phone finds the RFCOMM channel via SDP the same way `flutter_classic_bluetooth`'s `connect()` looks it up (no hardcoded channel on either side); reuses the exact same hello/whip/ack session logic as the LAN server (`WhipServer.create_session_handler`), framed as newline-delimited JSON since RFCOMM is a raw byte stream
  - [x] Desktop: registers/deregisters the SPP profile alongside the LAN server and mDNS advertisement in `main.py`; prints the Bluetooth adapter address at startup
  - [x] Mobile: LAN/Bluetooth mode switch on the pairing screen; Bluetooth mode lists paired devices (`FlutterClassicBluetooth.getPairedDevices()`) to pick the desktop from, then connects via `bt_client.dart` (same public shape as `WsClient`, same hello/paired/ack/error state machine)
  - [x] Mobile: runtime Bluetooth permission requests (`permission_handler`) for Android 12+ scan/connect and legacy location, plus manifest permissions split by SDK version
  - [x] `docs/protocol.md` — Bluetooth transport section (SPP UUID/SDP registration, that OS-level bonding is a separate prerequisite from the app's pairing-code handshake, newline-delimited framing)
  - [x] Removed the internet relay entirely (`relay/` package, `desktop/relay_client.py`, the mobile Internet mode/relay URL field) — it was never deployed anywhere public, only built and tested locally
  - [ ] Not yet verified on real hardware (no Bluetooth-equipped Linux desktop + Android phone available during implementation) — needs the same kind of on-device pass already done for LAN/relay: real bonding, `RegisterProfile` actually succeeding against a live `bluetoothd`, and a real whip → keypress round trip over RFCOMM
- [x] **App icons / branding** — `branding/khsae_tei_logo.png` (provided) is now the source of truth for app icons
  - [x] Android launcher icons regenerated at all 5 densities (mdpi–xxxhdpi) from the logo; confirmed rendering correctly on a real device (2026-08-06)
  - [x] Desktop: `desktop/assets/icon.png` (512×512) kept as the branding source; unused since the Python rewrite has no window to attach an icon to
  - [x] README now displays the logo
- [x] **On-device verification pass (2026-08-06, real Galaxy Note20, Android 13)**:
  - [x] LAN manual pairing (IP/port/code entry) → paired → whip → real Enter keypress simulated on desktop, confirmed via desktop log
  - [x] QR-code scan-to-pair flow — camera scan correctly filled fields and connected
  - [x] Internet/relay pairing flow through the actual mobile UI (not just a scripted client) — paired via a local relay instance, whip → ack round trip confirmed. Historical: the relay was subsequently removed entirely and replaced with the Bluetooth transport above.
  - [x] Accelerometer whip detection — tuned from real on-device magnitude data (see below), confirmed a real whip motion now triggers correctly (sound + event) at the new threshold
  - [x] Found and fixed real bugs along the way (not pre-existing knowledge, discovered during this pass):
    - Android silently drops incoming mDNS/multicast packets over WiFi unless the app holds a `WifiManager.MulticastLock`; the `multicast_dns` package never acquires one. Added a small native platform channel (`MainActivity.kt` + `discovery.dart`) to acquire/release it around each discovery call.
    - `mobile_scanner` 7.4.0 (bumped earlier) needs AGP ≥8.9.1; project was pinned to 8.7.0. Bumped AGP to 8.9.1, Gradle to 8.11.1, Kotlin to 2.1.0 to match.
    - `WhipDetector` sampled the accelerometer at the `sensors_plus` default (~5Hz), far too slow to catch a whip-crack transient that peaks and decays in well under 150ms. Switched to `SensorInterval.gameInterval` (~50Hz).
    - Whip threshold was an untuned guess (30 m/s²) that real swings never reached (measured peaks: 10.2–23.5 m/s²). Retuned to 15.0 m/s² from that data.
  - [ ] mDNS **Discover** button specifically: fixed the multicast-lock bug above, but on the test WiFi network the desktop's own multicast advertisement never reached the phone at all (raw socket sniff confirmed zero packets arrive), while regular unicast (LAN pairing, relay) worked fine after a brief delay. This looks like router-level multicast filtering (common on consumer/mesh APs, distinct from full AP client isolation) rather than an app bug — manual entry and QR scan are the confirmed-working fallbacks on networks like this one, exactly as `docs/protocol.md` already assumes. Still needs verification on a network without this restriction.
  - [ ] Walking/pocket-jostling false-positive tuning specifically wasn't captured cleanly this pass (data collection kept getting confounded with grip-adjustment noise); the 15.0 m/s² threshold is a real improvement over the untuned 30.0 default but hasn't been stress-tested against a dedicated "normal handling only" baseline yet.
- [x] **Two-screen app + background-surviving connection (2026-08-06)** — Home (`home_screen.dart`, minimal dashboard: branding, status, Start/Stop) and Settings (`settings_screen.dart`, connection config + Test Whip + event log), navigated via a bottom `NavigationBar`/`IndexedStack` shell (`app_shell.dart`)
  - [x] The live `WsClient`/`WhipDetector`/`SoundPlayer` moved out of the UI into a `flutter_background_service` foreground-service isolate (`background_service.dart`), so the connection and gesture detection keep running independent of any screen being open
  - [x] Notification kept as unobtrusive as Android allows for a true foreground service: `Importance.low`, no sound/vibration/badge (Android requires _some_ notification for indefinite background work — there's no way around that)
  - [x] Connection settings persisted via `shared_preferences` (`settings_store.dart`) — Settings is prefilled and the service can reconnect on its own after a restart
  - [x] "Disable battery optimization for this app" button in Settings (`MainActivity.kt` platform channel, `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`) — added because OEM battery managers (confirmed on this same Samsung device) throttle background services that aren't exempted, regardless of the foreground-service notification
  - [x] Verified end-to-end on the real Galaxy Note20: started from Home (silent notification appears, confirmed via `dumpsys notification`), connected from Settings, backgrounded the app (confirmed the process + foreground service survive via `dumpsys activity services`), did a **real whip motion with the app fully backgrounded** — sound played and the desktop received it, Stop cleanly tears down the service (notification disappears), settings correctly prefill after a full force-stop + relaunch
  - [ ] iOS not touched (Android-only scope, see below); boot-persistence (`autoStartOnBoot`) deliberately left off — "runs until user stops it" was read as a user-initiated start each session, not surviving a reboot

## Not done yet

Explicitly deferred / out of MVP scope:

- [ ] Windows/macOS desktop support (`pynput` is cross-platform-capable but untested outside Linux)
- [ ] Any kind of desktop GUI/tray icon (currently a plain terminal script; deliberately dropped the Electron window)
- [ ] TLS/WSS for the LAN path (plain `ws://`, acceptable for the LAN-only threat model — LAN and Bluetooth are both local-only now that the internet relay is gone, so there's no public-facing leg needing TLS)

Polish / production-readiness, not started:

- [ ] Packaging & distribution (e.g. PyInstaller for the desktop script, signed release APK for mobile, etc.)
- [ ] Automated integration/CI tests (currently one Flutter widget test + manual scripted protocol tests, no CI pipeline)
