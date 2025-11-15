#!/usr/bin/env python3
"""
RBAC Middleware for Agent Dashboard API

Provides authentication and authorization middleware for the dashboard API.
"""

import os
import json
import subprocess
import functools
from flask import request, jsonify, g
from werkzeug.exceptions import Unauthorized

class RBACMiddleware:
    def __init__(self, workspace_root):
        self.workspace_root = workspace_root
        self.rbac_script = os.path.join(workspace_root, "rbac_system.sh")
        self.audit_script = os.path.join(workspace_root, "audit_compliance.sh")

    def authenticate_request(self):
        """Authenticate incoming request"""
        auth_header = request.headers.get('Authorization', '')
        if not auth_header.startswith('Bearer '):
            raise Unauthorized("Missing or invalid authorization header")

        token = auth_header[7:]  # Remove 'Bearer ' prefix

        # Parse token (format: username:session_id)
        try:
            username, session_id = token.split(':', 1)
        except ValueError:
            raise Unauthorized("Invalid token format")

        # Validate session
        result = subprocess.run(
            [self.rbac_script, "validate", session_id],
            capture_output=True, text=True
        )

        if result.returncode != 0:
            # Log failed authentication
            subprocess.run([
                self.audit_script, "log", "authentication",
                username, "api_access", "dashboard", "failed", "invalid_session"
            ], capture_output=True)
            raise Unauthorized("Invalid session")

        # Store user in request context
        g.username = username
        g.session_id = session_id

        # Log successful authentication
        subprocess.run([
            self.audit_script, "log", "authentication",
            username, "api_access", "dashboard", "success", "session_validated"
        ], capture_output=True)

    def require_permission(self, permission):
        """Decorator to require specific permission"""
        def decorator(f):
            @functools.wraps(f)
            def wrapped(*args, **kwargs):
                if not hasattr(g, 'session_id'):
                    raise Unauthorized("Authentication required")

                session_id = g.session_id

                # Check permission
                result = subprocess.run(
                    [self.rbac_script, "check", session_id, permission],
                    capture_output=True, text=True
                )

                if result.returncode != 0:
                    # Log authorization failure
                    subprocess.run([
                        self.audit_script, "log", "authorization",
                        g.username, "api_access", request.path, "denied", f"missing_{permission}"
                    ], capture_output=True)
                    raise Unauthorized(f"Permission '{permission}' required")

                # Log successful authorization
                subprocess.run([
                    self.audit_script, "log", "authorization",
                    g.username, "api_access", request.path, "granted", permission
                ], capture_output=True)

                return f(*args, **kwargs)
            return wrapped
        return decorator

    def get_current_user(self):
        """Get current authenticated user"""
        return getattr(g, 'username', None)

# Global middleware instance
rbac_middleware = None

def init_rbac_middleware(app, workspace_root):
    """Initialize RBAC middleware for Flask app"""
    global rbac_middleware
    rbac_middleware = RBACMiddleware(workspace_root)

    @app.before_request
    def authenticate_before_request():
        # Skip authentication for health check and login endpoints
        if request.path in ['/health', '/login', '/']:
            return

        try:
            rbac_middleware.authenticate_request()
        except Unauthorized as e:
            return jsonify({"error": str(e)}), 401

def require_permission(permission):
    """Decorator for requiring permissions on routes"""
    if rbac_middleware is None:
        return lambda f: f
    return rbac_middleware.require_permission(permission)

def get_current_user():
    """Get current authenticated user"""
    if rbac_middleware is None:
        return None
    return rbac_middleware.get_current_user()
