#!/usr/bin/env python3
"""
AI/ML Tools Integration Demo
Demonstrates the implementation of all AI/ML tools from FREE_TOOLS_REFERENCE.md
"""

import sys
import os

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from ai_code_reviewer import AICodeReviewer
from langchain_agent_orchestrator import LangChainAgentOrchestrator
from agent_performance_analyzer import AgentPerformanceAnalyzer
from umami_analytics import AgentAnalyticsTracker


def demo_ai_code_reviewer():
    """Demonstrate AI code reviewer using transformers"""
    print("🔍 AI Code Reviewer Demo")
    print("=" * 50)

    reviewer = AICodeReviewer()

    sample_code = '''
def process_user_data(user_data):
    """Process user information from API"""
    if user_data is None:
        return None

    processed = {
        "name": user_data.get("name", "").strip(),
        "email": user_data.get("email", "").lower(),
        "age": int(user_data.get("age", 0))
    }

    # Validate email format
    if "@" not in processed["email"]:
        return None

    return processed
'''

    print("Analyzing sample code...")
    result = reviewer.generate_review_summary(sample_code)

    print(f"Overall Score: {result['overall_score']}/10")
    print(
        f"Sentiment: {result['sentiment']['sentiment']} ({result['sentiment']['confidence']:.2f})"
    )
    print(f"Bugs Found: {result['bugs_found']}")

    if result["recommendations"]:
        print("\nRecommendations:")
        for rec in result["recommendations"]:
            print(f"• {rec}")

    print("\n" + "=" * 50 + "\n")


def demo_langchain_orchestrator():
    """Demonstrate LangChain agent orchestration"""
    print("🤖 LangChain Agent Orchestrator Demo")
    print("=" * 50)

    try:
        orchestrator = LangChainAgentOrchestrator()

        # Sample task
        task = {
            "id": "demo_task_001",
            "type": "code_review",
            "description": "Review authentication module for security vulnerabilities and best practices",
        }

        print("Processing task with LangChain agent...")
        result = orchestrator.process_task(task)

        print(f"Status: {result['status']}")
        print(f"Task ID: {result['task_id']}")
        print(f"Agent Analysis: {result['agent_analysis'][:200]}...")

        # Generate workflow summary
        tasks = [
            {"type": "code_generation", "description": "Generate API endpoints"},
            {"type": "testing", "description": "Run unit tests"},
            {"type": "deployment", "description": "Deploy to staging"},
        ]

        print("\nGenerating workflow summary...")
        summary = orchestrator.generate_task_summary(tasks)
        print(f"Summary: {summary[:300]}...")

    except Exception as e:
        print(f"LangChain demo failed (likely due to missing Ollama): {e}")

    print("\n" + "=" * 50 + "\n")


def demo_performance_analyzer():
    """Demonstrate scikit-learn performance analysis"""
    print("📊 Agent Performance Analyzer Demo")
    print("=" * 50)

    analyzer = AgentPerformanceAnalyzer()

    print("Loading performance data...")
    df = analyzer.load_performance_data()

    print(f"Loaded {len(df)} performance records")

    print("Training models...")
    perf_results = analyzer.train_performance_model(df)
    failure_results = analyzer.train_failure_predictor(df)

    print(f"Performance Model RMSE: {perf_results['rmse']:.2f}")
    print(f"Failure Predictor Accuracy: {failure_results['accuracy']:.2f}")

    # Make predictions
    predicted_time = analyzer.predict_execution_time(
        "agent_codegen", "code_generation", 65.0, 70.0, 7
    )
    print(f"Predicted execution time for code generation: {predicted_time:.2f} seconds")

    failure_prob = analyzer.predict_failure_probability(
        "agent_deployment", "deployment", 80.0, 85.0, 8
    )
    print(f"Failure probability for deployment: {failure_prob:.2f}")

    # Generate report
    report = analyzer.generate_performance_report(df)
    print("\nPerformance Report Summary:")
    print(f"• Total tasks: {report['summary']['total_tasks']}")
    print(f"• Success rate: {report['summary']['overall_success_rate']:.1%}")
    print(
        f"• Average execution time: {report['summary']['average_execution_time']:.2f}s"
    )

    print("\n" + "=" * 50 + "\n")


def demo_umami_analytics():
    """Demonstrate Umami analytics integration"""
    print("📈 Umami Analytics Demo")
    print("=" * 50)

    tracker = AgentAnalyticsTracker()

    print("Initializing analytics tracking...")
    if tracker.initialize_tracking():
        print("✅ Analytics initialized successfully!")

        # Track some sample events
        print("Tracking sample events...")
        tracker.track_agent_execution("demo_agent", "code_review", 15.2, True)
        tracker.track_system_metrics(45.5, 62.1, 3)
        tracker.track_error("demo_agent", "timeout", "Operation timed out")

        # Generate report
        report = tracker.get_analytics_report(days=1)
        print(f"Analytics Report: {report.get('total_events', 0)} events tracked")

        # Generate tracking script
        script = tracker.generate_tracking_script()
        print("Generated tracking script for dashboards")

        print("\n🚀 Umami server is running at: http://localhost:3000")
        print("📊 View analytics dashboard in your browser")

    else:
        print("❌ Failed to initialize analytics")

    print("\n" + "=" * 50 + "\n")


def main():
    """Run all AI/ML tools demonstrations"""
    print("🚀 AI/ML Tools Integration Demo")
    print("Demonstrating all implemented tools from FREE_TOOLS_REFERENCE.md")
    print("=" * 70)

    # Check if required packages are available
    try:
        import transformers
        import langchain
        import sklearn

        print("✅ All required packages are installed")
    except ImportError as e:
        print(f"❌ Missing required packages: {e}")
        print("Please run: pip install transformers langchain scikit-learn")
        return

    print("\nStarting demonstrations...\n")

    # Run demos
    demo_ai_code_reviewer()
    demo_langchain_orchestrator()
    demo_performance_analyzer()
    demo_umami_analytics()

    print("🎉 All demonstrations completed!")
    print("\nNext steps:")
    print("1. Access Umami analytics at: http://localhost:3000")
    print("2. Review generated analytics files: umami_events.log, umami_websites.json")
    print("3. Check performance data in agent_performance_analyzer.py output")
    print("4. Integrate these tools into your agent workflows")


if __name__ == "__main__":
    main()
