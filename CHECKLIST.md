# KHSAE TEI — Progress Checklist

Status snapshot of the MVP (WiFi/LAN only, Linux desktop only) described in `docs/protocol.md`.

## Done

- [x] Repo scaffolded as two packages: `desktop/` (Electron + Node) and `mobile/` (Flutter)
- [x] `docs/protocol.md` — wire protocol spec (handshake, whip signal, discovery)
- [x] Desktop: WebSocket server (`ws`) on port 8787
- [x] Desktop: pairing-code handshake (`hello` → `paired`/`error`) required before whip messages are accepted
- [x] Desktop: Enter-key simulation via `@nut-tree-fork/nut-js`, triggered on whip messages
- [x] Desktop: mDNS advertisement (`_khsaetei._tcp.local`) via `bonjour-service`
- [x] Desktop: renderer UI — IP/port, pairing code (regenerable), QR code, live connection/whip event log
- [x] Desktop↔protocol verified end-to-end with a scripted WS client: wrong code rejected, correct code → `paired` → `whip` → `ack`, keypress simulation runs without error
- [x] Mobile: Flutter project scaffolded (Android)
- [x] Mobile: pairing screen — manual IP/port/code entry + Connect
- [x] Mobile: WebSocket client with handshake and reconnect-with-backoff
- [x] Mobile: "Test Whip" manual trigger button
- [x] Mobile: accelerometer-based whip detection (acceleration magnitude spike + refractory debounce)
- [x] Mobile: local whip sound playback on trigger (placeholder synthesized sound)
- [x] Mobile: mDNS auto-discovery ("Discover" button)
- [x] Mobile: QR-code scan-to-pair flow
- [x] Mobile: AndroidManifest permissions wired (INTERNET, CAMERA, CHANGE_WIFI_MULTICAST_STATE, cleartext traffic for `ws://`)
- [x] `flutter analyze` clean, `flutter test` passing (widget smoke test)
- [x] Initial commit pushed to `origin/master`

## Not done yet

Needs a real phone (can't be done in this dev sandbox):
- [ ] On-device verification of accelerometer whip detection
- [ ] On-device verification of mDNS discovery
- [ ] On-device verification of QR-code scanning
- [ ] Threshold/debounce tuning against real false positives (walking, pocket jostling) — current values (30 m/s² threshold, 800ms refractory) are untuned starting guesses

Explicitly deferred / out of MVP scope:
- [ ] Bluetooth transport
- [ ] Internet relay/bridge server (phone + desktop on different networks)
- [ ] Windows/macOS desktop support (nut-js is cross-platform-capable but untested outside Linux)
- [ ] Tray-resident desktop window / minimize-to-tray (currently a plain window)
- [ ] TLS/WSS (plain `ws://`, acceptable for the LAN-only MVP threat model)

Polish / production-readiness, not started:
- [ ] App icons / branding
- [ ] Packaging & distribution (Electron builder, signed release APK, etc.)
- [ ] Automated integration/CI tests (currently one Flutter widget test + one manual Node protocol script, no CI pipeline)
- [ ] Replace placeholder synthesized `mobile/assets/sounds/whip.wav` with a real whip sound sample
