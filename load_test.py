#!/usr/bin/env python3
"""
Load Testing Framework for MCP Server

Tests the MCP server under sustained load of 1000 requests per second.
Validates performance, stability, and resource usage under production-like conditions.
"""

import asyncio
import aiohttp
import time
import json
import statistics
from datetime import datetime
import argparse
import sys
from pathlib import Path
import psutil
import threading
import signal
import os


class LoadTester:
    """Load testing framework for MCP server."""

    def __init__(
        self, server_url="http://localhost:5005", target_rps=1000, duration_seconds=300
    ):
        self.server_url = server_url.rstrip("/")
        self.target_rps = target_rps
        self.duration_seconds = duration_seconds
        self.results = {
            "start_time": None,
            "end_time": None,
            "total_requests": 0,
            "successful_requests": 0,
            "failed_requests": 0,
            "response_times": [],
            "errors": [],
            "target_rps": target_rps,
            "actual_rps": 0,
            "duration_seconds": duration_seconds,
            "system_metrics": [],
        }
        self.running = False
        self.monitoring_thread = None

    async def make_request(self, session, endpoint="/health", method="GET", data=None):
        """Make a single HTTP request."""
        start_time = time.time()

        try:
            url = f"{self.server_url}{endpoint}"

            headers = {"X-Client-Id": "test_client"}  # Bypass rate limiting

            if method == "GET":
                async with session.get(url, headers=headers) as response:
                    await response.text()
                    status = response.status
            elif method == "POST":
                headers["Content-Type"] = "application/json"
                async with session.post(url, json=data, headers=headers) as response:
                    await response.text()
                    status = response.status
            else:
                raise ValueError(f"Unsupported method: {method}")

            response_time = (time.time() - start_time) * 1000  # Convert to milliseconds
            success = status == 200

            return {
                "success": success,
                "response_time": response_time,
                "status_code": status,
                "endpoint": endpoint,
            }

        except Exception as e:
            response_time = (time.time() - start_time) * 1000
            return {
                "success": False,
                "response_time": response_time,
                "error": str(e),
                "endpoint": endpoint,
            }

    async def worker(self, worker_id, request_queue):
        """Worker coroutine that processes requests."""
        async with aiohttp.ClientSession(
            connector=aiohttp.TCPConnector(limit=1000),
            timeout=aiohttp.ClientTimeout(total=30),
        ) as session:

            while self.running:
                try:
                    # Get next request from queue
                    request = await request_queue.get()

                    if request is None:  # Poison pill
                        break

                    result = await self.make_request(
                        session,
                        request.get("endpoint", "/health"),
                        request.get("method", "GET"),
                        request.get("data"),
                    )

                    # Record result
                    self.results["total_requests"] += 1
                    if result["success"]:
                        self.results["successful_requests"] += 1
                    else:
                        self.results["failed_requests"] += 1
                        if "error" in result:
                            self.results["errors"].append(result)

                    self.results["response_times"].append(result["response_time"])

                    request_queue.task_done()

                except Exception as e:
                    print(f"Worker {worker_id} error: {e}")
                    continue

    def generate_request_pattern(self):
        """Generate a realistic request pattern for testing."""
        # Mix of different endpoints to simulate real usage
        endpoints = [
            ("/health", "GET", None, 0.3),  # 30% health checks
            ("/api/agents/status", "GET", None, 0.2),  # 20% agent status
            ("/api/tasks/analytics", "GET", None, 0.15),  # 15% task analytics
            ("/api/metrics/system", "GET", None, 0.15),  # 15% system metrics
            ("/api/ml/analytics", "GET", None, 0.1),  # 10% ML analytics
            ("/api/umami/stats", "GET", None, 0.05),  # 5% umami stats
            ("/api/dashboard/refresh", "POST", {}, 0.05),  # 5% dashboard refresh
        ]

        import random

        endpoint = random.choices(
            [ep[0] for ep in endpoints], weights=[ep[3] for ep in endpoints]
        )[0]

        method = next(ep[1] for ep in endpoints if ep[0] == endpoint)
        data = next(ep[2] for ep in endpoints if ep[0] == endpoint)

        return {"endpoint": endpoint, "method": method, "data": data}

    def monitor_system_resources(self):
        """Monitor system resources during the test."""
        while self.running:
            try:
                cpu_percent = psutil.cpu_percent(interval=1)
                memory = psutil.virtual_memory()
                disk = psutil.disk_usage("/")

                metrics = {
                    "timestamp": datetime.now().isoformat(),
                    "cpu_percent": cpu_percent,
                    "memory_percent": memory.percent,
                    "memory_used_gb": memory.used / (1024**3),
                    "disk_percent": disk.percent,
                    "load_average": (
                        psutil.getloadavg() if hasattr(psutil, "getloadavg") else None
                    ),
                }

                self.results["system_metrics"].append(metrics)
                time.sleep(5)  # Sample every 5 seconds

            except Exception as e:
                print(f"Monitoring error: {e}")
                time.sleep(5)

    async def run_load_test(self):
        """Run the load test."""
        print(
            f"🚀 Starting load test: {self.target_rps} RPS for {self.duration_seconds}s"
        )
        print(f"Target server: {self.server_url}")
        print("=" * 60)

        self.running = True
        self.results["start_time"] = datetime.now().isoformat()

        # Start system monitoring
        self.monitoring_thread = threading.Thread(target=self.monitor_system_resources)
        self.monitoring_thread.daemon = True
        self.monitoring_thread.start()

        # Calculate timing
        interval = 1.0 / self.target_rps  # Time between requests
        num_workers = min(100, self.target_rps // 10)  # Scale workers with target RPS

        print(f"Using {num_workers} worker coroutines")
        print(f"Request interval: {interval:.6f}s")

        # Create request queue
        request_queue = asyncio.Queue(maxsize=num_workers * 10)

        # Start workers
        workers = []
        for i in range(num_workers):
            worker_task = asyncio.create_task(self.worker(i, request_queue))
            workers.append(worker_task)

        # Generate and queue requests
        start_time = time.time()
        request_count = 0

        try:
            while self.running and (time.time() - start_time) < self.duration_seconds:
                # Generate request
                request = self.generate_request_pattern()
                await request_queue.put(request)
                request_count += 1

                # Sleep to maintain target RPS
                await asyncio.sleep(interval)

        except KeyboardInterrupt:
            print("\n⏹️ Load test interrupted")

        # Stop workers
        self.running = False
        for _ in range(num_workers):
            await request_queue.put(None)  # Poison pills

        # Wait for workers to finish
        await asyncio.gather(*workers, return_exceptions=True)

        # Stop monitoring
        if self.monitoring_thread:
            self.monitoring_thread.join(timeout=5)

        # Calculate final results
        end_time = time.time()
        actual_duration = end_time - start_time
        self.results["end_time"] = datetime.now().isoformat()
        self.results["actual_rps"] = (
            request_count / actual_duration if actual_duration > 0 else 0
        )

        return self.results

    def calculate_statistics(self):
        """Calculate performance statistics."""
        if not self.results["response_times"]:
            return {}

        response_times = self.results["response_times"]

        stats = {
            "total_requests": self.results["total_requests"],
            "successful_requests": self.results["successful_requests"],
            "failed_requests": self.results["failed_requests"],
            "success_rate": (
                self.results["successful_requests"] / self.results["total_requests"]
                if self.results["total_requests"] > 0
                else 0
            ),
            "target_rps": self.results["target_rps"],
            "actual_rps": self.results["actual_rps"],
            "rps_achievement": (
                self.results["actual_rps"] / self.results["target_rps"]
                if self.results["target_rps"] > 0
                else 0
            ),
            "response_time_stats": {
                "min_ms": min(response_times),
                "max_ms": max(response_times),
                "mean_ms": statistics.mean(response_times),
                "median_ms": statistics.median(response_times),
                "p95_ms": statistics.quantiles(response_times, n=20)[
                    18
                ],  # 95th percentile
                "p99_ms": (
                    statistics.quantiles(response_times, n=100)[98]
                    if len(response_times) >= 100
                    else max(response_times)
                ),
            },
            "error_breakdown": {},
        }

        # Error analysis
        error_counts = {}
        for error in self.results["errors"]:
            error_type = error.get("error", "unknown")
            error_counts[error_type] = error_counts.get(error_type, 0) + 1

        stats["error_breakdown"] = error_counts

        return stats

    def print_results(self, stats):
        """Print test results in a readable format."""
        print("\n" + "=" * 80)
        print("LOAD TEST RESULTS")
        print("=" * 80)

        print(f"Duration: {self.results['duration_seconds']}s")
        print(f"Target RPS: {self.results['target_rps']}")
        print(".1f")
        print(".1%")

        print(f"\n📊 REQUESTS:")
        print(f"Total: {stats['total_requests']}")
        print(f"Successful: {stats['successful_requests']}")
        print(f"Failed: {stats['failed_requests']}")
        print(".1%")

        print(f"\n⏱️ RESPONSE TIMES (ms):")
        rt = stats["response_time_stats"]
        print(".1f")
        print(".1f")
        print(".1f")
        print(".1f")
        print(".1f")
        print(".1f")

        if stats["error_breakdown"]:
            print(f"\n❌ ERRORS:")
            for error_type, count in stats["error_breakdown"].items():
                print(f"  {error_type}: {count}")

        # Performance assessment
        success_rate = stats["success_rate"]
        rps_achievement = stats["rps_achievement"]
        p95_response_time = rt["p95_ms"]

        print(f"\n🎯 PERFORMANCE ASSESSMENT:")
        if (
            success_rate >= 0.99
            and rps_achievement >= 0.95
            and p95_response_time < 1000
        ):
            print("🟢 EXCELLENT: System handles load well")
        elif (
            success_rate >= 0.95 and rps_achievement >= 0.9 and p95_response_time < 2000
        ):
            print("🟡 GOOD: System handles load adequately")
        elif success_rate >= 0.9 and rps_achievement >= 0.8:
            print("🟠 WARNING: System struggling under load")
        else:
            print("🔴 CRITICAL: System failing under load")

        print("=" * 80)

    def save_results(self, output_file=None):
        """Save results to JSON file."""
        if not output_file:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_file = f"load_test_results_{timestamp}.json"

        results_with_stats = self.results.copy()
        results_with_stats["statistics"] = self.calculate_statistics()

        with open(output_file, "w") as f:
            json.dump(results_with_stats, f, indent=2)

        print(f"💾 Results saved to: {output_file}")
        return output_file


async def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(description="MCP Server Load Testing Framework")
    parser.add_argument("--url", default="http://localhost:5005", help="MCP server URL")
    parser.add_argument(
        "--rps", type=int, default=1000, help="Target requests per second"
    )
    parser.add_argument(
        "--duration", type=int, default=300, help="Test duration in seconds"
    )
    parser.add_argument("--output", help="Output file for results")
    parser.add_argument("--quiet", action="store_true", help="Suppress detailed output")

    args = parser.parse_args()

    # Validate server is running
    print("🔍 Checking if MCP server is running...")
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(f"{args.url}/health") as response:
                if response.status != 200:
                    print(
                        f"❌ MCP server health check failed (status: {response.status})"
                    )
                    sys.exit(1)
    except Exception as e:
        print(f"❌ Cannot connect to MCP server: {e}")
        print("Make sure the MCP server is running on the specified URL")
        sys.exit(1)

    print("✅ MCP server is responding")

    # Run load test
    tester = LoadTester(args.url, args.rps, args.duration)

    def signal_handler(signum, frame):
        print("\n⏹️ Received interrupt signal, stopping load test...")
        tester.running = False

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    try:
        results = await tester.run_load_test()
        stats = tester.calculate_statistics()

        if not args.quiet:
            tester.print_results(stats)

        output_file = tester.save_results(args.output)

        # Exit with appropriate code based on performance
        success_rate = stats["success_rate"]
        rps_achievement = stats["rps_achievement"]

        # More lenient criteria for development environment
        if success_rate >= 0.95 and rps_achievement >= 0.75:
            print("✅ Load test PASSED")
            sys.exit(0)
        else:
            print("❌ Load test FAILED")
            print(
                f"   Success rate: {success_rate:.1%}, RPS achievement: {rps_achievement:.1%}"
            )
            sys.exit(1)

    except Exception as e:
        print(f"💥 Load test failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
