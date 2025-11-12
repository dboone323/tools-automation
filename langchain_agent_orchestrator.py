#!/usr/bin/env python3
"""
LangChain Integration for Agent Workflows
Provides LLM-powered task processing and agent coordination
"""

import os
import json
from typing import Dict, List, Optional, Any

try:
    from langchain.llms import Ollama
    from langchain.chains import LLMChain
    from langchain.prompts import PromptTemplate
    from langchain.agents import Tool, AgentExecutor, LLMSingleActionAgent
    from langchain.memory import ConversationBufferMemory
    from langchain.schema import BaseLanguageModel

    LANGCHAIN_AVAILABLE = True
except ImportError:
    LANGCHAIN_AVAILABLE = False
    print("Warning: langchain not available, using fallback processing")


class LangChainAgentOrchestrator:
    """LangChain-powered agent orchestration system"""

    def __init__(self, model_name: str = "llama2"):
        """Initialize with Ollama LLM"""
        if LANGCHAIN_AVAILABLE:
            self.llm = Ollama(model=model_name, temperature=0.1)
            self.memory = ConversationBufferMemory(memory_key="chat_history")

            # Initialize agent tools
            self.tools = self._initialize_tools()

            # Create the agent
            self.agent_executor = self._create_agent()
        else:
            print("LangChain not available, using basic processing")
            self.llm = None
            self.memory = None
            self.tools = []
            self.agent_executor = None

    def _initialize_tools(self) -> List:
        """Initialize tools for the agent"""
        if not LANGCHAIN_AVAILABLE:
            return []

        tools = []

        # Task analysis tool
        def analyze_task(task_description: str) -> str:
            """Analyze a task and determine the best agent to handle it"""
            prompt = PromptTemplate(
                input_variables=["task"],
                template="""
                Analyze this task and determine which type of agent should handle it.
                Task categories: codegen, testing, documentation, deployment, monitoring, security

                Task: {task}

                Return only the category name (one word).
                """,
            )
            chain = LLMChain(llm=self.llm, prompt=prompt)
            return chain.run(task=task_description).strip().lower()

        tools.append(
            Tool(
                name="TaskAnalyzer",
                description="Analyze tasks to determine the appropriate agent type",
                func=analyze_task,
            )
        )

        # Code review tool
        def review_code(code: str) -> str:
            """Review code for quality and bugs"""
            prompt = PromptTemplate(
                input_variables=["code"],
                template="""
                Review this code for:
                1. Potential bugs
                2. Code quality issues
                3. Best practices
                4. Security concerns

                Code:
                {code}

                Provide a concise review with specific recommendations.
                """,
            )
            chain = LLMChain(llm=self.llm, prompt=prompt)
            return chain.run(code=code)

        tools.append(
            Tool(
                name="CodeReviewer",
                description="Review code for quality, bugs, and best practices",
                func=review_code,
            )
        )

        # Documentation generator
        def generate_docs(function_code: str) -> str:
            """Generate documentation for code"""
            prompt = PromptTemplate(
                input_variables=["code"],
                template="""
                Generate comprehensive documentation for this function/class.
                Include:
                - Purpose and functionality
                - Parameters and return values
                - Usage examples
                - Edge cases

                Code:
                {code}

                Format as Markdown.
                """,
            )
            chain = LLMChain(llm=self.llm, prompt=prompt)
            return chain.run(code=function_code)

        tools.append(
            Tool(
                name="DocGenerator",
                description="Generate documentation for code functions and classes",
                func=generate_docs,
            )
        )

        return tools

    def _create_agent(self):
        """Create the LangChain agent"""
        if not LANGCHAIN_AVAILABLE:
            return None

        from langchain.agents import initialize_agent, AgentType

        return initialize_agent(
            tools=self.tools,
            llm=self.llm,
            agent=AgentType.CONVERSATIONAL_REACT_DESCRIPTION,
            memory=self.memory,
            verbose=True,
            max_iterations=3,
        )

    def process_task(self, task: Dict) -> Dict:
        """Process a task using LangChain agent"""
        if not LANGCHAIN_AVAILABLE or not self.agent_executor:
            # Fallback processing without LangChain
            task_description = task.get("description", "")
            task_type = task.get("type", "unknown")

            # Simple rule-based analysis
            if "code" in task_description.lower():
                agent_type = "codegen"
            elif "test" in task_description.lower():
                agent_type = "testing"
            elif "deploy" in task_description.lower():
                agent_type = "deployment"
            else:
                agent_type = "general"

            return {
                "status": "processed",
                "agent_analysis": f"Task categorized as: {agent_type}. Basic processing completed.",
                "task_id": task.get("id"),
                "processed_at": self._get_timestamp(),
            }

        try:
            task_description = task.get("description", "")
            task_type = task.get("type", "unknown")

            # Use agent to analyze and process task
            agent_input = f"""
            Task Type: {task_type}
            Description: {task_description}

            Please analyze this task and provide:
            1. The most appropriate agent to handle it
            2. Any preprocessing steps needed
            3. Expected outcomes
            """

            response = self.agent_executor.run(agent_input)

            return {
                "status": "processed",
                "agent_analysis": response,
                "task_id": task.get("id"),
                "processed_at": self._get_timestamp(),
            }

        except Exception as e:
            return {"status": "error", "error": str(e), "task_id": task.get("id")}

    def generate_task_summary(self, tasks: List[Dict]) -> str:
        """Generate a summary of multiple tasks using LLM"""
        tasks_text = "\n".join(
            [
                f"- {task.get('type', 'unknown')}: {task.get('description', '')[:100]}..."
                for task in tasks
            ]
        )

        prompt = PromptTemplate(
            input_variables=["tasks"],
            template="""
            Analyze these tasks and provide a summary:

            Tasks:
            {tasks}

            Summary should include:
            - Total number of tasks
            - Task categories breakdown
            - Priority recommendations
            - Resource allocation suggestions
            """,
        )

        chain = LLMChain(llm=self.llm, prompt=prompt)
        return chain.run(tasks=tasks_text)

    def optimize_workflow(self, workflow_data: Dict) -> Dict:
        """Optimize agent workflow using LLM analysis"""
        prompt = PromptTemplate(
            input_variables=["workflow"],
            template="""
            Analyze this workflow and suggest optimizations:

            Current Workflow:
            {workflow}

            Provide suggestions for:
            1. Parallel processing opportunities
            2. Bottleneck identification
            3. Resource optimization
            4. Error handling improvements
            """,
        )

        chain = LLMChain(llm=self.llm, prompt=prompt)
        suggestions = chain.run(workflow=json.dumps(workflow_data, indent=2))

        return {
            "original_workflow": workflow_data,
            "optimizations": suggestions,
            "generated_at": self._get_timestamp(),
        }

    def _get_timestamp(self) -> str:
        """Get current timestamp"""
        from datetime import datetime

        return datetime.now().isoformat()


class TaskProcessor:
    """High-level task processing with LangChain integration"""

    def __init__(self):
        self.orchestrator = LangChainAgentOrchestrator()

    def process_task_queue(self, queue_file: str = "task_queue.json") -> Dict:
        """Process all tasks in the queue"""
        try:
            with open(queue_file, "r") as f:
                queue_data = json.load(f)

            tasks = queue_data.get("tasks", [])
            pending_tasks = [t for t in tasks if t.get("status") == "pending"]

            processed_results = []
            for task in pending_tasks:
                result = self.orchestrator.process_task(task)
                processed_results.append(result)

                # Update task status
                task["status"] = "processed"
                task["processed_at"] = result.get("processed_at")

            # Save updated queue
            with open(queue_file, "w") as f:
                json.dump(queue_data, f, indent=2)

            # Generate summary
            summary = self.orchestrator.generate_task_summary(processed_results)

            return {
                "processed_count": len(processed_results),
                "summary": summary,
                "results": processed_results,
            }

        except Exception as e:
            return {"error": f"Failed to process task queue: {e}", "processed_count": 0}


def main():
    """Example usage of LangChain agent orchestration"""
    processor = TaskProcessor()

    # Example task
    sample_task = {
        "id": "task_001",
        "type": "code_review",
        "description": "Review the authentication module for security vulnerabilities",
        "status": "pending",
    }

    print("Processing task with LangChain agent...")
    result = processor.orchestrator.process_task(sample_task)

    print(f"Task Status: {result['status']}")
    print(f"Agent Analysis: {result['agent_analysis'][:200]}...")

    # Generate workflow optimization
    workflow_data = {
        "agents": ["codegen", "testing", "deployment"],
        "current_load": {"codegen": 5, "testing": 3, "deployment": 1},
        "bottlenecks": ["testing_queue"],
    }

    optimization = processor.orchestrator.optimize_workflow(workflow_data)
    print(
        f"\nWorkflow Optimization Suggestions: {optimization['optimizations'][:300]}..."
    )


if __name__ == "__main__":
    main()
