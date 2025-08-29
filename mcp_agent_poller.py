#!/usr/bin/env python3
"""
Simple MCP agent poller demo.

Registers with the local MCP server and polls for tasks (status endpoint) every few seconds.
If a task is queued for this agent and execute is false, the agent can request execution.
This is a lightweight demo to show agent<->MCP interaction.
"""
import os
import sys
import time

import requests

MCP_URL = os.environ.get("MCP_URL", "http://127.0.0.1:5005")
AGENT_NAME = sys.argv[1] if len(sys.argv) > 1 else "demo-agent"


def register():
    r = requests.post(
        f"{MCP_URL}/register",
        json={"agent": AGENT_NAME, "capabilities": ["automation"]},
    )
    print("register ->", r.status_code, r.text)


def poll_loop():
    while True:
        try:
            r = requests.get(f"{MCP_URL}/status")
            print("status ->", r.status_code, r.json())
        except Exception as e:
            print("status failed", e)
        time.sleep(5)


def main():
    register()
    print("Starting poll loop (ctrl-c to stop)")
    poll_loop()


if __name__ == "__main__":
    main()
