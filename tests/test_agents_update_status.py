#!/usr/bin/env python3
"""
Comprehensive tests for agents/update_status.py
"""
import json
import os
import sys
import tempfile
import time
import unittest
import unittest.mock as mock
from pathlib import Path

# Add the agents directory to the path so we can import the module
# Add the workspace root to sys.path
if "/Users/danielstevens/Desktop/github-projects/tools-automation" not in sys.path:
    sys.path.insert(0, "/Users/danielstevens/Desktop/github-projects/tools-automation")

try:
    import agents.update_status as update_status
except ImportError as e:
    print(f"Failed to import agents.update_status: {e}", file=sys.stderr)
    sys.exit(1)


class TestUpdateStatus(unittest.TestCase):
    """Test cases for update_status.py functionality"""

    def setUp(self):
        """Set up test fixtures"""
        self.test_dir = tempfile.mkdtemp()
        self.status_file = os.path.join(self.test_dir, "test_status.json")
        self.lock_file = f"{self.status_file}.lock"

    def tearDown(self):
        """Clean up test fixtures"""
        import shutil

        # Remove test directory and all contents recursively
        if os.path.exists(self.test_dir):
            shutil.rmtree(self.test_dir)

    def test_module_import(self):
        """Test that the module can be imported successfully"""
        self.assertTrue(hasattr(update_status, "main"))

    def test_main_insufficient_arguments(self):
        """Test main function with insufficient arguments"""
        with mock.patch("sys.argv", ["update_status.py"]):
            with mock.patch("sys.stderr"):
                with self.assertRaises(SystemExit) as cm:
                    update_status.main()
                self.assertEqual(cm.exception.code, 1)

    def test_main_minimum_arguments(self):
        """Test main function with minimum required arguments"""
        test_args = ["update_status.py", "running", "test_agent", "12345"]

        with mock.patch("sys.argv", test_args):
            with mock.patch.dict(os.environ, {"STATUS_FILE": self.status_file}):
                with mock.patch("sys.stderr"):
                    with self.assertRaises(SystemExit) as cm:
                        update_status.main()
                    self.assertEqual(cm.exception.code, 0)

        # Verify file was created
        self.assertTrue(os.path.exists(self.status_file))
        with open(self.status_file, "r") as f:
            data = json.load(f)
        self.assertIn("agents", data)
        self.assertIn("test_agent", data["agents"])
        self.assertEqual(data["agents"]["test_agent"]["status"], "running")
        self.assertEqual(data["agents"]["test_agent"]["pid"], 12345)

    def test_main_with_task_id(self):
        """Test main function with task_id argument"""
        test_args = ["update_status.py", "completed", "test_agent", "12345", "task_001"]

        with mock.patch("sys.argv", test_args):
            with mock.patch.dict(os.environ, {"STATUS_FILE": self.status_file}):
                with mock.patch("sys.stderr"):
                    with self.assertRaises(SystemExit) as cm:
                        update_status.main()
                    self.assertEqual(cm.exception.code, 0)

        # Verify task_id was stored
        with open(self.status_file, "r") as f:
            data = json.load(f)
        self.assertEqual(data["agents"]["test_agent"]["current_task_id"], "task_001")

    def test_main_custom_status_file(self):
        """Test main function with custom status file from environment"""
        custom_file = os.path.join(self.test_dir, "custom_status.json")
        test_args = ["update_status.py", "idle", "agent_1", "99999"]

        with mock.patch("sys.argv", test_args):
            with mock.patch.dict(os.environ, {"STATUS_FILE": custom_file}):
                with mock.patch("sys.stderr"):
                    with self.assertRaises(SystemExit) as cm:
                        update_status.main()
                    self.assertEqual(cm.exception.code, 0)

        # Verify custom file was used
        self.assertTrue(os.path.exists(custom_file))
        with open(custom_file, "r") as f:
            data = json.load(f)
        self.assertIn("agent_1", data["agents"])

    def test_main_default_status_file(self):
        """Test main function with default status file"""
        test_args = ["update_status.py", "busy", "agent_2", "77777"]

        # Change to test directory so default file is created there
        original_cwd = os.getcwd()
        try:
            os.chdir(self.test_dir)
            with mock.patch("sys.argv", test_args):
                with mock.patch("sys.stderr"):
                    with self.assertRaises(SystemExit) as cm:
                        update_status.main()
                    self.assertEqual(cm.exception.code, 0)

            # Verify default file was created in current directory
            default_file = os.path.join(self.test_dir, "agent_status.json")
            self.assertTrue(os.path.exists(default_file))
        finally:
            os.chdir(original_cwd)

    def test_main_update_existing_agent(self):
        """Test updating status of existing agent"""
        # First create an agent
        initial_data = {
            "agents": {
                "existing_agent": {
                    "status": "idle",
                    "last_seen": 1000000000,
                    "pid": 11111,
                    "tasks_completed": 5,
                }
            },
            "last_update": 1000000000,
        }

        with open(self.status_file, "w") as f:
            json.dump(initial_data, f)

        # Update the agent
        test_args = [
            "update_status.py",
            "running",
            "existing_agent",
            "22222",
            "task_123",
        ]

        with mock.patch("sys.argv", test_args):
            with mock.patch.dict(os.environ, {"STATUS_FILE": self.status_file}):
                with mock.patch("sys.stderr"):
                    with self.assertRaises(SystemExit) as cm:
                        update_status.main()
                    self.assertEqual(cm.exception.code, 0)

        # Verify update preserved tasks_completed
        with open(self.status_file, "r") as f:
            data = json.load(f)
        agent = data["agents"]["existing_agent"]
        self.assertEqual(agent["status"], "running")
        self.assertEqual(agent["pid"], 22222)
        self.assertEqual(agent["current_task_id"], "task_123")
        self.assertEqual(agent["tasks_completed"], 5)  # Preserved
        self.assertGreater(agent["last_seen"], 1000000000)  # Updated

    def test_main_list_format_initialization(self):
        """Test handling list format status file"""
        # Create initial list format file
        initial_data = [
            {
                "id": "agent_a",
                "name": "agent_a",
                "status": "idle",
                "last_seen": 1000000000,
                "pid": 11111,
            }
        ]

        with open(self.status_file, "w") as f:
            json.dump(initial_data, f)

        # Update existing agent in list format
        test_args = ["update_status.py", "running", "agent_a", "22222"]

        with mock.patch("sys.argv", test_args):
            with mock.patch.dict(os.environ, {"STATUS_FILE": self.status_file}):
                with mock.patch("sys.stderr"):
                    with self.assertRaises(SystemExit) as cm:
                        update_status.main()
                    self.assertEqual(cm.exception.code, 0)

        # Verify list format was maintained and updated
        with open(self.status_file, "r") as f:
            data = json.load(f)
        self.assertIsInstance(data, list)
        agent = data[0]
        self.assertEqual(agent["status"], "running")
        self.assertEqual(agent["pid"], 22222)

    def test_main_list_format_new_agent(self):
        """Test adding new agent to list format"""
        # Create initial list format file
        initial_data = [
            {
                "id": "agent_a",
                "name": "agent_a",
                "status": "idle",
                "last_seen": 1000000000,
                "pid": 11111,
            }
        ]

        with open(self.status_file, "w") as f:
            json.dump(initial_data, f)

        # Add new agent
        test_args = ["update_status.py", "busy", "agent_b", "33333"]

        with mock.patch("sys.argv", test_args):
            with mock.patch.dict(os.environ, {"STATUS_FILE": self.status_file}):
                with mock.patch("sys.stderr"):
                    with self.assertRaises(SystemExit) as cm:
                        update_status.main()
                    self.assertEqual(cm.exception.code, 0)

        # Verify new agent was added
        with open(self.status_file, "r") as f:
            data = json.load(f)
        self.assertEqual(len(data), 2)
        agent_b = data[1]
        self.assertEqual(agent_b["id"], "agent_b")
        self.assertEqual(agent_b["status"], "busy")
        self.assertEqual(agent_b["pid"], 33333)

    def test_main_corrupt_json_retry(self):
        """Test handling of corrupt JSON with retry logic"""
        # Create corrupt JSON file
        with open(self.status_file, "w") as f:
            f.write("{ invalid json content")

        test_args = ["update_status.py", "running", "test_agent", "12345"]

        with mock.patch("sys.argv", test_args):
            with mock.patch.dict(os.environ, {"STATUS_FILE": self.status_file}):
                with mock.patch("time.sleep"):  # Speed up retries
                    with mock.patch("sys.stderr"):
                        with self.assertRaises(SystemExit) as cm:
                            update_status.main()
                        # Code exits with 1 when JSON parsing fails after retries
                        self.assertEqual(cm.exception.code, 1)

    def test_main_file_locking(self):
        """Test that file locking prevents concurrent access"""
        test_args = ["update_status.py", "running", "test_agent", "12345"]

        # Mock fcntl.flock to verify it's called
        with mock.patch("sys.argv", test_args):
            with mock.patch.dict(os.environ, {"STATUS_FILE": self.status_file}):
                with mock.patch("fcntl.flock") as mock_flock:
                    with mock.patch("sys.stderr"):
                        with self.assertRaises(SystemExit) as cm:
                            update_status.main()
                        self.assertEqual(cm.exception.code, 0)

        # Verify lock was acquired
        mock_flock.assert_called_once()

    def test_main_atomic_write(self):
        """Test atomic file writing using temporary file"""
        test_args = ["update_status.py", "completed", "test_agent", "12345"]

        with mock.patch("sys.argv", test_args):
            with mock.patch.dict(os.environ, {"STATUS_FILE": self.status_file}):
                with mock.patch("tempfile.NamedTemporaryFile") as mock_temp:
                    # Make NamedTemporaryFile return a proper context manager
                    mock_file = mock.MagicMock()
                    mock_file.__enter__ = mock.MagicMock(return_value=mock_file)
                    mock_file.__exit__ = mock.MagicMock(return_value=None)
                    mock_file.name = "/tmp/test_temp"
                    mock_file.flush = mock.MagicMock()
                    mock_file.fileno = mock.MagicMock(return_value=123)
                    mock_temp.return_value = mock_file

                    with mock.patch("os.rename") as mock_rename:
                        with mock.patch("os.fsync"):
                            with mock.patch("json.dump"):
                                with mock.patch("sys.stderr"):
                                    with self.assertRaises(SystemExit) as cm:
                                        update_status.main()
                                    self.assertEqual(cm.exception.code, 0)

        # Verify atomic write was attempted (only for dict format)
        mock_temp.assert_called_once()
        mock_rename.assert_called_once()

    def test_main_exception_handling(self):
        """Test exception handling in main function"""
        test_args = ["update_status.py", "running", "test_agent", "not_a_number"]

        with mock.patch("sys.argv", test_args):
            with mock.patch.dict(os.environ, {"STATUS_FILE": self.status_file}):
                with mock.patch("sys.stderr"):
                    with self.assertRaises(SystemExit) as cm:
                        update_status.main()
                    self.assertEqual(cm.exception.code, 1)

    def test_main_directory_creation(self):
        """Test automatic directory creation for status file"""
        nested_file = os.path.join(self.test_dir, "nested", "dir", "status.json")
        test_args = ["update_status.py", "idle", "test_agent", "12345"]

        with mock.patch("sys.argv", test_args):
            with mock.patch.dict(os.environ, {"STATUS_FILE": nested_file}):
                with mock.patch("sys.stderr"):
                    with self.assertRaises(SystemExit) as cm:
                        update_status.main()
                    self.assertEqual(cm.exception.code, 0)

        # Verify directory was created
        self.assertTrue(os.path.exists(os.path.dirname(nested_file)))
        self.assertTrue(os.path.exists(nested_file))

    def test_main_timestamp_update(self):
        """Test that timestamps are properly updated"""
        test_args = ["update_status.py", "running", "test_agent", "12345"]

        with mock.patch("sys.argv", test_args):
            with mock.patch.dict(os.environ, {"STATUS_FILE": self.status_file}):
                with mock.patch("time.time", return_value=1234567890.0):
                    with mock.patch("sys.stderr"):
                        with self.assertRaises(SystemExit) as cm:
                            update_status.main()
                        self.assertEqual(cm.exception.code, 0)

        with open(self.status_file, "r") as f:
            data = json.load(f)
        self.assertEqual(data["last_update"], 1234567890)
        self.assertEqual(data["agents"]["test_agent"]["last_seen"], 1234567890)

    def test_main_list_format_timestamp_update(self):
        """Test timestamp updates in list format"""
        # Create initial list format file
        initial_data = [
            {
                "id": "agent_a",
                "name": "agent_a",
                "status": "idle",
                "last_seen": 1000000000,
                "pid": 11111,
            }
        ]

        with open(self.status_file, "w") as f:
            json.dump(initial_data, f)

        test_args = ["update_status.py", "running", "agent_a", "22222"]

        with mock.patch("sys.argv", test_args):
            with mock.patch.dict(os.environ, {"STATUS_FILE": self.status_file}):
                with mock.patch("time.time", return_value=1234567890.0):
                    with mock.patch("sys.stderr"):
                        with self.assertRaises(SystemExit) as cm:
                            update_status.main()
                        self.assertEqual(cm.exception.code, 0)

        with open(self.status_file, "r") as f:
            data = json.load(f)
        agent = data[0]
        self.assertEqual(agent["last_seen"], 1234567890)


if __name__ == "__main__":
    unittest.main()
