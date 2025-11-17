#!/usr/bin/env python3
"""
Adaptive Strategy Evolution
Automatically tests and evolves strategies to improve performance over time
"""

import json
import sys
import random
from pathlib import Path
from typing import Dict, List, Optional
from datetime import datetime
from agents.utils import user_log
import copy

# Configuration
KNOWLEDGE_DIR = Path(__file__).parent / "knowledge"
STRATEGIES_FILE = KNOWLEDGE_DIR / "strategies.json"
EVOLUTION_FILE = KNOWLEDGE_DIR / "strategy_evolution.json"
EXPERIMENTS_FILE = KNOWLEDGE_DIR / "ab_experiments.json"


class StrategyEvolution:
    """Manages adaptive strategy evolution through A/B testing"""

    def __init__(self):
        self.strategies = self._load_strategies()
        self.evolution_history = self._load_evolution()
        self.experiments = self._load_experiments()

    def _load_strategies(self) -> Dict:
        """Load strategies"""
        if STRATEGIES_FILE.exists():
            with open(STRATEGIES_FILE, "r") as f:
                return json.load(f)
        return {"strategies": []}

    def _load_evolution(self) -> Dict:
        """Load evolution history"""
        if EVOLUTION_FILE.exists():
            with open(EVOLUTION_FILE, "r") as f:
                return json.load(f)
        return {"evolutions": [], "successful_mutations": []}

    def _load_experiments(self) -> Dict:
        """Load A/B test experiments"""
        if EXPERIMENTS_FILE.exists():
            with open(EXPERIMENTS_FILE, "r") as f:
                return json.load(f)
        return {"experiments": []}

    def _save_evolution(self):
        """Save evolution history"""
        EVOLUTION_FILE.parent.mkdir(parents=True, exist_ok=True)

        tmp_file = EVOLUTION_FILE.with_suffix(".tmp")
        with open(tmp_file, "w") as f:
            json.dump(self.evolution_history, f, indent=2)
        tmp_file.replace(EVOLUTION_FILE)

    def _save_experiments(self):
        """Save experiments"""
        EXPERIMENTS_FILE.parent.mkdir(parents=True, exist_ok=True)

        tmp_file = EXPERIMENTS_FILE.with_suffix(".tmp")
        with open(tmp_file, "w") as f:
            json.dump(self.experiments, f, indent=2)
        tmp_file.replace(EXPERIMENTS_FILE)

    def generate_variant(self, strategy_id: str) -> Optional[Dict]:
        """
        Generate a variant of a strategy for A/B testing

        Args:
            strategy_id: ID of the base strategy

        Returns:
            Variant strategy dictionary
        """
        user_log(f"[Strategy Evolution] Generating variant for {strategy_id}...", level="info", stderr=True)

        # Find base strategy
        base_strategy = self._find_strategy(strategy_id)
        if not base_strategy:
            user_log(f"[Strategy Evolution] Strategy {strategy_id} not found", level="error", stderr=True)
            return None

        # Create variant with mutations
        variant = copy.deepcopy(base_strategy)
        variant["id"] = (
            f"{strategy_id}_variant_{datetime.now().strftime('%Y%m%d%H%M%S')}"
        )
        variant["base_strategy"] = strategy_id
        variant["is_variant"] = True
        variant["mutations"] = []

        # Apply random mutations
        mutations = self._generate_mutations(variant)

        for mutation in mutations:
            variant["mutations"].append(mutation)

        user_log(f"[Strategy Evolution] Generated variant with {len(mutations)} mutation(s)", level="info", stderr=True)
        return variant

    def _generate_mutations(self, strategy: Dict) -> List[Dict]:
        """Generate random mutations for a strategy"""
        mutations = []
        mutation_types = [
            "adjust_timing",
            "add_pre_step",
            "add_post_step",
            "change_order",
            "add_validation",
        ]

        # Randomly select 1-2 mutations
        num_mutations = random.randint(1, 2)
        selected_mutations = random.sample(mutation_types, num_mutations)

        for mutation_type in selected_mutations:
            mutation = {"type": mutation_type, "applied_at": datetime.now().isoformat()}

            if mutation_type == "adjust_timing":
                # Adjust estimated time by ±20%
                adjustment = random.uniform(0.8, 1.2)
                mutation["description"] = f"Adjust timing by {adjustment:.1f}x"
                mutation["parameters"] = {"timing_adjustment": adjustment}

            elif mutation_type == "add_pre_step":
                # Add a preparation step
                pre_steps = [
                    "validate_environment",
                    "check_dependencies",
                    "backup_state",
                ]
                mutation["description"] = f"Add pre-step: {random.choice(pre_steps)}"
                mutation["parameters"] = {"pre_step": random.choice(pre_steps)}

            elif mutation_type == "add_post_step":
                # Add a verification step
                post_steps = ["verify_result", "run_smoke_test", "check_logs"]
                mutation["description"] = f"Add post-step: {random.choice(post_steps)}"
                mutation["parameters"] = {"post_step": random.choice(post_steps)}

            elif mutation_type == "change_order":
                mutation["description"] = "Reorder execution steps"
                mutation["parameters"] = {"reorder": True}

            elif mutation_type == "add_validation":
                mutation["description"] = "Add intermediate validation"
                mutation["parameters"] = {"validation_points": ["mid-execution"]}

            mutations.append(mutation)

        return mutations

    def create_ab_test(
        self, strategy_id: str, context: str, sample_size: int = 20
    ) -> Dict:
        """
        Create an A/B test experiment

        Args:
            strategy_id: Base strategy ID
            context: Context for testing
            sample_size: Number of executions per variant

        Returns:
            Experiment configuration
        """
        user_log(f"[Strategy Evolution] Creating A/B test for {strategy_id}...", level="info", stderr=True)

        # Generate variant
        variant = self.generate_variant(strategy_id)
        if not variant:
            return {"error": "Failed to generate variant"}

        # Create experiment
        experiment = {
            "id": f"exp_{datetime.now().strftime('%Y%m%d%H%M%S')}",
            "base_strategy": strategy_id,
            "variant_strategy": variant["id"],
            "variant_definition": variant,
            "context": context,
            "sample_size": sample_size,
            "status": "active",
            "created_at": datetime.now().isoformat(),
            "results": {
                "base": {
                    "executions": 0,
                    "successes": 0,
                    "failures": 0,
                    "total_time": 0,
                    "success_rate": 0.0,
                    "avg_time": 0.0,
                },
                "variant": {
                    "executions": 0,
                    "successes": 0,
                    "failures": 0,
                    "total_time": 0,
                    "success_rate": 0.0,
                    "avg_time": 0.0,
                },
            },
        }

        self.experiments["experiments"].append(experiment)
        self._save_experiments()

        user_log(f"[Strategy Evolution] Created experiment {experiment['id']}", level="info", stderr=True)
        return experiment

    def record_ab_result(
        self,
        experiment_id: str,
        variant_type: str,
        success: bool,
        execution_time: float,
    ):
        """
        Record A/B test result

        Args:
            experiment_id: Experiment ID
            variant_type: "base" or "variant"
            success: Whether execution succeeded
            execution_time: Time taken in seconds
        """
        # Find experiment
        experiment = self._find_experiment(experiment_id)
        if not experiment:
            user_log(f"[Strategy Evolution] Experiment {experiment_id} not found", level="error", stderr=True)
            return

        if experiment["status"] != "active":
            user_log(f"[Strategy Evolution] Experiment {experiment_id} is not active", level="warning", stderr=True)
            return

        # Update results
        results = experiment["results"][variant_type]
        results["executions"] += 1
        if success:
            results["successes"] += 1
        else:
            results["failures"] += 1
        results["total_time"] += execution_time

        # Recalculate metrics
        if results["executions"] > 0:
            results["success_rate"] = results["successes"] / results["executions"]
            results["avg_time"] = results["total_time"] / results["executions"]

        # Check if experiment is complete
        base_results = experiment["results"]["base"]
        variant_results = experiment["results"]["variant"]
        sample_size = experiment["sample_size"]

        if (
            base_results["executions"] >= sample_size
            and variant_results["executions"] >= sample_size
        ):
            self._complete_experiment(experiment)

        self._save_experiments()

    def _complete_experiment(self, experiment: Dict):
        """Complete an A/B test experiment and determine winner"""
        user_log(f"[Strategy Evolution] Completing experiment {experiment['id']}...", level="info", stderr=True)

        experiment["status"] = "completed"
        experiment["completed_at"] = datetime.now().isoformat()

        base_results = experiment["results"]["base"]
        variant_results = experiment["results"]["variant"]

        # Calculate improvement
        success_improvement = (
            variant_results["success_rate"] - base_results["success_rate"]
        )
        time_improvement = (
            (base_results["avg_time"] - variant_results["avg_time"])
            / base_results["avg_time"]
            if base_results["avg_time"] > 0
            else 0
        )

        # Determine winner (60% weight on success rate, 40% on time)
        base_score = (
            base_results["success_rate"] * 0.6
            + (1 / (1 + base_results["avg_time"])) * 0.4
        )
        variant_score = (
            variant_results["success_rate"] * 0.6
            + (1 / (1 + variant_results["avg_time"])) * 0.4
        )

        if variant_score > base_score * 1.05:  # 5% improvement threshold
            winner = "variant"
            decision = "adopt"
        elif variant_score < base_score * 0.95:  # 5% worse
            winner = "base"
            decision = "reject"
        else:
            winner = "tie"
            decision = "inconclusive"

        experiment["winner"] = winner
        experiment["decision"] = decision
        experiment["improvement"] = {
            "success_rate": success_improvement,
            "execution_time": time_improvement,
        }

        # Record evolution
        if decision == "adopt":
            self._record_evolution(experiment)

        user_log(f"[Strategy Evolution] Experiment complete: winner={winner}, decision={decision}", level="info", stderr=True)

    def _record_evolution(self, experiment: Dict):
        """Record successful evolution"""
        evolution = {
            "timestamp": datetime.now().isoformat(),
            "experiment_id": experiment["id"],
            "base_strategy": experiment["base_strategy"],
            "variant_strategy": experiment["variant_strategy"],
            "mutations": experiment["variant_definition"]["mutations"],
            "improvement": experiment["improvement"],
            "adopted": True,
        }

        self.evolution_history["evolutions"].append(evolution)
        self.evolution_history["successful_mutations"].append(
            {
                "mutations": experiment["variant_definition"]["mutations"],
                "improvement": experiment["improvement"],
            }
        )

        self._save_evolution()

        user_log(f"[Strategy Evolution] Evolution recorded: {evolution['base_strategy']} -> {evolution['variant_strategy']}", level="info", stderr=True)

    def get_experiment_status(self, experiment_id: str) -> Dict:
        """Get status of an A/B test experiment"""
        experiment = self._find_experiment(experiment_id)
        if not experiment:
            return {"error": "Experiment not found"}

        return {
            "id": experiment["id"],
            "status": experiment["status"],
            "base_strategy": experiment["base_strategy"],
            "variant_strategy": experiment["variant_strategy"],
            "sample_size": experiment["sample_size"],
            "progress": {
                "base": f"{experiment['results']['base']['executions']}/{experiment['sample_size']}",
                "variant": f"{experiment['results']['variant']['executions']}/{experiment['sample_size']}",
            },
            "results": experiment["results"],
            "winner": experiment.get("winner"),
            "decision": experiment.get("decision"),
        }

    def list_active_experiments(self) -> List[Dict]:
        """List all active experiments"""
        return [
            self.get_experiment_status(exp["id"])
            for exp in self.experiments["experiments"]
            if exp["status"] == "active"
        ]

    def get_evolution_history(self) -> Dict:
        """Get evolution history and statistics"""
        evolutions = self.evolution_history.get("evolutions", [])
        successful_mutations = self.evolution_history.get("successful_mutations", [])

        # Count mutation types
        mutation_counts = {}
        for mutation_group in successful_mutations:
            for mutation in mutation_group["mutations"]:
                mut_type = mutation["type"]
                mutation_counts[mut_type] = mutation_counts.get(mut_type, 0) + 1

        return {
            "total_evolutions": len(evolutions),
            "successful_mutations": len(successful_mutations),
            "mutation_type_frequency": mutation_counts,
            "recent_evolutions": evolutions[-10:],  # Last 10
        }

    def _find_strategy(self, strategy_id: str) -> Optional[Dict]:
        """Find strategy by ID"""
        for strategy in self.strategies.get("strategies", []):
            if strategy["id"] == strategy_id:
                return strategy
        return None

    def _find_experiment(self, experiment_id: str) -> Optional[Dict]:
        """Find experiment by ID"""
        for experiment in self.experiments["experiments"]:
            if experiment["id"] == experiment_id:
                return experiment
        return None


def main():
    """Main entry point"""
    if len(sys.argv) < 2:
        user_log("Usage: strategy_evolution.py <command> [args...]", level="error", stderr=True)
        user_log("\nCommands:", level="error", stderr=True)
        user_log("  variant <strategy_id>  - Generate variant for strategy", level="error", stderr=True)
        user_log(
            "  create-test <strategy_id> <context> [sample_size]  - Create A/B test",
            level="error",
            stderr=True,
        )
        user_log(
            "  record <experiment_id> <variant_type> <success> <time>  - Record result",
            level="error",
            stderr=True,
        )
        user_log("  status <experiment_id>  - Get experiment status", level="error", stderr=True)
        user_log("  list  - List active experiments", level="error", stderr=True)
        user_log("  history  - Show evolution history", level="error", stderr=True)
        sys.exit(1)

    command = sys.argv[1]
    evolution = StrategyEvolution()

    if command == "variant":
        if len(sys.argv) < 3:
            user_log("Error: variant requires strategy_id", level="error", stderr=True)
            sys.exit(1)

        strategy_id = sys.argv[2]
        variant = evolution.generate_variant(strategy_id)
        user_log(json.dumps(variant, indent=2) if variant else json.dumps({"error": "Failed"}))

    elif command == "create-test":
        if len(sys.argv) < 4:
            user_log("Error: create-test requires strategy_id and context", level="error", stderr=True)
            sys.exit(1)

        strategy_id = sys.argv[2]
        context = sys.argv[3]
        sample_size = int(sys.argv[4]) if len(sys.argv) > 4 else 20

        experiment = evolution.create_ab_test(strategy_id, context, sample_size)
        user_log(json.dumps(experiment, indent=2))

    elif command == "record":
        if len(sys.argv) < 6:
            user_log(
                "Error: record requires experiment_id, variant_type, success, time",
                level="error",
                stderr=True,
            )
            sys.exit(1)

        experiment_id = sys.argv[2]
        variant_type = sys.argv[3]
        success = sys.argv[4].lower() in ["true", "1", "yes"]
        execution_time = float(sys.argv[5])

        evolution.record_ab_result(experiment_id, variant_type, success, execution_time)
        user_log(json.dumps({"status": "recorded"}))

    elif command == "status":
        if len(sys.argv) < 3:
            user_log("Error: status requires experiment_id", level="error", stderr=True)
            sys.exit(1)

        experiment_id = sys.argv[2]
        status = evolution.get_experiment_status(experiment_id)
        user_log(json.dumps(status, indent=2))

    elif command == "list":
        experiments = evolution.list_active_experiments()
        user_log(json.dumps(experiments, indent=2))

    elif command == "history":
        history = evolution.get_evolution_history()
        user_log(json.dumps(history, indent=2))

    else:
        user_log(f"Error: Unknown command '{command}'", level="error", stderr=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
