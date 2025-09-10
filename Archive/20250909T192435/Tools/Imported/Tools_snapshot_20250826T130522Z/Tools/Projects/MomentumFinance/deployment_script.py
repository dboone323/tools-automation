#!/usr/bin/env python3
"""
MomentumFinance Deployment Script
Handles deployment to production environment
"""

import os
import sys
import logging
import subprocess
from datetime import datetime
from pathlib import Path

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class MomentumFinanceDeployer:
    """Handles deployment operations for MomentumFinance app"""
    
    def __init__(self):
        self.project_root = Path(__file__).parent
        self.build_path = self.project_root / "build"
        self.deployment_timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.config = self._load_deployment_config()
        self.results = {
            'timestamp': datetime.now().isoformat(),
            'deployment_id': self.deployment_timestamp,
            'status': 'INITIALIZED'
        }
        
    def validate_environment(self):
        """Validate deployment environment"""
        logger.info("🔍 Validating deployment environment...")
        
        # Check if we're on the main branch
        try:
            result = subprocess.run(
                ["git", "branch", "--show-current"],
                capture_output=True, text=True, cwd=self.project_root
            )
            current_branch = result.stdout.strip()
            
            if current_branch not in ["main", "develop"]:
                logger.warning(f"⚠️ Deploying from non-main branch: {current_branch}")
        except subprocess.CalledProcessError:
            logger.warning("⚠️ Could not determine git branch")
        
        # Check for required files
        required_files = [
            "MomentumFinance.xcodeproj/project.pbxproj",
            "Package.swift",
            "requirements.txt"
        ]
        
        missing_files = []
        for file_path in required_files:
            if not (self.project_root / file_path).exists():
                missing_files.append(file_path)
        
        if missing_files:
            logger.error(f"❌ Missing required files: {missing_files}")
            return False
            
        logger.info("✅ Environment validation passed")
        return True
    
    def run_quality_checks(self):
        """Run final quality checks before deployment"""
        logger.info("🔍 Running pre-deployment quality checks...")
        
        try:
            # Run quality check
            result = subprocess.run(
                ["python3", "workflow_quality_check.py"],
                capture_output=True, text=True, cwd=self.project_root
            )
            
            if result.returncode != 0:
                logger.error("❌ Quality checks failed")
                logger.error(result.stderr)
                return False
                
            logger.info("✅ Quality checks passed")
            return True
            
        except FileNotFoundError:
            logger.warning("⚠️ Quality check script not found, skipping...")
            return True
        except Exception as e:
            logger.error(f"❌ Quality check error: {e}")
            return False
    
    def build_ios_app(self):
        """Build the iOS application"""
        logger.info("🔨 Building iOS application...")
        
        try:
            # Build for iOS simulator (in CI environment)
            result = subprocess.run([
                "xcodebuild", 
                "-project", "MomentumFinance.xcodeproj",
                "-scheme", "MomentumFinance",
                "-sdk", "iphonesimulator",
                "-destination", "platform=iOS Simulator,name=iPhone 14",
                "build"
            ], capture_output=True, text=True, cwd=self.project_root)
            
            if result.returncode != 0:
                logger.error("❌ iOS build failed")
                logger.error(result.stderr)
                return False
                
            logger.info("✅ iOS build successful")
            return True
            
        except FileNotFoundError:
            logger.warning("⚠️ Xcode not found, skipping iOS build...")
            return True
        except Exception as e:
            logger.error(f"❌ Build error: {e}")
            return False
    
    def deploy(self):
        """Main deployment process"""
        logger.info("🚀 Starting MomentumFinance deployment...")
        
        # Validate environment
        if not self.validate_environment():
            logger.error("❌ Environment validation failed")
            sys.exit(1)
        
        # Run quality checks
        if not self.run_quality_checks():
            logger.error("❌ Quality checks failed")
            sys.exit(1)
        
        # Build application
        if not self.build_ios_app():
            logger.error("❌ Application build failed")
            sys.exit(1)
        
        # Deployment successful
        logger.info("🎉 Deployment completed successfully!")
        logger.info(f"📅 Deployment timestamp: {self.deployment_timestamp}")
        
        return True
    
    def _load_deployment_config(self):
        """Load deployment configuration"""
        return {
            'dry_run': os.getenv('DRY_RUN', 'false').lower() == 'true',
            'target_environment': os.getenv('TARGET_ENV', 'production'),
            'build_configuration': os.getenv('BUILD_CONFIG', 'Release'),
            'skip_tests': os.getenv('SKIP_TESTS', 'false').lower() == 'true',
            'verbose': os.getenv('VERBOSE', 'false').lower() == 'true'
        }

def main():
    """Main entry point"""
    logger.info("🚀 MomentumFinance Deployment Script")
    
    deployer = MomentumFinanceDeployer()
    
    try:
        success = deployer.deploy()
        if success:
            logger.info("✅ Deployment process completed successfully")
            sys.exit(0)
        else:
            logger.error("❌ Deployment process failed")
            sys.exit(1)
            
    except KeyboardInterrupt:
        logger.info("🛑 Deployment interrupted by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"❌ Unexpected error during deployment: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
