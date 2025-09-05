#!/usr/bin/env python3
"""
CI/CD Workflow Tests
Tests for GitHub Actions workflows and deployment processes.
"""

import os
import subprocess
import tempfile
from pathlib import Path

import pytest
import yaml


class TestCIWorkflows:
    """Test GitHub Actions workflow files."""

    def test_workflow_files_exist(self):
        """Test that workflow files exist and are valid YAML."""
        workflows_dir = Path(
            "/Users/danielstevens/Desktop/Quantum-workspace/.github/workflows"
        )

        if not workflows_dir.exists():
            pytest.skip("No .github/workflows directory found")

        workflow_files = list(workflows_dir.glob("*.yml")) + list(
            workflows_dir.glob("*.yaml")
        )

        assert len(workflow_files) > 0, "No workflow files found"

        for workflow_file in workflow_files:
            # Test YAML is valid
            with open(workflow_file, "r") as f:
                content = f.read()
                try:
                    yaml.safe_load(content)
                except yaml.YAMLError as e:
                    pytest.fail(f"Invalid YAML in {workflow_file}: {e}")

    def test_workflow_structure(self):
        """Test that workflows have required structure."""
        workflows_dir = Path(
            "/Users/danielstevens/Desktop/Quantum-workspace/.github/workflows"
        )

        if not workflows_dir.exists():
            pytest.skip("No .github/workflows directory found")

        workflow_files = list(workflows_dir.glob("*.yml")) + list(
            workflows_dir.glob("*.yaml")
        )

        for workflow_file in workflow_files:
            with open(workflow_file, "r") as f:
                workflow = yaml.safe_load(f)

            # Check required top-level keys
            assert "name" in workflow, f"Workflow {workflow_file} missing 'name'"
            # Workflows can have 'on' trigger OR 'workflow_call' for reusable workflows
            has_trigger = (
                "on" in workflow or True in workflow
            )  # True key indicates workflow_call
            assert (
                has_trigger
            ), f"Workflow {workflow_file} missing trigger ('on' or 'workflow_call')"
            assert "jobs" in workflow, f"Workflow {workflow_file} missing 'jobs'"

            # Check jobs structure
            jobs = workflow["jobs"]
            assert isinstance(jobs, dict), "Jobs should be a dictionary"
            assert len(jobs) > 0, "Workflow should have at least one job"

            for job_name, job_config in jobs.items():
                assert "runs-on" in job_config, f"Job {job_name} missing 'runs-on'"
                assert "steps" in job_config, f"Job {job_name} missing 'steps'"


class TestGitIntegration:
    """Test Git repository and branch management."""

    def test_git_repository_status(self):
        """Test that we're in a valid git repository."""
        result = subprocess.run(
            ["git", "status", "--porcelain"],
            capture_output=True,
            text=True,
            cwd="/Users/danielstevens/Desktop/Code",
        )

        assert result.returncode == 0, f"Git status failed: {result.stderr}"

    def test_git_branches(self):
        """Test that repository has expected branch structure."""
        result = subprocess.run(
            ["git", "branch", "-a"],
            capture_output=True,
            text=True,
            cwd="/Users/danielstevens/Desktop/Code",
        )

        assert result.returncode == 0, f"Git branch failed: {result.stderr}"
        # Should have at least main/master branch
        assert "main" in result.stdout or "master" in result.stdout

    def test_git_remotes(self):
        """Test that git remotes are configured."""
        result = subprocess.run(
            ["git", "remote", "-v"],
            capture_output=True,
            text=True,
            cwd="/Users/danielstevens/Desktop/Code",
        )

        assert result.returncode == 0, f"Git remote failed: {result.stderr}"
        # Should have at least one remote (typically origin)
        assert result.stdout.strip(), "No git remotes configured"


class TestDeploymentScripts:
    """Test deployment and release scripts."""

    def test_create_ci_compatible_script(self):
        """Test HabitQuest's CI-compatible project creation script."""
        script_path = Path(
            "/Users/danielstevens/Desktop/Quantum-workspace/Projects/HabitQuest/create_ci_compatible_project.sh"
        )

        if not script_path.exists():
            pytest.skip("CI-compatible script not found")

        # Test script exists and is executable
        assert script_path.exists()
        assert os.access(script_path, os.X_OK), "Script is not executable"

        # Test script runs without critical errors (don't actually create project)
        result = subprocess.run(
            ["bash", str(script_path), "--help"],
            capture_output=True,
            text=True,
            cwd="/Users/danielstevens/Desktop/Quantum-workspace/Projects/HabitQuest",
        )

        # Script should handle --help or show usage
        assert result.returncode in [0, 1, 2], f"Script failed: {result.stderr}"


class TestQualityGates:
    """Test code quality and testing gates."""

    def test_quality_config_exists(self):
        """Test that quality configuration files exist."""
        quality_config = Path(
            "/Users/danielstevens/Desktop/Quantum-workspace/Tools/quality-config.yaml"
        )

        if not quality_config.exists():
            pytest.skip("Quality config not found")

        assert quality_config.exists()

        # Test YAML is valid
        with open(quality_config, "r") as f:
            try:
                config = yaml.safe_load(f)
                assert isinstance(config, dict), "Quality config should be a dictionary"
            except yaml.YAMLError as e:
                pytest.fail(f"Invalid YAML in quality config: {e}")

    def test_cspell_config_exists(self):
        """Test that cspell configuration exists."""
        cspell_configs = [
            Path("/Users/danielstevens/Desktop/Quantum-workspace/Projects/cspell.json"),
            Path("/Users/danielstevens/Desktop/Quantum-workspace/Shared/cspell.json"),
            Path("/Users/danielstevens/Desktop/Quantum-workspace/Tools/cspell.json"),
            Path(
                "/Users/danielstevens/Desktop/Quantum-workspace/Documentation/cspell.json"
            ),
        ]

        found_configs = [config for config in cspell_configs if config.exists()]
        assert len(found_configs) > 0, "No cspell configurations found"

        # Test at least one config is valid JSON
        for config in found_configs:
            with open(config, "r") as f:
                import json

                try:
                    json.load(f)
                except json.JSONDecodeError as e:
                    pytest.fail(f"Invalid JSON in {config}: {e}")


class TestMonitoringAndLogging:
    """Test monitoring and logging systems."""

    def test_monitoring_dashboard_exists(self):
        """Test that monitoring dashboard exists."""
        dashboard = Path(
            "/Users/danielstevens/Desktop/Quantum-workspace/Tools/monitoring-dashboard.html"
        )

        if not dashboard.exists():
            pytest.skip("Monitoring dashboard not found")

        assert dashboard.exists()
        assert dashboard.stat().st_size > 0, "Monitoring dashboard is empty"

        # Check it's an HTML file
        with open(dashboard, "r") as f:
            content = f.read()
            assert "<html" in content.lower(), "Dashboard doesn't appear to be HTML"

    def test_log_files_exist(self):
        """Test that log files exist for quantum agents."""
        log_files = [
            "quantum_agent__Users_danielstevens_Desktop_Quantum-workspace_Projects_AvoidObstaclesGame.log",
            "quantum_agent__Users_danielstevens_Desktop_Quantum-workspace_Projects_CodingReviewer.log",
            "quantum_agent__Users_danielstevens_Desktop_Quantum-workspace_Projects_HabitQuest.log",
            "quantum_agent__Users_danielstevens_Desktop_Quantum-workspace_Projects_MomentumFinance.log",
        ]

        tools_dir = Path("/Users/danielstevens/Desktop/Quantum-workspace/Tools")
        found_logs = [
            tools_dir / log for log in log_files if (tools_dir / log).exists()
        ]

        # At least some logs should exist
        assert len(found_logs) > 0, "No quantum agent log files found"

        # Check logs are not empty
        for log_file in found_logs:
            assert log_file.stat().st_size > 0, f"Log file {log_file.name} is empty"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
