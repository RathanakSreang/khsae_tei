# KHSAE TEI Wire Protocol (v1)

The phone reaches the desktop over LAN (direct): `ws://<desktop-ip>:<port>` (default port `8787`) — the desktop app itself is the WebSocket server. No TLS — LAN-only, proportionate to the threat model (see below).

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

## 5. Server-initiated events: agent monitoring

Unlike `paired`/`ack`/`error`, which are always replies to something the phone sent, `agent_waiting` is **server-initiated**: the desktop pushes it unprompted to whichever session is currently paired the moment a monitored coding agent (see `desktop/agent_monitor/`) stops and is blocked on a confirmation/menu/text prompt. It reuses the same paired session — no separate connection or handshake.

```json
{
  "type": "agent_waiting",
  "agent_id": "3e9f2c1a-...",
  "pid": 48213,
  "workspace": "/home/rathanak/MyRubyOnRails/khsae_tei",
  "terminal": "/dev/pts/4",
  "label": "Claude",
  "state": "WAITING_FOR_CONFIRMATION",
  "prompt_type": "confirmation",
  "prompt": "Do you want to proceed? [y/N]"
}
```

`state` is one of `RUNNING`, `WAITING_FOR_INPUT`, `WAITING_FOR_CONFIRMATION`, `COMPLETED`, `ERROR` (only transitions into a `WAITING_*` state trigger this message — the desktop doesn't push `RUNNING`). `prompt_type` is one of `confirmation`, `menu`, `text_input`, `press_enter`, `unknown`, matching `agent_monitor/prompt_detector.py`'s `PromptType`. Multiple agents can be monitored concurrently, each identified by its own `agent_id`; a phone client should not assume only one agent is ever in flight.
