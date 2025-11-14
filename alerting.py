#!/usr/bin/env python3
"""Send alerts when autonomy score drops below threshold.
Supports webhook (Slack/Discord) and email (SMTP).
Configure via environment variables or alerting_config.json.
"""
import json, os, sys, datetime, subprocess

ROOT = os.path.dirname(os.path.abspath(__file__))
CONFIG_FILE = os.path.join(ROOT, "alerting_config.json")
TODOS_FILE = os.path.join(ROOT, "unified_todos.json")
PRED_FILE = os.path.join(ROOT, "predictive_data.json")

THRESHOLD = int(os.getenv("AUTONOMY_SCORE_THRESHOLD", "60"))


def load_config():
    if os.path.exists(CONFIG_FILE):
        return json.load(open(CONFIG_FILE))
    return {
        "webhook_url": os.getenv("ALERT_WEBHOOK_URL"),
        "email_enabled": os.getenv("ALERT_EMAIL_ENABLED", "false").lower() == "true",
        "email_to": os.getenv("ALERT_EMAIL_TO"),
        "email_from": os.getenv("ALERT_EMAIL_FROM"),
        "smtp_server": os.getenv("ALERT_SMTP_SERVER"),
        "smtp_port": int(os.getenv("ALERT_SMTP_PORT", "587")),
        "smtp_user": os.getenv("ALERT_SMTP_USER"),
        "smtp_password": os.getenv("ALERT_SMTP_PASSWORD"),
    }


def compute_autonomy_score():
    """Simplified score calculation matching dashboard logic."""
    score = 0
    # Task management (30 pts)
    if os.path.exists(TODOS_FILE):
        todos = json.load(open(TODOS_FILE)).get("todos", [])
        if todos:
            completed = [t for t in todos if t.get("status") == "completed"]
            assigned = [t for t in todos if t.get("assignee")]
            auto_gen = [
                t for t in todos if (t.get("metadata") or {}).get("auto_generated")
            ]
            score += int((len(completed) * 10 / len(todos)) if todos else 0)
            score += int((len(assigned) * 10 / len(todos)) if todos else 0)
            score += int((len(auto_gen) * 10 / len(todos)) if todos else 0)

    # System health (30 pts) - assume 100% if tests passed recently
    test_files = sorted(
        [
            f
            for f in os.listdir(os.path.join(ROOT, "reports"))
            if f.startswith("test_results_") and f.endswith(".json")
        ]
    )
    if test_files:
        latest = os.path.join(ROOT, "reports", test_files[-1])
        test_data = json.load(open(latest))
        passed = test_data.get("summary", {}).get("passed", 0)
        total = test_data.get("summary", {}).get("total", 1)
        score += int((passed * 30 / total) if total else 0)

    # Predictive (25 pts)
    if os.path.exists(PRED_FILE):
        pred = json.load(open(PRED_FILE))
        predictions = len(pred.get("failure_predictions", []))
        high_conf = len(
            [
                p
                for p in pred.get("failure_predictions", [])
                if p.get("confidence", 0) > 0.8
            ]
        )
        healing = len(pred.get("self_healing_actions", {}))
        score += min(predictions * 5 + high_conf * 10 + healing * 10, 40)

    return min(score, 100)


def send_webhook(config, score, message):
    url = config.get("webhook_url")
    if not url:
        return
    try:
        import urllib.request

        payload = json.dumps(
            {
                "text": f"⚠️ Autonomy Alert: Score dropped to {score}/100\n{message}",
                "username": "Autonomy Bot",
            }
        ).encode("utf-8")
        req = urllib.request.Request(
            url, data=payload, headers={"Content-Type": "application/json"}
        )
        urllib.request.urlopen(req, timeout=10)
        print(f"Webhook sent to {url}")
    except Exception as e:
        print(f"Webhook failed: {e}", file=sys.stderr)


def send_email(config, score, message):
    if not config.get("email_enabled"):
        return
    try:
        import smtplib
        from email.mime.text import MIMEText

        msg = MIMEText(f"Autonomy score dropped to {score}/100.\n\n{message}")
        msg["Subject"] = f"Autonomy Alert: Score {score}/100"
        msg["From"] = config.get("email_from")
        msg["To"] = config.get("email_to")

        server = smtplib.SMTP(config.get("smtp_server"), config.get("smtp_port"))
        server.starttls()
        server.login(config.get("smtp_user"), config.get("smtp_password"))
        server.send_message(msg)
        server.quit()
        print(f'Email sent to {config.get("email_to")}')
    except Exception as e:
        print(f"Email failed: {e}", file=sys.stderr)


def main():
    score = compute_autonomy_score()
    print(f"Current autonomy score: {score}/100")

    if score < THRESHOLD:
        config = load_config()
        message = f"Threshold: {THRESHOLD}. Check dashboard for details."
        print(f"Score below threshold ({THRESHOLD}), sending alerts...")
        send_webhook(config, score, message)
        send_email(config, score, message)
    else:
        print(f"Score above threshold ({THRESHOLD}), no alerts needed.")


if __name__ == "__main__":
    main()
