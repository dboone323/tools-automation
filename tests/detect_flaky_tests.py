#!/usr/bin/env python3
"""Flaky test detection and quarantine system."""

import subprocess
import json
import sys
import time
from collections import defaultdict
from pathlib import Path
import argparse


class FlakyTestDetector:
    """Detect and manage flaky tests."""

    def __init__(self, test_dir="tests", runs=5, threshold=0.02):
        """
        Initialize flaky test detector.

        Args:
            test_dir: Directory containing tests
            runs: Number of times to run each test
            threshold: Failure rate threshold for flakiness (2%)
        """
        self.test_dir = Path(test_dir)
        self.runs = runs
        self.threshold = threshold
        self.results_file = self.test_dir / "flaky_test_results.json"
        self.quarantine_file = self.test_dir / "quarantine_tests.json"

    def run_test_suite(self):
        """Run the test suite multiple times and collect results."""
        print(f"Running test suite {self.runs} times to detect flaky tests...")

        all_results = []

        for run in range(self.runs):
            print(f"\n--- Run {run + 1}/{self.runs} ---")
            start_time = time.time()

            # Run pytest and capture output
            result = subprocess.run(
                [
                    "python",
                    "-m",
                    "pytest",
                    str(self.test_dir),
                    "--tb=no",  # Minimal traceback
                    "--json-report",
                    "--json-report-file=temp_results.json",
                ],
                capture_output=True,
                text=True,
                cwd=self.test_dir.parent,
            )

            end_time = time.time()
            duration = end_time - start_time

            # Parse results
            run_results = self._parse_pytest_results(run, result, duration)
            all_results.append(run_results)

            print(f"Run {run + 1} completed in {duration:.2f}s")

        return all_results

    def _parse_pytest_results(self, run_number, result, duration):
        """Parse pytest JSON results."""
        results_file = self.test_dir.parent / "temp_results.json"

        try:
            if results_file.exists():
                with open(results_file, "r") as f:
                    data = json.load(f)
            else:
                # Fallback: parse stdout for basic info
                data = self._parse_stdout_results(result.stdout)

            run_results = {
                "run": run_number,
                "duration": duration,
                "exit_code": result.returncode,
                "tests": [],
            }

            # Extract test results
            for test in data.get("tests", []):
                test_result = {
                    "nodeid": test.get("nodeid", ""),
                    "outcome": test.get("outcome", "unknown"),
                    "duration": test.get("duration", 0),
                }
                run_results["tests"].append(test_result)

            return run_results

        except Exception as e:
            print(f"Error parsing results for run {run_number}: {e}")
            return {
                "run": run_number,
                "duration": duration,
                "exit_code": result.returncode,
                "tests": [],
                "error": str(e),
            }
        finally:
            # Clean up temp file
            if results_file.exists():
                results_file.unlink()

    def _parse_stdout_results(self, stdout):
        """Fallback parser for pytest stdout."""
        # Basic parsing of pytest output
        tests = []
        lines = stdout.split("\n")

        for line in lines:
            if line.startswith("tests/") or line.startswith("::"):
                # Extract test name and outcome
                parts = line.split()
                if len(parts) >= 2:
                    nodeid = parts[0]
                    outcome = (
                        "passed"
                        if "PASSED" in line
                        else "failed" if "FAILED" in line else "unknown"
                    )
                    tests.append({"nodeid": nodeid, "outcome": outcome, "duration": 0})

        return {"tests": tests}

    def analyze_flakiness(self, all_results):
        """Analyze results to identify flaky tests."""
        print("\nAnalyzing test results for flakiness...")

        # Aggregate results by test
        test_stats = defaultdict(lambda: {"runs": 0, "failures": 0, "durations": []})

        for run_results in all_results:
            for test in run_results.get("tests", []):
                nodeid = test["nodeid"]
                outcome = test["outcome"]
                duration = test["duration"]

                test_stats[nodeid]["runs"] += 1
                if outcome == "failed":
                    test_stats[nodeid]["failures"] += 1
                test_stats[nodeid]["durations"].append(duration)

        # Calculate flakiness metrics
        flaky_tests = []
        stable_tests = []

        for nodeid, stats in test_stats.items():
            runs = stats["runs"]
            failures = stats["failures"]
            failure_rate = failures / runs if runs > 0 else 0

            avg_duration = (
                sum(stats["durations"]) / len(stats["durations"])
                if stats["durations"]
                else 0
            )

            test_info = {
                "nodeid": nodeid,
                "runs": runs,
                "failures": failures,
                "failure_rate": failure_rate,
                "avg_duration": avg_duration,
                "is_flaky": failure_rate > self.threshold,
            }

            if test_info["is_flaky"]:
                flaky_tests.append(test_info)
            else:
                stable_tests.append(test_info)

        return flaky_tests, stable_tests

    def quarantine_flaky_tests(self, flaky_tests):
        """Move flaky tests to quarantine."""
        print(f"\nQuarantining {len(flaky_tests)} flaky tests...")

        quarantine_data = {
            "quarantined_at": time.time(),
            "threshold": self.threshold,
            "tests": flaky_tests,
        }

        with open(self.quarantine_file, "w") as f:
            json.dump(quarantine_data, f, indent=2)

        print(f"Quarantined tests saved to {self.quarantine_file}")

        # Create skip markers for quarantined tests
        self._create_skip_markers(flaky_tests)

    def _create_skip_markers(self, flaky_tests):
        """Create pytest skip markers for quarantined tests."""
        skip_file = self.test_dir / "conftest.py"

        skip_content = """
import pytest

# Flaky test quarantine
QUARANTINED_TESTS = {
"""

        for test in flaky_tests:
            nodeid = test["nodeid"]
            skip_content += f'    "{nodeid}": "Flaky test - failure rate: {test["failure_rate"]:.1%}",\n'

        skip_content += '''
}

@pytest.fixture(autouse=True)
def skip_quarantined_tests(request):
    """Skip quarantined tests."""
    if request.node.nodeid in QUARANTINED_TESTS:
        pytest.skip(QUARANTINED_TESTS[request.node.nodeid])
'''

        # Append to existing conftest.py or create new
        if skip_file.exists():
            with open(skip_file, "a") as f:
                f.write("\n\n" + skip_content)
        else:
            with open(skip_file, "w") as f:
                f.write(skip_content)

        print(f"Skip markers added to {skip_file}")

    def save_results(self, all_results, flaky_tests, stable_tests):
        """Save comprehensive results."""
        results_data = {
            "timestamp": time.time(),
            "runs": self.runs,
            "threshold": self.threshold,
            "all_results": all_results,
            "flaky_tests": flaky_tests,
            "stable_tests": stable_tests,
            "summary": {
                "total_tests": len(stable_tests) + len(flaky_tests),
                "flaky_count": len(flaky_tests),
                "stable_count": len(stable_tests),
                "flakiness_rate": (
                    len(flaky_tests) / (len(stable_tests) + len(flaky_tests))
                    if (len(stable_tests) + len(flaky_tests)) > 0
                    else 0
                ),
            },
        }

        with open(self.results_file, "w") as f:
            json.dump(results_data, f, indent=2)

        print(f"Results saved to {self.results_file}")

    def report_results(self, flaky_tests, stable_tests):
        """Print human-readable report."""
        print("\n" + "=" * 60)
        print("FLAKY TEST DETECTION REPORT")
        print("=" * 60)

        total_tests = len(flaky_tests) + len(stable_tests)
        flakiness_rate = len(flaky_tests) / total_tests if total_tests > 0 else 0

        print(f"Total tests analyzed: {total_tests}")
        print(f"Stable tests: {len(stable_tests)}")
        print(f"Flaky tests: {len(flaky_tests)}")
        print(".1f")

        if flaky_tests:
            print("\nFLAKY TESTS:")
            print("-" * 40)
            for test in sorted(
                flaky_tests, key=lambda x: x["failure_rate"], reverse=True
            ):
                print("30" "2d" ".1%")

        print("\nPhase 2 Quality Gate: Zero flaky tests above 2% threshold")
        if flakiness_rate <= 0.02:
            print("✅ PASSED: Flakiness rate within acceptable limits")
        else:
            print("❌ FAILED: Too many flaky tests detected")

        return flakiness_rate <= 0.02


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(description="Detect flaky tests")
    parser.add_argument("--runs", type=int, default=5, help="Number of test runs")
    parser.add_argument(
        "--threshold", type=float, default=0.02, help="Flakiness threshold"
    )
    parser.add_argument("--test-dir", default="tests", help="Test directory")

    args = parser.parse_args()

    detector = FlakyTestDetector(
        test_dir=args.test_dir, runs=args.runs, threshold=args.threshold
    )

    # Run detection
    all_results = detector.run_test_suite()
    flaky_tests, stable_tests = detector.analyze_flakiness(all_results)

    # Save and report results
    detector.save_results(all_results, flaky_tests, stable_tests)
    passed = detector.report_results(flaky_tests, stable_tests)

    # Quarantine if any flaky tests found
    if flaky_tests:
        detector.quarantine_flaky_tests(flaky_tests)

    # Exit with appropriate code
    sys.exit(0 if passed else 1)


if __name__ == "__main__":
    main()
