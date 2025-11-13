#!/usr/bin/env python3
"""
Performance Regression Detection System
Analyzes metrics against baselines to detect performance regressions and anomalies
"""

import json
import os
import time
import statistics
from datetime import datetime, timedelta
from collections import defaultdict
import numpy as np


class PerformanceRegressionDetector:
    """Detects performance regressions using statistical analysis"""

    def __init__(self, monitoring_dir):
        self.monitoring_dir = monitoring_dir
        self.metrics_dir = os.path.join(monitoring_dir, "metrics")
        self.alerts_dir = os.path.join(monitoring_dir, "alerts")
        self.baselines_file = os.path.join(
            self.metrics_dir, "performance_baseline.json"
        )

        # Configuration
        self.anomaly_sensitivity = 0.95  # Z-score threshold
        self.min_samples = 50
        self.regression_threshold = 0.20  # 20% degradation threshold
        self.improvement_threshold = -0.10  # 10% improvement threshold

        # Ensure directories exist
        os.makedirs(self.metrics_dir, exist_ok=True)
        os.makedirs(self.alerts_dir, exist_ok=True)

    def load_baseline(self):
        """Load performance baseline data"""
        if not os.path.exists(self.baselines_file):
            return None

        try:
            with open(self.baselines_file, "r") as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError) as e:
            print(f"Error loading baseline: {e}")
            return None

    def load_recent_metrics(self, hours=24):
        """Load recent performance metrics"""
        cutoff_time = time.time() - (hours * 3600)
        metrics_files = []

        # Find all performance metric files
        for filename in os.listdir(self.metrics_dir):
            if filename.startswith("performance_metrics_") and filename.endswith(
                ".json"
            ):
                try:
                    timestamp = int(filename.split("_")[2].split(".")[0])
                    if timestamp >= cutoff_time:
                        metrics_files.append((timestamp, filename))
                except (ValueError, IndexError):
                    continue

        # Sort by timestamp
        metrics_files.sort(key=lambda x: x[0])

        # Load metrics data
        metrics_data = []
        for timestamp, filename in metrics_files:
            try:
                filepath = os.path.join(self.metrics_dir, filename)
                with open(filepath, "r") as f:
                    data = json.load(f)
                    data["timestamp"] = timestamp
                    metrics_data.append(data)
            except (json.JSONDecodeError, IOError):
                continue

        return metrics_data

    def calculate_statistics(self, values):
        """Calculate statistical measures for a list of values"""
        if len(values) < 2:
            return {
                "mean": values[0] if values else 0,
                "median": values[0] if values else 0,
                "std_dev": 0,
                "min": min(values) if values else 0,
                "max": max(values) if values else 0,
                "count": len(values),
            }

        return {
            "mean": statistics.mean(values),
            "median": statistics.median(values),
            "std_dev": statistics.stdev(values),
            "min": min(values),
            "max": max(values),
            "count": len(values),
        }

    def detect_anomalies(self, current_value, baseline_stats, metric_name):
        """Detect if current value is anomalous compared to baseline"""
        if not baseline_stats or baseline_stats.get("count", 0) < self.min_samples:
            return None

        mean = baseline_stats.get("mean", 0)
        std_dev = baseline_stats.get("std_dev", 1)

        if std_dev == 0:
            # No variation in baseline, check against mean
            deviation = abs(current_value - mean) / max(abs(mean), 1)
            is_anomaly = deviation > 0.1  # 10% deviation threshold
        else:
            # Calculate z-score
            z_score = abs(current_value - mean) / std_dev
            is_anomaly = z_score > self.anomaly_sensitivity

        if is_anomaly:
            direction = "higher" if current_value > mean else "lower"
            deviation_percent = ((current_value - mean) / max(abs(mean), 1)) * 100

            return {
                "metric": metric_name,
                "current_value": current_value,
                "baseline_mean": mean,
                "baseline_std": std_dev,
                "direction": direction,
                "deviation_percent": deviation_percent,
                "z_score": z_score if std_dev > 0 else 0,
                "severity": "critical" if abs(deviation_percent) > 50 else "warning",
            }

        return None

    def detect_regression(self, current_stats, baseline_stats, metric_name):
        """Detect performance regression"""
        if not baseline_stats or not current_stats:
            return None

        current_mean = current_stats.get("mean", 0)
        baseline_mean = baseline_stats.get("mean", 0)

        if baseline_mean == 0:
            return None

        # Calculate regression ratio
        regression_ratio = (current_mean - baseline_mean) / baseline_mean

        # Check for significant regression
        if regression_ratio > self.regression_threshold:
            return {
                "type": "regression",
                "metric": metric_name,
                "current_mean": current_mean,
                "baseline_mean": baseline_mean,
                "regression_percent": regression_ratio * 100,
                "severity": "critical" if regression_ratio > 0.5 else "warning",
            }

        # Check for significant improvement
        if regression_ratio < self.improvement_threshold:
            return {
                "type": "improvement",
                "metric": metric_name,
                "current_mean": current_mean,
                "baseline_mean": baseline_mean,
                "improvement_percent": abs(regression_ratio) * 100,
                "severity": "info",
            }

        return None

    def analyze_performance(self):
        """Main analysis function"""
        print("🔍 Analyzing performance metrics for regressions and anomalies...")

        # Load baseline
        baseline = self.load_baseline()
        if not baseline:
            print("⚠️  No baseline data available. Run baseline generation first.")
            return []

        # Load recent metrics
        recent_metrics = self.load_recent_metrics(hours=24)
        if not recent_metrics:
            print("⚠️  No recent metrics data available.")
            return []

        # Group metrics by type
        metric_groups = defaultdict(list)

        for metric_data in recent_metrics:
            for key, value in metric_data.items():
                if isinstance(value, (int, float)) and key not in ["timestamp"]:
                    metric_groups[key].append(value)

        # Analyze each metric
        findings = []

        for metric_name, values in metric_groups.items():
            if len(values) < 5:  # Need minimum samples
                continue

            # Calculate current statistics
            current_stats = self.calculate_statistics(values)
            baseline_stats = baseline.get(metric_name)

            if not baseline_stats:
                continue

            # Get latest value for anomaly detection
            latest_value = values[-1]

            # Detect anomalies
            anomaly = self.detect_anomalies(latest_value, baseline_stats, metric_name)
            if anomaly:
                findings.append(
                    {"type": "anomaly", "data": anomaly, "timestamp": int(time.time())}
                )

            # Detect regressions (using recent window vs baseline)
            regression = self.detect_regression(
                current_stats, baseline_stats, metric_name
            )
            if regression:
                findings.append(
                    {
                        "type": "regression",
                        "data": regression,
                        "timestamp": int(time.time()),
                    }
                )

        # Generate alerts for findings
        alerts = []
        for finding in findings:
            alert = self.create_alert(finding)
            if alert:
                alerts.append(alert)

        print(f"✅ Analysis complete. Found {len(findings)} issues.")

        return findings

    def create_alert(self, finding):
        """Create an alert from a finding"""
        finding_type = finding["type"]
        data = finding["data"]
        timestamp = finding["timestamp"]

        if finding_type == "anomaly":
            severity = data["severity"]
            direction = data["direction"]
            deviation = abs(data["deviation_percent"])

            message = f"Performance anomaly detected in {data['metric']}: "
            message += f"{data['current_value']:.2f} ({direction} than baseline by {deviation:.1f}%)"

            if severity == "critical":
                message = f"🚨 CRITICAL: {message}"
            else:
                message = f"⚠️  WARNING: {message}"

        elif finding_type == "regression":
            reg_type = data["type"]
            severity = data["severity"]
            metric = data["metric"]
            percent = (
                data["regression_percent"]
                if reg_type == "regression"
                else data["improvement_percent"]
            )

            if reg_type == "regression":
                message = (
                    f"Performance regression in {metric}: {percent:.1f}% degradation"
                )
                if severity == "critical":
                    message = f"🚨 CRITICAL: {message}"
                else:
                    message = f"⚠️  WARNING: {message}"
            else:
                message = (
                    f"✅ Performance improvement in {metric}: {percent:.1f}% better"
                )

        else:
            return None

        # Create alert file
        alert_data = {
            "timestamp": timestamp,
            "type": finding_type,
            "severity": data.get("severity", "info"),
            "message": message,
            "data": data,
        }

        alert_filename = f"regression_alert_{timestamp}.json"
        alert_path = os.path.join(self.alerts_dir, alert_filename)

        try:
            with open(alert_path, "w") as f:
                json.dump(alert_data, f, indent=2)
            print(f"📝 Alert created: {message}")
            return alert_data
        except IOError as e:
            print(f"Error creating alert: {e}")
            return None

    def generate_regression_report(self):
        """Generate a detailed regression report"""
        print("📊 Generating performance regression report...")

        findings = self.analyze_performance()

        if not findings:
            print("✅ No regressions or anomalies detected.")
            return

        # Group findings by type and severity
        regressions = [f for f in findings if f["type"] == "regression"]
        anomalies = [f for f in findings if f["type"] == "anomaly"]

        report = {
            "generated_at": datetime.now().isoformat(),
            "analysis_period_hours": 24,
            "total_findings": len(findings),
            "regressions": len(regressions),
            "anomalies": len(anomalies),
            "details": findings,
        }

        # Save report
        report_path = os.path.join(
            self.monitoring_dir, "reports", f"regression_report_{int(time.time())}.json"
        )

        try:
            os.makedirs(os.path.dirname(report_path), exist_ok=True)
            with open(report_path, "w") as f:
                json.dump(report, f, indent=2)
            print(f"📄 Regression report saved: {report_path}")
        except IOError as e:
            print(f"Error saving report: {e}")

        return report


def main():
    """Main function"""
    monitoring_dir = os.path.dirname(os.path.abspath(__file__))

    detector = PerformanceRegressionDetector(monitoring_dir)

    import sys

    if len(sys.argv) > 1:
        command = sys.argv[1]

        if command == "analyze":
            findings = detector.analyze_performance()
            print(f"Found {len(findings)} performance issues")
        elif command == "report":
            report = detector.generate_regression_report()
            if report:
                print(f"Report generated with {report['total_findings']} findings")
        else:
            print("Usage: python performance_regression.py [analyze|report]")
    else:
        # Default: run analysis
        detector.analyze_performance()


if __name__ == "__main__":
    main()
