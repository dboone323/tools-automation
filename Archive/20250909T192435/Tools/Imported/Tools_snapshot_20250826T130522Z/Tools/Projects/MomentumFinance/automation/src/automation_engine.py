#!/usr/bin/env python3
"""
Working Automation Engine for Phase 3 Testing
"""

import os
import sys
import json
import logging
from pathlib import Path
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict

logger = logging.getLogger(__name__)

@dataclass
class AutomationScript:
    name: str
    path: str
    category: str

class AutomationEngine:
    def __init__(self):
        self.scripts: Dict[str, AutomationScript] = {}
        self.workspace_path = Path(os.getcwd())
        self.discover_scripts()
    
    def discover_scripts(self):
        """Discover automation scripts"""
        script_count = 0
        for script_path in self.workspace_path.glob("*.sh"):
            if not script_path.name.startswith("phase3_"):
                script = AutomationScript(
                    name=script_path.stem,
                    path=str(script_path),
                    category="automation"
                )
                self.scripts[script.name] = script
                script_count += 1
        
        for script_path in self.workspace_path.glob("*.py"):
            if not script_path.name.startswith("phase3_") and script_path.name != "working_automation_engine.py":
                script = AutomationScript(
                    name=script_path.stem,
                    path=str(script_path),
                    category="automation"
                )
                self.scripts[script.name] = script
                script_count += 1
        
        logger.info(f"Discovered {script_count} scripts")
    
    def get_status(self):
        return {
            "total_scripts": len(self.scripts),
            "workspace": str(self.workspace_path)
        }

# Global instance
_engine = None

def get_engine():
    global _engine
    if _engine is None:
        _engine = AutomationEngine()
    return _engine

def main():
    engine = get_engine()
    print(f"Working! Found {len(engine.scripts)} scripts")
    status = engine.get_status()
    print("Status:", json.dumps(status, indent=2))

if __name__ == "__main__":
    main()
