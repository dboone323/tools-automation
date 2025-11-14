#!/usr/bin/env python3
"""
Validate agent_status.json schema and integrity.
"""
import json
import sys
from pathlib import Path


def validate_agent_status(file_path: str) -> bool:
    """Validate the agent status JSON file."""
    try:
        with open(file_path, "r") as f:
            data = json.load(f)

        if not isinstance(data, dict):
            print(f"ERROR: Root must be a dictionary, got {type(data)}")
            return False

        # Check for required top-level keys
        required_keys = ["agents", "last_update"]
        for key in required_keys:
            if key not in data:
                print(f"ERROR: Missing required key: {key}")
                return False

        # Validate agents section
        agents = data.get("agents", {})
        if not isinstance(agents, dict):
            print("ERROR: 'agents' must be a dictionary")
            return False

        for agent_name, agent_data in agents.items():
            if not isinstance(agent_data, dict):
                print(f"ERROR: Agent '{agent_name}' data must be a dictionary")
                return False

            # Check required agent fields
            required_agent_keys = ["status", "last_seen"]
            for key in required_agent_keys:
                if key not in agent_data:
                    print(f"ERROR: Agent '{agent_name}' missing required key: {key}")
                    return False

            # Validate status
            valid_statuses = [
                "running",
                "stopped",
                "idle",
                "active",
                "restarting",
                "unknown",
            ]
            if agent_data["status"] not in valid_statuses:
                print(
                    f"WARNING: Agent '{agent_name}' has invalid status: {agent_data['status']}"
                )

        print(f"✅ Validation passed for {len(agents)} agents")
        return True

    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON: {e}")
        return False
    except FileNotFoundError:
        print(f"ERROR: File not found: {file_path}")
        return False
    except Exception as e:
        print(f"ERROR: Unexpected error: {e}")
        return False


def main():
    if len(sys.argv) != 2:
        print("Usage: python validate_agent_status.py <path_to_agent_status.json>")
        sys.exit(1)

    file_path = sys.argv[1]
    if validate_agent_status(file_path):
        print("✅ Agent status validation successful")
        sys.exit(0)
    else:
        print("❌ Agent status validation failed")
        sys.exit(1)


if __name__ == "__main__":
    main()
