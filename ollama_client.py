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
            # Log failed attempt
            log_usage_metrics(task, model, 0, 0, "failed")

    # All failed
    print(
        json.dumps({"error": "All models failed", "fallback_used": True}),
        file=sys.stderr,
    )
    sys.exit(1)


if __name__ == "__main__":
    main()
