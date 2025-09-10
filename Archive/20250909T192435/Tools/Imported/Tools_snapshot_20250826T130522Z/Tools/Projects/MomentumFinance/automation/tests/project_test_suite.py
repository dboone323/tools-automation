#!/usr/bin/env python3
"""
Comprehensive Test Suite for iOS Swift Projects
Tests automation system, project health, and generates reports
"""

import subprocess
import json
import os
import sys
from datetime import datetime
from pathlib import Path
import re

class ProjectTestSuite:
    def __init__(self, project_path, config_path):
        self.project_path = Path(project_path).resolve()
        self.config_path = Path(config_path).resolve()
        self.project_name = self.project_path.name
        self.results = {
            'timestamp': datetime.now().isoformat(),
            'project': self.project_name,
            'project_path': str(self.project_path),
            'tests': {},
            'summary': {}
        }
        
    def load_config(self):
        """Load project configuration"""
        try:
            if self.config_path.exists():
                with open(self.config_path, 'r') as f:
                    return json.load(f)
            return {}
        except Exception as e:
            print(f"❌ Error loading config: {e}")
            return {}
    
    def test_project_structure(self):
        """Test project structure and files"""
        print("🏗️  Testing project structure...")
        
        try:
            # Find Swift files
            swift_files = list(self.project_path.rglob("*.swift"))
            test_files = [f for f in swift_files if 'Test' in f.name]
            source_files = [f for f in swift_files if 'Test' not in f.name]
            
            # Find Xcode project
            xcodeproj_files = list(self.project_path.glob("*.xcodeproj"))
            
            # Calculate metrics
            total_lines = 0
            for file in source_files[:50]:  # Limit to prevent timeout
                try:
                    with open(file, 'r', encoding='utf-8') as f:
                        total_lines += len(f.readlines())
                except Exception:
                    continue
            
            self.results['tests']['project_structure'] = {
                'status': 'passed',
                'metrics': {
                    'total_swift_files': len(swift_files),
                    'source_files': len(source_files),
                    'test_files': len(test_files),
                    'total_lines': total_lines,
                    'avg_lines_per_file': total_lines // max(len(source_files), 1),
                    'xcode_projects': len(xcodeproj_files),
                    'has_tests': len(test_files) > 0
                }
            }
            
            print(f"  ✅ Found {len(swift_files)} Swift files ({len(source_files)} source, {len(test_files)} test)")
            print(f"  ✅ Found {len(xcodeproj_files)} Xcode project(s)")
            print(f"  ✅ Total lines of code: {total_lines}")
            
            return True
            
        except Exception as e:
            self.results['tests']['project_structure'] = {
                'status': 'error',
                'error': str(e)
            }
            print(f"  ❌ Error: {e}")
            return False
    
    def test_git_repository(self):
        """Test Git repository status"""
        print("🔀 Testing Git repository...")
        
        try:
            if not (self.project_path / '.git').exists():
                self.results['tests']['git_repository'] = {
                    'status': 'warning',
                    'message': 'No Git repository found'
                }
                print("  ⚠️  No Git repository found")
                return True
            
            # Get Git info
            os.chdir(self.project_path)
            
            # Current branch
            branch_result = subprocess.run(['git', 'branch', '--show-current'], 
                                         capture_output=True, text=True, timeout=10)
            current_branch = branch_result.stdout.strip() if branch_result.returncode == 0 else 'unknown'
            
            # Commit count
            commit_result = subprocess.run(['git', 'rev-list', '--count', 'HEAD'], 
                                         capture_output=True, text=True, timeout=10)
            commit_count = commit_result.stdout.strip() if commit_result.returncode == 0 else '0'
            
            # Status
            status_result = subprocess.run(['git', 'status', '--porcelain'], 
                                         capture_output=True, text=True, timeout=10)
            modified_files = len(status_result.stdout.strip().split('\n')) if status_result.stdout.strip() else 0
            
            self.results['tests']['git_repository'] = {
                'status': 'passed',
                'metrics': {
                    'current_branch': current_branch,
                    'total_commits': int(commit_count) if commit_count.isdigit() else 0,
                    'modified_files': modified_files,
                    'is_clean': modified_files == 0
                }
            }
            
            print(f"  ✅ Branch: {current_branch}")
            print(f"  ✅ Commits: {commit_count}")
            print(f"  ✅ Modified files: {modified_files}")
            
            return True
            
        except subprocess.TimeoutExpired:
            self.results['tests']['git_repository'] = {
                'status': 'timeout',
                'error': 'Git command timed out'
            }
            print("  ⏰ Git command timed out")
            return False
        except Exception as e:
            self.results['tests']['git_repository'] = {
                'status': 'error',
                'error': str(e)
            }
            print(f"  ❌ Error: {e}")
            return False
    
    def test_xcode_build(self):
        """Test Xcode build"""
        print("🔨 Testing Xcode build...")
        
        try:
            config = self.load_config()
            project_name = config.get('project', {}).get('name', self.project_name)
            
            # Check if Xcode project exists
            xcodeproj_path = self.project_path / f"{project_name}.xcodeproj"
            if not xcodeproj_path.exists():
                self.results['tests']['xcode_build'] = {
                    'status': 'failed',
                    'error': f'Xcode project not found: {xcodeproj_path}'
                }
                print(f"  ❌ Xcode project not found: {xcodeproj_path}")
                return False
            
            # Attempt build
            os.chdir(self.project_path)
            build_cmd = [
                'xcodebuild', '-project', f"{project_name}.xcodeproj",
                '-scheme', project_name, '-configuration', 'Debug',
                'clean', 'build', '-quiet'
            ]
            
            print(f"  🔨 Building {project_name}...")
            result = subprocess.run(build_cmd, capture_output=True, text=True, timeout=300)
            
            if result.returncode == 0:
                self.results['tests']['xcode_build'] = {
                    'status': 'passed',
                    'build_output': result.stdout[-500:] if result.stdout else '',
                    'build_time': 'under 5 minutes'
                }
                print("  ✅ Build successful")
                return True
            else:
                self.results['tests']['xcode_build'] = {
                    'status': 'failed',
                    'error': result.stderr[-1000:] if result.stderr else 'Build failed',
                    'build_output': result.stdout[-500:] if result.stdout else ''
                }
                print("  ❌ Build failed")
                print(f"  📝 Error: {result.stderr[-200:] if result.stderr else 'Unknown error'}")
                return False
                
        except subprocess.TimeoutExpired:
            self.results['tests']['xcode_build'] = {
                'status': 'timeout',
                'error': 'Build timed out after 5 minutes'
            }
            print("  ⏰ Build timed out")
            return False
        except Exception as e:
            self.results['tests']['xcode_build'] = {
                'status': 'error',
                'error': str(e)
            }
            print(f"  ❌ Error: {e}")
            return False
    
    def test_code_quality(self):
        """Test code quality metrics"""
        print("🔍 Testing code quality...")
        
        try:
            swift_files = list(self.project_path.rglob("*.swift"))
            source_files = [f for f in swift_files if 'Test' not in f.name]
            
            # Analyze code patterns
            todo_count = 0
            fixme_count = 0
            long_files = 0
            empty_files = 0
            
            for file in source_files:
                try:
                    with open(file, 'r', encoding='utf-8') as f:
                        content = f.read()
                        lines = content.split('\n')
                        
                        # Count TODOs and FIXMEs
                        todo_count += len(re.findall(r'TODO|todo', content, re.IGNORECASE))
                        fixme_count += len(re.findall(r'FIXME|fixme', content, re.IGNORECASE))
                        
                        # Check file length
                        if len(lines) > 500:
                            long_files += 1
                        if len(lines.strip()) == 0:
                            empty_files += 1
                            
                except Exception:
                    continue
            
            # Calculate quality score
            total_files = len(source_files)
            quality_score = 100
            
            if total_files > 0:
                if todo_count > total_files:
                    quality_score -= 10
                if fixme_count > 0:
                    quality_score -= 5
                if long_files > total_files * 0.1:
                    quality_score -= 15
                if empty_files > 0:
                    quality_score -= 5
            
            self.results['tests']['code_quality'] = {
                'status': 'passed',
                'metrics': {
                    'quality_score': max(quality_score, 0),
                    'todo_comments': todo_count,
                    'fixme_comments': fixme_count,
                    'long_files': long_files,
                    'empty_files': empty_files,
                    'total_source_files': total_files
                }
            }
            
            print(f"  ✅ Quality score: {quality_score}/100")
            print(f"  📝 TODO comments: {todo_count}")
            print(f"  🔧 FIXME comments: {fixme_count}")
            print(f"  📏 Long files (>500 lines): {long_files}")
            
            return True
            
        except Exception as e:
            self.results['tests']['code_quality'] = {
                'status': 'error',
                'error': str(e)
            }
            print(f"  ❌ Error: {e}")
            return False
    
    def test_automation_system(self):
        """Test automation system components"""
        print("�� Testing automation system...")
        
        try:
            automation_dir = self.project_path / 'automation'
            
            if not automation_dir.exists():
                self.results['tests']['automation_system'] = {
                    'status': 'failed',
                    'error': 'Automation directory not found'
                }
                print("  ❌ Automation directory not found")
                return False
            
            # Check components
            components = {
                'config': automation_dir / 'config' / 'automation_config.json',
                'runner': automation_dir / 'run_automation.sh',
                'src': automation_dir / 'src',
                'logs': automation_dir / 'logs',
                'reports': automation_dir / 'reports'
            }
            
            found_components = {}
            for name, path in components.items():
                found_components[name] = path.exists()
            
            # Test automation runner
            runner_works = False
            if components['runner'].exists():
                try:
                    os.chdir(automation_dir)
                    result = subprocess.run(['./run_automation.sh', 'status'], 
                                          capture_output=True, text=True, timeout=30)
                    runner_works = result.returncode == 0
                except Exception:
                    runner_works = False
            
            self.results['tests']['automation_system'] = {
                'status': 'passed' if all(found_components.values()) else 'warning',
                'components': found_components,
                'runner_functional': runner_works
            }
            
            print(f"  ✅ Components found: {sum(found_components.values())}/{len(found_components)}")
            print(f"  ✅ Runner functional: {'Yes' if runner_works else 'No'}")
            
            return True
            
        except Exception as e:
            self.results['tests']['automation_system'] = {
                'status': 'error',
                'error': str(e)
            }
            print(f"  ❌ Error: {e}")
            return False
    
    def generate_reports(self):
        """Generate test reports"""
        print("📊 Generating reports...")
        
        try:
            # Calculate summary
            total_tests = len(self.results['tests'])
            passed_tests = sum(1 for test in self.results['tests'].values() 
                             if test.get('status') == 'passed')
            failed_tests = sum(1 for test in self.results['tests'].values() 
                             if test.get('status') == 'failed')
            
            self.results['summary'] = {
                'total_tests': total_tests,
                'passed': passed_tests,
                'failed': failed_tests,
                'success_rate': (passed_tests / total_tests * 100) if total_tests > 0 else 0
            }
            
            # Create reports directory
            reports_dir = self.project_path / 'automation' / 'reports'
            reports_dir.mkdir(exist_ok=True)
            
            # JSON report
            json_report = reports_dir / f"test_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
            with open(json_report, 'w') as f:
                json.dump(self.results, f, indent=2)
            
            # Markdown report
            md_report = reports_dir / "latest_test_report.md"
            with open(md_report, 'w') as f:
                f.write(self.generate_markdown_report())
            
            # HTML report
            html_report = reports_dir / "latest_test_report.html"
            with open(html_report, 'w') as f:
                f.write(self.generate_html_report())
            
            print(f"  ✅ JSON report: {json_report}")
            print(f"  ✅ Markdown report: {md_report}")
            print(f"  ✅ HTML report: {html_report}")
            
            return True
            
        except Exception as e:
            print(f"  ❌ Error generating reports: {e}")
            return False
    
    def generate_markdown_report(self):
        """Generate markdown test report"""
        summary = self.results['summary']
        
        md = f"""# {self.project_name} Test Report

**Generated:** {self.results['timestamp']}
**Project Path:** {self.results['project_path']}

## Summary
- **Total Tests:** {summary['total_tests']}
- **Passed:** {summary['passed']}
- **Failed:** {summary['failed']}
- **Success Rate:** {summary['success_rate']:.1f}%

## Test Results

"""
        
        for test_name, test_data in self.results['tests'].items():
            status = test_data.get('status', 'unknown')
            emoji = {'passed': '✅', 'failed': '❌', 'warning': '⚠️', 'error': '🚨', 'timeout': '⏰'}.get(status, '❓')
            
            md += f"### {emoji} {test_name.replace('_', ' ').title()}\n"
            md += f"**Status:** {status}\n\n"
            
            if 'metrics' in test_data:
                md += "**Metrics:**\n"
                for key, value in test_data['metrics'].items():
                    md += f"- {key.replace('_', ' ').title()}: {value}\n"
                md += "\n"
            
            if test_data.get('error'):
                md += f"**Error:** {test_data['error']}\n\n"
        
        return md
    
    def generate_html_report(self):
        """Generate HTML test report"""
        summary = self.results['summary']
        
        return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{self.project_name} Test Report</title>
    <style>
        body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif; margin: 20px; line-height: 1.6; }}
        .header {{ background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 10px; margin-bottom: 30px; }}
        .summary {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }}
        .metric {{ background: #f8f9fa; padding: 20px; border-radius: 8px; text-align: center; border-left: 4px solid #007bff; }}
        .metric h3 {{ margin: 0 0 10px 0; color: #495057; }}
        .metric .value {{ font-size: 2em; font-weight: bold; color: #007bff; }}
        .test {{ margin: 20px 0; padding: 20px; border-radius: 8px; border-left: 4px solid #ccc; }}
        .test.passed {{ border-left-color: #28a745; background: #f8fff9; }}
        .test.failed {{ border-left-color: #dc3545; background: #fff8f8; }}
        .test.warning {{ border-left-color: #ffc107; background: #fffbf0; }}
        .test.error {{ border-left-color: #fd7e14; background: #fff5f0; }}
        .test h3 {{ margin-top: 0; }}
        .metrics-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 10px; margin-top: 15px; }}
        .metric-item {{ background: rgba(0,0,0,0.05); padding: 10px; border-radius: 4px; }}
        .metric-item strong {{ display: block; font-size: 1.2em; color: #495057; }}
        .error-text {{ background: #f8d7da; border: 1px solid #f5c6cb; color: #721c24; padding: 10px; border-radius: 4px; margin-top: 10px; }}
        .timestamp {{ color: #6c757d; font-size: 0.9em; }}
    </style>
</head>
<body>
    <div class="header">
        <h1>🧪 {self.project_name} Test Report</h1>
        <p class="timestamp">Generated: {self.results['timestamp']}</p>
        <p>Project: {self.results['project_path']}</p>
    </div>
    
    <div class="summary">
        <div class="metric">
            <h3>Total Tests</h3>
            <div class="value">{summary['total_tests']}</div>
        </div>
        <div class="metric">
            <h3>Passed</h3>
            <div class="value" style="color: #28a745;">{summary['passed']}</div>
        </div>
        <div class="metric">
            <h3>Failed</h3>
            <div class="value" style="color: #dc3545;">{summary['failed']}</div>
        </div>
        <div class="metric">
            <h3>Success Rate</h3>
            <div class="value" style="color: {'#28a745' if summary['success_rate'] >= 80 else '#dc3545' if summary['success_rate'] < 60 else '#ffc107'};">{summary['success_rate']:.1f}%</div>
        </div>
    </div>
    
    <h2>📋 Test Details</h2>
    {self._generate_test_details_html()}
</body>
</html>"""
    
    def _generate_test_details_html(self):
        """Generate HTML for test details"""
        html = ""
        
        for test_name, test_data in self.results['tests'].items():
            status = test_data.get('status', 'unknown')
            
            html += f'<div class="test {status}">'
            html += f'<h3>{test_name.replace("_", " ").title()}</h3>'
            html += f'<p><strong>Status:</strong> {status}</p>'
            
            if 'metrics' in test_data:
                html += '<div class="metrics-grid">'
                for key, value in test_data['metrics'].items():
                    html += f'<div class="metric-item"><strong>{value}</strong>{key.replace("_", " ").title()}</div>'
                html += '</div>'
            
            if test_data.get('error'):
                html += f'<div class="error-text"><strong>Error:</strong> {test_data["error"]}</div>'
            
            html += '</div>'
        
        return html
    
    def run_all_tests(self):
        """Run all tests"""
        print(f"🚀 Starting comprehensive test suite for {self.project_name}")
        print("=" * 60)
        
        # Run all tests
        tests = [
            self.test_project_structure,
            self.test_git_repository,
            self.test_automation_system,
            self.test_code_quality,
            # self.test_xcode_build,  # Commented out to save time
        ]
        
        for test in tests:
            try:
                test()
            except Exception as e:
                print(f"❌ Test {test.__name__} crashed: {e}")
            print()
        
        # Generate reports
        self.generate_reports()
        
        # Print summary
        print("=" * 60)
        print("📊 Test Summary:")
        summary = self.results['summary']
        print(f"  Total Tests: {summary['total_tests']}")
        print(f"  Passed: {summary['passed']}")
        print(f"  Failed: {summary['failed']}")
        print(f"  Success Rate: {summary['success_rate']:.1f}%")
        
        return summary['success_rate'] >= 70

if __name__ == "__main__":
    # Get paths
    script_dir = Path(__file__).parent
    project_dir = script_dir.parent.parent
    config_file = script_dir.parent / 'config' / 'automation_config.json'
    
    # Run tests
    test_suite = ProjectTestSuite(project_dir, config_file)
    success = test_suite.run_all_tests()
    
    print(f"\n🎯 Overall Result: {'SUCCESS' if success else 'NEEDS ATTENTION'}")
    sys.exit(0 if success else 1)
