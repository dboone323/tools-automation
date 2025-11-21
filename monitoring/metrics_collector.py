#!/usr/bin/env python3
"""
Agent Metrics Collector
Collects performance and operational metrics from all agents and stores in time-series database
"""

import json
import time
import sqlite3
import os
import sys
import subprocess
import re
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Any

class MetricsCollector:
    """Collects and stores agent metrics in time-series database"""
    
    def __init__(self, db_path: str = None):
        """Initialize metrics collector with database path"""
        if db_path is None:
            # Use config discovery to find workspace
            workspace_root = self._discover_workspace()
            db_path = os.path.join(workspace_root, "tools-automation", "monitoring", "metrics.db")
        
        # Ensure monitoring directory exists
        os.makedirs(os.path.dirname(db_path), exist_ok=True)
        
        self.db_path = db_path
        self.conn = None
        self._init_database()
    
    def _discover_workspace(self) -> str:
        """Discover workspace root using agent_config_discovery.sh"""
        try:
            script_dir = os.path.dirname(os.path.abspath(__file__))
            parent_dir = os.path.dirname(script_dir)
            config_script = os.path.join(parent_dir, "agents", "agent_config_discovery.sh")
            
            if os.path.exists(config_script):
                result = subprocess.run(
                    ["bash", config_script, "workspace-root"],
                    capture_output=True,
                    text=True
                )
                if result.returncode == 0:
                    return result.stdout.strip()
        except Exception:
            pass
        # Fallback
        return os.path.expanduser("~/Desktop/github-projects")
    
    def _get_process_stats(self, pid: int) -> tuple:
        """Get CPU and memory stats for a process (stdlib only)"""
        try:
            # Use ps command for cross-platform compatibility
            result = subprocess.run(
                ['ps', '-p', str(pid), '-o', '%cpu,%mem'],
                capture_output=True,
                text=True
            )
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                if len(lines) > 1:
                    parts = lines[1].split()
                    if len(parts) >= 2:
                        cpu_percent = float(parts[0])
                        mem_percent = float(parts[1])
                        # Estimate memory in MB (rough approximation)
                        # This is very approximate without psutil
                        memory_mb = mem_percent * 100  # Rough estimate
                        return (cpu_percent, memory_mb)
        except Exception:
            pass
        return (None, None)
    
    def _get_system_stats(self) -> Dict[str, float]:
        """Get system-wide stats (stdlib only)"""
        stats = {}
        
        # Get load averages
        try:
            load_1, load_5, load_15 = os.getloadavg()
            stats['load_1min'] = load_1
            stats['load_5min'] = load_5
            stats['load_15min'] = load_15
        except (AttributeError, OSError):
            stats['load_1min'] = None
            stats['load_5min'] = None
            stats['load_15min'] = None
        
        # Get CPU usage (macOS/Linux compatible)
        try:
            result = subprocess.run(
                ['top', '-l', '1', '-n', '0'],
                capture_output=True,
                text=True,
                timeout=2
            )
            if result.returncode == 0:
                for line in result.stdout.split('\n'):
                    if 'CPU usage' in line:
                        match = re.search(r'(\d+\.?\d*)%\s+idle', line)
                        if match:
                            idle = float(match.group(1))
                            stats['cpu_percent'] = 100 - idle
                            break
        except (Exception, subprocess.TimeoutExpired):
            stats['cpu_percent'] = None
        
        # Get memory usage
        try:
            result = subprocess.run(
                ['vm_stat'],
                capture_output=True,
                text=True
            )
            if result.returncode == 0:
                # Parse vm_stat output (macOS)
                free_pages = 0
                active_pages = 0
                for line in result.stdout.split('\n'):
                    if 'Pages free' in line:
                        free_pages = int(line.split(':')[1].strip().rstrip('.'))
                    elif 'Pages active' in line:
                        active_pages = int(line.split(':')[1].strip().rstrip('.'))
                if free_pages + active_pages > 0:
                    stats['memory_percent'] = (active_pages / (free_pages + active_pages)) * 100
        except Exception:
            stats['memory_percent'] = None
        
        # Get disk usage
        try:
            result = subprocess.run(
                ['df', '-h', '/'],
                capture_output=True,
                text=True
            )
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                if len(lines) > 1:
                    parts = lines[1].split()
                    if len(parts) >= 5:
                       stats['disk_percent'] = float(parts[4].rstrip('%'))
        except Exception:
            stats['disk_percent'] = None
        
        return stats
    
    def _count_agent_processes(self) -> int:
        """Count active agent processes"""
        try:
            result = subprocess.run(
                ['ps', 'aux'],
                capture_output=True,
                text=True
            )
            if result.returncode == 0:
                count = 0
                for line in result.stdout.split('\n'):
                    if 'agent_' in line or '_agent' in line:
                        if '.sh' in line or 'python' in line:
                            count += 1
                return count
        except Exception:
            pass
        return 0
    
    def _init_database(self):
        """Initialize SQLite database with metrics tables"""
        self.conn = sqlite3.connect(self.db_path)
        cursor = self.conn.cursor()
        
        # Agent metrics table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS agent_metrics (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp INTEGER NOT NULL,
                agent_name TEXT NOT NULL,
                status TEXT,
                cpu_percent REAL,
                memory_mb REAL,
                tasks_completed INTEGER,
                tasks_failed INTEGER,
                tasks_queued INTEGER,
                response_time_ms REAL,
                error_count INTEGER
            )
        """)
        
        # System metrics table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS system_metrics (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp INTEGER NOT NULL,
                cpu_percent REAL,
                memory_percent REAL,
                disk_percent REAL,
                load_1min REAL,
                load_5min REAL,
                load_15min REAL,
                active_agents INTEGER
            )
        """)
        
        # Task metrics table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS task_metrics (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp INTEGER NOT NULL,
                task_id TEXT NOT NULL,
                agent_name TEXT,
                duration_seconds REAL,
                status TEXT,
                success BOOLEAN,
                error_message TEXT
            )
        """)
        
        # Anomaly detection table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS anomalies (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                detected_at INTEGER NOT NULL,
                metric_type TEXT NOT NULL,
                metric_name TEXT NOT NULL,
                severity TEXT,
                description TEXT,
                value REAL,
                threshold REAL,
                acknowledged BOOLEAN DEFAULT 0
            )
        """)
        
        # Create indexes for performance
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_agent_metrics_timestamp ON agent_metrics(timestamp)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_agent_metrics_name ON agent_metrics(agent_name)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_system_metrics_timestamp ON system_metrics(timestamp)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_task_metrics_timestamp ON task_metrics(timestamp)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_anomalies_timestamp ON anomalies(detected_at)")
        
        self.conn.commit()
    
    def collect_agent_metrics(self, agent_status_file: str) -> int:
        """Collect metrics from all agents"""
        if not os.path.exists(agent_status_file):
            return 0
        
        try:
            with open(agent_status_file, 'r') as f:
                data = json.load(f)
        except (json.JSONDecodeError, FileNotFoundError):
            return 0
        
        timestamp = int(time.time())
        cursor = self.conn.cursor()
        metrics_collected = 0
        
        agents = data.get('agents', {})
        for agent_name, agent_data in agents.items():
            # Get process metrics if PID available
            cpu_percent = None
            memory_mb = None
            
            pid = agent_data.get('pid')
            if pid and isinstance(pid, (int, float)):
                cpu_percent, memory_mb = self._get_process_stats(int(pid))
            
            # Insert metrics
            cursor.execute("""
                INSERT INTO agent_metrics 
                (timestamp, agent_name, status, cpu_percent, memory_mb, 
                 tasks_completed, tasks_failed, tasks_queued, error_count)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                timestamp,
                agent_name,
                agent_data.get('status', 'unknown'),
                cpu_percent,
                memory_mb,
                agent_data.get('tasks_completed', 0),
                agent_data.get('tasks_failed', 0),
                agent_data.get('tasks_queued', 0),
                agent_data.get('error_count', 0)
            ))
            metrics_collected += 1
        
        self.conn.commit()
        return metrics_collected
    
    def collect_system_metrics(self) -> bool:
        """Collect system-wide metrics"""
        timestamp = int(time.time())
        
        # Get system stats using stdlib only
        stats = self._get_system_stats()
        cpu_percent = stats.get('cpu_percent')
        memory_percent = stats.get('memory_percent')
        disk_percent = stats.get('disk_percent')
        load_1 = stats.get('load_1min')
        load_5 = stats.get('load_5min')
        load_15 = stats.get('load_15min')
        
        # Count active agent processes
        active_agents = self._count_agent_processes()
        
        cursor = self.conn.cursor()
        cursor.execute("""
            INSERT INTO system_metrics
            (timestamp, cpu_percent, memory_percent, disk_percent,
             load_1min, load_5min, load_15min, active_agents)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            timestamp,
            cpu_percent,
            memory_percent,
            disk_percent,
            load_1,
            load_5,
            load_15,
            active_agents
        ))
        
        self.conn.commit()
        return True
    
    def record_task_metric(self, task_id: str, agent_name: str, 
                          duration: float, status: str, success: bool,
                          error_message: str = None):
        """Record metrics for a completed task"""
        timestamp = int(time.time())
        
        cursor = self.conn.cursor()
        cursor.execute("""
            INSERT INTO task_metrics
            (timestamp, task_id, agent_name, duration_seconds, status, success, error_message)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (
            timestamp,
            task_id,
            agent_name,
            duration,
            status,
            success,
            error_message
        ))
        
        self.conn.commit()
    
    def detect_anomalies(self) -> List[Dict[str, Any]]:
        """Detect anomalies in recent metrics"""
        anomalies = []
        cursor = self.conn.cursor()
        
        # Check for high CPU usage
        cursor.execute("""
            SELECT agent_name, AVG(cpu_percent) as avg_cpu
            FROM agent_metrics
            WHERE timestamp > ? AND cpu_percent IS NOT NULL
            GROUP BY agent_name
            HAVING avg_cpu > 80
        """, (int(time.time()) - 300,))  # Last 5 minutes
        
        for row in cursor.fetchall():
            agent_name, avg_cpu = row
            anomalies.append({
                'type': 'high_cpu',
                'agent': agent_name,
                'value': avg_cpu,
                'threshold': 80,
                'severity': 'warning' if avg_cpu < 90 else 'critical'
            })
        
        # Check for high memory usage
        cursor.execute("""
            SELECT agent_name, AVG(memory_mb) as avg_mem
            FROM agent_metrics
            WHERE timestamp > ? AND memory_mb IS NOT NULL
            GROUP BY agent_name
            HAVING avg_mem > 500
        """, (int(time.time()) - 300,))
        
        for row in cursor.fetchall():
            agent_name, avg_mem = row
            anomalies.append({
                'type': 'high_memory',
                'agent': agent_name,
                'value': avg_mem,
                'threshold': 500,
                'severity': 'warning' if avg_mem < 1000 else 'critical'
            })
        
        # Check for high task failure rate
        cursor.execute("""
            SELECT agent_name, 
                   COUNT(*) as total,
                   SUM(CASE WHEN success = 0 THEN 1 ELSE 0 END) as failures
            FROM task_metrics
            WHERE timestamp > ?
            GROUP BY agent_name
            HAVING (failures * 1.0 / total) > 0.3
        """, (int(time.time()) - 3600,))  # Last hour
        
        for row in cursor.fetchall():
            agent_name, total, failures = row
            failure_rate = failures / total
            anomalies.append({
                'type': 'high_failure_rate',
                'agent': agent_name,
                'value': failure_rate * 100,
                'threshold': 30,
                'severity': 'critical'
            })
        
        # Record detected anomalies
        timestamp = int(time.time())
        for anomaly in anomalies:
            cursor.execute("""
                INSERT INTO anomalies
                (detected_at, metric_type, metric_name, severity, description, value, threshold)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (
                timestamp,
                anomaly['type'],
                anomaly.get('agent', 'system'),
                anomaly['severity'],
                f"{anomaly['type']} detected for {anomaly.get('agent', 'system')}",
                anomaly['value'],
                anomaly['threshold']
            ))
        
        if anomalies:
            self.conn.commit()
        
        return anomalies
    
    def get_metrics_summary(self, hours: int = 24) -> Dict[str, Any]:
        """Get metrics summary for the specified time period"""
        since_timestamp = int(time.time()) - (hours * 3600)
        cursor = self.conn.cursor()
        
        # Agent statistics
        cursor.execute("""
            SELECT 
                COUNT(DISTINCT agent_name) as total_agents,
                AVG(cpu_percent) as avg_cpu,
                AVG(memory_mb) as avg_memory,
                SUM(tasks_completed) as total_tasks_completed
            FROM agent_metrics
            WHERE timestamp > ?
        """, (since_timestamp,))
        
        agent_stats = cursor.fetchone()
        
        # System statistics
        cursor.execute("""
            SELECT 
                AVG(cpu_percent) as avg_cpu,
                AVG(memory_percent) as avg_memory,
                AVG(load_1min) as avg_load,
                MAX(active_agents) as max_active_agents
            FROM system_metrics
            WHERE timestamp > ?
        """, (since_timestamp,))
        
        system_stats = cursor.fetchone()
        
        # Task statistics
        cursor.execute("""
            SELECT 
                COUNT(*) as total_tasks,
                SUM(CASE WHEN success = 1 THEN 1 ELSE 0 END) as successful_tasks,
                AVG(duration_seconds) as avg_duration
            FROM task_metrics
            WHERE timestamp > ?
        """, (since_timestamp,))
        
        task_stats = cursor.fetchone()
        
        # Recent anomalies
        cursor.execute("""
            SELECT COUNT(*) as total_anomalies,
                   SUM(CASE WHEN severity = 'critical' THEN 1 ELSE 0 END) as critical_anomalies
            FROM anomalies
            WHERE detected_at > ? AND acknowledged = 0
        """, (since_timestamp,))
        
        anomaly_stats = cursor.fetchone()
        
        return {
            'period_hours': hours,
            'agents': {
                'total': agent_stats[0] or 0,
                'avg_cpu_percent': round(agent_stats[1] or 0, 2),
                'avg_memory_mb': round(agent_stats[2] or 0, 2),
                'total_tasks_completed': agent_stats[3] or 0
            },
            'system': {
                'avg_cpu_percent': round(system_stats[0] or 0, 2),
                'avg_memory_percent': round(system_stats[1] or 0, 2),
                'avg_load': round(system_stats[2] or 0, 2),
                'max_active_agents': system_stats[3] or 0
            },
            'tasks': {
                'total': task_stats[0] or 0,
                'successful': task_stats[1] or 0,
                'avg_duration_seconds': round(task_stats[2] or 0, 2),
                'success_rate': round((task_stats[1] or 0) / (task_stats[0] or 1) * 100, 2)
            },
            'anomalies': {
                'total': anomaly_stats[0] or 0,
                'critical': anomaly_stats[1] or 0
            }
        }
    
    def cleanup_old_metrics(self, days_to_keep: int = 30):
        """Remove metrics older than specified days"""
        cutoff_timestamp = int(time.time()) - (days_to_keep * 24 * 3600)
        cursor = self.conn.cursor()
        
        tables = ['agent_metrics', 'system_metrics', 'task_metrics']
        total_deleted = 0
        
        for table in tables:
            cursor.execute(f"DELETE FROM {table} WHERE timestamp < ?", (cutoff_timestamp,))
            total_deleted += cursor.rowcount
        
        self.conn.commit()
        return total_deleted
    
    def close(self):
        """Close database connection"""
        if self.conn:
            self.conn.close()
    
    def __enter__(self):
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()


def main():
    """CLI interface for metrics collector"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Agent Metrics Collector")
    parser.add_argument('--db', help="Path to metrics database")
    parser.add_argument('--agent-status', help="Path to agent status JSON file")
    parser.add_argument('--collect', action='store_true', help="Collect current metrics")
    parser.add_argument('--summary', action='store_true', help="Show metrics summary")
    parser.add_argument('--hours', type=int, default=24, help="Hours for summary (default: 24)")
    parser.add_argument('--detect-anomalies', action='store_true', help="Detect anomalies")
    parser.add_argument('--cleanup', type=int, help="Cleanup metrics older than N days")
    
    args = parser.parse_args()
    
    with MetricsCollector(args.db) as collector:
        if args.collect:
            # Collect agent metrics
            if args.agent_status:
                count = collector.collect_agent_metrics(args.agent_status)
                print(f"✅ Collected metrics from {count} agents")
            
            # Collect system metrics
            collector.collect_system_metrics()
            print("✅ Collected system metrics")
        
        if args.detect_anomalies:
            anomalies = collector.detect_anomalies()
            if anomalies:
                print(f"⚠️  Detected {len(anomalies)} anomalies:")
                for anomaly in anomalies:
                    print(f"  - [{anomaly['severity']}] {anomaly['type']}: {anomaly.get('agent', 'system')} "
                          f"value={anomaly['value']:.2f}, threshold={anomaly['threshold']}")
            else:
                print("✅ No anomalies detected")
        
        if args.summary:
            summary = collector.get_metrics_summary(args.hours)
            print(f"\n📊 Metrics Summary (last {args.hours} hours)")
            print("=" * 60)
            print(f"\nAgents:")
            print(f"  Total: {summary['agents']['total']}")
            print(f"  Avg CPU: {summary['agents']['avg_cpu_percent']}%")
            print(f"  Avg Memory: {summary['agents']['avg_memory_mb']:.2f} MB")
            print(f"  Tasks Completed: {summary['agents']['total_tasks_completed']}")
            
            print(f"\nSystem:")
            print(f"  Avg CPU: {summary['system']['avg_cpu_percent']}%")
            print(f"  Avg Memory: {summary['system']['avg_memory_percent']}%")
            print(f"  Avg Load: {summary['system']['avg_load']}")
            print(f"  Max Active Agents: {summary['system']['max_active_agents']}")
            
            print(f"\nTasks:")
            print(f"  Total: {summary['tasks']['total']}")
            print(f"  Successful: {summary['tasks']['successful']}")
            print(f"  Success Rate: {summary['tasks']['success_rate']}%")
            print(f"  Avg Duration: {summary['tasks']['avg_duration_seconds']:.2f}s")
            
            print(f"\nAnomalies:")
            print(f"  Total: {summary['anomalies']['total']}")
            print(f"  Critical: {summary['anomalies']['critical']}")
        
        if args.cleanup:
            deleted = collector.cleanup_old_metrics(args.cleanup)
            print(f"✅ Cleaned up {deleted} old metrics (kept last {args.cleanup} days)")


if __name__ == '__main__':
    main()
