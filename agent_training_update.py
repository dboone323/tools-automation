#!/usr/bin/env python3
"""Update agent training data with solved task sample.
Usage:
  python agent_training_update.py --id <TODO_ID> [--snippet path/to/code_or_log]
Stores training data in agent_training_data.json
"""
import argparse, json, os, datetime

ROOT = os.path.dirname(os.path.abspath(__file__))
TRAIN_FILE = os.path.join(ROOT, "agent_training_data.json")
TODOS_FILE = os.path.join(ROOT, "unified_todos.json")


def load_json(path, default):
    if not os.path.exists(path):
        return default
    with open(path, "r") as f:
        return json.load(f)


def save_json(path, data):
    with open(path, "w") as f:
        json.dump(data, f, indent=2)


parser = argparse.ArgumentParser()
parser.add_argument("--id", required=True)
parser.add_argument("--snippet", help="Optional file containing resolution snippet/log")
args = parser.parse_args()

todos = load_json(TODOS_FILE, {"todos": []}).get("todos", [])
training = load_json(TRAIN_FILE, {"samples": []})

match = next((t for t in todos if t.get("id") == args.id), None)
if not match:
    print("Todo not found")
    exit(1)

sample = {
    "todo_id": match["id"],
    "title": match.get("title"),
    "category": match.get("category"),
    "assignee": match.get("assignee"),
    "outcome": match.get("resolution_outcome"),
    "root_cause": match.get("root_cause"),
    "time_to_resolution_seconds": match.get("time_to_resolution_seconds"),
    "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
}

if args.snippet and os.path.exists(args.snippet):
    with open(args.snippet, "r") as f:
        content = f.read()[:4000]
    sample["resolution_snippet"] = content

training["samples"].append(sample)
save_json(TRAIN_FILE, training)
print(f"Added training sample for {args.id}")
