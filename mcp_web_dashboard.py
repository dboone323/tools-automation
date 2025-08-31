#!/usr/bin/env python3
"""Minimal local web dashboard for MCP

Serves a small HTML page and proxies /api/status to the local MCP server.
No external dependencies.
"""
import json
import os
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse

MCP_URL = os.environ.get("MCP_URL", "http://127.0.0.1:5005")
HOST = "127.0.0.1"
PORT = int(os.environ.get("MCP_WEB_PORT", "8080"))

HTML = (
    r"""
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <title>MCP Dashboard</title>
  <style>body{font-family:system-ui,Segoe UI,Roboto,Arial;margin:20px}table{border-collapse:collapse;width:100%}td,th{border:1px solid #ddd;padding:8px}th{background:#f4f4f4}</style>
  <script>
    async function fetchStatus(){
      try{
        let r = await fetch('/api/status');
        let j = await r.json();
        let tbody = document.getElementById('tasks');
        tbody.innerHTML = '';
        for(let t of j.tasks || []){
          let row = document.createElement('tr');
          row.innerHTML = `<td>${t.id||''}</td><td>${t.project||''}</td><td>${t.status||''}</td><td>${t.returncode||''}</td><td><pre style="white-space:pre-wrap">${(t.stdout||'').slice(0,200)}</pre></td>`;
          tbody.appendChild(row);
        }
      }catch(e){console.error(e)}
    }
    setInterval(fetchStatus,2000);
    window.addEventListener('load',fetchStatus);
  </script>
</head>
<body>
  <h2>MCP Dashboard</h2>
  <p>Proxying to: <code>%s</code></p>
  <table>
    <thead><tr><th>ID</th><th>Project</th><th>Status</th><th>Code</th><th>Stdout (truncated)</th></tr></thead>
    <tbody id="tasks"></tbody>
  </table>
</body>
</html>
"""
    % MCP_URL
)


class Handler(BaseHTTPRequestHandler):
    def _send(self, data, status=200, content_type="application/json"):
        b = data.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/":
            self._send(HTML, content_type="text/html")
            return
        if parsed.path == "/api/status":
            try:
                with urllib.request.urlopen(MCP_URL + "/status", timeout=2) as r:
                    data = r.read().decode("utf-8")
                    self._send(data)
                    return
            except Exception as e:
                self._send(
                    json.dumps(
                        {"ok": False, "error": str(e), "agents": [], "tasks": []}
                    )
                )
                return

        self._send(json.dumps({"error": "not_found"}), status=404)


def run(host=HOST, port=PORT):
    httpd = HTTPServer((host, port), Handler)
    print(f"MCP Web Dashboard running on http://{host}:{port} (proxy -> {MCP_URL})")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("Shutting down")


if __name__ == "__main__":
    run()
