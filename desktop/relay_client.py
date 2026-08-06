import asyncio
import json

import websockets

MAX_BACKOFF_SECONDS = 16


class RelayClient:
    """Maintains one persistent outbound connection to a relay server so
    phones on a different network can reach this desktop. Reuses
    WhipServer's hello/whip/ack session logic unchanged - the relay just
    forwards frames between this connection and whichever phone it paired
    under our code."""

    def __init__(self, whip_server):
        self.whip_server = whip_server
        self.url = None
        self.wanted = False
        self.backoff_seconds = 1
        self._listeners = []
        self._task = None
        self._ws = None
        whip_server.on_event(self._on_server_event)

    def on_event(self, callback):
        self._listeners.append(callback)

    def _emit(self, event):
        for callback in self._listeners:
            callback(event)

    def _on_server_event(self, event):
        if event["kind"] == "code_regenerated" and self._ws is not None:
            asyncio.create_task(self._send_register_frame())

    def connect(self, url):
        self.url = url
        self.wanted = True
        self.backoff_seconds = 1
        if self._task:
            self._task.cancel()
        self._task = asyncio.create_task(self._run())

    async def _run(self):
        while self.wanted:
            session = None
            try:
                async with websockets.connect(self.url) as ws:
                    self._ws = ws
                    self.backoff_seconds = 1
                    await self._send_register_frame()
                    self._emit({"kind": "relay_connected", "url": self.url})

                    async for raw in ws:
                        try:
                            msg = json.loads(raw)
                        except (json.JSONDecodeError, TypeError):
                            continue

                        if msg.get("type") == "relay_registered":
                            continue

                        # Each "hello" starts a new phone's pairing cycle on
                        # this same persistent relay connection, so it needs
                        # a fresh session handler - otherwise a previous
                        # phone's already-paired state would silently
                        # swallow the next phone's hello.
                        if msg.get("type") == "hello":
                            session = self.whip_server.create_session_handler(
                                send=lambda m: ws.send(json.dumps(m)),
                                close=ws.close,
                                remote_label="relay",
                            )
                        if session:
                            await session["handle_message"](raw)
            except asyncio.CancelledError:
                raise
            except Exception as err:
                self._emit({"kind": "relay_error", "error": str(err)})
            finally:
                self._ws = None
                self._emit({"kind": "relay_disconnected"})

            if not self.wanted:
                break
            await asyncio.sleep(self.backoff_seconds)
            self.backoff_seconds = min(self.backoff_seconds * 2, MAX_BACKOFF_SECONDS)

    async def _send_register_frame(self):
        if self._ws is not None:
            await self._ws.send(json.dumps({"type": "relay_register", "code": self.whip_server.code}))

    def disconnect(self):
        self.wanted = False
        if self._task:
            self._task.cancel()
            self._task = None
        self._ws = None
