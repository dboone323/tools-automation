#!/usr/bin/env python3
"""
Agent status update script - handles both list and dict JSON formats
"""
import json
import time
import tempfile
import os
import sys


def main():
    if len(sys.argv) < 4:
        print(
            "Usage: update_status.py <status> <agent_name> <pid> [task_id]",
            file=sys.stderr,
        )
        sys.exit(1)

    try:
        status = sys.argv[1]
        agent_name = sys.argv[2]
        pid = int(sys.argv[3])
        task_id = sys.argv[4] if len(sys.argv) > 4 else ""
        status_file = os.environ.get("STATUS_FILE", "agent_status.json")

        print(
            f"DEBUG: update_status.py called with status={status}, agent_name={agent_name}, pid={pid}, task_id={task_id}, status_file={status_file}, cwd={os.getcwd()}",
            file=sys.stderr,
        )

        # Read existing data with retry
        max_retries = 3
        for attempt in range(max_retries):
            try:
                with open(status_file, "r") as f:
                    data = json.load(f)
                break
            except json.JSONDecodeError as e:
                if attempt < max_retries - 1:
                    print(
                        f"JSON decode error (attempt {attempt + 1}/{max_retries}): {e}",
                        file=sys.stderr,
                    )
                    time.sleep(0.1)
                    continue
                else:
                    raise e

        # Handle both formats: list of agents or dict with agents key
        if isinstance(data, list):
            # List format: find or create agent entry
            agent_found = False
            for agent in data:
                if agent.get("id") == agent_name or agent.get("name") == agent_name:
                    agent["status"] = status
                    agent["last_seen"] = int(time.time())
                    agent["pid"] = pid
                    if task_id:
                        agent["current_task_id"] = task_id
                    # Preserve tasks_completed if exists
                    agent_found = True
                    break
            if not agent_found:
                new_agent = {
                    "id": agent_name,
                    "name": agent_name,
                    "status": status,
                    "last_seen": int(time.time()),
                    "pid": pid,
                }
                if task_id:
                    new_agent["current_task_id"] = task_id
                data.append(new_agent)
        else:
            # Dict format (legacy)
            if "agents" not in data:
                data["agents"] = {}

            agent_data = {"status": status, "last_seen": int(time.time()), "pid": pid}

            # Only add tasks_completed if agent already has it
            if (
                agent_name in data["agents"]
                and "tasks_completed" in data["agents"][agent_name]
            ):
                agent_data["tasks_completed"] = data["agents"][agent_name][
                    "tasks_completed"
                ]

            if task_id:
                agent_data["current_task_id"] = task_id

            data["agents"][agent_name] = agent_data
            data["last_update"] = int(time.time())

        # Write to temporary file first, then atomically move
        with tempfile.NamedTemporaryFile(
            mode="w", dir=os.path.dirname(status_file), delete=False
        ) as temp_file:
            json.dump(data, temp_file, indent=2)
            temp_file.flush()
            os.fsync(temp_file.fileno())  # Force write to disk
            temp_path = temp_file.name

        # Atomic move
        os.rename(temp_path, status_file)

        sys.exit(0)
    except Exception as e:
        print(f"Failed to update status: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
