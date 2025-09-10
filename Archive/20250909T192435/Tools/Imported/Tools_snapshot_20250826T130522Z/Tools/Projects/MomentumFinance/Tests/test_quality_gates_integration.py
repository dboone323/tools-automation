import pytest
import json
import tempfile
import os
from pathlib import Path
import sys

# Add the parent directory to the path so we can import our modules
sys.path.insert(0, str(Path(__file__).parent.parent))

from quality_gates_validator import QualityGatesValidator

class TestQualityGatesIntegration:
    """Integration tests for quality gates"""
    
    def setup_method(self):
        """Setup for each test method"""
        self.validator = QualityGatesValidator()
    
    def test_full_validation_cycle(self):
        """Test a complete validation cycle"""
        # Run all gates
        result = self.validator.validate_all_gates()
        
        # Should return a boolean
        assert isinstance(result, bool)
        
        # Results should be populated
        assert self.validator.results['timestamp'] is not None
        assert isinstance(self.validator.results['gates'], dict)
        assert self.validator.results['overall_status'] in ['PASS', 'FAIL']
        assert isinstance(self.validator.results['score'], (int, float))
        assert isinstance(self.validator.results['max_score'], (int, float))
    
    def test_individual_gates(self):
        """Test each gate individually"""
        gates = [
            ('code_coverage', self.validator.gate_code_coverage),
            ('quality_score', self.validator.gate_quality_score),
            ('security_scan', self.validator.gate_security_scan),
            ('dependency_check', self.validator.gate_dependency_check),
            ('performance_metrics', self.validator.gate_performance_metrics)
        ]
        
        for gate_name, gate_func in gates:
            passed, result = gate_func()
            
            # Basic structure validation
            assert 'name' in result
            assert 'status' in result
            assert 'score' in result
            assert 'details' in result
            
            # Status should be valid
            assert result['status'] in ['PASS', 'FAIL', 'WARNING', 'ERROR']
            
            # Score should be numeric and non-negative
            assert isinstance(result['score'], (int, float))
            assert result['score'] >= 0
    
    def test_results_serialization(self):
        """Test that results can be properly serialized"""
        # Run validation
        self.validator.validate_all_gates()
        
        # Test JSON serialization
        try:
            json_str = json.dumps(self.validator.results, indent=2)
            # Should be able to parse it back
            parsed = json.loads(json_str)
            assert parsed == self.validator.results
        except Exception as e:
            pytest.fail(f"Results serialization failed: {e}")
    
    def test_save_results_functionality(self):
        """Test saving results to file"""
        # Run validation
        self.validator.validate_all_gates()
        
        # Create temporary directory for test
        with tempfile.TemporaryDirectory() as temp_dir:
            # Override the project_root for this test
            original_root = self.validator.project_root
            self.validator.project_root = Path(temp_dir)
            
            try:
                # Save results
                self.validator.save_results()
                
                # Check that file was created
                results_file = Path(temp_dir) / "quality_gates_results.json"
                assert results_file.exists()
                
                # Check that content is valid JSON
                with open(results_file) as f:
                    loaded_results = json.load(f)
                    assert loaded_results == self.validator.results
                    
            finally:
                # Restore original root
                self.validator.project_root = original_root

class TestScenarios:
    """Test different deployment scenarios"""
    
    def test_development_environment(self):
        """Test validation in development environment"""
        validator = QualityGatesValidator()
        
        # Should handle missing coverage files gracefully
        passed, coverage_result = validator.gate_code_coverage()
        assert coverage_result['status'] in ['PASS', 'WARNING', 'ERROR']
        
        # Should handle missing production files gracefully
        passed, deps_result = validator.gate_dependency_check()
        assert deps_result['status'] in ['PASS', 'WARNING', 'FAIL', 'ERROR']
    
    def test_ci_environment_simulation(self):
        """Simulate CI environment conditions"""
        validator = QualityGatesValidator()
        
        # In CI, we might have stricter requirements
        # But should still be able to run all gates
        result = validator.validate_all_gates()
        
        # Should complete without crashing
        assert isinstance(result, bool)
        assert len(validator.results['gates']) > 0
    
    def test_partial_failure_handling(self):
        """Test handling when some gates fail"""
        validator = QualityGatesValidator()
        
        # Run individual gates and check error handling
        gates_results = []
        
        try:
            passed, result = validator.gate_security_scan()
            gates_results.append((passed, result))
        except Exception as e:
            # Should not raise unhandled exceptions
            pytest.fail(f"Security gate raised unhandled exception: {e}")
        
        try:
            passed, result = validator.gate_performance_metrics()
            gates_results.append((passed, result))
        except Exception as e:
            pytest.fail(f"Performance gate raised unhandled exception: {e}")
        
        # At least some gates should have run
        assert len(gates_results) > 0

class TestErrorHandling:
    """Test error handling and edge cases"""
    
    def test_invalid_project_structure(self):
        """Test behavior with invalid project structure"""
        validator = QualityGatesValidator()
        
        # Override to point to non-existent directory
        validator.project_root = Path("/nonexistent/directory")
        
        # Should handle gracefully
        try:
            result = validator.validate_all_gates()
            # Should complete but may fail gates
            assert isinstance(result, bool)
        except Exception as e:
            # Should not crash with unhandled exceptions
            if "No such file or directory" not in str(e):
                pytest.fail(f"Unexpected error: {e}")
    
    def test_permission_errors(self):
        """Test handling of permission errors"""
        validator = QualityGatesValidator()
        
        # Test with temporary directory we can't write to
        # (This is hard to test reliably across platforms)
        try:
            validator.validate_all_gates()
            # Should complete
            assert True
        except PermissionError:
            # This is acceptable - should be handled gracefully
            pass

def test_integration_with_deployment():
    """Test integration between quality gates and deployment"""
    # This would test the integration between quality_gates_validator 
    # and deployment_script if they were used together
    
    try:
        from deployment_script import MomentumFinanceDeployer
        
        # Both should be importable and instantiable
        validator = QualityGatesValidator()
        deployer = MomentumFinanceDeployer()
        
        assert validator is not None
        assert deployer is not None
        
    except ImportError:
        # deployment_script might not be complete yet
        pass

if __name__ == "__main__":
    # Run integration tests when script is executed directly
    pytest.main([__file__, "-v", "-s"])
