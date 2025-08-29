#!/usr/bin/env python3
"""Lightweight MCP agent client.

Usage: run_agent.py --name NAME --capabilities cap1,cap2
It will register with MCP at http://127.0.0.1:5005/register and send periodic heartbeats.
"""
import argparse
import os
import time
import json
import sys

try:
    import requests
except Exception:
    print("requests library required. Install into Automation/.venv: pip install requests", file=sys.stderr)
    raise


def register(mcp_url, name, capabilities):
    url = mcp_url.rstrip('/') + '/register'
    payload = {'agent': name, 'capabilities': capabilities}
    try:
        r = requests.post(url, json=payload, timeout=5)
        r.raise_for_status()
        return r.json()
    except Exception as e:
        print(f"register failed: {e}")
        return None


def heartbeat(mcp_url, name):
    url = mcp_url.rstrip('/') + '/heartbeat'
    try:
        r = requests.post(url, json={'agent': name}, timeout=5)
        return r.status_code == 200
    except Exception:
        return False


def write_pid(pidfile):
    try:
        with open(pidfile, 'w') as f:
            f.write(str(os.getpid()))
    except Exception:
        pass


def perform_backup(path):
    # simple backup: copy file to .bak.timestamp
    try:
        import shutil
        ts = int(time.time())
        bak = f"{path}.bak.{ts}"
        shutil.copy2(path, bak)
        return os.path.abspath(bak)
    except Exception as e:
        print(f"backup failed: {e}")
        return None


def _with_file_lock(path, func, *a, **kw):
    """Run func while holding an advisory lock on the target file (POSIX using fcntl).
    If locking isn't available, run without lock as best-effort.
    """
    # Prefer portalocker if available (cross-platform); otherwise try POSIX fcntl or Windows msvcrt
    locker = None
    try:
        import portalocker
        locker = 'portalocker'
    except Exception:
        try:
            import fcntl
            locker = 'fcntl'
        except Exception:
            try:
                import msvcrt
                locker = 'msvcrt'
            except Exception:
                locker = None

    if locker == 'portalocker':
        fd = open(path, 'a+')
        try:
            portalocker.lock(fd, portalocker.LOCK_EX)
            return func(*a, **kw)
        finally:
            try:
                portalocker.unlock(fd)
            except Exception:
                pass
            try:
                fd.close()
            except Exception:
                pass

    if locker == 'fcntl':
        import fcntl
        fd = open(path, 'a+')
        try:
            fcntl.flock(fd.fileno(), fcntl.LOCK_EX)
            return func(*a, **kw)
        finally:
            try:
                fcntl.flock(fd.fileno(), fcntl.LOCK_UN)
            except Exception:
                pass
            try:
                fd.close()
            except Exception:
                pass

    if locker == 'msvcrt':
        import msvcrt
        fd = open(path, 'a+')
        try:
            msvcrt.locking(fd.fileno(), msvcrt.LK_LOCK, 1)
            return func(*a, **kw)
        finally:
            try:
                msvcrt.locking(fd.fileno(), msvcrt.LK_UN, 1)
            except Exception:
                pass
            try:
                fd.close()
            except Exception:
                pass

    # no locking available
    return func(*a, **kw)


def restore_backup(bak):
    try:
        import shutil
        orig = bak.rsplit('.bak.', 1)[0]
        shutil.copy2(bak, orig)
        return True
    except Exception as e:
        print(f"restore failed: {e}")
        return False


def _atomic_write(path, data):
    """Write data to path atomically using a temporary file and os.replace."""
    import tempfile
    d = os.path.dirname(path)
    fd, tmp = tempfile.mkstemp(dir=d)
    try:
        with os.fdopen(fd, 'w') as f:
            f.write(data)
        os.replace(tmp, path)
    finally:
        try:
            if os.path.exists(tmp):
                os.remove(tmp)
        except Exception:
            pass


def _latest_backup_for(path):
    # return most recent bak file path for given path or None
    try:
        d = os.path.dirname(path)
        base = os.path.basename(path)
        candidates = [os.path.join(d, x) for x in os.listdir(d) if x.startswith(base + '.bak.')]
        if not candidates:
            return None
        candidates.sort()
        return candidates[-1]
    except Exception:
        return None


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--name', required=True)
    p.add_argument('--capabilities', default='')
    p.add_argument('--mcp', default=os.environ.get('MCP_URL', 'http://127.0.0.1:5005'))
    p.add_argument('--backup-target', default=os.environ.get('AGENT_BACKUP_TARGET', None), help='path to file to backup/restore (for tests)')
    p.add_argument('--interval', type=int, default=30, help='heartbeat interval seconds')
    args = p.parse_args()

    caps = [c.strip() for c in args.capabilities.split(',') if c.strip()]
    print(f"Starting agent {args.name} -> MCP {args.mcp} capabilities={caps}")
    # write pidfile
    pidfile = os.path.join(os.path.dirname(__file__), '..', 'logs', f"{args.name}.pid")
    write_pid(pidfile)

    # simple HTTP health endpoint
    try:
        from http.server import HTTPServer, BaseHTTPRequestHandler

        class HealthHandler(BaseHTTPRequestHandler):
            def do_GET(self):
                if self.path == '/health':
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json')
                    self.end_headers()
                    self.wfile.write(json.dumps({'ok': True, 'agent': args.name}).encode('utf-8'))
                else:
                    self.send_response(404)
                    self.end_headers()

        # run health server in background thread
        def run_health():
            try:
                srv = HTTPServer(('127.0.0.1', 0), HealthHandler)
                sa = srv.socket.getsockname()
                print(f"health listening on {sa}")
                srv.serve_forever()
            except Exception:
                pass

        import threading
        threading.Thread(target=run_health, daemon=True).start()
    except Exception:
        pass

    # try registering a few times
    for i in range(3):
        res = register(args.mcp, args.name, caps)
        if res:
            print(f"registered: {res}")
            break
        print(f"register attempt {i+1} failed, retrying in 2s...")
        time.sleep(2)

    # main loop: heartbeat
    try:
        # simple loop: heartbeat and optionally poll tasks to execute
        while True:
            ok = heartbeat(args.mcp, args.name)
            print(f"heartbeat {'ok' if ok else 'fail'}")

            # if this agent can execute, poll /status tasks for queued tasks and exec them
            if 'execute' in caps:
                try:
                    r = requests.get(args.mcp.rstrip('/') + '/status', timeout=3)
                    st = r.json()
                    for t in st.get('tasks', []):
                        tid = t.get('id')
                        # always ensure a marker exists for modify-fail tasks when possible
                        if t.get('command') == 'modify-fail':
                            try:
                                target = args.backup_target or os.path.join(os.path.dirname(__file__), '..', 'test_modify_target.txt')
                                target = os.path.abspath(target)
                                marker = f"{target}.bak_marker"
                                if os.path.exists(target) and not os.path.exists(marker):
                                    # create backup file and marker under a file lock; best-effort
                                    def _do_backup():
                                        bak = perform_backup(target)
                                        try:
                                            _atomic_write(marker, str(bak or ''))
                                        except Exception:
                                            pass
                                        return bak

                                    bak = _with_file_lock(target, _do_backup)
                                    print(f"backup created for {tid}: {bak}")
                            except Exception as e:
                                print(f"backup check failed: {e}")

                        if t.get('status') == 'queued':
                            # attempt to execute via /execute_task
                            try:
                                # create a lightweight backup marker to avoid duplicate backups
                                target = args.backup_target or os.path.join(os.path.dirname(__file__), '..', 'test_modify_target.txt')
                                target = os.path.abspath(target)
                                marker = f"{target}.bak_marker"
                                if t.get('command') == 'modify-fail' and os.path.exists(target) and not os.path.exists(marker):
                                    def _do_backup_marker():
                                        bak = perform_backup(target)
                                        try:
                                            _atomic_write(marker, str(bak or ''))
                                        except Exception:
                                            pass
                                        return bak

                                    bak = _with_file_lock(target, _do_backup_marker)
                                    print(f"backup created and marker written: {bak}")

                                er = requests.post(args.mcp.rstrip('/') + '/execute_task', json={'task_id': tid}, timeout=5)
                                print(f"requested execute {tid} -> {er.status_code}")

                                # if we requested execute, poll task status and restore on failure
                                if er.status_code == 200:
                                    # poll task until finished or timeout
                                    poll_start = time.time()
                                    while time.time() - poll_start < 30:
                                        try:
                                            st = requests.get(args.mcp.rstrip('/') + '/status', timeout=3).json()
                                        except Exception:
                                            break
                                        task = next((x for x in st.get('tasks', []) if x.get('id') == tid), None)
                                        if not task:
                                            break
                                        if task.get('status') in ('success', 'failed', 'error'):
                                            # if failed/error, try restore
                                            if task.get('status') != 'success':
                                                latest = _latest_backup_for(target)
                                                if latest:
                                                    print(f"task {tid} failed; restoring from {latest}")
                                                    restore_backup(latest)
                                            break
                                        time.sleep(0.5)

                            except Exception as e:
                                print(f"execute request failed: {e}")
                except Exception:
                    pass

            time.sleep(args.interval)
    except KeyboardInterrupt:
        print("agent exiting")


if __name__ == '__main__':
    main()
