#!/usr/bin/env python3
"""
Interactive API Documentation Server

Serves the Swagger UI for the MCP Server API documentation.

Usage:
    python3 serve_api_docs.py [--port PORT] [--host HOST]

Example:
    python3 serve_api_docs.py --port 8080
    python3 serve_api_docs.py --host 0.0.0.0 --port 8080
"""

import argparse
import http.server
import socketserver
import os
import sys
import webbrowser
from pathlib import Path


class APIDocsHandler(http.server.SimpleHTTPRequestHandler):
    """Custom handler for API documentation server"""

    def __init__(self, *args, directory=None, **kwargs):
        super().__init__(*args, directory=directory, **kwargs)

    def do_GET(self):
        """Handle GET requests with proper MIME types"""
        # Set the correct content type for YAML files
        if self.path.endswith(".yaml") or self.path.endswith(".yml"):
            self.send_response(200)
            self.send_header("Content-type", "application/yaml")
            self.end_headers()

            # Read and serve the YAML file
            try:
                yaml_path = self.translate_path(self.path)
                with open(yaml_path, "rb") as f:
                    self.wfile.write(f.read())
            except FileNotFoundError:
                self.send_error(404, "File not found")
            return

        # Handle HTML files
        if self.path.endswith(".html") or self.path == "/" or self.path == "":
            if self.path == "/" or self.path == "":
                self.path = "/api/index.html"

        # Call parent handler for other files
        return super().do_GET()

    def log_message(self, format, *args):
        """Custom logging with emoji"""
        print(f"📖 API Docs Server: {format % args}")

    def end_headers(self):
        """Add CORS headers for API testing"""
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header(
            "Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS"
        )
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        super().end_headers()


def serve_api_docs(host="localhost", port=8080, open_browser=True):
    """Serve the API documentation"""

    # Change to docs directory
    docs_dir = Path(__file__).parent / "docs"
    if not docs_dir.exists():
        print("❌ Error: docs directory not found!")
        print(f"Expected location: {docs_dir.absolute()}")
        sys.exit(1)

    os.chdir(docs_dir)

    # Create server
    with socketserver.TCPServer(
        (host, port),
        lambda *args, **kwargs: APIDocsHandler(
            *args, directory=str(docs_dir), **kwargs
        ),
    ) as httpd:
        server_url = f"http://{host}:{port}/api/"

        print("🚀 Starting API Documentation Server")
        print(f"📖 Swagger UI: {server_url}")
        print(f"📁 Serving from: {docs_dir.absolute()}")
        print("🎯 MCP Server API documentation with interactive testing")
        print("💡 Press Ctrl+C to stop the server")
        print()

        # Open browser automatically
        if open_browser:
            try:
                webbrowser.open(server_url)
                print("🌐 Browser opened automatically")
            except Exception as e:
                print(f"⚠️  Could not open browser: {e}")

        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n🛑 Server stopped by user")
            httpd.shutdown()


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="Serve interactive API documentation for MCP Server",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 serve_api_docs.py                    # Serve on localhost:8080
  python3 serve_api_docs.py --port 3000        # Serve on localhost:3000
  python3 serve_api_docs.py --host 0.0.0.0    # Serve on all interfaces
  python3 serve_api_docs.py --no-browser      # Don't open browser automatically
        """,
    )

    parser.add_argument(
        "--host", default="localhost", help="Host to bind to (default: localhost)"
    )

    parser.add_argument(
        "--port", type=int, default=8080, help="Port to serve on (default: 8080)"
    )

    parser.add_argument(
        "--no-browser", action="store_true", help="Do not open browser automatically"
    )

    args = parser.parse_args()

    # Validate port range
    if not (1 <= args.port <= 65535):
        print(f"❌ Error: Invalid port number {args.port}. Must be between 1-65535")
        sys.exit(1)

    try:
        serve_api_docs(host=args.host, port=args.port, open_browser=not args.no_browser)
    except OSError as e:
        if e.errno == 48:  # Address already in use
            print(f"❌ Error: Port {args.port} is already in use")
            print("💡 Try a different port with --port PORT")
        else:
            print(f"❌ Error starting server: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
