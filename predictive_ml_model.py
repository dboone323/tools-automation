#!/usr/bin/env python3
"""Lightweight predictive risk scoring using pattern frequencies.
Updates predictive_data.json with ml_risk_scores.
Usage: python predictive_ml_model.py predictive_data.json
(No external ML libs required.)
"""
import json, sys, math, datetime, os

if len(sys.argv) < 2:
    print("Usage: predictive_ml_model.py predictive_data.json")
    sys.exit(0)

path = sys.argv[1]
if not os.path.exists(path):
    print("Predictive file not found")
    sys.exit(0)

data = json.load(open(path))
patterns = data.get("error_patterns", {})

# Simple logistic-style transform: score = 1/(1+e^{-k*(freq-norm)})
# Use adaptive k relative to max frequency.
if not patterns:
    print("No patterns to score")
    sys.exit(0)

max_freq = max(patterns.values()) or 1
scores = {}
for p, freq in patterns.items():
    norm = freq / max_freq  # 0..1
    k = 3.0
    val = 1.0 / (1.0 + math.exp(-k * (norm - 0.5)))  # center at 0.5
    scores[p] = round(val, 4)

# Aggregate top risk components if they appear in predictions
component_risks = {}
for pred in data.get("failure_predictions", []):
    comp = pred.get("component")
    # correlate component with patterns containing component keyword
    related = [scores[p] for p in scores if comp and comp.lower() in p.lower()]
    if related:
        component_risks[comp] = round(sum(related) / len(related), 4)

ml_section = {
    "generated_at": datetime.datetime.utcnow().isoformat() + "Z",
    "pattern_risk_scores": scores,
    "component_risk_scores": component_risks,
    "max_pattern_frequency": max_freq,
}

data["ml_risk_scores"] = ml_section

with open(path, "w") as f:
    json.dump(data, f, indent=2)
print("ML risk scores updated.")
