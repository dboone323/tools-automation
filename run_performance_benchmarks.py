#!/usr/bin/env python3
"""
Performance Benchmarking Script

Runs comprehensive performance tests against the live MCP server using Locust.
Generates detailed performance reports and validates against benchmarks.
"""

import subprocess
import json
import time
import csv
from pathlib import Path
from datetime import datetime


class PerformanceBenchmarker:
    """Run performance benchmarks against MCP server."""

    def __init__(self, host="http://localhost:5005", results_dir="performance_results"):
        self.host = host
        self.results_dir = Path(results_dir)
        self.results_dir.mkdir(exist_ok=True)
        self.timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    def check_server_availability(self):
        """Check if MCP server is running and available."""
        import requests

        try:
            response = requests.get(f"{self.host}/health", timeout=5)
            # Accept healthy (200), degraded (503), or rate-limited (429) states for testing
            return response.status_code in [200, 503, 429]
        except Exception:
            return False

    def run_load_test(
        self, users=10, spawn_rate=2, duration="1m", test_name="basic_load"
    ):
        """Run a Locust load test."""
        print(
            f"🚀 Running {test_name} test: {users} users @ {spawn_rate}/s for {duration}"
        )

        cmd = [
            "locust",
            "-f",
            "tests/performance/locustfile.py",
            "--host",
            self.host,
            "--no-web",
            "-c",
            str(users),
            "-r",
            str(spawn_rate),
            "--run-time",
            duration,
            "--csv",
            f"{self.results_dir}/{test_name}_{self.timestamp}",
        ]

        result = subprocess.run(
            cmd, capture_output=True, text=True, cwd=Path(__file__).parent.parent
        )

        success = result.returncode == 0
        print(f"{'✅' if success else '❌'} {test_name} test completed")

        return {
            "test_name": test_name,
            "success": success,
            "stdout": result.stdout,
            "stderr": result.stderr,
            "returncode": result.returncode,
            "users": users,
            "spawn_rate": spawn_rate,
            "duration": duration,
        }

    def run_performance_suite(self):
        """Run comprehensive performance test suite."""
        print("🏃 Starting Performance Benchmark Suite")
        print("=" * 50)

        if not self.check_server_availability():
            print("❌ MCP server not available. Please start the server first.")
            return False

        results = []

        # Test scenarios
        scenarios = [
            {"users": 5, "spawn_rate": 1, "duration": "30s", "name": "light_load"},
            {"users": 20, "spawn_rate": 2, "duration": "1m", "name": "medium_load"},
            {"users": 50, "spawn_rate": 5, "duration": "2m", "name": "heavy_load"},
            {"users": 100, "spawn_rate": 10, "duration": "3m", "name": "stress_test"},
        ]

        for scenario in scenarios:
            result = self.run_load_test(
                users=scenario["users"],
                spawn_rate=scenario["spawn_rate"],
                duration=scenario["duration"],
                test_name=scenario["name"],
            )
            results.append(result)

            # Brief pause between tests
            time.sleep(5)

        # Generate comprehensive report
        self.generate_report(results)

        return all(r["success"] for r in results)

    def generate_report(self, results):
        """Generate comprehensive performance report."""
        report_file = self.results_dir / f"performance_report_{self.timestamp}.json"

        # Analyze CSV results if available
        _csv_files = list(self.results_dir.glob(f"*_{self.timestamp}_stats.csv"))

        detailed_results = []
        for result in results:
            test_name = result["test_name"]
            csv_file = self.results_dir / f"{test_name}_{self.timestamp}_stats.csv"

            if csv_file.exists():
                stats = self.analyze_csv_results(csv_file)
                result["stats"] = stats
                detailed_results.append(result)
            else:
                detailed_results.append(result)

        # Calculate benchmarks
        benchmarks = self.calculate_benchmarks(detailed_results)

        report = {
            "timestamp": self.timestamp,
            "host": self.host,
            "test_results": detailed_results,
            "benchmarks": benchmarks,
            "summary": {
                "total_tests": len(results),
                "passed_tests": sum(1 for r in results if r["success"]),
                "failed_tests": sum(1 for r in results if not r["success"]),
                "overall_success": all(r["success"] for r in results),
            },
        }

        with open(report_file, "w") as f:
            json.dump(report, f, indent=2)

        print(f"\n📊 Performance report saved: {report_file}")
        self.print_summary_report(report)

    def analyze_csv_results(self, csv_file):
        """Analyze Locust CSV results."""
        stats = {}

        try:
            with open(csv_file, "r") as f:
                reader = csv.DictReader(f)
                rows = list(reader)

                if rows:
                    # Calculate aggregates
                    total_requests = sum(
                        int(row.get("Total Request Count", 0)) for row in rows
                    )
                    total_failures = sum(
                        int(row.get("Total Failure Count", 0)) for row in rows
                    )
                    avg_response_time = sum(
                        float(row.get("Average Response Time", 0)) for row in rows
                    ) / len(rows)
                    median_response_time = sum(
                        float(row.get("Median Response Time", 0)) for row in rows
                    ) / len(rows)
                    min_response_time = min(
                        float(row.get("Min Response Time", 0)) for row in rows
                    )
                    max_response_time = max(
                        float(row.get("Max Response Time", 0)) for row in rows
                    )

                    stats = {
                        "total_requests": total_requests,
                        "total_failures": total_failures,
                        "success_rate": (
                            ((total_requests - total_failures) / total_requests * 100)
                            if total_requests > 0
                            else 0
                        ),
                        "avg_response_time": avg_response_time,
                        "median_response_time": median_response_time,
                        "min_response_time": min_response_time,
                        "max_response_time": max_response_time,
                        "requests_per_second": total_requests
                        / 60,  # Assuming 1 minute test
                    }

        except Exception as e:
            stats = {"error": str(e)}

        return stats

    def calculate_benchmarks(self, results):
        """Calculate performance benchmarks."""
        benchmarks = {
            "response_time_target": "< 500ms average",
            "success_rate_target": "> 95%",
            "throughput_target": "> 100 requests/minute",
            "actual_results": {},
        }

        for result in results:
            if "stats" in result and result["stats"]:
                stats = result["stats"]
                test_name = result["test_name"]

                benchmarks["actual_results"][test_name] = {
                    "avg_response_time": stats.get("avg_response_time", 0),
                    "success_rate": stats.get("success_rate", 0),
                    "requests_per_minute": stats.get("requests_per_second", 0) * 60,
                    "meets_response_time_target": stats.get("avg_response_time", 999)
                    < 500,
                    "meets_success_rate_target": stats.get("success_rate", 0) > 95,
                    "meets_throughput_target": (
                        stats.get("requests_per_second", 0) * 60
                    )
                    > 100,
                }

        return benchmarks

    def print_summary_report(self, report):
        """Print human-readable summary report."""
        print("\n" + "=" * 60)
        print("PERFORMANCE BENCHMARK REPORT")
        print("=" * 60)

        summary = report["summary"]
        print(f"Total Tests: {summary['total_tests']}")
        print(f"Passed: {summary['passed_tests']}")
        print(f"Failed: {summary['failed_tests']}")
        print(
            f"Overall Success: {'✅ PASSED' if summary['overall_success'] else '❌ FAILED'}"
        )

        if report["benchmarks"]["actual_results"]:
            print("\nBENCHMARK RESULTS:")
            print("-" * 40)

            for test_name, results in report["benchmarks"]["actual_results"].items():
                print(f"\n{test_name.upper()}:")
                print(".2f")
                print(".1f")
                print(".0f")

                targets_met = sum(
                    [
                        results["meets_response_time_target"],
                        results["meets_success_rate_target"],
                        results["meets_throughput_target"],
                    ]
                )

                print(
                    f"  Targets Met: {targets_met}/3 {'✅' if targets_met == 3 else '⚠️'}"
                )

        print(f"\n📁 Detailed results: {self.results_dir}")
        print(f"📊 Full report: performance_report_{self.timestamp}.json")


def main():
    """Main entry point."""
    import argparse

    parser = argparse.ArgumentParser(
        description="Run MCP server performance benchmarks"
    )
    parser.add_argument(
        "--host", default="http://localhost:5005", help="MCP server host"
    )
    parser.add_argument(
        "--results-dir", default="performance_results", help="Results directory"
    )
    parser.add_argument("--quick", action="store_true", help="Run quick test only")

    args = parser.parse_args()

    benchmarker = PerformanceBenchmarker(host=args.host, results_dir=args.results_dir)

    if args.quick:
        # Quick single test
        success = benchmarker.run_load_test(
            users=5, spawn_rate=1, duration="30s", test_name="quick_test"
        )["success"]
    else:
        # Full performance suite
        success = benchmarker.run_performance_suite()

    exit(0 if success else 1)


if __name__ == "__main__":
    main()
