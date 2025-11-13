#!/usr/bin/env python3
"""
Basic usage example for the MCP Python SDK
"""

import asyncio
import json
from mcp_sdk import MCPClient, quick_status_check_sync


async def basic_example():
    """Basic client usage example"""
    print("🔄 Basic MCP Client Example")
    print("=" * 40)

    async with MCPClient() as client:
        # Get server status
        print("📊 Getting server status...")
        status = await client.get_status()
        print(f"Server status: {json.dumps(status.data, indent=2)}")

        # Get server health
        print("\n🏥 Getting server health...")
        health = await client.get_health()
        print(f"Server health: {json.dumps(health.data, indent=2)}")

        # List available agents
        print("\n🤖 Listing available agents...")
        agents = await client.list_controllers()
        print(f"Available agents: {json.dumps(agents.data, indent=2)}")


async def task_management_example():
    """Task management example"""
    print("\n📋 Task Management Example")
    print("=" * 40)

    async with MCPClient() as client:
        # Submit a code analysis task
        print("🔍 Submitting code analysis task...")
        task = await client.submit_task(
            {
                "type": "code_analysis",
                "target": "example.py",
                "parameters": {"include_metrics": True, "include_suggestions": True},
            }
        )
        print(f"Task submitted: {json.dumps(task.data, indent=2)}")

        if task.success and "id" in task.data:
            task_id = task.data["id"]

            # Check task status
            print(f"\n📊 Checking status of task {task_id}...")
            status = await client.get_task_status(task_id)
            print(f"Task status: {json.dumps(status.data, indent=2)}")

            # List recent tasks
            print("\n📝 Listing recent tasks...")
            tasks = await client.list_tasks(limit=5)
            print(f"Recent tasks: {json.dumps(tasks.data, indent=2)}")


async def ai_features_example():
    """AI features example"""
    print("\n🤖 AI Features Example")
    print("=" * 40)

    sample_code = '''
def calculate_fibonacci(n):
    """Calculate the nth Fibonacci number"""
    if n <= 1:
        return n
    return calculate_fibonacci(n-1) + calculate_fibonacci(n-2)
'''

    async with MCPClient() as client:
        # Analyze code
        print("🔬 Analyzing code...")
        analysis = await client.analyze_code(sample_code, "python")
        print(f"Code analysis: {json.dumps(analysis.data, indent=2)}")

        # Generate code
        print("\n💡 Generating code...")
        generation = await client.generate_code(
            "Create a function to check if a number is prime", "python"
        )
        print(f"Generated code: {json.dumps(generation.data, indent=2)}")


async def plugin_management_example():
    """Plugin management example"""
    print("\n🔌 Plugin Management Example")
    print("=" * 40)

    async with MCPClient() as client:
        # List available plugins
        print("📦 Listing available plugins...")
        plugins = await client.list_plugins()
        print(f"Available plugins: {json.dumps(plugins.data, indent=2)}")

        # Get plugin info (if plugins exist)
        if plugins.success and plugins.data:
            plugin_name = plugins.data[0].get("name", "example-plugin")
            print(f"\nℹ️  Getting info for plugin: {plugin_name}")
            info = await client.get_plugin_info(plugin_name)
            print(f"Plugin info: {json.dumps(info.data, indent=2)}")


async def webhook_example():
    """Webhook management example"""
    print("\n🪝 Webhook Management Example")
    print("=" * 40)

    async with MCPClient() as client:
        # Register a webhook
        print("📡 Registering webhook...")
        webhook = await client.register_webhook(
            "https://example.com/webhook", ["task.completed", "agent.status_changed"]
        )
        print(f"Webhook registered: {json.dumps(webhook.data, indent=2)}")

        # List webhooks
        print("\n📋 Listing webhooks...")
        webhooks = await client.list_webhooks()
        print(f"Registered webhooks: {json.dumps(webhooks.data, indent=2)}")


def synchronous_example():
    """Synchronous usage example"""
    print("\n⚡ Synchronous Usage Example")
    print("=" * 40)

    # Quick status check
    print("🔍 Quick status check...")
    try:
        status = quick_status_check_sync()
        print(f"Server status: {json.dumps(status, indent=2)}")
    except Exception as e:
        print(f"Status check failed: {e}")


async def error_handling_example():
    """Error handling example"""
    print("\n🚨 Error Handling Example")
    print("=" * 40)

    # Try to connect to a non-existent server
    print("🔌 Attempting connection to invalid server...")
    try:
        async with MCPClient(base_url="http://invalid-server:9999") as client:
            status = await client.get_status()
            print(f"Status: {status.data}")
    except Exception as e:
        print(f"Expected error: {type(e).__name__}: {e}")

    # Try with valid server but invalid endpoint
    print("\n❌ Attempting invalid endpoint...")
    try:
        async with MCPClient() as client:
            # This will likely fail if server doesn't have this endpoint
            result = await client._make_request("GET", "/nonexistent-endpoint")
            print(f"Result: {result.data}")
    except Exception as e:
        print(f"Expected error: {type(e).__name__}: {e}")


async def main():
    """Run all examples"""
    print("🚀 MCP Python SDK Examples")
    print("=" * 50)

    try:
        await basic_example()
        await task_management_example()
        await ai_features_example()
        await plugin_management_example()
        await webhook_example()
        synchronous_example()
        await error_handling_example()

        print("\n✅ All examples completed successfully!")

    except Exception as e:
        print(f"\n❌ Example failed with error: {e}")
        import traceback

        traceback.print_exc()


if __name__ == "__main__":
    asyncio.run(main())
