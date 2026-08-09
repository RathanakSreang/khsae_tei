import asyncio
import json
import socket

from dbus_next import BusType, Variant
from dbus_next.aio import MessageBus
from dbus_next.service import ServiceInterface, method

SPP_UUID = "00001101-0000-1000-8000-00805f9b34fb"
PROFILE_PATH = "/org/khsaetei/profile"


class _ProfileInterface(ServiceInterface):
    """Implements org.bluez.Profile1 - BlueZ calls NewConnection with an
    already-accepted RFCOMM socket fd once a phone opens the SPP channel we
    registered. Release/RequestDisconnection are required by the interface
    but nothing needs to happen on our side beyond letting the connection
    handler's own socket teardown run."""

    def __init__(self, on_connection):
        super().__init__("org.bluez.Profile1")
        self._on_connection = on_connection

    @method()
    def Release(self):
        pass

    @method()
    def NewConnection(self, device: "o", fd: "h", fd_properties: "a{sv}"):
        # In dbus-next's high-level service interface, an "h" (UNIX_FD)
        # argument arrives as the plain file descriptor integer itself.
        sock = socket.socket(fileno=fd)
        self._on_connection(device, sock)

    @method()
    def RequestDisconnection(self, device: "o"):
        pass


class BluetoothServer:
    """Registers a standard Serial Port Profile with BlueZ so a phone can
    connect over Bluetooth Classic RFCOMM, discovering the channel via SDP
    the same way the mobile flutter_classic_bluetooth package looks it up
    (by UUID, not a hardcoded channel). Reuses WhipServer's transport-agnostic
    hello/whip/ack session handler, framed as newline-delimited JSON since
    RFCOMM is a raw byte stream rather than WebSocket's message framing.

    One-time Bluetooth bonding (pairing) is left to the desktop OS's own
    Bluetooth settings - this only needs the adapter present and registers
    the profile for already-bonded (or bonding) devices to connect to."""

    def __init__(self, whip_server):
        self.whip_server = whip_server
        self._listeners = []
        self._bus = None
        self._adapter_address = None

    def on_event(self, callback):
        self._listeners.append(callback)

    def _emit(self, event):
        for callback in self._listeners:
            callback(event)

    async def start(self):
        try:
            # Unix fd passing (used by BlueZ to hand us the accepted RFCOMM
            # socket in NewConnection) must be negotiated on the bus first.
            self._bus = await MessageBus(bus_type=BusType.SYSTEM, negotiate_unix_fd=True).connect()
            self._adapter_address = await self._get_adapter_address()

            interface = _ProfileInterface(self._handle_connection)
            self._bus.export(PROFILE_PATH, interface)

            profile_manager = await self._profile_manager()
            await profile_manager.call_register_profile(
                PROFILE_PATH,
                SPP_UUID,
                {
                    "Name": Variant("s", "KHSAE TEI"),
                    "Role": Variant("s", "server"),
                    "RequireAuthentication": Variant("b", False),
                    "RequireAuthorization": Variant("b", False),
                },
            )
            self._emit({"kind": "bt_listening", "address": self._adapter_address})
        except Exception as err:
            # Bluetooth is best-effort, same as mDNS in discovery.py - no
            # adapter, bluetoothd not running, or a dbus-next/BlueZ
            # introspection quirk (e.g. InterfaceNotFoundError, which isn't
            # a DBusError) must never take the LAN server down with it.
            self._emit({"kind": "bt_error", "error": str(err)})

    async def _profile_manager(self):
        introspection = await self._bus.introspect("org.bluez", "/org/bluez")
        proxy = self._bus.get_proxy_object("org.bluez", "/org/bluez", introspection)
        return proxy.get_interface("org.bluez.ProfileManager1")

    async def _get_adapter_address(self):
        introspection = await self._bus.introspect("org.bluez", "/org/bluez/hci0")
        proxy = self._bus.get_proxy_object("org.bluez", "/org/bluez/hci0", introspection)
        props = proxy.get_interface("org.freedesktop.DBus.Properties")
        address = await props.call_get("org.bluez.Adapter1", "Address")
        return address.value

    def _handle_connection(self, device, sock):
        asyncio.create_task(self._run_connection(device, sock))

    async def _run_connection(self, device, sock):
        sock.setblocking(False)
        reader, writer = await asyncio.open_connection(sock=sock)

        async def close():
            writer.close()

        session = self.whip_server.create_session_handler(
            send=lambda msg: self._send_line(writer, msg),
            close=close,
            remote_label=f"bluetooth:{device}",
        )
        try:
            while True:
                raw = await reader.readline()
                if not raw:
                    break
                await session["handle_message"](raw.decode().strip())
        except (ConnectionResetError, OSError):
            pass
        finally:
            session["cleanup"]()
            if session["is_paired"]():
                self._emit({"kind": "disconnected", "remote": f"bluetooth:{device}"})
            writer.close()

    async def _send_line(self, writer, msg):
        writer.write((json.dumps(msg) + "\n").encode())
        await writer.drain()

    async def stop(self):
        if self._bus:
            try:
                profile_manager = await self._profile_manager()
                await profile_manager.call_unregister_profile(PROFILE_PATH)
            except Exception:
                pass
            self._bus.disconnect()
            self._bus = None
