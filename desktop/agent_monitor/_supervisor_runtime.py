import asyncio
import codecs
import errno
import fcntl
import json
import os
import signal
import struct
import termios
import tty
import uuid

import pyte

from .paths import socket_path

SETTLE_SECONDS = 0.4
KILL_ESCALATION_SECONDS = 0.5
SCREEN_COLS = 120
SCREEN_ROWS = 40
TAIL_ROWS = 8


class SupervisorRuntime:
    """The asyncio half of the pty supervisor - everything that has to
    happen after pty.fork() has already split the process. Proxies bytes in
    both directions between the real terminal and the agent's pty, feeds
    output through pyte to reconstruct on-screen text, and reports
    idle-settled snapshots to the hub."""

    def __init__(self, child_pid: int, master_fd: int, command: list):
        self.child_pid = child_pid
        self.master_fd = master_fd
        self.command = command
        self.agent_id = str(uuid.uuid4())
        self.workspace = os.getcwd()
        self.is_tty = os.isatty(0)
        self.terminal = os.ttyname(0) if self.is_tty else ""

        self._orig_termios = None
        self._decoder = codecs.getincrementaldecoder("utf-8")(errors="replace")
        self._screen = pyte.Screen(SCREEN_COLS, SCREEN_ROWS)
        self._stream = pyte.Stream(self._screen)
        self._settle_handle = None
        self._exit_code = 0
        self._exiting = None  # asyncio.Event, created inside run()
        self._writer = None

    async def run(self):
        loop = asyncio.get_running_loop()
        self._exiting = asyncio.Event()

        os.set_blocking(self.master_fd, False)
        if self.is_tty:
            os.set_blocking(0, False)
            self._orig_termios = termios.tcgetattr(0)
            tty.setraw(0)
        self._sync_winsize()

        _, writer = await asyncio.open_unix_connection(path=str(socket_path()))
        self._writer = writer
        await self._send_ipc({
            "type": "register",
            "agent_id": self.agent_id,
            "pid": self.child_pid,
            "workspace": self.workspace,
            "command": " ".join(self.command),
            "terminal": self.terminal,
        })

        loop.add_reader(self.master_fd, self._on_master_readable)
        if self.is_tty:
            loop.add_reader(0, self._on_stdin_readable)

        for sig in (signal.SIGCHLD, signal.SIGTERM, signal.SIGHUP):
            loop.add_signal_handler(sig, self._on_signal, sig)
        if self.is_tty:
            loop.add_signal_handler(signal.SIGWINCH, self._sync_winsize)

        try:
            await self._exiting.wait()
        finally:
            await self._shutdown(loop)

    # -- pty <-> real terminal proxying --------------------------------

    def _on_master_readable(self):
        try:
            data = os.read(self.master_fd, 65536)
        except OSError as err:
            # Reading a pty master after the child has exited raises EIO on
            # Linux, not a 0-byte EOF like a normal pipe.
            if err.errno == errno.EIO:
                data = b""
            else:
                raise
        if not data:
            # Remove the reader immediately - EIO recurs on every poll once
            # the child is gone, and we don't want the loop to keep calling
            # back into this before shutdown gets a chance to run.
            asyncio.get_running_loop().remove_reader(self.master_fd)
            self._exiting.set()
            return
        try:
            os.write(1, data)
        except OSError:
            pass
        self._stream.feed(self._decoder.decode(data))
        self._schedule_settle()

    def _on_stdin_readable(self):
        try:
            data = os.read(0, 4096)
        except OSError:
            data = b""
        if not data:
            return
        try:
            os.write(self.master_fd, data)
        except OSError:
            pass

    # -- window size ------------------------------------------------------

    def _sync_winsize(self):
        if not self.is_tty:
            return
        try:
            packed = fcntl.ioctl(0, termios.TIOCGWINSZ, struct.pack("HHHH", 0, 0, 0, 0))
            fcntl.ioctl(self.master_fd, termios.TIOCSWINSZ, packed)
        except OSError:
            pass

    # -- signals ------------------------------------------------------

    def _on_signal(self, sig: int):
        if sig == signal.SIGCHLD:
            try:
                pid, status = os.waitpid(self.child_pid, os.WNOHANG)
            except ChildProcessError:
                pid = 0
            if pid == self.child_pid:
                self._exit_code = os.WEXITSTATUS(status) if os.WIFEXITED(status) else 1
                self._exiting.set()
        else:
            # SIGTERM/SIGHUP against the supervisor itself, with the child
            # still running - it's about to be force-killed in _shutdown,
            # not exiting on its own, so this must not be reported as a
            # clean/successful completion.
            self._exit_code = -1
            self._exiting.set()

    # -- prompt-detection reporting --------------------------------------

    def _schedule_settle(self):
        loop = asyncio.get_running_loop()
        if self._settle_handle:
            self._settle_handle.cancel()
        self._settle_handle = loop.call_later(SETTLE_SECONDS, self._on_settle)

    def _on_settle(self):
        asyncio.ensure_future(self._report_settle())

    async def _report_settle(self):
        # Take rows ending at the cursor, not the bottom of the fixed-size
        # screen buffer - until enough output has been printed to actually
        # scroll the screen, the bottom rows are simply blank and the real
        # content (near the cursor) would otherwise be missed entirely.
        cursor_row = self._screen.cursor.y
        start = max(0, cursor_row - TAIL_ROWS + 1)
        tail = "\n".join(self._screen.display[start : cursor_row + 1])
        try:
            await self._send_ipc({"type": "screen_update", "agent_id": self.agent_id, "text": tail})
        except (BrokenPipeError, ConnectionResetError, OSError):
            pass

    async def _send_ipc(self, msg: dict):
        self._writer.write((json.dumps(msg) + "\n").encode())
        await self._writer.drain()

    # -- shutdown -----------------------------------------------------

    async def _shutdown(self, loop):
        loop.remove_reader(self.master_fd)
        if self.is_tty:
            loop.remove_reader(0)
            try:
                termios.tcsetattr(0, termios.TCSADRAIN, self._orig_termios)
            except termios.error:
                pass

        try:
            await self._send_ipc({"type": "exit", "agent_id": self.agent_id, "code": self._exit_code})
        except Exception:
            pass
        if self._writer:
            self._writer.close()

        # Closing the master fd delivers SIGHUP to the child's process group
        # (it's a session leader via pty.fork()'s login_tty), which is
        # usually enough on its own; killpg + a short escalation to SIGKILL
        # is the fallback so a killed supervisor never leaves the agent
        # running silently in the background.
        try:
            os.close(self.master_fd)
        except OSError:
            pass
        await self._ensure_child_gone()

    async def _ensure_child_gone(self):
        try:
            os.killpg(self.child_pid, signal.SIGTERM)
        except (ProcessLookupError, PermissionError):
            return
        await asyncio.sleep(KILL_ESCALATION_SECONDS)
        try:
            os.kill(self.child_pid, 0)
        except ProcessLookupError:
            return
        try:
            os.killpg(self.child_pid, signal.SIGKILL)
        except (ProcessLookupError, PermissionError):
            pass
