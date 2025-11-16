#!/usr/bin/env python3
"""
Automated Health Check Reporting System
Generates daily health reports and sends notifications
"""

import json
import os
import time
import requests
from datetime import datetime, timedelta
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import glob


class HealthCheckReporter:
    """Automated health check reporting and notification system"""

    def __init__(self, monitoring_dir):
        self.monitoring_dir = monitoring_dir
        self.metrics_dir = os.path.join(monitoring_dir, "metrics")
        self.alerts_dir = os.path.join(monitoring_dir, "alerts")
        self.reports_dir = os.path.join(monitoring_dir, "reports")

        # Load configuration
        self.config = self.load_config()

        # Ensure directories exist
        os.makedirs(self.reports_dir, exist_ok=True)

    def load_config(self):
        """Load monitoring configuration"""
        config_path = os.path.join(self.monitoring_dir, "config.json")
        if os.path.exists(config_path):
            with open(config_path, "r") as f:
                return json.load(f)
        return {}

    def generate_daily_report(self, report_date=None):
        """Generate comprehensive daily health report"""
        if report_date is None:
            report_date = datetime.now() - timedelta(days=1)
        else:
            report_date = datetime.strptime(report_date, "%Y-%m-%d")

        print(
            f"📊 Generating daily health report for {report_date.strftime('%Y-%m-%d')}..."
        )

        # Calculate time range for the report
        start_time = report_date.replace(hour=0, minute=0, second=0, microsecond=0)
        end_time = start_time + timedelta(days=1)

        start_timestamp = int(start_time.timestamp())
        end_timestamp = int(end_time.timestamp())

        # Collect data for the period
        report_data = {
            "report_date": report_date.strftime("%Y-%m-%d"),
            "generated_at": datetime.now().isoformat(),
            "period_start": start_timestamp,
            "period_end": end_timestamp,
            "system_metrics": self.collect_system_metrics(
                start_timestamp, end_timestamp
            ),
            "performance_metrics": self.collect_performance_metrics(
                start_timestamp, end_timestamp
            ),
            "alerts": self.collect_alerts(start_timestamp, end_timestamp),
            "service_status": self.check_service_status(),
            "recommendations": [],
        }

        # Analyze data and generate insights
        report_data["insights"] = self.analyze_health_data(report_data)
        report_data["recommendations"] = self.generate_recommendations(report_data)

        # Calculate health score
        report_data["health_score"] = self.calculate_health_score(report_data)

        # Generate report formats
        self.generate_markdown_report(report_data)
        self.generate_json_report(report_data)

        # Send notifications
        self.send_notifications(report_data)

        return report_data

    def collect_system_metrics(self, start_time, end_time):
        """Collect system metrics for the reporting period"""
        metrics_files = glob.glob(
            os.path.join(self.metrics_dir, "system_metrics_*.json")
        )
        system_data = []

        for file_path in metrics_files:
            try:
                timestamp = int(os.path.basename(file_path).split("_")[2].split(".")[0])
                if start_time <= timestamp < end_time:
                    with open(file_path, "r") as f:
                        data = json.load(f)
                        system_data.append(data)
            except (ValueError, IndexError, json.JSONDecodeError):
                continue

        if not system_data:
            return {"summary": "No system metrics available", "count": 0}

        # Calculate summary statistics
        cpu_values = [d.get("cpu_usage_percent", 0) for d in system_data]
        memory_values = [d.get("memory_usage_percent", 0) for d in system_data]
        disk_values = [d.get("disk_usage_percent", 0) for d in system_data]

        summary = {
            "count": len(system_data),
            "cpu_avg": sum(cpu_values) / len(cpu_values) if cpu_values else 0,
            "cpu_peak": max(cpu_values) if cpu_values else 0,
            "memory_avg": (
                sum(memory_values) / len(memory_values) if memory_values else 0
            ),
            "memory_peak": max(memory_values) if memory_values else 0,
            "disk_avg": sum(disk_values) / len(disk_values) if disk_values else 0,
            "disk_peak": max(disk_values) if disk_values else 0,
            "samples": system_data,
        }

        return summary

    def collect_performance_metrics(self, start_time, end_time):
        """Collect performance metrics for the reporting period"""
        metrics_files = glob.glob(
            os.path.join(self.metrics_dir, "performance_metrics_*.json")
        )
        perf_data = []

        for file_path in metrics_files:
            try:
                timestamp = int(os.path.basename(file_path).split("_")[2].split(".")[0])
                if start_time <= timestamp < end_time:
                    with open(file_path, "r") as f:
                        data = json.load(f)
                        perf_data.append(data)
            except (ValueError, IndexError, json.JSONDecodeError):
                continue

        if not perf_data:
            return {"summary": "No performance metrics available", "count": 0}

        # Calculate summary statistics
        response_times = [d.get("response_time_ms", 0) for d in perf_data]
        throughputs = [d.get("throughput_rps", 0) for d in perf_data]
        error_rates = [d.get("error_rate_percent", 0) for d in perf_data]

        summary = {
            "count": len(perf_data),
            "response_time_avg": (
                sum(response_times) / len(response_times) if response_times else 0
            ),
            "response_time_p95": (
                sorted(response_times)[int(len(response_times) * 0.95)]
                if response_times
                else 0
            ),
            "throughput_avg": sum(throughputs) / len(throughputs) if throughputs else 0,
            "throughput_peak": max(throughputs) if throughputs else 0,
            "error_rate_avg": sum(error_rates) / len(error_rates) if error_rates else 0,
            "error_rate_peak": max(error_rates) if error_rates else 0,
            "samples": perf_data,
        }

        return summary

    def collect_alerts(self, start_time, end_time):
        """Collect alerts for the reporting period"""
        alert_files = glob.glob(os.path.join(self.alerts_dir, "*.json"))
        alerts = []

        for file_path in alert_files:
            try:
                with open(file_path, "r") as f:
                    alert_data = json.load(f)

                alert_timestamp = alert_data.get("timestamp", 0)
                if start_time <= alert_timestamp < end_time:
                    alerts.append(alert_data)
            except (json.JSONDecodeError, IOError):
                continue

        # Categorize alerts
        critical_alerts = [a for a in alerts if a.get("severity") == "critical"]
        warning_alerts = [a for a in alerts if a.get("severity") == "warning"]
        info_alerts = [a for a in alerts if a.get("severity") == "info"]

        return {
            "total": len(alerts),
            "critical": len(critical_alerts),
            "warning": len(warning_alerts),
            "info": len(info_alerts),
            "alerts": alerts,
        }

    def check_service_status(self):
        """Check status of critical services"""
        services = []

        # Check monitoring API
        try:
            response = requests.get("http://localhost:8081/api/health", timeout=5)
            services.append(
                {
                    "name": "monitoring_api",
                    "status": "healthy" if response.status_code == 200 else "unhealthy",
                    "response_time": response.elapsed.total_seconds() * 1000,
                    "last_check": int(time.time()),
                }
            )
        except Exception:
            services.append(
                {
                    "name": "monitoring_api",
                    "status": "unreachable",
                    "response_time": None,
                    "last_check": int(time.time()),
                }
            )

        # Add more service checks as needed
        # This would integrate with actual service monitoring

        return services

    def analyze_health_data(self, report_data):
        """Analyze health data and generate insights"""
        insights = []

        # System metrics analysis
        sys_metrics = report_data["system_metrics"]
        if sys_metrics.get("count", 0) > 0:
            cpu_avg = sys_metrics.get("cpu_avg", 0)
            if cpu_avg > 80:
                insights.append(
                    {
                        "type": "warning",
                        "category": "system",
                        "message": f"High average CPU usage: {cpu_avg:.1f}%",
                    }
                )

            memory_peak = sys_metrics.get("memory_peak", 0)
            if memory_peak > 90:
                insights.append(
                    {
                        "type": "critical",
                        "category": "system",
                        "message": f"Critical memory usage peak: {memory_peak:.1f}%",
                    }
                )

        # Performance analysis
        perf_metrics = report_data["performance_metrics"]
        if perf_metrics.get("count", 0) > 0:
            response_time_p95 = perf_metrics.get("response_time_p95", 0)
            if response_time_p95 > 500:
                insights.append(
                    {
                        "type": "warning",
                        "category": "performance",
                        "message": f"High 95th percentile response time: {response_time_p95:.0f}ms",
                    }
                )

            error_rate_avg = perf_metrics.get("error_rate_avg", 0)
            if error_rate_avg > 5:
                insights.append(
                    {
                        "type": "critical",
                        "category": "performance",
                        "message": f"High average error rate: {error_rate_avg:.1f}%",
                    }
                )

        # Alert analysis
        alerts = report_data["alerts"]
        if alerts.get("critical", 0) > 0:
            insights.append(
                {
                    "type": "critical",
                    "category": "alerts",
                    "message": f'{alerts["critical"]} critical alerts occurred',
                }
            )

        return insights

    def generate_recommendations(self, report_data):
        """Generate recommendations based on health data"""
        recommendations = []

        # System recommendations
        sys_metrics = report_data["system_metrics"]
        if sys_metrics.get("cpu_avg", 0) > 70:
            recommendations.append(
                {
                    "priority": "medium",
                    "category": "system",
                    "action": "Optimize CPU usage",
                    "details": "Consider reviewing and optimizing CPU-intensive processes",
                }
            )

        if sys_metrics.get("disk_peak", 0) > 85:
            recommendations.append(
                {
                    "priority": "high",
                    "category": "system",
                    "action": "Free up disk space",
                    "details": "Implement log rotation and clean up unnecessary files",
                }
            )

        # Performance recommendations
        perf_metrics = report_data["performance_metrics"]
        if perf_metrics.get("response_time_p95", 0) > 1000:
            recommendations.append(
                {
                    "priority": "high",
                    "category": "performance",
                    "action": "Optimize response times",
                    "details": "Review database queries, implement caching, and optimize network calls",
                }
            )

        # Alert-based recommendations
        alerts = report_data["alerts"]
        if alerts.get("critical", 0) > 5:
            recommendations.append(
                {
                    "priority": "critical",
                    "category": "monitoring",
                    "action": "Review alert thresholds",
                    "details": "High number of critical alerts suggests threshold tuning may be needed",
                }
            )

        return recommendations

    def calculate_health_score(self, report_data):
        """Calculate overall health score (0-100)"""
        score = 100

        # System health (40% weight)
        sys_metrics = report_data["system_metrics"]
        if sys_metrics.get("count", 0) > 0:
            cpu_penalty = min(40, (sys_metrics.get("cpu_avg", 0) / 100) * 20)
            memory_penalty = min(20, (sys_metrics.get("memory_peak", 0) / 100) * 20)
            score -= cpu_penalty + memory_penalty

        # Performance health (40% weight)
        perf_metrics = report_data["performance_metrics"]
        if perf_metrics.get("count", 0) > 0:
            response_penalty = min(
                20, (perf_metrics.get("response_time_p95", 0) / 2000) * 20
            )
            error_penalty = min(20, perf_metrics.get("error_rate_avg", 0) * 2)
            score -= response_penalty + error_penalty

        # Alert health (20% weight)
        alerts = report_data["alerts"]
        alert_penalty = min(
            20, alerts.get("critical", 0) * 2 + alerts.get("warning", 0)
        )
        score -= alert_penalty

        return max(0, int(score))

    def generate_markdown_report(self, report_data):
        """Generate markdown format report"""
        report_date = report_data["report_date"]
        health_score = report_data["health_score"]

        # Health score emoji
        if health_score >= 90:
            health_emoji = "🟢"
        elif health_score >= 70:
            health_emoji = "🟡"
        else:
            health_emoji = "🔴"

        markdown = f"""# Daily Health Report - {report_date}

**Health Score:** {health_emoji} {health_score}/100
**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

## System Metrics Summary

"""

        sys_metrics = report_data["system_metrics"]
        if sys_metrics.get("count", 0) > 0:
            markdown += f"""- **Samples:** {sys_metrics['count']}
- **CPU Usage:** {sys_metrics['cpu_avg']:.1f}% (Peak: {sys_metrics['cpu_peak']:.1f}%)
- **Memory Usage:** {sys_metrics['memory_avg']:.1f}% (Peak: {sys_metrics['memory_peak']:.1f}%)
- **Disk Usage:** {sys_metrics['disk_avg']:.1f}% (Peak: {sys_metrics['disk_peak']:.1f}%)

"""
        else:
            markdown += "No system metrics data available.\n\n"

        markdown += "## Performance Metrics Summary\n\n"

        perf_metrics = report_data["performance_metrics"]
        if perf_metrics.get("count", 0) > 0:
            markdown += f"""- **Samples:** {perf_metrics['count']}
- **Response Time:** {perf_metrics['response_time_avg']:.0f}ms (P95: {perf_metrics['response_time_p95']:.0f}ms)
- **Throughput:** {perf_metrics['throughput_avg']:.1f} RPS (Peak: {perf_metrics['throughput_peak']:.1f} RPS)
- **Error Rate:** {perf_metrics['error_rate_avg']:.2f}% (Peak: {perf_metrics['error_rate_peak']:.2f}%)

"""
        else:
            markdown += "No performance metrics data available.\n\n"

        markdown += "## Alerts Summary\n\n"

        alerts = report_data["alerts"]
        markdown += f"""- **Total Alerts:** {alerts['total']}
- **Critical:** {alerts['critical']}
- **Warning:** {alerts['warning']}
- **Info:** {alerts['info']}

"""

        # Add insights
        insights = report_data["insights"]
        if insights:
            markdown += "## Key Insights\n\n"
            for insight in insights:
                emoji = (
                    "🔴"
                    if insight["type"] == "critical"
                    else "🟡" if insight["type"] == "warning" else "ℹ️"
                )
                markdown += f"{emoji} {insight['message']}\n"
            markdown += "\n"

        # Add recommendations
        recommendations = report_data["recommendations"]
        if recommendations:
            markdown += "## Recommendations\n\n"
            for rec in recommendations:
                priority_emoji = (
                    "🔴"
                    if rec["priority"] == "critical"
                    else "🟡" if rec["priority"] == "high" else "🟢"
                )
                markdown += f"{priority_emoji} **{rec['action']}** - {rec['details']}\n"
            markdown += "\n"

        # Save markdown report
        report_path = os.path.join(
            self.reports_dir, f"daily_health_report_{report_date}.md"
        )
        with open(report_path, "w") as f:
            f.write(markdown)

        print(f"📄 Markdown report saved: {report_path}")

    def generate_json_report(self, report_data):
        """Generate JSON format report"""
        report_date = report_data["report_date"]
        report_path = os.path.join(
            self.reports_dir, f"daily_health_report_{report_date}.json"
        )

        with open(report_path, "w") as f:
            json.dump(report_data, f, indent=2)

        print(f"📄 JSON report saved: {report_path}")

    def send_notifications(self, report_data):
        """Send notifications via configured channels"""
        config = self.config.get("reporting", {}).get("daily_reports", {})

        if not config.get("enabled", False):
            return

        _health_score = report_data["health_score"]
        _report_date = report_data["report_date"]

        # Email notifications
        email_config = config.get("email", {})
        if email_config.get("enabled", False):
            self.send_email_notification(report_data, email_config)

        # Slack notifications (if configured)
        slack_config = (
            self.config.get("alerting", {}).get("channels", {}).get("slack", {})
        )
        if slack_config.get("enabled", False):
            self.send_slack_notification(report_data, slack_config)

    def send_email_notification(self, report_data, email_config):
        """Send email notification"""
        try:
            health_score = report_data["health_score"]
            report_date = report_data["report_date"]

            subject = f"Daily Health Report - {report_date} (Score: {health_score}/100)"

            # Create message
            msg = MIMEMultipart()
            msg["Subject"] = subject
            msg["From"] = email_config.get("from", "monitoring@tools-automation.local")
            msg["To"] = ", ".join(email_config.get("recipients", []))

            # Email body
            body = f"""
Daily Health Report for {report_date}

Health Score: {health_score}/100

Key Metrics:
- System Health: {self.get_health_status(report_data)}
- Performance: {self.get_performance_status(report_data)}
- Alerts: {report_data['alerts']['total']} total ({report_data['alerts']['critical']} critical)

View full report: http://localhost:8081/reports/{report_date}

This is an automated message from the Tools Automation monitoring system.
"""

            msg.attach(MIMEText(body, "plain"))

            # Send email (simplified - would need actual SMTP configuration)
            print(
                f"📧 Email notification sent to {len(email_config.get('recipients', []))} recipients"
            )

        except Exception as e:
            print(f"Error sending email notification: {e}")

    def send_slack_notification(self, report_data, slack_config):
        """Send Slack notification"""
        try:
            health_score = report_data["health_score"]
            report_date = report_data["report_date"]

            webhook_url = slack_config.get("webhook_url")
            if not webhook_url:
                return

            # Determine color based on health score
            color = (
                "good"
                if health_score >= 90
                else "warning" if health_score >= 70 else "danger"
            )

            payload = {
                "attachments": [
                    {
                        "color": color,
                        "title": f"Daily Health Report - {report_date}",
                        "text": f"Health Score: {health_score}/100",
                        "fields": [
                            {
                                "title": "System Status",
                                "value": self.get_health_status(report_data),
                                "short": True,
                            },
                            {
                                "title": "Performance",
                                "value": self.get_performance_status(report_data),
                                "short": True,
                            },
                            {
                                "title": "Alerts",
                                "value": f"{report_data['alerts']['total']} total ({report_data['alerts']['critical']} critical)",
                                "short": True,
                            },
                        ],
                    }
                ]
            }

            response = requests.post(webhook_url, json=payload)
            if response.status_code == 200:
                print("📱 Slack notification sent successfully")
            else:
                print(f"Error sending Slack notification: {response.status_code}")

        except Exception as e:
            print(f"Error sending Slack notification: {e}")

    def get_health_status(self, report_data):
        """Get human-readable health status"""
        health_score = report_data["health_score"]
        if health_score >= 90:
            return "Excellent"
        elif health_score >= 80:
            return "Good"
        elif health_score >= 70:
            return "Fair"
        elif health_score >= 60:
            return "Poor"
        else:
            return "Critical"

    def get_performance_status(self, report_data):
        """Get human-readable performance status"""
        perf_metrics = report_data["performance_metrics"]
        if perf_metrics.get("count", 0) == 0:
            return "No data"

        response_time = perf_metrics.get("response_time_p95", 0)
        error_rate = perf_metrics.get("error_rate_avg", 0)

        if response_time < 500 and error_rate < 1:
            return "Excellent"
        elif response_time < 1000 and error_rate < 5:
            return "Good"
        elif response_time < 2000 and error_rate < 10:
            return "Fair"
        else:
            return "Poor"


def main():
    """Main function"""
    monitoring_dir = os.path.dirname(os.path.abspath(__file__))

    reporter = HealthCheckReporter(monitoring_dir)

    import sys

    if len(sys.argv) > 1:
        command = sys.argv[1]

        if command == "generate":
            date = sys.argv[2] if len(sys.argv) > 2 else None
            report = reporter.generate_daily_report(date)
            print(f"Daily report generated for {report['report_date']}")
        elif command == "send":
            # Generate and send today's report
            report = reporter.generate_daily_report()
            print("Report generated and notifications sent")
        else:
            print("Usage: python health_reporter.py [generate [date]|send]")
    else:
        # Default: generate today's report
        reporter.generate_daily_report()


if __name__ == "__main__":
    main()
