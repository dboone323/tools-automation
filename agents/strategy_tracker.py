#!/usr/bin/env python3
"""
Strategy Performance Tracker
Tracks success rates, execution times, and adaptations for each strategy
"""

import json
import sys
from pathlib import Path
from typing import Dict, List, Optional
from datetime import datetime, timedelta
import statistics

# Configuration
KNOWLEDGE_DIR = Path(__file__).parent / "knowledge"
STRATEGIES_FILE = KNOWLEDGE_DIR / "strategies.json"
STRATEGY_HISTORY_FILE = KNOWLEDGE_DIR / "strategy_history.json"


class StrategyTracker:
    """Tracks and analyzes strategy performance over time"""

    def __init__(self):
        self.strategies = self._load_strategies()
        self.history = self._load_history()

    def _load_strategies(self) -> Dict:
        """Load strategy definitions"""
        if STRATEGIES_FILE.exists():
            with open(STRATEGIES_FILE, "r") as f:
                return json.load(f)

        # Initialize with default strategies
        default_strategies = {
            "strategies": [
                {
                    "id": "rebuild",
                    "name": "Rebuild Project",
                    "description": "Clean rebuild of the entire project",
                    "contexts": ["build_error", "compile_error"],
                    "base_risk": 0.1,
                    "estimated_time": 60,
                    "success_rate": 0.0,
                    "total_attempts": 0,
                    "successful_attempts": 0,
                    "failed_attempts": 0,
                    "avg_execution_time": 0,
                    "adaptations": [],
                    "created_at": datetime.now().isoformat(),
                },
                {
                    "id": "clean_build",
                    "name": "Clean Build",
                    "description": "Clean build directory and rebuild",
                    "contexts": ["dependency_issue", "cache_issue"],
                    "base_risk": 0.2,
                    "estimated_time": 90,
                    "success_rate": 0.0,
                    "total_attempts": 0,
                    "successful_attempts": 0,
                    "failed_attempts": 0,
                    "avg_execution_time": 0,
                    "adaptations": [],
                    "created_at": datetime.now().isoformat(),
                },
                {
                    "id": "fix_imports",
                    "name": "Fix Import Statements",
                    "description": "Update and fix import statements",
                    "contexts": ["import_error", "missing_module"],
                    "base_risk": 0.3,
                    "estimated_time": 40,
                    "success_rate": 0.0,
                    "total_attempts": 0,
                    "successful_attempts": 0,
                    "failed_attempts": 0,
                    "avg_execution_time": 0,
                    "adaptations": [],
                    "created_at": datetime.now().isoformat(),
                },
                {
                    "id": "run_tests",
                    "name": "Run Test Suite",
                    "description": "Execute full test suite",
                    "contexts": ["test_failure", "regression"],
                    "base_risk": 0.1,
                    "estimated_time": 180,
                    "success_rate": 0.0,
                    "total_attempts": 0,
                    "successful_attempts": 0,
                    "failed_attempts": 0,
                    "avg_execution_time": 0,
                    "adaptations": [],
                    "created_at": datetime.now().isoformat(),
                },
            ],
            "metadata": {
                "last_updated": datetime.now().isoformat(),
                "total_strategies": 4,
            },
        }

        self._save_strategies(default_strategies)
        return default_strategies

    def _load_history(self) -> Dict:
        """Load strategy execution history"""
        if STRATEGY_HISTORY_FILE.exists():
            with open(STRATEGY_HISTORY_FILE, "r") as f:
                return json.load(f)
        return {"executions": []}

    def _save_strategies(self, data: Optional[Dict] = None):
        """Save strategies to file"""
        if data is None:
            data = self.strategies

        STRATEGIES_FILE.parent.mkdir(parents=True, exist_ok=True)

        # Update metadata
        data["metadata"] = {
            "last_updated": datetime.now().isoformat(),
            "total_strategies": len(data.get("strategies", [])),
        }

        # Atomic write
        tmp_file = STRATEGIES_FILE.with_suffix(".tmp")
        with open(tmp_file, "w") as f:
            json.dump(data, f, indent=2)
        tmp_file.replace(STRATEGIES_FILE)

    def _save_history(self):
        """Save execution history"""
        STRATEGY_HISTORY_FILE.parent.mkdir(parents=True, exist_ok=True)

        # Atomic write
        tmp_file = STRATEGY_HISTORY_FILE.with_suffix(".tmp")
        with open(tmp_file, "w") as f:
            json.dump(self.history, f, indent=2)
        tmp_file.replace(STRATEGY_HISTORY_FILE)

    def record_execution(
        self,
        strategy_id: str,
        context: str,
        success: bool,
        execution_time: float,
        details: Optional[Dict] = None,
    ):
        """
        Record a strategy execution

        Args:
            strategy_id: ID of the strategy
            context: Context in which strategy was executed
            success: Whether execution was successful
            execution_time: Time taken in seconds
            details: Additional execution details
        """
        print(
            f"[Strategy Tracker] Recording execution: {strategy_id} (success={success})",
            file=sys.stderr,
        )

        # Find strategy
        strategy = self._find_strategy(strategy_id)
        if not strategy:
            print(
                f"[Strategy Tracker] Warning: Strategy {strategy_id} not found",
                file=sys.stderr,
            )
            # Still record in history even for unknown strategies
            execution_record = {
                "timestamp": datetime.now().isoformat(),
                "strategy_id": strategy_id,
                "context": context,
                "success": success,
                "execution_time": execution_time,
                "details": details or {},
            }
            self.history["executions"].append(execution_record)

            # Keep last 1000 executions
            if len(self.history["executions"]) > 1000:
                self.history["executions"] = self.history["executions"][-1000:]

            # Save history
            self._save_history()
            return

        # Update strategy stats
        strategy["total_attempts"] += 1
        if success:
            strategy["successful_attempts"] += 1
        else:
            strategy["failed_attempts"] += 1

        # Update success rate
        strategy["success_rate"] = (
            strategy["successful_attempts"] / strategy["total_attempts"]
        )

        # Update average execution time
        if strategy["avg_execution_time"] == 0:
            strategy["avg_execution_time"] = execution_time
        else:
            # Exponential moving average
            alpha = 0.3
            strategy["avg_execution_time"] = (
                alpha * execution_time + (1 - alpha) * strategy["avg_execution_time"]
            )

        # Record in history
        execution_record = {
            "timestamp": datetime.now().isoformat(),
            "strategy_id": strategy_id,
            "context": context,
            "success": success,
            "execution_time": execution_time,
            "details": details or {},
        }
        self.history["executions"].append(execution_record)

        # Keep last 1000 executions
        if len(self.history["executions"]) > 1000:
            self.history["executions"] = self.history["executions"][-1000:]

        # Save
        self._save_strategies()
        self._save_history()

    def record_adaptation(self, strategy_id: str, change: str, impact: str):
        """
        Record a strategy adaptation

        Args:
            strategy_id: ID of the strategy
            change: Description of the change
            impact: Impact of the change
        """
        print(
            f"[Strategy Tracker] Recording adaptation: {strategy_id}", file=sys.stderr
        )

        strategy = self._find_strategy(strategy_id)
        if not strategy:
            return

        adaptation = {
            "date": datetime.now().isoformat(),
            "change": change,
            "impact": impact,
            "success_rate_before": strategy["success_rate"],
        }

        if "adaptations" not in strategy:
            strategy["adaptations"] = []

        strategy["adaptations"].append(adaptation)
        self._save_strategies()

    def get_strategy_performance(self, strategy_id: str) -> Dict:
        """Get performance metrics for a strategy"""
        strategy = self._find_strategy(strategy_id)
        if not strategy:
            return {"error": "Strategy not found"}

        # Get recent executions
        recent_executions = [
            e for e in self.history["executions"] if e["strategy_id"] == strategy_id
        ][
            -20:
        ]  # Last 20 executions

        # Calculate recent success rate
        recent_success_rate = 0.0
        if recent_executions:
            recent_successes = sum(1 for e in recent_executions if e["success"])
            recent_success_rate = recent_successes / len(recent_executions)

        # Calculate trend
        trend = "stable"
        if recent_success_rate > strategy["success_rate"] + 0.1:
            trend = "improving"
        elif recent_success_rate < strategy["success_rate"] - 0.1:
            trend = "declining"

        return {
            "strategy_id": strategy_id,
            "name": strategy["name"],
            "total_attempts": strategy["total_attempts"],
            "success_rate": strategy["success_rate"],
            "recent_success_rate": recent_success_rate,
            "trend": trend,
            "avg_execution_time": strategy["avg_execution_time"],
            "adaptations_count": len(strategy.get("adaptations", [])),
            "contexts": strategy.get("contexts", []),
        }

    def get_best_strategy(self, context: str) -> Optional[Dict]:
        """Get the best strategy for a given context"""
        # Filter strategies by context
        candidates = [
            s for s in self.strategies["strategies"] if context in s.get("contexts", [])
        ]

        if not candidates:
            return None

        # Sort by success rate (descending) and execution time (ascending)
        candidates.sort(
            key=lambda s: (
                -s["success_rate"],  # Higher success rate first
                (
                    s["avg_execution_time"]
                    if s["avg_execution_time"] > 0
                    else s["estimated_time"]
                ),  # Faster first
            )
        )

        return candidates[0] if candidates else None

    def get_all_strategies(self) -> List[Dict]:
        """Get all strategies with performance metrics"""
        return [
            self.get_strategy_performance(s["id"])
            for s in self.strategies["strategies"]
        ]

    def compare_strategies(self, strategy_ids: List[str]) -> Dict:
        """Compare performance of multiple strategies"""
        comparisons = []

        for strategy_id in strategy_ids:
            performance = self.get_strategy_performance(strategy_id)
            if "error" not in performance:
                comparisons.append(performance)

        if not comparisons:
            return {"error": "No valid strategies to compare"}

        # Sort by success rate
        comparisons.sort(key=lambda s: s["success_rate"], reverse=True)

        return {
            "strategies": comparisons,
            "best": comparisons[0]["strategy_id"],
            "worst": comparisons[-1]["strategy_id"],
            "avg_success_rate": statistics.mean(s["success_rate"] for s in comparisons),
        }

    def get_strategy_recommendations(self, context: str) -> List[Dict]:
        """Get recommended strategies for a context, ranked by performance"""
        candidates = [
            s
            for s in self.strategies["strategies"]
            if context in s.get("contexts", []) or not s.get("contexts")
        ]

        # Calculate score for each strategy
        recommendations = []
        for strategy in candidates:
            # Score based on success rate and execution time
            success_score = strategy["success_rate"] * 100
            time_score = max(
                0,
                100
                - (
                    strategy["avg_execution_time"]
                    if strategy["avg_execution_time"] > 0
                    else strategy["estimated_time"]
                )
                / 2,
            )

            # Weight: 70% success, 30% speed
            total_score = 0.7 * success_score + 0.3 * time_score

            recommendations.append(
                {
                    "strategy_id": strategy["id"],
                    "name": strategy["name"],
                    "description": strategy["description"],
                    "success_rate": strategy["success_rate"],
                    "avg_execution_time": strategy["avg_execution_time"]
                    or strategy["estimated_time"],
                    "score": total_score,
                    "confidence": "high" if strategy["total_attempts"] >= 10 else "low",
                }
            )

        # Sort by score
        recommendations.sort(key=lambda r: r["score"], reverse=True)

        return recommendations

    def _find_strategy(self, strategy_id: str) -> Optional[Dict]:
        """Find strategy by ID"""
        for strategy in self.strategies["strategies"]:
            if strategy["id"] == strategy_id:
                return strategy
        return None

    def add_strategy(
        self,
        strategy_id: str,
        name: str,
        description: str,
        contexts: List[str],
        risk: float,
        estimated_time: int,
    ):
        """Add a new strategy"""
        # Check if already exists
        if self._find_strategy(strategy_id):
            print(
                f"[Strategy Tracker] Strategy {strategy_id} already exists",
                file=sys.stderr,
            )
            return False

        strategy = {
            "id": strategy_id,
            "name": name,
            "description": description,
            "contexts": contexts,
            "base_risk": risk,
            "estimated_time": estimated_time,
            "success_rate": 0.0,
            "total_attempts": 0,
            "successful_attempts": 0,
            "failed_attempts": 0,
            "avg_execution_time": 0,
            "adaptations": [],
            "created_at": datetime.now().isoformat(),
        }

        self.strategies["strategies"].append(strategy)
        self._save_strategies()

        print(f"[Strategy Tracker] Added strategy: {strategy_id}", file=sys.stderr)
        return True


def main():
    """Main entry point"""
    if len(sys.argv) < 2:
        print("Usage: strategy_tracker.py <command> [args...]", file=sys.stderr)
        print("\nCommands:", file=sys.stderr)
        print(
            "  record <strategy_id> <context> <success> <time> [details_json]",
            file=sys.stderr,
        )
        print("  adapt <strategy_id> <change> <impact>", file=sys.stderr)
        print("  performance <strategy_id>", file=sys.stderr)
        print("  best <context>", file=sys.stderr)
        print("  list", file=sys.stderr)
        print("  compare <strategy_id1> <strategy_id2> [...]", file=sys.stderr)
        print("  recommend <context>", file=sys.stderr)
        print(
            "  add <strategy_id> <name> <description> <contexts> <risk> <time>",
            file=sys.stderr,
        )
        sys.exit(1)

    command = sys.argv[1]
    tracker = StrategyTracker()

    if command == "record":
        if len(sys.argv) < 6:
            print(
                "Error: record requires strategy_id, context, success, time",
                file=sys.stderr,
            )
            sys.exit(1)

        strategy_id = sys.argv[2]
        context = sys.argv[3]
        success = sys.argv[4].lower() in ["true", "1", "yes"]
        execution_time = float(sys.argv[5])
        details = json.loads(sys.argv[6]) if len(sys.argv) > 6 else None

        tracker.record_execution(strategy_id, context, success, execution_time, details)
        print(json.dumps({"status": "recorded", "strategy_id": strategy_id}))

    elif command == "adapt":
        if len(sys.argv) < 5:
            print("Error: adapt requires strategy_id, change, impact", file=sys.stderr)
            sys.exit(1)

        strategy_id = sys.argv[2]
        change = sys.argv[3]
        impact = sys.argv[4]

        tracker.record_adaptation(strategy_id, change, impact)
        print(json.dumps({"status": "recorded", "strategy_id": strategy_id}))

    elif command == "performance":
        if len(sys.argv) < 3:
            print("Error: performance requires strategy_id", file=sys.stderr)
            sys.exit(1)

        strategy_id = sys.argv[2]
        performance = tracker.get_strategy_performance(strategy_id)
        print(json.dumps(performance, indent=2))

    elif command == "best":
        if len(sys.argv) < 3:
            print("Error: best requires context", file=sys.stderr)
            sys.exit(1)

        context = sys.argv[2]
        best = tracker.get_best_strategy(context)
        print(
            json.dumps(best, indent=2)
            if best
            else json.dumps({"error": "No strategy found"})
        )

    elif command == "list":
        strategies = tracker.get_all_strategies()
        print(json.dumps(strategies, indent=2))

    elif command == "compare":
        if len(sys.argv) < 4:
            print("Error: compare requires at least 2 strategy IDs", file=sys.stderr)
            sys.exit(1)

        strategy_ids = sys.argv[2:]
        comparison = tracker.compare_strategies(strategy_ids)
        print(json.dumps(comparison, indent=2))

    elif command == "recommend":
        if len(sys.argv) < 3:
            print("Error: recommend requires context", file=sys.stderr)
            sys.exit(1)

        context = sys.argv[2]
        recommendations = tracker.get_strategy_recommendations(context)
        print(json.dumps(recommendations, indent=2))

    elif command == "add":
        if len(sys.argv) < 8:
            print(
                "Error: add requires strategy_id, name, description, contexts, risk, time",
                file=sys.stderr,
            )
            sys.exit(1)

        strategy_id = sys.argv[2]
        name = sys.argv[3]
        description = sys.argv[4]
        contexts = sys.argv[5].split(",")
        risk = float(sys.argv[6])
        estimated_time = int(sys.argv[7])

        success = tracker.add_strategy(
            strategy_id, name, description, contexts, risk, estimated_time
        )
        print(
            json.dumps(
                {"status": "added" if success else "exists", "strategy_id": strategy_id}
            )
        )

    else:
        print(f"Error: Unknown command '{command}'", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
