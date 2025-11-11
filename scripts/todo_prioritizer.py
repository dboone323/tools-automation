#!/usr/bin/env python3
"""
Advanced TODO Prioritizer
Intelligent priority scoring system for TODO tasks
"""

import os
import json
import re
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional, Tuple
import subprocess


class TodoPrioritizer:
    """Advanced priority scoring system for TODO tasks"""

    def __init__(self, workspace_root: Path):
        self.workspace_root = workspace_root
        self.config_dir = workspace_root / "config"
        self.priorities_file = self.config_dir / "todo_priorities.json"

        # Priority weights and scoring rules
        self.priority_weights = {
            "file_type": {
                "core": 10,  # Core application files
                "config": 7,  # Configuration files
                "test": 8,  # Test files
                "docs": 3,  # Documentation
                "build": 6,  # Build/deployment files
                "other": 5,  # Other files
            },
            "keywords": {
                "FIXME": 15,  # Critical fixes
                "BUG": 12,  # Bug fixes
                "HACK": 10,  # Technical debt
                "TODO": 5,  # Standard tasks
                "NOTE": 2,  # Notes/comments
                "XXX": 8,  # Important reminders
            },
            "urgency_indicators": {
                "urgent": 8,  # Urgent keywords
                "critical": 10,  # Critical keywords
                "security": 12,  # Security issues
                "performance": 9,  # Performance issues
                "breaking": 9,  # Breaking changes
            },
            "complexity_indicators": {
                "simple": -2,  # Simple tasks
                "complex": 3,  # Complex tasks
                "refactor": 4,  # Refactoring tasks
                "rewrite": 6,  # Major rewrites
            },
            "age_penalty": 0.1,  # Points per day old
            "line_penalty": 0.01,  # Points per line number
        }

        # File type classifications
        self.file_classifications = {
            "core": [
                ".swift",
                ".py",
                ".js",
                ".ts",
                ".java",
                ".cpp",
                ".c",
                ".h",
                ".hpp",
            ],
            "config": [".json", ".yml", ".yaml", ".xml", ".toml", ".ini", ".cfg"],
            "test": ["test_", "_test.", "spec.", ".test."],
            "docs": [".md", ".txt", ".rst", ".adoc", "readme", "changelog"],
            "build": [".gradle", ".pom", "dockerfile", "makefile", ".sh", ".bash"],
        }

        self._load_custom_priorities()

    def _load_custom_priorities(self):
        """Load custom priority rules from config file"""
        if self.priorities_file.exists():
            try:
                with open(self.priorities_file, "r") as f:
                    custom_rules = json.load(f)
                    # Merge custom rules with defaults
                    self._merge_priority_rules(custom_rules)
            except (FileNotFoundError, json.JSONDecodeError):
                pass

    def _merge_priority_rules(self, custom_rules: Dict[str, Any]):
        """Merge custom priority rules with defaults"""
        for category, rules in custom_rules.items():
            if category in self.priority_weights:
                self.priority_weights[category].update(rules)

    def _classify_file_type(self, file_path: str) -> str:
        """Classify file type based on extension and path"""
        file_path = file_path.lower()

        # Check file extensions
        for category, extensions in self.file_classifications.items():
            if any(ext in file_path for ext in extensions):
                return category

        return "other"

    def _analyze_keywords(self, text: str) -> Dict[str, int]:
        """Analyze text for priority keywords"""
        text_upper = text.upper()
        scores = {}

        # Check for keyword matches
        for keyword, weight in self.priority_weights["keywords"].items():
            if keyword in text_upper:
                scores[keyword.lower()] = weight

        # Check for urgency indicators
        for indicator, weight in self.priority_weights["urgency_indicators"].items():
            if indicator in text_upper:
                scores[f"urgency_{indicator}"] = weight

        # Check for complexity indicators
        for indicator, weight in self.priority_weights["complexity_indicators"].items():
            if indicator in text_upper:
                scores[f"complexity_{indicator}"] = weight

        return scores

    def _calculate_age_penalty(self, line_number: int, file_path: str) -> float:
        """Calculate age-based penalty (older code gets higher priority)"""
        # Simple heuristic: higher line numbers might indicate older code
        # Could be enhanced with git history analysis
        age_penalty = line_number * self.priority_weights["line_penalty"]

        # Additional penalty for files in root vs subdirectories
        path_depth = len(Path(file_path).parts) - 1
        depth_penalty = path_depth * 0.5

        return age_penalty + depth_penalty

    def _analyze_dependencies(self, text: str, file_path: str) -> int:
        """Analyze if TODO has dependencies on other tasks"""
        dependency_score = 0

        # Check for dependency indicators
        if any(
            word in text.lower()
            for word in ["depends on", "requires", "after", "before"]
        ):
            dependency_score += 2

        # Check for related file references
        if any(ext in text.lower() for ext in [".swift", ".py", ".js", ".json"]):
            dependency_score += 1

        return dependency_score

    def _calculate_base_score(self, todo: Dict[str, Any]) -> float:
        """Calculate base priority score"""
        score = 0.0
        file_path = todo.get("file", "")
        text = todo.get("text", "")
        line_number = todo.get("line", 0)

        # File type score
        file_type = self._classify_file_type(file_path)
        score += self.priority_weights["file_type"].get(file_type, 5)

        # Keyword analysis
        keyword_scores = self._analyze_keywords(text)
        score += sum(keyword_scores.values())

        # Age penalty (higher line numbers = potentially older code)
        score += self._calculate_age_penalty(line_number, file_path)

        # Dependency analysis
        score += self._analyze_dependencies(text, file_path)

        # Length-based complexity (longer TODOs might be more complex)
        text_length = len(text)
        if text_length > 100:
            score += 2  # Complex task
        elif text_length < 20:
            score -= 1  # Simple task

        return score

    def _apply_intelligence_multipliers(
        self, score: float, todo: Dict[str, Any]
    ) -> float:
        """Apply intelligent multipliers based on context"""

        # Security-related tasks get priority boost
        if any(
            word in todo.get("text", "").lower()
            for word in ["security", "auth", "encrypt", "vulnerability"]
        ):
            score *= 1.5

        # Performance-critical tasks
        if any(
            word in todo.get("text", "").lower()
            for word in ["performance", "speed", "optimization", "memory"]
        ):
            score *= 1.3

        # Breaking changes get higher priority
        if "breaking" in todo.get("text", "").lower():
            score *= 1.4

        # Test-related tasks in core files get boost
        file_path = todo.get("file", "").lower()
        if "test" in file_path and any(
            ext in file_path for ext in [".swift", ".py", ".js"]
        ):
            score *= 1.2

        return score

    def calculate_priority(self, todo: Dict[str, Any]) -> int:
        """Calculate intelligent priority score for a TODO item"""
        # Calculate base score
        base_score = self._calculate_base_score(todo)

        # Apply intelligence multipliers
        final_score = self._apply_intelligence_multipliers(base_score, todo)

        # Normalize to 1-10 scale
        normalized_score = max(1, min(10, round(final_score)))

        return normalized_score

    def get_priority_breakdown(self, todo: Dict[str, Any]) -> Dict[str, Any]:
        """Get detailed breakdown of priority calculation"""
        base_score = self._calculate_base_score(todo)
        final_score = self._apply_intelligence_multipliers(base_score, todo)
        normalized_score = self.calculate_priority(todo)

        breakdown = {
            "final_priority": normalized_score,
            "base_score": round(base_score, 2),
            "final_score": round(final_score, 2),
            "file_type": self._classify_file_type(todo.get("file", "")),
            "keyword_scores": self._analyze_keywords(todo.get("text", "")),
            "age_penalty": round(
                self._calculate_age_penalty(todo.get("line", 0), todo.get("file", "")),
                2,
            ),
            "dependency_score": self._analyze_dependencies(
                todo.get("text", ""), todo.get("file", "")
            ),
            "intelligence_multipliers": [],
        }

        # Track which multipliers were applied
        text_lower = todo.get("text", "").lower()
        if any(
            word in text_lower
            for word in ["security", "auth", "encrypt", "vulnerability"]
        ):
            breakdown["intelligence_multipliers"].append("security_boost")
        if any(
            word in text_lower
            for word in ["performance", "speed", "optimization", "memory"]
        ):
            breakdown["intelligence_multipliers"].append("performance_boost")
        if "breaking" in text_lower:
            breakdown["intelligence_multipliers"].append("breaking_change_boost")

        file_path = todo.get("file", "").lower()
        if "test" in file_path and any(
            ext in file_path for ext in [".swift", ".py", ".js"]
        ):
            breakdown["intelligence_multipliers"].append("test_file_boost")

        return breakdown

    def prioritize_todos(
        self, todos: List[Dict[str, Any]]
    ) -> List[Tuple[Dict[str, Any], int]]:
        """Prioritize a list of TODOs and return with scores"""
        prioritized = []

        for todo in todos:
            priority = self.calculate_priority(todo)
            prioritized.append((todo, priority))

        # Sort by priority (highest first)
        prioritized.sort(key=lambda x: x[1], reverse=True)

        return prioritized

    def save_priority_rules(self):
        """Save current priority rules to config file"""
        self.config_dir.mkdir(exist_ok=True)

        with open(self.priorities_file, "w") as f:
            json.dump(self.priority_weights, f, indent=2)

        print(f"💾 Saved priority rules to {self.priorities_file}")


def main():
    """Test the prioritizer with sample TODOs"""
    workspace_root = Path(__file__).parent.parent
    prioritizer = TodoPrioritizer(workspace_root)

    # Sample TODOs for testing
    sample_todos = [
        {
            "file": "src/main.swift",
            "line": 42,
            "text": "TODO: Implement user authentication",
        },
        {
            "file": "config/app.json",
            "line": 10,
            "text": "FIXME: Security vulnerability in auth endpoint",
        },
        {
            "file": "tests/AuthTests.py",
            "line": 25,
            "text": "TODO: Add performance tests",
        },
        {"file": "README.md", "line": 5, "text": "TODO: Update documentation"},
    ]

    print("🎯 Testing TODO Prioritizer")
    print("=" * 50)

    for todo in sample_todos:
        priority = prioritizer.calculate_priority(todo)
        breakdown = prioritizer.get_priority_breakdown(todo)

        print(f"\n📄 {todo['file']}:{todo['line']}")
        print(f"📝 {todo['text']}")
        print(f"🎖️  Priority: {priority}/10")
        print(f"📊 Breakdown: {breakdown}")


if __name__ == "__main__":
    main()
