# KHSAE TEI Wire Protocol (v1)

Two ways for the phone to reach the desktop:

- **LAN (direct)**: `ws://<desktop-ip>:<port>` (default port `8787`) — the desktop app itself is the WebSocket server. No TLS — LAN-only, proportionate to the threat model (see below).
- **Bluetooth (Classic RFCOMM)**: the desktop registers a standard Serial Port Profile (SPP) service over BlueZ; the phone connects to it by address once the two devices are bonded via the OS's own Bluetooth pairing UI (see §5). No network required at all.

Both paths speak the exact same `hello`/`whip`/`ack` vocabulary below and the same pairing code works on either, but they differ in **framing**: LAN uses WebSocket's own message framing (each JSON object is one text frame), while Bluetooth is a raw byte stream with no built-in message boundaries, so each JSON object is instead terminated by a single `\n` (newline-delimited JSON).

Every message is one JSON object: `{"type": "...", ...}`.

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

The desktop advertises an mDNS service `_khsaetei._tcp.local` on the port the WS server is listening on. The pairing code is **not** put in the mDNS TXT record — it's the thing keeping an attacker out, so it isn't broadcast; the user reads/scans it from the desktop UI directly. mDNS only helps the phone find the IP/port automatically. Manual IP:port entry is always available in the desktop UI as a fallback for networks where multicast is blocked. (mDNS only reaches devices on the same LAN, so it doesn't apply to the Bluetooth path — see §5.)

## 5. Bluetooth transport (Classic RFCOMM)

Bluetooth reuses the exact same hello/whip/ack session logic as LAN (`WhipServer.create_session_handler` in `desktop/server.py` is transport-agnostic and shared by both), just carried over RFCOMM instead of a WebSocket, and framed as newline-delimited JSON (§ above) instead of WS text frames.

**One-time OS-level pairing** (bonding) is a separate prerequisite from the app's own pairing-code handshake, and is not part of this protocol — it's done once through the desktop's and phone's native Bluetooth settings UI, the same way you'd pair a Bluetooth keyboard. This protocol only starts once an RFCOMM connection is already open between two bonded devices.

**Service registration**: the desktop registers a standard Serial Port Profile (SPP) service with BlueZ (`org.bluez.ProfileManager1.RegisterProfile`, UUID `00001101-0000-1000-8000-00805f9b34fb`), which advertises the RFCOMM channel via SDP. The phone looks up that UUID via SDP when connecting (`flutter_classic_bluetooth`'s `connect(address: ...)` does this automatically) — there is no fixed/hardcoded channel number on either side.

Once the RFCOMM socket is open, the phone sends the same `hello` message as the LAN path (§1), newline-terminated:
```json
{"type": "hello", "code": "482913", "clientName": "Rathanak's Phone"}
```

The desktop replies with `paired`/`error` and subsequent `whip`/`ack` messages exactly as in §1–2, each terminated by `\n`. There is no relay or intermediary — the RFCOMM socket itself is the session, just like the WebSocket connection is for LAN. Closing the socket de-authorizes the session, same as §1.

## 6. Server-initiated events: agent monitoring

Unlike `paired`/`ack`/`error`, which are always replies to something the phone sent, `agent_waiting` is **server-initiated**: the desktop pushes it unprompted to whichever session is currently paired (LAN or Bluetooth) the moment a monitored coding agent (see `desktop/agent_monitor/`) stops and is blocked on a confirmation/menu/text prompt. It reuses the same paired session — no separate connection or handshake.

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
