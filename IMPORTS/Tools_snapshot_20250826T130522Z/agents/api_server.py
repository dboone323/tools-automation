import http.server
import json
import os
import socketserver
import subprocess
from datetime import datetime

PORT = 8090
PLUGINS_DIR = os.path.join(os.path.dirname(__file__), "plugins")
AUDIT_LOG = os.path.join(os.path.dirname(__file__), "audit.log")
POLICY_CONF = os.path.join(os.path.dirname(__file__), "policy.conf")
API_TOKEN = os.environ.get("API_TOKEN", None)


class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        user = self.headers.get("X-User", "unknown")
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        if self.path.startswith("/api/plugins/list"):
            plugins = [f[:-3] for f in os.listdir(PLUGINS_DIR) if f.endswith(".sh")]
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"plugins": plugins}).encode())
            with open(AUDIT_LOG, "a") as f:
                f.write(f"[{now}] user={user} action=api_list_plugins result=success\n")
        elif self.path.startswith("/api/plugins/run/"):
            # Require API token for plugin execution
            token = self.headers.get("X-API-TOKEN")
            plugin = self.path.split("/")[-1]
            plugin_path = os.path.join(PLUGINS_DIR, plugin + ".sh")
            # Policy enforcement
            allow_list = []
            block_list = []
            try:
                with open(POLICY_CONF) as f:
                    section = None
                    for line in f:
                        line = line.strip()
                        if line == "[plugins]":
                            section = "plugins"
                        elif line.startswith("["):
                            section = None
                        elif section == "plugins" and line.startswith("allow="):
                            allow_list = [
                                x.strip() for x in line.split("=", 1)[1].split(",")
                            ]
                        elif section == "plugins" and line.startswith("block="):
                            block_list = [
                                x.strip() for x in line.split("=", 1)[1].split(",")
                            ]
            except Exception:
                pass
            if plugin in block_list:
                self.send_response(403)
                self.end_headers()
                with open(AUDIT_LOG, "a") as f:
                    f.write(
                        f"[{now}] user={user} action=api_run_plugin plugin={plugin} result=fail reason=policy_blocked\n"
                    )
                return
            if plugin not in allow_list:
                self.send_response(403)
                self.end_headers()
                with open(AUDIT_LOG, "a") as f:
                    f.write(
                        f"[{now}] user={user} action=api_run_plugin plugin={plugin} result=fail reason=policy_not_allowed\n"
                    )
                return
            if token != (API_TOKEN or "changeme"):
                self.send_response(403)
                self.end_headers()
                with open(AUDIT_LOG, "a") as f:
                    f.write(
                        f"[{now}] user={user} action=api_run_plugin plugin={plugin} result=fail reason=bad_token\n"
                    )
                return
            if os.path.isfile(plugin_path):
                result = subprocess.run([plugin_path], capture_output=True, text=True)
                self.send_response(200)
                self.send_header("Content-type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"output": result.stdout}).encode())
                with open(AUDIT_LOG, "a") as f:
                    f.write(
                        f"[{now}] user={user} action=api_run_plugin plugin={plugin} result=success\n"
                    )
            else:
                self.send_response(404)
                self.end_headers()
                with open(AUDIT_LOG, "a") as f:
                    f.write(
                        f"[{now}] user={user} action=api_run_plugin plugin={plugin} result=fail reason=not_found\n"
                    )
        else:
            super().do_GET()


if __name__ == "__main__":
    os.chdir(os.path.dirname(__file__))
    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        print(f"Agent API server running at http://localhost:{PORT}/api/plugins/list")
        httpd.serve_forever()
