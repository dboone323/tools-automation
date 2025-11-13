/**
 * MCP TypeScript SDK
 *
 * A comprehensive TypeScript SDK for interacting with the MCP (Model Context Protocol) server.
 *
 * Features:
 * - Full API coverage for all MCP endpoints
 * - TypeScript types and interfaces
 * - Promise-based async operations
 * - Automatic retry logic and error handling
 * - Axios-based HTTP client with interceptors
 */

import axios, { AxiosInstance, AxiosResponse } from 'axios';

// Types and Interfaces

export interface MCPResponse<T = any> {
  success: boolean;
  data: T;
  error?: string;
  statusCode: number;
  responseTime: number;
}

export interface AgentStatus {
  name: string;
  status: string;
  lastSeen: string;
  healthScore: number;
  capabilities: string[];
}

export interface TaskInfo {
  id: string;
  status: string;
  agent: string;
  createdAt: string;
  completedAt?: string;
  result?: any;
}

export interface TaskSubmission {
  type: string;
  target?: string;
  parameters?: Record<string, any>;
  priority?: 'low' | 'normal' | 'high' | 'critical';
}

export interface WebhookRegistration {
  url: string;
  events: string[];
  secret?: string;
}

export interface PluginInfo {
  name: string;
  version: string;
  description: string;
  capabilities: string[];
  installed: boolean;
}

export interface CodeAnalysisRequest {
  code: string;
  language?: string;
  options?: {
    includeSuggestions?: boolean;
    includeMetrics?: boolean;
  };
}

export interface CodeGenerationRequest {
  description: string;
  language?: string;
  context?: string;
  constraints?: string[];
}

export class MCPError extends Error {
  public statusCode: number;

  constructor(message: string, statusCode: number) {
    super(message);
    this.name = 'MCPError';
    this.statusCode = statusCode;
  }
}

export class MCPConnectionError extends MCPError {
  constructor(message: string) {
    super(message, 0);
    this.name = 'MCPConnectionError';
  }
}

export class MCPTimeoutError extends MCPError {
  constructor(message: string) {
    super(message, 408);
    this.name = 'MCPTimeoutError';
  }
}

// Main Client Class

export class MCPClient {
  private client: AxiosInstance;
  private baseURL: string;

  constructor(
    baseURL: string = 'http://localhost:5005',
    options: {
      timeout?: number;
      maxRetries?: number;
      retryDelay?: number;
      headers?: Record<string, string>;
    } = {}
  ) {
    this.baseURL = baseURL;

    this.client = axios.create({
      baseURL,
      timeout: options.timeout || 30000,
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'MCP-TypeScript-SDK/1.0.0',
        ...options.headers,
      },
    });

    // Add response interceptor for error handling
    this.client.interceptors.response.use(
      (response) => response,
      (error) => {
        if (error.code === 'ECONNREFUSED' || error.code === 'ENOTFOUND') {
          throw new MCPConnectionError(`Cannot connect to MCP server at ${baseURL}`);
        }

        if (error.code === 'ETIMEDOUT') {
          throw new MCPTimeoutError('Request timed out');
        }

        if (error.response) {
          const statusCode = error.response.status;
          const message = error.response.data?.error || error.message;
          throw new MCPError(message, statusCode);
        }

        throw error;
      }
    );

    // Configure retry logic
    const maxRetries = options.maxRetries || 3;
    const retryDelay = options.retryDelay || 1000;

    this.client.interceptors.response.use(
      async (response) => response,
      async (error) => {
        if (!error.config || maxRetries === 0) {
          throw error;
        }

        const config = error.config;
        config.retryCount = config.retryCount || 0;

        if (config.retryCount >= maxRetries) {
          throw error;
        }

        // Retry for server errors (5xx) and network errors
        if (
          error.response?.status >= 500 ||
          error.code === 'ECONNRESET' ||
          error.code === 'ETIMEDOUT'
        ) {
          config.retryCount += 1;
          const delay = retryDelay * Math.pow(2, config.retryCount - 1);

          await new Promise(resolve => setTimeout(resolve, delay));
          return this.client(config);
        }

        throw error;
      }
    );
  }

  private async makeRequest<T>(
    method: 'GET' | 'POST' | 'PUT' | 'DELETE',
    endpoint: string,
    data?: any,
    params?: Record<string, any>
  ): Promise<MCPResponse<T>> {
    const startTime = Date.now();

    try {
      const response: AxiosResponse = await this.client.request({
        method,
        url: endpoint,
        data,
        params,
      });

      const responseTime = Date.now() - startTime;

      return {
        success: true,
        data: response.data,
        statusCode: response.status,
        responseTime,
      };
    } catch (error) {
      const responseTime = Date.now() - startTime;

      if (error instanceof MCPError) {
        return {
          success: false,
          data: null as any,
          error: error.message,
          statusCode: error.statusCode,
          responseTime,
        };
      }

      throw error;
    }
  }

  // Status and Health Endpoints

  async getStatus(): Promise<MCPResponse<any>> {
    return this.makeRequest('GET', '/status');
  }

  async getHealth(): Promise<MCPResponse<any>> {
    return this.makeRequest('GET', '/health');
  }

  // Agent Management Endpoints

  async listControllers(): Promise<MCPResponse<AgentStatus[]>> {
    return this.makeRequest('GET', '/controllers');
  }

  async getAgentStatus(agentName: string): Promise<MCPResponse<AgentStatus>> {
    return this.makeRequest('GET', `/agents/${agentName}/status`);
  }

  async registerAgent(
    name: string,
    capabilities: string[]
  ): Promise<MCPResponse<{ agentId: string; registered: boolean }>> {
    return this.makeRequest('POST', '/agents/register', {
      name,
      capabilities,
    });
  }

  // Task Management Endpoints

  async submitTask(task: TaskSubmission): Promise<MCPResponse<TaskInfo>> {
    return this.makeRequest('POST', '/tasks/submit', task);
  }

  async getTaskStatus(taskId: string): Promise<MCPResponse<TaskInfo>> {
    return this.makeRequest('GET', `/tasks/${taskId}/status`);
  }

  async listTasks(
    options: {
      status?: string;
      limit?: number;
      offset?: number;
    } = {}
  ): Promise<MCPResponse<TaskInfo[]>> {
    return this.makeRequest('GET', '/tasks', options);
  }

  async cancelTask(taskId: string): Promise<MCPResponse<{ cancelled: boolean }>> {
    return this.makeRequest('POST', `/tasks/${taskId}/cancel`);
  }

  // AI Endpoints

  async analyzeCode(request: CodeAnalysisRequest): Promise<MCPResponse<any>> {
    return this.makeRequest('POST', '/api/ai/analyze_code', request);
  }

  async predictPerformance(metrics: Record<string, any>): Promise<MCPResponse<any>> {
    return this.makeRequest('POST', '/api/ai/predict_performance', metrics);
  }

  async generateCode(request: CodeGenerationRequest): Promise<MCPResponse<any>> {
    return this.makeRequest('POST', '/api/ai/generate_code', request);
  }

  // Webhook Management

  async registerWebhook(
    registration: WebhookRegistration
  ): Promise<MCPResponse<{ webhookId: string; registered: boolean }>> {
    return this.makeRequest('POST', '/webhooks/register', registration);
  }

  async listWebhooks(): Promise<MCPResponse<any[]>> {
    return this.makeRequest('GET', '/webhooks');
  }

  async deleteWebhook(webhookId: string): Promise<MCPResponse<{ deleted: boolean }>> {
    return this.makeRequest('DELETE', `/webhooks/${webhookId}`);
  }

  // Plugin Management

  async listPlugins(): Promise<MCPResponse<PluginInfo[]>> {
    return this.makeRequest('GET', '/plugins');
  }

  async getPluginInfo(pluginName: string): Promise<MCPResponse<PluginInfo>> {
    return this.makeRequest('GET', `/plugins/${pluginName}`);
  }

  async installPlugin(
    pluginName: string,
    config?: Record<string, any>
  ): Promise<MCPResponse<{ installed: boolean; version: string }>> {
    return this.makeRequest('POST', `/plugins/${pluginName}/install`, config || {});
  }

  async uninstallPlugin(pluginName: string): Promise<MCPResponse<{ uninstalled: boolean }>> {
    return this.makeRequest('POST', `/plugins/${pluginName}/uninstall`);
  }
}

// Utility Functions

export async function quickStatusCheck(
  baseURL: string = 'http://localhost:5005'
): Promise<any> {
  const client = new MCPClient(baseURL);
  const response = await client.getStatus();
  return response.data;
}

export async function createTask(
  task: TaskSubmission,
  baseURL: string = 'http://localhost:5005'
): Promise<TaskInfo> {
  const client = new MCPClient(baseURL);
  const response = await client.submitTask(task);
  return response.data;
}

// Default export
export default MCPClient;