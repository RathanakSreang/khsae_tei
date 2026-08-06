# KHSAE TEI Wire Protocol (v1)

Two ways for the phone to reach the desktop:

- **LAN (direct)**: `ws://<desktop-ip>:<port>` (default port `8787`) — the desktop app itself is the WebSocket server. No TLS — LAN-only, proportionate to the threat model (see below).
- **Internet (relay)**: `wss://<relay-host>` — a separate relay server (see §5) that both the desktop and the phone connect *outbound* to, so they don't need to be on the same network. TLS is expected here since traffic crosses the public internet (typically terminated by whatever host runs the relay).

Both paths speak the exact same `hello`/`whip`/`ack` vocabulary below — the phone doesn't need to know or care which one it's using, and the same pairing code works on either.

All messages are single JSON text frames: `{"type": "...", ...}`.

## 1. Handshake (pairing)

The desktop app generates a random 6-digit pairing code at server start (shown in its UI, regenerable). A phone must present this code once per connection before it is trusted. This is trust-on-first-use, not cryptographic auth — it exists to stop a random device on the same WiFi from spoofing an Enter keypress on your machine, not to defend against a determined attacker on the LAN.

**Client → Server**
```json
{"type": "hello", "code": "482913", "clientName": "Rathanak's Phone"}
```

**Server → Client (success)**
```json
{"type": "paired"}
```

**Server → Client (failure)**
```json
{"type": "error", "reason": "invalid_code"}
```
Server closes the socket after sending an error.

Only one connection needs to complete `hello`/`paired` to be authorized. There is no per-message token: the WebSocket connection itself **is** the session. Closing the socket de-authorizes; the phone must re-handshake to reconnect.

Any message sent before a successful handshake other than `hello` is ignored and the server closes the socket.

## 2. Whip signal

**Client → Server** (only after `paired`)
```json
{"type": "whip", "ts": 1738800000000}
```
`ts` is the client's epoch-millisecond timestamp when the gesture was detected (informational/latency debugging only).

**Server → Client**
```json
{"type": "ack"}
```
Sent after the server has triggered the Enter keypress. If the keypress simulation itself throws, the server sends `{"type": "error", "reason": "keypress_failed"}` instead.

## 3. Liveness

Standard WebSocket ping/pong frames (not JSON messages) are used for liveness. Client and server libraries handle this natively (`ws` on the server, most Dart WebSocket clients on the phone). A client that misses pong response(s) beyond the library's timeout is considered disconnected and must re-run the handshake on reconnect.

## 4. Discovery (out of band, not on the WebSocket)

The desktop advertises an mDNS service `_khsaetei._tcp.local` on the port the WS server is listening on. The pairing code is **not** put in the mDNS TXT record — it's the thing keeping an attacker out, so it isn't broadcast; the user reads/scans it from the desktop UI directly. mDNS only helps the phone find the IP/port automatically. Manual IP:port entry is always available in the desktop UI as a fallback for networks where multicast is blocked. (mDNS only reaches devices on the same LAN, so it doesn't apply to the relay path — the relay's address is configured directly in both apps.)

## 5. Relay protocol (internet path)

The relay (`relay/`) is a rendezvous point: it does not run keypress simulation or know anything about whips beyond forwarding frames. It keeps one extra piece of state per pairing code — which desktop connection registered it, and which phone (if any) is currently attached — and otherwise just pipes JSON frames between the two once both sides are present.

**Desktop → Relay** (sent once per connection, and again whenever the desktop regenerates its pairing code)
```json
{"type": "relay_register", "code": "482913"}
```

**Relay → Desktop**
```json
{"type": "relay_registered"}
```

**Phone → Relay** — identical to the LAN handshake:
```json
{"type": "hello", "code": "482913", "clientName": "Rathanak's Phone"}
```

The relay looks up `code` against registered desktop connections:
- No desktop registered under that code → relay itself replies `{"type": "error", "reason": "invalid_code"}` and closes the phone's socket. The desktop never sees this attempt.
- A phone is already attached to that code → relay replies `{"type": "error", "reason": "already_paired"}` and closes the new phone's socket. Only one phone per code at a time, same as the LAN model of one connection = one session.
- Otherwise the relay attaches this phone to the session and **forwards the raw `hello` frame** to the desktop's connection, unmodified.

From here, the relay is a dumb pipe: every subsequent frame from the phone is forwarded verbatim to the desktop's connection, and every frame from the desktop is forwarded verbatim to the phone's connection. The desktop validates the code and replies `paired`/`error` itself (the same handshake logic as the LAN path — the relay's own code lookup is just routing, not a replacement for it), and `whip`/`ack` flow through unchanged from §1–2.

Since the desktop keeps one persistent connection to the relay across many phones over time (one at a time, sequentially), the desktop must treat each incoming `hello` forwarded by the relay as the start of a brand new pairing session, independent of whether a previous phone paired and disconnected earlier on that same relay connection.

If the desktop's underlying relay connection drops (network blip, relay restart), the relay closes any attached phone connection too, and the desktop is expected to reconnect and re-register — the phone must then reconnect and re-pair as well.
