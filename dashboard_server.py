#!/usr/bin/env python3
"""
Simple web server to serve dashboards for the hybrid desktop app
"""
import http.server
import socketserver
import os
import sys
import urllib.request
import urllib.error
import json
from pathlib import Path


class ProxyHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # Add CORS headers to allow embedding
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header(
            "Access-Control-Allow-Headers", "X-Requested-With, Content-Type"
        )
        super().end_headers()

    def do_GET(self):
        # Handle API proxy requests
        if self.path.startswith("/api/"):
            self.proxy_api_request()
        else:
            super().do_GET()

    def do_POST(self):
        # Handle API proxy requests for POST
        if self.path.startswith("/api/"):
            self.proxy_api_request()
        else:
            self.send_error(405, "Method Not Allowed")

    def do_OPTIONS(self):
        # Handle CORS preflight requests
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header(
            "Access-Control-Allow-Headers", "X-Requested-With, Content-Type"
        )
        self.end_headers()

    def proxy_api_request(self):
        """Proxy API requests to the MCP server on port 5005"""
        try:
            # Construct the target URL by removing the /api prefix
            target_path = (
                "/" + self.path[4:] if self.path.startswith("/api/") else self.path
            )
            target_url = f"http://localhost:5005{target_path}"

            # Prepare the request
            if self.command == "POST":
                # Read the request body for POST requests
                content_length = self.headers.get("Content-Length")
                post_data = None
                if content_length:
                    try:
                        content_length = int(content_length)
                        if content_length > 0:
                            post_data = self.rfile.read(content_length)
                    except (ValueError, OSError) as e:
                        print(f"Error reading POST data: {e}")
                        post_data = b""

                # Create the proxy request
                req = urllib.request.Request(
                    target_url, data=post_data if post_data else None, method="POST"
                )

                # Set content type if provided
                content_type = self.headers.get("Content-Type")
                if content_type:
                    req.add_header("Content-Type", content_type)

            else:
                req = urllib.request.Request(target_url)

            # Add other headers (skip problematic ones)
            skip_headers = [
                "host",
                "content-length",
                "content-type",
                "connection",
                "keep-alive",
                "proxy-authenticate",
                "proxy-authorization",
                "te",
                "trailers",
                "transfer-encoding",
                "upgrade",
            ]
            for header_name, header_value in self.headers.items():
                if header_name.lower() not in skip_headers:
                    req.add_header(header_name, header_value)

            # Make the request
            with urllib.request.urlopen(req) as response:
                # Send the response back to the client
                self.send_response(response.status)
                for header_name, header_value in response.headers.items():
                    if header_name.lower() not in ["transfer-encoding", "connection"]:
                        self.send_header(header_name, header_value)
                self.end_headers()

                # Send the response body
                response_data = response.read()
                self.wfile.write(response_data)

        except urllib.error.HTTPError as e:
            print(f"HTTP Error proxying {self.path}: {e.code} {e.reason}")
            self.send_error(e.code, str(e.reason))
        except Exception as e:
            print(f"Proxy error for {self.path}: {str(e)}")
            self.send_error(500, f"Proxy error: {str(e)}")


def main():
    port = 8000
    web_dir = Path(__file__).parent

    os.chdir(web_dir)

    # Create daemon-like behavior
    try:
        with socketserver.TCPServer(("", port), ProxyHTTPRequestHandler) as httpd:
            print(
                f"🚀 Dashboard server with API proxy running at http://localhost:{port}"
            )
            print(f"📁 Serving files from: {web_dir}")
            print(f"🔗 Proxying API requests to: http://localhost:5005")
            print("Server is running... (use Ctrl+C to stop)")
            httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n👋 Server stopped")
        sys.exit(0)
    except Exception as e:
        print(f"Server error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
