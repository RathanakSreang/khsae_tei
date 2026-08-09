import os
from pathlib import Path


def socket_path() -> Path:
    """Local Unix domain socket the hub listens on and supervisors connect
    to. Kept in its own module (no asyncio/other imports) so
    supervisor.py can use it without pulling in anything before its
    pty.fork() call."""
    runtime_dir = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
    directory = Path(runtime_dir) / "khsae_tei"
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    return directory / "agent_monitor.sock"
