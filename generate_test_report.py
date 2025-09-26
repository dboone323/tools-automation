#!/usr/bin/env python3
"""
Quantum Workspace Test Report Generator
Generates comprehensive test reports for the entire workspace.
"""

import json
import subprocess
from datetime import datetime
from pathlib import Path

import yaml


class TestReportGenerator:
    """Generates comprehensive test reports for the Quantum Workspace."""

    def __init__(self):
        self.workspace_root = Path("/Users/danielstevens/Desktop/Code")
        self.reports_dir = self.workspace_root / "Tools" / "Automation" / "reports"
        self.reports_dir.mkdir(exist_ok=True)

    def generate_comprehensive_report(self):
        """Generate a comprehensive test report."""
        report = {
            "report_metadata": {
                "generated_at": datetime.now().isoformat(),
                "workspace": str(self.workspace_root),
                "test_type": "comprehensive_workspace_validation",
            },
            "test_results": {},
            "system_status": {},
            "recommendations": [],
        }

        # Run all test suites
        report["test_results"] = self._run_all_tests()

        # Gather system status
        report["system_status"] = self._gather_system_status()

        # Generate recommendations
        report["recommendations"] = self._generate_recommendations(report)

        # Save report
        report_file = (
            self.reports_dir
            / f"workspace_test_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        )
        with open(report_file, "w") as f:
            json.dump(report, f, indent=2, default=str)

        return report_file, report

    def _run_all_tests(self):
        """Run all available test suites."""
        test_results = {}

        # Python MCP and automation tests
        try:
            result = subprocess.run(
                ["python3", "-m", "pytest", "Automation/tests/", "--tb=short", "-q"],
                capture_output=True,
                text=True,
                cwd=self.workspace_root / "Tools",
            )
            test_results["python_tests"] = {
                "passed": "passed" in result.stdout,
                "output": result.stdout,
                "errors": result.stderr,
                "return_code": result.returncode,
            }
        except Exception as e:
            test_results["python_tests"] = {"error": str(e)}

        # Swift build tests
        try:
            result = subprocess.run(
                ["./Tools/Automation/master_automation.sh", "all"],
                capture_output=True,
                text=True,
                cwd=self.workspace_root / "Tools",
            )
            test_results["swift_builds"] = {
                "completed": result.returncode == 0,
                "output": result.stdout[-2000:],  # Last 2000 chars
                "errors": result.stderr,
                "return_code": result.returncode,
            }
        except Exception as e:
            test_results["swift_builds"] = {"error": str(e)}

        # GitHub workflows validation
        test_results["ci_cd_workflows"] = self._validate_workflows()

        return test_results

    def _validate_workflows(self):
        """Validate GitHub Actions workflows."""
        workflows_dir = self.workspace_root / ".github" / "workflows"
        workflow_results = {}

        if workflows_dir.exists():
            for workflow_file in workflows_dir.glob("*.yml"):
                try:
                    with open(workflow_file, "r") as f:
                        workflow = yaml.safe_load(f)

                    workflow_results[workflow_file.name] = {
                        "valid": True,
                        "name": workflow.get("name", "Unknown"),
                        "has_jobs": bool(workflow.get("jobs")),
                        "trigger_type": (
                            "workflow_call" if True in workflow else "traditional"
                        ),
                    }
                except Exception as e:
                    workflow_results[workflow_file.name] = {
                        "valid": False,
                        "error": str(e),
                    }
        else:
            workflow_results["status"] = "No workflows directory found"

        return workflow_results

    def _gather_system_status(self):
        """Gather system and project status information."""
        status = {}

        # Development tools status
        tools = ["xcodebuild", "swift", "swiftlint", "python3", "git"]
        status["development_tools"] = {}

        for tool in tools:
            try:
                result = subprocess.run(
                    [tool, "--version"], capture_output=True, text=True
                )
                status["development_tools"][tool] = {
                    "available": result.returncode == 0,
                    "version": (
                        result.stdout.strip() if result.returncode == 0 else None
                    ),
                }
            except Exception as e:
                status["development_tools"][tool] = {"error": str(e)}

        # Project status
        status["projects"] = self._get_project_status()

        # Repository status
        status["git_status"] = self._get_git_status()

        return status

    def _get_project_status(self):
        """Get status of all projects."""
        projects_dir = self.workspace_root / "Projects"
        project_status = {}

        if projects_dir.exists():
            for project_dir in projects_dir.iterdir():
                if project_dir.is_dir():
                    project_status[project_dir.name] = {
                        "exists": True,
                        "has_xcodeproj": any(project_dir.glob("*.xcodeproj")),
                        "swift_files": len(list(project_dir.rglob("*.swift"))),
                        "path": str(project_dir),
                    }

        return project_status

    def _get_git_status(self):
        """Get git repository status."""
        try:
            result = subprocess.run(
                ["git", "status", "--porcelain"],
                capture_output=True,
                text=True,
                cwd=self.workspace_root,
            )

            return {
                "clean": len(result.stdout.strip()) == 0,
                "changes": (
                    len(result.stdout.strip().split("\n"))
                    if result.stdout.strip()
                    else 0
                ),
                "output": result.stdout,
            }
        except Exception as e:
            return {"error": str(e)}

    def _generate_recommendations(self, report):
        """Generate recommendations based on test results."""
        recommendations = []

        # Check test results
        test_results = report.get("test_results", {})

        if not test_results.get("python_tests", {}).get("passed", False):
            recommendations.append(
                {
                    "priority": "high",
                    "category": "testing",
                    "issue": "Python tests are failing",
                    "action": "Fix failing Python tests in Automation/tests/",
                }
            )

        if not test_results.get("swift_builds", {}).get("completed", False):
            recommendations.append(
                {
                    "priority": "medium",
                    "category": "build",
                    "issue": "Swift builds have issues",
                    "action": "Address build failures, likely related to code signing and provisioning",
                }
            )

        # Check system status
        system_status = report.get("system_status", {})
        dev_tools = system_status.get("development_tools", {})

        missing_tools = [
            tool for tool, info in dev_tools.items() if not info.get("available")
        ]
        if missing_tools:
            recommendations.append(
                {
                    "priority": "high",
                    "category": "environment",
                    "issue": f"Missing development tools: {', '.join(missing_tools)}",
                    "action": "Install missing development tools",
                }
            )

        # Check projects
        projects = system_status.get("projects", {})
        projects_without_xcodeproj = [
            name
            for name, info in projects.items()
            if info.get("exists") and not info.get("has_xcodeproj")
        ]

        if projects_without_xcodeproj:
            recommendations.append(
                {
                    "priority": "low",
                    "category": "project_structure",
                    "issue": f"Projects without Xcode project files: {', '.join(projects_without_xcodeproj)}",
                    "action": "Review project structure and add Xcode project files if needed",
                }
            )

        # Git status
        git_status = system_status.get("git_status", {})
        if not git_status.get("clean", True):
            recommendations.append(
                {
                    "priority": "medium",
                    "category": "version_control",
                    "issue": f"Repository has uncommitted changes ({git_status.get('changes', 0)} files)",
                    "action": "Commit or stash changes before deployment",
                }
            )

        return recommendations


def main():
    """Main function to generate and display test report."""
    generator = TestReportGenerator()
    report_file, report = generator.generate_comprehensive_report()

    print("=== QUANTUM WORKSPACE TEST REPORT ===")
    print(f"Generated at: {report['report_metadata']['generated_at']}")
    print(f"Report saved to: {report_file}")
    print()

    # Test Results Summary
    print("TEST RESULTS SUMMARY:")
    test_results = report.get("test_results", {})
    for test_type, result in test_results.items():
        if isinstance(result, dict):
            if "passed" in result:
                status = "✅ PASSED" if result["passed"] else "❌ FAILED"
            elif "completed" in result:
                status = "✅ COMPLETED" if result["completed"] else "❌ FAILED"
            elif "error" in result:
                status = "❌ ERROR"
            else:
                status = "✅ OK"
            print(f"  {test_type}: {status}")
        else:
            print(f"  {test_type}: {result}")

    print()

    # System Status Summary
    print("SYSTEM STATUS:")
    system_status = report.get("system_status", {})
    dev_tools = system_status.get("development_tools", {})

    print("  Development Tools:")
    for tool, info in dev_tools.items():
        if info.get("available"):
            version = info.get("version", "Unknown version")
            print(f"    ✅ {tool}: {version}")
        else:
            print(f"    ❌ {tool}: Not available")

    projects = system_status.get("projects", {})
    print(f"  Projects: {len(projects)} found")

    git_status = system_status.get("git_status", {})
    if git_status.get("clean"):
        print("  Git Status: ✅ Clean working directory")
    else:
        print(f"  Git Status: ⚠️  {git_status.get('changes', 0)} uncommitted changes")

    print()

    # Recommendations
    recommendations = report.get("recommendations", [])
    if recommendations:
        print("RECOMMENDATIONS:")
        for rec in recommendations:
            priority_icon = {"high": "🔴", "medium": "🟡", "low": "🟢"}.get(
                rec["priority"], "⚪"
            )
            print(f"  {priority_icon} [{rec['priority'].upper()}] {rec['issue']}")
            print(f"      → {rec['action']}")
        print()
    else:
        print("✅ No recommendations - all systems operational!")

    print(f"\nDetailed report available at: {report_file}")


if __name__ == "__main__":
    main()
