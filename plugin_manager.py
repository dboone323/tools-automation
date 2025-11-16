#!/usr/bin/env python3
"""
Plugin Manager - Core plugin architecture for the MCP Server

Provides plugin loading, lifecycle management, and extension capabilities.
"""

import importlib
import inspect
import json
import logging
import sys
from abc import ABC, abstractmethod
from pathlib import Path
from typing import Any, Dict, List, Optional, Callable
from dataclasses import dataclass, field
from datetime import datetime

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@dataclass
class PluginMetadata:
    """Plugin metadata structure"""

    name: str
    version: str
    description: str
    author: str
    license: str = "MIT"
    dependencies: List[str] = field(default_factory=list)
    entry_point: str = ""
    config_schema: Dict[str, Any] = field(default_factory=dict)
    capabilities: List[str] = field(default_factory=list)
    tags: List[str] = field(default_factory=list)
    homepage: str = ""
    repository: str = ""
    created_at: str = field(default_factory=lambda: datetime.now().isoformat())
    updated_at: str = field(default_factory=lambda: datetime.now().isoformat())


@dataclass
class PluginInstance:
    """Loaded plugin instance"""

    metadata: PluginMetadata
    module: Any
    instance: Any
    config: Dict[str, Any] = field(default_factory=dict)
    enabled: bool = True
    loaded_at: str = field(default_factory=lambda: datetime.now().isoformat())
    health_status: str = "unknown"


class PluginError(Exception):
    """Base plugin error"""

    pass


class PluginLoadError(PluginError):
    """Plugin loading error"""

    pass


class PluginValidationError(PluginError):
    """Plugin validation error"""

    pass


class PluginBase(ABC):
    """Base class for all plugins"""

    def __init__(self, config: Dict[str, Any] = None):
        self.config = config or {}
        self.logger = logging.getLogger(
            f"{self.__class__.__module__}.{self.__class__.__name__}"
        )
        self._initialized = False

    @property
    @abstractmethod
    def metadata(self) -> PluginMetadata:
        """Plugin metadata"""
        pass

    @abstractmethod
    def initialize(self) -> None:
        """Initialize the plugin"""
        pass

    @abstractmethod
    def shutdown(self) -> None:
        """Shutdown the plugin"""
        pass

    def is_healthy(self) -> bool:
        """Check plugin health"""
        return self._initialized

    def get_capabilities(self) -> List[str]:
        """Get plugin capabilities"""
        return self.metadata.capabilities

    def handle_event(self, event_type: str, data: Dict[str, Any]) -> None:
        """Handle system events (optional)"""
        pass


class PluginManager:
    """Plugin manager for loading and managing plugins"""

    def __init__(self, plugin_dir: str = "plugins", config_dir: str = "config/plugins"):
        self.plugin_dir = Path(plugin_dir)
        self.config_dir = Path(config_dir)
        self.plugins: Dict[str, PluginInstance] = {}
        self.event_listeners: Dict[str, List[Callable]] = {}

        # Create directories
        self.plugin_dir.mkdir(exist_ok=True)
        self.config_dir.mkdir(exist_ok=True)

        # Setup logging
        self.logger = logging.getLogger(__name__)

    def discover_plugins(self) -> List[str]:
        """Discover available plugins"""
        plugins = []

        if not self.plugin_dir.exists():
            return plugins

        for item in self.plugin_dir.iterdir():
            if item.is_dir() and (item / "plugin.json").exists():
                plugins.append(item.name)

        return plugins

    def load_plugin_metadata(self, plugin_name: str) -> PluginMetadata:
        """Load plugin metadata"""
        metadata_file = self.plugin_dir / plugin_name / "plugin.json"

        if not metadata_file.exists():
            raise PluginLoadError(f"Plugin metadata not found: {metadata_file}")

        try:
            with open(metadata_file, "r") as f:
                data = json.load(f)

            # Validate required fields
            required_fields = [
                "name",
                "version",
                "description",
                "author",
                "entry_point",
            ]
            for field in required_fields:
                if field not in data:
                    raise PluginValidationError(f"Missing required field: {field}")

            return PluginMetadata(**data)

        except json.JSONDecodeError as e:
            raise PluginValidationError(f"Invalid plugin.json: {e}")

    def load_plugin_config(self, plugin_name: str) -> Dict[str, Any]:
        """Load plugin configuration"""
        config_file = self.config_dir / f"{plugin_name}.json"

        if config_file.exists():
            try:
                with open(config_file, "r") as f:
                    return json.load(f)
            except json.JSONDecodeError:
                self.logger.warning(
                    f"Invalid config file for {plugin_name}, using defaults"
                )

        return {}

    def save_plugin_config(self, plugin_name: str, config: Dict[str, Any]) -> None:
        """Save plugin configuration"""
        config_file = self.config_dir / f"{plugin_name}.json"
        config_file.parent.mkdir(exist_ok=True)

        with open(config_file, "w") as f:
            json.dump(config, f, indent=2)

    def validate_plugin_dependencies(self, metadata: PluginMetadata) -> bool:
        """Validate plugin dependencies"""
        for dep in metadata.dependencies:
            if dep not in self.plugins:
                self.logger.warning(f"Plugin {metadata.name} missing dependency: {dep}")
                return False
        return True

    def load_plugins(self, plugins_dir: str) -> List[str]:
        """Load all plugins from a directory"""
        loaded_plugins = []

        # Update plugin directory if different
        if plugins_dir != str(self.plugin_dir):
            self.plugin_dir = Path(plugins_dir)
            self.plugin_dir.mkdir(exist_ok=True)

        # Discover available plugins
        available_plugins = self.discover_plugins()

        if not available_plugins:
            self.logger.info(f"No plugins found in {plugins_dir}")
            return loaded_plugins

        self.logger.info(f"Loading {len(available_plugins)} plugins from {plugins_dir}")

        # Load each plugin
        for plugin_name in available_plugins:
            try:
                plugin_instance = self.load_plugin(plugin_name)
                loaded_plugins.append(plugin_name)
                self.logger.info(f"Successfully loaded plugin: {plugin_name}")
            except Exception as e:
                self.logger.error(f"Failed to load plugin {plugin_name}: {e}")

        self.logger.info(
            f"Loaded {len(loaded_plugins)} out of {len(available_plugins)} plugins"
        )
        return loaded_plugins

    def load_plugin(self, plugin_name: str, enable: bool = True) -> PluginInstance:
        if plugin_name in self.plugins:
            raise PluginLoadError(f"Plugin already loaded: {plugin_name}")

        try:
            # Load metadata
            metadata = self.load_plugin_metadata(plugin_name)

            # Load configuration
            config = self.load_plugin_config(plugin_name)

            # Validate dependencies
            if not self.validate_plugin_dependencies(metadata):
                raise PluginLoadError(f"Dependencies not satisfied for {plugin_name}")

            # Import plugin module
            plugin_path = self.plugin_dir / plugin_name
            if str(plugin_path) not in sys.path:
                sys.path.insert(0, str(plugin_path))

            try:
                module = importlib.import_module(metadata.entry_point)
            except ImportError as e:
                raise PluginLoadError(f"Failed to import plugin {plugin_name}: {e}")

            # Find plugin class
            plugin_class = None
            for name, obj in inspect.getmembers(module):
                if (
                    inspect.isclass(obj)
                    and issubclass(obj, PluginBase)
                    and obj != PluginBase
                ):
                    plugin_class = obj
                    break

            if not plugin_class:
                raise PluginLoadError(f"No plugin class found in {plugin_name}")

            # Create plugin instance
            instance = plugin_class(config)
            instance._initialized = False

            # Initialize plugin
            try:
                instance.initialize()
                instance._initialized = True
                health_status = "healthy" if instance.is_healthy() else "unhealthy"
            except Exception as e:
                self.logger.error(f"Failed to initialize plugin {plugin_name}: {e}")
                health_status = "failed"

            # Create plugin instance record
            plugin_instance = PluginInstance(
                metadata=metadata,
                module=module,
                instance=instance,
                config=config,
                enabled=enable,
                health_status=health_status,
            )

            self.plugins[plugin_name] = plugin_instance

            self.logger.info(f"Loaded plugin: {plugin_name} v{metadata.version}")
            return plugin_instance

        except Exception as e:
            self.logger.error(f"Failed to load plugin {plugin_name}: {e}")
            raise

    def unload_plugin(self, plugin_name: str) -> None:
        """Unload a plugin"""
        if plugin_name not in self.plugins:
            raise PluginLoadError(f"Plugin not loaded: {plugin_name}")

        plugin_instance = self.plugins[plugin_name]

        try:
            plugin_instance.instance.shutdown()
        except Exception as e:
            self.logger.warning(f"Error shutting down plugin {plugin_name}: {e}")

        # Remove from sys.path if added
        plugin_path = str(self.plugin_dir / plugin_name)
        if plugin_path in sys.path:
            sys.path.remove(plugin_path)

        # Remove from plugins dict
        del self.plugins[plugin_name]

        self.logger.info(f"Unloaded plugin: {plugin_name}")

    def enable_plugin(self, plugin_name: str) -> None:
        """Enable a plugin"""
        if plugin_name not in self.plugins:
            raise PluginLoadError(f"Plugin not loaded: {plugin_name}")

        self.plugins[plugin_name].enabled = True
        self.logger.info(f"Enabled plugin: {plugin_name}")

    def disable_plugin(self, plugin_name: str) -> None:
        """Disable a plugin"""
        if plugin_name not in self.plugins:
            raise PluginLoadError(f"Plugin not loaded: {plugin_name}")

        self.plugins[plugin_name].enabled = False
        self.logger.info(f"Disabled plugin: {plugin_name}")

    def reload_plugin(self, plugin_name: str) -> PluginInstance:
        """Reload a plugin"""
        self.unload_plugin(plugin_name)
        return self.load_plugin(plugin_name)

    def get_plugin(self, plugin_name: str) -> Optional[PluginInstance]:
        """Get a plugin instance"""
        return self.plugins.get(plugin_name)

    def list_plugins(self) -> List[PluginInstance]:
        """List all loaded plugins"""
        return list(self.plugins.values())

    def get_enabled_plugins(self) -> List[PluginInstance]:
        """Get enabled plugins"""
        return [p for p in self.plugins.values() if p.enabled]

    def emit_event(self, event_type: str, data: Dict[str, Any]) -> None:
        """Emit an event to all plugins"""
        for plugin_instance in self.get_enabled_plugins():
            try:
                plugin_instance.instance.handle_event(event_type, data)
            except Exception as e:
                self.logger.error(
                    f"Error handling event {event_type} in plugin {plugin_instance.metadata.name}: {e}"
                )

    def get_plugin_capabilities(self, plugin_name: str) -> List[str]:
        """Get plugin capabilities"""
        plugin = self.get_plugin(plugin_name)
        return plugin.instance.get_capabilities() if plugin else []

    def get_system_capabilities(self) -> Dict[str, List[str]]:
        """Get all system capabilities by plugin"""
        capabilities = {}
        for name, plugin in self.plugins.items():
            if plugin.enabled:
                capabilities[name] = plugin.instance.get_capabilities()
        return capabilities

    def get_health_status(self) -> Dict[str, str]:
        """Get health status of all plugins"""
        return {name: plugin.health_status for name, plugin in self.plugins.items()}

    def save_plugin_states(self) -> None:
        """Save plugin states to disk"""
        states = {}
        for name, plugin in self.plugins.items():
            states[name] = {
                "enabled": plugin.enabled,
                "config": plugin.config,
                "health_status": plugin.health_status,
            }

        state_file = self.config_dir / "plugin_states.json"
        with open(state_file, "w") as f:
            json.dump(states, f, indent=2)

    def load_plugin_states(self) -> None:
        """Load plugin states from disk"""
        state_file = self.config_dir / "plugin_states.json"
        if not state_file.exists():
            return

        try:
            with open(state_file, "r") as f:
                states = json.load(f)

            for name, state in states.items():
                if name in self.plugins:
                    self.plugins[name].enabled = state.get("enabled", True)
                    self.plugins[name].config = state.get("config", {})
                    self.plugins[name].health_status = state.get(
                        "health_status", "unknown"
                    )
        except Exception as e:
            self.logger.warning(f"Failed to load plugin states: {e}")
        """Shutdown all plugins"""
        plugin_names = list(self.plugins.keys())
        for plugin_name in plugin_names:
            try:
                self.unload_plugin(plugin_name)
            except Exception as e:
                self.logger.error(
                    f"Error unloading plugin {plugin_name} during shutdown: {e}"
                )

        self.logger.info("Plugin manager shutdown complete")


plugin_manager = PluginManager()


def get_plugin_manager() -> PluginManager:
    """Get the global plugin manager instance"""
    return plugin_manager


def initialize_plugin_system() -> None:
    """Initialize the plugin system"""
    manager = get_plugin_manager()

    # Load plugin states
    manager.load_plugin_states()

    # Discover and load plugins
    available_plugins = manager.discover_plugins()
    logger.info(f"Discovered {len(available_plugins)} plugins: {available_plugins}")

    for plugin_name in available_plugins:
        try:
            manager.load_plugin(plugin_name)
        except Exception as e:
            logger.error(f"Failed to load plugin {plugin_name}: {e}")

    # Save states
    manager.save_plugin_states()


if __name__ == "__main__":
    # CLI interface for plugin management
    import argparse

    parser = argparse.ArgumentParser(description="Plugin Manager CLI")
    parser.add_argument(
        "command",
        choices=["list", "load", "unload", "enable", "disable", "reload", "status"],
    )
    parser.add_argument("plugin", nargs="?", help="Plugin name")
    parser.add_argument("--init", action="store_true", help="Initialize plugin system")

    args = parser.parse_args()

    if args.init:
        initialize_plugin_system()
        print("Plugin system initialized")
        sys.exit(0)

    manager = get_plugin_manager()

    try:
        if args.command == "list":
            plugins = manager.list_plugins()
            if not plugins:
                print("No plugins loaded")
            else:
                print("Loaded plugins:")
                for plugin in plugins:
                    status = "✅" if plugin.enabled else "❌"
                    health = plugin.health_status
                    print(
                        f"  {status} {plugin.metadata.name} v{plugin.metadata.version} ({health})"
                    )

        elif args.command == "load":
            if not args.plugin:
                print("Plugin name required")
                sys.exit(1)
            manager.load_plugin(args.plugin)
            print(f"Loaded plugin: {args.plugin}")

        elif args.command == "unload":
            if not args.plugin:
                print("Plugin name required")
                sys.exit(1)
            manager.unload_plugin(args.plugin)
            print(f"Unloaded plugin: {args.plugin}")

        elif args.command == "enable":
            if not args.plugin:
                print("Plugin name required")
                sys.exit(1)
            manager.enable_plugin(args.plugin)
            print(f"Enabled plugin: {args.plugin}")

        elif args.command == "disable":
            if not args.plugin:
                print("Plugin name required")
                sys.exit(1)
            manager.disable_plugin(args.plugin)
            print(f"Disabled plugin: {args.plugin}")

        elif args.command == "reload":
            if not args.plugin:
                print("Plugin name required")
                sys.exit(1)
            manager.reload_plugin(args.plugin)
            print(f"Reloaded plugin: {args.plugin}")

        elif args.command == "status":
            status = manager.get_health_status()
            capabilities = manager.get_system_capabilities()

            print("Plugin Status:")
            for name, health in status.items():
                enabled = "✅" if manager.get_plugin(name).enabled else "❌"
                caps = ", ".join(capabilities.get(name, []))
                print(f"  {enabled} {name}: {health} - {caps}")

        # Save states after operations
        manager.save_plugin_states()

    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)
