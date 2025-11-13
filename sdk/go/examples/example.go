package main

import (
	"context"
	"fmt"
	"log"

	mcp "github.com/dboone323/tools-automation/sdk/go"
)

func main() {
	// Create MCP client
	client := mcp.NewClient("http://localhost:5005", nil)

	// Get server status
	fmt.Println("Getting server status...")
	status, err := client.GetStatus(context.Background())
	if err != nil {
		log.Printf("Error getting status: %v", err)
	} else {
		fmt.Printf("Server status: %+v\n", *status)
	}

	// Get health check
	fmt.Println("Getting health status...")
	health, err := client.GetHealth(context.Background())
	if err != nil {
		log.Printf("Error getting health: %v", err)
	} else {
		fmt.Printf("Health status: %+v\n", *health)
	}

	// Submit a task
	fmt.Println("Submitting a task...")
	task := mcp.TaskSubmission{
		Type:     "code_analysis",
		Target:   "example.go",
		Priority: "high",
		Parameters: map[string]interface{}{
			"language": "go",
			"depth":    "full",
		},
	}

	taskResult, err := client.SubmitTask(context.Background(), task)
	if err != nil {
		log.Printf("Error submitting task: %v", err)
	} else {
		fmt.Printf("Task submitted: %+v\n", *taskResult)
	}

	// List tasks
	fmt.Println("Listing tasks...")
	tasks, err := client.ListTasks(context.Background(), "", "")
	if err != nil {
		log.Printf("Error listing tasks: %v", err)
	} else {
		fmt.Printf("Tasks: %+v\n", *tasks)
	}

	fmt.Println("Go SDK example completed!")
}