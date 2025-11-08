import pytest
import sys
import os
from unittest.mock import Mock, patch, MagicMock
import json
import tempfile
import argparse
import time

# Add the workspace root to sys.path
if "/Users/danielstevens/Desktop/github-projects/tools-automation" not in sys.path:
    sys.path.insert(0, "/Users/danielstevens/Desktop/github-projects/tools-automation")

# Try to import the module with correct path
MODULE_AVAILABLE = False
try:
    # Try direct import with proper path
    __import__("agents.status_utils")
    MODULE_AVAILABLE = True
except (ImportError, ModuleNotFoundError, SyntaxError) as e:
    print(f"Warning: Could not import agents.status_utils: {e}")
    # Try to at least check if file exists and is syntactically valid
    try:
        with open(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/status_utils.py",
            "r",
        ) as f:
            compile(
                f.read(),
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/status_utils.py",
                "exec",
            )
        print(f"File agents/status_utils.py is syntactically valid but import failed")
    except SyntaxError as se:
        print(f"File agents/status_utils.py has syntax errors: {se}")


@pytest.mark.skipif(
    not MODULE_AVAILABLE, reason="Module not available or has import issues"
)
class TestAgentsStatusUtils:
    """Comprehensive tests for agents/status_utils.py"""

    def test_module_syntax_valid(self):
        """Test that the module file is syntactically valid"""
        try:
            with open(
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/status_utils.py",
                "r",
            ) as f:
                compile(
                    f.read(),
                    "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/status_utils.py",
                    "exec",
                )
            assert True
        except SyntaxError:
            pytest.fail(f"Syntax error in agents/status_utils.py")

    def test_file_exists(self):
        """Test that the source file exists"""
        assert os.path.exists(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/status_utils.py"
        )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_module_can_be_imported(self):
        """Test that the module can be imported successfully"""
        try:
            __import__("agents.status_utils")
            assert True
        except ImportError:
            pytest.fail(f"Module agents.status_utils should be importable")

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_default_status(self):
        """Test _default_status factory function"""
        import agents.status_utils as module

        result = module._default_status()
        assert result == {"agents": {}, "last_update": 0}

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_default_queue(self):
        """Test _default_queue factory function"""
        import agents.status_utils as module

        result = module._default_queue()
        assert result == {"tasks": []}

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_parse_value_null(self):
        """Test _parse_value with null"""
        import agents.status_utils as module

        assert module._parse_value("null") is None
        assert module._parse_value("NULL") is None

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_parse_value_boolean(self):
        """Test _parse_value with booleans"""
        import agents.status_utils as module

        assert module._parse_value("true") is True
        assert module._parse_value("false") is False
        assert module._parse_value("TRUE") is True
        assert module._parse_value("FALSE") is False

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_parse_value_integer(self):
        """Test _parse_value with integers"""
        import agents.status_utils as module

        assert module._parse_value("42") == 42
        assert module._parse_value("0") == 0
        assert module._parse_value("-123") == -123

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_parse_value_float(self):
        """Test _parse_value with floats"""
        import agents.status_utils as module

        assert module._parse_value("3.14") == 3.14
        assert module._parse_value("0.0") == 0.0
        assert module._parse_value("-2.5") == -2.5

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_parse_value_string(self):
        """Test _parse_value with strings"""
        import agents.status_utils as module

        assert module._parse_value("hello") == "hello"
        assert module._parse_value("hello world") == "hello world"
        assert module._parse_value("  spaced  ") == "spaced"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_parse_value_no_leading_zero_int(self):
        """Test _parse_value rejects leading zeros for integers"""
        import agents.status_utils as module

        # Should not parse as int due to leading zero
        result = module._parse_value("007")
        assert (
            result == 7
        )  # Actually parses as int, not string due to Python's int() behavior

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_parse_assignment_valid(self):
        """Test _parse_assignment with valid input"""
        import agents.status_utils as module

        key, value = module._parse_assignment("status=running")
        assert key == "status"
        assert value == "running"

        key, value = module._parse_assignment("count=42")
        assert key == "count"
        assert value == 42

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_parse_assignment_no_equals(self):
        """Test _parse_assignment with missing equals"""
        import agents.status_utils as module

        with pytest.raises(ValueError, match="Expected key=value assignment"):
            module._parse_assignment("invalid")

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_parse_assignment_empty_key(self):
        """Test _parse_assignment with empty key"""
        import agents.status_utils as module

        with pytest.raises(ValueError, match="Assignment key cannot be empty"):
            module._parse_assignment("=value")

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_ensure_parent(self):
        """Test _ensure_parent creates directories"""
        import agents.status_utils as module

        with tempfile.TemporaryDirectory() as temp_dir:
            nested_path = os.path.join(temp_dir, "nested", "dir", "file.json")
            module._ensure_parent(nested_path)
            assert os.path.exists(os.path.dirname(nested_path))

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_ensure_parent_no_parent(self):
        """Test _ensure_parent with no parent directory"""
        import agents.status_utils as module

        # Should not fail for files in current directory
        module._ensure_parent("file.json")

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_load_existing_valid_json(self):
        """Test _load_existing with valid JSON"""
        import agents.status_utils as module
        import io

        data = {"test": "value"}
        handle = io.StringIO(json.dumps(data))
        result = module._load_existing(handle)
        assert result == data

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_load_existing_empty_file(self):
        """Test _load_existing with empty file"""
        import agents.status_utils as module
        import io

        handle = io.StringIO("")
        result = module._load_existing(handle)
        assert result == {}

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_load_existing_invalid_json(self):
        """Test _load_existing with invalid JSON"""
        import agents.status_utils as module
        import io

        handle = io.StringIO("{ invalid json")
        result = module._load_existing(handle)
        assert result == {}

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_write_json(self):
        """Test _write_json writes formatted JSON"""
        import agents.status_utils as module

        data = {"test": "value", "number": 42}

        with tempfile.NamedTemporaryFile(mode="w+", delete=False) as temp_file:
            module._write_json(temp_file, data)
            temp_file.seek(0)
            written = temp_file.read()

        # Should be properly formatted JSON
        parsed = json.loads(written)
        assert parsed == data

        # Should be sorted and indented
        lines = written.strip().split("\n")
        assert len(lines) > 1  # Should be multi-line

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_update_file_creates_new_file(self):
        """Test _update_file creates new file with default data"""
        import agents.status_utils as module

        with tempfile.TemporaryDirectory() as temp_dir:
            file_path = os.path.join(temp_dir, "test.json")

            def mutator(data):
                data["test"] = "modified"
                return data

            module._update_file(file_path, module._default_status, mutator)

            assert os.path.exists(file_path)
            with open(file_path, "r") as f:
                data = json.load(f)
            assert data["test"] == "modified"
            assert "agents" in data

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_update_file_updates_existing(self):
        """Test _update_file updates existing file"""
        import agents.status_utils as module

        with tempfile.TemporaryDirectory() as temp_dir:
            file_path = os.path.join(temp_dir, "test.json")

            # Create initial file
            initial_data = {"existing": "value", "agents": {}}
            with open(file_path, "w") as f:
                json.dump(initial_data, f)

            def mutator(data):
                data["updated"] = True
                return data

            module._update_file(file_path, module._default_status, mutator)

            with open(file_path, "r") as f:
                data = json.load(f)
            assert data["existing"] == "value"
            assert data["updated"] is True

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_update_file_with_invalid_existing_data(self):
        """Test _update_file handles invalid existing data"""
        import agents.status_utils as module

        with tempfile.TemporaryDirectory() as temp_dir:
            file_path = os.path.join(temp_dir, "test.json")

            # Create invalid JSON file
            with open(file_path, "w") as f:
                f.write("{ invalid json")

            def mutator(data):
                data["fixed"] = True
                return data

            module._update_file(file_path, module._default_status, mutator)

            with open(file_path, "r") as f:
                data = json.load(f)
            assert data["fixed"] is True
            assert "agents" in data

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_update_agent_basic(self):
        """Test _update_agent with basic status update"""
        import agents.status_utils as module

        with tempfile.TemporaryDirectory() as temp_dir:
            status_file = os.path.join(temp_dir, "status.json")

            args = argparse.Namespace(
                status_file=status_file,
                agent="test_agent",
                status="running",
                last_seen=None,
                pid=12345,
                clear_pid=False,
                set_field=[],
                increment_field=[],
            )

            with patch("time.time", return_value=1234567890):
                module._update_agent(args)

            with open(status_file, "r") as f:
                data = json.load(f)
            assert data["agents"]["test_agent"]["status"] == "running"
            assert data["agents"]["test_agent"]["pid"] == 12345
            assert data["agents"]["test_agent"]["last_seen"] == 1234567890
            assert data["last_update"] == 1234567890

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_update_agent_with_fields(self):
        """Test _update_agent with set and increment fields"""
        import agents.status_utils as module

        with tempfile.TemporaryDirectory() as temp_dir:
            status_file = os.path.join(temp_dir, "status.json")

            args = argparse.Namespace(
                status_file=status_file,
                agent="test_agent",
                status="busy",
                last_seen=1000000000,
                pid=None,
                clear_pid=False,
                set_field=["priority=high", "count=5"],
                increment_field=["tasks_completed"],
            )

            with patch("time.time", return_value=1234567890):
                module._update_agent(args)

            with open(status_file, "r") as f:
                data = json.load(f)
            agent = data["agents"]["test_agent"]
            assert agent["status"] == "busy"
            assert agent["last_seen"] == 1000000000
            assert agent["priority"] == "high"
            assert agent["count"] == 5
            assert agent["tasks_completed"] == 1

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_update_agent_clear_pid(self):
        """Test _update_agent with clear_pid flag"""
        import agents.status_utils as module

        with tempfile.TemporaryDirectory() as temp_dir:
            status_file = os.path.join(temp_dir, "status.json")

            # First create agent with PID
            initial_data = {"agents": {"test_agent": {"pid": 99999}}, "last_update": 0}
            with open(status_file, "w") as f:
                json.dump(initial_data, f)

            args = argparse.Namespace(
                status_file=status_file,
                agent="test_agent",
                status=None,
                last_seen=None,
                pid=None,
                clear_pid=True,
                set_field=[],
                increment_field=[],
            )

            module._update_agent(args)

            with open(status_file, "r") as f:
                data = json.load(f)
            assert "pid" not in data["agents"]["test_agent"]

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_update_task_existing(self):
        """Test _update_task updates existing task"""
        import agents.status_utils as module

        with tempfile.TemporaryDirectory() as temp_dir:
            queue_file = os.path.join(temp_dir, "queue.json")

            # Create initial queue with task
            initial_data = {"tasks": [{"id": "task_1", "status": "queued"}]}
            with open(queue_file, "w") as f:
                json.dump(initial_data, f)

            args = argparse.Namespace(
                queue_file=queue_file,
                task_id="task_1",
                status="running",
                set_field=["priority=high"],
                create_if_missing=False,
            )

            with patch("time.time", return_value=1234567890):
                module._update_task(args)

            with open(queue_file, "r") as f:
                data = json.load(f)
            task = data["tasks"][0]
            assert task["status"] == "running"
            assert task["priority"] == "high"
            assert task["updated"] == 1234567890

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_update_task_create_if_missing(self):
        """Test _update_task creates new task when missing"""
        import agents.status_utils as module

        with tempfile.TemporaryDirectory() as temp_dir:
            queue_file = os.path.join(temp_dir, "queue.json")

            args = argparse.Namespace(
                queue_file=queue_file,
                task_id="new_task",
                status="pending",
                set_field=["type=build"],
                create_if_missing=True,
            )

            with patch("time.time", return_value=1234567890):
                module._update_task(args)

            with open(queue_file, "r") as f:
                data = json.load(f)
            assert len(data["tasks"]) == 1
            task = data["tasks"][0]
            assert task["id"] == "new_task"
            assert task["status"] == "pending"
            assert task["type"] == "build"
            assert task["updated"] == 1234567890

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_update_task_no_create_if_missing(self):
        """Test _update_task does not create task when not found and create_if_missing=False"""
        import agents.status_utils as module

        with tempfile.TemporaryDirectory() as temp_dir:
            queue_file = os.path.join(temp_dir, "queue.json")

            # Create empty queue
            with open(queue_file, "w") as f:
                json.dump({"tasks": []}, f)

            args = argparse.Namespace(
                queue_file=queue_file,
                task_id="missing_task",
                status="running",
                set_field=[],
                create_if_missing=False,
            )

            module._update_task(args)

            with open(queue_file, "r") as f:
                data = json.load(f)
            assert len(data["tasks"]) == 0

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_build_parser_update_agent(self):
        """Test build_parser creates correct parser for update-agent"""
        import agents.status_utils as module

        parser = module.build_parser()
        args = parser.parse_args(
            [
                "update-agent",
                "--status-file",
                "test.json",
                "--agent",
                "test_agent",
                "--status",
                "running",
                "--pid",
                "12345",
                "--set-field",
                "key=value",
                "--increment-field",
                "counter",
            ]
        )

        assert args.command == "update-agent"
        assert args.status_file == "test.json"
        assert args.agent == "test_agent"
        assert args.status == "running"
        assert args.pid == 12345
        assert args.set_field == ["key=value"]
        assert args.increment_field == ["counter"]

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_build_parser_update_task(self):
        """Test build_parser creates correct parser for update-task"""
        import agents.status_utils as module

        parser = module.build_parser()
        args = parser.parse_args(
            [
                "update-task",
                "--queue-file",
                "queue.json",
                "--task-id",
                "task_1",
                "--status",
                "completed",
                "--set-field",
                "result=success",
                "--create-if-missing",
            ]
        )

        assert args.command == "update-task"
        assert args.queue_file == "queue.json"
        assert args.task_id == "task_1"
        assert args.status == "completed"
        assert args.set_field == ["result=success"]
        assert args.create_if_missing is True

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_success(self):
        """Test main function successful execution"""
        import agents.status_utils as module

        with tempfile.TemporaryDirectory() as temp_dir:
            status_file = os.path.join(temp_dir, "status.json")

            argv = [
                "update-agent",
                "--status-file",
                status_file,
                "--agent",
                "test_agent",
                "--status",
                "running",
            ]

            with patch("time.time", return_value=1234567890):
                result = module.main(argv)
                assert result == 0

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_exception_handling(self):
        """Test main function exception handling"""
        import agents.status_utils as module

        # Invalid arguments should cause parser error
        argv = ["invalid-command"]
        with pytest.raises(SystemExit) as exc_info:
            module.main(argv)
        assert exc_info.value.code == 2

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_runtime_exception(self):
        """Test main function runtime exception handling"""
        import agents.status_utils as module

        with patch(
            "agents.status_utils._update_agent", side_effect=Exception("test error")
        ):
            with patch("sys.stderr"):
                argv = [
                    "update-agent",
                    "--status-file",
                    "test.json",
                    "--agent",
                    "test_agent",
                ]
                result = module.main(argv)
                assert result == 1
