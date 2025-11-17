#!/usr/bin/env python3

"""
Validation Framework - Multi-Layer Validation System
Provides syntax, logical, integration, and outcome validation for agent operations.
"""

import json
import sys
import subprocess
import logging
import time
from agents.utils import safe_run, user_log
logger = logging.getLogger(__name__)
from pathlib import Path
from typing import Dict, List, Tuple
from datetime import datetime
from enum import Enum

# Configuration
SCRIPT_DIR = Path(__file__).parent
ROOT_DIR = SCRIPT_DIR.parent.parent


class ValidationLayer(Enum):
    """Validation layers with timing."""

    SYNTAX = (1, 0)  # Layer 1: immediate
    LOGICAL = (2, 10)  # Layer 2: 10s delay
    INTEGRATION = (3, 30)  # Layer 3: 30s delay
    OUTCOME = (4, 300)  # Layer 4: 5min delay


class ValidationResult:
    """Result of a validation check."""

    def __init__(
        self, layer: ValidationLayer, passed: bool, message: str, details: Dict = None
    ):
        self.layer = layer
        self.passed = passed
        self.message = message
        self.details = details or {}
        self.timestamp = datetime.now().isoformat()

    def to_dict(self) -> Dict:
        return {
            "layer": self.layer.name,
            "passed": self.passed,
            "message": self.message,
            "details": self.details,
            "timestamp": self.timestamp,
        }


class ValidationFramework:
    """Multi-layer validation system for agent operations."""

    def __init__(self, operation_type: str = "general"):
        self.operation_type = operation_type
        self.results: List[ValidationResult] = []

    def validate_syntax(
        self, file_path: str, language: str = "auto"
    ) -> ValidationResult:
        """
        Layer 1: Syntax validation (immediate).
        Checks file for syntax errors without executing.
        """
        file_path = Path(file_path)

        if not file_path.exists():
            return ValidationResult(
                ValidationLayer.SYNTAX,
                False,
                f"File not found: {file_path}",
                {"error": "file_not_found"},
            )

        # Auto-detect language
        if language == "auto":
            suffix = file_path.suffix.lower()
            language_map = {
                ".swift": "swift",
                ".py": "python",
                ".sh": "bash",
                ".js": "javascript",
                ".ts": "typescript",
            }
            language = language_map.get(suffix, "unknown")

        # Syntax check based on language
        try:
            if language == "swift":
                result = safe_run(
                    ["swiftc", "-typecheck", str(file_path)],
                    capture_output=True,
                    text=True,
                    timeout=30,
                )
                passed = result.returncode == 0
                message = (
                    "Swift syntax valid" if passed else "Swift syntax errors found"
                )
                details = {"stderr": result.stderr} if not passed else {}

            elif language == "python":
                result = safe_run(
                    ["python3", "-m", "py_compile", str(file_path)],
                    capture_output=True,
                    text=True,
                    timeout=10,
                )
                passed = result.returncode == 0
                message = (
                    "Python syntax valid" if passed else "Python syntax errors found"
                )
                details = {"stderr": result.stderr} if not passed else {}

            elif language == "bash":
                result = safe_run(
                    ["bash", "-n", str(file_path)],
                    capture_output=True,
                    text=True,
                    timeout=5,
                )
                passed = result.returncode == 0
                message = "Bash syntax valid" if passed else "Bash syntax errors found"
                details = {"stderr": result.stderr} if not passed else {}

            else:
                # Unknown language, skip syntax check
                passed = True
                message = f"Syntax check skipped for {language}"
                details = {"reason": "unsupported_language"}

            validation = ValidationResult(
                ValidationLayer.SYNTAX, passed, message, details
            )
            self.results.append(validation)
            return validation

        except subprocess.TimeoutExpired:
            validation = ValidationResult(
                ValidationLayer.SYNTAX,
                False,
                "Syntax check timed out",
                {"error": "timeout"},
            )
            self.results.append(validation)
            return validation

        except Exception as e:
            validation = ValidationResult(
                ValidationLayer.SYNTAX,
                False,
                f"Syntax check failed: {str(e)}",
                {"error": str(e)},
            )
            self.results.append(validation)
            return validation

    def validate_logical(self, context: Dict) -> ValidationResult:
        """
        Layer 2: Logical validation (10s delay).
        Checks if operation makes sense in current context.
        """
        time.sleep(10)  # Deliberate delay for logical validation

        operation = context.get("operation", "unknown")
        file_path = context.get("file_path")

        # Check if operation is appropriate
        logical_checks = []

        # Check 1: File exists if operation requires it
        if file_path and operation in ["modify", "delete", "compile"]:
            if not Path(file_path).exists():
                logical_checks.append(
                    ("file_exists", False, f"File doesn't exist: {file_path}")
                )
            else:
                logical_checks.append(("file_exists", True, "File exists"))

        # Check 2: Dependencies met
        if context.get("requires_dependencies"):
            deps = context.get("dependencies", [])
            missing_deps = []
            for dep in deps:
                if not self._check_dependency(dep):
                    missing_deps.append(dep)

            if missing_deps:
                logical_checks.append(
                    ("dependencies", False, f"Missing: {', '.join(missing_deps)}")
                )
            else:
                logical_checks.append(
                    ("dependencies", True, "All dependencies available")
                )

        # Check 3: Operation sequence valid
        if context.get("previous_operation"):
            prev_op = context["previous_operation"]
            if not self._valid_sequence(prev_op, operation):
                logical_checks.append(
                    ("sequence", False, f"Invalid sequence: {prev_op} -> {operation}")
                )
            else:
                logical_checks.append(("sequence", True, "Operation sequence valid"))

        # Evaluate overall logical validity
        failed_checks = [c for c in logical_checks if not c[1]]
        passed = len(failed_checks) == 0

        if passed:
            message = f"Logical validation passed ({len(logical_checks)} checks)"
        else:
            message = f"Logical validation failed: {len(failed_checks)}/{len(logical_checks)} checks failed"

        validation = ValidationResult(
            ValidationLayer.LOGICAL,
            passed,
            message,
            {
                "checks": [
                    {"name": c[0], "passed": c[1], "message": c[2]}
                    for c in logical_checks
                ]
            },
        )
        self.results.append(validation)
        return validation

    def validate_integration(self, context: Dict) -> ValidationResult:
        """
        Layer 3: Integration validation (30s delay).
        Checks if operation integrates properly with system.
        """
        time.sleep(30)  # Deliberate delay for integration validation

        integration_checks = []

        # Check 1: Build succeeds if code change
        if context.get("affects_build", False):
            build_result = self._run_build_check(context)
            integration_checks.append(("build", build_result[0], build_result[1]))

        # Check 2: Tests pass if test-affecting change
        if context.get("affects_tests", False):
            test_result = self._run_test_check(context)
            integration_checks.append(("tests", test_result[0], test_result[1]))

        # Check 3: Lint passes if code change
        if context.get("affects_code", False):
            lint_result = self._run_lint_check(context)
            integration_checks.append(("lint", lint_result[0], lint_result[1]))

        # Evaluate overall integration
        failed_checks = [c for c in integration_checks if not c[1]]
        passed = len(failed_checks) == 0

        if passed:
            message = (
                f"Integration validation passed ({len(integration_checks)} checks)"
            )
        else:
            message = f"Integration validation failed: {len(failed_checks)}/{len(integration_checks)} checks failed"

        validation = ValidationResult(
            ValidationLayer.INTEGRATION,
            passed,
            message,
            {
                "checks": [
                    {"name": c[0], "passed": c[1], "message": c[2]}
                    for c in integration_checks
                ]
            },
        )
        self.results.append(validation)
        return validation

    def validate_outcome(self, context: Dict) -> ValidationResult:
        """
        Layer 4: Outcome validation (5min delay).
        Checks if operation achieved intended goal.
        """
        time.sleep(300)  # Deliberate delay for outcome validation

        goal = context.get("goal", "unknown")
        outcome_checks = []

        # Check 1: Goal achieved
        if goal == "fix_build":
            build_result = self._run_build_check(context)
            outcome_checks.append(
                (
                    "goal_achieved",
                    build_result[0],
                    "Build now succeeds" if build_result[0] else "Build still fails",
                )
            )

        elif goal == "fix_tests":
            test_result = self._run_test_check(context)
            outcome_checks.append(
                (
                    "goal_achieved",
                    test_result[0],
                    "Tests now pass" if test_result[0] else "Tests still fail",
                )
            )

        # Check 2: No regressions introduced
        regression_result = self._check_regressions(context)
        outcome_checks.append(
            ("no_regressions", regression_result[0], regression_result[1])
        )

        # Check 3: Quality maintained
        quality_result = self._check_quality_metrics(context)
        outcome_checks.append(("quality", quality_result[0], quality_result[1]))

        # Evaluate overall outcome
        failed_checks = [c for c in outcome_checks if not c[1]]
        passed = len(failed_checks) == 0

        if passed:
            message = "Outcome validation passed - goal achieved"
        else:
            message = f"Outcome validation failed: {len(failed_checks)}/{len(outcome_checks)} checks failed"

        validation = ValidationResult(
            ValidationLayer.OUTCOME,
            passed,
            message,
            {
                "checks": [
                    {"name": c[0], "passed": c[1], "message": c[2]}
                    for c in outcome_checks
                ]
            },
        )
        self.results.append(validation)
        return validation

    def validate_all_layers(
        self, file_path: str = None, context: Dict = None
    ) -> List[ValidationResult]:
        """Run all validation layers in sequence."""
        context = context or {}
        results = []

        # Layer 1: Syntax (if file provided)
        if file_path:
            syntax_result = self.validate_syntax(file_path)
            results.append(syntax_result)
            if not syntax_result.passed:
                return results  # Stop if syntax fails

        # Layer 2: Logical
        logical_result = self.validate_logical(context)
        results.append(logical_result)
        if not logical_result.passed:
            return results  # Stop if logical fails

        # Layer 3: Integration
        integration_result = self.validate_integration(context)
        results.append(integration_result)
        if not integration_result.passed:
            return results  # Stop if integration fails

        # Layer 4: Outcome
        outcome_result = self.validate_outcome(context)
        results.append(outcome_result)

        return results

    def get_validation_report(self) -> Dict:
        """Generate validation report."""
        passed = all(r.passed for r in self.results)

        return {
            "overall_passed": passed,
            "total_layers": len(self.results),
            "passed_layers": sum(1 for r in self.results if r.passed),
            "failed_layers": sum(1 for r in self.results if not r.passed),
            "layers": [r.to_dict() for r in self.results],
            "timestamp": datetime.now().isoformat(),
        }

    # Helper methods

    def _check_dependency(self, dependency: str) -> bool:
        """Check if a dependency is available."""
        try:
            safe_run(["which", dependency], capture_output=True, check=True)
            return True
        except subprocess.CalledProcessError:
            return False

    def _valid_sequence(self, prev_op: str, current_op: str) -> bool:
        """Check if operation sequence is valid."""
        invalid_sequences = [
            ("delete", "modify"),  # Can't modify after delete
            ("compile", "create"),  # Should create before compile
        ]
        return (prev_op, current_op) not in invalid_sequences

    def _run_build_check(self, context: Dict) -> Tuple[bool, str]:
        """Run build check."""
        project = context.get("project", "CodingReviewer")
        try:
            result = safe_run(
                ["xcodebuild", "build", "-scheme", project, "-configuration", "Debug"],
                capture_output=True,
                text=True,
                timeout=120,
                cwd=str(ROOT_DIR),
            )
            if result.returncode == 0:
                return (True, "Build succeeded")
            else:
                return (False, f"Build failed: {result.stderr[:200]}")
        except subprocess.TimeoutExpired:
            return (False, "Build timed out")
        except Exception as e:
            return (False, f"Build check failed: {str(e)}")

    def _run_test_check(self, context: Dict) -> Tuple[bool, str]:
        """Run test check."""
        project = context.get("project", "CodingReviewer")
        try:
            result = safe_run(
                ["xcodebuild", "test", "-scheme", project, "-configuration", "Debug"],
                capture_output=True,
                text=True,
                timeout=300,
                cwd=str(ROOT_DIR),
            )
            if result.returncode == 0:
                return (True, "Tests passed")
            else:
                return (False, f"Tests failed: {result.stderr[:200]}")
        except subprocess.TimeoutExpired:
            return (False, "Tests timed out")
        except Exception as e:
            return (False, f"Test check failed: {str(e)}")

    def _run_lint_check(self, context: Dict) -> Tuple[bool, str]:
        """Run lint check."""
        try:
            result = safe_run(
                ["swiftlint", "lint", "--quiet"],
                capture_output=True,
                text=True,
                timeout=30,
                cwd=str(ROOT_DIR),
            )
            if result.returncode == 0:
                return (True, "Lint passed")
            else:
                errors = result.stdout.count("error:")
                return (False, f"Lint found {errors} errors")
        except FileNotFoundError:
            return (True, "SwiftLint not available, skipping")
        except Exception as e:
            return (False, f"Lint check failed: {str(e)}")

    def _check_regressions(self, context: Dict) -> Tuple[bool, str]:
        """Check for regressions."""
        # Simple regression check: compare current state with before state
        before_state = context.get("before_state", {})
        after_state = context.get("after_state", {})

        # Check if any metrics got worse
        regressions = []

        if "test_pass_rate" in before_state and "test_pass_rate" in after_state:
            if after_state["test_pass_rate"] < before_state["test_pass_rate"]:
                regressions.append(
                    f"Test pass rate decreased from {before_state['test_pass_rate']} to {after_state['test_pass_rate']}"
                )

        if "build_time" in before_state and "build_time" in after_state:
            if (
                after_state["build_time"] > before_state["build_time"] * 1.5
            ):  # 50% increase
                regressions.append("Build time increased significantly")

        if regressions:
            return (False, "; ".join(regressions))
        else:
            return (True, "No regressions detected")

    def _check_quality_metrics(self, context: Dict) -> Tuple[bool, str]:
        """Check quality metrics."""
        # Basic quality checks
        checks = []

        # Check file size (not too large)
        file_path = context.get("file_path")
        if file_path and Path(file_path).exists():
            size = Path(file_path).stat().st_size
            if size > 1024 * 1024:  # 1MB
                checks.append(False)
            else:
                checks.append(True)

        # Check line count (not too many)
        if file_path and Path(file_path).exists():
            with open(file_path, "r") as f:
                lines = len(f.readlines())
            if lines > 500:
                checks.append(False)
            else:
                checks.append(True)

        if all(checks):
            return (True, "Quality metrics maintained")
        else:
            return (
                False,
                f"Quality concerns: {len([c for c in checks if not c])} issues",
            )


def main():
    """CLI interface for validation framework."""
    if len(sys.argv) < 2:
        user_log("Usage: validation_framework.py <command> [arguments]", level="error", stderr=True)
        user_log("\nCommands:", level="error", stderr=True)
        user_log("  syntax <file> [language]     - Validate syntax", level="error", stderr=True)
        user_log("  logical <context_json>       - Validate logic", level="error", stderr=True)
        user_log("  integration <context_json>   - Validate integration", level="error", stderr=True)
        user_log("  outcome <context_json>       - Validate outcome", level="error", stderr=True)
        user_log("  all <file> <context_json>    - Run all layers", level="error", stderr=True)
        sys.exit(1)

    command = sys.argv[1]
    framework = ValidationFramework()

    if command == "syntax":
        if len(sys.argv) < 3:
            user_log("ERROR: Missing file path", level="error", stderr=True)
            sys.exit(1)

        file_path = sys.argv[2]
        language = sys.argv[3] if len(sys.argv) > 3 else "auto"

        result = framework.validate_syntax(file_path, language)
        user_log(json.dumps(result.to_dict(), indent=2))
        sys.exit(0 if result.passed else 1)

    elif command == "logical":
        if len(sys.argv) < 3:
            user_log("ERROR: Missing context JSON", level="error", stderr=True)
            sys.exit(1)

        context = json.loads(sys.argv[2])
        result = framework.validate_logical(context)
        user_log(json.dumps(result.to_dict(), indent=2))
        sys.exit(0 if result.passed else 1)

    elif command == "integration":
        if len(sys.argv) < 3:
            user_log("ERROR: Missing context JSON", level="error", stderr=True)
            sys.exit(1)

        context = json.loads(sys.argv[2])
        result = framework.validate_integration(context)
        user_log(json.dumps(result.to_dict(), indent=2))
        sys.exit(0 if result.passed else 1)

    elif command == "outcome":
        if len(sys.argv) < 3:
            user_log("ERROR: Missing context JSON", level="error", stderr=True)
            sys.exit(1)

        context = json.loads(sys.argv[2])
        result = framework.validate_outcome(context)
        user_log(json.dumps(result.to_dict(), indent=2))
        sys.exit(0 if result.passed else 1)

    elif command == "all":
        if len(sys.argv) < 4:
            user_log("ERROR: Missing file path and context JSON", level="error", stderr=True)
            sys.exit(1)

        file_path = sys.argv[2]
        context = json.loads(sys.argv[3])

        _results = framework.validate_all_layers(file_path, context)
        report = framework.get_validation_report()
        user_log(json.dumps(report, indent=2))
        sys.exit(0 if report["overall_passed"] else 1)

    else:
        user_log(f"ERROR: Unknown command: {command}", level="error", stderr=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
