#!/usr/bin/env python3
# AI Log Analyzer for Agent System
# Scans agent logs for anomalies, errors, and patterns. Suggests fixes and optimizations.
import os
import re
from datetime import datetime

AGENT_LOGS_DIR = os.path.join(os.path.dirname(__file__), "logs")
AUDIT_LOG = os.path.join(os.path.dirname(__file__), "audit.log")
REPORT_FILE = os.path.join(os.path.dirname(__file__), "ai_log_analysis.txt")

# Simple rules for anomaly detection (can be replaced with ML model)
ANOMALY_PATTERNS = [
    (re.compile(r"ROLLBACK", re.IGNORECASE), "rollback_detected"),
    (re.compile(r"error|fail|exception|traceback", re.IGNORECASE), "error_detected"),
    (re.compile(r"backup|restore", re.IGNORECASE), "backup_restore_event"),
]

recommendations = []
now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

for log_file in os.listdir(AGENT_LOGS_DIR):
    if not log_file.endswith(".log"):
        continue
    path = os.path.join(AGENT_LOGS_DIR, log_file)
    with open(path) as f:
        lines = f.readlines()[-100:]
        for line in lines:
            for pattern, label in ANOMALY_PATTERNS:
                if pattern.search(line):
                    recommendations.append(
                        f"[{now}] {log_file}: {label} -> {line.strip()}"
                    )

# Suggest actions based on findings
suggested_actions = []
for rec in recommendations:
    if "rollback_detected" in rec:
        suggested_actions.append("Increase validation frequency for affected agent.")
    elif "error_detected" in rec:
        suggested_actions.append("Trigger auto-fix or notify supervisor.")
    elif "backup_restore_event" in rec:
        suggested_actions.append("Audit backup/restore sequence for anomalies.")

# Write report
with open(REPORT_FILE, "w") as f:
    f.write("\n".join(recommendations) + "\n")
    f.write("---\n")
    f.write("\n".join(set(suggested_actions)) + "\n")

# Audit log
with open(AUDIT_LOG, "a") as f:
    f.write(
        f"[{now}] user=ai_log_analyzer action=analyze_logs result=success findings={len(recommendations)} suggestions={len(suggested_actions)}\n"
    )

print(
    f"AI Log Analysis complete. Findings: {len(recommendations)}. Suggestions: {len(suggested_actions)}. See {REPORT_FILE}."
)
