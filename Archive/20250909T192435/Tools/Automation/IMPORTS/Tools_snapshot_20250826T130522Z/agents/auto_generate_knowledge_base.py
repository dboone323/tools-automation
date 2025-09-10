#!/usr/bin/env python3
# Auto-generate documentation/knowledge base from agent scripts, configs, and logs
import os
import re
from datetime import datetime

AGENTS_DIR = os.path.dirname(__file__)
DOC_FILE = os.path.join(AGENTS_DIR, "KNOWLEDGE_BASE.md")

header = f"""# Agent System Knowledge Base (Auto-Generated)

_Last updated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}_

"""

sections = []

# Summarize scripts
sections.append("## Agents & Tools\n")
for fname in sorted(os.listdir(AGENTS_DIR)):
    if fname.endswith((".sh", ".py")) and not fname.startswith(
        (
            "onboard",
            "distributed_launcher",
            "distributed_health_check",
            "auto_generate_knowledge_base",
        )
    ):
        path = os.path.join(AGENTS_DIR, fname)
        with open(path) as f:
            first_lines = [next(f) for _ in range(5)]
        desc = next(
            (
                re.sub(r"^# ?", "", l).strip()
                for l in first_lines
                if l.strip().startswith("#")
            ),
            fname,
        )
        sections.append(f"- **{fname}**: {desc}")
sections.append("")

# Summarize configs
sections.append("## Configs\n")
for fname in sorted(os.listdir(AGENTS_DIR)):
    if fname.endswith(".conf"):
        sections.append(f"- **{fname}**: Policy or configuration file.")
sections.append("")

# Summarize logs
sections.append("## Logs\n")
for fname in sorted(os.listdir(AGENTS_DIR)):
    if fname.endswith(".log"):
        sections.append(f"- **{fname}**: Audit or agent log file.")
sections.append("")

# Usage and quickstart
sections.append(
    "## Quickstart\n- Run `onboard.sh` to set up environment and permissions.\n- Start supervisor: `./agent_supervisor.sh`\n- Run API server: `python3 api_server.py`\n- Analyze logs: `python3 ai_log_analyzer.py`\n- For distributed: `./distributed_launcher.sh` and `./distributed_health_check.sh`\n"
)

with open(DOC_FILE, "w") as f:
    f.write(header)
    f.write("\n".join(sections))

print(f"Knowledge base auto-generated at {DOC_FILE}")
