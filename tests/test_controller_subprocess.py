import os
import time
import tempfile
import subprocess
import signal
import requests
from pathlib import Path
import importlib.util


# Load mcp_server module by path
here = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('mcp_server', str(here / 'mcp_server.py'))
server = importlib.util.module_from_spec(spec)
spec.loader.exec_module(server)


def run_server_in_thread(host='127.0.0.1', port=55125):
    import threading
    t = threading.Thread(target=server.run_server, args=(host, port), daemon=True)
    t.start()
    time.sleep(0.5)
    return t


def test_controller_subprocess_executes_task(tmp_path, monkeypatch):
    # Use temporary project dir as CODE_DIR so executed script writes artifacts there
    project_dir = tmp_path / 'proj'
    project_dir.mkdir()

    # create a simple artifact-writing script inside project_dir
    script = project_dir / 'write_artifact.sh'
    script.write_text("""#!/usr/bin/env bash
echo controller-run > artifacts/controller_output.txt
exit 0
""")
    script.chmod(0o755)

    # monkeypatch server CODE_DIR and allowed command
    monkeypatch.setattr(server, 'CODE_DIR', str(project_dir))
    monkeypatch.setitem(server.ALLOWED_COMMANDS, 'write-artifact', [str(script)])

    host = '127.0.0.1'
    port = 55125
    run_server_in_thread(host, port)
    base_url = f'http://{host}:{port}'

    # spawn controller subprocess pointing to the test server
    mcp_controller = str(here / 'mcp_controller.py')
    env = os.environ.copy()
    env.update({
        'MCP_URL': base_url,
        'AGENT_NAME': 'subproc-agent',
        'ARTIFACT_DIR': str(project_dir / 'artifacts'),
        'POLL_INTERVAL': '0.5',
        'HEARTBEAT_INTERVAL': '1.0',
    })

    proc = subprocess.Popen([env.get('PYTHON', 'python3'), mcp_controller], env=env)

    try:
        # Register a task for the controller to pick up
        r = requests.post(f'{base_url}/register', json={'agent': 'subproc-agent', 'capabilities': []}, timeout=5)
        assert r.status_code == 200

        r = requests.post(f'{base_url}/run', json={'agent': 'subproc-agent', 'command': 'write-artifact', 'execute': True}, timeout=5)
        assert r.status_code == 200
        task_id = r.json().get('task_id')
        assert task_id

        # wait for artifact to be created by subprocess controller
        artifact_file = project_dir / 'artifacts' / 'controller_output.txt'
        for _ in range(60):
            if artifact_file.exists():
                break
            time.sleep(0.2)

        assert artifact_file.exists()
        assert artifact_file.read_text().strip() == 'controller-run'

    finally:
        # terminate controller subprocess
        try:
            proc.send_signal(signal.SIGINT)
            proc.wait(timeout=3)
        except Exception:
            proc.kill()