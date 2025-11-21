#!/usr/bin/env python3
"""
AI Decision Learning System
Tracks decision outcomes and improves recommendations over time
"""

import json
import sqlite3
import time
from typing import Dict, List, Any
from pathlib import Path
import os

class AILearningSystem:
    """Learns from AI decision outcomes to improve future decisions"""
    
    def __init__(self, decisions_db: str = None):
        """Initialize learning system"""
        if decisions_db is None:
            workspace = Path(__file__).parent.parent
            decisions_db = workspace / "monitoring" / "ai_decisions.db"
        
        self.decisions_db = str(decisions_db)
        self._init_db()
    
    def _init_db(self):
        """Ensure learning tables exist"""
        conn = sqlite3.connect(self.decisions_db)
        cursor = conn.cursor()
        
        # Patterns table for learned patterns
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS learned_patterns (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                pattern_type TEXT NOT NULL,
                context_pattern TEXT,
                recommended_decision TEXT,
                success_count INTEGER DEFAULT 0,
                failure_count INTEGER DEFAULT 0,
                confidence_score REAL,
                created_at INTEGER,
                updated_at INTEGER
            )
        """)
        
        conn.commit()
        conn.close()
    
    def record_outcome(self, decision_id: int, outcome: str, 
                      success: bool, feedback: str = None):
        """
        Record the outcome of a decision for learning
        
        Args:
            decision_id: ID of the decision
            outcome: Description of what happened
            success: Whether the decision was successful
            feedback: Optional feedback
        """
        conn = sqlite3.connect(self.decisions_db)
        cursor = conn.cursor()
        
        # Update the decision record
        cursor.execute("""
            UPDATE decisions
            SET outcome = ?, feedback = ?
            WHERE id = ?
        """, (outcome, feedback, decision_id))
        
        # Learn from this outcome
        cursor.execute("""
            SELECT decision_type, context, decision, confidence
            FROM decisions
            WHERE id = ?
        """, (decision_id,))
        
        row = cursor.fetchone()
        if row:
            decision_type, context, decision, confidence = row
            
            # Update or create pattern
            self._update_pattern(
                cursor,
                decision_type=decision_type,
                context=context,
                decision=decision,
                success=success
            )
        
        conn.commit()
        conn.close()
    
    def _update_pattern(self, cursor, decision_type: str, context: str,
                       decision: str, success: bool):
        """Update learned pattern based on outcome"""
        
        # Simplified pattern matching (in production, use ML)
        context_key = self._extract_pattern(context)
        
        # Check if pattern exists
        cursor.execute("""
            SELECT id, success_count, failure_count
            FROM learned_patterns
            WHERE pattern_type = ? AND context_pattern = ? AND recommended_decision = ?
        """, (decision_type, context_key, decision))
        
        row = cursor.fetchone()
        timestamp = int(time.time())
        
        if row:
            # Update existing pattern
            pattern_id, successes, failures = row
            
            if success:
                successes += 1
            else:
                failures += 1
            
            confidence = successes / (successes + failures) if (successes + failures) > 0 else 0.5
            
            cursor.execute("""
                UPDATE learned_patterns
                SET success_count = ?, failure_count = ?, 
                    confidence_score = ?, updated_at = ?
                WHERE id = ?
            """, (successes, failures, confidence, timestamp, pattern_id))
        else:
            # Create new pattern
            successes = 1 if success else 0
            failures = 0 if success else 1
            confidence = successes / (successes + failures)
            
            cursor.execute("""
                INSERT INTO learned_patterns
                (pattern_type, context_pattern, recommended_decision,
                 success_count, failure_count, confidence_score, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, (decision_type, context_key, decision, successes, failures,
                  confidence, timestamp, timestamp))
    
    def _extract_pattern(self, context: str) -> str:
        """Extract simple pattern from context (placeholder for ML)"""
        try:
            ctx = json.loads(context)
            # Simple pattern: just use error_type if present
            if 'error_type' in ctx:
                return f"error:{ctx['error_type']}"
            return "general"
        except:
            return "unknown"
    
    def get_recommendation(self, decision_type: str, context: Dict[str, Any]) -> Dict[str, Any]:
        """
        Get learned recommendation for a decision
        
        Returns recommendation with confidence based on past outcomes
        """
        context_pattern = self._extract_pattern(json.dumps(context))
        
        conn = sqlite3.connect(self.decisions_db)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT recommended_decision, confidence_score, success_count, failure_count
            FROM learned_patterns
            WHERE pattern_type = ? AND context_pattern = ?
            ORDER BY confidence_score DESC, success_count DESC
            LIMIT 1
        """, (decision_type, context_pattern))
        
        row = cursor.fetchone()
        conn.close()
        
        if row:
            decision, confidence, successes, failures = row
            return {
                'recommendation': decision,
                'confidence': confidence,
                'based_on_outcomes': successes + failures,
                'success_rate': successes / (successes + failures) if (successes + failures) > 0 else 0
            }
        
        return None
    
    def get_learning_stats(self) -> Dict[str, Any]:
        """Get statistics about learned patterns"""
        conn = sqlite3.connect(self.decisions_db)
        cursor = conn.cursor()
        
        # Total patterns learned
        cursor.execute("SELECT COUNT(*) FROM learned_patterns")
        total_patterns = cursor.fetchone()[0]
        
        # Patterns by type
        cursor.execute("""
            SELECT pattern_type, COUNT(*) as count, AVG(confidence_score) as avg_confidence
            FROM learned_patterns
            GROUP BY pattern_type
        """)
        
        by_type = [
            {
                'type': row[0],
                'patterns': row[1],
                'avg_confidence': round(row[2], 2) if row[2] else 0
            }
            for row in cursor.fetchall()
        ]
        
        # Total outcomes tracked
        cursor.execute("""
            SELECT COUNT(*) FROM decisions WHERE outcome IS NOT NULL
        """)
        outcomes_tracked = cursor.fetchone()[0]
        
        conn.close()
        
        return {
            'total_patterns': total_patterns,
            'by_type': by_type,
            'outcomes_tracked': outcomes_tracked
        }


def main():
    """CLI for learning system"""
    import argparse
    
    parser = argparse.ArgumentParser(description="AI Decision Learning System")
    parser.add_argument('--stats', action='store_true', help="Show learning statistics")
    parser.add_argument('--record-outcome', type=int, metavar='DECISION_ID',
                       help="Record outcome for a decision")
    parser.add_argument('--outcome', help="Outcome description")
    parser.add_argument('--success', action='store_true', help="Decision was successful")
    parser.add_argument('--feedback', help="Optional feedback")
    
    args = parser.parse_args()
    
    learner = AILearningSystem()
    
    if args.stats:
        stats = learner.get_learning_stats()
        print(json.dumps(stats, indent=2))
    
    elif args.record_outcome:
        if not args.outcome:
            print("Error: --outcome required with --record-outcome")
            return 1
        
        learner.record_outcome(
            decision_id=args.record_outcome,
            outcome=args.outcome,
            success=args.success,
            feedback=args.feedback
        )
        print(f"✅ Recorded outcome for decision {args.record_outcome}")
    
    else:
        parser.print_help()


if __name__ == '__main__':
    main()
