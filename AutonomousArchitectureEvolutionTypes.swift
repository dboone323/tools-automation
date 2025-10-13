//
//  AutonomousArchitectureEvolutionTypes.swift
//  Quantum-workspace
//
//  Created for Phase 7E Universal Automation
//  Type definitions for Autonomous Architecture Evolution System
//

import Foundation
import Combine

// MARK: - Protocol Definitions

/// Protocol for architecture analysis capabilities
@MainActor
public protocol ArchitectureAnalyzer {
    func analyzeCodebase(at path: String) async throws -> ArchitectureAnalysis
    func identifyPatterns(in analysis: ArchitectureAnalysis) async throws -> [ArchitecturalPattern]
    func detectCodeSmells(in analysis: ArchitectureAnalysis) async throws -> [CodeSmell]
}

/// Protocol for intelligent refactoring suggestions
@MainActor
public protocol IntelligentRefactorer {
    func suggestRefactoring(for patterns: [ArchitecturalPattern], smells: [CodeSmell]) async throws -> [RefactoringSuggestion]
    func applyRefactoring(_ suggestion: RefactoringSuggestion, to codebase: String) async throws -> RefactoringResult
    func validateRefactoring(_ result: RefactoringResult) async throws -> ValidationResult
}

/// Protocol for autonomous architecture evolution
@MainActor
public protocol AutonomousArchitect {
    func evolveArchitecture(in codebase: String, with constraints: EvolutionConstraints) async throws -> ArchitectureEvolution
    func predictArchitectureFuture(for analysis: ArchitectureAnalysis, horizon: TimeInterval) async throws -> ArchitecturePrediction
    func optimizeArchitecture(_ analysis: ArchitectureAnalysis, for metrics: [OptimizationPlan.ArchitectureMetric]) async throws -> OptimizationPlan
}

// MARK: - Core Data Structures

/// Comprehensive architecture analysis result
public struct ArchitectureAnalysis: Codable, Sendable {
    public let timestamp: Date
    public let codebasePath: String
    public let files: [CodeFile]
    public let dependencies: [Dependency]
    public let complexity: ComplexityMetrics
    public let coupling: CouplingMetrics
    public let cohesion: CohesionMetrics
    public let patterns: [ArchitecturalPattern]
    public let smells: [CodeSmell]
    public let quality: QualityMetrics

    public init(timestamp: Date, codebasePath: String, files: [CodeFile], dependencies: [Dependency], complexity: ComplexityMetrics, coupling: CouplingMetrics, cohesion: CohesionMetrics, patterns: [ArchitecturalPattern], smells: [CodeSmell], quality: QualityMetrics) {
        self.timestamp = timestamp
        self.codebasePath = codebasePath
        self.files = files
        self.dependencies = dependencies
        self.complexity = complexity
        self.coupling = coupling
        self.cohesion = cohesion
        self.patterns = patterns
        self.smells = smells
        self.quality = quality
    }

    public struct CodeFile: Codable, Sendable {
        public let path: String
        public let language: String
        public let linesOfCode: Int
        public let complexity: Double
        public let dependencies: [String]
        public let interfaces: [String]
        public let classes: [String]
        public let functions: [String]

        public init(path: String, language: String, linesOfCode: Int, complexity: Double, dependencies: [String], interfaces: [String], classes: [String], functions: [String]) {
            self.path = path
            self.language = language
            self.linesOfCode = linesOfCode
            self.complexity = complexity
            self.dependencies = dependencies
            self.interfaces = interfaces
            self.classes = classes
            self.functions = functions
        }
    }

    public struct Dependency: Codable, Sendable {
        public let from: String
        public let to: String
        public let type: DependencyType
        public let strength: Double

        public init(from: String, to: String, type: DependencyType, strength: Double) {
            self.from = from
            self.to = to
            self.type = type
            self.strength = strength
        }

        public enum DependencyType: String, Codable {
            case import, inheritance, composition, protocol_conformance, function_call
        }
    }

    public struct ComplexityMetrics: Codable, Sendable {
        public let averageCyclomaticComplexity: Double
        public let maxCyclomaticComplexity: Double
        public let averageLinesPerFunction: Double
        public let maxLinesPerFunction: Double
        public let totalLinesOfCode: Int
        public let fileCount: Int

        public init(averageCyclomaticComplexity: Double, maxCyclomaticComplexity: Double, averageLinesPerFunction: Double, maxLinesPerFunction: Double, totalLinesOfCode: Int, fileCount: Int) {
            self.averageCyclomaticComplexity = averageCyclomaticComplexity
            self.maxCyclomaticComplexity = maxCyclomaticComplexity
            self.averageLinesPerFunction = averageLinesPerFunction
            self.maxLinesPerFunction = maxLinesPerFunction
            self.totalLinesOfCode = totalLinesOfCode
            self.fileCount = fileCount
        }
    }

    public struct CouplingMetrics: Codable, Sendable {
        public let afferentCoupling: Double
        public let efferentCoupling: Double
        public let instability: Double
        public let abstractness: Double
        public let distanceFromMainSequence: Double

        public init(afferentCoupling: Double, efferentCoupling: Double, instability: Double, abstractness: Double, distanceFromMainSequence: Double) {
            self.afferentCoupling = afferentCoupling
            self.efferentCoupling = efferentCoupling
            self.instability = instability
            self.abstractness = abstractness
            self.distanceFromMainSequence = distanceFromMainSequence
        }
    }

    public struct CohesionMetrics: Codable, Sendable {
        public let lackOfCohesionInMethods: Double
        public let tightClassCohesion: Double
        public let semanticCohesion: Double

        public init(lackOfCohesionInMethods: Double, tightClassCohesion: Double, semanticCohesion: Double) {
            self.lackOfCohesionInMethods = lackOfCohesionInMethods
            self.tightClassCohesion = tightClassCohesion
            self.semanticCohesion = semanticCohesion
        }
    }

    public struct QualityMetrics: Codable, Sendable {
        public let maintainabilityIndex: Double
        public let technicalDebtRatio: Double
        public let testCoverage: Double
        public let documentationCoverage: Double
        public let securityScore: Double

        public init(maintainabilityIndex: Double, technicalDebtRatio: Double, testCoverage: Double, documentationCoverage: Double, securityScore: Double) {
            self.maintainabilityIndex = maintainabilityIndex
            self.technicalDebtRatio = technicalDebtRatio
            self.testCoverage = testCoverage
            self.documentationCoverage = documentationCoverage
            self.securityScore = securityScore
        }
    }
}

/// Architectural pattern identification
public struct ArchitecturalPattern: Codable, Sendable {
    public let type: PatternType
    public let confidence: Double
    public let locations: [String]
    public let quality: PatternQuality
    public let suggestions: [String]

    public init(type: PatternType, confidence: Double, locations: [String], quality: PatternQuality, suggestions: [String]) {
        self.type = type
        self.confidence = confidence
        self.locations = locations
        self.quality = quality
        self.suggestions = suggestions
    }

    public enum PatternType: String, Codable {
        case mvvm, mvp, mvc, viper, clean_architecture, hexagonal
        case factory, singleton, observer, strategy, decorator
        case repository, service_layer, dependency_injection
        case custom
    }

    public enum PatternQuality: String, Codable {
        case excellent, good, fair, poor, anti_pattern
    }
}

/// Code smell detection
public struct CodeSmell: Codable, Sendable {
    public let type: SmellType
    public let severity: Severity
    public let location: String
    public let description: String
    public let impact: ImpactMetrics
    public let refactoringEffort: EffortLevel

    public init(type: SmellType, severity: Severity, location: String, description: String, impact: ImpactMetrics, refactoringEffort: EffortLevel) {
        self.type = type
        self.severity = severity
        self.location = location
        self.description = description
        self.impact = impact
        self.refactoringEffort = refactoringEffort
    }

    public enum SmellType: String, Codable {
        case longMethod = "long_method"
        case largeClass = "large_class"
        case featureEnvy = "feature_envy"
        case dataClump = "data_clump"
        case primitiveObsession = "primitive_obsession"
        case switchStatement = "switch_statement"
        case temporaryField = "temporary_field"
        case refusedBequest = "refused_bequest"
        case alternativeClasses = "alternative_classes"
        case divergentChange = "divergent_change"
        case shotgunSurgery = "shotgun_surgery"
        case parallelInheritance = "parallel_inheritance"
        case comments = "comments"
        case duplicateCode = "duplicate_code"
        case middleMan = "middle_man"
        case lazyClass = "lazy_class"
        case speculativeGenerality = "speculative_generality"
        case messageChains = "message_chains"
        case inappropriateIntimacy = "inappropriate_intimacy"
    }

    public enum Severity: String, Codable {
        case low, medium, high, critical
    }

    public struct ImpactMetrics: Codable, Sendable {
        public let maintainability: Double
        public let testability: Double
        public let reusability: Double
        public let performance: Double

        public init(maintainability: Double, testability: Double, reusability: Double, performance: Double) {
            self.maintainability = maintainability
            self.testability = testability
            self.reusability = reusability
            self.performance = performance
        }
    }

    public enum EffortLevel: String, Codable {
        case trivial, easy, medium, hard, very_hard
    }
}

/// Refactoring suggestion
public struct RefactoringSuggestion: Codable, Sendable {
    public let id: String
    public let type: RefactoringType
    public let description: String
    public let priority: Priority
    public let affectedFiles: [String]
    public let estimatedEffort: TimeInterval
    public let expectedBenefit: BenefitMetrics
    public let riskLevel: RiskLevel
    public let dependencies: [String]

    public init(id: String, type: RefactoringType, description: String, priority: Priority, affectedFiles: [String], estimatedEffort: TimeInterval, expectedBenefit: BenefitMetrics, riskLevel: RiskLevel, dependencies: [String]) {
        self.id = id
        self.type = type
        self.description = description
        self.priority = priority
        self.affectedFiles = affectedFiles
        self.estimatedEffort = estimatedEffort
        self.expectedBenefit = expectedBenefit
        self.riskLevel = riskLevel
        self.dependencies = dependencies
    }

    public enum RefactoringType: String, Codable {
        case extractMethod = "extract_method"
        case extractClass = "extract_class"
        case moveMethod = "move_method"
        case moveField = "move_field"
        case inlineMethod = "inline_method"
        case inlineClass = "inline_class"
        case renameMethod = "rename_method"
        case renameClass = "rename_class"
        case changeSignature = "change_signature"
        case introduceParameterObject = "introduce_parameter_object"
        case preserveWholeObject = "preserve_whole_object"
        case replaceParameterWithMethod = "replace_parameter_with_method"
        case introduceLocalExtension = "introduce_local_extension"
        case removeMiddleMan = "remove_middle_man"
        case replaceDelegationWithInheritance = "replace_delegation_with_inheritance"
        case replaceInheritanceWithDelegation = "replace_inheritance_with_delegation"
        case extractSuperclass = "extract_superclass"
        case extractSubclass = "extract_subclass"
        case extractInterface = "extract_interface"
        case collapseHierarchy = "collapse_hierarchy"
        case formTemplateMethod = "form_template_method"
        case replaceInheritanceWithComposition = "replace_inheritance_with_composition"
        case replaceConditionalWithPolymorphism = "replace_conditional_with_polymorphism"
        case introduceNullObject = "introduce_null_object"
        case replaceErrorCodeWithException = "replace_error_code_with_exception"
        case replaceExceptionWithTest = "replace_exception_with_test"
        case introduceAssertion = "introduce_assertion"
        case encapsulateField = "encapsulate_field"
        case encapsulateCollection = "encapsulate_collection"
        case replaceRecordWithDataClass = "replace_record_with_data_class"
        case replaceTypeCodeWithClass = "replace_type_code_with_class"
        case replaceTypeCodeWithSubclasses = "replace_type_code_with_subclasses"
        case replaceTypeCodeWithState = "replace_type_code_with_state"
        case replaceSubclassWithFields = "replace_subclass_with_fields"
        case introduceForeignMethod = "introduce_foreign_method"
        case removeParameter = "remove_parameter"
        case renameParameter = "rename_parameter"
        case addParameter = "add_parameter"
        case separateQueryFromModifier = "separate_query_from_modifier"
        case parameterizeMethod = "parameterize_method"
        case removeSettingMethod = "remove_setting_method"
        case hideMethod = "hide_method"
        case replaceConstructorWithFactoryMethod = "replace_constructor_with_factory_method"
        case introduceNamedParameter = "introduce_named_parameter"
        case eliminatePrimitiveObsession = "eliminate_primitive_obsession"
        case introduceDesignByContract = "introduce_design_by_contract"
    }

    public enum Priority: String, Codable {
        case low, medium, high, critical
    }

    public struct BenefitMetrics: Codable, Sendable {
        public let maintainability: Double
        public let performance: Double
        public let testability: Double
        public let reusability: Double
        public let totalBenefit: Double

        public init(maintainability: Double, performance: Double, testability: Double, reusability: Double, totalBenefit: Double) {
            self.maintainability = maintainability
            self.performance = performance
            self.testability = testability
            self.reusability = reusability
            self.totalBenefit = totalBenefit
        }
    }

    public enum RiskLevel: String, Codable {
        case very_low, low, medium, high, very_high
    }
}

/// Refactoring result
public struct RefactoringResult: Codable, Sendable {
    public let suggestionId: String
    public let success: Bool
    public let appliedChanges: [FileChange]
    public let compilationErrors: [CompilationError]
    public let testResults: TestResults
    public let performanceImpact: PerformanceImpact
    public let timestamp: Date

    public init(suggestionId: String, success: Bool, appliedChanges: [FileChange], compilationErrors: [CompilationError], testResults: TestResults, performanceImpact: PerformanceImpact, timestamp: Date) {
        self.suggestionId = suggestionId
        self.success = success
        self.appliedChanges = appliedChanges
        self.compilationErrors = compilationErrors
        self.testResults = testResults
        self.performanceImpact = performanceImpact
        self.timestamp = timestamp
    }

    public struct FileChange: Codable, Sendable {
        public let filePath: String
        public let changeType: ChangeType
        public let linesChanged: ClosedRange<Int>
        public let contentPreview: String

        public init(filePath: String, changeType: ChangeType, linesChanged: ClosedRange<Int>, contentPreview: String) {
            self.filePath = filePath
            self.changeType = changeType
            self.linesChanged = linesChanged
            self.contentPreview = contentPreview
        }

        public enum ChangeType: String, Codable {
            case modified, added, deleted, renamed
        }
    }

    public struct CompilationError: Codable, Sendable {
        public let file: String
        public let line: Int
        public let column: Int
        public let message: String
        public let severity: String

        public init(file: String, line: Int, column: Int, message: String, severity: String) {
            self.file = file
            self.line = line
            self.column = column
            self.message = message
            self.severity = severity
        }
    }

    public struct TestResults: Codable, Sendable {
        public let totalTests: Int
        public let passedTests: Int
        public let failedTests: Int
        public let skippedTests: Int
        public let executionTime: TimeInterval

        public init(totalTests: Int, passedTests: Int, failedTests: Int, skippedTests: Int, executionTime: TimeInterval) {
            self.totalTests = totalTests
            self.passedTests = passedTests
            self.failedTests = failedTests
            self.skippedTests = skippedTests
            self.executionTime = executionTime
        }
    }

    public struct PerformanceImpact: Codable, Sendable {
        public let buildTimeChange: Double
        public let memoryUsageChange: Double
        public let executionTimeChange: Double
        public let binarySizeChange: Double

        public init(buildTimeChange: Double, memoryUsageChange: Double, executionTimeChange: Double, binarySizeChange: Double) {
            self.buildTimeChange = buildTimeChange
            self.memoryUsageChange = memoryUsageChange
            self.executionTimeChange = executionTimeChange
            self.binarySizeChange = binarySizeChange
        }
    }
}

/// Validation result for refactoring
public struct ValidationResult: Codable, Sendable {
    public let refactoringId: String
    public let isValid: Bool
    public let validationErrors: [ValidationError]
    public let qualityMetrics: QualityMetrics
    public let regressionTests: RegressionTestResults

    public init(refactoringId: String, isValid: Bool, validationErrors: [ValidationError], qualityMetrics: QualityMetrics, regressionTests: RegressionTestResults) {
        self.refactoringId = refactoringId
        self.isValid = isValid
        self.validationErrors = validationErrors
        self.qualityMetrics = qualityMetrics
        self.regressionTests = regressionTests
    }

    public struct ValidationError: Codable, Sendable {
        public let type: ErrorType
        public let message: String
        public let severity: Severity

        public init(type: ErrorType, message: String, severity: Severity) {
            self.type = type
            self.message = message
            self.severity = severity
        }

        public enum ErrorType: String, Codable {
            case compilation, logic, performance, security, style
        }

        public enum Severity: String, Codable {
            case warning, error, critical
        }
    }

    public struct QualityMetrics: Codable, Sendable {
        public let maintainabilityIndex: Double
        public let cyclomaticComplexity: Double
        public let duplicationPercentage: Double
        public let testCoverage: Double

        public init(maintainabilityIndex: Double, cyclomaticComplexity: Double, duplicationPercentage: Double, testCoverage: Double) {
            self.maintainabilityIndex = maintainabilityIndex
            self.cyclomaticComplexity = cyclomaticComplexity
            self.duplicationPercentage = duplicationPercentage
            self.testCoverage = testCoverage
        }
    }

    public struct RegressionTestResults: Codable, Sendable {
        public let totalTests: Int
        public let regressionsFound: Int
        public let performanceRegressions: Int
        public let functionalRegressions: Int

        public init(totalTests: Int, regressionsFound: Int, performanceRegressions: Int, functionalRegressions: Int) {
            self.totalTests = totalTests
            self.regressionsFound = regressionsFound
            self.performanceRegressions = performanceRegressions
            self.functionalRegressions = functionalRegressions
        }
    }
}

/// Architecture evolution constraints
public struct EvolutionConstraints: Codable, Sendable {
    public let maxEffortPerIteration: TimeInterval
    public let riskTolerance: RiskTolerance
    public let qualityThresholds: QualityThresholds
    public let forbiddenPatterns: [String]
    public let requiredPatterns: [String]
    public let performanceRequirements: PerformanceRequirements

    public init(maxEffortPerIteration: TimeInterval, riskTolerance: RiskTolerance, qualityThresholds: QualityThresholds, forbiddenPatterns: [String], requiredPatterns: [String], performanceRequirements: PerformanceRequirements) {
        self.maxEffortPerIteration = maxEffortPerIteration
        self.riskTolerance = riskTolerance
        self.qualityThresholds = qualityThresholds
        self.forbiddenPatterns = forbiddenPatterns
        self.requiredPatterns = requiredPatterns
        self.performanceRequirements = performanceRequirements
    }

    public enum RiskTolerance: String, Codable {
        case very_conservative, conservative, moderate, aggressive, very_aggressive
    }

    public struct QualityThresholds: Codable, Sendable {
        public let minMaintainabilityIndex: Double
        public let maxCyclomaticComplexity: Double
        public let minTestCoverage: Double
        public let maxTechnicalDebtRatio: Double

        public init(minMaintainabilityIndex: Double, maxCyclomaticComplexity: Double, minTestCoverage: Double, maxTechnicalDebtRatio: Double) {
            self.minMaintainabilityIndex = minMaintainabilityIndex
            self.maxCyclomaticComplexity = maxCyclomaticComplexity
            self.minTestCoverage = minTestCoverage
            self.maxTechnicalDebtRatio = maxTechnicalDebtRatio
        }
    }

    public struct PerformanceRequirements: Codable, Sendable {
        public let maxBuildTime: TimeInterval
        public let maxMemoryUsage: Double
        public let minPerformanceScore: Double

        public init(maxBuildTime: TimeInterval, maxMemoryUsage: Double, minPerformanceScore: Double) {
            self.maxBuildTime = maxBuildTime
            self.maxMemoryUsage = maxMemoryUsage
            self.minPerformanceScore = minPerformanceScore
        }
    }
}

/// Architecture evolution result
public struct ArchitectureEvolution: Codable, Sendable {
    public let iterations: [EvolutionIteration]
    public let finalArchitecture: ArchitectureAnalysis
    public let totalEffort: TimeInterval
    public let qualityImprovement: QualityImprovement
    public let risksEncountered: [EvolutionRisk]
    public let recommendations: [EvolutionRecommendation]

    public init(iterations: [EvolutionIteration], finalArchitecture: ArchitectureAnalysis, totalEffort: TimeInterval, qualityImprovement: QualityImprovement, risksEncountered: [EvolutionRisk], recommendations: [EvolutionRecommendation]) {
        self.iterations = iterations
        self.finalArchitecture = finalArchitecture
        self.totalEffort = totalEffort
        self.qualityImprovement = qualityImprovement
        self.risksEncountered = risksEncountered
        self.recommendations = recommendations
    }

    public struct EvolutionIteration: Codable, Sendable {
        public let iterationNumber: Int
        public let appliedRefactorings: [RefactoringResult]
        public let architectureState: ArchitectureAnalysis
        public let effortSpent: TimeInterval
        public let qualityDelta: QualityDelta

        public init(iterationNumber: Int, appliedRefactorings: [RefactoringResult], architectureState: ArchitectureAnalysis, effortSpent: TimeInterval, qualityDelta: QualityDelta) {
            self.iterationNumber = iterationNumber
            self.appliedRefactorings = appliedRefactorings
            self.architectureState = architectureState
            self.effortSpent = effortSpent
            self.qualityDelta = qualityDelta
        }
    }

    public struct QualityDelta: Codable, Sendable {
        public let maintainabilityChange: Double
        public let complexityChange: Double
        public let testCoverageChange: Double
        public let performanceChange: Double

        public init(maintainabilityChange: Double, complexityChange: Double, testCoverageChange: Double, performanceChange: Double) {
            self.maintainabilityChange = maintainabilityChange
            self.complexityChange = complexityChange
            self.testCoverageChange = testCoverageChange
            self.performanceChange = performanceChange
        }
    }

    public struct QualityImprovement: Codable, Sendable {
        public let overallScore: Double
        public let maintainabilityGain: Double
        public let complexityReduction: Double
        public let testCoverageGain: Double
        public let performanceGain: Double

        public init(overallScore: Double, maintainabilityGain: Double, complexityReduction: Double, testCoverageGain: Double, performanceGain: Double) {
            self.overallScore = overallScore
            self.maintainabilityGain = maintainabilityGain
            self.complexityReduction = complexityReduction
            self.testCoverageGain = testCoverageGain
            self.performanceGain = performanceGain
        }
    }

    public struct EvolutionRisk: Codable, Sendable {
        public let type: RiskType
        public let severity: Severity
        public let description: String
        public let mitigationStrategy: String

        public init(type: RiskType, severity: Severity, description: String, mitigationStrategy: String) {
            self.type = type
            self.severity = severity
            self.description = description
            self.mitigationStrategy = mitigationStrategy
        }

        public enum RiskType: String, Codable {
            case compilation_failure, test_regression, performance_degradation, security_vulnerability, breaking_change
        }

        public enum Severity: String, Codable {
            case low, medium, high, critical
        }
    }

    public struct EvolutionRecommendation: Codable, Sendable {
        public let type: RecommendationType
        public let priority: Priority
        public let description: String
        public let implementationEffort: EffortLevel

        public init(type: RecommendationType, priority: Priority, description: String, implementationEffort: EffortLevel) {
            self.type = type
            self.priority = priority
            self.description = description
            self.implementationEffort = implementationEffort
        }

        public enum RecommendationType: String, Codable {
            case adopt_pattern, remove_anti_pattern, improve_testing, enhance_security, optimize_performance
        }

        public enum Priority: String, Codable {
            case low, medium, high, critical
        }

        public enum EffortLevel: String, Codable {
            case trivial, easy, medium, hard, very_hard
        }
    }
}

/// Architecture prediction
public struct ArchitecturePrediction: Codable, Sendable {
    public let predictionHorizon: TimeInterval
    public let currentArchitecture: ArchitectureAnalysis
    public let predictedEvolution: [PredictedChange]
    public let riskAssessment: RiskAssessment
    public let recommendedActions: [RecommendedAction]

    public init(predictionHorizon: TimeInterval, currentArchitecture: ArchitectureAnalysis, predictedEvolution: [PredictedChange], riskAssessment: RiskAssessment, recommendedActions: [RecommendedAction]) {
        self.predictionHorizon = predictionHorizon
        self.currentArchitecture = currentArchitecture
        self.predictedEvolution = predictedEvolution
        self.riskAssessment = riskAssessment
        self.recommendedActions = recommendedActions
    }

    public struct PredictedChange: Codable, Sendable {
        public let timeframe: TimeInterval
        public let changeType: ChangeType
        public let confidence: Double
        public let impact: ImpactMetrics

        public init(timeframe: TimeInterval, changeType: ChangeType, confidence: Double, impact: ImpactMetrics) {
            self.timeframe = timeframe
            self.changeType = changeType
            self.confidence = confidence
            self.impact = impact
        }

        public enum ChangeType: String, Codable {
            case complexity_increase, maintainability_decline, performance_degradation, security_risk, scalability_issue
        }

        public struct ImpactMetrics: Codable, Sendable {
            public let severity: Double
            public let affectedComponents: [String]
            public let mitigationCost: TimeInterval

            public init(severity: Double, affectedComponents: [String], mitigationCost: TimeInterval) {
                self.severity = severity
                self.affectedComponents = affectedComponents
                self.mitigationCost = mitigationCost
            }
        }
    }

    public struct RiskAssessment: Codable, Sendable {
        public let overallRiskLevel: RiskLevel
        public let riskFactors: [RiskFactor]
        public let mitigationStrategies: [String]

        public init(overallRiskLevel: RiskLevel, riskFactors: [RiskFactor], mitigationStrategies: [String]) {
            self.overallRiskLevel = overallRiskLevel
            self.riskFactors = riskFactors
            self.mitigationStrategies = mitigationStrategies
        }

        public enum RiskLevel: String, Codable {
            case very_low, low, medium, high, very_high
        }

        public struct RiskFactor: Codable, Sendable {
            public let factor: String
            public let probability: Double
            public let impact: Double
            public let riskScore: Double

            public init(factor: String, probability: Double, impact: Double, riskScore: Double) {
                self.factor = factor
                self.probability = probability
                self.impact = impact
                self.riskScore = riskScore
            }
        }
    }

    public struct RecommendedAction: Codable, Sendable {
        public let action: String
        public let priority: Priority
        public let timeline: TimeInterval
        public let expectedBenefit: Double
        public let implementationEffort: EffortLevel

        public init(action: String, priority: Priority, timeline: TimeInterval, expectedBenefit: Double, implementationEffort: EffortLevel) {
            self.action = action
            self.priority = priority
            self.timeline = timeline
            self.expectedBenefit = expectedBenefit
            self.implementationEffort = implementationEffort
        }

        public enum Priority: String, Codable {
            case low, medium, high, critical
        }

        public enum EffortLevel: String, Codable {
            case trivial, easy, medium, hard, very_hard
        }
    }
}

/// Architecture optimization plan
public struct OptimizationPlan: Codable, Sendable {
    public let targetMetrics: [ArchitectureMetric]
    public let optimizationSteps: [OptimizationStep]
    public let expectedOutcomes: ExpectedOutcomes
    public let implementationTimeline: [TimelinePhase]
    public let riskMitigation: [RiskMitigation]

    public init(targetMetrics: [ArchitectureMetric], optimizationSteps: [OptimizationStep], expectedOutcomes: ExpectedOutcomes, implementationTimeline: [TimelinePhase], riskMitigation: [RiskMitigation]) {
        self.targetMetrics = targetMetrics
        self.optimizationSteps = optimizationSteps
        self.expectedOutcomes = expectedOutcomes
        self.implementationTimeline = implementationTimeline
        self.riskMitigation = riskMitigation
    }

    public struct ArchitectureMetric: Codable, Sendable {
        public let name: String
        public let currentValue: Double
        public let targetValue: Double
        public let priority: Priority

        public init(name: String, currentValue: Double, targetValue: Double, priority: Priority) {
            self.name = name
            self.currentValue = currentValue
            self.targetValue = targetValue
            self.priority = priority
        }

        public enum Priority: String, Codable {
            case low, medium, high, critical
        }
    }

    public struct OptimizationStep: Codable, Sendable {
        public let stepNumber: Int
        public let description: String
        public let type: StepType
        public let affectedComponents: [String]
        public let effortEstimate: TimeInterval
        public let riskLevel: RiskLevel
        public let dependencies: [Int]

        public init(stepNumber: Int, description: String, type: StepType, affectedComponents: [String], effortEstimate: TimeInterval, riskLevel: RiskLevel, dependencies: [Int]) {
            self.stepNumber = stepNumber
            self.description = description
            self.type = stepType
            self.affectedComponents = affectedComponents
            self.effortEstimate = effortEstimate
            self.riskLevel = riskLevel
            self.dependencies = dependencies
        }

        public enum StepType: String, Codable {
            case refactoring, restructuring, optimization, testing, documentation
        }

        public enum RiskLevel: String, Codable {
            case very_low, low, medium, high, very_high
        }
    }

    public struct ExpectedOutcomes: Codable, Sendable {
        public let qualityImprovements: [QualityImprovement]
        public let performanceGains: [PerformanceGain]
        public let maintainabilityEnhancements: [MaintainabilityEnhancement]

        public init(qualityImprovements: [QualityImprovement], performanceGains: [PerformanceGain], maintainabilityEnhancements: [MaintainabilityEnhancement]) {
            self.qualityImprovements = qualityImprovements
            self.performanceGains = performanceGains
            self.maintainabilityEnhancements = maintainabilityEnhancements
        }

        public struct QualityImprovement: Codable, Sendable {
            public let metric: String
            public let expectedChange: Double
            public let confidence: Double

            public init(metric: String, expectedChange: Double, confidence: Double) {
                self.metric = metric
                self.expectedChange = expectedChange
                self.confidence = confidence
            }
        }

        public struct PerformanceGain: Codable, Sendable {
            public let aspect: String
            public let expectedImprovement: Double
            public let measurementMethod: String

            public init(aspect: String, expectedImprovement: Double, measurementMethod: String) {
                self.aspect = aspect
                self.expectedImprovement = expectedImprovement
                self.measurementMethod = measurementMethod
            }
        }

        public struct MaintainabilityEnhancement: Codable, Sendable {
            public let area: String
            public let improvement: String
            public let longTermBenefit: String

            public init(area: String, improvement: String, longTermBenefit: String) {
                self.area = area
                self.improvement = improvement
                self.longTermBenefit = longTermBenefit
            }
        }
    }

    public struct TimelinePhase: Codable, Sendable {
        public let phaseName: String
        public let duration: TimeInterval
        public let steps: [Int]
        public let milestones: [String]
        public let deliverables: [String]

        public init(phaseName: String, duration: TimeInterval, steps: [Int], milestones: [String], deliverables: [String]) {
            self.phaseName = phaseName
            self.duration = duration
            self.steps = steps
            self.milestones = milestones
            self.deliverables = deliverables
        }
    }

    public struct RiskMitigation: Codable, Sendable {
        public let risk: String
        public let mitigationStrategy: String
        public let contingencyPlan: String
        public let monitoringApproach: String

        public init(risk: String, mitigationStrategy: String, contingencyPlan: String, monitoringApproach: String) {
            self.risk = risk
            self.mitigationStrategy = mitigationStrategy
            self.contingencyPlan = contingencyPlan
            self.monitoringApproach = monitoringApproach
        }
    }
}

// MARK: - Observable Objects for SwiftUI

/// Observable wrapper for architecture analysis
@MainActor
public final class ObservableArchitectureAnalysis: ObservableObject {
    @Published public var analysis: ArchitectureAnalysis?
    @Published public var isLoading = false
    @Published public var error: Error?

    public init(analysis: ArchitectureAnalysis? = nil) {
        self.analysis = analysis
    }

    public func update(with analysis: ArchitectureAnalysis) {
        self.analysis = analysis
        self.error = nil
    }

    public func setError(_ error: Error) {
        self.error = error
        self.analysis = nil
    }
}

/// Observable wrapper for evolution progress
@MainActor
public final class ObservableEvolutionProgress: ObservableObject {
    @Published public var currentIteration = 0
    @Published public var totalIterations = 0
    @Published public var currentStep = ""
    @Published public var progress: Double = 0.0
    @Published public var isEvolving = false
    @Published public var evolutionResult: ArchitectureEvolution?

    public func startEvolution(totalIterations: Int) {
        self.totalIterations = totalIterations
        self.currentIteration = 0
        self.progress = 0.0
        self.isEvolving = true
        self.evolutionResult = nil
    }

    public func updateProgress(iteration: Int, step: String, progress: Double) {
        self.currentIteration = iteration
        self.currentStep = step
        self.progress = progress
    }

    public func completeEvolution(result: ArchitectureEvolution) {
        self.evolutionResult = result
        self.isEvolving = false
        self.progress = 1.0
    }
}

// MARK: - Error Types

/// Errors that can occur during architecture evolution
public enum ArchitectureEvolutionError: Error, LocalizedError {
    case analysisFailed(String)
    case refactoringFailed(String)
    case validationFailed(String)
    case evolutionFailed(String)
    case fileSystemError(String)

    public var errorDescription: String? {
        switch self {
        case .analysisFailed(let message):
            return "Architecture analysis failed: \(message)"
        case .refactoringFailed(let message):
            return "Refactoring operation failed: \(message)"
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .evolutionFailed(let message):
            return "Architecture evolution failed: \(message)"
        case .fileSystemError(let message):
            return "File system error: \(message)"
        }
    }
}

// MARK: - Utility Extensions

extension ArchitecturalPattern.PatternType {
    public var displayName: String {
        switch self {
        case .mvvm: return "MVVM"
        case .mvp: return "MVP"
        case .mvc: return "MVC"
        case .viper: return "VIPER"
        case .clean_architecture: return "Clean Architecture"
        case .hexagonal: return "Hexagonal Architecture"
        case .factory: return "Factory Pattern"
        case .singleton: return "Singleton Pattern"
        case .observer: return "Observer Pattern"
        case .strategy: return "Strategy Pattern"
        case .decorator: return "Decorator Pattern"
        case .repository: return "Repository Pattern"
        case .service_layer: return "Service Layer"
        case .dependency_injection: return "Dependency Injection"
        case .custom: return "Custom Pattern"
        }
    }
}

extension CodeSmell.SmellType {
    public var displayName: String {
        rawValue.split(separator: "_").map { $0.capitalized }.joined(separator: " ")
    }

    public var description: String {
        switch self {
        case .longMethod: return "A method that is too long and should be broken down"
        case .largeClass: return "A class that has grown too large and should be split"
        case .featureEnvy: return "A method that uses more features of another class than its own"
        case .dataClump: return "A group of variables that are always used together"
        case .primitiveObsession: return "Overuse of primitive types instead of small objects"
        case .switchStatement: return "A switch statement that should be replaced with polymorphism"
        case .temporaryField: return "A field that is only used temporarily"
        case .refusedBequest: return "A subclass that doesn't use all inherited methods"
        case .alternativeClasses: return "Classes that should be refactored to eliminate duplication"
        case .divergentChange: return "A class that changes for different reasons"
        case .shotgunSurgery: return "A change that requires changes to many classes"
        case .parallelInheritance: return "Two inheritance hierarchies that change together"
        case .comments: return "Excessive comments indicating unclear code"
        case .duplicateCode: return "Code that appears in multiple places"
        case .middleMan: return "A class that delegates too much to another class"
        case .lazyClass: return "A class that doesn't do enough to justify its existence"
        case .speculativeGenerality: return "Code created for future needs that never come"
        case .messageChains: return "A chain of method calls to get to data"
        case .inappropriateIntimacy: return "Classes that know too much about each other"
        }
    }
}

extension RefactoringSuggestion.RefactoringType {
    public var displayName: String {
        rawValue.split(separator: "_").map { $0.capitalized }.joined(separator: " ")
    }
}

// MARK: - JSON Encoding/Decoding Helpers

public extension ArchitectureAnalysis {
    /// Create from JSON data
    static func fromJSON(_ data: Data) throws -> ArchitectureAnalysis {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ArchitectureAnalysis.self, from: data)
    }

    /// Convert to JSON data
    func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(self)
    }
}

public extension ArchitectureEvolution {
    /// Create from JSON data
    static func fromJSON(_ data: Data) throws -> ArchitectureEvolution {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ArchitectureEvolution.self, from: data)
    }

    /// Convert to JSON data
    func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(self)
    }
}