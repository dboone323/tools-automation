// Package mcp provides a Go SDK for interacting with MCP (Model Context Protocol) servers
package mcp

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/go-resty/resty/v2"
)

// Client represents an MCP server client
type Client struct {
	baseURL    string
	httpClient *resty.Client
}

// ClientOptions contains configuration options for the MCP client
type ClientOptions struct {
	Timeout    time.Duration
	MaxRetries int
	RetryDelay time.Duration
	Headers    map[string]string
}

// DefaultClientOptions returns default client options
func DefaultClientOptions() *ClientOptions {
	return &ClientOptions{
		Timeout:    30 * time.Second,
		MaxRetries: 3,
		RetryDelay: 1 * time.Second,
		Headers:    make(map[string]string),
	}
}

// NewClient creates a new MCP client
func NewClient(baseURL string, opts *ClientOptions) *Client {
	if opts == nil {
		opts = DefaultClientOptions()
	}

	httpClient := resty.New().
		SetBaseURL(baseURL).
		SetTimeout(opts.Timeout).
		SetRetryCount(opts.MaxRetries).
		SetRetryWaitTime(opts.RetryDelay).
		SetRetryMaxWaitTime(30 * time.Second).
		SetHeaders(opts.Headers).
		SetHeader("Content-Type", "application/json").
		SetHeader("User-Agent", "mcp-go-sdk/1.0.0")

	return &Client{
		baseURL:    baseURL,
		httpClient: httpClient,
	}
}

// Response represents a standard MCP API response
type Response[T any] struct {
	Success     bool   `json:"success"`
	Data        T      `json:"data,omitempty"`
	Error       string `json:"error,omitempty"`
	StatusCode  int    `json:"statusCode"`
	ResponseTime int64  `json:"responseTime"`
}

// Error types
type (
	// MCPError represents an MCP API error
	MCPError struct {
		StatusCode int
		Message    string
		Response   interface{}
	}

	// ConnectionError represents a connection/network error
	ConnectionError struct {
		Err error
	}
)

func (e MCPError) Error() string {
	return fmt.Sprintf("MCP error (%d): %s", e.StatusCode, e.Message)
}

func (e ConnectionError) Error() string {
	return fmt.Sprintf("connection error: %v", e.Err)
}

// ServerStatus represents server status information
type ServerStatus struct {
	Status      string    `json:"status"`
	Version     string    `json:"version,omitempty"`
	Uptime      int64     `json:"uptime,omitempty"`
	LastChecked time.Time `json:"lastChecked,omitempty"`
}

// AgentStatus represents agent status information
type AgentStatus struct {
	Name          string   `json:"name"`
	Status        string   `json:"status"`
	LastSeen      string   `json:"lastSeen"`
	HealthScore   float64  `json:"healthScore"`
	Capabilities  []string `json:"capabilities"`
	ActiveTasks   int      `json:"activeTasks,omitempty"`
	TotalTasks    int      `json:"totalTasks,omitempty"`
}

// TaskInfo represents task information
type TaskInfo struct {
	ID          string                 `json:"id"`
	Status      string                 `json:"status"`
	Type        string                 `json:"type"`
	Agent       string                 `json:"agent"`
	CreatedAt   string                 `json:"createdAt"`
	CompletedAt string                 `json:"completedAt,omitempty"`
	Result      map[string]interface{} `json:"result,omitempty"`
	Error       string                 `json:"error,omitempty"`
	Priority    string                 `json:"priority,omitempty"`
	Progress    float64                `json:"progress,omitempty"`
}

// TaskSubmission represents a task submission request
type TaskSubmission struct {
	Type       string                 `json:"type"`
	Target     string                 `json:"target,omitempty"`
	Parameters map[string]interface{} `json:"parameters,omitempty"`
	Priority   string                 `json:"priority,omitempty"`
	Agent      string                 `json:"agent,omitempty"`
}

// CodeAnalysisRequest represents a code analysis request
type CodeAnalysisRequest struct {
	Code     string            `json:"code"`
	Language string            `json:"language,omitempty"`
	Options  map[string]bool   `json:"options,omitempty"`
	Context  map[string]string `json:"context,omitempty"`
}

// CodeGenerationRequest represents a code generation request
type CodeGenerationRequest struct {
	Description string   `json:"description"`
	Language    string   `json:"language,omitempty"`
	Context     string   `json:"context,omitempty"`
	Constraints []string `json:"constraints,omitempty"`
}

// WebhookRegistration represents a webhook registration
type WebhookRegistration struct {
	URL    string   `json:"url"`
	Events []string `json:"events"`
	Secret string   `json:"secret,omitempty"`
}

// PluginInfo represents plugin information
type PluginInfo struct {
	Name         string   `json:"name"`
	Version      string   `json:"version"`
	Description  string   `json:"description,omitempty"`
	Capabilities []string `json:"capabilities"`
	Status       string   `json:"status"`
	InstalledAt  string   `json:"installedAt,omitempty"`
}

// makeRequest performs an HTTP request and handles the response
func (c *Client) makeRequest(ctx context.Context, method, path string, body interface{}, result interface{}) error {
	req := c.httpClient.R().
		SetContext(ctx).
		SetResult(&result)

	if body != nil {
		req.SetBody(body)
	}

	resp, err := req.Execute(method, path)
	if err != nil {
		return ConnectionError{Err: err}
	}

	// Parse MCP server response format: {"ok": true, "data": {...}} or {"ok": true, "status": {...}}
	var mcpResp map[string]interface{}
	if err := json.Unmarshal(resp.Body(), &mcpResp); err != nil {
		return fmt.Errorf("failed to parse response: %w", err)
	}

	// Check if request was successful
	if ok, exists := mcpResp["ok"]; !exists || ok != true {
		statusCode := resp.StatusCode()
		errorMsg := "Unknown error"
		if errStr, exists := mcpResp["error"]; exists {
			errorMsg = fmt.Sprintf("%v", errStr)
		}
		return MCPError{
			StatusCode: statusCode,
			Message:    errorMsg,
			Response:   mcpResp,
		}
	}

	// Extract data from response - could be under different keys
	var data interface{}
	if d, exists := mcpResp["data"]; exists {
		data = d
	} else if s, exists := mcpResp["status"]; exists {
		data = s
	} else if agents, exists := mcpResp["agents"]; exists {
		data = agents
	} else if tasks, exists := mcpResp["analytics"]; exists {
		data = tasks
	} else {
		// For endpoints that return data at root level
		data = mcpResp
	}

	// Unmarshal the data into the result
	if data != nil && result != nil {
		dataBytes, err := json.Marshal(data)
		if err != nil {
			return fmt.Errorf("failed to marshal response data: %w", err)
		}
		if err := json.Unmarshal(dataBytes, result); err != nil {
			return fmt.Errorf("failed to unmarshal response data: %w", err)
		}
	}

	return nil
}

// GetStatus retrieves server status
func (c *Client) GetStatus(ctx context.Context) (*ServerStatus, error) {
	var result ServerStatus
	err := c.makeRequest(ctx, http.MethodGet, "/status", nil, &result)
	if err != nil {
		return nil, err
	}
	return &result, nil
}

// GetHealth performs a health check
func (c *Client) GetHealth(ctx context.Context) (*map[string]interface{}, error) {
	var result map[string]interface{}
	err := c.makeRequest(ctx, http.MethodGet, "/health", nil, &result)
	if err != nil {
		return nil, err
	}
	return &result, nil
}

// ListControllers lists all available agents
func (c *Client) ListControllers(ctx context.Context) (*map[string]interface{}, error) {
	var result map[string]interface{}
	err := c.makeRequest(ctx, http.MethodGet, "/api/agents/status", nil, &result)
	if err != nil {
		return nil, err
	}
	return &result, nil
}

// GetAgentStatus gets status of a specific agent
func (c *Client) GetAgentStatus(ctx context.Context, agentName string) (*Response[AgentStatus], error) {
	var result AgentStatus
	path := fmt.Sprintf("/agents/%s", agentName)
	err := c.makeRequest(ctx, http.MethodGet, path, nil, &result)
	if err != nil {
		return nil, err
	}
	return &Response[AgentStatus]{
		Success:      true,
		Data:         result,
		StatusCode:   200,
		ResponseTime: 0,
	}, nil
}

// RegisterAgent registers a new agent
func (c *Client) RegisterAgent(ctx context.Context, name string, capabilities []string) (*Response[AgentStatus], error) {
	body := map[string]interface{}{
		"name":         name,
		"capabilities": capabilities,
	}
	var result AgentStatus
	err := c.makeRequest(ctx, http.MethodPost, "/agents", body, &result)
	if err != nil {
		return nil, err
	}
	return &Response[AgentStatus]{
		Success:      true,
		Data:         result,
		StatusCode:   201,
		ResponseTime: 0,
	}, nil
}

// SubmitTask submits a task for processing
func (c *Client) SubmitTask(ctx context.Context, task TaskSubmission) (*map[string]interface{}, error) {
	var result map[string]interface{}
	err := c.makeRequest(ctx, http.MethodPost, "/run", task, &result)
	if err != nil {
		return nil, err
	}
	return &result, nil
}

// GetTaskStatus gets the status of a task
func (c *Client) GetTaskStatus(ctx context.Context, taskID string) (*Response[TaskInfo], error) {
	var result TaskInfo
	path := fmt.Sprintf("/tasks/%s", taskID)
	err := c.makeRequest(ctx, http.MethodGet, path, nil, &result)
	if err != nil {
		return nil, err
	}
	return &Response[TaskInfo]{
		Success:      true,
		Data:         result,
		StatusCode:   200,
		ResponseTime: 0,
	}, nil
}

// ListTasks lists tasks with optional filtering
func (c *Client) ListTasks(ctx context.Context, status, agent string) (*map[string]interface{}, error) {
	var result map[string]interface{}
	err := c.makeRequest(ctx, http.MethodGet, "/api/tasks/analytics", nil, &result)
	if err != nil {
		return nil, err
	}
	return &result, nil
}

// CancelTask cancels a running task
func (c *Client) CancelTask(ctx context.Context, taskID string) (*Response[map[string]string], error) {
	var result map[string]string
	path := fmt.Sprintf("/tasks/%s/cancel", taskID)
	err := c.makeRequest(ctx, http.MethodPost, path, nil, &result)
	if err != nil {
		return nil, err
	}
	return &Response[map[string]string]{
		Success:      true,
		Data:         result,
		StatusCode:   200,
		ResponseTime: 0,
	}, nil
}

// AnalyzeCode performs AI-powered code analysis
func (c *Client) AnalyzeCode(ctx context.Context, req CodeAnalysisRequest) (*Response[map[string]interface{}], error) {
	var result map[string]interface{}
	err := c.makeRequest(ctx, http.MethodPost, "/ai/analyze", req, &result)
	if err != nil {
		return nil, err
	}
	return &Response[map[string]interface{}]{
		Success:      true,
		Data:         result,
		StatusCode:   200,
		ResponseTime: 0,
	}, nil
}

// PredictPerformance predicts performance metrics
func (c *Client) PredictPerformance(ctx context.Context, metrics map[string]interface{}) (*Response[map[string]interface{}], error) {
	var result map[string]interface{}
	err := c.makeRequest(ctx, http.MethodPost, "/ai/predict", metrics, &result)
	if err != nil {
		return nil, err
	}
	return &Response[map[string]interface{}]{
		Success:      true,
		Data:         result,
		StatusCode:   200,
		ResponseTime: 0,
	}, nil
}

// GenerateCode generates code from description
func (c *Client) GenerateCode(ctx context.Context, req CodeGenerationRequest) (*Response[map[string]interface{}], error) {
	var result map[string]interface{}
	err := c.makeRequest(ctx, http.MethodPost, "/ai/generate", req, &result)
	if err != nil {
		return nil, err
	}
	return &Response[map[string]interface{}]{
		Success:      true,
		Data:         result,
		StatusCode:   200,
		ResponseTime: 0,
	}, nil
}

// RegisterWebhook registers a webhook for events
func (c *Client) RegisterWebhook(ctx context.Context, registration WebhookRegistration) (*Response[map[string]interface{}], error) {
	var result map[string]interface{}
	err := c.makeRequest(ctx, http.MethodPost, "/webhooks", registration, &result)
	if err != nil {
		return nil, err
	}
	return &Response[map[string]interface{}]{
		Success:      true,
		Data:         result,
		StatusCode:   201,
		ResponseTime: 0,
	}, nil
}

// ListWebhooks lists registered webhooks
func (c *Client) ListWebhooks(ctx context.Context) (*Response[[]map[string]interface{}], error) {
	var result []map[string]interface{}
	err := c.makeRequest(ctx, http.MethodGet, "/webhooks", nil, &result)
	if err != nil {
		return nil, err
	}
	return &Response[[]map[string]interface{}]{
		Success:      true,
		Data:         result,
		StatusCode:   200,
		ResponseTime: 0,
	}, nil
}

// DeleteWebhook deletes a webhook
func (c *Client) DeleteWebhook(ctx context.Context, webhookID string) (*Response[map[string]string], error) {
	var result map[string]string
	path := fmt.Sprintf("/webhooks/%s", webhookID)
	err := c.makeRequest(ctx, http.MethodDelete, path, nil, &result)
	if err != nil {
		return nil, err
	}
	return &Response[map[string]string]{
		Success:      true,
		Data:         result,
		StatusCode:   200,
		ResponseTime: 0,
	}, nil
}

// ListPlugins lists available plugins
func (c *Client) ListPlugins(ctx context.Context) (*Response[[]PluginInfo], error) {
	var result []PluginInfo
	err := c.makeRequest(ctx, http.MethodGet, "/plugins", nil, &result)
	if err != nil {
		return nil, err
	}
	return &Response[[]PluginInfo]{
		Success:      true,
		Data:         result,
		StatusCode:   200,
		ResponseTime: 0,
	}, nil
}

// GetPluginInfo gets information about a specific plugin
func (c *Client) GetPluginInfo(ctx context.Context, pluginName string) (*Response[PluginInfo], error) {
	var result PluginInfo
	path := fmt.Sprintf("/plugins/%s", pluginName)
	err := c.makeRequest(ctx, http.MethodGet, path, nil, &result)
	if err != nil {
		return nil, err
	}
	return &Response[PluginInfo]{
		Success:      true,
		Data:         result,
		StatusCode:   200,
		ResponseTime: 0,
	}, nil
}

// InstallPlugin installs a plugin
func (c *Client) InstallPlugin(ctx context.Context, pluginName string, config map[string]interface{}) (*Response[PluginInfo], error) {
	body := map[string]interface{}{
		"name":   pluginName,
		"config": config,
	}
	var result PluginInfo
	err := c.makeRequest(ctx, http.MethodPost, "/plugins/install", body, &result)
	if err != nil {
		return nil, err
	}
	return &Response[PluginInfo]{
		Success:      true,
		Data:         result,
		StatusCode:   200,
		ResponseTime: 0,
	}, nil
}

// UninstallPlugin uninstalls a plugin
func (c *Client) UninstallPlugin(ctx context.Context, pluginName string) (*Response[map[string]string], error) {
	var result map[string]string
	path := fmt.Sprintf("/plugins/%s/uninstall", pluginName)
	err := c.makeRequest(ctx, http.MethodPost, path, nil, &result)
	if err != nil {
		return nil, err
	}
	return &Response[map[string]string]{
		Success:      true,
		Data:         result,
		StatusCode:   200,
		ResponseTime: 0,
	}, nil
}