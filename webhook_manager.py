#!/usr/bin/env python3
"""
Webhook Manager - Event-driven webhook system for MCP Server

Provides webhook registration, event publishing, and delivery management.
"""

import asyncio
import hashlib
import hmac
import json
import logging
import os
import sys
import uuid
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional, Callable
from urllib.parse import urlparse

import aiohttp

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@dataclass
class WebhookConfig:
    """Webhook configuration"""

    url: str
    events: List[str] = field(default_factory=list)
    id: str = field(default_factory=lambda: str(uuid.uuid4()))
    secret: str = ""
    headers: Dict[str, str] = field(default_factory=dict)
    enabled: bool = True
    created_at: str = field(default_factory=lambda: datetime.now().isoformat())
    updated_at: str = field(default_factory=lambda: datetime.now().isoformat())
    retry_count: int = 3
    timeout: int = 30
    rate_limit: int = 100  # requests per minute


@dataclass
class WebhookDelivery:
    """Webhook delivery record"""

    webhook_id: str
    event_type: str
    payload: Dict[str, Any]
    id: str = field(default_factory=lambda: str(uuid.uuid4()))
    status: str = "pending"  # pending, success, failed, retry
    status_code: Optional[int] = None
    response_body: Optional[str] = None
    error_message: Optional[str] = None
    attempt_count: int = 0
    created_at: str = field(default_factory=lambda: datetime.now().isoformat())
    delivered_at: Optional[str] = None
    next_retry_at: Optional[str] = None


class WebhookError(Exception):
    """Base webhook error"""

    pass


class WebhookValidationError(WebhookError):
    """Webhook validation error"""

    pass


class WebhookDeliveryError(WebhookError):
    """Webhook delivery error"""

    pass


class WebhookManager:
    """Webhook manager for event-driven notifications"""

    def __init__(
        self,
        config_file: str = "config/webhooks.json",
        delivery_log: str = "logs/webhook_deliveries.jsonl",
    ):
        self.config_file = config_file
        self.delivery_log = delivery_log
        self.webhooks: Dict[str, WebhookConfig] = {}
        self.event_subscriptions: Dict[str, List[str]] = {}  # event -> [webhook_ids]
        self.delivery_queue: asyncio.Queue = asyncio.Queue()
        self.rate_limiters: Dict[str, Dict] = {}  # webhook_id -> rate limit info

        # Create directories
        import os

        os.makedirs(os.path.dirname(config_file), exist_ok=True)
        os.makedirs(os.path.dirname(delivery_log), exist_ok=True)

        # Setup logging
        self.logger = logging.getLogger(__name__)

        # Load configuration
        self.load_config()

    def validate_webhook_url(self, url: str) -> bool:
        """Validate webhook URL"""
        try:
            parsed = urlparse(url)
            return parsed.scheme in ["http", "https"] and bool(parsed.netloc)
        except Exception:
            return False

    def generate_webhook_secret(self) -> str:
        """Generate a secure webhook secret"""
        return hashlib.sha256(str(uuid.uuid4()).encode()).hexdigest()[:32]

    def register_webhook(
        self,
        url: str,
        events: List[str],
        secret: str = None,
        headers: Dict[str, str] = None,
        **kwargs,
    ) -> str:
        """Register a new webhook"""
        if not self.validate_webhook_url(url):
            raise WebhookValidationError(f"Invalid webhook URL: {url}")

        if not events:
            raise WebhookValidationError("At least one event type required")

        webhook_id = str(uuid.uuid4())
        secret = secret or self.generate_webhook_secret()

        webhook = WebhookConfig(
            id=webhook_id,
            url=url,
            events=events,
            secret=secret,
            headers=headers or {},
            **kwargs,
        )

        self.webhooks[webhook_id] = webhook

        # Update event subscriptions
        for event in events:
            if event not in self.event_subscriptions:
                self.event_subscriptions[event] = []
            self.event_subscriptions[event].append(webhook_id)

        self.save_config()
        self.logger.info(f"Registered webhook: {webhook_id} for events: {events}")

        return webhook_id

    def unregister_webhook(self, webhook_id: str) -> bool:
        """Unregister a webhook"""
        if webhook_id not in self.webhooks:
            return False

        webhook = self.webhooks[webhook_id]

        # Remove from event subscriptions
        for event in webhook.events:
            if event in self.event_subscriptions:
                self.event_subscriptions[event] = [
                    wid for wid in self.event_subscriptions[event] if wid != webhook_id
                ]
                if not self.event_subscriptions[event]:
                    del self.event_subscriptions[event]

        del self.webhooks[webhook_id]
        self.save_config()

        self.logger.info(f"Unregistered webhook: {webhook_id}")
        return True

    def update_webhook(self, webhook_id: str, **updates) -> bool:
        """Update webhook configuration"""
        if webhook_id not in self.webhooks:
            return False

        webhook = self.webhooks[webhook_id]
        old_events = set(webhook.events)

        # Update fields
        for key, value in updates.items():
            if hasattr(webhook, key):
                setattr(webhook, key, value)

        webhook.updated_at = datetime.now().isoformat()

        # Update event subscriptions if events changed
        new_events = set(webhook.events)
        if old_events != new_events:
            # Remove from old events
            for event in old_events - new_events:
                if event in self.event_subscriptions:
                    self.event_subscriptions[event] = [
                        wid
                        for wid in self.event_subscriptions[event]
                        if wid != webhook_id
                    ]

            # Add to new events
            for event in new_events - old_events:
                if event not in self.event_subscriptions:
                    self.event_subscriptions[event] = []
                self.event_subscriptions[event].append(webhook_id)

        self.save_config()
        return True

    def get_webhook(self, webhook_id: str) -> Optional[WebhookConfig]:
        """Get webhook configuration"""
        return self.webhooks.get(webhook_id)

    def list_webhooks(self) -> List[WebhookConfig]:
        """List all webhooks"""
        return list(self.webhooks.values())

    def get_webhooks_for_event(self, event_type: str) -> List[WebhookConfig]:
        """Get webhooks subscribed to an event"""
        webhook_ids = self.event_subscriptions.get(event_type, [])
        return [self.webhooks[wid] for wid in webhook_ids if wid in self.webhooks]

    def emit_event(self, event_type: str, payload: Dict[str, Any]) -> None:
        """Emit an event to subscribed webhooks"""
        webhooks = self.get_webhooks_for_event(event_type)

        if not webhooks:
            return

        self.logger.info(f"Emitting event '{event_type}' to {len(webhooks)} webhooks")

        for webhook in webhooks:
            if not webhook.enabled:
                continue

            # Check rate limit
            if not self.check_rate_limit(webhook.id):
                self.logger.warning(f"Rate limit exceeded for webhook {webhook.id}")
                continue

            # Create delivery record
            delivery = WebhookDelivery(
                webhook_id=webhook.id, event_type=event_type, payload=payload
            )

            # Add to delivery queue
            asyncio.create_task(self.delivery_queue.put(delivery))

    def check_rate_limit(self, webhook_id: str) -> bool:
        """Check if webhook is within rate limit"""
        now = datetime.now()
        rate_info = self.rate_limiters.get(
            webhook_id, {"requests": [], "window_start": now}
        )

        # Clean old requests (older than 1 minute)
        cutoff = now - timedelta(minutes=1)
        rate_info["requests"] = [
            req_time for req_time in rate_info["requests"] if req_time > cutoff
        ]

        webhook = self.webhooks.get(webhook_id)
        if not webhook:
            return False

        # Check rate limit
        if len(rate_info["requests"]) >= webhook.rate_limit:
            return False

        # Add current request
        rate_info["requests"].append(now)
        self.rate_limiters[webhook_id] = rate_info

        return True

    async def process_deliveries(self) -> None:
        """Process webhook deliveries"""
        async with aiohttp.ClientSession() as session:
            while True:
                try:
                    delivery = await self.delivery_queue.get()

                    if delivery.status == "success":
                        continue

                    await self.deliver_webhook(session, delivery)
                    self.delivery_queue.task_done()

                except Exception as e:
                    self.logger.error(f"Error processing delivery: {e}")
                    await asyncio.sleep(1)

    async def deliver_webhook(
        self, session: aiohttp.ClientSession, delivery: WebhookDelivery
    ) -> None:
        """Deliver webhook with retry logic"""
        webhook = self.webhooks.get(delivery.webhook_id)
        if not webhook:
            self.logger.error(f"Webhook not found: {delivery.webhook_id}")
            return

        delivery.attempt_count += 1

        try:
            # Prepare payload
            payload = {
                "id": delivery.id,
                "webhook_id": delivery.webhook_id,
                "event_type": delivery.event_type,
                "timestamp": delivery.created_at,
                "data": delivery.payload,
            }

            # Add signature if secret is configured
            headers = dict(webhook.headers)
            if webhook.secret:
                signature = self.generate_signature(
                    json.dumps(payload, sort_keys=True), webhook.secret
                )
                headers["X-Webhook-Signature"] = signature

            headers["Content-Type"] = "application/json"
            headers["User-Agent"] = "MCP-Server-Webhook/1.0"

            # Send request
            async with session.post(
                webhook.url,
                json=payload,
                headers=headers,
                timeout=aiohttp.ClientTimeout(total=webhook.timeout),
            ) as response:
                delivery.status_code = response.status
                delivery.response_body = await response.text()

                if response.status >= 200 and response.status < 300:
                    delivery.status = "success"
                    delivery.delivered_at = datetime.now().isoformat()
                    self.logger.info(
                        f"Webhook delivered successfully: {delivery.webhook_id}"
                    )
                else:
                    delivery.status = "failed"
                    delivery.error_message = (
                        f"HTTP {response.status}: {delivery.response_body}"
                    )
                    self.logger.warning(
                        f"Webhook delivery failed: {delivery.webhook_id} - {delivery.error_message}"
                    )

        except Exception as e:
            delivery.status = "failed"
            delivery.error_message = str(e)
            self.logger.error(f"Webhook delivery error: {delivery.webhook_id} - {e}")

        # Handle retries
        if delivery.status == "failed" and delivery.attempt_count < webhook.retry_count:
            delivery.status = "retry"
            delivery.next_retry_at = (
                datetime.now() + timedelta(seconds=2**delivery.attempt_count)
            ).isoformat()
            # Re-queue for retry
            await asyncio.sleep(2**delivery.attempt_count)
            await self.delivery_queue.put(delivery)
        elif delivery.status == "failed":
            self.logger.error(
                f"Webhook delivery failed permanently: {delivery.webhook_id}"
            )

        # Log delivery
        self.log_delivery(delivery)

    def generate_signature(self, payload: str, secret: str) -> str:
        """Generate webhook signature"""
        return hmac.new(secret.encode(), payload.encode(), hashlib.sha256).hexdigest()

    def log_delivery(self, delivery: WebhookDelivery) -> None:
        """Log webhook delivery"""
        try:
            with open(self.delivery_log, "a") as f:
                json.dump(
                    {
                        "id": delivery.id,
                        "webhook_id": delivery.webhook_id,
                        "event_type": delivery.event_type,
                        "status": delivery.status,
                        "status_code": delivery.status_code,
                        "attempt_count": delivery.attempt_count,
                        "created_at": delivery.created_at,
                        "delivered_at": delivery.delivered_at,
                        "error_message": delivery.error_message,
                    },
                    f,
                )
                f.write("\n")
        except Exception as e:
            self.logger.error(f"Failed to log delivery: {e}")

    def save_config(self) -> None:
        """Save webhook configuration"""
        try:
            config_data = {
                "webhooks": [webhook.__dict__ for webhook in self.webhooks.values()],
                "event_subscriptions": self.event_subscriptions,
            }

            with open(self.config_file, "w") as f:
                json.dump(config_data, f, indent=2)

        except Exception as e:
            self.logger.error(f"Failed to save webhook config: {e}")

    def load_config(self) -> None:
        """Load webhook configuration"""
        try:
            if not os.path.exists(self.config_file):
                return

            with open(self.config_file, "r") as f:
                config_data = json.load(f)

            # Load webhooks
            for webhook_data in config_data.get("webhooks", []):
                webhook = WebhookConfig(**webhook_data)
                self.webhooks[webhook.id] = webhook

            # Load event subscriptions
            self.event_subscriptions = config_data.get("event_subscriptions", {})

        except Exception as e:
            self.logger.error(f"Failed to load webhook config: {e}")

    def get_delivery_stats(self) -> Dict[str, Any]:
        """Get webhook delivery statistics"""
        stats = {
            "total_webhooks": len(self.webhooks),
            "enabled_webhooks": len([w for w in self.webhooks.values() if w.enabled]),
            "event_types": list(self.event_subscriptions.keys()),
            "deliveries": {"pending": 0, "success": 0, "failed": 0, "retry": 0},
        }

        # Count deliveries from log (simplified - in production use a database)
        try:
            if os.path.exists(self.delivery_log):
                with open(self.delivery_log, "r") as f:
                    for line in f:
                        delivery = json.loads(line)
                        status = delivery.get("status", "unknown")
                        if status in stats["deliveries"]:
                            stats["deliveries"][status] += 1
        except Exception as e:
            self.logger.error(f"Failed to read delivery stats: {e}")

    def shutdown(self) -> None:
        """Shutdown the webhook manager"""
        # Cancel any pending deliveries
        if hasattr(self, "delivery_queue") and self.delivery_queue:
            # Note: In a real implementation, you'd want to properly cancel pending tasks
            pass

        self.logger.info("Webhook manager shutdown complete")


webhook_manager = WebhookManager()


def get_webhook_manager() -> WebhookManager:
    """Get the global webhook manager instance"""
    return webhook_manager


async def start_webhook_processor() -> None:
    """Start the webhook delivery processor"""
    manager = get_webhook_manager()
    await manager.process_deliveries()


def emit_system_event(event_type: str, data: Dict[str, Any]) -> None:
    """Emit a system event to webhooks"""
    manager = get_webhook_manager()
    manager.emit_event(event_type, data)


if __name__ == "__main__":
    # CLI interface for webhook management
    import argparse

    parser = argparse.ArgumentParser(description="Webhook Manager CLI")
    parser.add_argument(
        "command", choices=["list", "register", "unregister", "update", "stats", "test"]
    )
    parser.add_argument("--id", help="Webhook ID")
    parser.add_argument("--url", help="Webhook URL")
    parser.add_argument("--events", nargs="+", help="Event types")
    parser.add_argument("--secret", help="Webhook secret")
    parser.add_argument("--event-type", help="Event type for testing")
    parser.add_argument("--event-data", help="Event data for testing (JSON)")

    args = parser.parse_args()

    manager = get_webhook_manager()

    try:
        if args.command == "list":
            webhooks = manager.list_webhooks()
            if not webhooks:
                print("No webhooks registered")
            else:
                print("Registered webhooks:")
                for webhook in webhooks:
                    status = "✅" if webhook.enabled else "❌"
                    events = ", ".join(webhook.events)
                    print(f"  {status} {webhook.id}: {webhook.url} ({events})")

        elif args.command == "register":
            if not args.url or not args.events:
                print("URL and events required")
                sys.exit(1)

            webhook_id = manager.register_webhook(
                url=args.url, events=args.events, secret=args.secret
            )
            print(f"Registered webhook: {webhook_id}")

        elif args.command == "unregister":
            if not args.id:
                print("Webhook ID required")
                sys.exit(1)

            if manager.unregister_webhook(args.id):
                print(f"Unregistered webhook: {args.id}")
            else:
                print(f"Webhook not found: {args.id}")

        elif args.command == "update":
            if not args.id:
                print("Webhook ID required")
                sys.exit(1)

            updates = {}
            if args.url:
                updates["url"] = args.url
            if args.events:
                updates["events"] = args.events
            if args.secret:
                updates["secret"] = args.secret

            if manager.update_webhook(args.id, **updates):
                print(f"Updated webhook: {args.id}")
            else:
                print(f"Webhook not found: {args.id}")

        elif args.command == "stats":
            stats = manager.get_delivery_stats()
            print("Webhook Statistics:")
            print(f"  Total webhooks: {stats['total_webhooks']}")
            print(f"  Enabled webhooks: {stats['enabled_webhooks']}")
            print(f"  Event types: {', '.join(stats['event_types'])}")
            print("  Delivery stats:")
            for status, count in stats["deliveries"].items():
                print(f"    {status}: {count}")

        elif args.command == "test":
            if not args.event_type:
                print("Event type required")
                sys.exit(1)

            event_data = {}
            if args.event_data:
                try:
                    event_data = json.loads(args.event_data)
                except json.JSONDecodeError:
                    print("Invalid JSON for event data")
                    sys.exit(1)

            manager.emit_event(args.event_type, event_data)
            print(f"Emitted test event: {args.event_type}")

    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)
