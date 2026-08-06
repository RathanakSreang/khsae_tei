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
- [x] Mobile: local whip sound playback on trigger — real recorded whip-crack clips, randomly picked from a 5-clip pool each trigger
- [x] Mobile: mDNS auto-discovery ("Discover" button)
- [x] Mobile: QR-code scan-to-pair flow
- [x] Mobile: AndroidManifest permissions wired (INTERNET, CAMERA, CHANGE_WIFI_MULTICAST_STATE, cleartext traffic for `ws://`)
- [x] `flutter analyze` clean, `flutter test` passing (widget smoke test)
- [x] Initial commit pushed to `origin/master`
- [x] **Internet relay/bridge server** (`relay/`) — rendezvous server so phone and desktop can pair when not on the same LAN, using the exact same pairing code as LAN mode
  - [x] `relay/src/server.js` — routes by pairing code, forwards frames verbatim once both sides are attached, rejects unknown/already-taken codes at the relay itself
  - [x] Desktop: `relay_client.js` — persistent outbound connection to a configured relay URL, reconnect-with-backoff, reuses the exact same hello/whip/ack session logic as the LAN server (refactored into `WhipServer.createSessionHandler`)
  - [x] Desktop: renderer UI — relay URL field, Connect/Disconnect, live status dot
  - [x] Mobile: LAN/Internet mode switch on the pairing screen; Internet mode connects via an arbitrary relay URL using the same `WsClient`
  - [x] `docs/protocol.md` — relay protocol section (`relay_register`/`relay_registered`, routing rules, forwarding behavior)
  - [x] Verified end-to-end locally: relay + desktop (plain Node, no Electron needed) + scripted phone clients — wrong code rejected by the relay itself, a second phone joining an already-paired code rejected, and (this was a real bug caught by testing) **sequential** phones pairing one after another over the same persistent desktop↔relay connection now works correctly
  - [x] Cross-verified the same round trip from the actual Dart `web_socket_channel` client (not just Node's `ws`), confirming the mobile-side protocol implementation is compatible
- [x] **App icons / branding** — `branding/khsae_tei_logo.png` (provided) is now the source of truth for app icons
  - [x] Android launcher icons regenerated at all 5 densities (mdpi–xxxhdpi) from the logo
  - [x] Desktop: `desktop/assets/icon.png` (512×512), wired into the `BrowserWindow` icon and the renderer's favicon link
  - [x] README now displays the logo

## Not done yet

Needs a real phone (can't be done in this dev sandbox):
- [ ] On-device verification of accelerometer whip detection
- [ ] On-device verification of mDNS discovery
- [ ] On-device verification of QR-code scanning
- [ ] On-device verification of the Internet/relay pairing flow through the mobile UI (relay protocol itself is verified server-side and via a scripted Dart client, but not yet through the actual app UI on a phone)
- [ ] Threshold/debounce tuning against real false positives (walking, pocket jostling) — current values (30 m/s² threshold, 800ms refractory) are untuned starting guesses

Needs a real deployment (relay was only built + tested locally so far, per the "build+test locally for now" decision):
- [ ] Deploy the relay somewhere publicly reachable (no hosting target chosen yet)
- [ ] Put the relay behind TLS (`wss://`) — required once it's actually public; typically free from whatever PaaS terminates TLS for you, not something the relay code itself needs to implement
- [ ] Desktop QR code only encodes the LAN address today; doesn't yet have a relay-based QR/discovery equivalent

Explicitly deferred / out of MVP scope:
- [ ] Bluetooth transport
- [ ] Windows/macOS desktop support (nut-js is cross-platform-capable but untested outside Linux)
- [ ] Tray-resident desktop window / minimize-to-tray (currently a plain window)
- [ ] TLS/WSS for the LAN path (plain `ws://`, acceptable for the LAN-only threat model — this is distinct from the relay's TLS need above, since the relay is public-facing)

Polish / production-readiness, not started:
- [ ] Packaging & distribution (Electron builder, signed release APK, etc.) — note the app icon assets are now in place for whenever this happens
- [ ] On-device verification that the new Android launcher icon actually renders correctly (needs a real phone/emulator build)
- [ ] Automated integration/CI tests (currently one Flutter widget test + one manual Node protocol script, no CI pipeline)
