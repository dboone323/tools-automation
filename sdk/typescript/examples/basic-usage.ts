/**
 * Basic usage examples for the MCP TypeScript SDK
 */

import { MCPClient, quickStatusCheck, createTask } from '../src/index';

/**
 * Basic client usage example
 */
async function basicExample(): Promise<void> {
  console.log('🔄 Basic MCP Client Example');
  console.log('='.repeat(40));

  const client = new MCPClient();

  try {
    // Get server status
    console.log('📊 Getting server status...');
    const status = await client.getStatus();
    console.log('Server status:', JSON.stringify(status.data, null, 2));

    // Get server health
    console.log('\n🏥 Getting server health...');
    const health = await client.getHealth();
    console.log('Server health:', JSON.stringify(health.data, null, 2));

    // List available agents
    console.log('\n🤖 Listing available agents...');
    const agents = await client.listControllers();
    console.log('Available agents:', JSON.stringify(agents.data, null, 2));

  } catch (error) {
    console.error('Basic example failed:', error);
  }
}

/**
 * Task management example
 */
async function taskManagementExample(): Promise<void> {
  console.log('\n📋 Task Management Example');
  console.log('='.repeat(40));

  const client = new MCPClient();

  try {
    // Submit a code analysis task
    console.log('🔍 Submitting code analysis task...');
    const task = await client.submitTask({
      type: 'code_analysis',
      target: 'example.ts',
      parameters: {
        includeMetrics: true,
        includeSuggestions: true,
      },
      priority: 'normal',
    });
    console.log('Task submitted:', JSON.stringify(task.data, null, 2));

    if (task.success && task.data.id) {
      const taskId = task.data.id;

      // Check task status
      console.log(`\n📊 Checking status of task ${taskId}...`);
      const status = await client.getTaskStatus(taskId);
      console.log('Task status:', JSON.stringify(status.data, null, 2));

      // List recent tasks
      console.log('\n📝 Listing recent tasks...');
      const tasks = await client.listTasks({ limit: 5 });
      console.log('Recent tasks:', JSON.stringify(tasks.data, null, 2));
    }

  } catch (error) {
    console.error('Task management example failed:', error);
  }
}

/**
 * AI features example
 */
async function aiFeaturesExample(): Promise<void> {
  console.log('\n🤖 AI Features Example');
  console.log('='.repeat(40));

  const sampleCode = `
function calculateFibonacci(n: number): number {
  if (n <= 1) return n;
  return calculateFibonacci(n - 1) + calculateFibonacci(n - 2);
}
`;

  const client = new MCPClient();

  try {
    // Analyze code
    console.log('🔬 Analyzing code...');
    const analysis = await client.analyzeCode({
      code: sampleCode,
      language: 'typescript',
      options: {
        includeSuggestions: true,
        includeMetrics: true,
      },
    });
    console.log('Code analysis:', JSON.stringify(analysis.data, null, 2));

    // Generate code
    console.log('\n💡 Generating code...');
    const generation = await client.generateCode({
      description: 'Create a function to check if a number is prime in TypeScript',
      language: 'typescript',
      context: 'utility functions',
      constraints: ['Use proper TypeScript types', 'Include error handling'],
    });
    console.log('Generated code:', JSON.stringify(generation.data, null, 2));

  } catch (error) {
    console.error('AI features example failed:', error);
  }
}

/**
 * Plugin management example
 */
async function pluginManagementExample(): Promise<void> {
  console.log('\n🔌 Plugin Management Example');
  console.log('='.repeat(40));

  const client = new MCPClient();

  try {
    // List available plugins
    console.log('📦 Listing available plugins...');
    const plugins = await client.listPlugins();
    console.log('Available plugins:', JSON.stringify(plugins.data, null, 2));

    // Get plugin info (if plugins exist)
    if (plugins.success && plugins.data && plugins.data.length > 0) {
      const pluginName = plugins.data[0].name;
      console.log(`\nℹ️  Getting info for plugin: ${pluginName}`);
      const info = await client.getPluginInfo(pluginName);
      console.log('Plugin info:', JSON.stringify(info.data, null, 2));

      // Install plugin example (commented out to avoid actual installation)
      // console.log(`\n⬇️  Installing plugin: ${pluginName}`);
      // const installResult = await client.installPlugin(pluginName, {
      //   autoStart: true,
      //   config: { someSetting: 'value' }
      // });
      // console.log('Install result:', JSON.stringify(installResult.data, null, 2));
    }

  } catch (error) {
    console.error('Plugin management example failed:', error);
  }
}

/**
 * Webhook management example
 */
async function webhookExample(): Promise<void> {
  console.log('\n🪝 Webhook Management Example');
  console.log('='.repeat(40));

  const client = new MCPClient();

  try {
    // Register a webhook
    console.log('📡 Registering webhook...');
    const webhook = await client.registerWebhook({
      url: 'https://example.com/webhook/mcp-events',
      events: ['task.completed', 'agent.status_changed', 'system.alert'],
      secret: 'webhook-secret-key',
    });
    console.log('Webhook registered:', JSON.stringify(webhook.data, null, 2));

    // List webhooks
    console.log('\n📋 Listing webhooks...');
    const webhooks = await client.listWebhooks();
    console.log('Registered webhooks:', JSON.stringify(webhooks.data, null, 2));

  } catch (error) {
    console.error('Webhook example failed:', error);
  }
}

/**
 * Synchronous usage example
 */
async function synchronousExample(): Promise<void> {
  console.log('\n⚡ Synchronous Usage Example');
  console.log('='.repeat(40));

  try {
    // Quick status check
    console.log('🔍 Quick status check...');
    const status = await quickStatusCheck();
    console.log('Server status:', JSON.stringify(status, null, 2));

    // Create task utility
    console.log('\n📝 Creating task using utility function...');
    const task = await createTask({
      type: 'code_generation',
      parameters: {
        description: 'Generate a hello world function',
        language: 'typescript',
      },
    });
    console.log('Task created:', JSON.stringify(task, null, 2));

  } catch (error) {
    console.error('Synchronous example failed:', error);
  }
}

/**
 * Error handling example
 */
async function errorHandlingExample(): Promise<void> {
  console.log('\n🚨 Error Handling Example');
  console.log('='.repeat(40));

  // Try to connect to a non-existent server
  console.log('🔌 Attempting connection to invalid server...');
  try {
    const client = new MCPClient('http://invalid-server:9999', {
      timeout: 5000,
    });
    const status = await client.getStatus();
    console.log('Status:', status.data);
  } catch (error) {
    console.log(`Expected error: ${error.constructor.name}: ${error.message}`);
  }

  // Try with valid server but invalid operation
  console.log('\n❌ Attempting invalid operation...');
  try {
    const client = new MCPClient();
    // Try to get status of non-existent agent
    const status = await client.getAgentStatus('non-existent-agent-12345');
    console.log('Agent status:', status.data);
  } catch (error) {
    console.log(`Expected error: ${error.constructor.name}: ${error.message}`);
  }
}

/**
 * Advanced configuration example
 */
async function advancedConfigExample(): Promise<void> {
  console.log('\n⚙️  Advanced Configuration Example');
  console.log('='.repeat(40));

  // Custom client configuration
  const client = new MCPClient('http://localhost:5005', {
    timeout: 60000, // 60 seconds
    maxRetries: 5,
    retryDelay: 2000, // 2 seconds
    headers: {
      'X-API-Key': 'your-api-key',
      'X-Client-Version': '1.0.0',
    },
  });

  try {
    console.log('🔧 Testing custom configuration...');
    const status = await client.getStatus();
    console.log('Server status with custom config:', JSON.stringify(status.data, null, 2));

  } catch (error) {
    console.error('Advanced config example failed:', error);
  }
}

/**
 * Main function to run all examples
 */
async function main(): Promise<void> {
  console.log('🚀 MCP TypeScript SDK Examples');
  console.log('='.repeat(50));

  try {
    await basicExample();
    await taskManagementExample();
    await aiFeaturesExample();
    await pluginManagementExample();
    await webhookExample();
    await synchronousExample();
    await errorHandlingExample();
    await advancedConfigExample();

    console.log('\n✅ All examples completed successfully!');

  } catch (error) {
    console.error('\n❌ Examples failed with error:', error);
    process.exit(1);
  }
}

// Run examples if this file is executed directly
if (require.main === module) {
  main().catch(console.error);
}

export {
  basicExample,
  taskManagementExample,
  aiFeaturesExample,
  pluginManagementExample,
  webhookExample,
  synchronousExample,
  errorHandlingExample,
  advancedConfigExample,
};