#!/usr/bin/env swift
// Ollama Code Generation Script
// Uses the enhanced OllamaClient for AI-powered code generation

import Foundation

// Import the OllamaClient from the Shared directory
let sharedPath = "/Users/danielstevens/Desktop/Quantum-workspace/Shared"
let ollamaClientPath = "\(sharedPath)/OllamaClient.swift"

// Load the OllamaClient
guard let ollamaClientSource = try? String(contentsOfFile: ollamaClientPath, encoding: .utf8) else {
    print("Error: Could not load OllamaClient.swift")
    exit(1)
}

// Simple Ollama integration for code generation
class OllamaCodeGenerator {
    private let baseURL = "http://localhost:11434"
    private let session = URLSession.shared

    func generateCode(description: String, language: String = "Swift", project: String = "General") async throws -> String {
        let prompt = """
        Generate \(language) code for a \(project) project based on this description:

        Description: \(description)

        Requirements:
        1. Write clean, well-structured, and well-documented code
        2. Include proper error handling
        3. Follow \(language) best practices
        4. Add comments explaining complex logic
        5. Include necessary imports
        6. Make the code production-ready

        Generate the complete code file:
        """

        return try await self.generateWithOllama(prompt: prompt, model: "codellama")
    }

    func analyzeCode(code: String, language: String = "Swift") async throws -> String {
        let prompt = """
        Analyze this \(language) code for:
        1. Potential bugs or issues
        2. Code quality improvements
        3. Best practices suggestions
        4. Security concerns
        5. Performance optimizations

        Code:
        \(code)

        Provide specific recommendations with severity levels:
        """

        return try await self.generateWithOllama(prompt: prompt, model: "codellama")
    }

    func generateTests(code: String, language: String = "Swift", testFramework: String = "XCTest") async throws -> String {
        let prompt = """
        Generate comprehensive \(testFramework) unit tests for this \(language) code:

        Code to test:
        \(code)

        Requirements:
        1. Test all public methods and functions
        2. Include edge cases and error conditions
        3. Test both success and failure scenarios
        4. Add descriptive test names
        5. Include setup and teardown where needed

        Generate the complete test file:
        """

        return try await self.generateWithOllama(prompt: prompt, model: "codellama")
    }

    private func generateWithOllama(prompt: String, model: String = "codellama") async throws -> String {
        let endpoint = "\(baseURL)/api/generate"

        let requestBody: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "temperature": 0.2,
            "num_predict": 1000,
            "stream": false,
        ]

        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "OllamaCodeGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "OllamaCodeGenerator", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard httpResponse.statusCode == 200 else {
            throw NSError(
                domain: "OllamaCodeGenerator",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "HTTP error: \(httpResponse.statusCode)"]
            )
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responseText = json["response"] as? String
        else {
            throw NSError(domain: "OllamaCodeGenerator", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
        }

        return responseText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func isServerRunning() async -> Bool {
        let endpoint = "\(baseURL)/api/tags"

        guard let url = URL(string: endpoint) else {
            return false
        }

        do {
            let (_, response) = try await session.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}

// Main execution function
func main() async {
    let generator = OllamaCodeGenerator()

    // Check if Ollama is running
    guard await generator.isServerRunning() else {
        print("Error: Ollama server is not running. Please start Ollama first.")
        print("Run: brew services start ollama")
        exit(1)
    }

    let arguments = CommandLine.arguments

    guard arguments.count >= 3 else {
        print("Usage: \(arguments[0]) <command> <description/code> [language] [project]")
        print("Commands: generate, analyze, test")
        exit(1)
    }

    let command = arguments[1]
    let input = arguments[2]
    let language = arguments.count > 3 ? arguments[3] : "Swift"
    let project = arguments.count > 4 ? arguments[4] : "General"

    do {
        switch command {
        case "generate":
            print("🤖 Generating \(language) code for \(project)...")
            let code = try await generator.generateCode(description: input, language: language, project: project)
            print("Generated Code:")
            print("```\(language.lowercased())")
            print(code)
            print("```")

        case "analyze":
            print("🔍 Analyzing \(language) code...")
            let analysis = try await generator.analyzeCode(code: input, language: language)
            print("Analysis Results:")
            print(analysis)

        case "test":
            print("🧪 Generating tests for \(language) code...")
            let tests = try await generator.generateTests(code: input, language: language)
            print("Generated Tests:")
            print("```\(language.lowercased())")
            print(tests)
            print("```")

        default:
            print("Unknown command: \(command)")
            print("Available commands: generate, analyze, test")
            exit(1)
        }
    } catch {
        print("Error: \(error.localizedDescription)")
        exit(1)
    }
}

// Run the main function
Task {
    await main()
}
