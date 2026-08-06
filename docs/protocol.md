# KHSAE TEI Wire Protocol (v1, LAN MVP)

Transport: plain WebSocket, `ws://<desktop-ip>:<port>` (default port `8787`). No TLS — LAN-only MVP, proportionate to the threat model (see below).

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

The desktop advertises an mDNS service `_khsaetei._tcp.local` on the port the WS server is listening on. The pairing code is **not** put in the mDNS TXT record — it's the thing keeping an attacker out, so it isn't broadcast; the user reads/scans it from the desktop UI directly. mDNS only helps the phone find the IP/port automatically. Manual IP:port entry is always available in the desktop UI as a fallback for networks where multicast is blocked.
