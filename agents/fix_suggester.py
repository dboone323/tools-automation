#!/usr/bin/env python3

"""
Fix Suggester - Intelligent Fix Recommendation System
Combines knowledge base patterns with AI analysis to suggest fixes.
"""

import json
import sys
from agents.utils import safe_run, user_log
import subprocess
from pathlib import Path
import logging
from typing import Dict, List, Optional
import logging
logger = logging.getLogger(__name__)

# Configuration
SCRIPT_DIR = Path(__file__).parent
KNOWLEDGE_DIR = SCRIPT_DIR / "knowledge"
MCP_CLIENT = SCRIPT_DIR / "mcp_client.sh"
DECISION_ENGINE = SCRIPT_DIR / "decision_engine.py"


class FixSuggester:
    """Intelligent fix suggestion system."""

    def __init__(self):
        self.mcp_available = MCP_CLIENT.exists() and self._check_mcp()
        self.decision_engine_available = DECISION_ENGINE.exists()

    def _check_mcp(self) -> bool:
        """Check if MCP client is functional."""
        try:
            result = safe_run(
                [str(MCP_CLIENT), "test"], capture_output=True, text=True, timeout=5
            )
            return result.returncode == 0
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return False

    def suggest_fix(self, error_pattern: str, context: Dict = None) -> Dict:
        """
        Suggest fix for error pattern using multiple strategies.

        Args:
            error_pattern: Error message or pattern
            context: Additional context (files, severity, etc.)

        Returns:
            {
                "primary_suggestion": Dict,
                "alternatives": List[Dict],
                "confidence": float,
                "sources": List[str],
                "reasoning": str
            }
        """
        context = context or {}
        suggestions = []

        # Strategy 1: Decision Engine (knowledge base + heuristics)
        if self.decision_engine_available:
            try:
                decision = self._get_decision_engine_suggestion(error_pattern, context)
                suggestions.append(
                    {
                        "source": "decision_engine",
                        "action": decision.get("recommended_action"),
                        "confidence": decision.get("confidence", 0.5),
                        "reasoning": decision.get("reasoning", ""),
                        "auto_execute": decision.get("auto_execute", False),
                        "alternatives": decision.get("alternatives", []),
                    }
                )
            except Exception as e:
                logging.getLogger(__name__).warning("Decision engine failed: %s", e)

        # Strategy 2: MCP Client (AI-enhanced analysis)
        if self.mcp_available:
            try:
                mcp_suggestion = self._get_mcp_suggestion(error_pattern, context)
                if mcp_suggestion:
                    suggestions.append(
                        {
                            "source": "mcp_ai",
                            "action": self._extract_action_from_ai(mcp_suggestion),
                            "confidence": 0.6,  # AI suggestions get moderate confidence
                            "reasoning": mcp_suggestion.get("fix_suggestion", ""),
                            "root_cause": mcp_suggestion.get("root_cause", ""),
                            "prevention": mcp_suggestion.get("prevention", ""),
                        }
                    )
            except Exception as e:
                logging.getLogger(__name__).warning("MCP client failed: %s", e)

        # Strategy 3: Pattern matching fallback
        if not suggestions:
            fallback = self._get_fallback_suggestion(error_pattern)
            suggestions.append(fallback)

        # Combine and rank suggestions
        return self._combine_suggestions(suggestions)

    def _get_decision_engine_suggestion(
        self, error_pattern: str, context: Dict
    ) -> Dict:
        """Get suggestion from decision engine."""
        context_json = json.dumps(context)
        result = safe_run(
            [str(DECISION_ENGINE), "evaluate", error_pattern, context_json],
            capture_output=True,
            text=True,
            timeout=10,
        )

        if result.returncode == 0:
            return json.loads(result.stdout)
        else:
            raise RuntimeError(f"Decision engine failed: {result.stderr}")

    def _get_mcp_suggestion(self, error_pattern: str, context: Dict) -> Optional[Dict]:
        """Get suggestion from MCP client (AI analysis)."""
        _context_str = json.dumps(context) if context else ""
        result = safe_run(
            [str(MCP_CLIENT), "suggest-fix", error_pattern],
            capture_output=True,
            text=True,
            timeout=30,
        )

        if result.returncode == 0:
            try:
                # MCP returns JSON or text, try to parse
                output = result.stdout.strip()
                if output.startswith("{"):
                    return json.loads(output)
                else:
                    # AI returned text, structure it
                    return {
                        "fix_suggestion": output,
                        "root_cause": "See AI analysis",
                        "prevention": "See AI suggestions",
                    }
            except json.JSONDecodeError:
                return {"fix_suggestion": result.stdout.strip()}

        return None

    def _extract_action_from_ai(self, ai_response: Dict) -> str:
        """Extract actionable command from AI response."""
        suggestion = ai_response.get("fix_suggestion", "")

        # Look for common action keywords
        actions = {
            "rebuild": ["rebuild", "build again", "recompile"],
            "clean_build": ["clean", "clean build"],
            "update_dependencies": ["update", "pod install", "swift package"],
            "fix_lint": ["lint", "swiftlint"],
            "fix_format": ["format", "swiftformat"],
            "fix_imports": ["import", "missing module"],
        }

        suggestion_lower = suggestion.lower()
        for action, keywords in actions.items():
            if any(keyword in suggestion_lower for keyword in keywords):
                return action

        return "manual_fix"  # Requires human intervention

    def _get_fallback_suggestion(self, error_pattern: str) -> Dict:
        """Fallback suggestion when other strategies fail."""
        error_lower = error_pattern.lower()

        # Simple pattern matching
        if "build" in error_lower or "compile" in error_lower:
            return {
                "source": "fallback",
                "action": "rebuild",
                "confidence": 0.4,
                "reasoning": "Build-related error detected, suggest rebuild",
            }
        elif "test" in error_lower:
            return {
                "source": "fallback",
                "action": "run_tests",
                "confidence": 0.4,
                "reasoning": "Test-related error, suggest re-running tests",
            }
        elif "lint" in error_lower or "format" in error_lower:
            return {
                "source": "fallback",
                "action": "fix_lint",
                "confidence": 0.5,
                "reasoning": "Lint/format error, suggest running formatter",
            }
        else:
            return {
                "source": "fallback",
                "action": "skip",
                "confidence": 0.3,
                "reasoning": "Unknown error type, manual intervention recommended",
            }

    def _combine_suggestions(self, suggestions: List[Dict]) -> Dict:
        """Combine multiple suggestions into unified recommendation."""
        if not suggestions:
            return {
                "primary_suggestion": {
                    "action": "skip",
                    "confidence": 0.0,
                    "reasoning": "No suggestions available",
                },
                "alternatives": [],
                "confidence": 0.0,
                "sources": [],
                "reasoning": "Unable to generate suggestions",
            }

        # Sort by confidence
        suggestions.sort(key=lambda x: x.get("confidence", 0), reverse=True)

        primary = suggestions[0]
        alternatives = []

        # Collect unique alternative actions
        seen_actions = {primary.get("action")}
        for sugg in suggestions[1:]:
            action = sugg.get("action")
            if action and action not in seen_actions:
                alternatives.append(
                    {
                        "action": action,
                        "confidence": sugg.get("confidence", 0.5),
                        "reasoning": sugg.get("reasoning", ""),
                    }
                )
                seen_actions.add(action)

        # Add alternatives from primary suggestion
        if "alternatives" in primary:
            for alt in primary["alternatives"]:
                action = alt.get("action")
                if action and action not in seen_actions:
                    alternatives.append(alt)
                    seen_actions.add(action)

        # Build combined reasoning
        reasoning_parts = []
        for sugg in suggestions:
            source = sugg.get("source", "unknown")
            reason = sugg.get("reasoning", "")
            if reason:
                reasoning_parts.append(f"[{source}] {reason}")

        return {
            "primary_suggestion": {
                "action": primary.get("action"),
                "confidence": primary.get("confidence", 0.5),
                "reasoning": primary.get("reasoning", ""),
                "auto_execute": primary.get("auto_execute", False),
            },
            "alternatives": alternatives[:3],  # Top 3 alternatives
            "confidence": primary.get("confidence", 0.5),
            "sources": [s.get("source") for s in suggestions],
            "reasoning": "\n".join(reasoning_parts),
            "ai_analysis": primary.get("root_cause") or primary.get("prevention"),
            "system_status": {
                "decision_engine_available": self.decision_engine_available,
                "mcp_available": self.mcp_available,
            },
        }

    def explain_fix(self, action: str) -> Dict:
        """Explain what a fix action does and its risks."""
        action_details = {
            "rebuild": {
                "description": "Rebuild project from current state",
                "risk": "low",
                "time_estimate": "1-2 minutes",
                "side_effects": "None, safe operation",
            },
            "clean_build": {
                "description": "Clean build folder and rebuild from scratch",
                "risk": "low",
                "time_estimate": "2-3 minutes",
                "side_effects": "Removes derived data, longer build time",
            },
            "update_dependencies": {
                "description": "Update project dependencies (SPM/CocoaPods)",
                "risk": "medium",
                "time_estimate": "2-5 minutes",
                "side_effects": "May introduce breaking changes from updated packages",
            },
            "fix_lint": {
                "description": "Run SwiftLint autocorrect",
                "risk": "low",
                "time_estimate": "30 seconds",
                "side_effects": "Modifies source files, commit changes after review",
            },
            "fix_format": {
                "description": "Run SwiftFormat on project",
                "risk": "low",
                "time_estimate": "20 seconds",
                "side_effects": "Reformats code, may affect diffs",
            },
            "run_tests": {
                "description": "Execute test suite",
                "risk": "low",
                "time_estimate": "3-5 minutes",
                "side_effects": "None, validation only",
            },
            "manual_fix": {
                "description": "Requires manual code changes",
                "risk": "variable",
                "time_estimate": "variable",
                "side_effects": "Depends on specific changes needed",
            },
            "skip": {
                "description": "Skip automatic fix, log for manual review",
                "risk": "none",
                "time_estimate": "0 seconds",
                "side_effects": "Issue remains unresolved",
            },
        }

        return action_details.get(
            action,
            {
                "description": f"Unknown action: {action}",
                "risk": "unknown",
                "time_estimate": "unknown",
                "side_effects": "Unknown",
            },
        )


def main():
    """CLI interface for fix suggester."""
    if len(sys.argv) < 2:
        user_log("Usage: fix_suggester.py <command> [arguments]", level="error", stderr=True)
        user_log("\nCommands:", level="error", stderr=True)
        user_log(
            "  suggest <error_pattern> [context_json]  - Suggest fix for error",
            level="error",
            stderr=True,
        )
        user_log(
            "  explain <action>                        - Explain what an action does",
            level="error",
            stderr=True,
        )
        sys.exit(1)

    command = sys.argv[1]
    suggester = FixSuggester()

    if command == "suggest":
        if len(sys.argv) < 3:
            user_log("ERROR: Missing error_pattern argument", level="error", stderr=True)
            sys.exit(1)

        error_pattern = sys.argv[2]
        context = {}
        if len(sys.argv) > 3:
            try:
                context = json.loads(sys.argv[3])
            except json.JSONDecodeError:
                user_log("WARN: Invalid context JSON, ignoring", level="warning", stderr=True)

        result = suggester.suggest_fix(error_pattern, context)
        user_log(json.dumps(result, indent=2))

    elif command == "explain":
        if len(sys.argv) < 3:
            user_log("ERROR: Missing action argument", level="error", stderr=True)
            sys.exit(1)

        action = sys.argv[2]
        result = suggester.explain_fix(action)
        user_log(json.dumps(result, indent=2))

    else:
        user_log(f"ERROR: Unknown command: {command}", level="error", stderr=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
