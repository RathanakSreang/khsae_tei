"""Run a coding-agent CLI under a pty this process owns, so its output can be
monitored for prompts without scraping VS Code's UI:

    python3 -m agent_monitor.supervisor claude
    python3 -m agent_monitor.supervisor python3 agent_monitor/fake_agent.py

Transparently proxies the real terminal <-> the agent's own pty (colors,
resizing, Ctrl-C, arrow-key menus all behave exactly as if the agent were
run directly), while separately reconstructing on-screen text via pyte and
reporting idle-settled snapshots to agent_monitor.hub's AgentMonitorHub over
a local Unix socket.

pty.fork() is called as the very first thing in main(), before anything else
(asyncio, pyte, ...) is touched, to stay on the safe side of Python's
fork-with-threads hazards.
"""

import os
import pty
import sys


def main() -> None:
    if len(sys.argv) < 2:
        print("usage: python3 -m agent_monitor.supervisor <command> [args...]", file=sys.stderr)
        raise SystemExit(2)
    command = sys.argv[1:]

    child_pid, master_fd = pty.fork()
    if child_pid == 0:
        try:
            os.execvp(command[0], command)
        except FileNotFoundError:
            sys.stderr.write(f"khsae_tei: command not found: {command[0]}\n")
            os._exit(127)
        os._exit(126)  # only reached if execvp itself raised something else

    _run_parent(child_pid, master_fd, command)


def _run_parent(child_pid: int, master_fd: int, command: list) -> None:
    import asyncio

    from ._supervisor_runtime import SupervisorRuntime

    try:
        asyncio.run(SupervisorRuntime(child_pid, master_fd, command).run())
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
