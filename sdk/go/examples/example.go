package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"strings"
	"time"

	mcp "github.com/dboone323/tools-automation/sdk/go"
)

func main() {
	fmt.Println(strings.Repeat("=", 51))

	// Create MCP client with custom options
	opts := &mcp.ClientOptions{
		Timeout:    30 * time.Second,
		MaxRetries: 3,
		RetryDelay: 1 * time.Second,
		Headers: map[string]string{
			"User-Agent": "mcp-go-sdk-example/1.0.0",
		},
	}
	client := mcp.NewClient("http://localhost:5005", opts)

	ctx := context.Background()

	// Basic server operations
	basicServerExample(ctx, client)

	// Task management
	taskManagementExample(ctx, client)

	// AI features
	aiFeaturesExample(ctx, client)

	// Plugin management
	pluginManagementExample(ctx, client)

	// Webhook management
	webhookExample(ctx, client)

	// Error handling
	errorHandlingExample(ctx)

	fmt.Println("\n✅ All Go SDK examples completed successfully!")
}

func basicServerExample(ctx context.Context, client *mcp.Client) {
	fmt.Println("\n📊 Basic Server Operations Example")
	fmt.Println(strings.Repeat("=", 40))

	// Get server status
	fmt.Println("🔍 Getting server status...")
	status, err := client.GetStatus(ctx)
	if err != nil {
		log.Printf("❌ Error getting status: %v", err)
		return
	}
	printJSON("Server status", status)

	// Get health check
	fmt.Println("🏥 Getting health status...")
	health, err := client.GetHealth(ctx)
	if err != nil {
		log.Printf("❌ Error getting health: %v", err)
		return
	}
	printJSON("Health status", health)

	// List controllers/agents
	fmt.Println("🤖 Listing available agents...")
	agents, err := client.ListControllers(ctx)
	if err != nil {
		log.Printf("❌ Error listing agents: %v", err)
		return
	}
	printJSON("Available agents", agents)
}

func taskManagementExample(ctx context.Context, client *mcp.Client) {
	fmt.Println("\n📋 Task Management Example")
	fmt.Println(strings.Repeat("=", 40))

	// Submit a code analysis task
	fmt.Println("🔍 Submitting code analysis task...")
	task := mcp.TaskSubmission{
		Type:     "code_analysis",
		Target:   "example.go",
		Priority: "normal",
		Parameters: map[string]interface{}{
			"language":      "go",
			"include_metrics": true,
			"depth":         "full",
		},
	}

	taskResult, err := client.SubmitTask(ctx, task)
	if err != nil {
		log.Printf("❌ Error submitting task: %v", err)
		return
	}
	printJSON("Task submitted", taskResult)

	// If task was submitted successfully, check its status
	if taskResult != nil && len(*taskResult) > 0 {
		// Extract task ID from result (this depends on your API response format)
		if taskData, ok := (*taskResult)["data"].(map[string]interface{}); ok {
			if taskID, ok := taskData["id"].(string); ok {
				fmt.Printf("📊 Checking status of task %s...\n", taskID)
				status, err := client.GetTaskStatus(ctx, taskID)
				if err != nil {
					log.Printf("❌ Error getting task status: %v", err)
				} else {
					printJSON("Task status", status)
				}
			}
		}
	}

	// List recent tasks
	fmt.Println("📝 Listing recent tasks...")
	tasks, err := client.ListTasks(ctx, "", "")
	if err != nil {
		log.Printf("❌ Error listing tasks: %v", err)
		return
	}
	printJSON("Recent tasks", tasks)
}

func aiFeaturesExample(ctx context.Context, client *mcp.Client) {
	fmt.Println("\n🤖 AI Features Example")
	fmt.Println(strings.Repeat("=", 40))

	sampleCode := `package main

import "fmt"

func main() {
	fmt.Println("Hello, World!")
}`

	// Analyze code
	fmt.Println("🔬 Analyzing code...")
	analysis := mcp.CodeAnalysisRequest{
		Code:     sampleCode,
		Language: "go",
		Options: map[string]bool{
			"includeSuggestions": true,
			"includeMetrics":    true,
		},
		Context: map[string]string{
			"framework": "none",
			"purpose":   "example",
		},
	}

	analysisResult, err := client.AnalyzeCode(ctx, analysis)
	if err != nil {
		log.Printf("❌ Error analyzing code: %v", err)
	} else {
		printJSON("Code analysis", analysisResult)
	}

	// Generate code
	fmt.Println("💡 Generating code...")
	generation := mcp.CodeGenerationRequest{
		Description: "Create a function to calculate factorial in Go",
		Language:    "go",
		Context:     "mathematical utilities",
		Constraints: []string{
			"Use proper error handling",
			"Include input validation",
			"Use uint64 for large numbers",
		},
	}

	genResult, err := client.GenerateCode(ctx, generation)
	if err != nil {
		log.Printf("❌ Error generating code: %v", err)
	} else {
		printJSON("Generated code", genResult)
	}

	// Performance prediction
	fmt.Println("📈 Predicting performance...")
	metrics := map[string]interface{}{
		"cpu_usage":    45.5,
		"memory_mb":    256,
		"request_rate": 100,
		"error_rate":   0.01,
	}

	prediction, err := client.PredictPerformance(ctx, metrics)
	if err != nil {
		log.Printf("❌ Error predicting performance: %v", err)
	} else {
		printJSON("Performance prediction", prediction)
	}
}

func pluginManagementExample(ctx context.Context, client *mcp.Client) {
	fmt.Println("\n🔌 Plugin Management Example")
	fmt.Println(strings.Repeat("=", 40))

	// List available plugins
	fmt.Println("📦 Listing available plugins...")
	plugins, err := client.ListPlugins(ctx)
	if err != nil {
		log.Printf("❌ Error listing plugins: %v", err)
		return
	}
	printJSON("Available plugins", plugins)

	// If plugins exist, get info about the first one
	if plugins != nil && plugins.Data != nil && len(plugins.Data) > 0 {
		pluginName := plugins.Data[0].Name
		fmt.Printf("ℹ️  Getting info for plugin: %s\n", pluginName)

		info, err := client.GetPluginInfo(ctx, pluginName)
		if err != nil {
			log.Printf("❌ Error getting plugin info: %v", err)
		} else {
			printJSON("Plugin info", info)
		}

		// Example of installing a plugin (commented out to avoid actual installation)
		// fmt.Printf("⬇️  Installing plugin: %s\n", pluginName)
		// config := map[string]interface{}{
		//     "auto_start": true,
		//     "settings": map[string]interface{}{
		//         "log_level": "info",
		//     },
		// }
		// installResult, err := client.InstallPlugin(ctx, pluginName, config)
		// if err != nil {
		//     log.Printf("❌ Error installing plugin: %v", err)
		// } else {
		//     printJSON("Install result", installResult)
		// }
	}
}

func webhookExample(ctx context.Context, client *mcp.Client) {
	fmt.Println("\n🪝 Webhook Management Example")
	fmt.Println(strings.Repeat("=", 40))

	// Register a webhook
	fmt.Println("📡 Registering webhook...")
	webhook := mcp.WebhookRegistration{
		URL:    "https://example.com/webhook/mcp-events",
		Events: []string{"task.completed", "agent.status_changed", "system.alert"},
		Secret: "webhook-secret-key-12345",
	}

	regResult, err := client.RegisterWebhook(ctx, webhook)
	if err != nil {
		log.Printf("❌ Error registering webhook: %v", err)
	} else {
		printJSON("Webhook registered", regResult)
	}

	// List webhooks
	fmt.Println("📋 Listing webhooks...")
	webhooks, err := client.ListWebhooks(ctx)
	if err != nil {
		log.Printf("❌ Error listing webhooks: %v", err)
	} else {
		printJSON("Registered webhooks", webhooks)
	}
}

func errorHandlingExample(ctx context.Context) {
	fmt.Println("\n🚨 Error Handling Example")
	fmt.Println(strings.Repeat("=", 40))

	// Try to connect to a non-existent server
	fmt.Println("🔌 Attempting connection to invalid server...")
	invalidClient := mcp.NewClient("http://invalid-server:9999", &mcp.ClientOptions{
		Timeout:    5 * time.Second,
		MaxRetries: 2,
	})

	_, err := invalidClient.GetStatus(ctx)
	if err != nil {
		fmt.Printf("✅ Expected connection error: %T - %v\n", err, err)
	}

	// Try with valid server but invalid operation
	fmt.Println("❌ Attempting invalid operation...")
	validClient := mcp.NewClient("http://localhost:5005", nil)

	// Try to get status of non-existent agent
	_, err = validClient.GetAgentStatus(ctx, "non-existent-agent-12345")
	if err != nil {
		fmt.Printf("✅ Expected API error: %T - %v\n", err, err)
	}

	// Try to cancel non-existent task
	_, err = validClient.CancelTask(ctx, "invalid-task-id-12345")
	if err != nil {
		fmt.Printf("✅ Expected cancellation error: %T - %v\n", err, err)
	}
}

// Helper function to pretty print JSON
func printJSON(label string, data interface{}) {
	jsonData, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		fmt.Printf("%s: <error marshaling JSON: %v>\n", label, err)
		return
	}
	fmt.Printf("%s:\n%s\n", label, string(jsonData))
}