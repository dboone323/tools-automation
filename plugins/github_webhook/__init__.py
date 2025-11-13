#!/usr/bin/env python3
"""
GitHub Webhook Plugin
Handles GitHub webhook events and integrates with MCP server
"""

import json
import hmac
import hashlib
from typing import Dict, Any, Optional
import logging
from plugins import WebhookPlugin, HookPlugin

logger = logging.getLogger(__name__)


class GitHubWebhookPlugin(WebhookPlugin, HookPlugin):
    """Plugin for handling GitHub webhook events"""

    def __init__(self):
        super().__init__("github_webhook", "1.0.0")
        self.description = (
            "Handles GitHub webhook events for repository monitoring and automation"
        )
        self.webhook_secret = None
        self.supported_events = [
            "push",
            "pull_request",
            "issues",
            "release",
            "create",
            "delete",
            "fork",
            "watch",
            "star",
        ]

    def initialize(self, config: Dict[str, Any]) -> bool:
        """Initialize the GitHub webhook plugin"""
        try:
            self.webhook_secret = config.get("webhook_secret")
            self.repository_filter = config.get("repository_filter", [])
            self.event_filter = config.get("event_filter", self.supported_events)

            # Register webhook endpoints
            self.register_webhook(
                "/webhooks/github", self.handle_github_webhook, ["POST"]
            )

            # Register hooks for different GitHub events
            self.register_hook("github_push", self.on_push_event)
            self.register_hook("github_pull_request", self.on_pull_request_event)
            self.register_hook("github_issues", self.on_issues_event)
            self.register_hook("github_release", self.on_release_event)

            logger.info("GitHub webhook plugin initialized successfully")
            return True

        except Exception as e:
            logger.error(f"Failed to initialize GitHub webhook plugin: {e}")
            return False

    def shutdown(self) -> bool:
        """Shutdown the GitHub webhook plugin"""
        try:
            # Unregister webhooks and hooks
            self.unregister_webhook("/webhooks/github")
            logger.info("GitHub webhook plugin shutdown successfully")
            return True
        except Exception as e:
            logger.error(f"Error shutting down GitHub webhook plugin: {e}")
            return False

    def verify_signature(self, payload: bytes, signature: str) -> bool:
        """Verify GitHub webhook signature"""
        if not self.webhook_secret:
            logger.warning(
                "No webhook secret configured, skipping signature verification"
            )
            return True

        if not signature:
            logger.error("No signature provided in webhook request")
            return False

        # GitHub sends signature as 'sha256=...'
        if not signature.startswith("sha256="):
            logger.error("Invalid signature format")
            return False

        expected_signature = hmac.new(
            self.webhook_secret.encode(), payload, hashlib.sha256
        ).hexdigest()

        provided_signature = signature.split("=", 1)[1]

        return hmac.compare_digest(expected_signature, provided_signature)

    def handle_github_webhook(self, request_data: Dict[str, Any]) -> Dict[str, Any]:
        """Handle incoming GitHub webhook"""
        try:
            # Extract headers and payload
            headers = request_data.get("headers", {})
            raw_payload = request_data.get("body", b"")
            event_type = headers.get("X-GitHub-Event", "")
            signature = headers.get("X-Hub-Signature-256", "")

            # Verify signature if configured
            if not self.verify_signature(raw_payload, signature):
                return {"error": "Invalid signature", "status": "unauthorized"}

            # Parse payload
            try:
                payload = (
                    json.loads(raw_payload.decode("utf-8"))
                    if isinstance(raw_payload, bytes)
                    else raw_payload
                )
            except json.JSONDecodeError as e:
                return {"error": f"Invalid JSON payload: {e}", "status": "bad_request"}

            # Check repository filter
            repository = payload.get("repository", {}).get("full_name", "")
            if self.repository_filter and repository not in self.repository_filter:
                logger.info(f"Ignoring webhook for filtered repository: {repository}")
                return {"status": "ignored", "reason": "repository_filtered"}

            # Check event filter
            if event_type not in self.event_filter:
                logger.info(f"Ignoring filtered event type: {event_type}")
                return {"status": "ignored", "reason": "event_filtered"}

            # Process the event
            result = self.process_github_event(event_type, payload)

            return {
                "status": "processed",
                "event_type": event_type,
                "repository": repository,
                "result": result,
            }

        except Exception as e:
            logger.error(f"Error processing GitHub webhook: {e}")
            return {"error": str(e), "status": "error"}

    def process_github_event(
        self, event_type: str, payload: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Process a GitHub event by triggering appropriate hooks"""
        try:
            hook_name = f"github_{event_type.replace('-', '_')}"
            results = self.trigger_hook(hook_name, payload)

            return {
                "hook_triggered": hook_name,
                "hook_results": results,
                "processed": True,
            }

        except Exception as e:
            logger.error(f"Error processing GitHub event {event_type}: {e}")
            return {"error": str(e), "processed": False}

    def on_push_event(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Handle push events"""
        repository = payload.get("repository", {}).get("full_name", "")
        ref = payload.get("ref", "")
        commits = payload.get("commits", [])

        logger.info(f"Push event: {repository} {ref} ({len(commits)} commits)")

        # Trigger MCP server actions for code changes
        return {
            "action": "push_processed",
            "repository": repository,
            "ref": ref,
            "commits": len(commits),
        }

    def on_pull_request_event(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Handle pull request events"""
        action = payload.get("action", "")
        pr_number = payload.get("number", 0)
        repository = payload.get("repository", {}).get("full_name", "")

        logger.info(f"Pull request event: {repository} #{pr_number} {action}")

        # Trigger code review or merge actions
        return {
            "action": "pr_processed",
            "repository": repository,
            "number": pr_number,
            "pr_action": action,
        }

    def on_issues_event(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Handle issues events"""
        action = payload.get("action", "")
        issue_number = payload.get("issue", {}).get("number", 0)
        repository = payload.get("repository", {}).get("full_name", "")

        logger.info(f"Issues event: {repository} #{issue_number} {action}")

        # Trigger issue tracking or assignment actions
        return {
            "action": "issue_processed",
            "repository": repository,
            "number": issue_number,
            "issue_action": action,
        }

    def on_release_event(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Handle release events"""
        action = payload.get("action", "")
        tag_name = payload.get("release", {}).get("tag_name", "")
        repository = payload.get("repository", {}).get("full_name", "")

        logger.info(f"Release event: {repository} {tag_name} {action}")

        # Trigger deployment or notification actions
        return {
            "action": "release_processed",
            "repository": repository,
            "tag": tag_name,
            "release_action": action,
        }
