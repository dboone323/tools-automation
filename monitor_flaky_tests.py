#!/usr/bin/env python3
"""
Flaky Test Monitoring and Quarantine System

Automatically detects flaky tests in CI/CD pipelines and quarantines them
for manual review. Integrates with GitHub Actions for continuous monitoring.
"""

import json
import os
import subprocess
import sys
from pathlib import Path
from datetime import datetime, timedelta
from collections import defaultdict, Counter
import argparse


class FlakyTestMonitor:
    """Monitor and quarantine flaky tests in CI/CD."""

    def __init__(
        self, test_results_dir="test_results", quarantine_file="quarantined_tests.json"
    ):
        self.test_results_dir = Path(test_results_dir)
        self.test_results_dir.mkdir(exist_ok=True)
        self.quarantine_file = Path(quarantine_file)
        self.flakiness_threshold = 0.8  # 80% failure rate over recent runs
        self.min_runs = 5  # Minimum runs to consider for flakiness
        self.max_quarantine_days = 30  # Auto-remove from quarantine after 30 days

    def run_tests_and_collect_results(self, test_command="pytest", output_file=None):
        """Run tests and collect results for flakiness analysis."""
        if output_file is None:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_file = self.test_results_dir / f"test_run_{timestamp}.json"

        print(f"🧪 Running tests: {test_command}")

        # Run tests with JSON output
        cmd = (
            f"{test_command} --tb=short --json-report --json-report-file={output_file}"
        )

        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)

        success = result.returncode == 0
        print(
            f"{'✅' if success else '❌'} Test run completed (exit code: {result.returncode})"
        )

        return {
            "success": success,
            "output_file": str(output_file),
            "returncode": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr,
            "timestamp": datetime.now().isoformat(),
        }

    def analyze_test_results(self, results_file):
        """Analyze test results for flakiness patterns."""
        try:
            with open(results_file, "r") as f:
                data = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError) as e:
            print(f"❌ Error reading test results: {e}")
            return {}

        # Extract test outcomes
        test_results = {}
        if "tests" in data:
            for test in data["tests"]:
                test_id = f"{test.get('nodeid', test.get('id', 'unknown'))}"
                outcome = test.get("outcome", "unknown")
                test_results[test_id] = outcome

        return test_results

    def update_flakiness_history(self, current_results):
        """Update historical flakiness data."""
        history_file = self.test_results_dir / "flakiness_history.json"

        # Load existing history
        if history_file.exists():
            try:
                with open(history_file, "r") as f:
                    history = json.load(f)
            except json.JSONDecodeError:
                history = {}
        else:
            history = {}

        # Add current results
        timestamp = datetime.now().isoformat()
        history[timestamp] = current_results

        # Keep only last 50 runs to prevent file from growing too large
        if len(history) > 50:
            sorted_timestamps = sorted(history.keys())
            to_remove = sorted_timestamps[:-50]
            for ts in to_remove:
                del history[ts]

        # Save updated history
        with open(history_file, "w") as f:
            json.dump(history, f, indent=2)

        return history

    def detect_flaky_tests(self, history):
        """Detect flaky tests based on historical data."""
        if len(history) < self.min_runs:
            print(
                f"⚠️ Not enough test runs for flakiness analysis (need {self.min_runs}, have {len(history)})"
            )
            return {}

        flaky_tests = {}

        # Analyze each test across all runs
        all_tests = set()
        for run_results in history.values():
            all_tests.update(run_results.keys())

        for test_id in all_tests:
            outcomes = []
            for run_results in history.values():
                outcome = run_results.get(
                    test_id, "missing"
                )  # Treat missing as failure
                outcomes.append(outcome)

            if len(outcomes) >= self.min_runs:
                failure_rate = outcomes.count("failed") / len(outcomes)
                passed_rate = outcomes.count("passed") / len(outcomes)

                # Consider flaky if high failure rate but some passes
                if failure_rate >= self.flakiness_threshold and passed_rate > 0:
                    flaky_tests[test_id] = {
                        "failure_rate": failure_rate,
                        "passed_rate": passed_rate,
                        "total_runs": len(outcomes),
                        "recent_outcomes": outcomes[-10:],  # Last 10 runs
                        "detected_at": datetime.now().isoformat(),
                    }

        return flaky_tests

    def manage_quarantine(self, flaky_tests):
        """Manage quarantined tests list."""
        # Load existing quarantine
        if self.quarantine_file.exists():
            try:
                with open(self.quarantine_file, "r") as f:
                    quarantine = json.load(f)
            except json.JSONDecodeError:
                quarantine = {}
        else:
            quarantine = {}

        # Add new flaky tests to quarantine
        for test_id, analysis in flaky_tests.items():
            if test_id not in quarantine:
                quarantine[test_id] = {
                    "quarantined_at": datetime.now().isoformat(),
                    "reason": "flaky_test_detected",
                    "analysis": analysis,
                    "status": "active",
                }
                print(f"🚨 Quarantined flaky test: {test_id}")

        # Remove old quarantined tests (auto-expire after max days)
        to_remove = []
        cutoff_date = datetime.now() - timedelta(days=self.max_quarantine_days)

        for test_id, data in quarantine.items():
            quarantined_at = datetime.fromisoformat(data["quarantined_at"])
            if quarantined_at < cutoff_date:
                to_remove.append(test_id)
                print(f"✅ Auto-removed from quarantine (expired): {test_id}")

        for test_id in to_remove:
            del quarantine[test_id]

        # Save updated quarantine
        with open(self.quarantine_file, "w") as f:
            json.dump(quarantine, f, indent=2)

        return quarantine

    def generate_quarantine_pytest_skip(self):
        """Generate pytest skip markers for quarantined tests."""
        if not self.quarantine_file.exists():
            return ""

        try:
            with open(self.quarantine_file, "r") as f:
                quarantine = json.load(f)
        except json.JSONDecodeError:
            return ""

        active_quarantines = [
            test_id
            for test_id, data in quarantine.items()
            if data.get("status") == "active"
        ]

        if not active_quarantines:
            return ""

        # Generate pytest.ini content
        skip_content = "# Auto-generated quarantine markers\n"
        skip_content += "# These tests are skipped due to flakiness\n\n"

        for test_id in active_quarantines:
            skip_content += f"markers =\n    quarantine: marks tests as quarantined due to flakiness\n"
            skip_content += f'addopts =\n    -m "not quarantine"\n'
            break  # Only add once

        # Create conftest.py content for individual test skipping
        conftest_content = """# Auto-generated conftest.py for quarantined tests
import pytest

QUARANTINED_TESTS = {
"""

        for test_id in active_quarantines:
            conftest_content += f'    "{test_id}": "flaky_test",\n'

        conftest_content += """}

def pytest_collection_modifyitems(config, items):
    for item in items:
        test_id = item.nodeid
        if test_id in QUARANTINED_TESTS:
            item.add_marker(pytest.mark.quarantine)
            item.add_marker(pytest.mark.skip(reason=f"Quarantined: {QUARANTINED_TESTS[test_id]}"))
"""

        # Write conftest.py
        conftest_file = Path("conftest.py")
        existing_content = ""
        if conftest_file.exists():
            with open(conftest_file, "r") as f:
                existing_content = f.read()

        # Only update if quarantine content changed
        quarantine_section = (
            "\n# QUARANTINE SECTION - AUTO GENERATED\n"
            + conftest_content
            + "\n# END QUARANTINE SECTION\n"
        )

        if "# QUARANTINE SECTION" not in existing_content:
            with open(conftest_file, "a") as f:
                f.write(quarantine_section)
        else:
            # Replace existing quarantine section
            start_marker = "# QUARANTINE SECTION - AUTO GENERATED"
            end_marker = "# END QUARANTINE SECTION"

            before_section = existing_content.split(start_marker)[0]
            after_section = (
                existing_content.split(end_marker)[1]
                if end_marker in existing_content
                else ""
            )

            new_content = before_section + quarantine_section + after_section

            with open(conftest_file, "w") as f:
                f.write(new_content)

        return conftest_content

    def run_monitoring_cycle(self, test_command="pytest"):
        """Run complete monitoring cycle: test → analyze → quarantine → update."""
        print("🔍 Starting flaky test monitoring cycle")
        print("=" * 50)

        # Step 1: Run tests
        test_result = self.run_tests_and_collect_results(test_command)

        if not test_result["success"]:
            print("⚠️ Test run failed - proceeding with analysis anyway")

        # Step 2: Analyze results
        current_results = self.analyze_test_results(test_result["output_file"])

        # Step 3: Update history
        history = self.update_flakiness_history(current_results)

        # Step 4: Detect flaky tests
        flaky_tests = self.detect_flaky_tests(history)

        if flaky_tests:
            print(f"🚨 Detected {len(flaky_tests)} flaky tests:")
            for test_id, analysis in flaky_tests.items():
                print(".1%")
        else:
            print("✅ No flaky tests detected")

        # Step 5: Manage quarantine
        quarantine = self.manage_quarantine(flaky_tests)

        # Step 6: Update pytest configuration
        self.generate_quarantine_pytest_skip()

        # Generate summary report
        summary = {
            "timestamp": datetime.now().isoformat(),
            "test_run_success": test_result["success"],
            "tests_analyzed": len(current_results),
            "flaky_tests_detected": len(flaky_tests),
            "quarantined_tests": len(
                [t for t in quarantine.values() if t.get("status") == "active"]
            ),
            "flaky_test_details": flaky_tests,
        }

        summary_file = (
            self.test_results_dir
            / f"monitoring_summary_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        )
        with open(summary_file, "w") as f:
            json.dump(summary, f, indent=2)

        print(f"\n📊 Monitoring summary saved: {summary_file}")
        print(f"📁 Quarantine file: {self.quarantine_file}")

        return summary

    def get_quarantine_status(self):
        """Get current quarantine status."""
        if not self.quarantine_file.exists():
            return {"quarantined_tests": 0, "tests": []}

        try:
            with open(self.quarantine_file, "r") as f:
                quarantine = json.load(f)
        except json.JSONDecodeError:
            return {"quarantined_tests": 0, "tests": []}

        active_tests = [
            test_id
            for test_id, data in quarantine.items()
            if data.get("status") == "active"
        ]

        return {
            "quarantined_tests": len(active_tests),
            "tests": active_tests,
            "details": quarantine,
        }


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Flaky test monitoring and quarantine system"
    )
    parser.add_argument("--test-command", default="pytest", help="Test command to run")
    parser.add_argument(
        "--results-dir", default="test_results", help="Test results directory"
    )
    parser.add_argument(
        "--quarantine-file", default="quarantined_tests.json", help="Quarantine file"
    )
    parser.add_argument(
        "--status", action="store_true", help="Show quarantine status only"
    )
    parser.add_argument(
        "--threshold", type=float, default=0.8, help="Flakiness threshold (0-1)"
    )
    parser.add_argument(
        "--min-runs", type=int, default=5, help="Minimum runs for analysis"
    )

    args = parser.parse_args()

    monitor = FlakyTestMonitor(
        test_results_dir=args.results_dir, quarantine_file=args.quarantine_file
    )

    monitor.flakiness_threshold = args.threshold
    monitor.min_runs = args.min_runs

    if args.status:
        status = monitor.get_quarantine_status()
        print(f"Quarantined tests: {status['quarantined_tests']}")
        if status["tests"]:
            print("Tests:")
            for test in status["tests"]:
                print(f"  - {test}")
        else:
            print("No tests currently quarantined")
    else:
        summary = monitor.run_monitoring_cycle(args.test_command)
        print(
            f"\n✅ Monitoring cycle completed. Flaky tests detected: {summary['flaky_tests_detected']}"
        )


if __name__ == "__main__":
    main()
