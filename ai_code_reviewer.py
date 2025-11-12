#!/usr/bin/env python3
"""
AI Code Review Agent using Hugging Face Transformers
Provides automated code review with sentiment analysis and bug detection
"""

import re
from typing import Dict, List, Tuple

try:
    from transformers import pipeline

    TRANSFORMERS_AVAILABLE = True
except ImportError:
    TRANSFORMERS_AVAILABLE = False
    print("Warning: transformers not available, using fallback analysis")


class AICodeReviewer:
    """AI-powered code review using transformers"""

    def __init__(self):
        """Initialize the AI code reviewer with pre-trained models"""
        if TRANSFORMERS_AVAILABLE:
            try:
                # Sentiment analysis for code quality assessment
                self.sentiment_analyzer = pipeline(
                    "sentiment-analysis",
                    model="cardiffnlp/twitter-roberta-base-sentiment-latest",
                )

                # Text classification for bug detection
                self.bug_detector = pipeline(
                    "text-classification", model="microsoft/DialoGPT-medium"
                )

            except Exception as e:
                print(f"Warning: Could not load AI models: {e}")
                print("Falling back to rule-based analysis")
                self.sentiment_analyzer = None
                self.bug_detector = None
        else:
            print("Transformers not available, using rule-based analysis only")
            self.sentiment_analyzer = None
            self.bug_detector = None

    def analyze_code_sentiment(self, code: str) -> Dict:
        """Analyze code quality using sentiment analysis"""
        if not self.sentiment_analyzer:
            return {"sentiment": "neutral", "confidence": 0.5}

        # Extract meaningful comments and function names for analysis
        analysis_text = self._extract_analysis_text(code)

        try:
            result = self.sentiment_analyzer(analysis_text)[0]
            return {"sentiment": result["label"].lower(), "confidence": result["score"]}
        except Exception as e:
            print(f"Sentiment analysis failed: {e}")
            return {"sentiment": "neutral", "confidence": 0.5}

    def detect_potential_bugs(self, code: str) -> List[Dict]:
        """Detect potential bugs using pattern recognition"""
        bugs = []

        # Rule-based bug detection (fallback when AI models aren't available)
        lines = code.split("\n")

        for i, line in enumerate(lines, 1):
            # Check for common Python issues
            if "==" in line and "if " in line and "is " not in line:
                # Potential identity vs equality confusion
                if re.search(r"\bif\s+.*==.*None\b", line):
                    bugs.append(
                        {
                            "line": i,
                            "type": "identity_check",
                            "message": "Use 'is None' instead of '== None'",
                            "severity": "medium",
                        }
                    )

            # Check for unused variables
            if re.search(r"\b\w+\s*=\s*[^=]*$", line.strip()):
                var_match = re.search(r"\b(\w+)\s*=", line.strip())
                if var_match:
                    var_name = var_match.group(1)
                    # Check if variable is used later (simple heuristic)
                    remaining_code = "\n".join(lines[i:])
                    if var_name not in remaining_code:
                        bugs.append(
                            {
                                "line": i,
                                "type": "unused_variable",
                                "message": f"Variable '{var_name}' appears to be unused",
                                "severity": "low",
                            }
                        )

        return bugs

    def generate_review_summary(self, code: str) -> Dict:
        """Generate a comprehensive code review summary"""
        sentiment = self.analyze_code_sentiment(code)
        bugs = self.detect_potential_bugs(code)

        # Calculate overall score
        base_score = 8.0  # Start with good score

        # Adjust score based on sentiment
        if sentiment["sentiment"] == "negative":
            base_score -= 2.0
        elif sentiment["sentiment"] == "positive":
            base_score += 0.5

        # Adjust score based on bugs
        high_severity = len([b for b in bugs if b["severity"] == "high"])
        medium_severity = len([b for b in bugs if b["severity"] == "medium"])

        base_score -= high_severity * 1.0
        base_score -= medium_severity * 0.5

        # Ensure score is within bounds
        final_score = max(0.0, min(10.0, base_score))

        return {
            "overall_score": round(final_score, 1),
            "sentiment": sentiment,
            "bugs_found": len(bugs),
            "bug_details": bugs,
            "recommendations": self._generate_recommendations(sentiment, bugs),
        }

    def _extract_analysis_text(self, code: str) -> str:
        """Extract meaningful text for sentiment analysis"""
        lines = code.split("\n")
        analysis_parts = []

        for line in lines:
            line = line.strip()
            if line.startswith("#") or line.startswith('"""') or line.startswith("'''"):
                # Comments and docstrings
                analysis_parts.append(line)
            elif "def " in line or "class " in line:
                # Function and class definitions
                analysis_parts.append(line)

        return " ".join(analysis_parts) if analysis_parts else code[:500]

    def _generate_recommendations(self, sentiment: Dict, bugs: List[Dict]) -> List[str]:
        """Generate improvement recommendations"""
        recommendations = []

        if sentiment["sentiment"] == "negative" and sentiment["confidence"] > 0.7:
            recommendations.append("Consider refactoring for better code clarity")

        if bugs:
            recommendations.append(f"Address {len(bugs)} potential issues found")
            if any(b["severity"] == "high" for b in bugs):
                recommendations.append("Fix high-severity issues before deployment")

        if not recommendations:
            recommendations.append(
                "Code looks good! Consider adding more documentation"
            )

        return recommendations


def review_file(file_path: str) -> Dict:
    """Review a single file using AI code reviewer"""
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            code = f.read()

        reviewer = AICodeReviewer()
        return reviewer.generate_review_summary(code)

    except Exception as e:
        return {
            "error": f"Failed to review file: {e}",
            "overall_score": 0.0,
            "bugs_found": 0,
        }


if __name__ == "__main__":
    # Example usage
    sample_code = '''
def calculate_total(items):
    """Calculate total price of items"""
    total = 0
    for item in items:
        total += item.price
    return total

class ShoppingCart:
    def __init__(self):
        self.items = []

    def add_item(self, item):
        self.items.append(item)

    def get_total(self):
        return calculate_total(self.items)
'''

    reviewer = AICodeReviewer()
    result = reviewer.generate_review_summary(sample_code)

    print("AI Code Review Results:")
    print(f"Overall Score: {result['overall_score']}/10")
    print(
        f"Sentiment: {result['sentiment']['sentiment']} ({result['sentiment']['confidence']:.2f})"
    )
    print(f"Bugs Found: {result['bugs_found']}")

    if result["bug_details"]:
        print("\nIssues Found:")
        for bug in result["bug_details"]:
            print(f"  Line {bug['line']}: {bug['message']} ({bug['severity']})")

    print(f"\nRecommendations: {', '.join(result['recommendations'])}")
