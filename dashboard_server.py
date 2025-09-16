#!/usr/bin/env python3
import http.server
import socketserver
import os
from urllib.parse import unquote
import threading

class CustomHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        print(f"=== New request: {self.path} ===")

        # Strip query parameters from path
        path = self.path.split('?')[0]

        try:
            print(f"Request received: {path}")

            # Handle root path
            if path == '/' or path == '':
                path = '/dashboard.html'

            # Handle requests for dashboard.html
            if path == '/dashboard.html':
                dashboard_path = os.path.join(os.getcwd(), 'dashboard.html')
                print(f"Serving dashboard from: {dashboard_path}")

                if not os.path.exists(dashboard_path):
                    print("Dashboard file not found!")
                    self.send_error(404, "Dashboard file not found")
                    return

                try:
                    with open(dashboard_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                        self.send_response(200)
                        self.send_header('Content-type', 'text/html')
                        self.send_header('Content-Length', str(len(content.encode('utf-8'))))
                        self.end_headers()
                        self.wfile.write(content.encode('utf-8'))
                    print("Dashboard served successfully")
                    return
                except Exception as e:
                    print(f"Error reading dashboard file: {e}")
                    self.send_error(500, f"Internal server error: {e}")
                    return

            # Handle requests for agents directory
            if path.startswith('/agents/'):
                # Remove the leading slash and join with current directory
                file_path = path[1:]  # Remove leading '/'
                full_path = os.path.join(os.getcwd(), file_path)
                print(f"Serving agent file from: {full_path}")

                if not os.path.exists(full_path):
                    print(f"Agent file not found: {full_path}")
                    self.send_error(404, "Agent file not found")
                    return

                try:
                    with open(full_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                        self.send_response(200)
                        # Set content type based on file extension
                        if file_path.endswith('.json'):
                            self.send_header('Content-type', 'application/json')
                        else:
                            self.send_header('Content-type', 'text/plain')
                        self.send_header('Content-Length', str(len(content.encode('utf-8'))))
                        self.end_headers()
                        self.wfile.write(content.encode('utf-8'))
                    print(f"Agent file served successfully: {file_path}")
                    return
                except Exception as e:
                    print(f"Error reading agent file: {e}")
                    self.send_error(500, f"Internal server error: {e}")
                    return

            # For all other requests, use the default handler
            print(f"Using default handler for: {path}")
            super().do_GET()

        except Exception as e:
            print(f"Unexpected error in do_GET: {e}")
            import traceback
            traceback.print_exc()
            try:
                self.send_error(500, f"Internal server error: {e}")
            except Exception as send_error:
                print(f"Failed to send error response: {send_error}")

    def log_message(self, format, *args):
        # Log all messages for debugging
        print(f"LOG: {format % args}")

def run_server():
    PORT = 8083  # Try a different port to avoid any conflicts

    try:
        print(f"Current working directory: {os.getcwd()}")
        print(f"Attempting to start server on port {PORT}")
        # Use ThreadingTCPServer for better stability
        server = socketserver.ThreadingTCPServer(("", PORT), CustomHTTPRequestHandler)
        print(f"Server bound to port {PORT}")
        print(f"Dashboard server running at http://localhost:{PORT}")
        print(f"Access the dashboard at: http://localhost:{PORT}/dashboard.html")
        print("Press Ctrl+C to stop the server")
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped by user")
    except Exception as e:
        print(f"Server error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    print("Starting dashboard server from Automation directory...")
    run_server()