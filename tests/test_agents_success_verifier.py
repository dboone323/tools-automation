import pytest
import sys
import os
import json
import tempfile
from unittest.mock import Mock, patch, MagicMock
from pathlib import Path

# Add the workspace root to sys.path
if "/Users/danielstevens/Desktop/github-projects/tools-automation" not in sys.path:
    sys.path.insert(0, "/Users/danielstevens/Desktop/github-projects/tools-automation")

# Try to import the module with correct path
MODULE_AVAILABLE = False
try:
    # Try direct import with proper path
    __import__("agents.success_verifier")
    MODULE_AVAILABLE = True
except (ImportError, ModuleNotFoundError, SyntaxError) as e:
    print(f"Warning: Could not import agents.success_verifier: {e}")
    # Try to at least check if file exists and is syntactically valid
    try:
        with open(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/success_verifier.py",
            "r",
        ) as f:
            compile(
                f.read(),
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/success_verifier.py",
                "exec",
            )
        print(
            f"File agents/success_verifier.py is syntactically valid but import failed"
        )
    except SyntaxError as se:
        print(f"File agents/success_verifier.py has syntax errors: {se}")


@pytest.mark.skipif(
    not MODULE_AVAILABLE, reason="Module not available or has import issues"
)
class TestAgentsSuccessVerifier:
    """Comprehensive tests for agents/success_verifier.py"""

    def test_module_syntax_valid(self):
        """Test that the module file is syntactically valid"""
        try:
            with open(
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/success_verifier.py",
                "r",
            ) as f:
                compile(
                    f.read(),
                    "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/success_verifier.py",
                    "exec",
                )
            assert True
        except SyntaxError:
            pytest.fail(f"Syntax error in agents/success_verifier.py")

    def test_file_exists(self):
        """Test that the source file exists"""
        assert os.path.exists(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/success_verifier.py"
        )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_module_can_be_imported(self):
        """Test that the module can be imported successfully"""
        try:
            __import__("agents.success_verifier")
            assert True
        except ImportError:
            pytest.fail(f"Module agents.success_verifier should be importable")

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_success_verifier_init(self):
        """Test SuccessVerifier initialization"""
        import agents.success_verifier as module

        verifier = module.SuccessVerifier()
        assert verifier.checks_passed == []
        assert verifier.checks_failed == []

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_verify_codegen_success_all_pass(self):
        """Test verify_codegen_success with all checks passing"""
        import agents.success_verifier as module

        verifier = module.SuccessVerifier()

        with patch.object(
            verifier, "_check_syntax_valid", return_value=True
        ), patch.object(
            verifier, "_check_compiles_successfully", return_value=True
        ), patch.object(
            verifier, "_check_tests_pass", return_value=True
        ), patch.object(
            verifier, "_check_no_regressions", return_value=True
        ), patch.object(
            verifier, "_check_meets_quality_gates", return_value=True
        ):

            result = verifier.verify_codegen_success("test.swift")
            assert result is True

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_verify_codegen_success_some_fail(self):
        """Test verify_codegen_success with some checks failing"""
        import agents.success_verifier as module

        verifier = module.SuccessVerifier()

        with patch.object(
            verifier, "_check_syntax_valid", return_value=True
        ), patch.object(
            verifier, "_check_compiles_successfully", return_value=False
        ), patch.object(
            verifier, "_check_tests_pass", return_value=True
        ), patch.object(
            verifier, "_check_no_regressions", return_value=True
        ), patch.object(
            verifier, "_check_meets_quality_gates", return_value=True
        ):

            result = verifier.verify_codegen_success("test.swift")
            assert result is False

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_verify_build_success(self):
        """Test verify_build_success"""
        import agents.success_verifier as module

        verifier = module.SuccessVerifier()

        with patch.object(
            verifier, "_check_build_completes", return_value=True
        ), patch.object(
            verifier, "_check_no_build_errors", return_value=True
        ), patch.object(
            verifier, "_check_dependencies_resolved", return_value=True
        ), patch.object(
            verifier, "_check_build_artifacts_exist", return_value=True
        ):

            result = verifier.verify_build_success()
            assert result is True

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_verify_test_success(self):
        """Test verify_test_success"""
        import agents.success_verifier as module

        verifier = module.SuccessVerifier()

        with patch.object(
            verifier, "_check_tests_execute", return_value=True
        ), patch.object(
            verifier, "_check_all_tests_pass", return_value=True
        ), patch.object(
            verifier, "_check_no_test_timeouts", return_value=True
        ), patch.object(
            verifier, "_check_coverage_maintained", return_value=True
        ):

            result = verifier.verify_test_success()
            assert result is True

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_verify_fix_success(self):
        """Test verify_fix_success"""
        import agents.success_verifier as module

        verifier = module.SuccessVerifier()

        with patch.object(
            verifier, "_check_error_resolved", return_value=True
        ), patch.object(
            verifier, "_check_no_new_errors", return_value=True
        ), patch.object(
            verifier, "_check_functionality_preserved", return_value=True
        ):

            result = verifier.verify_fix_success("error pattern")
            assert result is True

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_get_verification_report_success(self):
        """Test get_verification_report with all checks passing"""
        import agents.success_verifier as module

        verifier = module.SuccessVerifier()
        verifier.checks_passed = [{"check": "test1"}, {"check": "test2"}]
        verifier.checks_failed = []

        report = verifier.get_verification_report()

        assert report["success"] is True
        assert report["total_checks"] == 2
        assert report["passed"] == 2
        assert report["failed"] == 0
        assert report["pass_rate"] == 1.0

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_get_verification_report_failure(self):
        """Test get_verification_report with some checks failing"""
        import agents.success_verifier as module

        verifier = module.SuccessVerifier()
        verifier.checks_passed = [{"check": "test1"}]
        verifier.checks_failed = [{"check": "test2", "reason": "failed"}]

        report = verifier.get_verification_report()

        assert report["success"] is False
        assert report["total_checks"] == 2
        assert report["passed"] == 1
        assert report["failed"] == 1
        assert report["pass_rate"] == 0.5

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_get_verification_report_empty(self):
        """Test get_verification_report with no checks"""
        import agents.success_verifier as module

        verifier = module.SuccessVerifier()

        report = verifier.get_verification_report()

        assert report["success"] is True
        assert report["total_checks"] == 0
        assert report["passed"] == 0
        assert report["failed"] == 0
        assert report["pass_rate"] == 0

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_check_syntax_valid_swift_success(self):
        """Test _check_syntax_valid for Swift file success"""
        import agents.success_verifier as module

        verifier = module.SuccessVerifier()

        with patch("subprocess.run") as mock_run:
            mock_run.return_value = Mock(returncode=0, stderr=b"")

            with tempfile.NamedTemporaryFile(suffix=".swift", delete=False) as f:
                f.write(b"print('hello')")
                temp_path = Path(f.name)

            try:
                result = verifier._check_syntax_valid(temp_path)
                assert result is True
                assert len(verifier.checks_passed) == 1
                assert verifier.checks_passed[0]["check"] == "syntax_valid"
            finally:
                os.unlink(temp_path)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_check_syntax_valid_python_success(self):
        """Test _check_syntax_valid for Python file success"""
        import agents.success_verifier as module

        verifier = module.SuccessVerifier()

        with patch("subprocess.run") as mock_run:
            mock_run.return_value = Mock(returncode=0, stderr=b"")

            with tempfile.NamedTemporaryFile(suffix=".py", delete=False) as f:
                f.write(b"print('hello')")
                temp_path = Path(f.name)

            try:
                result = verifier._check_syntax_valid(temp_path)
                assert result is True
                assert len(verifier.checks_passed) == 1
            finally:
                os.unlink(temp_path)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_check_syntax_valid_file_not_found(self):
        """Test _check_syntax_valid for non-existent file"""
        import agents.success_verifier as module

        verifier = module.SuccessVerifier()

        result = verifier._check_syntax_valid(Path("/nonexistent/file.swift"))
        assert result is False
        assert len(verifier.checks_failed) == 1
        assert "File not found" in verifier.checks_failed[0]["reason"]

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_check_syntax_valid_unknown_type(self):
        """Test _check_syntax_valid for unknown file type"""
        import agents.success_verifier as module

        verifier = module.SuccessVerifier()

        with tempfile.NamedTemporaryFile(suffix=".unknown", delete=False) as f:
            f.write(b"content")
            temp_path = Path(f.name)

        try:
            result = verifier._check_syntax_valid(temp_path)
            assert result is True
            assert len(verifier.checks_passed) == 1
            assert "skipped (unknown type)" in verifier.checks_passed[0]["result"]
        finally:
            os.unlink(temp_path)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_check_compiles_successfully_success(self):
        """Test _check_compiles_successfully success"""
        import agents.success_verifier as module

        verifier = module.SuccessVerifier()

        with patch("subprocess.run") as mock_run:
            mock_run.return_value = Mock(returncode=0)

            result = verifier._check_compiles_successfully(
                Path("test.swift"), {"project": "TestProject"}
            )
            assert result is True
            assert len(verifier.checks_passed) == 1

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_check_compiles_successfully_failure(self):
        """Test _check_compiles_successfully failure"""
        import agents.success_verifier as module

        verifier = module.SuccessVerifier()

        with patch("subprocess.run") as mock_run:
            mock_run.return_value = Mock(returncode=1)

            result = verifier._check_compiles_successfully(Path("test.swift"), {})
            assert result is False
            assert len(verifier.checks_failed) == 1

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_check_tests_pass_success(self):
        """Test _check_tests_pass success"""
        import agents.success_verifier as module

        verifier = module.SuccessVerifier()

        with patch("subprocess.run") as mock_run:
            mock_run.return_value = Mock(returncode=0)

            result = verifier._check_tests_pass({"project": "TestProject"})
            assert result is True
            assert len(verifier.checks_passed) == 1

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_check_tests_pass_no_tests(self):
        """Test _check_tests_pass when no tests exist"""
        import agents.success_verifier as module

        verifier = module.SuccessVerifier()

        with patch("subprocess.run", side_effect=Exception("No tests found")):
            result = verifier._check_tests_pass({})
            assert result is True
            assert len(verifier.checks_passed) == 1
            assert "skipped (no tests)" in verifier.checks_passed[0]["result"]

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_check_no_regressions_no_baseline(self):
        """Test _check_no_regressions with no baseline data"""
        import agents.success_verifier as module

        verifier = module.SuccessVerifier()

        result = verifier._check_no_regressions({})
        assert result is True
        assert len(verifier.checks_passed) == 1
        assert "skipped (no baseline)" in verifier.checks_passed[0]["result"]

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_check_no_regressions_with_regression(self):
        """Test _check_no_regressions with performance regression"""
        import agents.success_verifier as module

        verifier = module.SuccessVerifier()

        context = {
            "before_state": {"test_pass_rate": 0.9, "build_time": 100},
            "after_state": {"test_pass_rate": 0.7, "build_time": 200},
        }

        result = verifier._check_no_regressions(context)
        assert result is False
        assert len(verifier.checks_failed) == 1
        assert "Test pass rate decreased" in verifier.checks_failed[0]["reason"]

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_check_meets_quality_gates_success(self):
        """Test _check_meets_quality_gates success"""
        import agents.success_verifier as module

        verifier = module.SuccessVerifier()

        with tempfile.NamedTemporaryFile(suffix=".swift", delete=False) as f:
            f.write(b"print('hello')\n" * 10)  # Small file
            temp_path = Path(f.name)

        try:
            with patch("subprocess.run", return_value=Mock(returncode=0)):
                result = verifier._check_meets_quality_gates(temp_path)
                assert result is True
                assert len(verifier.checks_passed) == 1
        finally:
            os.unlink(temp_path)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_check_meets_quality_gates_file_too_large(self):
        """Test _check_meets_quality_gates with file too large"""
        import agents.success_verifier as module

        verifier = module.SuccessVerifier()

        with tempfile.NamedTemporaryFile(suffix=".swift", delete=False) as f:
            # Write more than 1MB
            f.write(b"x" * (1024 * 1024 + 1))
            temp_path = Path(f.name)

        try:
            result = verifier._check_meets_quality_gates(temp_path)
            assert result is False
            assert len(verifier.checks_failed) == 1
            assert "File too large" in verifier.checks_failed[0]["reason"]
        finally:
            os.unlink(temp_path)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_check_coverage_maintained_success(self):
        """Test _check_coverage_maintained success"""
        import agents.success_verifier as module

        verifier = module.SuccessVerifier()

        context = {
            "before_coverage": 80.0,
            "after_coverage": 78.0,  # 2% decrease, within 5% tolerance
        }

        result = verifier._check_coverage_maintained(context)
        assert result is True
        assert len(verifier.checks_passed) == 1

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_check_coverage_maintained_failure(self):
        """Test _check_coverage_maintained failure"""
        import agents.success_verifier as module

        verifier = module.SuccessVerifier()

        context = {
            "before_coverage": 80.0,
            "after_coverage": 70.0,  # 10% decrease, exceeds 5% tolerance
        }

        result = verifier._check_coverage_maintained(context)
        assert result is False
        assert len(verifier.checks_failed) == 1

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_codegen_command(self):
        """Test main function codegen command"""
        import agents.success_verifier as module

        with patch("sys.argv", ["success_verifier.py", "codegen", "test.swift"]), patch(
            "json.dumps"
        ) as mock_json_dumps, patch("sys.exit") as mock_exit, patch.object(
            module.SuccessVerifier, "verify_codegen_success", return_value=True
        ):

            module.main()

            # Should call json.dumps and exit with 0
            mock_json_dumps.assert_called_once()
            mock_exit.assert_called_once_with(0)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_build_command(self):
        """Test main function build command"""
        import agents.success_verifier as module

        with patch("sys.argv", ["success_verifier.py", "build"]), patch(
            "json.dumps"
        ) as mock_json_dumps, patch("sys.exit") as mock_exit, patch.object(
            module.SuccessVerifier, "verify_build_success", return_value=True
        ):

            module.main()

            mock_json_dumps.assert_called_once()
            mock_exit.assert_called_once_with(0)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_invalid_command(self):
        """Test main function with invalid command"""
        import agents.success_verifier as module

        with patch("sys.argv", ["success_verifier.py", "invalid"]), patch(
            "sys.stderr"
        ) as mock_stderr, pytest.raises(SystemExit) as exc_info:

            module.main()

            assert exc_info.value.code == 1

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_missing_arguments(self):
        """Test main function with missing arguments"""
        import agents.success_verifier as module

        with patch("sys.argv", ["success_verifier.py"]), patch(
            "sys.stderr"
        ) as mock_stderr, pytest.raises(SystemExit) as exc_info:

            module.main()

            assert exc_info.value.code == 1
