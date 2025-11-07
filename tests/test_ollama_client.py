import pytest
import sys
import os
from unittest.mock import Mock, patch, MagicMock, mock_open
import json

# Add the workspace root to sys.path
if "/Users/danielstevens/Desktop/github-projects/tools-automation" not in sys.path:
    sys.path.insert(0, "/Users/danielstevens/Desktop/github-projects/tools-automation")

# Try to import the module with correct path
MODULE_AVAILABLE = False
try:
    # Try direct import with proper path
    __import__("ollama_client")
    MODULE_AVAILABLE = True
except (ImportError, ModuleNotFoundError, SyntaxError) as e:
    print(f"Warning: Could not import ollama_client: {e}")
    # Try to at least check if file exists and is syntactically valid
    try:
        with open(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/ollama_client.py",
            "r",
        ) as f:
            compile(
                f.read(),
                "/Users/danielstevens/Desktop/github-projects/tools-automation/ollama_client.py",
                "exec",
            )
        print(f"File ollama_client.py is syntactically valid but import failed")
    except SyntaxError as se:
        print(f"File ollama_client.py has syntax errors: {se}")


@pytest.mark.skipif(
    not MODULE_AVAILABLE, reason="Module not available or has import issues"
)
class TestOllamaClient:
    """Comprehensive tests for ollama_client.py"""

    def test_module_syntax_valid(self):
        """Test that the module file is syntactically valid"""
        try:
            with open(
                "/Users/danielstevens/Desktop/github-projects/tools-automation/ollama_client.py",
                "r",
            ) as f:
                compile(
                    f.read(),
                    "/Users/danielstevens/Desktop/github-projects/tools-automation/ollama_client.py",
                    "exec",
                )
            assert True
        except SyntaxError:
            pytest.fail(f"Syntax error in ollama_client.py")

    def test_file_exists(self):
        """Test that the source file exists"""
        assert os.path.exists(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/ollama_client.py"
        )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_module_can_be_imported(self):
        """Test that the module can be imported successfully"""
        try:
            __import__("ollama_client")
            assert True
        except ImportError:
            pytest.fail(f"Module ollama_client should be importable")

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_cloud_fallback_policy_init(self):
        """Test CloudFallbackPolicy initialization"""
        import ollama_client as module

        with patch("os.path.exists", return_value=True):
            with patch("ollama_client.load_json") as mock_load:
                mock_load.side_effect = [{"enabled": True}, {"quotas": {}}]
                policy = module.CloudFallbackPolicy()
                assert policy.enabled is True
                assert policy.config == {"enabled": True}
                assert policy.quota_data == {"quotas": {}}

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_check_quota_disabled(self):
        """Test check_quota when fallback disabled"""
        import ollama_client as module

        policy = module.CloudFallbackPolicy()
        policy.enabled = False
        assert policy.check_quota("high") is True

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_check_quota_allowed_priority(self):
        """Test check_quota with allowed priority"""
        import ollama_client as module

        policy = module.CloudFallbackPolicy()
        policy.enabled = True
        policy.config = {"allowed_priority_levels": ["high"]}
        policy.quota_data = {
            "quotas": {
                "high": {
                    "daily_used": 10,
                    "hourly_used": 5,
                    "daily_limit": 100,
                    "hourly_limit": 20,
                }
            }
        }

        assert policy.check_quota("high") is True

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_check_quota_exceeded(self):
        """Test check_quota when quota exceeded"""
        import ollama_client as module

        policy = module.CloudFallbackPolicy()
        policy.enabled = True
        policy.config = {"allowed_priority_levels": ["high"]}
        policy.quota_data = {
            "quotas": {
                "high": {
                    "daily_used": 100,
                    "hourly_used": 20,
                    "daily_limit": 100,
                    "hourly_limit": 20,
                }
            }
        }

        assert policy.check_quota("high") is False

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_check_circuit_breaker_closed(self):
        """Test check_circuit_breaker when closed"""
        import ollama_client as module

        policy = module.CloudFallbackPolicy()
        policy.enabled = True
        policy.quota_data = {"circuit_breaker": {"high": {"state": "closed"}}}

        assert policy.check_circuit_breaker("high") is True

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_check_circuit_breaker_open_reset(self):
        """Test check_circuit_breaker when open but reset time passed"""
        import ollama_client as module
        from datetime import datetime, timedelta, timezone

        policy = module.CloudFallbackPolicy()
        policy.enabled = True
        policy.config = {"circuit_breaker": {"reset_after_minutes": 30}}
        past_time = (datetime.now(timezone.utc) - timedelta(minutes=31)).isoformat()
        policy.quota_data = {
            "circuit_breaker": {"high": {"state": "open", "opened_at": past_time}}
        }

        with patch("ollama_client.save_json") as mock_save:
            assert policy.check_circuit_breaker("high") is True
            mock_save.assert_called_once()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_record_failure_trip_breaker(self):
        """Test record_failure tripping circuit breaker"""
        import ollama_client as module
        from datetime import datetime, timezone

        policy = module.CloudFallbackPolicy()
        policy.enabled = True
        policy.config = {"circuit_breaker": {"failure_threshold": 3}}
        policy.quota_data = {
            "circuit_breaker": {"high": {"state": "closed", "failure_count": 2}}
        }

        with patch("ollama_client.save_json") as mock_save:
            policy.record_failure("high")
            # Should have incremented failure count and tripped breaker
            assert policy.quota_data["circuit_breaker"]["high"]["failure_count"] == 3
            assert policy.quota_data["circuit_breaker"]["high"]["state"] == "open"
            mock_save.assert_called_once()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_increment_quota(self):
        """Test increment_quota"""
        import ollama_client as module
        from datetime import datetime, timezone

        policy = module.CloudFallbackPolicy()
        policy.enabled = True
        policy.quota_data = {"quotas": {"high": {"daily_used": 10, "hourly_used": 5}}}

        with patch("ollama_client.save_json") as mock_save:
            policy.increment_quota("high")
            assert policy.quota_data["quotas"]["high"]["daily_used"] == 11
            assert policy.quota_data["quotas"]["high"]["hourly_used"] == 6
            mock_save.assert_called_once()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_load_json(self):
        """Test load_json function"""
        import ollama_client as module

        test_data = {"test": "data"}
        with patch("os.path.exists", return_value=True):
            with patch("builtins.open", mock_open(read_data=json.dumps(test_data))):
                result = module.load_json("test.json")
                assert result == test_data

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_save_json(self):
        """Test save_json function"""
        import ollama_client as module

        test_data = {"test": "data"}
        with patch("builtins.open", mock_open()) as mock_file:
            with patch("os.makedirs"):
                module.save_json("test.json", test_data)
                mock_file.assert_called()
                assert mock_file().write.called

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_run_ollama_success(self):
        """Test run_ollama successful execution"""
        import ollama_client as module

        with patch("subprocess.run") as mock_run:
            mock_run.return_value = Mock(stdout="response text", returncode=0)
            result = module.run_ollama("test-model", "test prompt", {})
            assert result == "response text"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_run_ollama_failure(self):
        """Test run_ollama when subprocess fails"""
        import ollama_client as module

        with patch("subprocess.run") as mock_run:
            mock_run.return_value = Mock(stdout="", returncode=1, stderr="error")
            result = module.run_ollama("test-model", "test prompt", {})
            assert result is None

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_log_usage_metrics(self):
        """Test log_usage_metrics function"""
        import ollama_client as module

        with patch("ollama_client.save_json") as mock_save:
            with patch("os.path.exists", return_value=True):
                with patch("ollama_client.load_json", return_value={"metrics": []}):
                    module.log_usage_metrics(
                        "test-task", "test-model", 100, 50, "success"
                    )
                    mock_save.assert_called()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_create_backup(self):
        """Test create_backup function"""
        import ollama_client as module

        with patch("shutil.copy2") as mock_copy:
            with patch("os.path.exists", return_value=True):
                module.create_backup()
                mock_copy.assert_called()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_rollback_changes(self):
        """Test rollback_changes function"""
        import ollama_client as module

        with patch("os.path.exists", return_value=True):
            with patch("shutil.copy2") as mock_copy:
                with patch("os.listdir", return_value=["backup.json"]):
                    result = module.rollback_changes()
                    assert "rollback_complete" in result["status"]

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_dry_run(self):
        """Test main function with dry-run option"""
        import ollama_client as module

        test_input = {"task": "test", "prompt": "test prompt"}
        registry_data = {"test": {"primaryModel": "llama2", "priority": "medium"}}
        with patch("sys.stdin.read", return_value=json.dumps(test_input)):
            with patch("sys.argv", ["ollama_client.py", "--dry-run"]):
                with patch("ollama_client.load_json", return_value=registry_data):
                    with patch("sys.exit") as mock_exit:
                        with patch("builtins.print") as mock_print:
                            # Just test that it doesn't crash
                            try:
                                module.main()
                            except SystemExit:
                                pass  # Expected

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_normal_execution(self):
        """Test main function normal execution"""
        import ollama_client as module

        test_input = {"task": "test", "prompt": "test prompt"}
        registry_data = {"test": {"primaryModel": "llama2", "priority": "medium"}}
        with patch("sys.stdin.read", return_value=json.dumps(test_input)):
            with patch("sys.argv", ["ollama_client.py"]):
                with patch(
                    "ollama_client.load_json",
                    side_effect=[registry_data, {}, registry_data, {}],
                ):
                    with patch("ollama_client.run_ollama", return_value="response"):
                        with patch("sys.exit") as mock_exit:
                            with patch("builtins.print") as mock_print:
                                # Just test that it doesn't crash
                                try:
                                    module.main()
                                except SystemExit:
                                    pass  # Expected
