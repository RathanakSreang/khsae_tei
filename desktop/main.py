import asyncio
import sys
import threading
import time

import qrcode

import discovery
from agent_monitor.hub import AgentMonitorHub
from bluetooth_server import BluetoothServer
from net import get_lan_ip
from server import DEFAULT_PORT, WhipServer

HELP_TEXT = "Commands: [r] regenerate code   [h] help   [q] quit"


def print_server_info(whip_server):
    ip = get_lan_ip()
    url = f"ws://{ip}:{whip_server.port}?code={whip_server.code}"
    print(f"\nDesktop address: {ip}:{whip_server.port}")
    print(f"Pairing code:    {whip_server.code}\n")
    qr = qrcode.QRCode(border=1)
    qr.add_data(url)
    qr.make()
    qr.print_ascii(invert=True)
    print()


def log_event(event):
    kind = event.get("kind")
    if kind == "listening":
        message = f"Server listening on port {event['port']}"
    elif kind == "paired":
        message = f"Paired: {event.get('clientName') or event.get('remote')}"
    elif kind == "pair_failed":
        message = f"Rejected wrong code from {event.get('remote')}"
    elif kind == "whip":
        message = f"Whip received from {event.get('remote')} -> Enter sent"
    elif kind == "keypress_failed":
        message = f"Keypress failed: {event.get('error')}"
    elif kind == "disconnected":
        message = f"Disconnected: {event.get('remote')}"
    elif kind == "code_regenerated":
        message = "Pairing code regenerated"
    elif kind == "bt_listening":
        message = f"Bluetooth SPP registered on adapter {event.get('address')}"
    elif kind == "bt_error":
        message = f"Bluetooth unavailable: {event.get('error')}"
    elif kind == "agent_hub_listening":
        message = f"Agent monitor listening on {event.get('path')}"
    elif kind == "agent_registered":
        message = f"Agent registered: {event.get('label')} (pid {event.get('pid')}) in {event.get('workspace')}"
    elif kind == "agent_state":
        message = f"Agent {event.get('label')} -> {event.get('state')}"
    elif kind == "agent_done":
        message = f"Agent {event.get('label')} finished: {event.get('state')}"
    else:
        message = str(event)
    print(f"[{time.strftime('%H:%M:%S')}] {message}")


def stdin_reader_thread(loop, queue):
    for line in sys.stdin:
        loop.call_soon_threadsafe(queue.put_nowait, line.strip())
    loop.call_soon_threadsafe(queue.put_nowait, "q")


async def command_loop(queue, whip_server):
    while True:
        cmd = await queue.get()
        if cmd in ("q", "quit", "exit"):
            return
        elif cmd in ("r", "regen"):
            whip_server.regenerate_code()
            print_server_info(whip_server)
        elif cmd in ("h", "help", "?"):
            print(HELP_TEXT)
        elif cmd:
            print(f"Unknown command '{cmd}'. {HELP_TEXT}")


async def main():
    whip_server = WhipServer(DEFAULT_PORT)
    whip_server.on_event(log_event)

    bluetooth_server = BluetoothServer(whip_server)
    bluetooth_server.on_event(log_event)

    agent_hub = AgentMonitorHub(whip_server)
    agent_hub.on_event(log_event)

    await whip_server.start()
    discovery.advertise(whip_server.port)
    await bluetooth_server.start()
    await agent_hub.start()

    print("=" * 50)
    print(" KHSAE TEI desktop")
    print("=" * 50)
    print_server_info(whip_server)
    print(HELP_TEXT + "\n")

    queue = asyncio.Queue()
    loop = asyncio.get_running_loop()
    threading.Thread(target=stdin_reader_thread, args=(loop, queue), daemon=True).start()

    try:
        await command_loop(queue, whip_server)
    finally:
        discovery.stop()
        await agent_hub.stop()
        await bluetooth_server.stop()
        await whip_server.stop()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
