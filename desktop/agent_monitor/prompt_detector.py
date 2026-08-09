import re
from dataclasses import dataclass
from enum import Enum

# How many trailing non-blank lines of a screen we look at. Deliberately
# small: matching against the whole scrollback would pick up stale prompt-like
# text (e.g. "Continue? [y/N]" printed minutes ago and long since answered)
# instead of what's actually on screen right now.
_TAIL_LINES = 6


class PromptType(str, Enum):
    CONFIRMATION = "confirmation"
    MENU = "menu"
    TEXT_INPUT = "text_input"
    PRESS_ENTER = "press_enter"
    UNKNOWN = "unknown"


@dataclass(frozen=True)
class PromptPattern:
    """One entry in the configurable detection table - not tied to any
    single agent's exact wording, so new phrasings can be added here without
    touching detect_prompt() itself."""

    regex: "re.Pattern[str]"
    type: PromptType
    confidence: float
    description: str


# Ordered by specificity/confidence: the first matching pattern wins. Kept
# deliberately narrow (bracketed y/n, explicit "press enter", a real cursor
# glyph) rather than matching on bare words like "continue" or "confirm",
# which show up constantly in ordinary non-blocking output.
PATTERNS: list[PromptPattern] = [
    PromptPattern(
        re.compile(r"\[[Yy]/[Nn]\]\s*$"),
        PromptType.CONFIRMATION,
        0.95,
        "bracketed y/n default",
    ),
    PromptPattern(
        re.compile(r"\((?:y/n|yes/no)\)\s*$", re.IGNORECASE),
        PromptType.CONFIRMATION,
        0.9,
        "parenthesized y/n",
    ),
    PromptPattern(
        re.compile(r"(do you want to (proceed|continue)|allow this (command|action|tool))\b.*\?\s*$", re.IGNORECASE),
        PromptType.CONFIRMATION,
        0.85,
        "explicit yes/no question",
    ),
    PromptPattern(
        re.compile(r"press (any key|enter|return)\b(.*continue)?", re.IGNORECASE),
        PromptType.PRESS_ENTER,
        0.85,
        "press enter/any key to continue",
    ),
    PromptPattern(
        re.compile(r"^\s*❯\s*\S"),
        PromptType.MENU,
        0.9,
        "inquirer/ink-style selection cursor",
    ),
    PromptPattern(
        re.compile(r"^\s*>\s+\S"),
        PromptType.MENU,
        0.6,
        "plain '>' selection cursor (lower confidence, common char)",
    ),
    PromptPattern(
        re.compile(r"\S:\s*$"),
        PromptType.TEXT_INPUT,
        0.5,
        "trailing colon prompt (weak signal, relies on caller's idle gate)",
    ),
]


def _tail_lines(text: str) -> list[str]:
    lines = [line.rstrip() for line in text.splitlines() if line.strip()]
    return lines[-_TAIL_LINES:]


def detect_prompt(output: str) -> dict:
    """Classifies the tail of already-rendered terminal text (no ANSI codes -
    the caller is expected to have run it through a real terminal emulator
    such as pyte first, since redraw-heavy menus can't be reliably matched
    off raw escape-coded bytes).

    Returns a plain dict: {"waiting": bool, "type": str, "prompt": str,
    "confidence": float}. Matching is restricted to the last few non-blank
    lines and to fairly specific patterns (bracketed y/n, explicit "press
    enter", a real menu cursor glyph, ...) rather than bare keywords like
    "continue" or "confirm", which appear constantly in normal scrolling
    output that isn't actually blocked on anything.
    """
    lines = _tail_lines(output)
    if not lines:
        return {"waiting": False, "type": PromptType.UNKNOWN.value, "prompt": "", "confidence": 0.0}

    # Menu patterns care about the exact line that has the cursor; the other
    # patterns are checked against the last line and then the last couple of
    # lines joined, so a wrapped question ("Do you want to proceed\nwith
    # this? [y/N]") still matches.
    candidates = [lines[-1], " ".join(lines[-2:])]

    for pattern in PATTERNS:
        if pattern.type == PromptType.MENU:
            for line in reversed(lines):
                if pattern.regex.search(line):
                    return {
                        "waiting": True,
                        "type": pattern.type.value,
                        "prompt": line.strip(),
                        "confidence": pattern.confidence,
                    }
            continue
        for candidate in candidates:
            if pattern.regex.search(candidate):
                return {
                    "waiting": True,
                    "type": pattern.type.value,
                    "prompt": candidate.strip(),
                    "confidence": pattern.confidence,
                }

    return {"waiting": False, "type": PromptType.UNKNOWN.value, "prompt": "", "confidence": 0.0}


_SELF_TEST_CASES = [
    ("Do you want to proceed? [y/N]", True, PromptType.CONFIRMATION),
    ("Allow this command? [y/N]", True, PromptType.CONFIRMATION),
    ("Overwrite existing file? (y/n)", True, PromptType.CONFIRMATION),
    ("Press Enter to continue", True, PromptType.PRESS_ENTER),
    ("❯ Yes\n  No", True, PromptType.MENU),
    ("Running tests...\nAll 42 tests passed, continuing to build.", False, PromptType.UNKNOWN),
    ("Please confirm your email address was sent.", False, PromptType.UNKNOWN),
    ("Downloading dependencies, this may take a while, please wait...", False, PromptType.UNKNOWN),
]


def _run_self_test() -> None:
    failures = []
    for text, expected_waiting, expected_type in _SELF_TEST_CASES:
        result = detect_prompt(text)
        ok = result["waiting"] == expected_waiting and (not expected_waiting or result["type"] == expected_type.value)
        status = "ok" if ok else "FAIL"
        print(f"[{status}] {text!r} -> {result}")
        if not ok:
            failures.append(text)
    if failures:
        raise SystemExit(f"{len(failures)} self-test case(s) failed")
    print(f"\nAll {len(_SELF_TEST_CASES)} self-test cases passed.")


if __name__ == "__main__":
    _run_self_test()
