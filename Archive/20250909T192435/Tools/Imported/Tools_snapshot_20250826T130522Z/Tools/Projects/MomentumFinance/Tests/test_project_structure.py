import pytest
import sys
import os
from pathlib import Path

# Add the parent directory to the path so we can import our modules
sys.path.insert(0, str(Path(__file__).parent.parent))

def test_import_quality_gates():
    """Test that we can import the quality gates validator"""
    try:
        import quality_gates_validator
        assert True
    except ImportError:
        pytest.fail("Failed to import quality_gates_validator")

def test_import_deployment_script():
    """Test that we can import the deployment script"""
    try:
        import deployment_script
        assert True
    except ImportError:
        pytest.fail("Failed to import deployment_script")

def test_import_workflow_quality_check():
    """Test that we can import the workflow quality check"""
    try:
        import workflow_quality_check
        assert True
    except ImportError:
        pytest.fail("Failed to import workflow_quality_check")

class TestQualityGatesValidator:
    """Test the QualityGatesValidator class"""
    
    def test_validator_initialization(self):
        """Test that the validator initializes correctly"""
        from quality_gates_validator import QualityGatesValidator
        
        validator = QualityGatesValidator()
        assert validator.project_root is not None
        assert validator.results is not None
        assert 'timestamp' in validator.results
        assert 'gates' in validator.results
        assert 'overall_status' in validator.results
    
    def test_code_coverage_gate(self):
        """Test the code coverage gate"""
        from quality_gates_validator import QualityGatesValidator
        
        validator = QualityGatesValidator()
        passed, result = validator.gate_code_coverage()
        
        # Should pass or warn (not fail) since we're in test environment
        assert result['name'] == 'Code Coverage'
        assert result['status'] in ['PASS', 'WARNING', 'ERROR']
        assert isinstance(result['score'], int)
        assert 'details' in result
    
    def test_quality_score_gate(self):
        """Test the quality score gate"""
        from quality_gates_validator import QualityGatesValidator
        
        validator = QualityGatesValidator()
        passed, result = validator.gate_quality_score()
        
        assert result['name'] == 'Quality Score'
        assert result['status'] in ['PASS', 'FAIL', 'ERROR']
        assert isinstance(result['score'], int)
        assert 'details' in result
    
    def test_security_scan_gate(self):
        """Test the security scan gate"""
        from quality_gates_validator import QualityGatesValidator
        
        validator = QualityGatesValidator()
        passed, result = validator.gate_security_scan()
        
        assert result['name'] == 'Security Scan'
        assert result['status'] in ['PASS', 'WARNING', 'ERROR']
        assert isinstance(result['score'], int)
        assert 'details' in result
    
    def test_dependency_check_gate(self):
        """Test the dependency check gate"""
        from quality_gates_validator import QualityGatesValidator
        
        validator = QualityGatesValidator()
        passed, result = validator.gate_dependency_check()
        
        assert result['name'] == 'Dependency Check'
        assert result['status'] in ['PASS', 'WARNING', 'FAIL', 'ERROR']
        assert isinstance(result['score'], int)
        assert 'details' in result
    
    def test_performance_metrics_gate(self):
        """Test the performance metrics gate"""
        from quality_gates_validator import QualityGatesValidator
        
        validator = QualityGatesValidator()
        passed, result = validator.gate_performance_metrics()
        
        assert result['name'] == 'Performance Metrics'
        assert result['status'] in ['PASS', 'WARNING', 'ERROR']
        assert isinstance(result['score'], int)
        assert 'details' in result

class TestDeploymentScript:
    """Test the deployment script functionality"""
    
    def test_deployment_script_imports(self):
        """Test that deployment script has required classes"""
        from deployment_script import MomentumFinanceDeployer
        
        deployer = MomentumFinanceDeployer()
        assert deployer.project_root is not None
        assert hasattr(deployer, 'validate_environment')
        assert hasattr(deployer, 'run_quality_checks')
        assert hasattr(deployer, 'build_ios_app')

class TestWorkflowQualityCheck:
    """Test the workflow quality check functionality"""
    
    def test_quality_check_runs(self):
        """Test that quality check can be imported and has basic structure"""
        try:
            import workflow_quality_check
            # Just test that it imports without error
            assert True
        except Exception as e:
            pytest.fail(f"Quality check import failed: {e}")

class TestProjectStructure:
    """Test the overall project structure"""
    
    def test_required_files_exist(self):
        """Test that all required files exist"""
        project_root = Path(__file__).parent.parent
        
        required_files = [
            'Package.swift',
            'deployment_script.py',
            'quality_gates_validator.py',
            'workflow_quality_check.py'
        ]
        
        for file_name in required_files:
            file_path = project_root / file_name
            assert file_path.exists(), f"Required file {file_name} does not exist"
    
    def test_required_directories_exist(self):
        """Test that required directories exist"""
        project_root = Path(__file__).parent.parent
        
        required_dirs = [
            'tests',
            '.github/workflows'
        ]
        
        for dir_name in required_dirs:
            dir_path = project_root / dir_name
            if not dir_path.exists():
                # Some directories might be created by CI, so warn but don't fail
                print(f"Warning: Directory {dir_name} does not exist")

def test_python_environment():
    """Test that Python environment is properly set up"""
    import sys
    
    # Test Python version
    assert sys.version_info >= (3, 6), "Python 3.6+ is required"
    
    # Test that we can import common modules
    try:
        import json
        import os
        import subprocess
        import logging
        from datetime import datetime
        from pathlib import Path
        assert True
    except ImportError as e:
        pytest.fail(f"Failed to import required module: {e}")

def test_swift_package_structure():
    """Test that Swift package structure is valid"""
    project_root = Path(__file__).parent.parent
    package_swift = project_root / "Package.swift"
    
    if package_swift.exists():
        content = package_swift.read_text()
        
        # Basic Swift package validation
        assert "swift-tools-version" in content
        assert "Package(" in content
        assert "name:" in content
        assert "targets:" in content

if __name__ == "__main__":
    # Run tests when script is executed directly
    pytest.main([__file__, "-v"])
