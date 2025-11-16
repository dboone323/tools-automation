#!/usr/bin/env python3
"""
RBAC-Integrated Agent Dashboard API Server

Provides REST API endpoints for the agent performance dashboard with RBAC authentication.
"""

import os
import sys
from flask import jsonify, request

# Add current directory to path for imports
sys.path.insert(0, os.path.dirname(__file__))

# Import original dashboard
from agent_dashboard_api import AgentDashboardAPI
from rbac_dashboard_middleware import init_rbac_middleware, require_permission


class RBACAgentDashboardAPI(AgentDashboardAPI):
    def __init__(self, workspace_root):
        super().__init__(workspace_root)

        # Initialize RBAC middleware
        init_rbac_middleware(self.app, workspace_root)

        # Override routes with RBAC protection
        self.setup_rbac_routes()

    def setup_rbac_routes(self):
        """Setup routes with RBAC protection"""

        @self.app.route("/api/agents/status")
        @require_permission("agent_management")
        def get_agent_status():
            return super().get_agent_status()

        @self.app.route("/api/agents/performance")
        @require_permission("agent_management")
        def get_agent_performance():
            return super().get_agent_performance()

        @self.app.route("/api/tasks/history")
        @require_permission("agent_management")
        def get_task_history():
            return super().get_task_history()

        @self.app.route("/api/system/config", methods=["GET"])
        @require_permission("system_configuration")
        def get_system_config():
            return super().get_system_config()

        @self.app.route("/api/system/config", methods=["POST"])
        @require_permission("system_configuration")
        def update_system_config():
            return super().update_system_config()

        @self.app.route("/api/security/audit")
        @require_permission("security_operations")
        def get_security_audit():
            return super().get_security_audit()

        @self.app.route("/api/deploy", methods=["POST"])
        @require_permission("deployment_access")
        def deploy_system():
            return super().deploy_system()


def main():
    workspace_root = os.path.dirname(os.path.abspath(__file__))
    dashboard = RBACAgentDashboardAPI(workspace_root)

    # Add user info to all responses
    @dashboard.app.after_request
    def add_user_info(response):
        if hasattr(request, "user") and request.user:
            response_data = response.get_json()
            if response_data:
                response_data["current_user"] = request.user
                response = jsonify(response_data)
        return response

    dashboard.app.run(host="0.0.0.0", port=5001, debug=False)


if __name__ == "__main__":
    main()
