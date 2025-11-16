#!/usr/bin/env python3
"""
Simple web server to serve dashboards for the hybrid desktop app
"""
import http.server
import os
import sys
import json
import datetime
from pathlib import Path


class ProxyHTTPRequestHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Override to add more detailed logging
        print(f"REQUEST: {format % args}")

    def end_headers(self):
        # Add CORS headers to allow embedding
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header(
            "Access-Control-Allow-Headers", "X-Requested-With, Content-Type"
        )
        super().end_headers()

    def _safe_int_parse(self, value, default=0):
        """Safely parse integer values, handling malformed data"""
        try:
            if isinstance(value, str):
                cleaned = value.strip()
                if "\n" in cleaned:
                    cleaned = cleaned.split("\n")[0]
                return int(float(cleaned))
            return int(value)
        except (ValueError, TypeError):
            return default

    def do_GET(self):
        # Handle root path
        if self.path == "/":
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.end_headers()
            self.wfile.write(
                b"""
<!DOCTYPE html>
<html>
<head>
    <title>Tools Automation Dashboard</title>
    <meta http-equiv="refresh" content="0; url=/agent_dashboard.html">
</head>
<body>
    <p>Redirecting to <a href="/agent_dashboard.html">Agent Dashboard</a>...</p>
</body>
</html>
"""
            )
            return

        # Handle API proxy requests
        if self.path.startswith("/api/") or self.path == "/health":
            self.handle_api_request()
        else:
            self.serve_static_file()

    def handle_api_request(self):
        """Handle API requests with mock/real data"""
        try:
            if self.path == "/api/system/status":
                self.send_json_response(
                    {
                        "status": "ok",
                        "message": "Comprehensive automation ecosystem running",
                        "timestamp": str(datetime.datetime.now()),
                        "version": "2.0.0",
                        # System Resources
                        "cpu_usage": 45.2,
                        "memory_usage": 62.8,
                        "disk_usage": 34.1,
                        "network_usage": 23.5,
                        "agent_count": 17,
                        # Server Components
                        "servers": {
                            "dashboard_server": {
                                "status": "running",
                                "port": 8085,
                                "uptime": "2d 14h 32m",
                                "requests_served": 15432,
                                "avg_response_time": 45.2,
                            },
                            "api_gateway": {
                                "status": "running",
                                "port": 8080,
                                "uptime": "7d 3h 15m",
                                "requests_served": 89456,
                                "avg_response_time": 23.1,
                            },
                            "database_server": {
                                "status": "running",
                                "port": 5432,
                                "uptime": "14d 8h 22m",
                                "connections": 23,
                                "query_time": 12.3,
                            },
                            "cache_server": {
                                "status": "running",
                                "port": 6379,
                                "uptime": "5d 19h 7m",
                                "memory_used": "2.1GB",
                                "hit_rate": 94.2,
                            },
                            "message_queue": {
                                "status": "running",
                                "port": 5672,
                                "uptime": "12d 6h 45m",
                                "queues": 15,
                                "messages_processed": 456789,
                            },
                            "monitoring_server": {
                                "status": "running",
                                "port": 9090,
                                "uptime": "9d 11h 28m",
                                "metrics_collected": 2345678,
                                "alerts_active": 3,
                            },
                        },
                        # Service Health
                        "services": {
                            "authentication": {
                                "status": "healthy",
                                "response_time": 15.2,
                            },
                            "authorization": {
                                "status": "healthy",
                                "response_time": 8.7,
                            },
                            "notification": {
                                "status": "healthy",
                                "response_time": 22.1,
                            },
                            "backup": {"status": "healthy", "last_backup": "2h ago"},
                            "security_scan": {
                                "status": "healthy",
                                "last_scan": "1h ago",
                            },
                            "performance_monitor": {
                                "status": "healthy",
                                "cpu_threshold": 80.0,
                            },
                        },
                        # Infrastructure
                        "infrastructure": {
                            "load_balancer": {
                                "status": "active",
                                "servers": 3,
                                "health": 100.0,
                            },
                            "firewall": {
                                "status": "active",
                                "rules": 156,
                                "blocked_attempts": 2341,
                            },
                            "ssl_certificate": {
                                "status": "valid",
                                "expires": "2026-05-15",
                                "days_left": 183,
                            },
                            "dns": {"status": "healthy", "resolution_time": 12.3},
                            "cdn": {"status": "active", "cache_hit_rate": 87.5},
                        },
                        "history": [
                            {
                                "timestamp": datetime.datetime.now().timestamp()
                                - i * 60,
                                "cpu_usage": 40 + i,
                                "memory_usage": 60 + i,
                                "network_usage": 20 + i * 0.5,
                                "active_connections": 45 + i * 2,
                            }
                            for i in range(10)
                        ],
                    }
                )

            elif self.path == "/api/metrics/system":
                self.send_json_response(
                    {
                        "cpu_usage": 45.2,
                        "memory_usage": 62.8,
                        "disk_usage": 34.1,
                        "process_count": 125,
                        "agent_count": 3,
                        "timestamp": datetime.datetime.now().timestamp(),
                        "history": [
                            {
                                "timestamp": datetime.datetime.now().timestamp()
                                - i * 60,
                                "cpu_usage": str(40 + i),
                                "memory_usage": str(60 + i),
                            }
                            for i in range(10)
                        ],
                    }
                )

            elif self.path == "/api/agents/status":
                self.send_json_response(
                    {
                        "agents": {
                            # Core Development Agents
                            "code_analyzer": {
                                "status": "running",
                                "type": "development",
                                "last_active": datetime.datetime.now().timestamp(),
                                "tasks_completed": 1247,
                                "success_rate": 0.94,
                                "specialties": ["Python", "JavaScript", "TypeScript"],
                            },
                            "test_runner": {
                                "status": "idle",
                                "type": "testing",
                                "last_active": datetime.datetime.now().timestamp()
                                - 300,
                                "tasks_completed": 892,
                                "success_rate": 0.87,
                                "specialties": [
                                    "Unit Tests",
                                    "Integration Tests",
                                    "E2E Tests",
                                ],
                            },
                            "doc_generator": {
                                "status": "running",
                                "type": "documentation",
                                "last_active": datetime.datetime.now().timestamp(),
                                "tasks_completed": 456,
                                "success_rate": 0.96,
                                "specialties": ["API Docs", "README", "Code Comments"],
                            },
                            "security_scanner": {
                                "status": "running",
                                "type": "security",
                                "last_active": datetime.datetime.now().timestamp()
                                - 120,
                                "tasks_completed": 234,
                                "success_rate": 0.91,
                                "specialties": [
                                    "Vulnerability Scanning",
                                    "Code Security",
                                    "Dependency Audit",
                                ],
                            },
                            "performance_optimizer": {
                                "status": "idle",
                                "type": "optimization",
                                "last_active": datetime.datetime.now().timestamp()
                                - 600,
                                "tasks_completed": 178,
                                "success_rate": 0.89,
                                "specialties": [
                                    "Memory Optimization",
                                    "CPU Tuning",
                                    "Database Queries",
                                ],
                            },
                            # Deployment & Infrastructure Agents
                            "deployment_manager": {
                                "status": "running",
                                "type": "deployment",
                                "last_active": datetime.datetime.now().timestamp(),
                                "tasks_completed": 567,
                                "success_rate": 0.93,
                                "specialties": [
                                    "Docker",
                                    "Kubernetes",
                                    "CI/CD",
                                    "Cloud Deployment",
                                ],
                            },
                            "infrastructure_monitor": {
                                "status": "running",
                                "type": "monitoring",
                                "last_active": datetime.datetime.now().timestamp(),
                                "tasks_completed": 1234,
                                "success_rate": 0.98,
                                "specialties": [
                                    "System Monitoring",
                                    "Resource Tracking",
                                    "Alert Management",
                                ],
                            },
                            "backup_agent": {
                                "status": "idle",
                                "type": "backup",
                                "last_active": datetime.datetime.now().timestamp()
                                - 3600,
                                "tasks_completed": 89,
                                "success_rate": 1.0,
                                "specialties": [
                                    "Data Backup",
                                    "Disaster Recovery",
                                    "Version Control",
                                ],
                            },
                            # AI/ML Agents
                            "ml_trainer": {
                                "status": "running",
                                "type": "ai_ml",
                                "last_active": datetime.datetime.now().timestamp()
                                - 180,
                                "tasks_completed": 45,
                                "success_rate": 0.82,
                                "specialties": [
                                    "Model Training",
                                    "Data Processing",
                                    "Feature Engineering",
                                ],
                            },
                            "predictive_analyzer": {
                                "status": "running",
                                "type": "ai_ml",
                                "last_active": datetime.datetime.now().timestamp(),
                                "tasks_completed": 2341,
                                "success_rate": 0.95,
                                "specialties": [
                                    "Predictive Analytics",
                                    "Anomaly Detection",
                                    "Trend Analysis",
                                ],
                            },
                            # Communication & Collaboration Agents
                            "notification_dispatcher": {
                                "status": "running",
                                "type": "communication",
                                "last_active": datetime.datetime.now().timestamp(),
                                "tasks_completed": 3456,
                                "success_rate": 0.99,
                                "specialties": ["Email", "Slack", "Teams", "SMS"],
                            },
                            "collaboration_coordinator": {
                                "status": "idle",
                                "type": "collaboration",
                                "last_active": datetime.datetime.now().timestamp()
                                - 900,
                                "tasks_completed": 123,
                                "success_rate": 0.94,
                                "specialties": [
                                    "Task Assignment",
                                    "Progress Tracking",
                                    "Team Coordination",
                                ],
                            },
                            # Specialized Agents
                            "data_processor": {
                                "status": "running",
                                "type": "data",
                                "last_active": datetime.datetime.now().timestamp() - 60,
                                "tasks_completed": 2156,
                                "success_rate": 0.97,
                                "specialties": ["ETL", "Data Cleaning", "Analytics"],
                            },
                            "api_gateway": {
                                "status": "running",
                                "type": "infrastructure",
                                "last_active": datetime.datetime.now().timestamp(),
                                "tasks_completed": 5678,
                                "success_rate": 0.99,
                                "specialties": [
                                    "API Routing",
                                    "Rate Limiting",
                                    "Authentication",
                                ],
                            },
                            "log_analyzer": {
                                "status": "running",
                                "type": "monitoring",
                                "last_active": datetime.datetime.now().timestamp(),
                                "tasks_completed": 4321,
                                "success_rate": 0.96,
                                "specialties": [
                                    "Log Parsing",
                                    "Error Detection",
                                    "Performance Analysis",
                                ],
                            },
                        },
                        "agent_types": {
                            "development": 3,
                            "testing": 1,
                            "documentation": 1,
                            "security": 1,
                            "optimization": 1,
                            "deployment": 1,
                            "monitoring": 2,
                            "backup": 1,
                            "ai_ml": 2,
                            "communication": 1,
                            "collaboration": 1,
                            "data": 1,
                            "infrastructure": 1,
                        },
                        "total_agents": 17,
                        "active_agents": 12,
                        "idle_agents": 5,
                        "last_update": datetime.datetime.now().timestamp(),
                    }
                )

            elif self.path == "/api/tools/status":
                self.send_json_response(
                    {
                        "tools": {
                            # Development Tools
                            "code_formatter": {
                                "status": "active",
                                "version": "1.2.3",
                                "last_used": datetime.datetime.now().timestamp() - 300,
                                "usage_count": 3456,
                                "languages": [
                                    "Python",
                                    "JavaScript",
                                    "TypeScript",
                                    "Go",
                                ],
                            },
                            "linter": {
                                "status": "active",
                                "version": "2.1.4",
                                "last_used": datetime.datetime.now().timestamp() - 120,
                                "usage_count": 5678,
                                "rules_active": 234,
                            },
                            "debugger": {
                                "status": "idle",
                                "version": "3.0.1",
                                "last_used": datetime.datetime.now().timestamp() - 1800,
                                "usage_count": 1234,
                                "breakpoints_set": 45,
                            },
                            # Testing Tools
                            "unit_test_runner": {
                                "status": "active",
                                "version": "4.5.6",
                                "last_used": datetime.datetime.now().timestamp(),
                                "usage_count": 7890,
                                "tests_run": 45678,
                                "pass_rate": 94.2,
                            },
                            "integration_tester": {
                                "status": "active",
                                "version": "2.3.4",
                                "last_used": datetime.datetime.now().timestamp() - 600,
                                "usage_count": 2345,
                                "scenarios_tested": 567,
                            },
                            "performance_tester": {
                                "status": "idle",
                                "version": "1.8.9",
                                "last_used": datetime.datetime.now().timestamp() - 3600,
                                "usage_count": 890,
                                "benchmarks_run": 123,
                            },
                            # Deployment Tools
                            "container_builder": {
                                "status": "active",
                                "version": "24.0.5",
                                "last_used": datetime.datetime.now().timestamp(),
                                "usage_count": 3456,
                                "images_built": 2341,
                            },
                            "orchestrator": {
                                "status": "active",
                                "version": "1.28.2",
                                "last_used": datetime.datetime.now().timestamp(),
                                "usage_count": 4567,
                                "pods_managed": 89,
                            },
                            "ci_cd_pipeline": {
                                "status": "active",
                                "version": "2.4.1",
                                "last_used": datetime.datetime.now().timestamp() - 300,
                                "usage_count": 6789,
                                "pipelines_run": 3456,
                                "success_rate": 91.5,
                            },
                            # Monitoring Tools
                            "metrics_collector": {
                                "status": "active",
                                "version": "1.5.2",
                                "last_used": datetime.datetime.now().timestamp(),
                                "usage_count": 12345,
                                "metrics_collected": 2345678,
                            },
                            "log_aggregator": {
                                "status": "active",
                                "version": "3.2.1",
                                "last_used": datetime.datetime.now().timestamp(),
                                "usage_count": 9876,
                                "logs_processed": 3456789,
                            },
                            "alert_manager": {
                                "status": "active",
                                "version": "0.25.0",
                                "last_used": datetime.datetime.now().timestamp(),
                                "usage_count": 5432,
                                "alerts_sent": 1234,
                            },
                        },
                        "tool_categories": {
                            "development": 3,
                            "testing": 3,
                            "deployment": 3,
                            "monitoring": 3,
                        },
                        "total_tools": 12,
                        "active_tools": 10,
                        "idle_tools": 2,
                        "last_update": datetime.datetime.now().timestamp(),
                    }
                )

            elif self.path == "/api/infrastructure/status":
                self.send_json_response(
                    {
                        "infrastructure": {
                            "compute": {
                                "instances": [
                                    {
                                        "id": "web-01",
                                        "type": "t3.medium",
                                        "status": "running",
                                        "cpu_usage": 45.2,
                                        "memory_usage": 62.8,
                                        "uptime": "14d 8h 22m",
                                        "region": "us-east-1",
                                    },
                                    {
                                        "id": "api-01",
                                        "type": "t3.large",
                                        "status": "running",
                                        "cpu_usage": 67.3,
                                        "memory_usage": 54.1,
                                        "uptime": "12d 6h 45m",
                                        "region": "us-east-1",
                                    },
                                    {
                                        "id": "db-01",
                                        "type": "r5.large",
                                        "status": "running",
                                        "cpu_usage": 34.7,
                                        "memory_usage": 78.9,
                                        "uptime": "21d 3h 12m",
                                        "region": "us-west-2",
                                    },
                                ],
                                "total_instances": 3,
                                "healthy_instances": 3,
                                "avg_cpu_usage": 49.1,
                                "avg_memory_usage": 65.3,
                            },
                            "storage": {
                                "buckets": [
                                    {
                                        "name": "app-data",
                                        "size": "2.3TB",
                                        "objects": 45678,
                                        "last_modified": datetime.datetime.now().timestamp()
                                        - 3600,
                                    },
                                    {
                                        "name": "backups",
                                        "size": "5.7TB",
                                        "objects": 1234,
                                        "last_modified": datetime.datetime.now().timestamp()
                                        - 86400,
                                    },
                                    {
                                        "name": "logs",
                                        "size": "890GB",
                                        "objects": 56789,
                                        "last_modified": datetime.datetime.now().timestamp()
                                        - 1800,
                                    },
                                ],
                                "total_storage": "8.89TB",
                                "used_storage": "6.2TB",
                                "available_storage": "2.69TB",
                            },
                            "networking": {
                                "load_balancers": [
                                    {
                                        "name": "app-lb",
                                        "type": "application",
                                        "status": "active",
                                        "target_groups": 3,
                                        "healthy_targets": 6,
                                        "unhealthy_targets": 0,
                                    }
                                ],
                                "cdn_distributions": [
                                    {
                                        "id": "E1A2B3C4D5F6",
                                        "status": "deployed",
                                        "origins": 2,
                                        "cache_hit_rate": 87.5,
                                        "requests_per_second": 1234.5,
                                    }
                                ],
                                "dns_zones": [
                                    {
                                        "name": "example.com",
                                        "type": "public",
                                        "records": 45,
                                        "last_updated": datetime.datetime.now().timestamp()
                                        - 7200,
                                    }
                                ],
                            },
                            "security": {
                                "firewalls": [
                                    {
                                        "name": "default-sg",
                                        "rules": 12,
                                        "allowed_traffic": "22,80,443",
                                        "blocked_attempts": 2341,
                                    }
                                ],
                                "ssl_certificates": [
                                    {
                                        "domain": "*.example.com",
                                        "issuer": "Let's Encrypt",
                                        "expires": "2026-02-15",
                                        "status": "valid",
                                        "days_left": 125,
                                    }
                                ],
                                "waf_rules": [
                                    {
                                        "name": "SQL Injection Protection",
                                        "rules": 25,
                                        "blocked_requests": 456,
                                        "false_positives": 12,
                                    }
                                ],
                            },
                        },
                        "health_score": 98.5,
                        "last_update": datetime.datetime.now().timestamp(),
                    }
                )

            elif self.path == "/api/security/status":
                self.send_json_response(
                    {
                        "security": {
                            "threat_detection": {
                                "active_scans": 3,
                                "threats_detected": 12,
                                "threats_blocked": 12,
                                "false_positives": 2,
                                "last_scan": datetime.datetime.now().timestamp() - 3600,
                            },
                            "vulnerability_management": {
                                "critical_vulnerabilities": 0,
                                "high_vulnerabilities": 3,
                                "medium_vulnerabilities": 15,
                                "low_vulnerabilities": 42,
                                "last_assessment": datetime.datetime.now().timestamp()
                                - 86400,
                            },
                            "access_control": {
                                "active_sessions": 23,
                                "failed_logins": 5,
                                "suspicious_activities": 2,
                                "mfa_enabled_users": 18,
                                "total_users": 20,
                            },
                            "data_protection": {
                                "encrypted_databases": 3,
                                "encrypted_backups": 12,
                                "data_loss_prevention_rules": 25,
                                "compliance_score": 96.7,
                            },
                            "network_security": {
                                "active_firewall_rules": 156,
                                "blocked_connections": 2341,
                                "ddos_attempts": 3,
                                "intrusion_attempts": 45,
                            },
                        },
                        "overall_security_score": 94.2,
                        "last_update": datetime.datetime.now().timestamp(),
                    }
                )

            elif self.path == "/api/performance/metrics":
                self.send_json_response(
                    {
                        "performance": {
                            "response_times": {
                                "api_gateway": {"p50": 23.1, "p95": 89.4, "p99": 234.5},
                                "database": {"p50": 12.3, "p95": 67.8, "p99": 145.2},
                                "cache": {"p50": 1.2, "p95": 5.6, "p99": 12.3},
                                "external_apis": {
                                    "p50": 156.7,
                                    "p95": 445.2,
                                    "p99": 892.1,
                                },
                            },
                            "throughput": {
                                "requests_per_second": 1234.5,
                                "data_transfer_mb_per_sec": 45.6,
                                "database_queries_per_sec": 567.8,
                                "cache_hits_per_sec": 890.1,
                            },
                            "resource_utilization": {
                                "cpu_percentile": {
                                    "p50": 45.2,
                                    "p95": 78.9,
                                    "p99": 92.3,
                                },
                                "memory_percentile": {
                                    "p50": 62.8,
                                    "p95": 85.4,
                                    "p99": 94.7,
                                },
                                "disk_io_percentile": {
                                    "p50": 23.4,
                                    "p95": 67.8,
                                    "p99": 89.1,
                                },
                                "network_io_percentile": {
                                    "p50": 34.5,
                                    "p95": 78.9,
                                    "p99": 91.2,
                                },
                            },
                            "error_rates": {
                                "http_4xx_rate": 2.3,
                                "http_5xx_rate": 0.1,
                                "database_errors_rate": 0.05,
                                "timeout_rate": 1.2,
                            },
                        },
                        "time_range": "last_24h",
                        "last_update": datetime.datetime.now().timestamp(),
                    }
                )

            elif self.path == "/api/tasks/analytics":
                self.send_json_response(
                    {
                        "total_tasks": 3456,
                        "completed": 3120,
                        "failed": 156,
                        "running": 180,
                        "queued": 234,
                        "success_rate": 0.952,
                        "avg_duration": 2.3,
                        "total_files_processed": 12450,
                        "total_issues_found": 567,
                        # Task breakdown by type
                        "by_type": {
                            "code_analysis": {
                                "total": 1200,
                                "completed": 1150,
                                "failed": 25,
                                "running": 25,
                            },
                            "testing": {
                                "total": 890,
                                "completed": 834,
                                "failed": 34,
                                "running": 22,
                            },
                            "deployment": {
                                "total": 456,
                                "completed": 432,
                                "failed": 12,
                                "running": 12,
                            },
                            "documentation": {
                                "total": 234,
                                "completed": 221,
                                "failed": 8,
                                "running": 5,
                            },
                            "security_scan": {
                                "total": 345,
                                "completed": 321,
                                "failed": 15,
                                "running": 9,
                            },
                            "performance_test": {
                                "total": 167,
                                "completed": 152,
                                "failed": 9,
                                "running": 6,
                            },
                            "backup": {
                                "total": 89,
                                "completed": 89,
                                "failed": 0,
                                "running": 0,
                            },
                            "monitoring": {
                                "total": 75,
                                "completed": 71,
                                "failed": 2,
                                "running": 2,
                            },
                        },
                        # Task breakdown by priority
                        "by_priority": {
                            "critical": {
                                "total": 234,
                                "completed": 221,
                                "failed": 8,
                                "running": 5,
                            },
                            "high": {
                                "total": 678,
                                "completed": 634,
                                "failed": 23,
                                "running": 21,
                            },
                            "medium": {
                                "total": 1456,
                                "completed": 1345,
                                "failed": 67,
                                "running": 44,
                            },
                            "low": {
                                "total": 1088,
                                "completed": 920,
                                "failed": 58,
                                "running": 110,
                            },
                        },
                        # Performance metrics
                        "performance": {
                            "fastest_completion": 0.2,  # seconds
                            "slowest_completion": 45.6,  # seconds
                            "avg_queue_time": 12.3,  # seconds
                            "avg_processing_time": 2.3,  # seconds
                            "throughput_per_hour": 144,  # tasks
                        },
                        # Recent task activity
                        "recent_tasks": [
                            {
                                "id": "task_3456",
                                "type": "code_analysis",
                                "status": "completed",
                                "duration": 1.2,
                                "started_at": datetime.datetime.now().timestamp() - 300,
                                "completed_at": datetime.datetime.now().timestamp()
                                - 180,
                            },
                            {
                                "id": "task_3455",
                                "type": "testing",
                                "status": "running",
                                "duration": None,
                                "started_at": datetime.datetime.now().timestamp() - 120,
                                "completed_at": None,
                            },
                            {
                                "id": "task_3454",
                                "type": "deployment",
                                "status": "completed",
                                "duration": 5.6,
                                "started_at": datetime.datetime.now().timestamp() - 600,
                                "completed_at": datetime.datetime.now().timestamp()
                                - 360,
                            },
                        ],
                        "last_update": datetime.datetime.now().timestamp(),
                    }
                )

            elif self.path == "/api/ml/analytics":
                self.send_json_response(
                    {
                        "models": {
                            "predictive_analyzer": {
                                "accuracy": 0.94,
                                "precision": 0.91,
                                "recall": 0.87,
                                "f1_score": 0.89,
                                "predictions_count": 2341,
                                "last_training": "2025-11-13T10:30:00Z",
                                "dataset_size": 50000,
                                "features_used": 45,
                                "model_type": "Random Forest",
                            },
                            "anomaly_detector": {
                                "accuracy": 0.96,
                                "false_positive_rate": 0.02,
                                "anomalies_detected": 234,
                                "normal_events": 45678,
                                "last_training": "2025-11-12T15:45:00Z",
                                "dataset_size": 100000,
                                "algorithm": "Isolation Forest",
                            },
                            "recommendation_engine": {
                                "accuracy": 0.89,
                                "coverage": 0.76,
                                "diversity": 0.82,
                                "recommendations_made": 5678,
                                "user_satisfaction": 4.2,
                                "last_training": "2025-11-11T08:20:00Z",
                                "dataset_size": 25000,
                            },
                            "sentiment_analyzer": {
                                "accuracy": 0.92,
                                "precision": 0.89,
                                "recall": 0.91,
                                "f1_score": 0.90,
                                "texts_analyzed": 12345,
                                "last_training": "2025-11-10T12:15:00Z",
                                "dataset_size": 75000,
                            },
                        },
                        "overall_metrics": {
                            "avg_accuracy": 0.928,
                            "total_predictions": 23456,
                            "total_training_time": 45.6,  # hours
                            "models_deployed": 4,
                            "active_experiments": 3,
                        },
                        "training_history": [
                            {
                                "model": "predictive_analyzer",
                                "timestamp": "2025-11-13T10:30:00Z",
                                "accuracy_before": 0.91,
                                "accuracy_after": 0.94,
                                "training_time": 2.3,
                                "improvement": 0.03,
                            },
                            {
                                "model": "anomaly_detector",
                                "timestamp": "2025-11-12T15:45:00Z",
                                "accuracy_before": 0.93,
                                "accuracy_after": 0.96,
                                "training_time": 1.8,
                                "improvement": 0.03,
                            },
                        ],
                        "performance_metrics": {
                            "avg_inference_time": 0.023,  # seconds
                            "max_inference_time": 0.156,
                            "p95_inference_time": 0.045,
                            "throughput": 890.5,  # predictions per second
                            "memory_usage": 2.3,  # GB
                            "cpu_usage": 34.5,
                        },
                        "last_update": datetime.datetime.now().timestamp(),
                    }
                )

            elif self.path == "/api/umami/stats":
                self.send_json_response(
                    {
                        "total_events": 1250,
                        "unique_visitors": 89,
                        "page_views": 2150,
                        "avg_session_duration": 4.2,
                        "top_pages": [
                            {"path": "/dashboard", "views": 450},
                            {"path": "/agents", "views": 320},
                            {"path": "/analytics", "views": 280},
                        ],
                    }
                )

            elif self.path == "/api/todo/dashboard":
                self.send_json_response(
                    {
                        "total_todos": 45,
                        "by_status": {"pending": 12, "in_progress": 8, "completed": 25},
                        "by_category": {
                            "bug_fixes": 15,
                            "features": 10,
                            "documentation": 8,
                            "testing": 12,
                        },
                        "by_priority": {"high": 18, "medium": 15, "low": 12},
                        "overdue": 3,
                        "recent_activity": [
                            {
                                "title": "Fix authentication bug",
                                "status": "completed",
                                "updated_at": datetime.datetime.now().isoformat(),
                            },
                            {
                                "title": "Add user profile feature",
                                "status": "in_progress",
                                "updated_at": datetime.datetime.now().isoformat(),
                            },
                            {
                                "title": "Update documentation",
                                "status": "pending",
                                "updated_at": datetime.datetime.now().isoformat(),
                            },
                        ],
                    }
                )

            elif self.path == "/api/todo/analyze":
                self.send_json_response(
                    {"todos_created": 5, "message": "Analysis completed"}
                )

            elif self.path == "/api/todo/process":
                self.send_json_response({"message": "Todo processing completed"})

            elif self.path == "/api/todo/execute-critical":
                self.send_json_response({"message": "Critical todos executed"})

            elif self.path == "/api/todo/report":
                self.send_json_response({"message": "Report generated successfully"})

            elif self.path == "/health":
                self.send_json_response(
                    {
                        "status": "healthy",
                        "timestamp": datetime.datetime.now().isoformat(),
                        "version": "1.0.0",
                    }
                )

            elif self.path == "/metrics":
                # Expose simple metrics in Prometheus text format
                self.send_response(200)
                self.send_header("Content-Type", "text/plain; version=0.0.4")
                self.send_header("X-Content-Type-Options", "nosniff")
                self.end_headers()
                lines = []
                # Dashboard-specific metrics
                lines.append(
                    "# HELP dashboard_requests_total Total number of dashboard requests"
                )
                lines.append("# TYPE dashboard_requests_total counter")
                lines.append("dashboard_requests_total 1234")
                lines.append("")
                lines.append(
                    "# HELP dashboard_active_connections Number of active connections"
                )
                lines.append("# TYPE dashboard_active_connections gauge")
                lines.append("dashboard_active_connections 5")
                lines.append("")
                lines.append(
                    "# HELP dashboard_response_time_seconds Response time in seconds"
                )
                lines.append("# TYPE dashboard_response_time_seconds histogram")
                lines.append('dashboard_response_time_seconds_bucket{le="0.1"} 120')
                lines.append('dashboard_response_time_seconds_bucket{le="0.5"} 180')
                lines.append('dashboard_response_time_seconds_bucket{le="1.0"} 200')
                lines.append('dashboard_response_time_seconds_bucket{le="2.0"} 210')
                lines.append('dashboard_response_time_seconds_bucket{le="5.0"} 215')
                lines.append('dashboard_response_time_seconds_bucket{le="+Inf"} 220')
                lines.append("dashboard_response_time_seconds_count 220")
                lines.append("dashboard_response_time_seconds_sum 45.6")
                lines.append("")
                lines.append(
                    "# HELP dashboard_memory_usage_bytes Memory usage in bytes"
                )
                lines.append("# TYPE dashboard_memory_usage_bytes gauge")
                lines.append("dashboard_memory_usage_bytes 67108864")
                lines.append("")
                lines.append("# HELP dashboard_cpu_usage_percent CPU usage percentage")
                lines.append("# TYPE dashboard_cpu_usage_percent gauge")
                lines.append("dashboard_cpu_usage_percent 23.5")
                body = "\n".join(lines) + "\n"
                self.wfile.write(body.encode("utf-8"))
                return

            else:
                self.send_error(404, "API endpoint not found")

        except Exception as e:
            self.send_error(500, f"API error: {str(e)}")

    def send_json_response(self, data):
        """Send a JSON response"""
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def serve_static_file(self):
        """Serve static files from the web directory"""
        try:
            # Remove leading slash and prevent directory traversal
            path = self.path.lstrip("/")
            if ".." in path or path.startswith("/"):
                self.send_error(403, "Forbidden")
                return

            # Build full path
            file_path = os.path.join(os.getcwd(), path)

            # Check if file exists
            if not os.path.exists(file_path) or not os.path.isfile(file_path):
                self.send_error(404, "File not found")
                return

            # Send file
            with open(file_path, "rb") as f:
                self.send_response(200)
                # Set content type based on file extension
                if path.endswith(".html"):
                    self.send_header("Content-Type", "text/html")
                elif path.endswith(".css"):
                    self.send_header("Content-Type", "text/css")
                elif path.endswith(".js"):
                    self.send_header("Content-Type", "application/javascript")
                elif path.endswith(".json"):
                    self.send_header("Content-Type", "application/json")
                else:
                    self.send_header("Content-Type", "text/plain")
                self.end_headers()
                self.wfile.write(f.read())

        except Exception:
            self.send_error(500, "Internal server error")

    def do_POST(self):
        # Handle API proxy requests for POST
        if self.path.startswith("/api/"):
            if self.path == "/api/dashboard/refresh":
                self.send_json_response(
                    {"status": "success", "message": "Dashboard refresh triggered"}
                )
            else:
                self.send_error(404, "API endpoint not found")
        else:
            self.send_error(405, "Method Not Allowed")

    def do_OPTIONS(self):
        # Handle CORS preflight requests
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header(
            "Access-Control-Allow-Headers", "X-Requested-With, Content-Type"
        )
        self.end_headers()


def main():
    PORT = 8085
    web_dir = Path(__file__).parent

    os.chdir(web_dir)

    # Create daemon-like behavior
    try:
        with http.server.HTTPServer(("", PORT), ProxyHTTPRequestHandler) as httpd:
            print(
                f"🚀 Dashboard server with API proxy running at http://localhost:{PORT}"
            )
            print(f"📁 Serving files from: {web_dir}")
            print("Server is running... (use Ctrl+C to stop)")
            httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n👋 Server stopped")
        sys.exit(0)
    except Exception as e:
        print(f"Server error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
