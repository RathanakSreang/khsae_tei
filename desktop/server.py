import json
import random

import websockets
from websockets.exceptions import ConnectionClosed

from keypress import simulate_enter

DEFAULT_PORT = 8787


def generate_code():
    return str(random.randint(100000, 999999))


class WhipServer:
    def __init__(self, port=DEFAULT_PORT):
        self.port = port
        self.code = generate_code()
        self._listeners = []
        self._server = None
        # send() callables for every currently paired session - lets
        # push_event() reach whichever session the phone is actually
        # connected over without any transport-specific code.
        self._paired_sends = set()

    def on_event(self, callback):
        self._listeners.append(callback)

    def _emit(self, event):
        for callback in self._listeners:
            callback(event)

    async def start(self):
        self._server = await websockets.serve(self._handle_connection, "0.0.0.0", self.port)
        self._emit({"kind": "listening", "port": self.port})

    async def _handle_connection(self, ws):
        remote = ws.remote_address[0] if ws.remote_address else "unknown"
        session = self.create_session_handler(
            send=lambda msg: ws.send(json.dumps(msg)),
            close=ws.close,
            remote_label=remote,
        )
        try:
            async for raw in ws:
                await session["handle_message"](raw)
        except ConnectionClosed:
            pass
        finally:
            session["cleanup"]()
            if session["is_paired"]():
                self._emit({"kind": "disconnected", "remote": remote})

    def create_session_handler(self, send, close, remote_label):
        """Builds the hello/whip/ack state machine used for one logical
        connection, decoupled from the transport so both the LAN server and
        the relay client (a single outbound connection multiplexing many
        phones) can share identical pairing/keypress behavior."""
        state = {"paired": False}

        async def handle_message(raw):
            try:
                msg = json.loads(raw)
            except (json.JSONDecodeError, TypeError):
                await close()
                return

            if not state["paired"]:
                if msg.get("type") != "hello":
                    await close()
                    return
                if msg.get("code") != self.code:
                    await send({"type": "error", "reason": "invalid_code"})
                    await close()
                    self._emit({
                        "kind": "pair_failed",
                        "remote": remote_label,
                        "clientName": msg.get("clientName"),
                    })
                    return
                state["paired"] = True
                self._paired_sends.add(send)
                await send({"type": "paired"})
                self._emit({
                    "kind": "paired",
                    "remote": remote_label,
                    "clientName": msg.get("clientName"),
                })
                return

            if msg.get("type") == "whip":
                try:
                    await simulate_enter()
                    await send({"type": "ack"})
                    self._emit({"kind": "whip", "remote": remote_label, "ts": msg.get("ts")})
                except Exception as err:
                    await send({"type": "error", "reason": "keypress_failed"})
                    self._emit({
                        "kind": "keypress_failed",
                        "remote": remote_label,
                        "error": str(err),
                    })

        def cleanup():
            self._paired_sends.discard(send)

        return {"handle_message": handle_message, "is_paired": lambda: state["paired"], "cleanup": cleanup}

    async def push_event(self, msg):
        """Sends an unsolicited server-initiated message (e.g. agent_waiting)
        to every currently paired session. Swallows individual send errors so
        one dead connection (not yet reaped) doesn't block the others."""
        for send in list(self._paired_sends):
            try:
                await send(msg)
            except Exception:
                pass

    def regenerate_code(self):
        self.code = generate_code()
        self._emit({"kind": "code_regenerated"})
        return self.code

    async def stop(self):
        if self._server:
            self._server.close()
            await self._server.wait_closed()
