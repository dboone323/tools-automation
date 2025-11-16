#!/usr/bin/env python3
"""
48-Hour Validation Automation System

Sets up continuous automated testing for 48-hour validation cycles.
Includes scheduling, monitoring, and reporting for long-term test stability.
"""

import json
import os
import subprocess
import shlex
import time

try:
    import schedule
except ImportError:
    # Fallback to a dummy scheduling module for environments without 'schedule' installed.
    class _DummyJob:
        def minutes(self):
            return self

        def do(self, fn):
            # don't schedule anything in the dummy implementation
            return None

    class _DummySchedule:
        jobs = []

        def every(self, interval):
            return _DummyJob()

        def run_pending(self):
            return None

    schedule = _DummySchedule()
from pathlib import Path
from datetime import datetime, timedelta
import argparse
import signal
import sys


class ValidationOrchestrator:
    """Orchestrate 48-hour automated validation cycles."""

    def __init__(
        self, config_file="validation_config.json", results_dir="validation_results"
    ):
        self.config_file = Path(config_file)
        self.results_dir = Path(results_dir)
        self.results_dir.mkdir(exist_ok=True)
        self.running = False
        self.cycles_completed = 0
        self.load_config()

    def load_config(self):
        """Load validation configuration."""
        default_config = {
            "cycle_duration_hours": 48,
            "test_suites": [
                {
                    "name": "unit_tests",
                    "command": "pytest tests/unit/ -v --tb=short",
                    "interval_minutes": 30,
                    "timeout_seconds": 300,
                },
                {
                    "name": "integration_tests",
                    "command": "pytest tests/integration/ -v --tb=short",
                    "interval_minutes": 60,
                    "timeout_seconds": 600,
                },
                {
                    "name": "e2e_tests",
                    "command": "pytest tests/e2e/ -v --tb=short",
                    "interval_minutes": 120,
                    "timeout_seconds": 1800,
                },
                {
                    "name": "performance_tests",
                    "command": "python run_performance_benchmarks.py --quick",
                    "interval_minutes": 240,  # Every 4 hours
                    "timeout_seconds": 3600,
                },
            ],
            "health_checks": [
                {
                    "name": "mcp_server_health",
                    "command": "curl -f http://localhost:5005/health",
                    "interval_minutes": 5,
                    "timeout_seconds": 30,
                },
                {
                    "name": "database_connectivity",
                    "command": "python -c \"import sqlite3; sqlite3.connect('agents.db').close()\"",
                    "interval_minutes": 15,
                    "timeout_seconds": 30,
                },
            ],
            "alerts": {
                "email_enabled": False,
                "slack_webhook": None,
                "alert_on_failure": True,
                "alert_on_recovery": True,
            },
            "reporting": {
                "generate_reports": True,
                "report_interval_hours": 6,
                "keep_reports_days": 7,
            },
        }

        if self.config_file.exists():
            try:
                with open(self.config_file, "r") as f:
                    user_config = json.load(f)
                # Merge with defaults
                for key, value in user_config.items():
                    if key in default_config:
                        if isinstance(default_config[key], dict):
                            default_config[key].update(value)
                        else:
                            default_config[key] = value
            except json.JSONDecodeError:
                print("⚠️ Invalid config file, using defaults")

        self.config = default_config

    def save_config(self):
        """Save current configuration."""
        with open(self.config_file, "w") as f:
            json.dump(self.config, f, indent=2)

    def run_test_suite(self, suite_config):
        """Run a specific test suite."""
        name = suite_config["name"]
        command = suite_config["command"]
        timeout = suite_config.get("timeout_seconds", 300)

        print(f"🧪 Running {name} test suite...")

        start_time = datetime.now()

        try:
            # Run the test suite without shell where possible to avoid shell injection
            args = shlex.split(command)
            env_vars = {}
            i = 0
            while i < len(args) and "=" in args[i] and not args[i].startswith("="):
                key, val = args[i].split("=", 1)
                env_vars[key] = val
                i += 1

            if i > 0:
                cmd_list = args[i:]
                env = {**os.environ, **env_vars}
            else:
                cmd_list = args
                env = os.environ

            requires_shell = any(
                c in command for c in ["|", "<", ">", "&&", "||", ";", "$"]
            )

            if requires_shell:
                result = subprocess.run(
                    command,
                    shell=True,
                    capture_output=True,
                    text=True,
                    timeout=timeout,
                    cwd=Path(__file__).parent,
                )
            else:
                result = subprocess.run(
                    cmd_list,
                    capture_output=True,
                    text=True,
                    timeout=timeout,
                    cwd=Path(__file__).parent,
                    env=env,
                )

            success = result.returncode == 0
            duration = (datetime.now() - start_time).total_seconds()

            test_result = {
                "suite_name": name,
                "timestamp": start_time.isoformat(),
                "success": success,
                "returncode": result.returncode,
                "duration_seconds": duration,
                "stdout": (
                    result.stdout[-5000:] if result.stdout else ""
                ),  # Last 5000 chars
                "stderr": result.stderr[-5000:] if result.stderr else "",
                "command": command,
            }

            print(f"{'✅' if success else '❌'} {name} completed in {duration:.1f}s")

            return test_result

        except subprocess.TimeoutExpired:
            print(f"⏰ {name} timed out after {timeout}s")
            return {
                "suite_name": name,
                "timestamp": start_time.isoformat(),
                "success": False,
                "error": "timeout",
                "timeout_seconds": timeout,
                "command": command,
            }
        except Exception as e:
            print(f"💥 {name} failed with error: {e}")
            return {
                "suite_name": name,
                "timestamp": start_time.isoformat(),
                "success": False,
                "error": str(e),
                "command": command,
            }

    def run_health_check(self, check_config):
        """Run a health check."""
        name = check_config["name"]
        command = check_config["command"]
        timeout = check_config.get("timeout_seconds", 30)

        try:
            # Run health check command without a shell if possible
            args = shlex.split(command)
            env_vars = {}
            i = 0
            while i < len(args) and "=" in args[i] and not args[i].startswith("="):
                key, val = args[i].split("=", 1)
                env_vars[key] = val
                i += 1

            if i > 0:
                cmd_list = args[i:]
                env = {**os.environ, **env_vars}
            else:
                cmd_list = args
                env = os.environ

            requires_shell = any(
                c in command for c in ["|", "<", ">", "&&", "||", ";", "$"]
            )

            if requires_shell:
                result = subprocess.run(
                    command,
                    shell=True,
                    capture_output=True,
                    text=True,
                    timeout=timeout,
                    cwd=Path(__file__).parent,
                )
            else:
                result = subprocess.run(
                    cmd_list,
                    capture_output=True,
                    text=True,
                    timeout=timeout,
                    cwd=Path(__file__).parent,
                    env=env,
                )

            success = result.returncode == 0

            return {
                "check_name": name,
                "timestamp": datetime.now().isoformat(),
                "success": success,
                "returncode": result.returncode,
                "stdout": result.stdout.strip(),
                "stderr": result.stderr.strip(),
            }

        except subprocess.TimeoutExpired:
            return {
                "check_name": name,
                "timestamp": datetime.now().isoformat(),
                "success": False,
                "error": "timeout",
            }
        except Exception as e:
            return {
                "check_name": name,
                "timestamp": datetime.now().isoformat(),
                "success": False,
                "error": str(e),
            }

    def send_alert(self, alert_type, message, details=None):
        """Send alert notification."""
        if not self.config["alerts"]["alert_on_failure"] and alert_type == "failure":
            return
        if not self.config["alerts"]["alert_on_recovery"] and alert_type == "recovery":
            return

        alert_message = f"🚨 VALIDATION ALERT: {alert_type.upper()}\n{message}"

        if details:
            alert_message += f"\n\nDetails:\n{json.dumps(details, indent=2)}"

        print(alert_message)

        # Email alert (if configured)
        if self.config["alerts"]["email_enabled"]:
            # TODO: Implement email sending
            pass

        # Slack alert (if configured)
        if self.config["alerts"]["slack_webhook"]:
            # TODO: Implement Slack webhook
            pass

    def generate_report(self):
        """Generate comprehensive validation report."""
        report_file = (
            self.results_dir
            / f"validation_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        )

        # Collect recent results
        recent_results = self.collect_recent_results(hours=24)

        # Calculate statistics
        stats = self.calculate_statistics(recent_results)

        report = {
            "generated_at": datetime.now().isoformat(),
            "cycles_completed": self.cycles_completed,
            "statistics": stats,
            "recent_results": recent_results,
            "configuration": self.config,
            "system_info": {
                "python_version": sys.version,
                "platform": sys.platform,
                "working_directory": str(Path.cwd()),
            },
        }

        with open(report_file, "w") as f:
            json.dump(report, f, indent=2)

        print(f"📊 Validation report generated: {report_file}")

        # Generate summary
        self.print_summary_report(stats)

        return report

    def collect_recent_results(self, hours=24):
        """Collect test results from the last N hours."""
        cutoff_time = datetime.now() - timedelta(hours=hours)

        results = {"test_suites": [], "health_checks": []}

        # Find result files
        for result_file in self.results_dir.glob("*.json"):
            if result_file.name.startswith("test_result_"):
                try:
                    with open(result_file, "r") as f:
                        data = json.load(f)

                    result_time = datetime.fromisoformat(data["timestamp"])
                    if result_time > cutoff_time:
                        results["test_suites"].append(data)
                except Exception:
                    pass

            elif result_file.name.startswith("health_check_"):
                try:
                    with open(result_file, "r") as f:
                        data = json.load(f)

                    result_time = datetime.fromisoformat(data["timestamp"])
                    if result_time > cutoff_time:
                        results["health_checks"].append(data)
                except Exception:
                    pass

        return results

    def calculate_statistics(self, recent_results):
        """Calculate validation statistics."""
        test_suites = recent_results["test_suites"]
        health_checks = recent_results["health_checks"]

        stats = {
            "timeframe_hours": 24,
            "test_suites_run": len(test_suites),
            "health_checks_run": len(health_checks),
            "test_suite_success_rate": 0,
            "health_check_success_rate": 0,
            "average_test_duration": 0,
            "failed_tests": [],
            "failed_checks": [],
        }

        if test_suites:
            successful_tests = sum(1 for t in test_suites if t.get("success", False))
            stats["test_suite_success_rate"] = successful_tests / len(test_suites)

            total_duration = sum(t.get("duration_seconds", 0) for t in test_suites)
            stats["average_test_duration"] = total_duration / len(test_suites)

            stats["failed_tests"] = [
                t for t in test_suites if not t.get("success", False)
            ]

        if health_checks:
            successful_checks = sum(1 for c in health_checks if c.get("success", False))
            stats["health_check_success_rate"] = successful_checks / len(health_checks)

            stats["failed_checks"] = [
                c for c in health_checks if not c.get("success", False)
            ]

        return stats

    def print_summary_report(self, stats):
        """Print human-readable summary."""
        print("\n" + "=" * 60)
        print("VALIDATION SUMMARY REPORT (24h)")
        print("=" * 60)

        print(f"Test Suites Run: {stats['test_suites_run']}")
        print(f"Health Checks Run: {stats['health_checks_run']}")
        # Formatting artifact removed intentionally

        if stats["failed_tests"]:
            print(f"\n❌ Failed Test Suites: {len(stats['failed_tests'])}")
            for test in stats["failed_tests"][-5:]:  # Show last 5 failures
                print(f"  - {test['suite_name']} ({test['timestamp']})")

        if stats["failed_checks"]:
            print(f"\n⚠️ Failed Health Checks: {len(stats['failed_checks'])}")
            for check in stats["failed_checks"][-5:]:  # Show last 5 failures
                print(f"  - {check['check_name']} ({check['timestamp']})")

        overall_health = (
            stats["test_suite_success_rate"] + stats["health_check_success_rate"]
        ) / 2
        health_status = (
            "🟢 GOOD"
            if overall_health > 0.95
            else "🟡 WARNING" if overall_health > 0.8 else "🔴 CRITICAL"
        )
        print(f"\n🏥 Overall Health: {health_status} ({overall_health:.1%})")

    def cleanup_old_results(self):
        """Clean up old result files."""
        keep_days = self.config["reporting"]["keep_reports_days"]
        cutoff_date = datetime.now() - timedelta(days=keep_days)

        cleaned_count = 0
        for result_file in self.results_dir.glob("*.json"):
            try:
                file_date = datetime.fromtimestamp(result_file.stat().st_mtime)
                if file_date < cutoff_date:
                    result_file.unlink()
                    cleaned_count += 1
            except Exception:
                pass

        if cleaned_count > 0:
            print(f"🧹 Cleaned up {cleaned_count} old result files")

    def schedule_tasks(self):
        """Schedule all validation tasks."""
        # Schedule test suites
        for suite in self.config["test_suites"]:
            interval = suite["interval_minutes"]
            schedule.every(interval).minutes.do(
                lambda s=suite: self.run_scheduled_test(s)
            )

        # Schedule health checks
        for check in self.config["health_checks"]:
            interval = check["interval_minutes"]
            schedule.every(interval).minutes.do(
                lambda c=check: self.run_scheduled_health_check(c)
            )

        # Schedule reporting
        report_interval = self.config["reporting"]["report_interval_hours"]
        schedule.every(report_interval).hours.do(self.generate_report)

        # Schedule cleanup
        schedule.every().day.do(self.cleanup_old_results)

    def run_scheduled_test(self, suite_config):
        """Run scheduled test suite and save results."""
        result = self.run_test_suite(suite_config)

        # Save result
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        result_file = (
            self.results_dir / f"test_result_{suite_config['name']}_{timestamp}.json"
        )

        with open(result_file, "w") as f:
            json.dump(result, f, indent=2)

        # Send alert on failure
        if not result["success"]:
            self.send_alert(
                "failure", f"Test suite '{suite_config['name']}' failed", result
            )

        return result

    def run_scheduled_health_check(self, check_config):
        """Run scheduled health check and save results."""
        result = self.run_health_check(check_config)

        # Save result
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        result_file = (
            self.results_dir / f"health_check_{check_config['name']}_{timestamp}.json"
        )

        with open(result_file, "w") as f:
            json.dump(result, f, indent=2)

        # Send alert on failure (only if previously successful)
        if not result["success"]:
            self.send_alert(
                "failure", f"Health check '{check_config['name']}' failed", result
            )

        return result

    def start_validation_cycle(self, duration_hours=None):
        """Start the validation cycle."""
        if duration_hours is None:
            duration_hours = self.config["cycle_duration_hours"]

        print(f"🚀 Starting {duration_hours}-hour validation cycle")
        print("=" * 50)

        self.running = True
        self.cycles_completed += 1
        start_time = datetime.now()
        end_time = start_time + timedelta(hours=duration_hours)

        # Schedule tasks
        self.schedule_tasks()

        # Run initial tests
        print("🏃 Running initial test cycle...")
        for suite in self.config["test_suites"]:
            self.run_scheduled_test(suite)

        for check in self.config["health_checks"]:
            self.run_scheduled_health_check(check)

        # Generate initial report
        self.generate_report()

        # Main loop
        try:
            while self.running and datetime.now() < end_time:
                schedule.run_pending()
                time.sleep(60)  # Check every minute

        except KeyboardInterrupt:
            print("\n⏹️ Validation cycle interrupted by user")

        # Final report
        print("🏁 Generating final validation report...")
        final_report = self.generate_report()

        _elapsed = datetime.now() - start_time
        # Removed formatting artifact
        return final_report

    def stop_validation_cycle(self):
        """Stop the current validation cycle."""
        print("⏹️ Stopping validation cycle...")
        self.running = False

    def get_status(self):
        """Get current validation status."""
        return {
            "running": self.running,
            "cycles_completed": self.cycles_completed,
            "config": self.config,
            "next_scheduled_runs": [
                {
                    "job": str(job),
                    "next_run": (
                        job.next_run.isoformat() if hasattr(job, "next_run") else None
                    ),
                }
                for job in schedule.jobs
            ],
        }


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(description="48-Hour Validation Automation System")
    parser.add_argument(
        "--config", default="validation_config.json", help="Configuration file"
    )
    parser.add_argument(
        "--results-dir", default="validation_results", help="Results directory"
    )
    parser.add_argument(
        "--duration-hours", type=int, help="Validation duration in hours"
    )
    parser.add_argument("--status", action="store_true", help="Show current status")
    parser.add_argument(
        "--generate-config", action="store_true", help="Generate default config file"
    )

    args = parser.parse_args()

    orchestrator = ValidationOrchestrator(
        config_file=args.config, results_dir=args.results_dir
    )

    if args.generate_config:
        orchestrator.save_config()
        print(f"✅ Default configuration saved to {args.config}")
        return

    if args.status:
        status = orchestrator.get_status()
        print(json.dumps(status, indent=2))
        return

    # Handle signals for graceful shutdown
    def signal_handler(signum, frame):
        print("\n⏹️ Received signal, stopping validation cycle...")
        orchestrator.stop_validation_cycle()

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    # Start validation cycle
    try:
        orchestrator.start_validation_cycle(args.duration_hours)
    except Exception as e:
        print(f"💥 Validation cycle failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
