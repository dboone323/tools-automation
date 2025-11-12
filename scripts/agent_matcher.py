#!/usr/bin/env python3
"""
Advanced Agent Matcher
Intelligent agent assignment system for TODO tasks
"""

import os
import json
import re
from pathlib import Path
from typing import Dict, Any, List, Optional, Tuple
from difflib import SequenceMatcher


class AgentMatcher:
    """Advanced agent matching system for TODO tasks"""

    def __init__(self, workspace_root: Path):
        self.workspace_root = workspace_root
        self.config_dir = workspace_root / "config"
        self.capabilities_file = self.config_dir / "agent_capabilities.json"
        self.agent_status_file = self.config_dir / "agent_status.json"

        # Agent capability mappings
        self.agent_capabilities = {
            "agent_codegen.sh": {
                "file_types": [
                    ".swift",
                    ".py",
                    ".js",
                    ".ts",
                    ".java",
                    ".cpp",
                    ".c",
                    ".h",
                    ".hpp",
                    ".cs",
                ],
                "task_types": [
                    "code_generation",
                    "implementation",
                    "feature",
                    "refactor",
                    "code_fix",
                ],
                "content_keywords": [
                    "implement",
                    "add",
                    "create",
                    "build",
                    "develop",
                    "code",
                ],
                "priority": 8,
                "specialties": [
                    "object-oriented",
                    "algorithms",
                    "data structures",
                    "api",
                ],
                "workload_capacity": 10,
            },
            "agent_build.sh": {
                "file_types": [
                    ".json",
                    ".yml",
                    ".yaml",
                    ".xml",
                    ".toml",
                    ".ini",
                    ".cfg",
                    ".gradle",
                    ".pom",
                    "dockerfile",
                    "makefile",
                ],
                "task_types": [
                    "build",
                    "configuration",
                    "deployment",
                    "ci_cd",
                    "packaging",
                ],
                "content_keywords": [
                    "build",
                    "deploy",
                    "config",
                    "setup",
                    "install",
                    "package",
                ],
                "priority": 7,
                "specialties": ["automation", "infrastructure", "containers", "ci_cd"],
                "workload_capacity": 8,
            },
            "agent_test.sh": {
                "file_types": [
                    ".py",
                    ".js",
                    ".ts",
                    ".java",
                    ".swift",
                    ".spec.",
                    ".test.",
                ],
                "task_types": [
                    "testing",
                    "validation",
                    "quality_assurance",
                    "coverage",
                ],
                "content_keywords": [
                    "test",
                    "validate",
                    "assert",
                    "verify",
                    "coverage",
                    "spec",
                ],
                "priority": 9,
                "specialties": [
                    "unit_tests",
                    "integration_tests",
                    "test_automation",
                    "tdd",
                ],
                "workload_capacity": 12,
            },
            "agent_documentation.sh": {
                "file_types": [
                    ".md",
                    ".txt",
                    ".rst",
                    ".adoc",
                    "readme",
                    "changelog",
                    "license",
                ],
                "task_types": ["documentation", "readme", "comments", "api_docs"],
                "content_keywords": [
                    "docs",
                    "document",
                    "readme",
                    "comment",
                    "describe",
                    "explain",
                ],
                "priority": 5,
                "specialties": [
                    "technical_writing",
                    "api_documentation",
                    "user_guides",
                ],
                "workload_capacity": 6,
            },
            "agent_debug.sh": {
                "file_types": ["*"],  # All file types
                "task_types": [
                    "debugging",
                    "troubleshooting",
                    "analysis",
                    "monitoring",
                    "logging",
                ],
                "content_keywords": [
                    "debug",
                    "fix",
                    "error",
                    "issue",
                    "problem",
                    "trace",
                    "log",
                ],
                "priority": 9,
                "specialties": [
                    "error_analysis",
                    "performance_debugging",
                    "memory_leaks",
                    "concurrency",
                ],
                "workload_capacity": 15,
            },
            "agent_security.sh": {
                "file_types": [".py", ".js", ".ts", ".java", ".swift", ".json", ".yml"],
                "task_types": ["security", "auth", "encryption", "vulnerability_fix"],
                "content_keywords": [
                    "security",
                    "auth",
                    "encrypt",
                    "vulnerable",
                    "hack",
                    "breach",
                ],
                "priority": 10,
                "specialties": [
                    "cryptography",
                    "authentication",
                    "authorization",
                    "owasp",
                ],
                "workload_capacity": 5,
            },
            "agent_performance_monitor.sh": {
                "file_types": [".swift", ".py", ".js", ".ts", ".java", ".cpp", ".c"],
                "task_types": ["optimization", "performance", "profiling", "caching"],
                "content_keywords": [
                    "performance",
                    "speed",
                    "optimize",
                    "fast",
                    "slow",
                    "memory",
                    "cpu",
                ],
                "priority": 8,
                "specialties": [
                    "algorithm_optimization",
                    "memory_management",
                    "caching",
                    "profiling",
                ],
                "workload_capacity": 7,
            },
            "pull_request_agent.sh": {
                "file_types": ["*"],
                "task_types": ["pull_request", "code_review", "merge"],
                "content_keywords": ["pr", "pull", "request", "review", "merge"],
                "priority": 6,
                "specialties": ["code_review", "collaboration", "version_control"],
                "workload_capacity": 8,
            },
        }

        self._load_custom_capabilities()

    def _load_custom_capabilities(self):
        """Load custom agent capabilities from config file"""
        if self.capabilities_file.exists():
            try:
                with open(self.capabilities_file, "r") as f:
                    custom_caps = json.load(f)
                    # Merge custom capabilities with defaults
                    for agent, caps in custom_caps.items():
                        if agent in self.agent_capabilities:
                            self.agent_capabilities[agent].update(caps)
                        else:
                            self.agent_capabilities[agent] = caps
            except (FileNotFoundError, json.JSONDecodeError):
                pass

    def _get_agent_workload(self, agent_name: str) -> int:
        """Get current workload for an agent"""
        if not self.agent_status_file.exists():
            return 0

        try:
            with open(self.agent_status_file, "r") as f:
                status_data = json.load(f)

            agent_status = status_data.get(agent_name, {})
            current_tasks = agent_status.get("current_tasks", 0)
            return current_tasks
        except (FileNotFoundError, json.JSONDecodeError):
            return 0

    def _calculate_file_type_score(
        self, file_path: str, agent_config: Dict[str, Any]
    ) -> float:
        """Calculate score based on file type matching"""
        if not file_path:
            return 0.0

        file_ext = Path(file_path).suffix.lower()
        file_name = Path(file_path).name.lower()

        score = 0.0

        # Direct file extension match
        if file_ext in agent_config.get("file_types", []):
            score += 3.0

        # Wildcard match (all files)
        if "*" in agent_config.get("file_types", []):
            score += 1.0

        # File name pattern matching
        for pattern in agent_config.get("file_types", []):
            if pattern in file_name and not pattern.startswith("."):
                score += 2.0

        return score

    def _calculate_content_score(
        self, text: str, agent_config: Dict[str, Any]
    ) -> float:
        """Calculate score based on content analysis"""
        if not text:
            return 0.0

        text_lower = text.lower()
        score = 0.0

        # Keyword matching
        keywords = agent_config.get("content_keywords", [])
        for keyword in keywords:
            if keyword in text_lower:
                score += 2.0

        # Task type matching
        task_types = agent_config.get("task_types", [])
        for task_type in task_types:
            if task_type in text_lower:
                score += 1.5

        # Specialty matching
        specialties = agent_config.get("specialties", [])
        for specialty in specialties:
            if specialty.replace("_", " ") in text_lower:
                score += 2.5

        return score

    def _calculate_context_score(
        self, todo: Dict[str, Any], agent_config: Dict[str, Any]
    ) -> float:
        """Calculate contextual score based on TODO metadata"""
        score = 0.0

        # Priority alignment (higher priority agents get boost for high-priority tasks)
        task_priority = todo.get("priority", 5)
        agent_base_priority = agent_config.get("priority", 5)

        if task_priority >= 8 and agent_base_priority >= 8:
            score += 1.0  # High-priority agent for high-priority task
        elif task_priority <= 3 and agent_base_priority <= 5:
            score += 0.5  # Low-priority agent for low-priority task

        # File location context
        file_path = todo.get("file", "")
        if "test" in file_path.lower() and "test" in agent_config.get("task_types", []):
            score += 1.5  # Test files for test agent
        elif "config" in file_path.lower() and "config" in agent_config.get(
            "task_types", []
        ):
            score += 1.5  # Config files for build agent

        # Line number context (higher lines might indicate older/more critical code)
        line_number = todo.get("line", 0)
        if line_number > 100 and agent_config.get("priority", 5) >= 7:
            score += 0.5

        return score

    def _calculate_workload_score(
        self, agent_name: str, agent_config: Dict[str, Any]
    ) -> float:
        """Calculate score based on agent workload capacity"""
        current_workload = self._get_agent_workload(agent_name)
        capacity = agent_config.get("workload_capacity", 10)

        # Calculate availability ratio
        if capacity == 0:
            return 0.0

        availability_ratio = max(0, (capacity - current_workload) / capacity)

        # Convert to score (higher availability = higher score)
        return availability_ratio * 2.0

    def _apply_special_rules(
        self, todo: Dict[str, Any], agent_name: str, base_score: float
    ) -> float:
        """Apply special matching rules"""
        text = todo.get("text", "").lower()
        file_path = todo.get("file", "").lower()

        # Security tasks always go to security agent if available
        if (
            any(word in text for word in ["security", "auth", "encrypt", "vulnerable"])
            and agent_name == "agent_security.sh"
        ):
            return base_score * 2.0

        # Performance tasks get boost for performance agent
        if (
            any(word in text for word in ["performance", "speed", "optimize", "memory"])
            and agent_name == "agent_performance_monitor.sh"
        ):
            return base_score * 1.8

        # FIXME tasks get priority boost for debug agent
        if "fixme" in text and agent_name == "agent_debug.sh":
            return base_score * 1.5

        # Test files strongly prefer test agent
        if "test" in file_path and agent_name == "agent_test.sh":
            return base_score * 1.7

        return base_score

    def match_agent(self, todo: Dict[str, Any]) -> Tuple[str, Dict[str, Any]]:
        """Find the best agent match for a TODO task"""
        best_agent = "agent_debug.sh"  # Default fallback
        best_score = 0.0
        best_breakdown = {}

        for agent_name, agent_config in self.agent_capabilities.items():
            # Calculate different score components
            file_score = self._calculate_file_type_score(
                todo.get("file", ""), agent_config
            )
            content_score = self._calculate_content_score(
                todo.get("text", ""), agent_config
            )
            context_score = self._calculate_context_score(todo, agent_config)
            workload_score = self._calculate_workload_score(agent_name, agent_config)

            # Combine scores with weights
            total_score = (
                file_score * 0.4  # 40% file type
                + content_score * 0.35  # 35% content
                + context_score * 0.15  # 15% context
                + workload_score * 0.1  # 10% workload
            )

            # Apply special rules
            total_score = self._apply_special_rules(todo, agent_name, total_score)

            # Track best match
            if total_score > best_score:
                best_score = total_score
                best_agent = agent_name
                best_breakdown = {
                    "total_score": round(total_score, 2),
                    "file_score": round(file_score, 2),
                    "content_score": round(content_score, 2),
                    "context_score": round(context_score, 2),
                    "workload_score": round(workload_score, 2),
                    "agent_priority": agent_config.get("priority", 5),
                    "current_workload": self._get_agent_workload(agent_name),
                    "capacity": agent_config.get("workload_capacity", 10),
                }

        return best_agent, best_breakdown

    def get_agent_recommendations(
        self, todo: Dict[str, Any], top_n: int = 3
    ) -> List[Tuple[str, Dict[str, Any]]]:
        """Get top N agent recommendations for a TODO"""
        agent_scores = []

        for agent_name, agent_config in self.agent_capabilities.items():
            file_score = self._calculate_file_type_score(
                todo.get("file", ""), agent_config
            )
            content_score = self._calculate_content_score(
                todo.get("text", ""), agent_config
            )
            context_score = self._calculate_context_score(todo, agent_config)
            workload_score = self._calculate_workload_score(agent_name, agent_config)

            total_score = (
                file_score * 0.4
                + content_score * 0.35
                + context_score * 0.15
                + workload_score * 0.1
            )

            total_score = self._apply_special_rules(todo, agent_name, total_score)

            breakdown = {
                "total_score": round(total_score, 2),
                "file_score": round(file_score, 2),
                "content_score": round(content_score, 2),
                "context_score": round(context_score, 2),
                "workload_score": round(workload_score, 2),
            }

            agent_scores.append((agent_name, breakdown))

        # Sort by score descending
        agent_scores.sort(key=lambda x: x[1]["total_score"], reverse=True)

        return agent_scores[:top_n]

    def save_capabilities(self):
        """Save current agent capabilities to config file"""
        self.config_dir.mkdir(exist_ok=True)

        with open(self.capabilities_file, "w") as f:
            json.dump(self.agent_capabilities, f, indent=2)

        print(f"💾 Saved agent capabilities to {self.capabilities_file}")


def main():
    """Test the agent matcher with sample TODOs"""
    workspace_root = Path(__file__).parent.parent
    matcher = AgentMatcher(workspace_root)

    # Sample TODOs for testing
    sample_todos = [
        {
            "file": "src/main.swift",
            "line": 42,
            "text": "TODO: Implement user authentication",
            "priority": 8,
        },
        {
            "file": "config/app.json",
            "line": 10,
            "text": "FIXME: Security vulnerability in auth endpoint",
            "priority": 10,
        },
        {
            "file": "tests/AuthTests.py",
            "line": 25,
            "text": "TODO: Add performance tests for login",
            "priority": 7,
        },
        {
            "file": "README.md",
            "line": 5,
            "text": "TODO: Update API documentation",
            "priority": 4,
        },
        {
            "file": "src/PerformanceMonitor.swift",
            "line": 150,
            "text": "FIXME: Memory leak in performance monitoring",
            "priority": 9,
        },
    ]

    print("🎯 Testing Advanced Agent Matcher")
    print("=" * 60)

    for todo in sample_todos:
        agent, breakdown = matcher.match_agent(todo)
        recommendations = matcher.get_agent_recommendations(todo, 3)

        print(f"\n📄 {todo['file']}:{todo['line']}")
        print(f"📝 {todo['text']}")
        print(f"🎖️  Priority: {todo['priority']}/10")
        print(f"🤖 Best Agent: {agent}")
        print(f"📊 Score Breakdown: {breakdown}")
        print(f"🏆 Top 3 Recommendations:")
        for i, (rec_agent, rec_breakdown) in enumerate(recommendations, 1):
            print(f"  {i}. {rec_agent}: {rec_breakdown['total_score']} points")


if __name__ == "__main__":
    main()
