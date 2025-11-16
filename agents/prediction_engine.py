#!/usr/bin/env python3
"""
Failure Prediction Engine
Predicts potential failures before they occur based on code changes and historical patterns
"""

import json
import sys
import os
import re
from pathlib import Path
from typing import Dict, List
from datetime import datetime
import hashlib

# Configuration
KNOWLEDGE_DIR = Path(__file__).parent / "knowledge"
ERROR_PATTERNS_FILE = KNOWLEDGE_DIR / "error_patterns.json"
FAILURE_ANALYSIS_FILE = KNOWLEDGE_DIR / "failure_analysis.json"
PREDICTIONS_FILE = KNOWLEDGE_DIR / "predictions.json"


class FailurePredictor:
    """Predicts potential failures based on code changes and patterns"""

    def __init__(self):
        self.error_patterns = self._load_error_patterns()
        self.failure_analysis = self._load_failure_analysis()
        self.predictions_history = self._load_predictions()

    def _load_error_patterns(self) -> Dict:
        """Load error patterns from knowledge base"""
        if ERROR_PATTERNS_FILE.exists():
            with open(ERROR_PATTERNS_FILE, "r") as f:
                return json.load(f)
        return {"patterns": []}

    def _load_failure_analysis(self) -> Dict:
        """Load failure analysis from knowledge base"""
        if FAILURE_ANALYSIS_FILE.exists():
            try:
                with open(FAILURE_ANALYSIS_FILE, "r") as f:
                    content = f.read().strip()
                    # Handle multiple JSON objects - take the last valid one
                    if content.count("{") > 1:
                        # Split on }\n{ pattern and take last
                        parts = content.split("}\n{")
                        if len(parts) > 1:
                            content = "{" + parts[-1]
                    return json.loads(content)
            except json.JSONDecodeError as e:
                print(
                    f"[Prediction] Warning: Could not parse failure_analysis.json: {e}",
                    file=sys.stderr,
                )
                # Return minimal structure
                return {"failures": []}
        return {"failures": []}

    def _load_predictions(self) -> Dict:
        """Load prediction history"""
        if PREDICTIONS_FILE.exists():
            with open(PREDICTIONS_FILE, "r") as f:
                return json.load(f)
        return {"predictions": [], "accuracy": {"correct": 0, "incorrect": 0}}

    def _save_predictions(self):
        """Save predictions to file"""
        PREDICTIONS_FILE.parent.mkdir(parents=True, exist_ok=True)

        # Atomic write
        tmp_file = PREDICTIONS_FILE.with_suffix(".tmp")
        with open(tmp_file, "w") as f:
            json.dump(self.predictions_history, f, indent=2)
        tmp_file.replace(PREDICTIONS_FILE)

    def analyze_change(self, file_path: str, change_type: str = "modification") -> Dict:
        """
        Analyze a code change and predict potential failures

        Args:
            file_path: Path to the changed file
            change_type: Type of change (modification, addition, deletion)

        Returns:
            Dictionary with risk score and predicted issues
        """
        print(
            f"[Prediction] Analyzing {change_type} in {file_path}...", file=sys.stderr
        )

        # Calculate risk score
        risk_score = self._calculate_risk_score(file_path, change_type)

        # Check against known failure patterns
        predicted_issues = self._check_failure_patterns(file_path)

        # Analyze code complexity
        complexity_issues = self._analyze_complexity(file_path)

        # Check for anti-patterns
        anti_patterns = self._check_anti_patterns(file_path)

        # Combine all findings
        all_issues = predicted_issues + complexity_issues + anti_patterns

        # Generate prevention strategies
        preventions = self._suggest_preventions(all_issues, risk_score)

        # Create prediction record
        prediction = {
            "timestamp": datetime.now().isoformat(),
            "file": file_path,
            "change_type": change_type,
            "risk_score": risk_score,
            "predicted_issues": all_issues,
            "preventions": preventions,
            "status": "pending",  # Will be updated when outcome is known
        }

        # Save prediction
        self.predictions_history["predictions"].append(prediction)
        self._save_predictions()

        return {
            "risk_score": risk_score,
            "risk_level": self._risk_level(risk_score),
            "predicted_issues": all_issues,
            "preventions": preventions,
            "recommendation": self._get_recommendation(risk_score),
        }

    def _calculate_risk_score(self, file_path: str, change_type: str) -> float:
        """Calculate risk score for a change (0.0 - 1.0)"""
        risk = 0.0

        # Base risk by change type
        type_risk = {
            "addition": 0.3,  # New files have moderate risk
            "modification": 0.4,  # Modifications have higher risk
            "deletion": 0.2,  # Deletions have lower risk
        }
        risk += type_risk.get(change_type, 0.3)

        # Check file type risk
        if file_path.endswith(".swift"):
            risk += 0.1  # Swift files are critical
        elif file_path.endswith(".py"):
            risk += 0.05
        elif file_path.endswith(".sh"):
            risk += 0.15  # Shell scripts can be risky

        # Check if file has failure history
        file_failures = self._get_file_failure_count(file_path)
        if file_failures > 0:
            risk += min(0.2, file_failures * 0.05)

        # Check if file is in critical path
        if any(
            critical in file_path for critical in ["build", "deploy", "main", "core"]
        ):
            risk += 0.1

        return min(1.0, risk)

    def _get_file_failure_count(self, file_path: str) -> int:
        """Get number of historical failures for a file"""
        count = 0
        for failure in self.failure_analysis.get("failures", []):
            if failure.get("file") == file_path:
                count += 1
        return count

    def _check_failure_patterns(self, file_path: str) -> List[Dict]:
        """Check file against known failure patterns"""
        issues = []

        # Read file content if it exists
        if not os.path.exists(file_path):
            return issues

        try:
            with open(file_path, "r") as f:
                content = f.read()
        except Exception as e:
            print(
                f"[Prediction] Warning: Could not read {file_path}: {e}",
                file=sys.stderr,
            )
            return issues

        # Check against known error patterns
        for pattern_entry in self.error_patterns.get("patterns", []):
            pattern = pattern_entry.get("pattern", "")
            if not pattern:
                continue

            # Check if pattern matches file content
            if re.search(pattern, content, re.IGNORECASE):
                issues.append(
                    {
                        "type": "known_pattern",
                        "severity": pattern_entry.get("severity", "medium"),
                        "category": pattern_entry.get("category", "unknown"),
                        "description": f"Code matches known failure pattern: {pattern_entry.get('message', 'Unknown')}",
                        "confidence": 0.7,
                    }
                )

        return issues

    def _analyze_complexity(self, file_path: str) -> List[Dict]:
        """Analyze code complexity and identify issues"""
        issues = []

        if not os.path.exists(file_path):
            return issues

        try:
            with open(file_path, "r") as f:
                content = f.read()
                lines = content.split("\n")
        except Exception:
            return issues

        # Check file size
        if len(lines) > 500:
            issues.append(
                {
                    "type": "complexity",
                    "severity": "medium",
                    "category": "maintainability",
                    "description": f"File has {len(lines)} lines (>500), increasing failure risk",
                    "confidence": 0.6,
                }
            )

        # Check function length (simplified)
        if file_path.endswith((".swift", ".py")):
            func_patterns = [r"func \w+\(", r"def \w+\("]
            for pattern in func_patterns:
                matches = list(re.finditer(pattern, content))
                if len(matches) > 20:
                    issues.append(
                        {
                            "type": "complexity",
                            "severity": "low",
                            "category": "maintainability",
                            "description": f"File has {len(matches)} functions, consider splitting",
                            "confidence": 0.5,
                        }
                    )
                    break

        # Check nesting depth (simplified check)
        max_indent = 0
        for line in lines:
            indent = len(line) - len(line.lstrip())
            max_indent = max(max_indent, indent // 4)  # Assuming 4-space indents

        if max_indent > 6:
            issues.append(
                {
                    "type": "complexity",
                    "severity": "medium",
                    "category": "maintainability",
                    "description": f"Deep nesting detected (level {max_indent}), may cause logic errors",
                    "confidence": 0.6,
                }
            )

        return issues

    def _check_anti_patterns(self, file_path: str) -> List[Dict]:
        """Check for known anti-patterns"""
        issues = []

        if not os.path.exists(file_path):
            return issues

        try:
            with open(file_path, "r") as f:
                content = f.read()
        except Exception:
            return issues

        # Swift anti-patterns
        if file_path.endswith(".swift"):
            # Check for SwiftUI import in data models
            if "import SwiftUI" in content and any(
                keyword in content for keyword in ["struct ", "class "]
            ):
                if not any(
                    view in content
                    for view in ["View", "@State", "@Binding", "@ObservedObject"]
                ):
                    issues.append(
                        {
                            "type": "anti_pattern",
                            "severity": "high",
                            "category": "architecture",
                            "description": "SwiftUI imported in potential data model (violates architecture rules)",
                            "confidence": 0.8,
                        }
                    )

            # Check for force unwrapping
            if "!" in content and "!=" not in content:
                force_unwrap_count = len(re.findall(r"\w+!(?!=)", content))
                if force_unwrap_count > 5:
                    issues.append(
                        {
                            "type": "anti_pattern",
                            "severity": "medium",
                            "category": "safety",
                            "description": f"Excessive force unwrapping ({force_unwrap_count} instances), may cause crashes",
                            "confidence": 0.7,
                        }
                    )

        # Python anti-patterns
        if file_path.endswith(".py"):
            # Check for bare except
            if re.search(r"except\s*:", content):
                issues.append(
                    {
                        "type": "anti_pattern",
                        "severity": "medium",
                        "category": "error_handling",
                        "description": "Bare except clause detected, may hide errors",
                        "confidence": 0.8,
                    }
                )

        # Shell script anti-patterns
        if file_path.endswith(".sh"):
            # Check for missing error handling
            if "set -e" not in content and "set -euo pipefail" not in content:
                issues.append(
                    {
                        "type": "anti_pattern",
                        "severity": "high",
                        "category": "error_handling",
                        "description": "Missing error handling (set -e), script may fail silently",
                        "confidence": 0.9,
                    }
                )

        return issues

    def _suggest_preventions(self, issues: List[Dict], risk_score: float) -> List[Dict]:
        """Suggest prevention strategies based on predicted issues"""
        preventions = []

        # Group issues by type
        issue_types = {}
        for issue in issues:
            issue_type = issue.get("type", "unknown")
            if issue_type not in issue_types:
                issue_types[issue_type] = []
            issue_types[issue_type].append(issue)

        # Generate preventions based on issue types
        if "known_pattern" in issue_types:
            preventions.append(
                {
                    "strategy": "pre_validation",
                    "action": "Run validation checks before committing",
                    "priority": "high",
                    "estimated_effort": "5 minutes",
                }
            )

        if "complexity" in issue_types:
            preventions.append(
                {
                    "strategy": "refactoring",
                    "action": "Consider refactoring to reduce complexity",
                    "priority": "medium",
                    "estimated_effort": "30 minutes",
                }
            )

        if "anti_pattern" in issue_types:
            high_severity_anti_patterns = [
                i for i in issue_types["anti_pattern"] if i.get("severity") == "high"
            ]
            if high_severity_anti_patterns:
                preventions.append(
                    {
                        "strategy": "code_review",
                        "action": "Mandatory code review before deployment",
                        "priority": "critical",
                        "estimated_effort": "15 minutes",
                    }
                )

        # Add monitoring based on risk score
        if risk_score > 0.7:
            preventions.append(
                {
                    "strategy": "enhanced_monitoring",
                    "action": "Enable enhanced monitoring for this change",
                    "priority": "high",
                    "estimated_effort": "2 minutes",
                }
            )

        # Add testing recommendation
        if risk_score > 0.5:
            preventions.append(
                {
                    "strategy": "comprehensive_testing",
                    "action": "Run full test suite including integration tests",
                    "priority": "high",
                    "estimated_effort": "10 minutes",
                }
            )

        return preventions

    def _risk_level(self, risk_score: float) -> str:
        """Convert risk score to risk level"""
        if risk_score >= 0.8:
            return "critical"
        elif risk_score >= 0.6:
            return "high"
        elif risk_score >= 0.4:
            return "medium"
        else:
            return "low"

    def _get_recommendation(self, risk_score: float) -> str:
        """Get recommendation based on risk score"""
        if risk_score >= 0.8:
            return "STOP: Critical risk detected. Mandatory review and validation required before proceeding."
        elif risk_score >= 0.6:
            return "CAUTION: High risk detected. Enhanced validation and testing strongly recommended."
        elif risk_score >= 0.4:
            return "REVIEW: Medium risk detected. Standard validation should be sufficient."
        else:
            return "PROCEED: Low risk detected. Normal validation process applies."

    def update_prediction_outcome(
        self, prediction_id: str, outcome: str, actual_issues: List[str]
    ):
        """
        Update prediction with actual outcome

        Args:
            prediction_id: ID of the prediction (timestamp or hash)
            outcome: "success" or "failure"
            actual_issues: List of actual issues that occurred
        """
        # Find prediction
        for pred in self.predictions_history["predictions"]:
            if (
                pred["timestamp"] == prediction_id
                or hashlib.md5(pred["timestamp"].encode()).hexdigest() == prediction_id
            ):
                pred["status"] = "completed"
                pred["outcome"] = outcome
                pred["actual_issues"] = actual_issues

                # Update accuracy
                predicted_issue_types = set(
                    issue["type"] for issue in pred["predicted_issues"]
                )
                actual_issue_types = set(actual_issues)

                if (
                    outcome == "failure"
                    and len(predicted_issue_types & actual_issue_types) > 0
                ):
                    # We predicted at least one issue that occurred
                    self.predictions_history["accuracy"]["correct"] += 1
                elif outcome == "success" and len(pred["predicted_issues"]) == 0:
                    # We predicted no issues and there were none
                    self.predictions_history["accuracy"]["correct"] += 1
                elif (
                    outcome == "failure"
                    and len(predicted_issue_types & actual_issue_types) == 0
                ):
                    # We failed to predict the failure
                    self.predictions_history["accuracy"]["incorrect"] += 1
                else:
                    # False positive (predicted issues but none occurred)
                    self.predictions_history["accuracy"]["incorrect"] += 1

                break

        self._save_predictions()

    def get_prediction_accuracy(self) -> Dict:
        """Get prediction accuracy statistics"""
        accuracy = self.predictions_history.get(
            "accuracy", {"correct": 0, "incorrect": 0}
        )
        total = accuracy["correct"] + accuracy["incorrect"]

        if total == 0:
            return {
                "total_predictions": len(
                    self.predictions_history.get("predictions", [])
                ),
                "verified_predictions": 0,
                "accuracy_rate": 0.0,
                "correct": 0,
                "incorrect": 0,
            }

        return {
            "total_predictions": len(self.predictions_history.get("predictions", [])),
            "verified_predictions": total,
            "accuracy_rate": accuracy["correct"] / total if total > 0 else 0.0,
            "correct": accuracy["correct"],
            "incorrect": accuracy["incorrect"],
        }


def main():
    """Main entry point"""
    if len(sys.argv) < 2:
        print("Usage: prediction_engine.py <command> [args...]", file=sys.stderr)
        print("\nCommands:", file=sys.stderr)
        print(
            "  analyze <file_path> [change_type]  - Analyze file and predict failures",
            file=sys.stderr,
        )
        print(
            "  update <prediction_id> <outcome> [issues...]  - Update prediction outcome",
            file=sys.stderr,
        )
        print("  accuracy  - Show prediction accuracy statistics", file=sys.stderr)
        sys.exit(1)

    command = sys.argv[1]
    predictor = FailurePredictor()

    if command == "analyze":
        if len(sys.argv) < 3:
            print("Error: analyze requires file_path argument", file=sys.stderr)
            sys.exit(1)

        file_path = sys.argv[2]
        change_type = sys.argv[3] if len(sys.argv) > 3 else "modification"

        result = predictor.analyze_change(file_path, change_type)
        print(json.dumps(result, indent=2))

    elif command == "update":
        if len(sys.argv) < 4:
            print("Error: update requires prediction_id and outcome", file=sys.stderr)
            sys.exit(1)

        prediction_id = sys.argv[2]
        outcome = sys.argv[3]
        actual_issues = sys.argv[4:] if len(sys.argv) > 4 else []

        predictor.update_prediction_outcome(prediction_id, outcome, actual_issues)
        print(
            json.dumps(
                {
                    "status": "updated",
                    "prediction_id": prediction_id,
                    "outcome": outcome,
                }
            )
        )

    elif command == "accuracy":
        accuracy = predictor.get_prediction_accuracy()
        print(json.dumps(accuracy, indent=2))

    else:
        print(f"Error: Unknown command '{command}'", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
