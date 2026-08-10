from __future__ import annotations

import asyncio
import json
import os

from .paths import socket_path
from .prompt_detector import detect_prompt

_LABELS = {"claude": "Claude", "codex": "Codex"}


def _label_for(command: str) -> str:
    # `command` is the full invocation (e.g. "claude --foo" or "python3
    # fake_agent.py") - the label is derived from just the executable name.
    executable = command.split()[0] if command else ""
    base = os.path.basename(executable) or "agent"
    return _LABELS.get(base, base)


class Agent:
    def __init__(self, agent_id: str, pid, workspace: str, command: str, terminal: str):
        self.id = agent_id
        self.pid = pid
        self.workspace = workspace
        self.command = command
        self.terminal = terminal
        self.label = _label_for(command)
        self.state = "RUNNING"
        self.last_prompt = None


class AgentMonitorHub:
    """Listens on a local Unix domain socket for `agent_monitor/supervisor.py`
    processes (one per coding-agent instance the user has wrapped), tracks a
    small state machine per agent, and pushes a phone-facing event through
    the existing WhipServer whenever an agent transitions into a waiting
    state. Mirrors the on_event/_emit shape of WhipServer for consistency
    with the rest of desktop/."""

    def __init__(self, whip_server):
        self.whip_server = whip_server
        self._listeners = []
        self._server = None
        self._agents: dict[str, Agent] = {}

    def on_event(self, callback):
        self._listeners.append(callback)

    def _emit(self, event):
        for callback in self._listeners:
            callback(event)

    async def start(self):
        path = socket_path()
        if path.exists():
            path.unlink()
        self._server = await asyncio.start_unix_server(self._handle_connection, path=str(path))
        self._emit({"kind": "agent_hub_listening", "path": str(path)})

    async def _handle_connection(self, reader, writer):
        agent: Agent | None = None
        try:
            while True:
                raw = await reader.readline()
                if not raw:
                    break
                try:
                    msg = json.loads(raw.decode())
                except (json.JSONDecodeError, UnicodeDecodeError):
                    continue
                agent = await self._handle_message(msg, agent)
        finally:
            writer.close()
            # A connection that drops without an explicit "exit" message
            # (supervisor killed, crashed) still needs the phone-visible
            # registry cleaned up - treat it the same as an error exit.
            if agent is not None and self._agents.pop(agent.id, None) is not None:
                self._emit({"kind": "agent_done", "agent_id": agent.id, "label": agent.label, "state": "ERROR"})

    async def _handle_message(self, msg: dict, agent: "Agent | None") -> "Agent | None":
        kind = msg.get("type")

        if kind == "register":
            agent = Agent(
                agent_id=msg["agent_id"],
                pid=msg.get("pid"),
                workspace=msg.get("workspace", ""),
                command=msg.get("command", ""),
                terminal=msg.get("terminal", ""),
            )
            self._agents[agent.id] = agent
            self._emit({
                "kind": "agent_registered",
                "agent_id": agent.id,
                "label": agent.label,
                "workspace": agent.workspace,
                "pid": agent.pid,
            })
            return agent

        if agent is None:
            return None

        if kind == "screen_update":
            detection = detect_prompt(msg.get("text", ""))
            new_state = self._state_for(detection)
            if new_state != agent.state:
                previous = agent.state
                agent.state = new_state
                agent.last_prompt = detection if detection["waiting"] else None
                self._emit({
                    "kind": "agent_state",
                    "agent_id": agent.id,
                    "label": agent.label,
                    "state": new_state,
                    "previous": previous,
                })
                if new_state in ("WAITING_FOR_INPUT", "WAITING_FOR_CONFIRMATION"):
                    await self._push_waiting(agent, detection)
            return agent

        if kind == "exit":
            code = msg.get("code", 0)
            agent.state = "COMPLETED" if code == 0 else "ERROR"
            self._emit({
                "kind": "agent_done",
                "agent_id": agent.id,
                "label": agent.label,
                "state": agent.state,
                "code": code,
            })
            self._agents.pop(agent.id, None)
            return agent

        return agent

    @staticmethod
    def _state_for(detection: dict) -> str:
        if not detection["waiting"]:
            return "RUNNING"
        if detection["type"] == "confirmation":
            return "WAITING_FOR_CONFIRMATION"
        return "WAITING_FOR_INPUT"

    async def _push_waiting(self, agent: Agent, detection: dict):
        await self.whip_server.push_event({
            "type": "agent_waiting",
            "agent_id": agent.id,
            "pid": agent.pid,
            "workspace": agent.workspace,
            "terminal": agent.terminal,
            "label": agent.label,
            "state": agent.state,
            "prompt_type": detection["type"],
            "prompt": detection["prompt"],
        })

    async def stop(self):
        if self._server:
            self._server.close()
            await self._server.wait_closed()
            path = socket_path()
            if path.exists():
                path.unlink()
