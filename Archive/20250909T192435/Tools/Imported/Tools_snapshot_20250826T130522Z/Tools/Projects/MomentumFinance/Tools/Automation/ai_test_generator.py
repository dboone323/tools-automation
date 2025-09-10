#!/usr/bin/env python3
"""
🧪 AI Learning Test Scenario Generator
Creates diverse test scenarios to validate AI learning capabilities
"""

import json
import random
from datetime import datetime, timedelta
import os
import sys
from pathlib import Path

class AILearningTestGenerator:
    def __init__(self, base_dir="/Users/danielstevens/Desktop/Code"):
        self.base_dir = Path(base_dir)
        self.projects = ["CodingReviewer", "HabitQuest", "MomentumFinance"]
        self.platforms = {
            "CodingReviewer": "macOS",
            "HabitQuest": "iOS", 
            "MomentumFinance": "Universal"
        }
        
    def generate_test_scenarios(self, count=10):
        """Generate diverse test scenarios for AI learning validation"""
        scenarios = []
        
        # Error types and patterns
        error_types = [
            "build_failure", "test_failure", "deployment_failure",
            "dependency_issue", "configuration_error", "syntax_error",
            "environment_issue", "resource_conflict", "timeout_error",
            "permission_denied"
        ]
        
        # Success patterns
        fix_patterns = [
            "dependency_update", "config_correction", "syntax_fix",
            "environment_setup", "permission_fix", "timeout_increase",
            "resource_allocation", "cache_clear", "rebuild_clean",
            "tool_upgrade"
        ]
        
        for i in range(count):
            scenario = {
                "test_id": f"scenario_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{i:03d}",
                "timestamp": (datetime.now() - timedelta(hours=random.randint(1, 72))).isoformat(),
                "project": random.choice(self.projects),
                "error_type": random.choice(error_types),
                "fix_pattern": random.choice(fix_patterns),
                "success_rate": random.uniform(0.6, 1.0),
                "complexity_score": random.randint(1, 10),
                "learning_weight": random.uniform(0.1, 1.0),
                "context": self._generate_context(),
                "expected_outcome": "resolved" if random.random() > 0.1 else "needs_attention"
            }
            scenarios.append(scenario)
            
        return scenarios
    
    def _generate_context(self):
        """Generate realistic context for test scenarios"""
        contexts = [
            "Swift compilation error in main view controller",
            "iOS deployment target mismatch",
            "Xcode build configuration issue", 
            "CocoaPods dependency conflict",
            "macOS notarization failure",
            "Unit test timeout in CI environment",
            "GitHub Actions workflow permission issue",
            "Memory leak in release build",
            "App Store Connect upload failure",
            "Code signing certificate expired"
        ]
        return random.choice(contexts)
    
    def create_learning_data(self, project_name, scenario_count=5):
        """Create learning data for a specific project"""
        project_path = self.base_dir / "Projects" / project_name
        learning_dir = project_path / ".ai_learning_system"
        
        # Create learning directory if it doesn't exist
        learning_dir.mkdir(exist_ok=True)
        
        # Generate test scenarios
        scenarios = self.generate_test_scenarios(scenario_count)
        
        # Create learning database files
        for scenario in scenarios:
            # Fix history
            fix_history = {
                "fix_id": scenario["test_id"],
                "timestamp": scenario["timestamp"],
                "project": project_name,
                "platform": self.platforms.get(project_name, "Unknown"),
                "error_pattern": {
                    "type": scenario["error_type"],
                    "context": scenario["context"],
                    "complexity": scenario["complexity_score"]
                },
                "solution_pattern": {
                    "method": scenario["fix_pattern"],
                    "success_rate": scenario["success_rate"],
                    "confidence": scenario["learning_weight"]
                },
                "outcome": {
                    "status": scenario["expected_outcome"],
                    "learning_value": scenario["learning_weight"],
                    "reproducible": random.random() > 0.3
                }
            }
            
            # Save fix history
            fix_file = learning_dir / f"fix_history_{scenario['test_id']}.json"
            with open(fix_file, 'w') as f:
                json.dump(fix_history, f, indent=2)
            
            # Pattern correlation
            pattern_correlation = {
                "pattern_id": f"pattern_{scenario['test_id']}",
                "timestamp": scenario["timestamp"],
                "error_fingerprint": f"{scenario['error_type']}_{scenario['complexity_score']}",
                "solution_fingerprint": f"{scenario['fix_pattern']}_{int(scenario['success_rate']*100)}",
                "correlation_strength": scenario["learning_weight"],
                "occurrence_count": random.randint(1, 10),
                "cross_project_applicability": random.random() > 0.5
            }
            
            # Save pattern correlation
            pattern_file = learning_dir / f"pattern_correlation_{scenario['test_id']}.json"
            with open(pattern_file, 'w') as f:
                json.dump(pattern_correlation, f, indent=2)
        
        print(f"✅ Generated {len(scenarios)} test scenarios for {project_name}")
        return scenarios
    
    def validate_learning_effectiveness(self, project_name):
        """Validate that the AI learning system can process test data"""
        project_path = self.base_dir / "Projects" / project_name
        learning_dir = project_path / ".ai_learning_system"
        
        if not learning_dir.exists():
            print(f"❌ Learning directory not found for {project_name}")
            return False
        
        # Count learning files
        fix_files = list(learning_dir.glob("fix_history_*.json"))
        pattern_files = list(learning_dir.glob("pattern_correlation_*.json"))
        
        print(f"📊 {project_name} Learning Data:")
        print(f"   - Fix history files: {len(fix_files)}")
        print(f"   - Pattern correlation files: {len(pattern_files)}")
        
        # Sample analysis of learning data
        if fix_files:
            with open(fix_files[0]) as f:
                sample_fix = json.load(f)
            print(f"   - Sample fix type: {sample_fix['error_pattern']['type']}")
            print(f"   - Sample success rate: {sample_fix['solution_pattern']['success_rate']:.2%}")
        
        return len(fix_files) > 0 and len(pattern_files) > 0
    
    def generate_comprehensive_test_suite(self):
        """Generate comprehensive test suite for all projects"""
        print("🧪 Generating Comprehensive AI Learning Test Suite")
        print("=" * 60)
        
        total_scenarios = 0
        
        for project in self.projects:
            print(f"\n🔍 Processing {project}...")
            scenarios = self.create_learning_data(project, scenario_count=8)
            total_scenarios += len(scenarios)
            
            # Validate learning data
            if self.validate_learning_effectiveness(project):
                print(f"✅ {project} validation successful")
            else:
                print(f"❌ {project} validation failed")
        
        print(f"\n📈 Test Suite Summary:")
        print(f"   - Total scenarios generated: {total_scenarios}")
        print(f"   - Projects tested: {len(self.projects)}")
        print(f"   - Expected learning improvements: Immediate")
        
        return total_scenarios

def main():
    """Main execution function"""
    generator = AILearningTestGenerator()
    
    if len(sys.argv) > 1:
        command = sys.argv[1].lower()
        
        if command == "generate":
            generator.generate_comprehensive_test_suite()
        elif command == "validate":
            project = sys.argv[2] if len(sys.argv) > 2 else "CodingReviewer"
            generator.validate_learning_effectiveness(project)
        elif command == "scenarios":
            count = int(sys.argv[2]) if len(sys.argv) > 2 else 10
            scenarios = generator.generate_test_scenarios(count)
            for scenario in scenarios:
                print(f"📋 {scenario['test_id']}: {scenario['error_type']} → {scenario['fix_pattern']}")
        else:
            print("❌ Unknown command. Use: generate, validate, or scenarios")
    else:
        # Default: generate comprehensive test suite
        generator.generate_comprehensive_test_suite()

if __name__ == "__main__":
    main()
