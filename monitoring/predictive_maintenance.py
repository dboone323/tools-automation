#!/usr/bin/env python3
"""
Predictive Maintenance System
Analyzes system trends and predicts potential maintenance needs
"""

import json
import os
import time
import statistics
from datetime import datetime
import numpy as np
from sklearn.linear_model import LinearRegression


class PredictiveMaintenance:
    """Predictive maintenance using trend analysis and machine learning"""

    def __init__(self, monitoring_dir):
        self.monitoring_dir = monitoring_dir
        self.metrics_dir = os.path.join(monitoring_dir, "metrics")
        self.alerts_dir = os.path.join(monitoring_dir, "alerts")
        self.predictions_dir = os.path.join(monitoring_dir, "predictions")

        # Configuration
        self.prediction_window_hours = 168  # 7 days
        self.min_data_points = 100
        self.trend_analysis_window = 24  # hours
        self.failure_prediction_threshold = 0.8  # 80% confidence

        # Maintenance prediction thresholds
        self.maintenance_thresholds = {
            "cpu_usage_percent": 85,
            "memory_usage_percent": 90,
            "disk_usage_percent": 95,
            "response_time_ms": 800,
            "error_rate_percent": 10,
        }

        # Ensure directories exist
        os.makedirs(self.predictions_dir, exist_ok=True)

    def load_historical_data(self, metric_name, hours=168):
        """Load historical data for a specific metric"""
        cutoff_time = time.time() - (hours * 3600)
        data_points = []

        # Find all metric files
        for filename in os.listdir(self.metrics_dir):
            if filename.endswith(".json"):
                try:
                    # Extract timestamp from filename
                    if "system_metrics_" in filename:
                        timestamp = int(filename.split("_")[2].split(".")[0])
                    elif "performance_metrics_" in filename:
                        timestamp = int(filename.split("_")[2].split(".")[0])
                    else:
                        continue

                    if timestamp >= cutoff_time:
                        filepath = os.path.join(self.metrics_dir, filename)
                        with open(filepath, "r") as f:
                            data = json.load(f)

                        if metric_name in data:
                            data_points.append(
                                {"timestamp": timestamp, "value": data[metric_name]}
                            )

                except (ValueError, IndexError, json.JSONDecodeError, IOError):
                    continue

        # Sort by timestamp
        data_points.sort(key=lambda x: x["timestamp"])
        return data_points

    def calculate_trend(self, data_points):
        """Calculate trend using linear regression"""
        if len(data_points) < 10:
            return None

        # Prepare data for regression
        timestamps = np.array([point["timestamp"] for point in data_points]).reshape(
            -1, 1
        )
        values = np.array([point["value"] for point in data_points])

        # Normalize timestamps (relative to first point)
        timestamps_normalized = timestamps - timestamps[0]

        # Fit linear regression
        model = LinearRegression()
        model.fit(timestamps_normalized, values)

        # Calculate trend metrics
        slope = model.coef_[0]
        intercept = model.intercept_
        r_squared = model.score(timestamps_normalized, values)

        # Calculate trend direction and magnitude
        time_span = (timestamps[-1] - timestamps[0]) / 3600  # hours
        total_change = slope * (timestamps[-1] - timestamps[0])[0]
        change_percent = (total_change / values[0]) * 100 if values[0] != 0 else 0

        return {
            "slope": slope,
            "intercept": intercept,
            "r_squared": r_squared,
            "total_change": total_change,
            "change_percent": change_percent,
            "time_span_hours": time_span,
            "direction": (
                "increasing" if slope > 0 else "decreasing" if slope < 0 else "stable"
            ),
            "confidence": r_squared,
        }

    def predict_future_value(self, data_points, hours_ahead=24):
        """Predict future value using trend analysis"""
        if len(data_points) < 10:
            return None

        trend = self.calculate_trend(data_points)
        if not trend:
            return None

        # Use linear extrapolation
        last_timestamp = data_points[-1]["timestamp"]
        future_timestamp = last_timestamp + (hours_ahead * 3600)

        # Calculate predicted value
        time_diff = future_timestamp - data_points[0]["timestamp"]
        predicted_value = trend["intercept"] + (trend["slope"] * time_diff)

        # Calculate confidence interval (simplified)
        residuals = []
        for point in data_points:
            time_diff_point = point["timestamp"] - data_points[0]["timestamp"]
            predicted_point = trend["intercept"] + (trend["slope"] * time_diff_point)
            residuals.append(point["value"] - predicted_point)

        std_residual = statistics.stdev(residuals) if len(residuals) > 1 else 0

        # Prediction interval (simplified)
        margin = 1.96 * std_residual  # 95% confidence interval

        return {
            "predicted_value": max(0, predicted_value),  # Ensure non-negative
            "upper_bound": max(0, predicted_value + margin),
            "lower_bound": max(0, predicted_value - margin),
            "confidence": trend["r_squared"],
            "hours_ahead": hours_ahead,
            "based_on_points": len(data_points),
        }

    def analyze_maintenance_needs(self):
        """Analyze all metrics for maintenance predictions"""
        print("🔮 Analyzing system for predictive maintenance needs...")

        metrics_to_analyze = [
            "cpu_usage_percent",
            "memory_usage_percent",
            "disk_usage_percent",
            "response_time_ms",
            "error_rate_percent",
            "throughput_rps",
        ]

        maintenance_predictions = []

        for metric_name in metrics_to_analyze:
            try:
                # Load historical data
                data_points = self.load_historical_data(
                    metric_name, self.prediction_window_hours
                )

                if len(data_points) < self.min_data_points:
                    print(
                        f"⚠️  Insufficient data for {metric_name} ({len(data_points)} points)"
                    )
                    continue

                # Calculate current trend
                trend = self.calculate_trend(data_points)

                if not trend:
                    continue

                # Predict future values
                prediction_24h = self.predict_future_value(data_points, 24)
                prediction_168h = self.predict_future_value(data_points, 168)  # 7 days

                # Analyze maintenance needs
                maintenance_need = self.assess_maintenance_need(
                    metric_name, trend, prediction_24h, prediction_168h
                )

                if maintenance_need:
                    maintenance_predictions.append(
                        {
                            "metric": metric_name,
                            "trend": trend,
                            "prediction_24h": prediction_24h,
                            "prediction_168h": prediction_168h,
                            "maintenance_need": maintenance_need,
                            "analyzed_at": int(time.time()),
                        }
                    )

                    print(
                        f"🔧 Maintenance prediction for {metric_name}: {maintenance_need['recommendation']}"
                    )

            except Exception as e:
                print(f"Error analyzing {metric_name}: {e}")
                continue

        # Generate maintenance report
        self.generate_maintenance_report(maintenance_predictions)

        return maintenance_predictions

    def assess_maintenance_need(self, metric_name, trend, pred_24h, pred_168h):
        """Assess if maintenance is needed based on predictions"""
        threshold = self.maintenance_thresholds.get(metric_name)

        if not threshold:
            return None

        maintenance_needed = False
        urgency = "low"
        reasons = []

        # Check trend direction
        if trend["direction"] == "increasing":
            if metric_name in [
                "cpu_usage_percent",
                "memory_usage_percent",
                "disk_usage_percent",
                "response_time_ms",
                "error_rate_percent",
            ]:
                maintenance_needed = True
                reasons.append(
                    f"Increasing trend ({trend['change_percent']:.1f}% over {trend['time_span_hours']:.1f}h)"
                )

        # Check 24-hour prediction
        if pred_24h and pred_24h["predicted_value"] > threshold:
            maintenance_needed = True
            urgency = "medium"
            exceed_percent = (
                (pred_24h["predicted_value"] - threshold) / threshold
            ) * 100
            reasons.append(f"24h prediction exceeds threshold by {exceed_percent:.1f}%")

        # Check 7-day prediction
        if pred_168h and pred_168h["predicted_value"] > threshold:
            maintenance_needed = True
            urgency = "high"
            exceed_percent = (
                (pred_168h["predicted_value"] - threshold) / threshold
            ) * 100
            reasons.append(
                f"7-day prediction exceeds threshold by {exceed_percent:.1f}%"
            )

        # Check confidence
        if trend["confidence"] < 0.7:
            reasons.append("Low confidence in trend analysis")

        if not maintenance_needed:
            return None

        # Generate recommendation
        recommendation = self.generate_recommendation(metric_name, urgency, reasons)

        return {
            "needed": True,
            "urgency": urgency,
            "reasons": reasons,
            "recommendation": recommendation,
            "predicted_exceedance": pred_168h["predicted_value"] if pred_168h else None,
            "confidence": trend["confidence"],
        }

    def generate_recommendation(self, metric_name, urgency, reasons):
        """Generate maintenance recommendation based on metric and urgency"""
        base_recommendations = {
            "cpu_usage_percent": [
                "Optimize CPU-intensive processes",
                "Consider scaling compute resources",
                "Review application performance bottlenecks",
            ],
            "memory_usage_percent": [
                "Optimize memory usage in applications",
                "Consider increasing memory allocation",
                "Check for memory leaks",
            ],
            "disk_usage_percent": [
                "Clean up unnecessary files and logs",
                "Implement log rotation policies",
                "Consider increasing disk space",
            ],
            "response_time_ms": [
                "Optimize database queries",
                "Implement caching strategies",
                "Review network latency issues",
            ],
            "error_rate_percent": [
                "Investigate error sources",
                "Implement better error handling",
                "Review application stability",
            ],
            "throughput_rps": [
                "This is a throughput metric - monitor for capacity planning"
            ],
        }

        recommendations = base_recommendations.get(
            metric_name, ["Review system configuration"]
        )

        urgency_prefix = {
            "high": "🚨 URGENT: ",
            "medium": "⚠️  SCHEDULED: ",
            "low": "📅 PLANNED: ",
        }

        return urgency_prefix.get(urgency, "") + recommendations[0]

    def generate_maintenance_report(self, predictions):
        """Generate comprehensive maintenance report"""
        print("📋 Generating predictive maintenance report...")

        report = {
            "generated_at": datetime.now().isoformat(),
            "analysis_period_hours": self.prediction_window_hours,
            "total_predictions": len(predictions),
            "urgent_maintenance": len(
                [p for p in predictions if p["maintenance_need"]["urgency"] == "high"]
            ),
            "scheduled_maintenance": len(
                [p for p in predictions if p["maintenance_need"]["urgency"] == "medium"]
            ),
            "planned_maintenance": len(
                [p for p in predictions if p["maintenance_need"]["urgency"] == "low"]
            ),
            "predictions": predictions,
        }

        # Group by urgency
        urgent = [p for p in predictions if p["maintenance_need"]["urgency"] == "high"]
        scheduled = [
            p for p in predictions if p["maintenance_need"]["urgency"] == "medium"
        ]
        planned = [p for p in predictions if p["maintenance_need"]["urgency"] == "low"]

        # Create detailed markdown report
        markdown_report = f"""# Predictive Maintenance Report

**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
**Analysis Period:** {self.prediction_window_hours} hours

## Summary

- **Total Predictions:** {len(predictions)}
- **Urgent Maintenance:** {len(urgent)}
- **Scheduled Maintenance:** {len(scheduled)}
- **Planned Maintenance:** {len(planned)}

## Urgent Maintenance Required

"""

        for pred in urgent:
            markdown_report += f"""
### {pred['metric'].replace('_', ' ').title()}

**Recommendation:** {pred['maintenance_need']['recommendation']}
**Reasons:**
"""
            for reason in pred["maintenance_need"]["reasons"]:
                markdown_report += f"- {reason}\n"

            if pred["prediction_168h"]:
                markdown_report += f"""
**7-Day Prediction:** {pred['prediction_168h']['predicted_value']:.2f}
**Confidence:** {pred['trend']['confidence']:.2%}
"""

        markdown_report += "\n## Scheduled Maintenance\n\n"

        for pred in scheduled:
            markdown_report += f"""
### {pred['metric'].replace('_', ' ').title()}

**Recommendation:** {pred['maintenance_need']['recommendation']}
**Reasons:**
"""
            for reason in pred["maintenance_need"]["reasons"]:
                markdown_report += f"- {reason}\n"

        markdown_report += "\n## Planned Maintenance\n\n"

        for pred in planned:
            markdown_report += f"""
### {pred['metric'].replace('_', ' ').title()}

**Recommendation:** {pred['maintenance_need']['recommendation']}
**Reasons:**
"""
            for reason in pred["maintenance_need"]["reasons"]:
                markdown_report += f"- {reason}\n"

        # Save reports
        timestamp = int(time.time())

        # JSON report
        json_path = os.path.join(
            self.predictions_dir, f"maintenance_report_{timestamp}.json"
        )
        with open(json_path, "w") as f:
            json.dump(report, f, indent=2)

        # Markdown report
        md_path = os.path.join(
            self.monitoring_dir, "reports", f"maintenance_report_{timestamp}.md"
        )
        os.makedirs(os.path.dirname(md_path), exist_ok=True)
        with open(md_path, "w") as f:
            f.write(markdown_report)

        print(f"📄 Maintenance report saved: {md_path}")

        # Create alerts for urgent maintenance
        for pred in urgent:
            self.create_maintenance_alert(pred)

        return report

    def create_maintenance_alert(self, prediction):
        """Create an alert for urgent maintenance needs"""
        alert_data = {
            "timestamp": int(time.time()),
            "type": "predictive_maintenance",
            "severity": (
                "critical"
                if prediction["maintenance_need"]["urgency"] == "high"
                else "warning"
            ),
            "message": prediction["maintenance_need"]["recommendation"],
            "metric": prediction["metric"],
            "urgency": prediction["maintenance_need"]["urgency"],
            "reasons": prediction["maintenance_need"]["reasons"],
            "prediction_data": {
                "trend": prediction["trend"],
                "prediction_24h": prediction["prediction_24h"],
                "prediction_168h": prediction["prediction_168h"],
            },
        }

        alert_filename = f"maintenance_alert_{int(time.time())}.json"
        alert_path = os.path.join(self.alerts_dir, alert_filename)

        try:
            with open(alert_path, "w") as f:
                json.dump(alert_data, f, indent=2)
            print(f"🚨 Maintenance alert created for {prediction['metric']}")
        except IOError as e:
            print(f"Error creating maintenance alert: {e}")


def main():
    """Main function"""
    monitoring_dir = os.path.dirname(os.path.abspath(__file__))

    predictor = PredictiveMaintenance(monitoring_dir)

    import sys

    if len(sys.argv) > 1:
        command = sys.argv[1]

        if command == "analyze":
            predictions = predictor.analyze_maintenance_needs()
            print(f"Generated {len(predictions)} maintenance predictions")
        elif command == "report":
            report = predictor.generate_maintenance_report([])
            print("Maintenance report generated")
        else:
            print("Usage: python predictive_maintenance.py [analyze|report]")
    else:
        # Default: run analysis
        predictor.analyze_maintenance_needs()


if __name__ == "__main__":
    main()
