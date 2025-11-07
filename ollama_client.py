#!/usr/bin/env python3
# ollama_client.py: Unified Ollama adapter for Python scripts
# Reads JSON from stdin: { task, prompt, system?, files[], images[], params? }
# Outputs JSON: { text, model, latency_ms, tokens_est?, fallback_used?, error? }
# Options: --dry-run (print routing without inference), --rollback (revert recent changes)

import json
import sys
import time
import subprocess
import os
import shutil
from typing import Dict, Any, List, Optional
from pathlib import Path

MODEL_REGISTRY = os.getenv("MODEL_REGISTRY", "model_registry.json")
RESOURCE_PROFILE = os.getenv("RESOURCE_PROFILE", "resource_profile.json")
CLOUD_FALLBACK_CONFIG = os.getenv(
    "CLOUD_FALLBACK_CONFIG", "config/cloud_fallback_config.json"
)
QUOTA_TRACKER = os.getenv("QUOTA_TRACKER", "metrics/quota_tracker.json")
ESCALATION_LOG = os.getenv("ESCALATION_LOG", "logs/cloud_escalation_log.jsonl")


class CloudFallbackPolicy:
    """Manages cloud fallback policy with circuit breaker and quotas"""

    def __init__(self):
        self.enabled = False
        self.config: Dict[str, Any] = {}
        self.quota_data: Dict[str, Any] = {}

        if os.path.exists(CLOUD_FALLBACK_CONFIG):
            self.enabled = True
            self.config = load_json(CLOUD_FALLBACK_CONFIG)
            if os.path.exists(QUOTA_TRACKER):
                self.quota_data = load_json(QUOTA_TRACKER)

    def check_quota(self, priority: str) -> bool:
        """Check if quota available for given priority"""
        if not self.enabled:
            return True

        allowed = self.config.get("allowed_priority_levels", [])
        if priority not in allowed:
            return False

        quotas = self.quota_data.get("quotas", {}).get(priority, {})
        daily_used = quotas.get("daily_used", 0)
        hourly_used = quotas.get("hourly_used", 0)
        daily_limit = quotas.get("daily_limit", 999999)
        hourly_limit = quotas.get("hourly_limit", 999999)

        return daily_used < daily_limit and hourly_used < hourly_limit

    def check_circuit_breaker(self, priority: str) -> bool:
        """Check if circuit breaker allows requests"""
        if not self.enabled:
            return True

        cb = self.quota_data.get("circuit_breaker", {}).get(priority, {})
        state = cb.get("state", "closed")

        if state == "open":
            # Check if reset time has passed
            opened_at = cb.get("opened_at")
            if opened_at:
                from datetime import datetime, timedelta, timezone

                opened_time = datetime.fromisoformat(opened_at.replace("Z", "+00:00"))
                reset_minutes = self.config.get("circuit_breaker", {}).get(
                    "reset_after_minutes", 30
                )
                if datetime.now(timezone.utc) - opened_time >= timedelta(
                    minutes=reset_minutes
                ):
                    # Reset circuit breaker
                    self.quota_data["circuit_breaker"][priority]["state"] = "closed"
                    self.quota_data["circuit_breaker"][priority]["failure_count"] = 0
                    self.quota_data["circuit_breaker"][priority]["opened_at"] = None
                    save_json(QUOTA_TRACKER, self.quota_data)
                    return True
            return False

        return True

    def record_failure(self, priority: str) -> None:
        """Record a failure and potentially trip circuit breaker"""
        if not self.enabled:
            return

        from datetime import datetime, timezone

        now = datetime.now(timezone.utc).isoformat() + "Z"

        if "circuit_breaker" not in self.quota_data:
            self.quota_data["circuit_breaker"] = {}
        if priority not in self.quota_data["circuit_breaker"]:
            self.quota_data["circuit_breaker"][priority] = {
                "state": "closed",
                "failure_count": 0,
                "last_failure": None,
                "opened_at": None,
            }

        cb = self.quota_data["circuit_breaker"][priority]
        cb["failure_count"] = cb.get("failure_count", 0) + 1
        cb["last_failure"] = now

        # Trip circuit breaker if threshold exceeded
        threshold = self.config.get("circuit_breaker", {}).get("failure_threshold", 3)
        if cb["failure_count"] >= threshold:
            cb["state"] = "open"
            cb["opened_at"] = now
            print(f"Circuit breaker tripped for priority: {priority}", file=sys.stderr)

        save_json(QUOTA_TRACKER, self.quota_data)

    def increment_quota(self, priority: str) -> None:
        """Increment quota usage for given priority"""
        if not self.enabled:
            return

        if "quotas" not in self.quota_data:
            self.quota_data["quotas"] = {}
        if priority not in self.quota_data["quotas"]:
            self.quota_data["quotas"][priority] = {"daily_used": 0, "hourly_used": 0}

        self.quota_data["quotas"][priority]["daily_used"] += 1
        self.quota_data["quotas"][priority]["hourly_used"] += 1
        save_json(QUOTA_TRACKER, self.quota_data)

    def log_escalation(
        self,
        task: str,
        priority: str,
        reason: str,
        model_attempted: str,
        cloud_provider: str,
    ) -> None:
        """Log cloud escalation event"""
        if not self.enabled:
            return

        from datetime import datetime, timezone

        timestamp = datetime.now(timezone.utc).isoformat() + "Z"

        quotas = self.quota_data.get("quotas", {}).get(priority, {})
        daily_limit = quotas.get("daily_limit", 0)
        daily_used = quotas.get("daily_used", 0)
        quota_remaining = daily_limit - daily_used

        event = {
            "timestamp": timestamp,
            "task": task,
            "priority": priority,
            "reason": reason,
            "model_attempted": model_attempted,
            "cloud_provider": cloud_provider,
            "quota_remaining": quota_remaining,
        }

        # Append to escalation log
        with open(ESCALATION_LOG, "a") as f:
            f.write(json.dumps(event) + "\n")

        # Update dashboard metrics
        dashboard_file = os.getenv("DASHBOARD_DATA", "dashboard_data.json")
        if os.path.exists(dashboard_file):
            try:
                data = load_json(dashboard_file)
                if "ai_metrics" not in data:
                    data["ai_metrics"] = {}
                data["ai_metrics"]["escalation_count"] = (
                    data["ai_metrics"].get("escalation_count", 0) + 1
                )
                total_calls = data.get("ollama_metrics", {}).get("total_calls", 1)
                data["ai_metrics"]["fallback_rate"] = data["ai_metrics"][
                    "escalation_count"
                ] / max(total_calls, 1)
                save_json(dashboard_file, data)
            except Exception as e:
                print(f"Warning: Failed to update dashboard: {e}", file=sys.stderr)


def load_json(file_path: str) -> Dict[str, Any]:
    with open(file_path, "r") as f:
        return json.load(f)


def save_json(file_path: str, data: Dict[str, Any]) -> None:
    with open(file_path, "w") as f:
        json.dump(data, f, indent=2)


def extract_text_from_pdf(pdf_path: str) -> str:
    """Extract text from PDF using pdftotext if available."""
    try:
        result = subprocess.run(
            ["pdftotext", "-layout", pdf_path, "-"],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode == 0:
            return result.stdout
        else:
            return ""
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return ""


def run_ollama(model: str, prompt: str, options: Dict[str, Any]) -> Optional[str]:
    """Run Ollama with given model and prompt."""
    cmd = ["ollama", "run", model, "--format", "json"]
    for key, value in options.items():
        if key.startswith("num_") or key in [
            "temperature",
            "top_p",
            "top_k",
            "repeat_penalty",
            "num_predict",
        ]:
            cmd.extend(["--" + key.replace("_", "-"), str(value)])
    try:
        result = subprocess.run(
            cmd, input=prompt, capture_output=True, text=True, timeout=300
        )
        if result.returncode == 0:
            return result.stdout.strip()
        else:
            return None
    except subprocess.TimeoutExpired:
        return None


def log_usage_metrics(
    task: str, model: str, latency_ms: int, tokens_est: int, status: str
) -> None:
    """Log usage metrics to dashboard_data.json"""
    dashboard_file = os.getenv("DASHBOARD_DATA", "dashboard_data.json")
    timestamp = int(time.time())

    try:
        if os.path.exists(dashboard_file):
            with open(dashboard_file, "r") as f:
                data = json.load(f)
        else:
            data = {}

        # Initialize ollama_metrics if not exists
        if "ollama_metrics" not in data:
            data["ollama_metrics"] = {}

        metrics = data["ollama_metrics"]
        metrics["last_updated"] = timestamp
        metrics["total_calls"] = metrics.get("total_calls", 0) + 1
        metrics["successful_calls"] = metrics.get("successful_calls", 0) + (
            1 if status == "success" else 0
        )
        metrics["failed_calls"] = metrics.get("failed_calls", 0) + (
            1 if status == "failed" else 0
        )
        metrics["total_latency_ms"] = metrics.get("total_latency_ms", 0) + latency_ms
        metrics["total_tokens"] = metrics.get("total_tokens", 0) + tokens_est

        # Task usage
        if "task_usage" not in metrics:
            metrics["task_usage"] = {}
        metrics["task_usage"][task] = metrics["task_usage"].get(task, 0) + 1

        # Model usage
        if "model_usage" not in metrics:
            metrics["model_usage"] = {}
        metrics["model_usage"][model] = metrics["model_usage"].get(model, 0) + 1

        # Recent calls (keep last 10)
        if "recent_calls" not in metrics:
            metrics["recent_calls"] = []
        metrics["recent_calls"].append(
            {
                "timestamp": timestamp,
                "task": task,
                "model": model,
                "latency_ms": latency_ms,
                "tokens_est": tokens_est,
                "status": status,
            }
        )
        metrics["recent_calls"] = metrics["recent_calls"][-10:]

        save_json(dashboard_file, data)
    except Exception as e:
        print(f"Warning: Failed to log metrics: {e}", file=sys.stderr)


def create_backup() -> None:
    """Create backup of model registry for rollback"""
    backup_dir = Path("./ollama_backups")
    backup_dir.mkdir(exist_ok=True)
    registry_path = Path(MODEL_REGISTRY)
    if registry_path.exists():
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        backup_path = (
            backup_dir / f"{registry_path.stem}_{timestamp}{registry_path.suffix}"
        )
        shutil.copy2(registry_path, backup_path)


def rollback_changes() -> Dict[str, Any]:
    """Rollback to most recent backup"""
    backup_dir = Path("./ollama_backups")
    if not backup_dir.exists():
        return {"error": "No backups found for rollback"}

    backups = sorted(
        backup_dir.glob("*.json"), key=lambda x: x.stat().st_mtime, reverse=True
    )
    if not backups:
        return {"error": "No backups found for rollback"}

    latest_backup = backups[0]
    shutil.copy2(latest_backup, MODEL_REGISTRY)
    return {"status": "rollback_complete", "restored_from": str(latest_backup)}


def main():
    # Parse command line arguments
    dry_run = "--dry-run" in sys.argv
    rollback = "--rollback" in sys.argv
    # Initialize policy
    policy = CloudFallbackPolicy()

    if rollback:
        result = rollback_changes()
        print(json.dumps(result))
        sys.exit(0 if "status" in result else 1)

    input_data = json.load(sys.stdin)
    task = input_data.get("task")
    prompt = input_data.get("prompt")
    system = input_data.get("system", "")
    files = input_data.get("files", [])
    images = input_data.get("images", [])
    params = input_data.get("params", {})

    if not task or not prompt:
        print(json.dumps({"error": "Missing task or prompt"}), file=sys.stderr)
        sys.exit(1)

    registry = load_json(MODEL_REGISTRY)
    if task not in registry:
        print(json.dumps({"error": "Task not found in registry"}), file=sys.stderr)
        sys.exit(1)

    task_config = registry[task]
    primary_model = task_config["primaryModel"]
    priority = task_config.get("priority", "medium")
    fallbacks = task_config.get("fallbacks", [])
    preset = task_config.get("preset", {})
    preprocess = task_config.get("preprocess", {})

    # Preprocess files
    full_prompt = prompt
    if system:
        full_prompt = f"{system}\n\n{prompt}"

    if preprocess.get("pdfToText") and files:
        for file in files:
            if file.endswith(".pdf"):
                text = extract_text_from_pdf(file)
                if text:
                    full_prompt += f"\n\nPDF Content:\n{text}"
                elif preprocess.get("ocrIfNoText"):
                    # Placeholder for OCR; assume vision model handles images
                    pass

    # For images, assume vision model; append base64 or path (simplified)
    if preprocess.get("imageToVision") and images:
        # Ollama vision support; append image paths (assumes model supports)
        full_prompt += "\n\nImages: " + ", ".join(images)

    # Resource limits
    profile = load_json(RESOURCE_PROFILE)
    os.environ["OLLAMA_NUM_PARALLEL"] = str(profile.get("OLLAMA_NUM_PARALLEL", 1))

    # Try models
    models = [primary_model] + fallbacks
    local_failed = False
    for i, model in enumerate(models):
        if dry_run:
            # Dry run mode: just return routing info without inference
            result = {
                "dry_run": True,
                "model": model,
                "task": task,
                "routing_info": f"Would call {model} for {task}",
                "fallback_used": i > 0,
            }
            print(json.dumps(result))
            sys.exit(0)

        start_time = time.time()
        output = run_ollama(model, full_prompt, preset)
        latency_ms = int((time.time() - start_time) * 1000)
        if output:
            tokens_est = len(full_prompt.split()) + len(
                output.split()
            )  # Rough estimate

            # Create backup before logging successful metrics
            create_backup()

            # Log usage metrics
            log_usage_metrics(task, model, latency_ms, tokens_est, "success")

            result = {
                "text": output,
                "model": model,
                "latency_ms": latency_ms,
                "tokens_est": tokens_est,
                "fallback_used": i > 0,
            }
            print(json.dumps(result))
            sys.exit(0)
        else:
            # Record failure for policy tracking and log failed attempt
            policy.record_failure(priority)
            log_usage_metrics(task, model, 0, 0, "failed")
            local_failed = True

    # All local models failed - check if cloud escalation is allowed
    if local_failed and policy.enabled:
        if not policy.check_quota(priority):
            print(
                json.dumps(
                    {
                        "error": "All local models failed and cloud quota exhausted",
                        "fallback_used": False,
                        "reason": "quota_exhausted",
                    }
                ),
                file=sys.stderr,
            )
            sys.exit(1)

        if not policy.check_circuit_breaker(priority):
            print(
                json.dumps(
                    {
                        "error": "All local models failed and circuit breaker open",
                        "fallback_used": False,
                        "reason": "circuit_breaker_open",
                    }
                ),
                file=sys.stderr,
            )
            sys.exit(1)

        # Log cloud escalation (would attempt cloud here if enabled)
        policy.log_escalation(
            task, priority, "local_failure", primary_model, "ollama_cloud"
        )
        policy.increment_quota(priority)

        # For now, cloud is disabled, so this is just logging
        print(
            json.dumps(
                {
                    "error": "All local models failed, cloud escalation logged but not enabled",
                    "fallback_used": False,
                    "reason": "cloud_disabled",
                }
            ),
            file=sys.stderr,
        )
        sys.exit(1)

    # All failed
    print(
        json.dumps({"error": "All models failed", "fallback_used": True}),
        file=sys.stderr,
    )
    sys.exit(1)


if __name__ == "__main__":
    main()
