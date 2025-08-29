import http.server
import socketserver
import os
import time
from pathlib import Path

AGENTS_DIR = Path(__file__).parent
LOGS = [
    "build_agent.log", "debug_agent.log", "codegen_agent.log", "uiux_agent.log",
    "apple_pro_agent.log", "collab_agent.log", "updater_agent.log", "search_agent.log", "supervisor.log"
]
PORT = 8088

class LogHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/":
            self.send_response(200)
            self.send_header("Content-type", "text/html")
            self.end_headers()
            self.wfile.write(self.render_dashboard().encode())
        else:
            super().do_GET()

    def render_dashboard(self):
        html = ["<html><head><title>Agent Monitor Dashboard</title>",
                "<meta http-equiv='refresh' content='5'>",
                "<style>body{font-family:monospace;} .error{color:red;} .ok{color:green;} pre{background:#222;color:#eee;padding:8px;}</style>",
                "</head><body>",
                "<h2>Agent Monitor Dashboard</h2>",
                f"<p>Last updated: {time.strftime('%Y-%m-%d %H:%M:%S')}</p>"]
        for log in LOGS:
            log_path = AGENTS_DIR / log
            html.append(f"<h3>{log}</h3>")
            if log_path.exists():
                with open(log_path) as f:
                    lines = f.readlines()[-30:]
                html.append("<pre>")
                for line in lines:
                    if any(w in line.lower() for w in ["error", "fail", "stuck", "timeout"]):
                        html.append(f"<span class='error'>{line.strip()}</span>\n")
                    elif "complete" in line.lower() or "cycle" in line.lower():
                        html.append(f"<span class='ok'>{line.strip()}</span>\n")
                    else:
                        html.append(line)
                html.append("</pre>")
            else:
                html.append("<pre>No log found.</pre>")
        html.append("</body></html>")
        return ''.join(html)

if __name__ == "__main__":
    with socketserver.TCPServer(("", PORT), LogHandler) as httpd:
        print(f"Serving agent monitor dashboard at http://localhost:{PORT}")
        httpd.serve_forever()
