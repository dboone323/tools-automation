import json
import subprocess
import sys
import os

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))
import os


from monitor_flaky_tests import FlakyTestMonitor


class DummyCompletedProcess:
    def __init__(self, returncode=0, stdout="", stderr=""):
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr


def test_run_tests_and_collect_results(monkeypatch, tmp_path):
    monitor = FlakyTestMonitor(test_results_dir=tmp_path)

    def fake_run(cmd, capture_output=True, text=True, **kw):
        # cmd is a list; ensure --json-report-file flag is passed
        assert any("--json-report" in c or c == "--json-report" for c in cmd)
        return DummyCompletedProcess(returncode=0, stdout="OK", stderr="")

    monkeypatch.setattr(subprocess, "run", fake_run)

    res = monitor.run_tests_and_collect_results(
        test_command="pytest tests/unit", output_file=tmp_path / "r.json"
    )

    assert res["success"]
    assert "output_file" in res


def test_analyze_test_results(tmp_path):
    monitor = FlakyTestMonitor(test_results_dir=tmp_path)
    sample = {
        "tests": [
            {"nodeid": "test_a.py::test_1", "outcome": "passed"},
            {"nodeid": "test_b.py::test_2", "outcome": "failed"},
        ]
    }
    f = tmp_path / "r.json"
    f.write_text(json.dumps(sample))

    results = monitor.analyze_test_results(str(f))
    assert "test_a.py::test_1" in results
    assert results["test_b.py::test_2"] == "failed"
