#!/usr/bin/env python3
"""
MCP Server Plugin Integration

Integrates the advanced plugin and webhook managers with the MCP server.
This replaces the simple plugin system with the comprehensive extensions framework.
"""

import os
import sys
import importlib.util
import logging
from typing import Dict, Any

# Add the current directory to Python path for imports
sys.path.insert(0, os.path.dirname(__file__))

# Import the advanced plugin and webhook managers
try:
    from plugin_manager import PluginManager, PluginMetadata
    from webhook_manager import WebhookManager

    ADVANCED_MANAGERS_AVAILABLE = True
except ImportError as e:
    print(f"Advanced plugin managers not available: {e}")
    ADVANCED_MANAGERS_AVAILABLE = False


class MCPPluginIntegrator:
    """Integrates advanced plugin and webhook managers with MCP server"""

    def __init__(self):
        self.plugin_manager = None
        self.webhook_manager = None
        self.logger = logging.getLogger(__name__)

        if ADVANCED_MANAGERS_AVAILABLE:
            self.plugin_manager = PluginManager()
            self.webhook_manager = WebhookManager()
            self.logger.info("Advanced plugin managers initialized")
        else:
            self.logger.warning("Using fallback plugin system")

    def load_plugins(self, plugins_dir: str) -> None:
        """Load plugins using the advanced plugin manager"""
        if not ADVANCED_MANAGERS_AVAILABLE:
            self.logger.warning(
                "Advanced managers not available, skipping plugin loading"
            )
            return

        if not os.path.exists(plugins_dir):
            self.logger.info(f"Plugins directory {plugins_dir} does not exist")
            return

        self.logger.info(f"Loading plugins from {plugins_dir}")

        # Load plugins using the advanced plugin manager
        loaded_plugins = self.plugin_manager.load_plugins(plugins_dir)

        if loaded_plugins:
            self.logger.info(
                f"Successfully loaded {len(loaded_plugins)} plugins: {loaded_plugins}"
            )
        else:
            self.logger.info("No plugins loaded")

    def register_webhook(self, path: str, handler, methods=None) -> None:
        """Register a webhook endpoint"""
        if self.webhook_manager:
            self.webhook_manager.register_webhook(path, handler, methods)
            self.logger.info(f"Registered webhook: {path}")

    def trigger_event(self, event_type: str, data: Dict[str, Any]) -> None:
        """Trigger an event to plugins and webhooks"""
        if self.plugin_manager:
            self.plugin_manager.emit_event(event_type, data)

        if self.webhook_manager:
            # Run webhook notifications asynchronously
            import asyncio
            import threading

            def run_async():
                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
                try:
                    loop.run_until_complete(
                        self.webhook_manager.notify_event(event_type, data)
                    )
                except Exception as e:
                    self.logger.error(f"Error in webhook notification: {e}")
                finally:
                    loop.close()

            thread = threading.Thread(target=run_async, daemon=True)
            thread.start()

    def get_plugin_status(self) -> Dict[str, Any]:
        """Get status of loaded plugins"""
        if not self.plugin_manager:
            return {"plugins_available": False}

        plugins_status = {}
        for name, plugin in self.plugin_manager.plugins.items():
            plugins_status[name] = {
                "healthy": plugin.instance.is_healthy(),
                "capabilities": plugin.instance.get_capabilities(),
                "metadata": (
                    plugin.metadata.__dict__ if hasattr(plugin, "metadata") else {}
                ),
            }

        return {
            "plugins_available": True,
            "loaded_plugins": len(plugins_status),
            "plugin_details": plugins_status,
        }

    def get_webhook_status(self) -> Dict[str, Any]:
        """Get status of registered webhooks"""
        if not self.webhook_manager:
            return {"webhooks_available": False}

        return {
            "webhooks_available": True,
            "registered_webhooks": len(self.webhook_manager.webhooks),
            "webhook_endpoints": list(self.webhook_manager.webhooks.keys()),
        }

    def shutdown(self) -> None:
        """Shutdown all plugins and webhooks"""
        if self.plugin_manager:
            self.plugin_manager.shutdown()
            self.logger.info("Plugin manager shutdown complete")

        if self.webhook_manager:
            # Shutdown webhook manager if it has a shutdown method
            if hasattr(self.webhook_manager, "shutdown"):
                self.webhook_manager.shutdown()
            self.logger.info("Webhook manager shutdown complete")


# Global integrator instance
integrator = MCPPluginIntegrator()


def get_integrator():
    """Get the global plugin integrator instance"""
    return integrator


# Backward compatibility functions for existing MCP server
def load_plugins(plugins_dir):
    """Load plugins (backward compatibility)"""
    integrator.load_plugins(plugins_dir)


def register_webhook(path, handler, methods=None):
    """Register webhook (backward compatibility)"""
    integrator.register_webhook(path, handler, methods)


def trigger_event(event_type, data):
    """Trigger event (backward compatibility)"""
    integrator.trigger_event(event_type, data)


def shutdown_plugins():
    """Shutdown plugins (backward compatibility)"""
    integrator.shutdown()


# Enhanced plugin manager for MCP server compatibility
class EnhancedPluginManager:
    """Enhanced plugin manager that wraps the advanced plugin system"""

    def __init__(self):
        self.plugins = {}
        self.webhooks = {}
        self.hooks = {}

    def load_plugins(self, plugins_dir):
        """Load plugins from directory"""
        integrator.load_plugins(plugins_dir)
        # Update local references for backward compatibility
        if integrator.plugin_manager:
            self.plugins = integrator.plugin_manager.plugins
        return self.plugins

    def register_webhook(self, path, handler, methods=None):
        """Register webhook"""
        integrator.register_webhook(path, handler, methods)
        if methods is None:
            methods = ["POST"]
        self.webhooks[path] = {"handler": handler, "methods": methods}

    def register_hook(self, hook_name, callback):
        """Register hook"""
        if hook_name not in self.hooks:
            self.hooks[hook_name] = []
        self.hooks[hook_name].append(callback)

    def trigger_hook(self, hook_name, *args, **kwargs):
        """Trigger hook"""
        results = []
        if hook_name in self.hooks:
            for callback in self.hooks[hook_name]:
                try:
                    result = callback(*args, **kwargs)
                    results.append(result)
                except Exception as e:
                    print(f"Error in hook {hook_name}: {e}")
        return results

    def shutdown_plugins(self):
        """Shutdown plugins"""
        integrator.shutdown()
        self.plugins.clear()
        self.webhooks.clear()
        self.hooks.clear()


# Replace the simple plugin manager with enhanced one
plugin_manager = EnhancedPluginManager()

if __name__ == "__main__":
    # Test the integration
    logging.basicConfig(level=logging.INFO)

    print("Testing MCP Plugin Integration...")

    # Test plugin loading
    plugins_dir = os.path.join(os.path.dirname(__file__), "plugins")
    integrator.load_plugins(plugins_dir)

    # Test status reporting
    plugin_status = integrator.get_plugin_status()
    webhook_status = integrator.get_webhook_status()

    print(f"Plugin Status: {plugin_status}")
    print(f"Webhook Status: {webhook_status}")

    # Test event triggering
    test_event = {
        "agent_name": "test_agent",
        "event_type": "test",
        "timestamp": 1234567890,
    }
    integrator.trigger_event("test_event", test_event)

    print("Plugin integration test completed")
