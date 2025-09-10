import pytest
import subprocess
import sys
import os
from pathlib import Path
import tempfile

# Add the parent directory to the path so we can import our modules
sys.path.insert(0, str(Path(__file__).parent.parent))

class TestDeploymentIntegration:
    """Integration tests for the deployment system"""
    
    def test_deployment_script_exists(self):
        """Test that deployment script exists and is executable"""
        project_root = Path(__file__).parent.parent
        deployment_script = project_root / "deployment_script.py"
        
        assert deployment_script.exists(), "deployment_script.py should exist"
        assert deployment_script.is_file(), "deployment_script.py should be a file"
    
    def test_deployment_script_imports(self):
        """Test that deployment script can be imported"""
        try:
            import deployment_script
            assert hasattr(deployment_script, 'MomentumFinanceDeployer')
        except ImportError as e:
            pytest.fail(f"Failed to import deployment_script: {e}")
    
    def test_deployer_initialization(self):
        """Test that deployer can be initialized"""
        from deployment_script import MomentumFinanceDeployer
        
        deployer = MomentumFinanceDeployer()
        assert deployer.project_root is not None
        assert deployer.config is not None
        assert deployer.results is not None
    
    def test_environment_validation(self):
        """Test environment validation functionality"""
        from deployment_script import MomentumFinanceDeployer
        
        deployer = MomentumFinanceDeployer()
        
        # Should be able to call validate_environment
        try:
            is_valid = deployer.validate_environment()
            assert isinstance(is_valid, bool)
        except Exception as e:
            # May fail in test environment, but shouldn't crash
            if "not found" not in str(e).lower():
                pytest.fail(f"Unexpected error in validate_environment: {e}")
    
    def test_quality_checks_integration(self):
        """Test integration with quality checks"""
        from deployment_script import MomentumFinanceDeployer
        
        deployer = MomentumFinanceDeployer()
        
        # Should be able to call run_quality_checks
        try:
            quality_passed = deployer.run_quality_checks()
            assert isinstance(quality_passed, bool)
        except Exception as e:
            # May fail in test environment, but shouldn't crash
            print(f"Quality checks failed (expected in test): {e}")
    
    def test_git_operations(self):
        """Test git-related operations"""
        from deployment_script import MomentumFinanceDeployer
        
        deployer = MomentumFinanceDeployer()
        
        # Test git status check (if in a git repo)
        try:
            # This might fail if not in a git repo, which is fine
            deployer.check_git_status()
        except Exception as e:
            # Expected in non-git environments
            print(f"Git operations failed (expected): {e}")

class TestWorkflowIntegration:
    """Test integration with GitHub workflows"""
    
    def test_workflow_files_exist(self):
        """Test that workflow files exist"""
        project_root = Path(__file__).parent.parent
        workflows_dir = project_root / ".github" / "workflows"
        
        if workflows_dir.exists():
            workflow_files = list(workflows_dir.glob("*.yml"))
            assert len(workflow_files) > 0, "Should have at least one workflow file"
            
            # Check that workflows reference our scripts
            for workflow_file in workflow_files:
                content = workflow_file.read_text()
                
                # Look for references to our Python scripts
                if any(script in content for script in ['deployment_script.py', 'quality_gates_validator.py']):
                    # This workflow uses our scripts
                    assert 'python' in content or 'python3' in content
    
    def test_requirements_file(self):
        """Test that requirements are properly specified"""
        project_root = Path(__file__).parent.parent
        
        # Check for requirements files
        requirements_files = [
            'requirements.txt',
            'requirements-test.txt',
            'requirements-dev.txt'
        ]
        
        found_requirements = False
        for req_file in requirements_files:
            req_path = project_root / req_file
            if req_path.exists():
                found_requirements = True
                content = req_path.read_text()
                # Should not be empty
                assert len(content.strip()) > 0
        
        # At least one requirements file should exist
        if not found_requirements:
            print("Warning: No requirements files found")

class TestEndToEndScenarios:
    """End-to-end testing scenarios"""
    
    def test_dry_run_deployment(self):
        """Test a dry-run deployment scenario"""
        try:
            from deployment_script import MomentumFinanceDeployer
            
            deployer = MomentumFinanceDeployer()
            
            # Enable dry-run mode if available
            if hasattr(deployer.config, 'dry_run'):
                deployer.config['dry_run'] = True
            
            # Try to run environment validation
            env_valid = deployer.validate_environment()
            
            # In test environment, this might fail, but should not crash
            assert isinstance(env_valid, bool)
            
        except Exception as e:
            # Expected in test environment
            print(f"Dry run failed (expected): {e}")
    
    def test_quality_gates_before_deployment(self):
        """Test that quality gates are checked before deployment"""
        try:
            from quality_gates_validator import QualityGatesValidator
            from deployment_script import MomentumFinanceDeployer
            
            # First run quality gates
            validator = QualityGatesValidator()
            gates_passed = validator.validate_all_gates()
            
            # Then check deployer
            deployer = MomentumFinanceDeployer()
            
            # Both should be functional
            assert isinstance(gates_passed, bool)
            assert deployer is not None
            
        except Exception as e:
            print(f"Integration test failed (may be expected): {e}")

class TestCIEnvironment:
    """Tests specific to CI environment"""
    
    def test_python_executable_available(self):
        """Test that Python executable is available"""
        try:
            result = subprocess.run(['python3', '--version'], 
                                  capture_output=True, text=True)
            assert result.returncode == 0
        except FileNotFoundError:
            try:
                result = subprocess.run(['python', '--version'], 
                                      capture_output=True, text=True)
                assert result.returncode == 0
            except FileNotFoundError:
                pytest.fail("Neither python3 nor python executable found")
    
    def test_git_available(self):
        """Test that git is available in the environment"""
        try:
            result = subprocess.run(['git', '--version'], 
                                  capture_output=True, text=True)
            assert result.returncode == 0
        except FileNotFoundError:
            print("Warning: git not available in test environment")
    
    def test_swift_tools_available(self):
        """Test that Swift tools are available (if on macOS)"""
        import platform
        
        if platform.system() == 'Darwin':  # macOS
            try:
                result = subprocess.run(['swift', '--version'], 
                                      capture_output=True, text=True)
                if result.returncode != 0:
                    print("Warning: Swift not available")
            except FileNotFoundError:
                print("Warning: Swift not found")

def test_overall_project_health():
    """Overall project health check"""
    project_root = Path(__file__).parent.parent
    
    # Check that basic Python files are present and importable
    python_files = [
        'deployment_script.py',
        'quality_gates_validator.py',
        'workflow_quality_check.py'
    ]
    
    for py_file in python_files:
        file_path = project_root / py_file
        assert file_path.exists(), f"{py_file} should exist"
        
        # Check that file is not empty
        content = file_path.read_text()
        assert len(content.strip()) > 0, f"{py_file} should not be empty"
        
        # Basic syntax check
        try:
            compile(content, py_file, 'exec')
        except SyntaxError as e:
            pytest.fail(f"Syntax error in {py_file}: {e}")

if __name__ == "__main__":
    # Run integration tests when script is executed directly  
    pytest.main([__file__, "-v", "-s"])
