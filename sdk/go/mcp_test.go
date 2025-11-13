package mcp

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func setupTestServer() *httptest.Server {
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Match the actual MCP server response format: {"ok": true, "data": {...}}
		response := map[string]interface{}{
			"ok": true,
		}

		switch r.URL.Path {
		case "/status":
			response["data"] = map[string]interface{}{
				"status": "healthy",
				"version": "1.0.0",
			}
		case "/health":
			response["data"] = map[string]interface{}{
				"status": "healthy",
				"uptime": "1h 30m",
			}
		case "/api/agents/status":
			response["data"] = map[string]interface{}{
				"agents": []map[string]interface{}{
					{"name": "agent1", "status": "active", "capabilities": []string{"analysis", "execution"}},
				},
				"total": 1,
			}
		case "/api/tasks/analytics":
			response["data"] = map[string]interface{}{
				"completed_tasks": 34,
				"failed_tasks": 65,
				"queued_tasks": 94,
				"running_tasks": 0,
				"success_rate": 17.616580310880828,
				"timestamp": 1762998703748289,
				"total_tasks": 193,
			}
		case "/run":
			if r.Method == "POST" {
				response["data"] = map[string]interface{}{
					"id": "task-123",
					"status": "queued",
				}
				w.WriteHeader(201)
			}
		default:
			response["ok"] = false
			response["error"] = "Not found"
			w.WriteHeader(404)
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(response)
	}))
}

func TestNewClient(t *testing.T) {
	client := NewClient("http://localhost:5005", nil)
	assert.NotNil(t, client)
	assert.Equal(t, "http://localhost:5005", client.baseURL)
}

func TestDefaultClientOptions(t *testing.T) {
	opts := DefaultClientOptions()
	assert.NotNil(t, opts)
	assert.Equal(t, 30*time.Second, opts.Timeout)
	assert.Equal(t, 3, opts.MaxRetries)
	assert.Equal(t, 1*time.Second, opts.RetryDelay)
}

func TestGetStatus(t *testing.T) {
	server := setupTestServer()
	defer server.Close()

	client := NewClient(server.URL, &ClientOptions{Timeout: 5 * time.Second})

	status, err := client.GetStatus(context.Background())
	require.NoError(t, err)
	assert.NotNil(t, status)
	assert.Equal(t, "healthy", status.Status)
	assert.Equal(t, "1.0.0", status.Version)
}

func TestListControllers(t *testing.T) {
	server := setupTestServer()
	defer server.Close()

	client := NewClient(server.URL, nil)

	controllers, err := client.ListControllers(context.Background())
	require.NoError(t, err)
	assert.NotNil(t, controllers)
	// The response should contain agent data
	assert.NotEmpty(t, *controllers)
}

func TestGetHealth(t *testing.T) {
	server := setupTestServer()
	defer server.Close()

	client := NewClient(server.URL, &ClientOptions{Timeout: 5 * time.Second})

	health, err := client.GetHealth(context.Background())
	require.NoError(t, err)
	assert.NotNil(t, health)
	assert.Equal(t, "healthy", (*health)["status"])
}

func TestListTasks(t *testing.T) {
	server := setupTestServer()
	defer server.Close()

	client := NewClient(server.URL, nil)

	tasks, err := client.ListTasks(context.Background(), "", "")
	require.NoError(t, err)
	assert.NotNil(t, tasks)
	assert.Equal(t, float64(34), (*tasks)["completed_tasks"])
	assert.Equal(t, float64(65), (*tasks)["failed_tasks"])
	assert.Equal(t, float64(94), (*tasks)["queued_tasks"])
	assert.Equal(t, float64(0), (*tasks)["running_tasks"])
}

func TestConnectionError(t *testing.T) {
	client := NewClient("http://invalid-server:9999", &ClientOptions{
		Timeout:    1 * time.Second,
		MaxRetries: 0, // Disable retries for faster test
	})

	_, err := client.GetStatus(context.Background())
	assert.Error(t, err)

	_, ok := err.(ConnectionError)
	assert.True(t, ok)
}

func TestClientWithCustomOptions(t *testing.T) {
	opts := &ClientOptions{
		Timeout:    60 * time.Second,
		MaxRetries: 5,
		RetryDelay: 2 * time.Second,
		Headers: map[string]string{
			"Authorization": "Bearer token123",
			"X-Custom":      "value",
		},
	}

	client := NewClient("http://localhost:5005", opts)
	assert.NotNil(t, client)

	// Check that client has the correct options
	assert.Equal(t, 60*time.Second, client.httpClient.GetClient().Timeout)

	// Check that custom headers are set in the client's default headers
	authHeader := client.httpClient.Header.Get("Authorization")
	customHeader := client.httpClient.Header.Get("X-Custom")
	contentType := client.httpClient.Header.Get("Content-Type")

	assert.Equal(t, "Bearer token123", authHeader)
	assert.Equal(t, "value", customHeader)
	assert.Equal(t, "application/json", contentType)
}

func TestTaskSubmission(t *testing.T) {
	task := TaskSubmission{
		Type:       "code_analysis",
		Target:     "src/main.go",
		Priority:   "high",
		Parameters: map[string]interface{}{
			"includeMetrics": true,
			"outputFormat":   "json",
		},
	}

	data, err := json.Marshal(task)
	require.NoError(t, err)

	var unmarshaled TaskSubmission
	err = json.Unmarshal(data, &unmarshaled)
	require.NoError(t, err)

	assert.Equal(t, task.Type, unmarshaled.Type)
	assert.Equal(t, task.Target, unmarshaled.Target)
	assert.Equal(t, task.Priority, unmarshaled.Priority)
	assert.Equal(t, task.Parameters["includeMetrics"], unmarshaled.Parameters["includeMetrics"])
}

func TestCodeAnalysisRequest(t *testing.T) {
	req := CodeAnalysisRequest{
		Code:     "func add(a, b int) int { return a + b }",
		Language: "go",
		Options: map[string]bool{
			"includeSuggestions": true,
			"includeMetrics":    true,
		},
		Context: map[string]string{
			"framework": "gin",
			"version":   "1.9",
		},
	}

	data, err := json.Marshal(req)
	require.NoError(t, err)

	var unmarshaled CodeAnalysisRequest
	err = json.Unmarshal(data, &unmarshaled)
	require.NoError(t, err)

	assert.Equal(t, req.Code, unmarshaled.Code)
	assert.Equal(t, req.Language, unmarshaled.Language)
	assert.Equal(t, req.Options["includeSuggestions"], unmarshaled.Options["includeSuggestions"])
	assert.Equal(t, req.Context["framework"], unmarshaled.Context["framework"])
}

func TestCodeGenerationRequest(t *testing.T) {
	req := CodeGenerationRequest{
		Description: "Create a REST API handler for user authentication",
		Language:    "go",
		Context:     "Gin web framework application",
		Constraints: []string{
			"Use proper error handling",
			"Include input validation",
			"Return JSON responses",
		},
	}

	data, err := json.Marshal(req)
	require.NoError(t, err)

	var unmarshaled CodeGenerationRequest
	err = json.Unmarshal(data, &unmarshaled)
	require.NoError(t, err)

	assert.Equal(t, req.Description, unmarshaled.Description)
	assert.Equal(t, req.Language, unmarshaled.Language)
	assert.Equal(t, req.Context, unmarshaled.Context)
	assert.Equal(t, req.Constraints, unmarshaled.Constraints)
}

func TestWebhookRegistration(t *testing.T) {
	reg := WebhookRegistration{
		URL:    "https://my-app.com/webhooks/mcp",
		Events: []string{"task.completed", "task.failed"},
		Secret: "webhook-secret-key",
	}

	data, err := json.Marshal(reg)
	require.NoError(t, err)

	var unmarshaled WebhookRegistration
	err = json.Unmarshal(data, &unmarshaled)
	require.NoError(t, err)

	assert.Equal(t, reg.URL, unmarshaled.URL)
	assert.Equal(t, reg.Events, unmarshaled.Events)
	assert.Equal(t, reg.Secret, unmarshaled.Secret)
}