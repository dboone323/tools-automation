#!/usr/bin/env python3
"""
MCP Python SDK

A comprehensive Python SDK for interacting with the MCP (Model Context Protocol) server.
"""

from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="mcp-sdk",
    version="1.0.0",
    author="Tools Automation",
    author_email="sdk@tools-automation.com",
    description="Python SDK for MCP (Model Context Protocol) server",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/dboone323/tools-automation",
    packages=find_packages(),
    classifiers=[
        "Development Status :: 5 - Production/Stable",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Topic :: Software Development :: Libraries :: Python Modules",
        "Topic :: System :: Distributed Computing",
    ],
    python_requires=">=3.8",
    install_requires=[
        "aiohttp>=3.8.0",
        "typing-extensions>=4.0.0",
    ],
    extras_require={
        "dev": [
            "pytest>=7.0.0",
            "pytest-asyncio>=0.21.0",
            "black>=22.0.0",
            "isort>=5.10.0",
            "mypy>=1.0.0",
            "flake8>=4.0.0",
        ],
    },
    entry_points={
        "console_scripts": [
            "mcp-cli=mcp_sdk:main",
        ],
    },
    keywords="mcp sdk api client automation",
    project_urls={
        "Bug Reports": "https://github.com/dboone323/tools-automation/issues",
        "Source": "https://github.com/dboone323/tools-automation",
        "Documentation": "https://github.com/dboone323/tools-automation/docs",
    },
)
