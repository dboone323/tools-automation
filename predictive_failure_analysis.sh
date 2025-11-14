#!/bin/bash
# Predictive Failure Analysis and Self-Healing System
# Analyzes historical data to predict failures and implement automatic fixes

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGS_DIR="$WORKSPACE_ROOT/logs"
REPORTS_DIR="$WORKSPACE_ROOT/reports"
UNIFIED_TODOS_FILE="$WORKSPACE_ROOT/unified_todos.json"
PREDICTIVE_DATA_FILE="$WORKSPACE_ROOT/predictive_data.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[PREDICTIVE]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_predictive() { echo -e "${PURPLE}[PREDICTIVE]${NC} $1"; }

initialize_predictive_data() {
    log_info "Initializing predictive analysis data..."

    if [[ ! -f "$PREDICTIVE_DATA_FILE" ]]; then
        cat >"$PREDICTIVE_DATA_FILE" <<'EOF'
{
  "error_patterns": {},
  "failure_predictions": [],
  "self_healing_actions": {},
  "system_health_trends": {
    "last_updated": "",
    "error_frequency": {},
    "recovery_times": {},
    "system_load": []
  },
  "learning_data": {
    "successful_fixes": [],
    "failed_fixes": [],
    "pattern_correlations": {}
  }
}
EOF
        log_success "Predictive data file initialized."
    fi
}

analyze_historical_patterns() {
    log_info "Analyzing historical error patterns..."

    python3 -c "
import json
import os
import glob
from datetime import datetime, timedelta
from collections import defaultdict, Counter
import re

logs_dir = '$LOGS_DIR'
predictive_file = '$PREDICTIVE_DATA_FILE'

# Load existing predictive data
if os.path.exists(predictive_file):
    with open(predictive_file, 'r') as f:
        predictive_data = json.load(f)
else:
    predictive_data = {
        'error_patterns': {},
        'failure_predictions': [],
        'self_healing_actions': {},
        'system_health_trends': {
            'last_updated': '',
            'error_frequency': {},
            'recovery_times': {},
            'system_load': []
        },
        'learning_data': {
            'successful_fixes': [],
            'failed_fixes': [],
            'pattern_correlations': {}
        }
    }

# Analyze all log files
error_timeline = defaultdict(list)
pattern_frequency = Counter()

for log_file in glob.glob(os.path.join(logs_dir, '*.log')):
    try:
        with open(log_file, 'r') as f:
            lines = f.readlines()
            
        for i, line in enumerate(lines):
            # Extract timestamp if available
            timestamp_match = re.search(r'(\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2})', line)
            timestamp = timestamp_match.group(1) if timestamp_match else datetime.now().isoformat()
            
            # Check for error patterns
            error_patterns = [
                'ModuleNotFoundError',
                'ImportError', 
                'Connection refused',
                'command not found',
                'Permission denied',
                'TimeoutError',
                'OSError',
                'SyntaxError',
                'AttributeError',
                'KeyError',
                'ValueError'
            ]
            
            for pattern in error_patterns:
                if pattern in line:
                    error_timeline[timestamp[:10]].append({
                        'pattern': pattern,
                        'line': line.strip(),
                        'log_file': os.path.basename(log_file),
                        'line_number': i + 1
                    })
                    pattern_frequency[pattern] += 1
                    
    except Exception as e:
        print(f'Error processing {log_file}: {e}')

# Analyze patterns for predictions
predictions = []

# Predict Redis dependency issues if pattern is increasing
redis_errors = [e for errors in error_timeline.values() for e in errors if 'redis' in e['pattern'].lower() or 'redis' in e['line'].lower()]
if len(redis_errors) > 5:
    predictions.append({
        'type': 'dependency_failure',
        'component': 'redis',
        'confidence': min(len(redis_errors) / 10, 0.9),
        'prediction': 'Redis dependency issues likely to continue',
        'recommended_action': 'Ensure Redis is installed and accessible',
        'timeframe': 'next_24_hours'
    })

# Predict Flask issues if pattern detected
flask_errors = [e for errors in error_timeline.values() for e in errors if 'flask' in e['pattern'].lower() or 'flask' in e['line'].lower()]
if len(flask_errors) > 3:
    predictions.append({
        'type': 'dependency_failure', 
        'component': 'flask',
        'confidence': min(len(flask_errors) / 8, 0.8),
        'prediction': 'Flask web service issues likely',
        'recommended_action': 'Verify Flask installation and imports',
        'timeframe': 'next_12_hours'
    })

# Predict network issues if connection errors are frequent
connection_errors = [e for errors in error_timeline.values() for e in errors if 'connection' in e['line'].lower() or 'network' in e['line'].lower()]
if len(connection_errors) > 10:
    predictions.append({
        'type': 'network_failure',
        'component': 'connectivity',
        'confidence': min(len(connection_errors) / 15, 0.85),
        'prediction': 'Network connectivity issues predicted',
        'recommended_action': 'Check network configuration and DNS',
        'timeframe': 'next_6_hours'
    })

# Update predictive data
predictive_data['error_patterns'] = dict(pattern_frequency)
predictive_data['failure_predictions'] = predictions
predictive_data['system_health_trends']['last_updated'] = datetime.now().isoformat()
predictive_data['system_health_trends']['error_frequency'] = dict(pattern_frequency)

# Save updated data
with open(predictive_file, 'w') as f:
    json.dump(predictive_data, f, indent=2)

print(f'Analyzed {len(error_timeline)} days of error data')
print(f'Generated {len(predictions)} failure predictions')
print(f'Most common errors: {pattern_frequency.most_common(5)}')
" 2>/dev/null

    log_success "Historical pattern analysis complete."
}

implement_self_healing() {
    log_info "Implementing self-healing actions..."

    # Self-healing for common issues
    python3 -c "
import json
import os
import subprocess
import sys
from datetime import datetime

predictive_file = '$PREDICTIVE_DATA_FILE'
unified_todos_file = '$UNIFIED_TODOS_FILE'

# Load predictive data
if not os.path.exists(predictive_file):
    print('No predictive data available')
    sys.exit(0)

with open(predictive_file, 'r') as f:
    predictive_data = json.load(f)

# Load todos
todos = []
if os.path.exists(unified_todos_file):
    with open(unified_todos_file, 'r') as f:
        data = json.load(f)
        todos = data.get('todos', [])

healing_actions = []

# Self-healing: Check and install missing Python packages
missing_packages = []
try:
    subprocess.run([sys.executable, '-c', 'import redis'], check=True, capture_output=True)
except subprocess.CalledProcessError:
    missing_packages.append('redis')

try:
    subprocess.run([sys.executable, '-c', 'import flask'], check=True, capture_output=True)
except subprocess.CalledProcessError:
    missing_packages.append('flask')

if missing_packages:
    print(f'Attempting to install missing packages: {missing_packages}')
    try:
        # Try pip install in virtual environment
        venv_pip = os.path.join('$WORKSPACE_ROOT', '.venv', 'bin', 'pip')
        if os.path.exists(venv_pip):
            for package in missing_packages:
                result = subprocess.run([venv_pip, 'install', package], capture_output=True, text=True)
                if result.returncode == 0:
                    healing_actions.append(f'Successfully installed {package}')
                    print(f'✅ Installed {package}')
                else:
                    healing_actions.append(f'Failed to install {package}: {result.stderr}')
                    print(f'❌ Failed to install {package}')
        else:
            healing_actions.append('Virtual environment pip not found')
    except Exception as e:
        healing_actions.append(f'Installation error: {e}')

# Self-healing: Check system commands
missing_commands = []
commands_to_check = ['bc', 'curl', 'wget', 'ping', 'nslookup']

for cmd in commands_to_check:
    try:
        subprocess.run(['which', cmd], check=True, capture_output=True)
    except subprocess.CalledProcessError:
        missing_commands.append(cmd)

if missing_commands:
    print(f'Missing system commands detected: {missing_commands}')
    # On macOS, try to install with brew if available
    try:
        subprocess.run(['which', 'brew'], check=True, capture_output=True)
        for cmd in missing_commands:
            if cmd == 'bc':
                result = subprocess.run(['brew', 'install', cmd], capture_output=True, text=True)
                if result.returncode == 0:
                    healing_actions.append(f'Successfully installed {cmd} via brew')
                    print(f'✅ Installed {cmd}')
                else:
                    healing_actions.append(f'Failed to install {cmd} via brew')
    except subprocess.CalledProcessError:
        healing_actions.append('Homebrew not available for system package installation')

# Self-healing: Check network connectivity
try:
    result = subprocess.run(['ping', '-c', '1', '8.8.8.8'], capture_output=True, timeout=5)
    if result.returncode != 0:
        healing_actions.append('Network connectivity issues detected - manual intervention required')
        print('⚠️ Network connectivity issues detected')
    else:
        healing_actions.append('Network connectivity verified')
except subprocess.TimeoutExpired:
    healing_actions.append('Network connectivity check timed out')
except Exception as e:
    healing_actions.append(f'Network check error: {e}')

# Self-healing: Restart critical services if predictions indicate issues
critical_services = {
    'redis': ['redis-server'],
    'docker': ['docker']
}
for prediction in predictive_data.get('failure_predictions', []):
    comp = prediction.get('component')
    if comp in critical_services:
        for svc in critical_services[comp]:
            # Attempt restart only if command exists
            if subprocess.run(['which', svc], capture_output=True).returncode == 0:
                try:
                    healing_actions.append(f'Attempting restart of {svc}')
                    # macOS launchctl or brew services could be used; try generic pkill & restart
                    subprocess.run(['pkill', '-f', svc], capture_output=True)
                    subprocess.Popen([svc], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    healing_actions.append(f'Restarted {svc}')
                    print(f'🔄 Restarted {svc}')
                except Exception as e:
                    healing_actions.append(f'Failed to restart {svc}: {e}')

# Self-healing: Free disk space if usage high (>90%) by pruning old logs
try:
    st = subprocess.run(['df', '/'], capture_output=True, text=True)
    if st.returncode == 0:
        lines = st.stdout.strip().split('\n')
        if len(lines) > 1:
            usage_pct = int(lines[-1].split()[4].rstrip('%'))
            if usage_pct > 90:
                log_dir = os.path.join('$WORKSPACE_ROOT', 'logs')
                if os.path.isdir(log_dir):
                    old_logs = sorted([
                        (os.path.getmtime(os.path.join(log_dir, f)), f)
                        for f in os.listdir(log_dir) if f.endswith('.log')
                    ])
                    removed = 0
                    for _, f in old_logs[:5]:  # remove up to 5 oldest
                        try:
                            os.remove(os.path.join(log_dir, f))
                            removed += 1
                        except Exception:
                            pass
                    healing_actions.append(f'Disk space critical; pruned {removed} old log files')
except Exception as e:
    healing_actions.append(f'Disk space pruning error: {e}')

# Update predictive data with healing results
predictive_data['self_healing_actions'][datetime.now().isoformat()] = healing_actions

with open(predictive_file, 'w') as f:
    json.dump(predictive_data, f, indent=2)

print(f'Self-healing actions completed: {len(healing_actions)} actions performed')
" 2>/dev/null

    log_success "Self-healing implementation complete."
}

generate_predictive_report() {
    log_info "Generating predictive analysis report..."

    local report_file="$REPORTS_DIR/predictive_analysis_$(date +%Y%m%d_%H%M%S).md"

    # Generate comprehensive report
    python3 -c "
import json
import os
from datetime import datetime

predictive_file = '$PREDICTIVE_DATA_FILE'
report_file = '$report_file'

if os.path.exists(predictive_file):
    with open(predictive_file, 'r') as f:
        data = json.load(f)
    
    # Generate markdown report
    report_content = f'''# Predictive Failure Analysis Report
Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

## System Health Trends

### Error Pattern Analysis
'''
    
    error_patterns = data.get('error_patterns', {})
    if error_patterns:
        report_content += '| Error Type | Frequency | Severity |\n|------------|-----------|----------|\n'
        for pattern, count in sorted(error_patterns.items(), key=lambda x: x[1], reverse=True)[:10]:
            severity = 'High' if count > 20 else 'Medium' if count > 10 else 'Low'
            report_content += f'| {pattern} | {count} | {severity} |\n'
    else:
        report_content += 'No error patterns detected.\n'
    
    report_content += '\n### Failure Predictions\n'
    
    predictions = data.get('failure_predictions', [])
    if predictions:
        for pred in predictions:
            confidence_pct = int(pred['confidence'] * 100)
            report_content += f'''#### {pred['component'].title()} Failure Prediction
- **Confidence**: {confidence_pct}%
- **Prediction**: {pred['prediction']}
- **Timeframe**: {pred['timeframe'].replace('_', ' ')}
- **Recommended Action**: {pred['recommended_action']}

'''
    else:
        report_content += 'No failure predictions available.\n'
    
    report_content += '''### Self-Healing Actions Performed

'''
    
    healing_actions = data.get('self_healing_actions', {})
    if healing_actions:
        recent_actions = dict(list(healing_actions.items())[-5:])  # Last 5 action sets
        for timestamp, actions in recent_actions.items():
            report_content += f'**{timestamp}**:\n'
            for action in actions:
                status = '✅' if 'Successfully' in action or 'verified' in action.lower() else '❌' if 'Failed' in action or 'error' in action.lower() else '⚠️'
                report_content += f'- {status} {action}\n'
            report_content += '\n'
    else:
        report_content += 'No self-healing actions recorded.\n'
    
    report_content += '''## Recommendations

### Immediate Actions
1. **Review High-Confidence Predictions**: Address any predictions with >80% confidence
2. **Monitor Critical Components**: Focus on frequently failing components
3. **Update Dependencies**: Ensure all required packages are installed

### Preventive Measures
1. **Regular Health Checks**: Run automated tests daily
2. **Log Rotation**: Implement log rotation to prevent disk space issues
3. **Backup Strategies**: Ensure critical data is backed up regularly

### Long-term Improvements
1. **Enhanced Monitoring**: Add more comprehensive system monitoring
2. **Automated Scaling**: Implement auto-scaling for high-load scenarios
3. **Redundancy**: Add redundancy for critical system components

---
Report generated by predictive failure analysis system
'''
    
    with open(report_file, 'w') as f:
        f.write(report_content)
    
    print(f'Predictive report generated: {report_file}')
else:
    print('No predictive data available for report generation')
" 2>/dev/null

    log_success "Predictive analysis report generated."
}

main() {
    log_info "Starting Predictive Failure Analysis and Self-Healing System"

    # Ensure required tools are available
    if ! command -v python3 >/dev/null 2>&1; then
        log_error "python3 is required but not installed"
        exit 1
    fi

    # Create directories if they don't exist
    mkdir -p "$REPORTS_DIR"

    # Run predictive analysis pipeline
    initialize_predictive_data
    analyze_historical_patterns
    # Optional ML enhanced prediction step
    if [[ -f "$WORKSPACE_ROOT/predictive_ml_model.py" ]]; then
        log_info "Running ML predictive model refinement..."
        python3 "$WORKSPACE_ROOT/predictive_ml_model.py" "$PREDICTIVE_DATA_FILE" || log_warning "ML model step failed"
    fi
    implement_self_healing
    generate_predictive_report

    log_success "Predictive analysis and self-healing complete!"
}

# Run main if script is called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
