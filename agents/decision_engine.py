#!/usr/bin/env python3

"""
Decision Engine - Autonomous Action Selection System
Evaluates situations, selects actions, and verifies outcomes with confidence scoring.
"""

import json
import sys
import hashlib
from typing import Dict, List
from datetime import datetime
from pathlib import Path

# Configuration
SCRIPT_DIR = Path(__file__).parent
KNOWLEDGE_DIR = SCRIPT_DIR / "knowledge"
ERROR_PATTERNS_FILE = KNOWLEDGE_DIR / "error_patterns.json"
FIX_HISTORY_FILE = KNOWLEDGE_DIR / "fix_history.json"
FAILURE_ANALYSIS_FILE = KNOWLEDGE_DIR / "failure_analysis.json"
CORRELATION_MATRIX_FILE = KNOWLEDGE_DIR / "correlation_matrix.json"

# Confidence thresholds
MIN_CONFIDENCE_AUTO_EXECUTE = 0.75
MIN_CONFIDENCE_SUGGEST = 0.50
HIGH_SEVERITY_CONFIDENCE_BOOST = 0.15

# Action registry with risk scores
ACTION_REGISTRY = {
    "rebuild": {"risk": 0.1, "time_estimate": 60, "category": "build"},
    "clean_build": {"risk": 0.2, "time_estimate": 90, "category": "build"},
    "update_dependencies": {
        "risk": 0.4,
        "time_estimate": 120,
        "category": "dependency",
    },
    "fix_lint": {"risk": 0.1, "time_estimate": 30, "category": "lint"},
    "fix_format": {"risk": 0.05, "time_estimate": 20, "category": "format"},
    "run_tests": {"risk": 0.1, "time_estimate": 180, "category": "test"},
    "fix_imports": {"risk": 0.3, "time_estimate": 40, "category": "code"},
    "rollback": {"risk": 0.5, "time_estimate": 30, "category": "recovery"},
    "skip": {"risk": 0.0, "time_estimate": 0, "category": "none"},
}


class DecisionEngine:
    """Autonomous decision-making engine for agent system."""

    def __init__(self):
        self.error_patterns = self._load_json(ERROR_PATTERNS_FILE)
        self.fix_history = self._load_json(FIX_HISTORY_FILE)
        self.failure_analysis = self._load_json(FAILURE_ANALYSIS_FILE)
        self.correlation_matrix = self._load_json(CORRELATION_MATRIX_FILE)

    def _load_json(self, filepath: Path) -> dict:
        """Load JSON file safely."""
        if not filepath.exists():
            return {}
        try:
            with open(filepath, "r") as f:
                return json.load(f)
        except json.JSONDecodeError:
            return {}

    def _save_json(self, filepath: Path, data: dict):
        """Save JSON file atomically."""
        filepath.parent.mkdir(parents=True, exist_ok=True)
        tmp_file = filepath.with_suffix(".tmp")
        with open(tmp_file, "w") as f:
            json.dump(data, f, indent=2)
        tmp_file.replace(filepath)

    def _stable_hash(self, text: str) -> str:
        """Generate stable 8-character hash for text."""
        return hashlib.md5(text.encode()).hexdigest()[:8]

    def evaluate_situation(
        self, error_pattern: str, context: Dict[str, any] = None
    ) -> Dict[str, any]:
        """
        Evaluate error situation and recommend actions.

        Returns:
            {
                "recommended_action": str,
                "confidence": float (0.0-1.0),
                "reasoning": str,
                "alternatives": List[Dict],
                "auto_execute": bool
            }
        """
        context = context or {}

        # Look up error in knowledge base
        error_hash = self._stable_hash(error_pattern.lower())
        known_error = self.error_patterns.get(error_hash)

        if not known_error:
            # Unknown error - low confidence, suggest safe actions
            return {
                "recommended_action": "analyze_and_log",
                "confidence": 0.3,
                "reasoning": "Unknown error pattern, needs analysis",
                "alternatives": [
                    {"action": "rebuild", "confidence": 0.4},
                    {"action": "skip", "confidence": 0.5},
                ],
                "auto_execute": False,
            }

        # Known error - calculate confidence based on history
        category = known_error.get("category", "unknown")
        severity = known_error.get("severity", "medium")
        occurrences = known_error.get("count", 1)

        # Check fix history for this error
        successful_fixes = self._get_successful_fixes(error_hash)

        if successful_fixes:
            # We've fixed this before
            best_fix = successful_fixes[0]  # Most successful
            confidence = self._calculate_confidence(
                base=0.70,
                success_rate=best_fix.get("success_rate", 0.5),
                occurrences=occurrences,
                severity=severity,
            )

            return {
                "recommended_action": best_fix["action"],
                "confidence": confidence,
                "reasoning": f"Previously fixed {best_fix.get('times_used', 0)} times with {int(best_fix.get('success_rate', 0)*100)}% success rate",
                "alternatives": self._get_alternative_actions(successful_fixes[1:3]),
                "auto_execute": confidence >= MIN_CONFIDENCE_AUTO_EXECUTE,
                "known_error": True,
                "category": category,
                "severity": severity,
            }

        # Known error but no fix history - use heuristics
        action = self._heuristic_action_selection(category, severity, context)
        confidence = self._calculate_confidence(
            base=0.50, occurrences=occurrences, severity=severity
        )

        return {
            "recommended_action": action,
            "confidence": confidence,
            "reasoning": f"Heuristic selection for {category} error (severity: {severity})",
            "alternatives": self._get_heuristic_alternatives(category),
            "auto_execute": confidence >= MIN_CONFIDENCE_AUTO_EXECUTE,
            "known_error": True,
            "category": category,
            "severity": severity,
        }

    def _calculate_confidence(
        self,
        base: float,
        success_rate: float = 0.5,
        occurrences: int = 1,
        severity: str = "medium",
    ) -> float:
        """Calculate confidence score with multiple factors."""
        confidence = base

        # Success rate factor
        confidence += (success_rate - 0.5) * 0.2

        # Occurrence factor (more occurrences = more confidence)
        occurrence_boost = min(occurrences / 10.0, 0.15)
        confidence += occurrence_boost

        # Severity factor (high severity = more aggressive)
        if severity == "high":
            confidence += HIGH_SEVERITY_CONFIDENCE_BOOST
        elif severity == "low":
            confidence -= 0.05

        # Clamp to valid range
        return max(0.0, min(1.0, confidence))

    def _get_successful_fixes(self, error_hash: str) -> List[Dict]:
        """Get successful fixes from history, sorted by success rate."""
        fixes = []

        for fix_id, fix_data in self.fix_history.items():
            if fix_data.get("error_hash") == error_hash and fix_data.get(
                "success", False
            ):
                fixes.append(fix_data)

        # Sort by success rate, then by times used
        fixes.sort(
            key=lambda x: (x.get("success_rate", 0), x.get("times_used", 0)),
            reverse=True,
        )
        return fixes

    def _heuristic_action_selection(
        self, category: str, severity: str, context: Dict
    ) -> str:
        """Select action using heuristics when no fix history available."""
        # Category-based selection
        category_actions = {
            "build": "clean_build" if severity == "high" else "rebuild",
            "test": "run_tests",
            "lint": "fix_lint",
            "format": "fix_format",
            "dependency": "update_dependencies",
            "import": "fix_imports",
            "unknown": "rebuild",
        }

        return category_actions.get(category, "rebuild")

    def _get_alternative_actions(self, fixes: List[Dict]) -> List[Dict]:
        """Get alternative actions from fix list."""
        alternatives = []
        for fix in fixes[:3]:  # Top 3 alternatives
            alternatives.append(
                {
                    "action": fix.get("action", "unknown"),
                    "confidence": fix.get("success_rate", 0.5)
                    * 0.8,  # Slightly lower than primary
                }
            )
        return alternatives

    def _get_heuristic_alternatives(self, category: str) -> List[Dict]:
        """Get alternative actions based on category."""
        alternatives_map = {
            "build": [
                {"action": "clean_build", "confidence": 0.6},
                {"action": "update_dependencies", "confidence": 0.4},
            ],
            "test": [
                {"action": "rebuild", "confidence": 0.5},
                {"action": "clean_build", "confidence": 0.4},
            ],
            "lint": [{"action": "fix_format", "confidence": 0.5}],
            "dependency": [{"action": "rebuild", "confidence": 0.5}],
        }

        return alternatives_map.get(category, [{"action": "skip", "confidence": 0.3}])

    def verify_outcome(
        self, action: str, before_state: str, after_state: str
    ) -> Dict[str, any]:
        """
        Verify if an action was successful.

        Returns:
            {
                "success": bool,
                "confidence": float,
                "explanation": str,
                "metrics": Dict
            }
        """
        # Simple state comparison heuristics
        success_indicators = ["success", "passed", "completed", "✅", "fixed"]
        failure_indicators = ["failed", "error", "❌", "timeout", "crashed"]

        after_lower = after_state.lower()

        # Check for success indicators
        success_count = sum(
            1 for indicator in success_indicators if indicator in after_lower
        )
        failure_count = sum(
            1 for indicator in failure_indicators if indicator in after_lower
        )

        # Determine success
        if success_count > failure_count:
            success = True
            confidence = 0.7 + min(success_count * 0.1, 0.2)
            explanation = (
                f"Success indicators found ({success_count}), action likely succeeded"
            )
        elif failure_count > success_count:
            success = False
            confidence = 0.7 + min(failure_count * 0.1, 0.2)
            explanation = (
                f"Failure indicators found ({failure_count}), action likely failed"
            )
        else:
            # Ambiguous - compare states
            success = after_state != before_state
            confidence = 0.5
            explanation = "State changed but outcome unclear"

        return {
            "success": success,
            "confidence": confidence,
            "explanation": explanation,
            "metrics": {
                "success_indicators": success_count,
                "failure_indicators": failure_count,
                "state_changed": after_state != before_state,
            },
        }

    def record_fix_attempt(
        self, error_pattern: str, action: str, success: bool, duration: float = 0.0
    ):
        """Record a fix attempt to build history and correlation data."""
        error_hash = self._stable_hash(error_pattern.lower())
        fix_id = f"{error_hash}_{action}_{datetime.now().strftime('%Y%m%d_%H%M%S')}"

        # Update fix history
        if fix_id not in self.fix_history:
            self.fix_history[fix_id] = {
                "error_hash": error_hash,
                "action": action,
                "times_used": 0,
                "successes": 0,
                "failures": 0,
                "success_rate": 0.0,
                "avg_duration": 0.0,
                "first_used": datetime.now().isoformat(),
                "last_used": datetime.now().isoformat(),
            }

        fix_data = self.fix_history[fix_id]
        fix_data["times_used"] += 1
        fix_data["last_used"] = datetime.now().isoformat()

        if success:
            fix_data["successes"] += 1
        else:
            fix_data["failures"] += 1

        fix_data["success_rate"] = fix_data["successes"] / fix_data["times_used"]

        # Update average duration
        if duration > 0:
            current_avg = fix_data.get("avg_duration", 0.0)
            times = fix_data["times_used"]
            fix_data["avg_duration"] = ((current_avg * (times - 1)) + duration) / times

        self._save_json(FIX_HISTORY_FILE, self.fix_history)

        # Update correlation matrix
        self._update_correlations(error_hash, action, success)

    def _update_correlations(self, error_hash: str, action: str, success: bool):
        """Update correlation matrix between errors and actions."""
        key = f"{error_hash}:{action}"

        if key not in self.correlation_matrix:
            self.correlation_matrix[key] = {
                "error_hash": error_hash,
                "action": action,
                "total_attempts": 0,
                "successes": 0,
                "correlation_score": 0.0,
            }

        corr_data = self.correlation_matrix[key]
        corr_data["total_attempts"] += 1
        if success:
            corr_data["successes"] += 1

        # Calculate correlation score (success rate with confidence adjustment)
        attempts = corr_data["total_attempts"]
        successes = corr_data["successes"]

        # Wilson score interval for small samples
        if attempts >= 3:
            success_rate = successes / attempts
            # Simple confidence adjustment
            confidence_penalty = max(0, (10 - attempts) * 0.02)
            corr_data["correlation_score"] = success_rate - confidence_penalty
        else:
            corr_data["correlation_score"] = 0.3  # Low confidence for few samples

        self._save_json(CORRELATION_MATRIX_FILE, self.correlation_matrix)


def main():
    """CLI interface for decision engine."""
    if len(sys.argv) < 2:
        print("Usage: decision_engine.py <command> [arguments]", file=sys.stderr)
        print("\nCommands:", file=sys.stderr)
        print(
            "  evaluate <error_pattern> [context_json]  - Evaluate situation and recommend action",
            file=sys.stderr,
        )
        print(
            "  verify <action> <before> <after>         - Verify if action succeeded",
            file=sys.stderr,
        )
        print(
            "  record <error_pattern> <action> <success> [duration] - Record fix attempt",
            file=sys.stderr,
        )
        sys.exit(1)

    command = sys.argv[1]
    engine = DecisionEngine()

    if command == "evaluate":
        if len(sys.argv) < 3:
            print("ERROR: Missing error_pattern argument", file=sys.stderr)
            sys.exit(1)

        error_pattern = sys.argv[2]
        context = {}
        if len(sys.argv) > 3:
            try:
                context = json.loads(sys.argv[3])
            except json.JSONDecodeError:
                print("WARN: Invalid context JSON, ignoring", file=sys.stderr)

        result = engine.evaluate_situation(error_pattern, context)
        print(json.dumps(result, indent=2))

    elif command == "verify":
        if len(sys.argv) < 5:
            print("ERROR: Missing arguments for verify", file=sys.stderr)
            sys.exit(1)

        action = sys.argv[2]
        before = sys.argv[3]
        after = sys.argv[4]

        result = engine.verify_outcome(action, before, after)
        print(json.dumps(result, indent=2))

    elif command == "record":
        if len(sys.argv) < 5:
            print("ERROR: Missing arguments for record", file=sys.stderr)
            sys.exit(1)

        error_pattern = sys.argv[2]
        action = sys.argv[3]
        success = sys.argv[4].lower() in ["true", "1", "yes", "success"]
        duration = float(sys.argv[5]) if len(sys.argv) > 5 else 0.0

        engine.record_fix_attempt(error_pattern, action, success, duration)
        print(json.dumps({"status": "recorded", "success": success}))

    else:
        print(f"ERROR: Unknown command: {command}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
