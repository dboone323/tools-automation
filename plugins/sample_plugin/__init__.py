"""
Sample Plugin Package

This package contains the sample plugin implementation demonstrating
the MCP plugin architecture.
"""

from .sample_plugin import SamplePlugin, create_plugin

__version__ = "1.0.0"
__all__ = ["SamplePlugin", "create_plugin"]
