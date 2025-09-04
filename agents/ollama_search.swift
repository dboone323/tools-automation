#!/usr/bin/env swift
// Ollama Search and Analysis Script
// Uses Ollama AI for intelligent code search and analysis

import Foundation

// Ollama-powered search and analysis
class OllamaSearchAnalyzer {
    private let baseURL = "http://localhost:11434"
    private let session = URLSession.shared

    func analyzeCodebase(query: String, projectPath: String) async throws -> String {
        // Read some key files from the project for analysis
        let keyFiles = try findKeyFiles(in: projectPath)

        let context = keyFiles.map { file in
            """
            File: \(file.path)
            Content preview:
            \(file.content.prefix(1000))
            ---
            """
        }.joined(separator: "\n")

        let prompt = """
        Analyze this codebase based on the query: "\(query)"

        Codebase Context:
        \(context)

        Please provide:
        1. Summary of what the codebase does
        2. Key components and architecture
        3. Potential issues or areas for improvement
        4. Recommendations based on the query
        5. Specific files/locations related to the query

        Focus on being specific and actionable.
        """

        return try await generateWithOllama(prompt: prompt, model: "llama2")
    }

    func findIssues(projectPath: String) async throws -> String {
        let keyFiles = try findKeyFiles(in: projectPath)

        let context = keyFiles.map { file in
            """
            File: \(file.path)
            Content:
            \(file.content.prefix(2000))
            ---
            """
        }.joined(separator: "\n")

        let prompt = """
        Analyze this Swift codebase for potential issues:

        Codebase Content:
        \(context)

        Look for:
        1. Code quality issues
        2. Potential bugs or vulnerabilities
        3. Performance problems
        4. Security concerns
        5. Deprecated API usage
        6. Code smells and anti-patterns
        7. Missing error handling
        8. Poor naming conventions

        Provide specific recommendations with severity levels (Critical/High/Medium/Low) and file locations.
        """

        return try await generateWithOllama(prompt: prompt, model: "codellama")
    }

    func searchForPattern(query: String, projectPath: String) async throws -> String {
        let keyFiles = try findKeyFiles(in: projectPath)

        let context = keyFiles.map { file in
            """
            File: \(file.path)
            Content:
            \(file.content)
            ---
            """
        }.joined(separator: "\n")

        let prompt = """
        Search for patterns related to: "\(query)"

        Codebase Content:
        \(context)

        Find and analyze:
        1. Direct matches for the search term
        2. Related concepts and implementations
        3. Usage patterns and examples
        4. Potential improvements or alternatives
        5. Dependencies and relationships

        Provide specific file locations and code snippets.
        """

        return try await generateWithOllama(prompt: prompt, model: "codellama")
    }

    func generateCodeInsights(projectPath: String) async throws -> String {
        let keyFiles = try findKeyFiles(in: projectPath)

        let context = keyFiles.map { file in
            """
            File: \(file.path)
            Language: Swift
            Content:
            \(file.content.prefix(1500))
            ---
            """
        }.joined(separator: "\n")

        let prompt = """
        Provide comprehensive code insights for this Swift project:

        Project Files:
        \(context)

        Generate insights on:
        1. Overall architecture and design patterns
        2. Code organization and structure
        3. Key classes, structs, and protocols
        4. Data flow and relationships
        5. Potential refactoring opportunities
        6. Best practices compliance
        7. Testing coverage suggestions
        8. Documentation needs

        Be specific and provide actionable recommendations.
        """

        return try await generateWithOllama(prompt: prompt, model: "llama2")
    }

    private func findKeyFiles(in projectPath: String) throws -> [(path: String, content: String)] {
        let fileManager = FileManager.default
        var keyFiles: [(String, String)] = []

        // Common Swift project files to analyze
        let keyFilePatterns = [
            "*.swift",
            "Package.swift",
            "*.xcodeproj",
            "README.md",
            "*.plist",
        ]

        for pattern in keyFilePatterns {
            let enumerator = fileManager.enumerator(atPath: projectPath)
            while let file = enumerator?.nextObject() as? String {
                if fileMatchesPattern(file, pattern: pattern) {
                    let fullPath = "\(projectPath)/\(file)"
                    if let content = try? String(contentsOfFile: fullPath, encoding: .utf8) {
                        keyFiles.append((file, content))
                        if keyFiles.count >= 10 { // Limit to 10 key files
                            break
                        }
                    }
                }
            }
            if keyFiles.count >= 10 {
                break
            }
        }

        return keyFiles
    }

    private func fileMatchesPattern(_ file: String, pattern: String) -> Bool {
        if pattern.hasPrefix("*.") {
            let fileExtension = String(pattern.dropFirst(2))
            return file.hasSuffix(fileExtension)
        }
        return file.contains(pattern)
    }

    private func generateWithOllama(prompt: String, model: String = "llama2") async throws -> String {
        let endpoint = "\(baseURL)/api/generate"

        let requestBody: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "temperature": 0.3,
            "num_predict": 1500,
            "stream": false,
        ]

        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "OllamaSearchAnalyzer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "OllamaSearchAnalyzer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "OllamaSearchAnalyzer", code: 3, userInfo: [NSLocalizedDescriptionKey: "HTTP error: \(httpResponse.statusCode)"])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responseText = json["response"] as? String
        else {
            throw NSError(domain: "OllamaSearchAnalyzer", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
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
    let analyzer = OllamaSearchAnalyzer()

    // Check if Ollama is running
    guard await analyzer.isServerRunning() else {
        print("Error: Ollama server is not running. Please start Ollama first.")
        print("Run: brew services start ollama")
        exit(1)
    }

    let arguments = CommandLine.arguments

    guard arguments.count >= 4 else {
        print("Usage: \(arguments[0]) <command> <project_path> <query>")
        print("Commands: analyze, issues, search, insights")
        exit(1)
    }

    let command = arguments[1]
    let projectPath = arguments[2]
    let query = arguments[3]

    // Verify project path exists
    guard FileManager.default.fileExists(atPath: projectPath) else {
        print("Error: Project path does not exist: \(projectPath)")
        exit(1)
    }

    do {
        switch command {
        case "analyze":
            print("🔍 Analyzing codebase for: \(query)")
            let analysis = try await analyzer.analyzeCodebase(query: query, projectPath: projectPath)
            print("Analysis Results:")
            print("==================")
            print(analysis)

        case "issues":
            print("🔧 Finding issues in codebase...")
            let issues = try await analyzer.findIssues(projectPath: projectPath)
            print("Issues Found:")
            print("=============")
            print(issues)

        case "search":
            print("🔎 Searching for: \(query)")
            let results = try await analyzer.searchForPattern(query: query, projectPath: projectPath)
            print("Search Results:")
            print("===============")
            print(results)

        case "insights":
            print("💡 Generating code insights...")
            let insights = try await analyzer.generateCodeInsights(projectPath: projectPath)
            print("Code Insights:")
            print("==============")
            print(insights)

        default:
            print("Unknown command: \(command)")
            print("Available commands: analyze, issues, search, insights")
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
