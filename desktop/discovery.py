import socket
import threading

from zeroconf import ServiceInfo, Zeroconf

from net import get_lan_ip

_zeroconf = None
_info = None
_lock = threading.Lock()


def advertise(port):
    """Registers the mDNS service in a background thread. register_service()
    is a blocking call (probing takes a couple seconds, longer on flaky
    networks); mDNS is a best-effort convenience here, not a hard
    requirement, so app startup must not wait on it. Manual IP:port entry
    is always the fallback on networks where multicast doesn't work."""

    def _register():
        global _zeroconf, _info
        try:
            zc = Zeroconf()
            ip = get_lan_ip()
            info = ServiceInfo(
                "_khsaetei._tcp.local.",
                "KHSAE TEI._khsaetei._tcp.local.",
                addresses=[socket.inet_aton(ip)],
                port=port,
            )
            zc.register_service(info)
            with _lock:
                _zeroconf, _info = zc, info
        except Exception:
            pass

    threading.Thread(target=_register, daemon=True).start()


def stop():
    global _zeroconf, _info
    with _lock:
        zc, info = _zeroconf, _info
        _zeroconf = None
        _info = None
    if zc and info:
        try:
            zc.unregister_service(info)
        except Exception:
            pass
    if zc:
        zc.close()
