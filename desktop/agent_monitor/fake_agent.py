"""A tiny scripted stand-in for a real coding agent CLI, used to prove the
supervisor -> hub -> prompt_detector -> WebSocket chain end-to-end without
needing Claude/Codex installed. Run it through the supervisor:

    python3 -m agent_monitor.supervisor python3 agent_monitor/fake_agent.py
"""

import time


def main() -> None:
    print("Fake Agent starting up...")
    for step in range(1, 4):
        print(f"Doing step {step} of 3...")
        time.sleep(0.5)

    answer = input("Do you want to proceed? [y/N] ")
    if answer.strip().lower() == "y":
        print("Proceeding...")
        time.sleep(0.3)
        print("Done.")
    else:
        print("Aborted.")


if __name__ == "__main__":
    main()
