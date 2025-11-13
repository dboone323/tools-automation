#!/usr/bin/env python3
"""
Tools Automation Plugin System
Extensible plugin architecture for MCP server extensions and integrations
"""

import os
import sys
import importlib
import inspect
from typing import Dict, List, Any, Optional, Callable
from abc import ABC, abstractmethod
import logging

logger = logging.getLogger(__name__)


class PluginBase(ABC):
    """Base class for all MCP server plugins"""

    def __init__(self, name: str, version: str = "1.0.0"):
        self.name = name
        self.version = version
        self.enabled = True
        self.config = {}

    @abstractmethod
    def initialize(self, config: Dict[str, Any]) -> bool:
        """Initialize the plugin with configuration"""
        pass

    @abstractmethod
    def shutdown(self) -> bool:
        """Shutdown the plugin gracefully"""
        pass

    def get_info(self) -> Dict[str, Any]:
        """Get plugin information"""
        return {
            "name": self.name,
            "version": self.version,
            "enabled": self.enabled,
            "type": self.__class__.__name__,
            "description": getattr(self, "description", "No description available"),
        }


class HookPlugin(PluginBase):
    """Plugin that provides hooks for MCP server events"""

    def __init__(self, name: str, version: str = "1.0.0"):
        super().__init__(name, version)
        self.hooks = {}

    def register_hook(self, hook_name: str, callback: Callable) -> None:
        """Register a hook callback"""
        if hook_name not in self.hooks:
            self.hooks[hook_name] = []
        self.hooks[hook_name].append(callback)
        logger.info(f"Registered hook '{hook_name}' for plugin '{self.name}'")

    def unregister_hook(self, hook_name: str, callback: Callable) -> None:
        """Unregister a hook callback"""
        if hook_name in self.hooks:
            try:
                self.hooks[hook_name].remove(callback)
                logger.info(f"Unregistered hook '{hook_name}' for plugin '{self.name}'")
            except ValueError:
                logger.warning(
                    f"Hook callback not found for '{hook_name}' in plugin '{self.name}'"
                )

    def trigger_hook(self, hook_name: str, *args, **kwargs) -> List[Any]:
        """Trigger a hook and return results from all callbacks"""
        results = []
        if hook_name in self.hooks:
            for callback in self.hooks[hook_name]:
                try:
                    result = callback(*args, **kwargs)
                    results.append(result)
                except Exception as e:
                    logger.error(
                        f"Error in hook '{hook_name}' for plugin '{self.name}': {e}"
                    )
        return results


class WebhookPlugin(PluginBase):
    """Plugin that handles webhook endpoints and events"""

    def __init__(self, name: str, version: str = "1.0.0"):
        super().__init__(name, version)
        self.webhooks = {}
        self.secret = None

    def register_webhook(
        self, path: str, handler: Callable, methods: List[str] = None
    ) -> None:
        """Register a webhook endpoint"""
        if methods is None:
            methods = ["POST"]

        self.webhooks[path] = {"handler": handler, "methods": methods}
        logger.info(f"Registered webhook '{path}' for plugin '{self.name}'")

    def unregister_webhook(self, path: str) -> None:
        """Unregister a webhook endpoint"""
        if path in self.webhooks:
            del self.webhooks[path]
            logger.info(f"Unregistered webhook '{path}' for plugin '{self.name}'")

    def handle_webhook(self, path: str, request_data: Dict[str, Any]) -> Any:
        """Handle incoming webhook request"""
        if path in self.webhooks:
            try:
                return self.webhooks[path]["handler"](request_data)
            except Exception as e:
                logger.error(
                    f"Error handling webhook '{path}' for plugin '{self.name}': {e}"
                )
                return {"error": str(e), "status": "failed"}
        return {"error": "Webhook not found", "status": "not_found"}


class IntegrationPlugin(PluginBase):
    """Plugin that provides integrations with external services"""

    def __init__(self, name: str, version: str = "1.0.0"):
        super().__init__(name, version)
        self.integrations = {}

    def register_integration(self, service_name: str, integration_class: Any) -> None:
        """Register an integration with an external service"""
        self.integrations[service_name] = integration_class
        logger.info(f"Registered integration '{service_name}' for plugin '{self.name}'")

    def get_integration(self, service_name: str) -> Optional[Any]:
        """Get an integration instance"""
        return self.integrations.get(service_name)


class PluginManager:
    """Manages loading, initialization, and lifecycle of plugins"""

    def __init__(self, plugins_dir: str = "plugins"):
        self.plugins_dir = plugins_dir
        self.plugins: Dict[str, PluginBase] = {}
        self.hooks: Dict[str, List[Callable]] = {}
        self.webhooks: Dict[str, Dict[str, Any]] = {}
        self.logger = logging.getLogger(__name__)

        # Create plugins directory if it doesn't exist
        os.makedirs(plugins_dir, exist_ok=True)

    def discover_plugins(self) -> List[str]:
        """Discover available plugins in the plugins directory"""
        plugins = []
        if os.path.exists(self.plugins_dir):
            for item in os.listdir(self.plugins_dir):
                plugin_dir = os.path.join(self.plugins_dir, item)
                if os.path.isdir(plugin_dir) and not item.startswith("_"):
                    init_file = os.path.join(plugin_dir, "__init__.py")
                    if os.path.exists(init_file):
                        plugins.append(item)
        return plugins

    def load_plugin(self, plugin_name: str, config: Dict[str, Any] = None) -> bool:
        """Load and initialize a plugin"""
        if config is None:
            config = {}

        try:
            # Import the plugin module
            plugin_module = importlib.import_module(f"plugins.{plugin_name}")

            # Find plugin classes
            plugin_classes = []
            for name, obj in inspect.getmembers(plugin_module):
                if (
                    inspect.isclass(obj)
                    and issubclass(obj, PluginBase)
                    and obj != PluginBase
                    and obj != HookPlugin
                    and obj != WebhookPlugin
                    and obj != IntegrationPlugin
                ):
                    plugin_classes.append(obj)

            if not plugin_classes:
                self.logger.error(f"No plugin classes found in {plugin_name}")
                return False

            # Use the first plugin class found
            plugin_class = plugin_classes[0]
            plugin_instance = plugin_class()

            # Initialize the plugin
            if plugin_instance.initialize(config):
                self.plugins[plugin_name] = plugin_instance
                self.logger.info(
                    f"Loaded plugin: {plugin_name} ({plugin_instance.version})"
                )

                # Register hooks if it's a hook plugin
                if isinstance(plugin_instance, HookPlugin):
                    for hook_name, callbacks in plugin_instance.hooks.items():
                        if hook_name not in self.hooks:
                            self.hooks[hook_name] = []
                        self.hooks[hook_name].extend(callbacks)

                # Register webhooks if it's a webhook plugin
                if isinstance(plugin_instance, WebhookPlugin):
                    for path, webhook_info in plugin_instance.webhooks.items():
                        self.webhooks[path] = {
                            "plugin": plugin_name,
                            "handler": webhook_info["handler"],
                            "methods": webhook_info["methods"],
                        }

                return True
            else:
                self.logger.error(f"Failed to initialize plugin: {plugin_name}")
                return False

        except Exception as e:
            self.logger.error(f"Error loading plugin {plugin_name}: {e}")
            return False

    def unload_plugin(self, plugin_name: str) -> bool:
        """Unload a plugin"""
        if plugin_name in self.plugins:
            plugin = self.plugins[plugin_name]

            # Shutdown the plugin
            try:
                plugin.shutdown()
            except Exception as e:
                self.logger.error(f"Error shutting down plugin {plugin_name}: {e}")

            # Remove hooks
            if isinstance(plugin, HookPlugin):
                for hook_name, callbacks in plugin.hooks.items():
                    if hook_name in self.hooks:
                        for callback in callbacks:
                            try:
                                self.hooks[hook_name].remove(callback)
                            except ValueError:
                                pass

            # Remove webhooks
            webhooks_to_remove = []
            for path, webhook_info in self.webhooks.items():
                if webhook_info["plugin"] == plugin_name:
                    webhooks_to_remove.append(path)

            for path in webhooks_to_remove:
                del self.webhooks[path]

            # Remove from plugins dict
            del self.plugins[plugin_name]
            self.logger.info(f"Unloaded plugin: {plugin_name}")
            return True

        return False

    def trigger_hook(self, hook_name: str, *args, **kwargs) -> List[Any]:
        """Trigger a hook across all plugins"""
        results = []

        # Trigger hooks from registered plugins
        if hook_name in self.hooks:
            for callback in self.hooks[hook_name]:
                try:
                    result = callback(*args, **kwargs)
                    results.append(result)
                except Exception as e:
                    self.logger.error(f"Error in hook '{hook_name}': {e}")

        # Also trigger plugin-specific hooks
        for plugin in self.plugins.values():
            if isinstance(plugin, HookPlugin):
                plugin_results = plugin.trigger_hook(hook_name, *args, **kwargs)
                results.extend(plugin_results)

        return results

    def handle_webhook(self, path: str, request_data: Dict[str, Any]) -> Any:
        """Handle incoming webhook request"""
        if path in self.webhooks:
            webhook_info = self.webhooks[path]
            plugin_name = webhook_info["plugin"]

            if plugin_name in self.plugins:
                plugin = self.plugins[plugin_name]
                if isinstance(plugin, WebhookPlugin):
                    return plugin.handle_webhook(path, request_data)

        return {"error": "Webhook not found", "status": "not_found"}

    def get_plugin_info(self) -> Dict[str, Any]:
        """Get information about all loaded plugins"""
        return {
            plugin_name: plugin.get_info()
            for plugin_name, plugin in self.plugins.items()
        }

    def get_webhook_endpoints(self) -> Dict[str, Dict[str, Any]]:
        """Get all registered webhook endpoints"""
        return self.webhooks.copy()

    def reload_plugin(self, plugin_name: str, config: Dict[str, Any] = None) -> bool:
        """Reload a plugin"""
        if self.unload_plugin(plugin_name):
            return self.load_plugin(plugin_name, config)
        return False
