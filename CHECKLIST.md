# KHSAE TEI — Progress Checklist

Status snapshot of the MVP (LAN only, Linux desktop only) described in `docs/protocol.md`.

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
- [x] Mobile: AndroidManifest permissions wired (INTERNET, CAMERA, CHANGE_WIFI_MULTICAST_STATE, cleartext traffic for `ws://`)
- [x] `flutter analyze` clean, `flutter test` passing (widget smoke test)
- [x] Initial commit pushed to `origin/master`
- [x] Removed the internet relay entirely (`relay/` package, `desktop/relay_client.py`, the mobile Internet mode/relay URL field) — it was never deployed anywhere public, only built and tested locally
- Historical: a Bluetooth Classic (RFCOMM/SPP) transport (`desktop/bluetooth_server.py`, BlueZ D-Bus SPP profile registration, `mobile/lib/bt_client.dart`, `flutter_classic_bluetooth`) was built as the LAN-alternative in place of the relay, then removed entirely (2026-08-09) as a product decision — LAN is the only transport now.
- [x] **App icons / branding** — `branding/khsae_tei_logo.png` (provided) is now the source of truth for app icons
  - [x] Android launcher icons regenerated at all 5 densities (mdpi–xxxhdpi) from the logo; confirmed rendering correctly on a real device (2026-08-06)
  - [x] Desktop: `desktop/assets/icon.png` (512×512) kept as the branding source; unused since the Python rewrite has no window to attach an icon to
  - [x] README now displays the logo
- [x] **On-device verification pass (2026-08-06, real Galaxy Note20, Android 13)**:
  - [x] LAN manual pairing (IP/port/code entry) → paired → whip → real Enter keypress simulated on desktop, confirmed via desktop log
  - [x] QR-code scan-to-pair flow — camera scan correctly filled fields and connected
  - [x] Internet/relay pairing flow through the actual mobile UI (not just a scripted client) — paired via a local relay instance, whip → ack round trip confirmed. Historical: the relay was subsequently removed entirely (briefly replaced with a Bluetooth transport, which was itself later removed too — see above).
  - [x] Accelerometer whip detection — tuned from real on-device magnitude data (see below), confirmed a real whip motion now triggers correctly (sound + event) at the new threshold
  - [x] Found and fixed real bugs along the way (not pre-existing knowledge, discovered during this pass):
    - Android silently drops incoming mDNS/multicast packets over WiFi unless the app holds a `WifiManager.MulticastLock`; the `multicast_dns` package never acquires one. Added a small native platform channel (`MainActivity.kt` + `discovery.dart`) to acquire/release it around each discovery call.
    - `mobile_scanner` 7.4.0 (bumped earlier) needs AGP ≥8.9.1; project was pinned to 8.7.0. Bumped AGP to 8.9.1, Gradle to 8.11.1, Kotlin to 2.1.0 to match.
    - `WhipDetector` sampled the accelerometer at the `sensors_plus` default (~5Hz), far too slow to catch a whip-crack transient that peaks and decays in well under 150ms. Switched to `SensorInterval.gameInterval` (~50Hz).
    - Whip threshold was an untuned guess (30 m/s²) that real swings never reached (measured peaks: 10.2–23.5 m/s²). Retuned to 15.0 m/s² from that data.
  - [ ] mDNS **Discover** button specifically: fixed the multicast-lock bug above, but on the test WiFi network the desktop's own multicast advertisement never reached the phone at all (raw socket sniff confirmed zero packets arrive), while regular unicast (LAN pairing, relay) worked fine after a brief delay. This looks like router-level multicast filtering (common on consumer/mesh APs, distinct from full AP client isolation) rather than an app bug — manual entry and QR scan are the confirmed-working fallbacks on networks like this one, exactly as `docs/protocol.md` already assumes. Still needs verification on a network without this restriction.
  - [ ] Walking/pocket-jostling false-positive tuning specifically wasn't captured cleanly this pass (data collection kept getting confounded with grip-adjustment noise); the 15.0 m/s² threshold is a real improvement over the untuned 30.0 default but hasn't been stress-tested against a dedicated "normal handling only" baseline yet.
- [x] **Two-screen app** (2026-08-06) — Home (`home_screen.dart`, minimal dashboard: branding, status, Start/Stop) and Settings (`settings_screen.dart`, connection config + Test Whip + event log), navigated via a bottom `NavigationBar`/`IndexedStack` shell (`app_shell.dart`)
  - [x] Connection settings persisted via `shared_preferences` (`settings_store.dart`) — Settings is prefilled on restart
  - Historical: a `flutter_background_service` foreground-service isolate (`background_service.dart`) briefly moved the live `WsClient`/`WhipDetector`/`SoundPlayer` out of the UI so detection/connection survived backgrounding, verified end-to-end on a real Galaxy Note20 (silent low-importance notification, survived backgrounding, real whip motion while backgrounded worked, clean teardown on Stop). Removed entirely (2026-08-09, "no need for now") — `WsClient`/`WhipDetector`/`SoundPlayer` now live directly in the UI process via a `WhipController` singleton (`lib/whip_controller.dart`); detection and the connection only run while the app is open. The "Disable battery optimization" button and its `MainActivity.kt` platform-channel handler were removed alongside it (its only purpose was protecting the now-gone foreground service).

## Not done yet

Explicitly deferred / out of MVP scope:

- [ ] Windows/macOS desktop support (`pynput` is cross-platform-capable but untested outside Linux)
- [ ] Any kind of desktop GUI/tray icon (currently a plain terminal script; deliberately dropped the Electron window)
- [ ] TLS/WSS for the LAN path (plain `ws://`, acceptable for the LAN-only threat model — LAN is the only transport now that the internet relay and Bluetooth are both gone, so there's no public-facing leg needing TLS)

Polish / production-readiness, not started:

- [ ] Packaging & distribution (e.g. PyInstaller for the desktop script, signed release APK for mobile, etc.)
- [ ] Automated integration/CI tests (currently one Flutter widget test + manual scripted protocol tests, no CI pipeline)
