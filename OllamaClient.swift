// OllamaClient.swift: Unified Ollama adapter for Swift scripts
// Expects JSON input: { task, prompt, system?, files[], images[], params? }
// Outputs JSON: { text, model, latency_ms, tokens_est?, fallback_used?, error? }

import Foundation

struct OllamaRequest: Codable {
    let task: String
    let prompt: String
    let system: String?
    let files: [String]?
    let images: [String]?
    let params: [String: AnyCodable]?
}

struct OllamaResponse: Codable {
    let text: String?
    let model: String?
    let latency_ms: Int?
    let tokens_est: Int?
    let fallback_used: Bool?
    let error: String?
}

struct TaskConfig: Codable {
    let primaryModel: String
    let fallbacks: [String]?
    let preset: [String: AnyCodable]
    let preprocess: [String: Bool]
    let limits: [String: Int]
}

class OllamaClient {
    let modelRegistryPath: String
    let resourceProfilePath: String

    init(modelRegistryPath: String = "model_registry.json", resourceProfilePath: String = "resource_profile.json") {
        self.modelRegistryPath = modelRegistryPath
        self.resourceProfilePath = resourceProfilePath
    }

    func loadJSON<T: Decodable>(from path: String) -> T? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func run(request: OllamaRequest) -> OllamaResponse {
        guard let registry: [String: TaskConfig] = loadJSON(from: modelRegistryPath),
              let taskConfig = registry[request.task] else {
            return OllamaResponse(text: nil, model: nil, latency_ms: nil, tokens_est: nil, fallback_used: nil, error: "Task not found")
        }

        let models = [taskConfig.primaryModel] + (taskConfig.fallbacks ?? [])
        let startTime = Date()

        for (index, model) in models.enumerated() {
            if let output = callOllama(model: model, prompt: request.prompt, system: request.system, preset: taskConfig.preset) {
                let latency = Int(Date().timeIntervalSince(startTime) * 1000)
                let tokensEst = estimateTokens(prompt: request.prompt, output: output)
                return OllamaResponse(text: output, model: model, latency_ms: latency, tokens_est: tokensEst, fallback_used: index > 0, error: nil)
            }
        }

        return OllamaResponse(text: nil, model: nil, latency_ms: nil, tokens_est: nil, fallback_used: true, error: "All models failed")
    }

    private func callOllama(model: String, prompt: String, system: String?, preset: [String: AnyCodable]) -> String? {
        var fullPrompt = prompt
        if let system = system {
            fullPrompt = "\(system)\n\n\(prompt)"
        }

        // Simplified: Use Process to call ollama (assumes no images for Swift)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ollama")  // Adjust path
        process.arguments = ["run", model, "--format", "json"] + preset.flatMap { ["--\($0.key)", "\($0.value)"] }
        process.standardInput = Pipe()
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            if let inputPipe = process.standardInput as? Pipe {
                try inputPipe.fileHandleForWriting.write(Data(fullPrompt.utf8))
                try inputPipe.fileHandleForWriting.close()
            }
            process.waitUntilExit()
            if process.terminationStatus == 0, let outputPipe = process.standardOutput as? Pipe {
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            return nil
        }
        return nil
    }

    private func estimateTokens(prompt: String, output: String) -> Int {
        // Rough: 4 chars per token
        return (prompt.count + output.count) / 4
    }
}

// Usage example (for testing)
let client = OllamaClient()
let request = OllamaRequest(task: "codeGen", prompt: "Write a hello world function", system: nil, files: nil, images: nil, params: nil)
let response = client.run(request: request)
print(JSONEncoder().encode(response))