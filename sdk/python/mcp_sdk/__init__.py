#!/usr/bin/env python3
"""
MCP Python SDK

A comprehensive Python SDK for interacting with the MCP (Model Context Protocol) server.

Features:
- Full API coverage for all MCP endpoints
- Async/await support for non-blocking operations
- Automatic retry logic and error handling
- Type hints and comprehensive documentation
- Connection pooling and session management

Usage:
    from mcp_sdk import MCPClient

    async with MCPClient(base_url="http://localhost:5005") as client:
        status = await client.get_status()
        agents = await client.list_controllers()
"""

import asyncio
import aiohttp
import json
import logging
from typing import Dict, List, Optional, Any
from dataclasses import dataclass
from urllib.parse import urljoin
import time

__version__ = "1.0.0"
__author__ = "Tools Automation SDK"

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@dataclass
class MCPResponse:
    """Standardized MCP API response"""

    success: bool
    data: Any
    error: Optional[str] = None
    status_code: int = 200
    response_time: float = 0.0


@dataclass
class AgentStatus:
    """Agent status information"""

    name: str
    status: str
    last_seen: str
    health_score: float
    capabilities: List[str]


@dataclass
class TaskInfo:
    """Task information"""

    id: str
    status: str
    agent: str
    created_at: str
    completed_at: Optional[str] = None


class MCPError(Exception):
    """Base exception for MCP operations"""

    def __init__(self, message: str, status_code: Optional[int] = None):
        super().__init__(message)
        self.status_code = status_code

    def __str__(self):
        return self.args[0] if self.args else ""


class MCPConnectionError(MCPError):
    """Connection-related errors"""

    pass


class MCPTimeoutError(MCPError):
    """Timeout errors"""

    pass


class MCPAPIError(MCPError):
    """API-related errors"""

    def __init__(self, message: str, status_code: int):
        super().__init__(message)
        self.status_code = status_code


class MCPClient:
    """
    MCP Server Client

    Provides a comprehensive interface to the MCP server with automatic
    retry logic, connection pooling, and error handling.
    """

    def __init__(
        self,
        base_url: str = "http://localhost:5005",
        timeout: float = 30.0,
        max_retries: int = 3,
        retry_delay: float = 1.0,
        session: Optional[aiohttp.ClientSession] = None,
    ):
        """
        Initialize MCP client

        Args:
            base_url: Base URL of the MCP server
            timeout: Request timeout in seconds
            max_retries: Maximum number of retries for failed requests
            retry_delay: Delay between retries in seconds
            session: Optional aiohttp session (will create one if not provided)
        """
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self.max_retries = max_retries
        self.retry_delay = retry_delay
        self._session = session
        self._session_owner = session is None

    async def __aenter__(self):
        """Async context manager entry"""
        if self._session_owner:
            self._session = aiohttp.ClientSession(
                timeout=aiohttp.ClientTimeout(total=self.timeout)
            )
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit"""
        if self._session_owner and self._session:
            await self._session.close()

    async def _make_request(
        self,
        method: str,
        endpoint: str,
        data: Optional[Dict] = None,
        params: Optional[Dict] = None,
    ) -> MCPResponse:
        """Make HTTP request with retry logic"""
        url = urljoin(self.base_url + "/", endpoint.lstrip("/"))

        for attempt in range(self.max_retries + 1):
            try:
                start_time = time.time()

                async with self._session.request(
                    method=method, url=url, json=data, params=params
                ) as response:
                    response_time = time.time() - start_time

                    if response.status >= 500:
                        # Server error, retry
                        if attempt < self.max_retries:
                            await asyncio.sleep(self.retry_delay * (2**attempt))
                            continue

                    try:
                        response_data = await response.json()
                    except Exception:
                        response_data = await response.text()

                    if response.status >= 400:
                        error_msg = (
                            response_data.get("error", str(response_data))
                            if isinstance(response_data, dict)
                            else str(response_data)
                        )
                        raise MCPAPIError(error_msg, response.status)

                    return MCPResponse(
                        success=True,
                        data=response_data,
                        status_code=response.status,
                        response_time=response_time,
                    )

            except asyncio.TimeoutError:
                if attempt < self.max_retries:
                    await asyncio.sleep(self.retry_delay * (2**attempt))
                    continue
                raise MCPTimeoutError(f"Request timeout after {self.timeout}s")

            except aiohttp.ClientError as e:
                if attempt < self.max_retries:
                    await asyncio.sleep(self.retry_delay * (2**attempt))
                    continue
                raise MCPConnectionError(f"Connection error: {e}")

        # This should never be reached
        raise MCPError("Request failed after all retries")

    # Status and Health Endpoints

    async def get_status(self) -> MCPResponse:
        """Get MCP server status"""
        return await self._make_request("GET", "/status")

    async def get_health(self) -> MCPResponse:
        """Get MCP server health"""
        return await self._make_request("GET", "/health")

    # Agent Management Endpoints

    async def list_controllers(self) -> MCPResponse:
        """List all available controllers/agents"""
        return await self._make_request("GET", "/controllers")

    async def get_agent_status(self, agent_name: str) -> MCPResponse:
        """Get status of specific agent"""
        return await self._make_request("GET", f"/agents/{agent_name}/status")

    async def register_agent(
        self, agent_name: str, capabilities: List[str]
    ) -> MCPResponse:
        """Register a new agent"""
        data = {"name": agent_name, "capabilities": capabilities}
        return await self._make_request("POST", "/agents/register", data)

    # Task Management Endpoints

    async def submit_task(self, task_data: Dict) -> MCPResponse:
        """Submit a new task"""
        return await self._make_request("POST", "/tasks/submit", task_data)

    async def get_task_status(self, task_id: str) -> MCPResponse:
        """Get status of specific task"""
        return await self._make_request("GET", f"/tasks/{task_id}/status")

    async def list_tasks(
        self, status: Optional[str] = None, limit: int = 50
    ) -> MCPResponse:
        """List tasks with optional filtering"""
        params = {}
        if status:
            params["status"] = status
        if limit:
            params["limit"] = str(limit)
        return await self._make_request("GET", "/tasks", params=params)

    async def cancel_task(self, task_id: str) -> MCPResponse:
        """Cancel a running task"""
        return await self._make_request("POST", f"/tasks/{task_id}/cancel")

    # AI Endpoints

    async def analyze_code(self, code: str, language: str = "python") -> MCPResponse:
        """Analyze code using AI"""
        data = {"code": code, "language": language}
        return await self._make_request("POST", "/api/ai/analyze_code", data)

    async def predict_performance(self, metrics: Dict) -> MCPResponse:
        """Predict performance based on metrics"""
        return await self._make_request("POST", "/api/ai/predict_performance", metrics)

    async def generate_code(
        self, description: str, language: str = "python"
    ) -> MCPResponse:
        """Generate code from description"""
        data = {"description": description, "language": language}
        return await self._make_request("POST", "/api/ai/generate_code", data)

    # Webhook Management

    async def register_webhook(self, url: str, events: List[str]) -> MCPResponse:
        """Register a webhook for events"""
        data = {"url": url, "events": events}
        return await self._make_request("POST", "/webhooks/register", data)

    async def list_webhooks(self) -> MCPResponse:
        """List registered webhooks"""
        return await self._make_request("GET", "/webhooks")

    async def delete_webhook(self, webhook_id: str) -> MCPResponse:
        """Delete a webhook"""
        return await self._make_request("DELETE", f"/webhooks/{webhook_id}")

    # Plugin Management

    async def list_plugins(self) -> MCPResponse:
        """List available plugins"""
        return await self._make_request("GET", "/plugins")

    async def get_plugin_info(self, plugin_name: str) -> MCPResponse:
        """Get information about a specific plugin"""
        return await self._make_request("GET", f"/plugins/{plugin_name}")

    async def install_plugin(
        self, plugin_name: str, config: Optional[Dict] = None
    ) -> MCPResponse:
        """Install a plugin"""
        data = config or {}
        return await self._make_request("POST", f"/plugins/{plugin_name}/install", data)

    # Utility Methods

    def get_agent_status_sync(self, agent_name: str) -> Dict:
        """Synchronous version of get_agent_status"""
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            response = loop.run_until_complete(self.get_agent_status(agent_name))
            return response.data
        finally:
            loop.close()

    def submit_task_sync(self, task_data: Dict) -> Dict:
        """Synchronous version of submit_task"""
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            response = loop.run_until_complete(self.submit_task(task_data))
            return response.data
        finally:
            loop.close()


# Convenience functions for quick usage


async def quick_status_check(base_url: str = "http://localhost:5005") -> Dict:
    """Quick status check of MCP server"""
    async with MCPClient(base_url=base_url) as client:
        response = await client.get_status()
        return response.data


def quick_status_check_sync(base_url: str = "http://localhost:5005") -> Dict:
    """Synchronous version of quick status check"""
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    try:
        return loop.run_until_complete(quick_status_check(base_url))
    finally:
        loop.close()


# CLI Interface


def main():
    """CLI interface for MCP SDK"""
    import argparse

    parser = argparse.ArgumentParser(description="MCP Python SDK CLI")
    parser.add_argument(
        "--base-url", default="http://localhost:5005", help="MCP server base URL"
    )
    parser.add_argument("--status", action="store_true", help="Get server status")
    parser.add_argument("--agents", action="store_true", help="List available agents")
    parser.add_argument("--tasks", action="store_true", help="List recent tasks")

    args = parser.parse_args()

    if args.status:
        try:
            status = quick_status_check_sync(args.base_url)
            print("MCP Server Status:")
            print(json.dumps(status, indent=2))
        except Exception as e:
            print(f"Error: {e}")
            exit(1)

    elif args.agents:

        async def list_agents():
            async with MCPClient(base_url=args.base_url) as client:
                response = await client.list_controllers()
                print("Available Agents:")
                print(json.dumps(response.data, indent=2))

        try:
            asyncio.run(list_agents())
        except Exception as e:
            print(f"Error: {e}")
            exit(1)

    elif args.tasks:

        async def list_tasks():
            async with MCPClient(base_url=args.base_url) as client:
                response = await client.list_tasks(limit=10)
                print("Recent Tasks:")
                print(json.dumps(response.data, indent=2))

        try:
            asyncio.run(list_tasks())
        except Exception as e:
            print(f"Error: {e}")
            exit(1)

    else:
        parser.print_help()


if __name__ == "__main__":
    main()
