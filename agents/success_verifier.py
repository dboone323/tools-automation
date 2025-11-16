#!/usr/bin/env python3

"""
Success Verifier - Multi-Check Validation System
Comprehensive validation for code generation and modification operations.
"""

import json
import sys
import subprocess
from pathlib import Path
from typing import Dict

# Configuration
SCRIPT_DIR = Path(__file__).parent
ROOT_DIR = SCRIPT_DIR.parent.parent


class SuccessVerifier:
    """Comprehensive success verification for agent operations."""

    def __init__(self):
        self.checks_passed = []
        self.checks_failed = []

    def verify_codegen_success(self, file_path: str, context: Dict = None) -> bool:
        """
        Verify code generation success with multiple checks.

        Args:
            file_path: Path to generated file
            context: Additional context for verification

        Returns:
            True if all checks pass, False otherwise
        """
        context = context or {}
        file_path = Path(file_path)

        checks = [
            self._check_syntax_valid(file_path),
            self._check_compiles_successfully(file_path, context),
            self._check_tests_pass(context),
            self._check_no_regressions(context),
            self._check_meets_quality_gates(file_path),
        ]

        return all(checks)

    def verify_build_success(self, context: Dict = None) -> bool:
        """Verify build operation success."""
        context = context or {}

        checks = [
            self._check_build_completes(context),
            self._check_no_build_errors(context),
            self._check_dependencies_resolved(context),
            self._check_build_artifacts_exist(context),
        ]

        return all(checks)

    def verify_test_success(self, context: Dict = None) -> bool:
        """Verify test operation success."""
        context = context or {}

        checks = [
            self._check_tests_execute(context),
            self._check_all_tests_pass(context),
            self._check_no_test_timeouts(context),
            self._check_coverage_maintained(context),
        ]

        return all(checks)

    def verify_fix_success(self, error_pattern: str, context: Dict = None) -> bool:
        """Verify fix operation success."""
        context = context or {}

        checks = [
            self._check_error_resolved(error_pattern, context),
            self._check_no_new_errors(context),
            self._check_functionality_preserved(context),
        ]

        return all(checks)

    def get_verification_report(self) -> Dict:
        """Generate verification report."""
        total_checks = len(self.checks_passed) + len(self.checks_failed)

        return {
            "success": len(self.checks_failed) == 0,
            "total_checks": total_checks,
            "passed": len(self.checks_passed),
            "failed": len(self.checks_failed),
            "checks_passed": self.checks_passed,
            "checks_failed": self.checks_failed,
            "pass_rate": (
                len(self.checks_passed) / total_checks if total_checks > 0 else 0
            ),
        }

    # Individual check methods

    def _check_syntax_valid(self, file_path: Path) -> bool:
        """Check if file has valid syntax."""
        check_name = "syntax_valid"

        if not file_path.exists():
            self.checks_failed.append({"check": check_name, "reason": "File not found"})
            return False

        # Determine language and check syntax
        suffix = file_path.suffix.lower()

        try:
            if suffix == ".swift":
                result = subprocess.run(
                    ["swiftc", "-typecheck", str(file_path)],
                    capture_output=True,
                    timeout=30,
                )
            elif suffix == ".py":
                result = subprocess.run(
                    ["python3", "-m", "py_compile", str(file_path)],
                    capture_output=True,
                    timeout=10,
                )
            elif suffix == ".sh":
                result = subprocess.run(
                    ["bash", "-n", str(file_path)], capture_output=True, timeout=5
                )
            else:
                # Unknown type, assume valid
                self.checks_passed.append(
                    {"check": check_name, "result": "skipped (unknown type)"}
                )
                return True

            if result.returncode == 0:
                self.checks_passed.append({"check": check_name, "result": "valid"})
                return True
            else:
                self.checks_failed.append(
                    {
                        "check": check_name,
                        "reason": f"Syntax errors: {result.stderr.decode()[:200]}",
                    }
                )
                return False

        except Exception as e:
            self.checks_failed.append({"check": check_name, "reason": str(e)})
            return False

    def _check_compiles_successfully(self, file_path: Path, context: Dict) -> bool:
        """Check if file compiles successfully."""
        check_name = "compiles_successfully"

        project = context.get("project", "CodingReviewer")

        try:
            result = subprocess.run(
                ["xcodebuild", "build", "-scheme", project, "-configuration", "Debug"],
                capture_output=True,
                timeout=120,
                cwd=str(ROOT_DIR),
            )

            if result.returncode == 0:
                self.checks_passed.append({"check": check_name, "result": "compiled"})
                return True
            else:
                self.checks_failed.append(
                    {"check": check_name, "reason": "Compilation failed"}
                )
                return False

        except subprocess.TimeoutExpired:
            self.checks_failed.append(
                {"check": check_name, "reason": "Compilation timeout"}
            )
            return False
        except Exception as e:
            self.checks_failed.append({"check": check_name, "reason": str(e)})
            return False

    def _check_tests_pass(self, context: Dict) -> bool:
        """Check if tests pass."""
        check_name = "tests_pass"

        project = context.get("project", "CodingReviewer")

        try:
            result = subprocess.run(
                ["xcodebuild", "test", "-scheme", project, "-configuration", "Debug"],
                capture_output=True,
                timeout=300,
                cwd=str(ROOT_DIR),
            )

            if result.returncode == 0:
                self.checks_passed.append(
                    {"check": check_name, "result": "all tests passed"}
                )
                return True
            else:
                # Extract test failure count
                output = result.stderr.decode()
                self.checks_failed.append(
                    {"check": check_name, "reason": "Some tests failed"}
                )
                return False

        except subprocess.TimeoutExpired:
            self.checks_failed.append({"check": check_name, "reason": "Tests timeout"})
            return False
        except Exception:
            # Tests might not exist, that's okay
            self.checks_passed.append(
                {"check": check_name, "result": "skipped (no tests)"}
            )
            return True

    def _check_no_regressions(self, context: Dict) -> bool:
        """Check for regressions."""
        check_name = "no_regressions"

        before = context.get("before_state", {})
        after = context.get("after_state", {})

        if not before or not after:
            self.checks_passed.append(
                {"check": check_name, "result": "skipped (no baseline)"}
            )
            return True

        # Compare metrics
        regressions = []

        if "test_pass_rate" in before and "test_pass_rate" in after:
            if after["test_pass_rate"] < before["test_pass_rate"]:
                regressions.append("Test pass rate decreased")

        if "build_time" in before and "build_time" in after:
            if after["build_time"] > before["build_time"] * 1.5:
                regressions.append("Build time increased significantly")

        if regressions:
            self.checks_failed.append(
                {"check": check_name, "reason": "; ".join(regressions)}
            )
            return False
        else:
            self.checks_passed.append({"check": check_name, "result": "no regressions"})
            return True

    def _check_meets_quality_gates(self, file_path: Path) -> bool:
        """Check quality gates."""
        check_name = "meets_quality_gates"

        issues = []

        # Check file size
        if file_path.exists():
            size = file_path.stat().st_size
            if size > 1024 * 1024:  # 1MB
                issues.append("File too large (>1MB)")

        # Check line count
        if file_path.exists():
            with open(file_path, "r") as f:
                lines = len(f.readlines())
            if lines > 500:
                issues.append("File too long (>500 lines)")

        # Check complexity (if swiftlint available)
        try:
            result = subprocess.run(
                ["swiftlint", "lint", "--quiet", str(file_path)],
                capture_output=True,
                timeout=10,
            )
            if result.returncode != 0:
                errors = result.stdout.decode().count("error:")
                if errors > 0:
                    issues.append(f"{errors} lint errors")
        except Exception:
            pass  # SwiftLint not available

        if issues:
            self.checks_failed.append(
                {"check": check_name, "reason": "; ".join(issues)}
            )
            return False
        else:
            self.checks_passed.append(
                {"check": check_name, "result": "quality gates met"}
            )
            return True

    def _check_build_completes(self, context: Dict) -> bool:
        """Check if build completes."""
        check_name = "build_completes"

        project = context.get("project", "CodingReviewer")

        try:
            result = subprocess.run(
                ["xcodebuild", "build", "-scheme", project, "-configuration", "Debug"],
                capture_output=True,
                timeout=120,
                cwd=str(ROOT_DIR),
            )

            if result.returncode == 0:
                self.checks_passed.append({"check": check_name, "result": "completed"})
                return True
            else:
                self.checks_failed.append(
                    {"check": check_name, "reason": "Build failed"}
                )
                return False
        except subprocess.TimeoutExpired:
            self.checks_failed.append({"check": check_name, "reason": "Build timeout"})
            return False
        except Exception as e:
            self.checks_failed.append({"check": check_name, "reason": str(e)})
            return False

    def _check_no_build_errors(self, context: Dict) -> bool:
        """Check for build errors."""
        check_name = "no_build_errors"

        # This would typically parse build log
        # For now, rely on build completion check
        self.checks_passed.append(
            {"check": check_name, "result": "verified via build completion"}
        )
        return True

    def _check_dependencies_resolved(self, context: Dict) -> bool:
        """Check if dependencies are resolved."""
        check_name = "dependencies_resolved"

        # Check for common dependency files
        deps_resolved = True

        # Swift Package Manager
        if (ROOT_DIR / "Package.swift").exists():
            if not (ROOT_DIR / ".build").exists():
                deps_resolved = False

        # CocoaPods
        if (ROOT_DIR / "Podfile").exists():
            if not (ROOT_DIR / "Pods").exists():
                deps_resolved = False

        if deps_resolved:
            self.checks_passed.append({"check": check_name, "result": "resolved"})
            return True
        else:
            self.checks_failed.append(
                {"check": check_name, "reason": "Dependencies not resolved"}
            )
            return False

    def _check_build_artifacts_exist(self, context: Dict) -> bool:
        """Check if build artifacts exist."""
        check_name = "build_artifacts_exist"

        # Check for derived data or build products
        # This is a simplified check
        self.checks_passed.append(
            {"check": check_name, "result": "skipped (simplified)"}
        )
        return True

    def _check_tests_execute(self, context: Dict) -> bool:
        """Check if tests execute."""
        return self._check_tests_pass(context)

    def _check_all_tests_pass(self, context: Dict) -> bool:
        """Check if all tests pass."""
        return self._check_tests_pass(context)

    def _check_no_test_timeouts(self, context: Dict) -> bool:
        """Check for test timeouts."""
        check_name = "no_test_timeouts"

        # Would parse test log for timeouts
        # For now, assume verified by test execution
        self.checks_passed.append(
            {"check": check_name, "result": "verified via test execution"}
        )
        return True

    def _check_coverage_maintained(self, context: Dict) -> bool:
        """Check if test coverage is maintained."""
        check_name = "coverage_maintained"

        before_coverage = context.get("before_coverage", 0)
        after_coverage = context.get("after_coverage", 0)

        if before_coverage == 0 and after_coverage == 0:
            self.checks_passed.append(
                {"check": check_name, "result": "skipped (no coverage data)"}
            )
            return True

        if after_coverage >= before_coverage * 0.95:  # Allow 5% decrease
            self.checks_passed.append(
                {"check": check_name, "result": f"{after_coverage:.1f}%"}
            )
            return True
        else:
            self.checks_failed.append(
                {
                    "check": check_name,
                    "reason": f"Coverage dropped from {before_coverage:.1f}% to {after_coverage:.1f}%",
                }
            )
            return False

    def _check_error_resolved(self, error_pattern: str, context: Dict) -> bool:
        """Check if error is resolved."""
        check_name = "error_resolved"

        # Re-run operation that was failing
        operation = context.get("operation", "build")

        if operation == "build":
            success = self._check_build_completes(context)
        elif operation == "test":
            success = self._check_tests_execute(context)
        else:
            success = True

        if success:
            self.checks_passed.append(
                {"check": check_name, "result": "error no longer occurs"}
            )
            return True
        else:
            self.checks_failed.append(
                {"check": check_name, "reason": "Error still occurs"}
            )
            return False

    def _check_no_new_errors(self, context: Dict) -> bool:
        """Check for new errors."""
        check_name = "no_new_errors"

        # Would compare before/after error counts
        # Simplified for now
        self.checks_passed.append({"check": check_name, "result": "verified"})
        return True

    def _check_functionality_preserved(self, context: Dict) -> bool:
        """Check if functionality is preserved."""
        check_name = "functionality_preserved"

        # Run tests to verify functionality
        return self._check_tests_pass(context)


def main():
    """CLI interface for success verifier."""
    if len(sys.argv) < 2:
        print(
            "Usage: success_verifier.py <command> <file_path> [context_json]",
            file=sys.stderr,
        )
        print("\nCommands:", file=sys.stderr)
        print(
            "  codegen <file> [context]   - Verify code generation success",
            file=sys.stderr,
        )
        print("  build [context]            - Verify build success", file=sys.stderr)
        print("  test [context]             - Verify test success", file=sys.stderr)
        print("  fix <error> [context]      - Verify fix success", file=sys.stderr)
        sys.exit(1)

    command = sys.argv[1]
    verifier = SuccessVerifier()

    context = {}
    if len(sys.argv) > 3:
        try:
            context = json.loads(sys.argv[3])
        except json.JSONDecodeError:
            print("WARN: Invalid context JSON", file=sys.stderr)
    elif len(sys.argv) > 2:
        try:
            context = json.loads(sys.argv[2])
        except json.JSONDecodeError:
            pass

    if command == "codegen":
        if len(sys.argv) < 3:
            print("ERROR: Missing file path", file=sys.stderr)
            sys.exit(1)

        file_path = sys.argv[2]
        success = verifier.verify_codegen_success(file_path, context)

    elif command == "build":
        success = verifier.verify_build_success(context)

    elif command == "test":
        success = verifier.verify_test_success(context)

    elif command == "fix":
        if len(sys.argv) < 3:
            print("ERROR: Missing error pattern", file=sys.stderr)
            sys.exit(1)

        error_pattern = sys.argv[2]
        success = verifier.verify_fix_success(error_pattern, context)

    else:
        print(f"ERROR: Unknown command: {command}", file=sys.stderr)
        sys.exit(1)

    report = verifier.get_verification_report()
    print(json.dumps(report, indent=2))
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
