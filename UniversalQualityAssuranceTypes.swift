//
//  UniversalQualityAssuranceTypes.swift
//  Quantum-workspace
//
//  Created for Phase 7E Universal Automation
//  Comprehensive type definitions for Universal Quality Assurance System
//

import Foundation

// MARK: - Core Type Definitions

/// Quality pattern for analysis
struct QualityPattern: Codable, Sendable {
    let id: String
    let name: String
    let type: PatternType
    let description: String
    let indicators: [String]
    let confidence: Double
    let impact: Double

    enum PatternType: String, Codable {
        case positive, negative, neutral, emerging
    }
}

/// Quality state for superposition analysis
struct QualityState: Codable, Sendable {
    let id: String
    let name: String
    let quality: Double
    let probability: Double
    let characteristics: [String]
    let transitions: [String: Double]
}

/// Quality entanglement analysis
struct QualityEntanglementAnalysis: Codable, Sendable {
    let components: [String]
    let entanglementMatrix: [[Double]]
    let qualityPropagationPaths: [PropagationPath]
    let criticalEntanglementPoints: [String]

    struct PropagationPath: Codable, Sendable {
        let source: String
        let target: String
        let strength: Double
        let qualityImpact: Double
        let path: [String]
    }
}

/// Quality superposition measurement
struct QualitySuperpositionMeasurement: Codable, Sendable {
    let states: [QualityState]
    let interferencePatterns: [InterferencePattern]
    let coherenceMeasure: Double
    let decoherenceRate: Double
    let stabilityIndex: Double

    struct InterferencePattern: Codable, Sendable {
        let frequency: Double
        let amplitude: Double
        let phase: Double
        let qualityImpact: Double
    }
}

/// Quality interference detection
struct QualityInterferenceDetection: Codable, Sendable {
    let detectedInterferences: [DetectedInterference]
    let interferenceLevel: Double
    let sources: [InterferenceSource]
    let mitigationStrategies: [MitigationStrategy]
    let residualInterference: Double

    struct DetectedInterference: Codable, Sendable {
        let id: String
        let type: InterferenceType
        let location: String
        let intensity: Double
        let frequency: Double
        let duration: TimeInterval

        enum InterferenceType: String, Codable {
            case external, internal, cross_component, temporal
        }
    }

    struct InterferenceSource: Codable, Sendable {
        let component: String
        let factor: String
        let contribution: Double
        let correlation: Double
    }

    struct MitigationStrategy: Codable, Sendable {
        let strategy: String
        let effectiveness: Double
        let cost: Double
        let implementation: String
    }
}

/// Quality prediction model
struct QualityPredictionModel: Codable, Sendable {
    let modelId: String
    let algorithm: PredictionAlgorithm
    let features: [String]
    let accuracy: Double
    let confidence: Double
    let predictionHorizon: TimeInterval
    let lastTrained: Date

    enum PredictionAlgorithm: String, Codable {
        case linear_regression, neural_network, random_forest, quantum_ml
    }
}

/// Quality trend analysis
struct QualityTrendAnalysis: Codable, Sendable {
    let trends: [MetricTrend]
    let seasonality: SeasonalityAnalysis
    let anomalies: [Anomaly]
    let predictions: [TrendPrediction]
    let confidence: Double

    struct MetricTrend: Codable, Sendable {
        let metric: String
        let direction: TrendDirection
        let slope: Double
        let rSquared: Double
        let dataPoints: Int

        enum TrendDirection: String, Codable {
            case increasing, decreasing, stable, volatile
        }
    }

    struct SeasonalityAnalysis: Codable, Sendable {
        let detected: Bool
        let period: TimeInterval?
        let strength: Double
        let components: [SeasonalComponent]

        struct SeasonalComponent: Codable, Sendable {
            let frequency: Double
            let amplitude: Double
            let phase: Double
        }
    }

    struct Anomaly: Codable, Sendable {
        let timestamp: Date
        let metric: String
        let value: Double
        let expectedValue: Double
        let deviation: Double
        let severity: AnomalySeverity

        enum AnomalySeverity: String, Codable {
            case low, medium, high, critical
        }
    }

    struct TrendPrediction: Codable, Sendable {
        let metric: String
        let predictedValue: Double
        let confidence: Double
        let timeframe: TimeInterval
        let factors: [PredictionFactor]

        struct PredictionFactor: Codable, Sendable {
            let factor: String
            let weight: Double
            let contribution: Double
        }
    }
}

/// Quality gate improvement suggestion
struct QualityGateImprovementSuggestion: Codable, Sendable {
    let gateId: String
    let currentThreshold: Double
    let suggestedThreshold: Double
    let improvementType: ImprovementType
    let rationale: String
    let expectedImpact: ExpectedImpact
    let riskAssessment: RiskAssessment

    enum ImprovementType: String, Codable {
        case tighten, loosen, add_condition, remove_condition, adjust_weight
    }

    struct ExpectedImpact: Codable, Sendable {
        let qualityImprovement: Double
        let falsePositiveChange: Double
        let falseNegativeChange: Double
        let developmentOverhead: Double
    }

    struct RiskAssessment: Codable, Sendable {
        let regressionRisk: Double
        let stabilityRisk: Double
        let teamImpact: Double
        let mitigationStrategies: [String]
    }
}

/// Quality gate evolution strategy
struct QualityGateEvolutionStrategy: Codable, Sendable {
    let strategyId: String
    let name: String
    let description: String
    let evolutionSteps: [EvolutionStep]
    let successCriteria: [SuccessCriterion]
    let rollbackPlan: RollbackPlan
    let monitoringPlan: MonitoringPlan

    struct EvolutionStep: Codable, Sendable {
        let step: Int
        let description: String
        let changes: [GateChange]
        let validation: StepValidation
        let duration: TimeInterval

        struct GateChange: Codable, Sendable {
            let gateId: String
            let changeType: ChangeType
            let oldValue: Double?
            let newValue: Double?

            enum ChangeType: String, Codable {
                case threshold, weight, condition, removal
            }
        }

        struct StepValidation: Codable, Sendable {
            let tests: [String]
            let metrics: [String]
            let successThreshold: Double
        }
    }

    struct SuccessCriterion: Codable, Sendable {
        let metric: String
        let `operator`: ComparisonOperator
        let value: Double
        let timeframe: TimeInterval

        enum ComparisonOperator: String, Codable {
            case greater_than, less_than, equal_to, not_equal_to
        }
    }

    struct RollbackPlan: Codable, Sendable {
        let automatic: Bool
        let triggerConditions: [String]
        let rollbackSteps: [String]
        let recoveryTime: TimeInterval
    }

    struct MonitoringPlan: Codable, Sendable {
        let metrics: [String]
        let alerts: [Alert]
        let reporting: [Report]

        struct Alert: Codable, Sendable {
            let condition: String
            let severity: String
            let channels: [String]
        }

        struct Report: Codable, Sendable {
            let frequency: String
            let recipients: [String]
            let format: String
        }
    }
}

/// Quality constraint analysis
struct QualityConstraintAnalysis: Codable, Sendable {
    let constraints: [QualityConstraint]
    let constraintMatrix: [[Double]]
    let feasibleRegion: FeasibleRegion
    let optimizationSuggestions: [OptimizationSuggestion]

    struct QualityConstraint: Codable, Sendable {
        let id: String
        let type: ConstraintType
        let description: String
        let boundary: Boundary
        let priority: Int

        enum ConstraintType: String, Codable {
            case business, technical, resource, time, risk
        }

        struct Boundary: Codable, Sendable {
            let min: Double?
            let max: Double?
            let target: Double?
        }
    }

    struct FeasibleRegion: Codable, Sendable {
        let vertices: [[Double]]
        let volume: Double
        let center: [Double]
        let boundaries: [String]
    }

    struct OptimizationSuggestion: Codable, Sendable {
        let suggestion: String
        let impact: Double
        let feasibility: Double
        let tradeoffs: [String]
    }
}

/// Quality validation result
struct QualityValidationResult: Codable, Sendable {
    let validationId: String
    let timestamp: Date
    let component: String
    let validationType: ValidationType
    let status: ValidationStatus
    let score: Double
    let details: ValidationDetails
    let recommendations: [String]

    enum ValidationType: String, Codable {
        case code_quality, test_quality, performance, security, compliance
    }

    enum ValidationStatus: String, Codable {
        case passed, failed, warning, error
    }

    struct ValidationDetails: Codable, Sendable {
        let checks: [ValidationCheck]
        let metrics: [String: Double]
        let issues: [ValidationIssue]
        let evidence: [String]

        struct ValidationCheck: Codable, Sendable {
            let name: String
            let status: ValidationStatus
            let value: Double
            let threshold: Double
        }

        struct ValidationIssue: Codable, Sendable {
            let severity: String
            let description: String
            let location: String
            let suggestion: String
        }
    }
}

/// Quality improvement implementation
struct QualityImprovementImplementation: Codable, Sendable {
    let implementationId: String
    let improvement: QualityImprovement
    let status: ImplementationStatus
    let progress: Double
    let startTime: Date
    let estimatedCompletion: Date
    let actualCompletion: Date?
    let results: ImplementationResults
    let issues: [ImplementationIssue]

    enum ImplementationStatus: String, Codable {
        case pending, in_progress, completed, failed, cancelled
    }

    struct ImplementationResults: Codable, Sendable {
        let success: Bool
        let qualityImpact: Double
        let timeSpent: TimeInterval
        let resourcesUsed: [String: Double]
        let sideEffects: [String]
    }

    struct ImplementationIssue: Codable, Sendable {
        let issue: String
        let severity: String
        let impact: String
        let resolution: String
    }
}

/// Quality automation workflow
struct QualityAutomationWorkflow: Codable, Sendable {
    let workflowId: String
    let name: String
    let description: String
    let triggers: [WorkflowTrigger]
    let steps: [WorkflowStep]
    let conditions: [WorkflowCondition]
    let errorHandling: ErrorHandling
    let monitoring: WorkflowMonitoring

    struct WorkflowTrigger: Codable, Sendable {
        let type: TriggerType
        let condition: String
        let frequency: String?

        enum TriggerType: String, Codable {
            case manual, scheduled, event, metric_threshold
        }
    }

    struct WorkflowStep: Codable, Sendable {
        let stepId: String
        let name: String
        let type: StepType
        let configuration: [String: String]
        let timeout: TimeInterval
        let retryPolicy: RetryPolicy

        enum StepType: String, Codable {
            case assessment, validation, improvement, reporting, notification
        }

        struct RetryPolicy: Codable, Sendable {
            let maxAttempts: Int
            let backoffStrategy: BackoffStrategy
            let backoffMultiplier: Double

            enum BackoffStrategy: String, Codable {
                case linear, exponential, fixed
            }
        }
    }

    struct WorkflowCondition: Codable, Sendable {
        let condition: String
        let action: String
        let priority: Int
    }

    struct ErrorHandling: Codable, Sendable {
        let onError: [String]
        let onTimeout: [String]
        let onFailure: [String]
        let recoveryStrategies: [String]
    }

    struct WorkflowMonitoring: Codable, Sendable {
        let metrics: [String]
        let alerts: [String]
        let logging: LoggingConfiguration

        struct LoggingConfiguration: Codable, Sendable {
            let level: String
            let format: String
            let destinations: [String]
        }
    }
}

/// Quality orchestration plan
struct QualityOrchestrationPlan: Codable, Sendable {
    let planId: String
    let projectId: String
    let environment: String
    let phases: [OrchestrationPhase]
    let dependencies: [String: [String]]
    let resources: ResourceRequirements
    let timeline: Timeline
    let riskMitigation: RiskMitigation

    struct OrchestrationPhase: Codable, Sendable {
        let phaseId: String
        let name: String
        let type: PhaseType
        let duration: TimeInterval
        let components: [String]
        let deliverables: [String]
        let qualityGates: [String]

        enum PhaseType: String, Codable {
            case planning, assessment, improvement, validation, deployment
        }
    }

    struct ResourceRequirements: Codable, Sendable {
        let team: [String]
        let tools: [String]
        let infrastructure: [String]
        let budget: Double
    }

    struct Timeline: Codable, Sendable {
        let startDate: Date
        let endDate: Date
        let milestones: [Milestone]
        let criticalPath: [String]

        struct Milestone: Codable, Sendable {
            let name: String
            let date: Date
            let deliverables: [String]
            let dependencies: [String]
        }
    }

    struct RiskMitigation: Codable, Sendable {
        let risks: [IdentifiedRisk]
        let mitigationStrategies: [String]
        let contingencyPlans: [String]

        struct IdentifiedRisk: Codable, Sendable {
            let risk: String
            let probability: Double
            let impact: Double
            let mitigation: String
        }
    }
}

/// Quality coordination result
struct QualityCoordinationResult: Codable, Sendable {
    let coordinationId: String
    let timestamp: Date
    let component: String
    let gate: String
    let status: CoordinationStatus
    let duration: TimeInterval
    let issues: [CoordinationIssue]
    let metrics: [String: Double]

    enum CoordinationStatus: String, Codable {
        case success, partial_success, failed, blocked
    }

    struct CoordinationIssue: Codable, Sendable {
        let issue: String
        let severity: String
        let impact: String
        let resolution: String
    }
}

/// Quality synchronization status
struct QualitySynchronizationStatus: Codable, Sendable {
    let synchronizationId: String
    let timestamp: Date
    let components: [ComponentStatus]
    let overallStatus: SynchronizationStatus
    let consistency: Double
    let conflicts: [SynchronizationConflict]

    struct ComponentStatus: Codable, Sendable {
        let component: String
        let status: SynchronizationStatus
        let lastSync: Date
        let version: String
    }

    enum SynchronizationStatus: String, Codable {
        case synchronized, pending, failed, conflict
    }

    struct SynchronizationConflict: Codable, Sendable {
        let component1: String
        let component2: String
        let conflictType: String
        let resolution: String
    }
}

/// Quality enforcement action
struct QualityEnforcementAction: Codable, Sendable {
    let actionId: String
    let timestamp: Date
    let type: ActionType
    let target: String
    let reason: String
    let impact: Double
    let status: ActionStatus

    enum ActionType: String, Codable {
        case block, warn, approve, escalate
    }

    enum ActionStatus: String, Codable {
        case pending, executed, failed, cancelled
    }
}

/// Quality monitoring alert
struct QualityMonitoringAlert: Codable, Sendable {
    let alertId: String
    let timestamp: Date
    let severity: AlertSeverity
    let component: String
    let metric: String
    let value: Double
    let threshold: Double
    let message: String
    let recommendations: [String]
    let acknowledged: Bool

    enum AlertSeverity: String, Codable {
        case info, warning, error, critical
    }
}

/// Quality evolution tracking
struct QualityEvolutionTracking: Codable, Sendable {
    let trackingId: String
    let startDate: Date
    let currentDate: Date
    let evolutionMetrics: [EvolutionMetric]
    let milestones: [EvolutionMilestone]
    let predictions: [EvolutionPrediction]
    let interventions: [EvolutionIntervention]

    struct EvolutionMetric: Codable, Sendable {
        let metric: String
        let baseline: Double
        let current: Double
        let target: Double
        let trend: TrendDirection

        enum TrendDirection: String, Codable {
            case improving, stable, declining
        }
    }

    struct EvolutionMilestone: Codable, Sendable {
        let milestone: String
        let date: Date
        let achieved: Bool
        let metrics: [String: Double]
    }

    struct EvolutionPrediction: Codable, Sendable {
        let timeframe: TimeInterval
        let predictedMetrics: [String: Double]
        let confidence: Double
        let assumptions: [String]
    }

    struct EvolutionIntervention: Codable, Sendable {
        let intervention: String
        let date: Date
        let type: InterventionType
        let impact: Double
        let outcome: String

        enum InterventionType: String, Codable {
            case automation, process_change, tool_upgrade, training
        }
    }
}

/// Quality assurance dashboard
struct QualityAssuranceDashboard: Codable, Sendable {
    let dashboardId: String
    let name: String
    let description: String
    let widgets: [DashboardWidget]
    let filters: [DashboardFilter]
    let refreshRate: TimeInterval
    let permissions: [String]

    struct DashboardWidget: Codable, Sendable {
        let widgetId: String
        let type: WidgetType
        let title: String
        let configuration: [String: String]
        let position: WidgetPosition

        enum WidgetType: String, Codable {
            case metric_chart, quality_score, trend_graph, alert_list, action_items
        }

        struct WidgetPosition: Codable, Sendable {
            let x: Int
            let y: Int
            let width: Int
            let height: Int
        }
    }

    struct DashboardFilter: Codable, Sendable {
        let filterId: String
        let name: String
        let type: FilterType
        let options: [String]
        let defaultValue: String

        enum FilterType: String, Codable {
            case project, environment, time_range, component, severity
        }
    }
}

/// Quality assurance configuration
struct QualityAssuranceConfiguration: Codable, Sendable {
    let configurationId: String
    let version: String
    let environments: [EnvironmentConfiguration]
    let standards: QualityStandardsConfiguration
    let automation: AutomationConfiguration
    let integrations: IntegrationConfiguration
    let notifications: NotificationConfiguration

    struct EnvironmentConfiguration: Codable, Sendable {
        let environment: String
        let qualityGates: [String]
        let thresholds: [String: Double]
        let tools: [String]
        let schedules: [Schedule]

        struct Schedule: Codable, Sendable {
            let name: String
            let frequency: String
            let time: String
        }
    }

    struct QualityStandardsConfiguration: Codable, Sendable {
        let codeQuality: CodeQualityConfiguration
        let testing: TestingConfiguration
        let performance: PerformanceConfiguration
        let security: SecurityConfiguration
        let compliance: ComplianceConfiguration

        struct CodeQualityConfiguration: Codable, Sendable {
            let complexityLimits: [String: Double]
            let coverageRequirements: [String: Double]
            let styleRules: [String]
        }

        struct TestingConfiguration: Codable, Sendable {
            let coverageTargets: [String: Double]
            let testTypes: [String]
            let executionLimits: [String: Double]
        }

        struct PerformanceConfiguration: Codable, Sendable {
            let responseTimeLimits: [String: Double]
            let resourceLimits: [String: Double]
            let scalabilityRequirements: [String: Double]
        }

        struct SecurityConfiguration: Codable, Sendable {
            let vulnerabilityThresholds: [String: Double]
            let complianceRequirements: [String]
            let scanningFrequency: String
        }

        struct ComplianceConfiguration: Codable, Sendable {
            let standards: [String]
            let auditRequirements: [String]
            let documentationStandards: [String]
        }
    }

    struct AutomationConfiguration: Codable, Sendable {
        let enabled: Bool
        let workflows: [String]
        let triggers: [String]
        let errorHandling: ErrorHandlingConfiguration

        struct ErrorHandlingConfiguration: Codable, Sendable {
            let retryPolicy: RetryPolicy
            let escalationRules: [String]
            let recoveryStrategies: [String]

            struct RetryPolicy: Codable, Sendable {
                let maxRetries: Int
                let backoffStrategy: String
                let timeout: TimeInterval
            }
        }
    }

    struct IntegrationConfiguration: Codable, Sendable {
        let ciCdSystems: [String]
        let monitoringSystems: [String]
        let ticketingSystems: [String]
        let notificationChannels: [String]
        let apiEndpoints: [String: String]
    }

    struct NotificationConfiguration: Codable, Sendable {
        let channels: [NotificationChannel]
        let templates: [NotificationTemplate]
        let schedules: [NotificationSchedule]

        struct NotificationChannel: Codable, Sendable {
            let name: String
            let type: String
            let configuration: [String: String]
        }

        struct NotificationTemplate: Codable, Sendable {
            let name: String
            let type: String
            let content: String
            let variables: [String]
        }

        struct NotificationSchedule: Codable, Sendable {
            let name: String
            let frequency: String
            let conditions: [String]
        }
    }
}

/// Quality assurance metrics collection
struct QualityAssuranceMetricsCollection: Codable, Sendable {
    let collectionId: String
    let timestamp: Date
    let projectId: String
    let environment: String
    let metrics: [CollectedMetric]
    let aggregations: [MetricAggregation]
    let anomalies: [MetricAnomaly]

    struct CollectedMetric: Codable, Sendable {
        let name: String
        let value: Double
        let unit: String
        let timestamp: Date
        let source: String
        let confidence: Double
    }

    struct MetricAggregation: Codable, Sendable {
        let name: String
        let type: AggregationType
        let value: Double
        let period: TimeInterval
        let dataPoints: Int

        enum AggregationType: String, Codable {
            case average, median, min, max, percentile, trend
        }
    }

    struct MetricAnomaly: Codable, Sendable {
        let metric: String
        let value: Double
        let expectedValue: Double
        let deviation: Double
        let severity: String
        let explanation: String
    }
}

/// Quality assurance audit trail
struct QualityAssuranceAuditTrail: Codable, Sendable {
    let auditId: String
    let startDate: Date
    let endDate: Date
    let events: [AuditEvent]
    let summary: AuditSummary
    let compliance: AuditCompliance

    struct AuditEvent: Codable, Sendable {
        let eventId: String
        let timestamp: Date
        let type: EventType
        let actor: String
        let action: String
        let target: String
        let details: [String: String]
        let result: EventResult

        enum EventType: String, Codable {
            case assessment, validation, improvement, configuration_change, alert
        }

        enum EventResult: String, Codable {
            case success, failure, warning, info
        }
    }

    struct AuditSummary: Codable, Sendable {
        let totalEvents: Int
        let eventsByType: [String: Int]
        let eventsByResult: [String: Int]
        let topActors: [String]
        let timeDistribution: [String: TimeInterval]
    }

    struct AuditCompliance: Codable, Sendable {
        let standard: String
        let requirements: [ComplianceRequirement]
        let violations: [ComplianceViolation]
        let remediation: [String]

        struct ComplianceRequirement: Codable, Sendable {
            let requirement: String
            let status: ComplianceStatus
            let evidence: [String]

            enum ComplianceStatus: String, Codable {
                case compliant, non_compliant, not_applicable
            }
        }

        struct ComplianceViolation: Codable, Sendable {
            let violation: String
            let severity: String
            let description: String
            let remediation: String
        }
    }
}

// MARK: - Protocol Extensions

extension UniversalQualityAssurance {
    /// Default implementation for quantum quality metrics
    var quantumMetrics: QuantumQualityMetrics {
        QuantumQualityMetricsImpl()
    }

    /// Default implementation for gate evolution
    var gateEvolution: AutonomousQualityGateEvolution {
        AutonomousQualityGateEvolutionImpl()
    }

    /// Default implementation for quality validation
    var qualityValidation: ComprehensiveQualityValidation {
        ComprehensiveQualityValidationImpl()
    }

    /// Default implementation for improvement automation
    var improvementAutomation: QualityImprovementAutomation {
        QualityImprovementAutomationImpl()
    }

    /// Default implementation for quality orchestration
    var qualityOrchestration: QualityAssuranceOrchestration {
        QualityAssuranceOrchestrationImpl()
    }
}

// MARK: - Utility Extensions

extension QualityAssessment {
    /// Calculate quantum-enhanced quality score
    func quantumEnhancedScore() -> Double {
        guard let quantum = quantumAssessment else { return overallScore }
        return (overallScore + quantum.quantumQualityScore) / 2.0
    }

    /// Get critical issues
    func criticalIssues() -> [QualityIssue] {
        issues.filter { $0.severity == .critical }
    }

    /// Get issues by category
    func issuesByCategory() -> [String: [QualityIssue]] {
        Dictionary(grouping: issues) { $0.category.rawValue }
    }
}

extension QualityMetrics {
    /// Calculate weighted quality score
    func weightedScore(weights: [String: Double] = [:]) -> Double {
        let defaultWeights = [
            "code": 0.25,
            "test": 0.20,
            "performance": 0.20,
            "security": 0.20,
            "compliance": 0.15,
        ]

        let actualWeights = weights.isEmpty ? defaultWeights : weights

        let scores = [
            codeQuality.coverage,
            testQuality.unitTestCoverage,
            performanceQuality.scalability,
            securityQuality.complianceScore,
            complianceQuality.standardCompliance,
        ]

        return zip(actualWeights.values, scores).map(*).reduce(0, +)
    }

    /// Get metrics summary
    func summary() -> [String: Double] {
        [
            "code_coverage": codeQuality.coverage,
            "test_coverage": testQuality.unitTestCoverage,
            "performance_score": performanceQuality.scalability,
            "security_score": securityQuality.complianceScore,
            "compliance_score": complianceQuality.standardCompliance,
        ]
    }
}

extension QualityGates {
    /// Validate gate configuration
    func validateConfiguration() throws {
        guard !gates.isEmpty else {
            throw QualityAssuranceError.invalidConfiguration("No quality gates defined")
        }

        for gate in gates {
            guard gate.weight > 0 && gate.weight <= 1.0 else {
                throw QualityAssuranceError.invalidConfiguration("Invalid gate weight: \(gate.weight)")
            }
        }

        let totalWeight = gates.map(\.weight).reduce(0, +)
        guard abs(totalWeight - 1.0) < 0.01 else {
            throw QualityAssuranceError.invalidConfiguration("Gate weights must sum to 1.0, got \(totalWeight)")
        }
    }

    /// Get gate by name
    func gate(named name: String) -> QualityGate? {
        gates.first { $0.name == name }
    }
}

extension QualityHistory {
    /// Calculate trend for metric
    func trend(for metric: String) -> QualityTrends.MetricTrend? {
        trends.metricTrends[metric]
    }

    /// Get recent assessments
    func recentAssessments(limit: Int = 10) -> [HistoricalAssessment] {
        Array(assessments.suffix(limit))
    }

    /// Calculate average score over period
    func averageScore(over days: Int) -> Double {
        let cutoff = Date().addingTimeInterval(-Double(days * 24 * 3600))
        let recentAssessments = assessments.filter { $0.timestamp >= cutoff }
        return recentAssessments.map(\.score).reduce(0, +) / Double(recentAssessments.count)
    }
}

// MARK: - Error Types

enum QualityAssuranceError: Error, LocalizedError {
    case invalidConfiguration(String)
    case assessmentFailed(String)
    case validationFailed(String)
    case improvementFailed(String)
    case evolutionFailed(String)
    case synchronizationFailed(String)

    var errorDescription: String? {
        switch self {
        case let .invalidConfiguration(message):
            return "Invalid configuration: \(message)"
        case let .assessmentFailed(message):
            return "Assessment failed: \(message)"
        case let .validationFailed(message):
            return "Validation failed: \(message)"
        case let .improvementFailed(message):
            return "Improvement failed: \(message)"
        case let .evolutionFailed(message):
            return "Evolution failed: \(message)"
        case let .synchronizationFailed(message):
            return "Synchronization failed: \(message)"
        }
    }
}

// MARK: - Logging Extensions

extension UniversalQualityAssurance {
    func log_info(_ message: String) {
        print("ℹ️ [Quality Assurance] \(message)")
    }

    func log_success(_ message: String) {
        print("✅ [Quality Assurance] \(message)")
    }

    func log_warning(_ message: String) {
        print("⚠️ [Quality Assurance] \(message)")
    }

    func log_error(_ message: String) {
        print("❌ [Quality Assurance] \(message)")
    }
}

// MARK: - Mock Data Extensions

extension QualityPattern {
    static var mock: [QualityPattern] {
        [
            QualityPattern(
                id: "pattern_1",
                name: "High Complexity Pattern",
                type: .negative,
                description: "Files with high cyclomatic complexity",
                indicators: ["complexity > 10", "lines > 100"],
                confidence: 0.85,
                impact: -0.3
            ),
            QualityPattern(
                id: "pattern_2",
                name: "Good Test Coverage",
                type: .positive,
                description: "Components with comprehensive test coverage",
                indicators: ["test_coverage > 0.8", "test_types > 2"],
                confidence: 0.92,
                impact: 0.25
            ),
        ]
    }
}

extension QualityEntanglementAnalysis {
    static var mock: QualityEntanglementAnalysis {
        QualityEntanglementAnalysis(
            components: ["UI", "Business Logic", "Data Access"],
            entanglementMatrix: [
                [1.0, 0.8, 0.6],
                [0.8, 1.0, 0.7],
                [0.6, 0.7, 1.0],
            ],
            qualityPropagationPaths: [
                PropagationPath(
                    source: "UI",
                    target: "Business Logic",
                    strength: 0.8,
                    qualityImpact: 0.15,
                    path: ["UI", "Business Logic"]
                ),
            ],
            criticalEntanglementPoints: ["Business Logic"]
        )
    }
}

extension QualitySuperpositionMeasurement {
    static var mock: QualitySuperpositionMeasurement {
        QualitySuperpositionMeasurement(
            states: [
                QualityState(
                    id: "state_1",
                    name: "High Quality",
                    quality: 0.9,
                    probability: 0.6,
                    characteristics: ["good_coverage", "low_complexity"],
                    transitions: ["state_2": 0.3, "state_3": 0.1]
                ),
                QualityState(
                    id: "state_2",
                    name: "Medium Quality",
                    quality: 0.7,
                    probability: 0.3,
                    characteristics: ["average_coverage", "medium_complexity"],
                    transitions: ["state_1": 0.2, "state_3": 0.1]
                ),
            ],
            interferencePatterns: [
                InterferencePattern(
                    frequency: 0.1,
                    amplitude: 0.05,
                    phase: 0.0,
                    qualityImpact: -0.02
                ),
            ],
            coherenceMeasure: 0.85,
            decoherenceRate: 0.02,
            stabilityIndex: 0.88
        )
    }
}

extension QualityInterferenceDetection {
    static var mock: QualityInterferenceDetection {
        QualityInterferenceDetection(
            detectedInterferences: [
                DetectedInterference(
                    id: "interference_1",
                    type: .cross_component,
                    location: "UI-Business Logic",
                    intensity: 0.15,
                    frequency: 0.05,
                    duration: 3600
                ),
            ],
            interferenceLevel: 0.08,
            sources: [
                InterferenceSource(
                    component: "UI",
                    factor: "rapid_changes",
                    contribution: 0.6,
                    correlation: 0.75
                ),
            ],
            mitigationStrategies: [
                MitigationStrategy(
                    strategy: "Implement interface contracts",
                    effectiveness: 0.8,
                    cost: 0.3,
                    implementation: "Define clear API boundaries"
                ),
            ],
            residualInterference: 0.02
        )
    }
}

extension QualityPredictionModel {
    static var mock: QualityPredictionModel {
        QualityPredictionModel(
            modelId: "quantum_predictor_v1",
            algorithm: .quantum_ml,
            features: ["code_complexity", "test_coverage", "commit_frequency"],
            accuracy: 0.87,
            confidence: 0.82,
            predictionHorizon: 30 * 24 * 3600,
            lastTrained: Date().addingTimeInterval(-7 * 24 * 3600)
        )
    }
}

extension QualityTrendAnalysis {
    static var mock: QualityTrendAnalysis {
        QualityTrendAnalysis(
            trends: [
                MetricTrend(
                    metric: "code_coverage",
                    direction: .increasing,
                    slope: 0.002,
                    rSquared: 0.85,
                    dataPoints: 50
                ),
                MetricTrend(
                    metric: "test_coverage",
                    direction: .stable,
                    slope: 0.0001,
                    rSquared: 0.92,
                    dataPoints: 50
                ),
            ],
            seasonality: SeasonalityAnalysis(
                detected: true,
                period: 7 * 24 * 3600,
                strength: 0.15,
                components: [
                    SeasonalComponent(
                        frequency: 0.142857,
                        amplitude: 0.05,
                        phase: 0.0
                    ),
                ]
            ),
            anomalies: [
                Anomaly(
                    timestamp: Date().addingTimeInterval(-2 * 24 * 3600),
                    metric: "build_time",
                    value: 1200.0,
                    expectedValue: 300.0,
                    deviation: 3.0,
                    severity: .high
                ),
            ],
            predictions: [
                TrendPrediction(
                    metric: "code_coverage",
                    predictedValue: 0.88,
                    confidence: 0.85,
                    timeframe: 30 * 24 * 3600,
                    factors: [
                        PredictionFactor(
                            factor: "team_size",
                            weight: 0.3,
                            contribution: 0.02
                        ),
                    ]
                ),
            ],
            confidence: 0.83
        )
    }
}

extension QualityGateImprovementSuggestion {
    static var mock: [QualityGateImprovementSuggestion] {
        [
            QualityGateImprovementSuggestion(
                gateId: "code_coverage",
                currentThreshold: 0.75,
                suggestedThreshold: 0.80,
                improvementType: .tighten,
                rationale: "Recent improvements in test coverage justify higher standards",
                expectedImpact: ExpectedImpact(
                    qualityImprovement: 0.05,
                    falsePositiveChange: 0.02,
                    falseNegativeChange: -0.01,
                    developmentOverhead: 0.03
                ),
                riskAssessment: RiskAssessment(
                    regressionRisk: 0.05,
                    stabilityRisk: 0.02,
                    teamImpact: 0.1,
                    mitigationStrategies: ["Gradual rollout", "Additional training"]
                )
            ),
        ]
    }
}

extension QualityGateEvolutionStrategy {
    static var mock: QualityGateEvolutionStrategy {
        QualityGateEvolutionStrategy(
            strategyId: "gradual_evolution_v1",
            name: "Gradual Quality Gate Evolution",
            description: "Incremental improvement of quality gates based on team maturity",
            evolutionSteps: [
                EvolutionStep(
                    step: 1,
                    description: "Increase code coverage threshold",
                    changes: [
                        GateChange(
                            gateId: "code_coverage",
                            changeType: .threshold,
                            oldValue: 0.75,
                            newValue: 0.78
                        ),
                    ],
                    validation: StepValidation(
                        tests: ["unit_tests", "integration_tests"],
                        metrics: ["code_coverage", "build_success_rate"],
                        successThreshold: 0.95
                    ),
                    duration: 7 * 24 * 3600
                ),
            ],
            successCriteria: [
                SuccessCriterion(
                    metric: "overall_quality_score",
                    operator: .greater_than,
                    value: 0.80,
                    timeframe: 30 * 24 * 3600
                ),
            ],
            rollbackPlan: RollbackPlan(
                automatic: true,
                triggerConditions: ["quality_score < 0.75", "build_failure_rate > 0.1"],
                rollbackSteps: ["Revert gate changes", "Notify team", "Schedule review"],
                recoveryTime: 3600
            ),
            monitoringPlan: MonitoringPlan(
                metrics: ["quality_score", "gate_compliance", "build_success_rate"],
                alerts: [
                    Alert(
                        condition: "quality_score < 0.75",
                        severity: "warning",
                        channels: ["slack", "email"]
                    ),
                ],
                reporting: [
                    Report(
                        frequency: "weekly",
                        recipients: ["team_lead", "qa_manager"],
                        format: "dashboard"
                    ),
                ]
            )
        )
    }
}

extension QualityConstraintAnalysis {
    static var mock: QualityConstraintAnalysis {
        QualityConstraintAnalysis(
            constraints: [
                QualityConstraint(
                    id: "business_uptime",
                    type: .business,
                    description: "Maintain 99.9% uptime",
                    boundary: QualityConstraint.Boundary(
                        min: 0.999,
                        max: nil,
                        target: 0.999
                    ),
                    priority: 1
                ),
                QualityConstraint(
                    id: "development_velocity",
                    type: .technical,
                    description: "Maintain development velocity",
                    boundary: QualityConstraint.Boundary(
                        min: nil,
                        max: 0.8,
                        target: 0.7
                    ),
                    priority: 2
                ),
            ],
            constraintMatrix: [
                [1.0, 0.3],
                [0.3, 1.0],
            ],
            feasibleRegion: FeasibleRegion(
                vertices: [[0.999, 0.7], [0.999, 0.8], [0.995, 0.8]],
                volume: 0.002,
                center: [0.997, 0.75],
                boundaries: ["uptime_constraint", "velocity_constraint"]
            ),
            optimizationSuggestions: [
                OptimizationSuggestion(
                    suggestion: "Implement automated testing to reduce manual testing time",
                    impact: 0.15,
                    feasibility: 0.9,
                    tradeoffs: ["Initial setup cost", "Learning curve"]
                ),
            ]
        )
    }
}

// MARK: - JSON Encoding/Decoding Helpers

extension QualityAssuranceConfiguration {
    /// Load configuration from file
    static func load(from path: String) throws -> QualityAssuranceConfiguration {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try JSONDecoder().decode(QualityAssuranceConfiguration.self, from: data)
    }

    /// Save configuration to file
    func save(to path: String) throws {
        let data = try JSONEncoder().encode(self)
        try data.write(to: URL(fileURLWithPath: path))
    }
}

extension QualityAssuranceMetricsCollection {
    /// Create from metrics dictionary
    static func create(from metrics: [String: Double], projectId: String, environment: String) -> QualityAssuranceMetricsCollection {
        let collectedMetrics = metrics.map { name, value in
            CollectedMetric(
                name: name,
                value: value,
                unit: "score",
                timestamp: Date(),
                source: "assessment",
                confidence: 0.9
            )
        }

        return QualityAssuranceMetricsCollection(
            collectionId: UUID().uuidString,
            timestamp: Date(),
            projectId: projectId,
            environment: environment,
            metrics: collectedMetrics,
            aggregations: [],
            anomalies: []
        )
    }
}

extension QualityAssuranceAuditTrail {
    /// Add event to audit trail
    mutating func addEvent(_ event: AuditEvent) {
        events.append(event)
    }

    /// Get events in date range
    func events(in range: ClosedRange<Date>) -> [AuditEvent] {
        events.filter { range.contains($0.timestamp) }
    }

    /// Generate compliance report
    func complianceReport(for standard: String) -> AuditCompliance? {
        compliance.first { $0.standard == standard }
    }
}

// MARK: - Utility Functions

/// Create quality assurance configuration from defaults
func createDefaultQualityAssuranceConfiguration() -> QualityAssuranceConfiguration {
    QualityAssuranceConfiguration(
        configurationId: "default_config_v1",
        version: "1.0",
        environments: [
            EnvironmentConfiguration(
                environment: "development",
                qualityGates: ["basic_checks"],
                thresholds: ["code_coverage": 0.7, "test_coverage": 0.6],
                tools: ["swiftlint", "xctest"],
                schedules: [
                    Schedule(name: "daily_assessment", frequency: "daily", time: "09:00"),
                ]
            ),
            EnvironmentConfiguration(
                environment: "production",
                qualityGates: ["strict_checks"],
                thresholds: ["code_coverage": 0.85, "test_coverage": 0.80],
                tools: ["swiftlint", "xctest", "sonarcloud"],
                schedules: [
                    Schedule(name: "continuous_monitoring", frequency: "hourly", time: "*"),
                ]
            ),
        ],
        standards: QualityStandardsConfiguration(
            codeQuality: QualityStandardsConfiguration.CodeQualityConfiguration(
                complexityLimits: ["cyclomatic": 10.0, "cognitive": 15.0],
                coverageRequirements: ["statement": 0.80, "branch": 0.75],
                styleRules: ["swiftlint_rules", "formatting_rules"]
            ),
            testing: QualityStandardsConfiguration.TestingConfiguration(
                coverageTargets: ["unit": 0.80, "integration": 0.70],
                testTypes: ["unit", "integration", "e2e"],
                executionLimits: ["timeout": 300.0, "max_parallel": 4.0]
            ),
            performance: QualityStandardsConfiguration.PerformanceConfiguration(
                responseTimeLimits: ["api": 200.0, "ui": 100.0],
                resourceLimits: ["memory": 0.80, "cpu": 0.75],
                scalabilityRequirements: ["concurrent_users": 1000.0]
            ),
            security: QualityStandardsConfiguration.SecurityConfiguration(
                vulnerabilityThresholds: ["critical": 0.0, "high": 1.0],
                complianceRequirements: ["owasp", "nist"],
                scanningFrequency: "daily"
            ),
            compliance: QualityStandardsConfiguration.ComplianceConfiguration(
                standards: ["pci_dss", "gdpr", "iso27001"],
                auditRequirements: ["quarterly_audit", "annual_review"],
                documentationStandards: ["api_docs", "security_docs"]
            )
        ),
        automation: QualityAssuranceConfiguration.AutomationConfiguration(
            enabled: true,
            workflows: ["assessment_workflow", "improvement_workflow"],
            triggers: ["commit", "schedule", "manual"],
            errorHandling: QualityAssuranceConfiguration.AutomationConfiguration.ErrorHandlingConfiguration(
                retryPolicy: QualityAssuranceConfiguration.AutomationConfiguration.ErrorHandlingConfiguration.RetryPolicy(
                    maxRetries: 3,
                    backoffStrategy: "exponential",
                    timeout: 3600
                ),
                escalationRules: ["notify_team_lead", "create_ticket"],
                recoveryStrategies: ["rollback_changes", "manual_intervention"]
            )
        ),
        integrations: QualityAssuranceConfiguration.IntegrationConfiguration(
            ciCdSystems: ["github_actions", "jenkins"],
            monitoringSystems: ["datadog", "prometheus"],
            ticketingSystems: ["jira", "github_issues"],
            notificationChannels: ["slack", "email"],
            apiEndpoints: [
                "github_api": "https://api.github.com",
                "slack_api": "https://slack.com/api",
            ]
        ),
        notifications: QualityAssuranceConfiguration.NotificationConfiguration(
            channels: [
                QualityAssuranceConfiguration.NotificationConfiguration.NotificationChannel(
                    name: "slack",
                    type: "slack",
                    configuration: ["webhook_url": "https://hooks.slack.com/..."]
                ),
                QualityAssuranceConfiguration.NotificationConfiguration.NotificationChannel(
                    name: "email",
                    type: "smtp",
                    configuration: ["smtp_server": "smtp.company.com"]
                ),
            ],
            templates: [
                QualityAssuranceConfiguration.NotificationConfiguration.NotificationTemplate(
                    name: "quality_alert",
                    type: "alert",
                    content: "Quality alert: {{metric}} is {{value}} (threshold: {{threshold}})",
                    variables: ["metric", "value", "threshold"]
                ),
            ],
            schedules: [
                QualityAssuranceConfiguration.NotificationConfiguration.NotificationSchedule(
                    name: "daily_summary",
                    frequency: "daily",
                    conditions: ["has_new_issues"]
                ),
            ]
        )
    )
}

/// Validate quality assurance configuration
func validateQualityAssuranceConfiguration(_ config: QualityAssuranceConfiguration) throws {
    guard !config.environments.isEmpty else {
        throw QualityAssuranceError.invalidConfiguration("At least one environment must be configured")
    }

    for environment in config.environments {
        guard !environment.qualityGates.isEmpty else {
            throw QualityAssuranceError.invalidConfiguration("Environment \(environment.environment) must have quality gates")
        }

        guard !environment.tools.isEmpty else {
            throw QualityAssuranceError.invalidConfiguration("Environment \(environment.environment) must have tools configured")
        }
    }

    // Validate automation configuration
    if config.automation.enabled {
        guard !config.automation.workflows.isEmpty else {
            throw QualityAssuranceError.invalidConfiguration("Automation enabled but no workflows configured")
        }
    }
}

/// Create quality dashboard configuration
func createQualityDashboardConfiguration() -> QualityAssuranceDashboard {
    QualityAssuranceDashboard(
        dashboardId: "universal_quality_dashboard",
        name: "Universal Quality Assurance Dashboard",
        description: "Comprehensive quality monitoring and assurance dashboard",
        widgets: [
            DashboardWidget(
                widgetId: "overall_score",
                type: .metric_chart,
                title: "Overall Quality Score",
                configuration: ["metric": "overall_score", "chart_type": "line"],
                position: DashboardWidget.WidgetPosition(x: 0, y: 0, width: 6, height: 4)
            ),
            DashboardWidget(
                widgetId: "code_quality",
                type: .quality_score,
                title: "Code Quality Metrics",
                configuration: ["metrics": "coverage,complexity,maintainability"],
                position: DashboardWidget.WidgetPosition(x: 6, y: 0, width: 6, height: 4)
            ),
            DashboardWidget(
                widgetId: "quality_trends",
                type: .trend_graph,
                title: "Quality Trends",
                configuration: ["period": "30d", "metrics": "all"],
                position: DashboardWidget.WidgetPosition(x: 0, y: 4, width: 8, height: 4)
            ),
            DashboardWidget(
                widgetId: "active_alerts",
                type: .alert_list,
                title: "Active Alerts",
                configuration: ["severity_filter": "warning,critical"],
                position: DashboardWidget.WidgetPosition(x: 8, y: 4, width: 4, height: 4)
            ),
            DashboardWidget(
                widgetId: "action_items",
                type: .action_items,
                title: "Action Items",
                configuration: ["status_filter": "open,pending"],
                position: DashboardWidget.WidgetPosition(x: 0, y: 8, width: 12, height: 4)
            ),
        ],
        filters: [
            DashboardFilter(
                filterId: "project_filter",
                name: "Project",
                type: .project,
                options: ["all_projects"],
                defaultValue: "all"
            ),
            DashboardFilter(
                filterId: "environment_filter",
                name: "Environment",
                type: .environment,
                options: ["development", "staging", "production"],
                defaultValue: "production"
            ),
            DashboardFilter(
                filterId: "time_filter",
                name: "Time Range",
                type: .time_range,
                options: ["1d", "7d", "30d", "90d"],
                defaultValue: "30d"
            ),
        ],
        refreshRate: 300.0, // 5 minutes
        permissions: ["read", "write", "admin"]
    )
}

/// Initialize quality assurance system with default configuration
func initializeQualityAssuranceSystem() -> UniversalQualityAssurance {
    let system = UniversalQualityAssurance()

    // Load or create default configuration
    do {
        let config = try QualityAssuranceConfiguration.load(from: "quality_config.json")
        system.log_info("Loaded quality assurance configuration")
    } catch {
        let defaultConfig = createDefaultQualityAssuranceConfiguration()
        do {
            try defaultConfig.save(to: "quality_config.json")
            system.log_info("Created default quality assurance configuration")
        } catch {
            system.log_warning("Could not save default configuration: \(error.localizedDescription)")
        }
    }

    return system
}
