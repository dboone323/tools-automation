#!/usr/bin/env python3
"""
AI Decision Engine
Unified AI interface for autonomous agent decision-making with multi-provider support
"""

import json
import os
import sys
import time
import subprocess
import requests
from typing import Dict, List, Optional, Any, Tuple
from datetime import datetime
import sqlite3
from pathlib import Path

class AIDecisionEngine:
    """Unified AI decision engine for all agents"""
    
    # Provider configuration
    PROVIDERS = {
        'ollama': {
            'endpoint': 'http://127.0.0.1:11434/api/generate',
            'models': ['llama2', 'codellama', 'mistral', 'llama3'],
            'default_model': 'llama2'
        },
        'openai': {
            'endpoint': 'https://api.openai.com/v1/chat/completions',
            'models': ['gpt-4', 'gpt-3.5-turbo'],
            'default_model': 'gpt-3.5-turbo'
        }
    }
    
    def __init__(self, provider: str = 'ollama', model: str = None, 
                 history_db: str = None):
        """Initialize AI decision engine"""
        self.provider = provider
        self.model = model or self.PROVIDERS[provider]['default_model']
        
        # Initialize decision history database
        if history_db is None:
            workspace = self._discover_workspace()
            history_db = os.path.join(workspace, "tools-automation", 
                                     "monitoring", "ai_decisions.db")
        
        os.makedirs(os.path.dirname(history_db), exist_ok=True)
        self.history_db = history_db
        self._init_history_db()
    
    def _discover_workspace(self) -> str:
        """Discover workspace root"""
        try:
            # Try using config discovery
            config_script = Path(__file__).parent.parent / "agents" / "agent_config_discovery.sh"
            if config_script.exists():
                result = subprocess.run(
                    ["bash", str(config_script), "workspace-root"],
                    capture_output=True,
                    text=True
                )
                if result.returncode == 0:
                    return result.stdout.strip()
        except Exception:
            pass
        return os.path.expanduser("~/Desktop/github-projects")
    
    def _init_history_db(self):
        """Initialize decision history database"""
        conn = sqlite3.connect(self.history_db)
        cursor = conn.cursor()
        
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS decisions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp INTEGER NOT NULL,
                agent_name TEXT NOT NULL,
                decision_type TEXT NOT NULL,
                context TEXT,
                prompt TEXT,
                decision TEXT,
                confidence REAL,
                provider TEXT,
                model TEXT,
                execution_time_ms REAL,
                outcome TEXT,
                feedback TEXT
            )
        """)
        
        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_decisions_timestamp 
            ON decisions(timestamp)
        """)
        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_decisions_agent 
            ON decisions(agent_name)
        """)
        
        conn.commit()
        conn.close()
    
    def make_decision(self, agent_name: str, decision_type: str, 
                     context: Dict[str, Any], 
                     options: List[str] = None) -> Dict[str, Any]:
        """
        Make an AI-assisted decision
        
        Args:
            agent_name: Name of the requesting agent
            decision_type: Type of decision (e.g., 'error_recovery', 'task_prioritization')
            context: Context information for the decision
            options: Optional list of predefined options
        
        Returns:
            Decision dictionary with 'decision', 'confidence', 'reasoning'
        """
        start_time = time.time()
        
        # Build prompt based on decision type
        prompt = self._build_prompt(decision_type, context, options)
        
        # Get AI response
        try:
            response = self._query_ai(prompt)
            decision_data = self._parse_ai_response(response, options)
        except Exception as e:
            # Fallback to rule-based decision
            decision_data = self._fallback_decision(decision_type, context, options)
            decision_data['fallback_reason'] = str(e)
        
        execution_time = (time.time() - start_time) * 1000
        
        # Record decision in history
        self._record_decision(
            agent_name=agent_name,
            decision_type=decision_type,
            context=json.dumps(context),
            prompt=prompt,
            decision=decision_data['decision'],
            confidence=decision_data['confidence'],
            execution_time_ms=execution_time
        )
        
        decision_data['execution_time_ms'] = execution_time
        return decision_data
    
    def _build_prompt(self, decision_type: str, context: Dict[str, Any],
                     options: List[str] = None) -> str:
        """Build AI prompt based on decision type"""
        
        base_prompt = f"""You are an autonomous agent decision system. 
Make a decision based on the following information.

Decision Type: {decision_type}
Context: {json.dumps(context, indent=2)}
"""
        
        if options:
            base_prompt += f"\nAvailable Options:\n"
            for i, opt in enumerate(options, 1):
                base_prompt += f"{i}. {opt}\n"
            base_prompt += "\nSelect the best option number."
        
        # Add type-specific guidance
        if decision_type == 'error_recovery':
            base_prompt += """
Analyze the error and suggest the best recovery action.
Consider: error type, frequency, impact, and available remediation options.
Respond with: {"decision": "action", "confidence": 0.0-1.0, "reasoning": "why"}
"""
        elif decision_type == 'task_prioritization':
            base_prompt += """
Prioritize the given tasks based on: urgency, dependencies, impact, and resource availability.
Respond with: {"decision": "priority_order", "confidence": 0.0-1.0, "reasoning": "why"}
"""
        elif decision_type == 'build_failure_diagnosis':
            base_prompt += """
Analyze the build failure and suggest the root cause and fix.
Respond with: {"decision": "diagnosis_and_fix", "confidence": 0.0-1.0, "reasoning": "analysis"}
"""
        else:
            base_prompt += """
Analyze the situation and make the best decision.
Respond with: {"decision": "your_decision", "confidence": 0.0-1.0, "reasoning": "explanation"}
"""
        
        return base_prompt
    
    def _query_ai(self, prompt: str, timeout: int = 30) -> str:
        """Query AI provider"""
        if self.provider == 'ollama':
            return self._query_ollama(prompt, timeout)
        elif self.provider == 'openai':
            return self._query_openai(prompt, timeout)
        else:
            raise ValueError(f"Unsupported provider: {self.provider}")
    
    def _query_ollama(self, prompt: str, timeout: int) -> str:
        """Query Ollama local LLM"""
        endpoint = self.PROVIDERS['ollama']['endpoint']
        
        payload = {
            "model": self.model,
            "prompt": prompt,
            "stream": False,
            "options": {
                "temperature": 0.7,
                "top_p": 0.9
            }
        }
        
        response = requests.post(endpoint, json=payload, timeout=timeout)
        response.raise_for_status()
        
        result = response.json()
        return result.get('response', '')
    
    def _query_openai(self, prompt: str, timeout: int) -> str:
        """Query OpenAI API"""
        api_key = os.environ.get('OPENAI_API_KEY')
        if not api_key:
            raise ValueError("OPENAI_API_KEY environment variable not set")
        
        endpoint = self.PROVIDERS['openai']['endpoint']
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }
        
        payload = {
            "model": self.model,
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.7
        }
        
        response = requests.post(endpoint, headers=headers, json=payload, timeout=timeout)
        response.raise_for_status()
        
        result = response.json()
        return result['choices'][0]['message']['content']
    
    def _parse_ai_response(self, response: str, options: List[str] = None) -> Dict[str, Any]:
        """Parse AI response into structured decision"""
        try:
            # Try to parse as JSON
            decision_data = json.loads(response)
            
            # Validate required fields
            if 'decision' not in decision_data:
                decision_data['decision'] = response[:200]
            if 'confidence' not in decision_data:
                decision_data['confidence'] = 0.7
            if 'reasoning' not in decision_data:
                decision_data['reasoning'] = "AI decision"
            
            # Ensure confidence is in valid range
            decision_data['confidence'] = max(0.0, min(1.0, decision_data['confidence']))
            
            return decision_data
        except json.JSONDecodeError:
            # Fallback: extract decision from text
            return {
                'decision': response[:200],
                'confidence': 0.6,
                'reasoning': 'Extracted from text response'
            }
    
    def _fallback_decision(self, decision_type: str, context: Dict[str, Any],
                          options: List[str] = None) -> Dict[str, Any]:
        """Rule-based fallback decision when AI is unavailable"""
        
        if decision_type == 'error_recovery':
            # Simple heuristic: retry for network/timeout errors, restart for crashes
            error_type = context.get('error_type', '').lower()
            if 'network' in error_type or 'timeout' in error_type:
                return {
                    'decision': 'retry_with_backoff',
                    'confidence': 0.7,
                    'reasoning': 'Rule-based: Network/timeout errors typically benefit from retry'
                }
            elif 'crash' in error_type or 'segfault' in error_type:
                return {
                    'decision': 'restart_agent',
                    'confidence': 0.8,
                    'reasoning': 'Rule-based: Crash errors require agent restart'
                }
            else:
                return {
                    'decision': 'log_and_continue',
                    'confidence': 0.5,
                    'reasoning': 'Rule-based: Unknown error, proceed with caution'
                }
        
        elif decision_type == 'task_prioritization':
            # Simple heuristic: prioritize by explicit priority field
            tasks = context.get('tasks', [])
            prioritized = sorted(tasks, key=lambda t: t.get('priority', 5), reverse=True)
            return {
                'decision': json.dumps([t.get('id') for t in prioritized]),
                'confidence': 0.6,
                'reasoning': 'Rule-based: Sorted by priority field'
            }
        
        elif options and len(options) > 0:
            # Default to first option
            return {
                'decision': options[0],
                'confidence': 0.5,
                'reasoning': 'Rule-based: Selected first available option'
            }
        
        return {
            'decision': 'no_action',
            'confidence': 0.3,
            'reasoning': 'Rule-based: Insufficient information for decision'
        }
    
    def _record_decision(self, agent_name: str, decision_type: str,
                        context: str, prompt: str, decision: str,
                        confidence: float, execution_time_ms: float):
        """Record decision in history database"""
        conn = sqlite3.connect(self.history_db)
        cursor = conn.cursor()
        
        cursor.execute("""
            INSERT INTO decisions
            (timestamp, agent_name, decision_type, context, prompt, decision,
             confidence, provider, model, execution_time_ms)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            int(time.time()),
            agent_name,
            decision_type,
            context,
            prompt,
            decision,
            confidence,
            self.provider,
            self.model,
            execution_time_ms
        ))
        
        conn.commit()
        conn.close()
    
    def record_outcome(self, decision_id: int, outcome: str, feedback: str = None):
        """Record outcome of a decision for learning"""
        conn = sqlite3.connect(self.history_db)
        cursor = conn.cursor()
        
        cursor.execute("""
            UPDATE decisions
            SET outcome = ?, feedback = ?
            WHERE id = ?
        """, (outcome, feedback, decision_id))
        
        conn.commit()
        conn.close()
    
    def get_decision_history(self, agent_name: str = None, 
                            decision_type: str = None,
                            hours: int = 24) -> List[Dict[str, Any]]:
        """Get decision history"""
        conn = sqlite3.connect(self.history_db)
        cursor = conn.cursor()
        
        query = "SELECT * FROM decisions WHERE timestamp > ?"
        params = [int(time.time()) - (hours * 3600)]
        
        if agent_name:
            query += " AND agent_name = ?"
            params.append(agent_name)
        
        if decision_type:
            query += " AND decision_type = ?"
            params.append(decision_type)
        
        query += " ORDER BY timestamp DESC"
        
        cursor.execute(query, params)
        
        columns = [desc[0] for desc in cursor.description]
        results = []
        for row in cursor.fetchall():
            results.append(dict(zip(columns, row)))
        
        conn.close()
        return results
    
    def get_decision_metrics(self, hours: int = 24) -> Dict[str, Any]:
        """Get metrics about AI decisions"""
        conn = sqlite3.connect(self.history_db)
        cursor = conn.cursor()
        
        since_timestamp = int(time.time()) - (hours * 3600)
        
        # Overall metrics
        cursor.execute("""
            SELECT 
                COUNT(*) as total_decisions,
                AVG(confidence) as avg_confidence,
                AVG(execution_time_ms) as avg_execution_time,
                COUNT(CASE WHEN outcome = 'success' THEN 1 END) as successful_outcomes
            FROM decisions
            WHERE timestamp > ?
        """, (since_timestamp,))
        
        overall = cursor.fetchone()
        
        # By decision type
        cursor.execute("""
            SELECT decision_type, COUNT(*) as count, AVG(confidence) as avg_confidence
            FROM decisions
            WHERE timestamp > ?
            GROUP BY decision_type
            ORDER BY count DESC
        """, (since_timestamp,))
        
        by_type = [{'type': row[0], 'count': row[1], 'avg_confidence': row[2]}
                   for row in cursor.fetchall()]
        
        # By agent
        cursor.execute("""
            SELECT agent_name, COUNT(*) as count
            FROM decisions
            WHERE timestamp > ?
            GROUP BY agent_name
            ORDER BY count DESC
            LIMIT 10
        """, (since_timestamp,))
        
        by_agent = [{'agent': row[0], 'count': row[1]}
                    for row in cursor.fetchall()]
        
        conn.close()
        
        return {
            'period_hours': hours,
            'total_decisions': overall[0] or 0,
            'avg_confidence': round(overall[1] or 0, 2),
            'avg_execution_time_ms': round(overall[2] or 0, 2),
            'successful_outcomes': overall[3] or 0,
            'success_rate': round((overall[3] or 0) / (overall[0] or 1) * 100, 2),
            'by_type': by_type,
            'by_agent': by_agent
        }


def main():
    """CLI interface for AI decision engine"""
    import argparse
    
    parser = argparse.ArgumentParser(description="AI Decision Engine")
    parser.add_argument('--provider', choices=['ollama', 'openai'], 
                       default='ollama', help="AI provider")
    parser.add_argument('--model', help="Model name")
    parser.add_argument('--agent', required=True, help="Agent name")
    parser.add_argument('--type', required=True, help="Decision type")
    parser.add_argument('--context', help="Context JSON")
    parser.add_argument('--options', nargs='+', help="Available options")
    parser.add_argument('--history', action='store_true', help="Show decision history")
    parser.add_argument('--metrics', action='store_true', help="Show decision metrics")
    parser.add_argument('--hours', type=int, default=24, help="Hours for history/metrics")
    
    args = parser.parse_args()
    
    engine = AIDecisionEngine(provider=args.provider, model=args.model)
    
    if args.history:
        history = engine.get_decision_history(
            agent_name=args.agent if args.agent != 'all' else None,
            hours=args.hours
        )
        print(json.dumps(history, indent=2))
    
    elif args.metrics:
        metrics = engine.get_decision_metrics(hours=args.hours)
        print(f"\n📊 AI Decision Metrics (last {args.hours} hours)")
        print("=" * 60)
        print(f"Total Decisions: {metrics['total_decisions']}")
        print(f"Avg Confidence: {metrics['avg_confidence']}")
        print(f"Avg Execution Time: {metrics['avg_execution_time_ms']:.2f}ms")
        print(f"Success Rate: {metrics['success_rate']}%")
        print(f"\nBy Type: {json.dumps(metrics['by_type'], indent=2)}")
        print(f"\nTop Agents: {json.dumps(metrics['by_agent'], indent=2)}")
    
    else:
        # Make a decision
        context = json.loads(args.context) if args.context else {}
        
        decision = engine.make_decision(
            agent_name=args.agent,
            decision_type=args.type,
            context=context,
            options=args.options
        )
        
        print(json.dumps(decision, indent=2))


if __name__ == '__main__':
    main()
