// OllamaClient.swift: Unified Ollama adapter for Swift scripts
// Expects JSON input: { task, prompt, system?, files[], images[], params? }
// Outputs JSON: { text, model, latency_ms, tokens_est?, fallback_used?, error? }

import Foundation

// MARK: - Cloud Fallback Policy (Swift)

private struct CloudFallbackPolicy {
    let configPath: String
    let quotaTrackerPath: String
    let escalationLogPath: String

    private(set) var enabled: Bool = false
    private var config: [String: Any] = [:]
    private var quotas: [String: Any] = [:]
    private var circuitBreaker: [String: Any] = [:]

    init(configPath: String = "config/cloud_fallback_config.json",
         quotaTrackerPath: String = "metrics/quota_tracker.json",
         escalationLogPath: String = "logs/cloud_escalation_log.jsonl") {
        self.configPath = configPath
        self.quotaTrackerPath = quotaTrackerPath
        self.escalationLogPath = escalationLogPath
        self.reload()
    }

    mutating func reload() {
        guard let cfg = Self.readJSON(path: configPath) else { return }
        self.config = cfg
        self.enabled = true
        let tracker = Self.readJSON(path: quotaTrackerPath) ?? [:]
        self.quotas = (tracker["quotas"] as? [String: Any]) ?? [:]
        self.circuitBreaker = (tracker["circuit_breaker"] as? [String: Any]) ?? [:]
    }

    func allowed(priority: String) -> Bool {
        guard enabled else { return true }
        let allowed = config["allowed_priority_levels"] as? [String] ?? []
        return allowed.contains(priority)
    }

    func checkQuota(priority: String) -> Bool {
        guard enabled else { return true }
        guard let q = quotas[priority] as? [String: Any] else { return false }
        let dailyUsed = (q["daily_used"] as? Int) ?? 0
        let hourlyUsed = (q["hourly_used"] as? Int) ?? 0
        let dailyLimit = (q["daily_limit"] as? Int) ?? Int.max
        let hourlyLimit = (q["hourly_limit"] as? Int) ?? Int.max
        return dailyUsed < dailyLimit && hourlyUsed < hourlyLimit
    }

    mutating func incrementQuota(priority: String) {
        guard enabled else { return }
        var tracker = Self.readJSON(path: quotaTrackerPath) ?? [:]
        var quotasDict = (tracker["quotas"] as? [String: Any]) ?? [:]
        var pq = (quotasDict[priority] as? [String: Any]) ?? [:]
        let daily = ((pq["daily_used"] as? Int) ?? 0) + 1
        let hourly = ((pq["hourly_used"] as? Int) ?? 0) + 1
        pq["daily_used"] = daily
        pq["hourly_used"] = hourly
        quotasDict[priority] = pq
        tracker["quotas"] = quotasDict
        Self.writeJSON(path: quotaTrackerPath, object: tracker)
        // Refresh in-memory view
        self.reload()
    }

    mutating func recordFailure(priority: String) {
        guard enabled else { return }
        var tracker = Self.readJSON(path: quotaTrackerPath) ?? [:]
        var cb = (tracker["circuit_breaker"] as? [String: Any]) ?? [:]
        var pcb = (cb[priority] as? [String: Any]) ?? [
            "state": "closed", "failure_count": 0, "last_failure": NSNull(), "opened_at": NSNull()
        ]
        let now = Self.iso8601Now()
        let failures = ((pcb["failure_count"] as? Int) ?? 0) + 1
        pcb["failure_count"] = failures
        pcb["last_failure"] = now
        // Threshold
        let threshold = ((config["circuit_breaker"] as? [String: Any])?["failure_threshold"] as? Int) ?? 3
        if failures >= threshold {
            pcb["state"] = "open"
            pcb["opened_at"] = now
        }
        cb[priority] = pcb
        tracker["circuit_breaker"] = cb
        Self.writeJSON(path: quotaTrackerPath, object: tracker)
        self.reload()
    }

    mutating func checkCircuit(priority: String) -> Bool {
        guard enabled else { return true }
        guard let pcb = circuitBreaker[priority] as? [String: Any] else { return true }
        let state = (pcb["state"] as? String) ?? "closed"
        if state == "open" {
            // Check reset window
            let resetMins = ((config["circuit_breaker"] as? [String: Any])?["reset_after_minutes"] as? Int) ?? 30
            if let opened = pcb["opened_at"] as? String,
               let openedDate = Self.iso8601Parse(opened) {
                if Date().timeIntervalSince(openedDate) >= Double(resetMins * 60) {
                    // Reset breaker
                    var tracker = Self.readJSON(path: quotaTrackerPath) ?? [:]
                    var cb = (tracker["circuit_breaker"] as? [String: Any]) ?? [:]
                    var mpcb = (cb[priority] as? [String: Any]) ?? [:]
                    mpcb["state"] = "closed"
                    mpcb["failure_count"] = 0
                    mpcb["opened_at"] = NSNull()
                    cb[priority] = mpcb
                    tracker["circuit_breaker"] = cb
                    Self.writeJSON(path: quotaTrackerPath, object: tracker)
                    self.reload()
                    return true
                }
            }
            return false
        }
        return true
    }

    func logEscalation(task: String, priority: String, reason: String, modelAttempted: String, provider: String) {
        guard enabled else { return }
        let now = Self.iso8601Now()
        let remaining: Int = {
            guard let q = quotas[priority] as? [String: Any] else { return 0 }
            let dailyLimit = (q["daily_limit"] as? Int) ?? 0
            let dailyUsed = (q["daily_used"] as? Int) ?? 0
            return max(dailyLimit - dailyUsed, 0)
        }()
        let line: [String: Any] = [
            "timestamp": now,
            "task": task,
            "priority": priority,
            "reason": reason,
            "model_attempted": modelAttempted,
            "cloud_provider": provider,
            "quota_remaining": remaining
        ]
        if let data = try? JSONSerialization.data(withJSONObject: line),
           let s = String(data: data, encoding: .utf8) {
            if FileManager.default.fileExists(atPath: escalationLogPath) == false {
                FileManager.default.createFile(atPath: escalationLogPath, contents: nil)
            }
            if let h = try? FileHandle(forWritingTo: URL(fileURLWithPath: escalationLogPath)) {
                h.seekToEndOfFile()
                h.write(Data((s + "\n").utf8))
                try? h.close()
            }
        }
        // Update dashboard (best-effort)
        let dashboard = "dashboard_data.json"
        if var d = Self.readJSON(path: dashboard) {
            var ai = (d["ai_metrics"] as? [String: Any]) ?? [:]
            let current = (ai["escalation_count"] as? Int) ?? 0
            ai["escalation_count"] = current + 1
            let totalCalls = ((d["ollama_metrics"] as? [String: Any])?["total_calls"] as? Int) ?? 1
            ai["fallback_rate"] = Double((ai["escalation_count"] as? Int ?? 1)) / Double(max(totalCalls, 1))
            d["ai_metrics"] = ai
            Self.writeJSON(path: dashboard, object: d)
        }
    }

    // MARK: - Helpers

    private static func readJSON(path: String) -> [String: Any]? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func writeJSON(path: String, object: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]) {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }

    private static func iso8601Now() -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: Date())
    }

    private static func iso8601Parse(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }
}

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
    let priority: String?
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
        var policy = CloudFallbackPolicy()
        guard let registry: [String: TaskConfig] = loadJSON(from: modelRegistryPath),
              let taskConfig = registry[request.task]
        else {
            return OllamaResponse(text: nil, model: nil, latency_ms: nil, tokens_est: nil, fallback_used: nil, error: "Task not found")
        }

        let models = [taskConfig.primaryModel] + (taskConfig.fallbacks ?? [])
        let startTime = Date()
        let priority = taskConfig.priority ?? "medium"
        var localFailed = false

        for (index, model) in models.enumerated() {
            if let output = callOllama(model: model, prompt: request.prompt, system: request.system, preset: taskConfig.preset) {
                let latency = Int(Date().timeIntervalSince(startTime) * 1000)
                let tokensEst = estimateTokens(prompt: request.prompt, output: output)
                return OllamaResponse(text: output, model: model, latency_ms: latency, tokens_est: tokensEst, fallback_used: index > 0, error: nil)
            }
            // record failure for circuit breaker
            policy.recordFailure(priority: priority)
            localFailed = true
        }

        // All local models failed - consider cloud escalation (disabled by default)
        if localFailed && policy.enabled && policy.allowed(priority: priority) {
            if policy.checkQuota(priority: priority) && policy.checkCircuit(priority: priority) {
                policy.logEscalation(task: request.task, priority: priority, reason: "local_failure", modelAttempted: taskConfig.primaryModel, provider: "ollama_cloud")
                policy.incrementQuota(priority: priority)
                return OllamaResponse(text: nil, model: nil, latency_ms: nil, tokens_est: nil, fallback_used: false, error: "All local models failed; cloud escalation logged but not enabled")
            } else {
                return OllamaResponse(text: nil, model: nil, latency_ms: nil, tokens_est: nil, fallback_used: false, error: "All local models failed; cloud quota exhausted or circuit open")
            }
        }

        return OllamaResponse(text: nil, model: nil, latency_ms: nil, tokens_est: nil, fallback_used: true, error: "All models failed")
    }

    private func callOllama(model: String, prompt: String, system: String?, preset: [String: AnyCodable]) -> String? {
        var fullPrompt = prompt
        if let system {
            fullPrompt = "\(system)\n\n\(prompt)"
        }

        // Simplified: Use Process to call ollama (assumes no images for Swift)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ollama") // Adjust path
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
        (prompt.count + output.count) / 4
    }
}

// Usage example (for testing)
let client = OllamaClient()
let request = OllamaRequest(task: "codeGen", prompt: "Write a hello world function", system: nil, files: nil, images: nil, params: nil)
let response = client.run(request: request)
print(JSONEncoder().encode(response))
