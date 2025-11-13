package mcp // import "github.com/dboone323/tools-automation/sdk/go"

Package mcp provides a Go SDK for interacting with MCP (Model Context Protocol)
servers

TYPES

type AgentStatus struct {
	Name         string   `json:"name"`
	Status       string   `json:"status"`
	LastSeen     string   `json:"lastSeen"`
	HealthScore  float64  `json:"healthScore"`
	Capabilities []string `json:"capabilities"`
	ActiveTasks  int      `json:"activeTasks,omitempty"`
	TotalTasks   int      `json:"totalTasks,omitempty"`
}
    AgentStatus represents agent status information

type Client struct {
	// Has unexported fields.
}
    Client represents an MCP server client

func NewClient(baseURL string, opts *ClientOptions) *Client
    NewClient creates a new MCP client

func (c *Client) AnalyzeCode(ctx context.Context, req CodeAnalysisRequest) (*Response[map[string]interface{}], error)
    AnalyzeCode performs AI-powered code analysis

func (c *Client) CancelTask(ctx context.Context, taskID string) (*Response[map[string]string], error)
    CancelTask cancels a running task

func (c *Client) DeleteWebhook(ctx context.Context, webhookID string) (*Response[map[string]string], error)
    DeleteWebhook deletes a webhook

func (c *Client) GenerateCode(ctx context.Context, req CodeGenerationRequest) (*Response[map[string]interface{}], error)
    GenerateCode generates code from description

func (c *Client) GetAgentStatus(ctx context.Context, agentName string) (*Response[AgentStatus], error)
    GetAgentStatus gets status of a specific agent

func (c *Client) GetHealth(ctx context.Context) (*map[string]interface{}, error)
    GetHealth performs a health check

func (c *Client) GetPluginInfo(ctx context.Context, pluginName string) (*Response[PluginInfo], error)
    GetPluginInfo gets information about a specific plugin

func (c *Client) GetStatus(ctx context.Context) (*ServerStatus, error)
    GetStatus retrieves server status

func (c *Client) GetTaskStatus(ctx context.Context, taskID string) (*Response[TaskInfo], error)
    GetTaskStatus gets the status of a task

func (c *Client) InstallPlugin(ctx context.Context, pluginName string, config map[string]interface{}) (*Response[PluginInfo], error)
    InstallPlugin installs a plugin

func (c *Client) ListControllers(ctx context.Context) (*map[string]interface{}, error)
    ListControllers lists all available agents

func (c *Client) ListPlugins(ctx context.Context) (*Response[[]PluginInfo], error)
    ListPlugins lists available plugins

func (c *Client) ListTasks(ctx context.Context, status, agent string) (*map[string]interface{}, error)
    ListTasks lists tasks with optional filtering

func (c *Client) ListWebhooks(ctx context.Context) (*Response[[]map[string]interface{}], error)
    ListWebhooks lists registered webhooks

func (c *Client) PredictPerformance(ctx context.Context, metrics map[string]interface{}) (*Response[map[string]interface{}], error)
    PredictPerformance predicts performance metrics

func (c *Client) RegisterAgent(ctx context.Context, name string, capabilities []string) (*Response[AgentStatus], error)
    RegisterAgent registers a new agent

func (c *Client) RegisterWebhook(ctx context.Context, registration WebhookRegistration) (*Response[map[string]interface{}], error)
    RegisterWebhook registers a webhook for events

func (c *Client) SubmitTask(ctx context.Context, task TaskSubmission) (*map[string]interface{}, error)
    SubmitTask submits a task for processing

func (c *Client) UninstallPlugin(ctx context.Context, pluginName string) (*Response[map[string]string], error)
    UninstallPlugin uninstalls a plugin

type ClientOptions struct {
	Timeout    time.Duration
	MaxRetries int
	RetryDelay time.Duration
	Headers    map[string]string
}
    ClientOptions contains configuration options for the MCP client

func DefaultClientOptions() *ClientOptions
    DefaultClientOptions returns default client options

type CodeAnalysisRequest struct {
	Code     string            `json:"code"`
	Language string            `json:"language,omitempty"`
	Options  map[string]bool   `json:"options,omitempty"`
	Context  map[string]string `json:"context,omitempty"`
}
    CodeAnalysisRequest represents a code analysis request

type CodeGenerationRequest struct {
	Description string   `json:"description"`
	Language    string   `json:"language,omitempty"`
	Context     string   `json:"context,omitempty"`
	Constraints []string `json:"constraints,omitempty"`
}
    CodeGenerationRequest represents a code generation request

type ConnectionError struct {
	Err error
}
    ConnectionError represents a connection/network error

func (e ConnectionError) Error() string

type MCPError struct {
	StatusCode int
	Message    string
	Response   interface{}
}
    MCPError represents an MCP API error

func (e MCPError) Error() string

type PluginInfo struct {
	Name         string   `json:"name"`
	Version      string   `json:"version"`
	Description  string   `json:"description,omitempty"`
	Capabilities []string `json:"capabilities"`
	Status       string   `json:"status"`
	InstalledAt  string   `json:"installedAt,omitempty"`
}
    PluginInfo represents plugin information

type Response[T any] struct {
	Success      bool   `json:"success"`
	Data         T      `json:"data,omitempty"`
	Error        string `json:"error,omitempty"`
	StatusCode   int    `json:"statusCode"`
	ResponseTime int64  `json:"responseTime"`
}
    Response represents a standard MCP API response

type ServerStatus struct {
	Status      string    `json:"status"`
	Version     string    `json:"version,omitempty"`
	Uptime      int64     `json:"uptime,omitempty"`
	LastChecked time.Time `json:"lastChecked,omitempty"`
}
    ServerStatus represents server status information

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
    TaskInfo represents task information

type TaskSubmission struct {
	Type       string                 `json:"type"`
	Target     string                 `json:"target,omitempty"`
	Parameters map[string]interface{} `json:"parameters,omitempty"`
	Priority   string                 `json:"priority,omitempty"`
	Agent      string                 `json:"agent,omitempty"`
}
    TaskSubmission represents a task submission request

type WebhookRegistration struct {
	URL    string   `json:"url"`
	Events []string `json:"events"`
	Secret string   `json:"secret,omitempty"`
}
    WebhookRegistration represents a webhook registration

