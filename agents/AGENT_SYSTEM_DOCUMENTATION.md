# Agent System Documentation

## Overview
The Quantum Workspace Agent System is a comprehensive automation framework designed to enhance development productivity through specialized AI-powered agents. This system provides automated testing, security analysis, performance monitoring, and various development assistance capabilities.

## Architecture

### Core Components
- **MCP Server**: Python-based coordination server (`mcp_server.py`) running on port 5005
- **Agent Supervisor**: Bash-based supervisor managing agent lifecycle (`agent_supervisor.sh`)
- **Task Queue**: JSON-based task management system (`task_queue.json`)
- **Agent Status**: Real-time agent status tracking (`agent_status.json`)
- **Performance Monitor**: System resource and agent performance tracking

### Agent Types

#### 1. Testing Agent (`agent_testing.sh`)
**Purpose**: Automated test generation, execution, and coverage analysis for Swift projects

**Capabilities**:
- Unit test generation for Swift classes and structs
- Test suite execution using Xcode
- Test coverage analysis and reporting
- Identification of untested code
- Integration with backup system for safe modifications

**Configuration**:
- Sleep interval: 15 minutes (900 seconds)
- Log file: `testing_agent.log`
- Project directory: `/Users/danielstevens/Desktop/Quantum-workspace/Projects`

#### 2. Security Agent (`agent_security.sh`)
**Purpose**: Comprehensive security vulnerability scanning and compliance checking

**Capabilities**:
- Static security analysis of Swift source code
- Hardcoded secrets detection
- Insecure networking identification
- Weak cryptography analysis
- Input validation and SQL injection detection
- Access control review
- Dependency vulnerability scanning
- Privacy compliance checking
- Automated security report generation

**Security Checks**:
- **Hardcoded Secrets**: API keys, passwords, tokens
- **Insecure Networking**: HTTP URLs, missing certificate validation
- **Weak Cryptography**: MD5/SHA1 usage, proper CryptoKit validation
- **Input Validation**: User input handling, sanitization checks
- **Access Control**: Authentication checks, access modifier analysis
- **Compliance**: Data privacy, storage security

#### 3. Performance Monitor (`agent_performance_monitor.sh`)
**Purpose**: System resource monitoring and agent efficiency tracking

**Capabilities**:
- Real-time system metrics collection (CPU, memory, disk, processes)
- Agent status monitoring and reporting
- Task queue analysis and completion rate tracking
- Performance trend analysis with alerts
- Automated performance report generation
- Resource usage warnings and critical alerts

**Monitoring Metrics**:
- CPU usage percentage
- Memory usage percentage
- Disk usage percentage
- Process count
- Agent count and status
- Task completion rates

## Integration and Workflow

### Task Processing Flow
1. **Task Creation**: Tasks are added to `task_queue.json` with specific agent assignment
2. **Agent Discovery**: Agents continuously poll the task queue for assigned tasks
3. **Task Execution**: Assigned agent processes the task and updates status
4. **Result Reporting**: Task completion status is updated in the queue
5. **Performance Tracking**: Performance monitor tracks all agent activities

### Agent Communication
- **Status Updates**: Agents update `agent_status.json` with current status and PID
- **Task Updates**: Agents update `task_queue.json` with task progress
- **Logging**: All agents maintain individual log files for debugging
- **Performance Data**: Performance metrics stored in `performance_metrics.json`

## Configuration Files

### agent_status.json
Tracks the current status of all agents:
```json
{
  "agents": {
    "agent_name": {
      "status": "running|idle|stopped",
      "pid": 12345
    }
  },
  "last_update": 1757975491
}
```

### task_queue.json
Manages pending and completed tasks:
```json
{
  "tasks": [
    {
      "id": "task_001",
      "type": "security|testing|build|debug",
      "description": "Task description",
      "priority": 1-10,
      "assigned_agent": "agent_name.sh",
      "status": "queued|running|completed|failed",
      "created": 1757975491,
      "dependencies": []
    }
  ],
  "completed": [],
  "failed": []
}
```

### performance_metrics.json
Stores historical performance data:
```json
{
  "metrics": [
    {
      "timestamp": 1757975491,
      "cpu_usage": "45.2",
      "memory_usage": "67.8",
      "disk_usage": "31",
      "process_count": 732,
      "agent_count": 17
    }
  ]
}
```

## Usage Examples

### Running Security Analysis
```bash
# Add security task to queue
jq '.tasks += [{
  "id": "security_001",
  "type": "security",
  "description": "Security analysis for MyProject",
  "priority": 9,
  "assigned_agent": "agent_security.sh",
  "status": "queued",
  "created": '$(date +%s)',
  "dependencies": []
}]' task_queue.json > task_queue.json.tmp && mv task_queue.json.tmp task_queue.json
```

### Running Test Generation
```bash
# Add testing task to queue
jq '.tasks += [{
  "id": "testing_001",
  "type": "testing",
  "description": "Generate tests for MyProject",
  "priority": 8,
  "assigned_agent": "agent_testing.sh",
  "status": "queued",
  "created": '$(date +%s)',
  "dependencies": []
}]' task_queue.json > task_queue.json.tmp && mv task_queue.json.tmp task_queue.json
```

### Monitoring Performance
```bash
# Check current performance metrics
tail -20 performance_monitor.log

# View latest performance report
ls -la PERFORMANCE_REPORT_*.md | tail -1 | xargs cat
```

## Best Practices

### Agent Development
1. **Error Handling**: Always include proper error handling and logging
2. **Resource Management**: Monitor resource usage and implement cleanup
3. **Status Updates**: Regularly update agent status for monitoring
4. **Backup Integration**: Use backup system before making file changes
5. **Lint Compliance**: Ensure all scripts pass shellcheck validation

### Task Management
1. **Priority Assignment**: Use priority levels 1-10 for task scheduling
2. **Dependency Management**: Specify task dependencies when required
3. **Status Tracking**: Update task status throughout execution
4. **Error Reporting**: Provide detailed error information for failed tasks

### Performance Optimization
1. **Sleep Intervals**: Adjust sleep intervals based on task frequency
2. **Resource Limits**: Monitor and limit resource usage per agent
3. **Concurrent Processing**: Design agents for concurrent task processing
4. **Cleanup**: Implement proper cleanup of temporary files and processes

## Troubleshooting

### Common Issues

#### Agent Not Starting
- Check file permissions: `chmod +x agent_name.sh`
- Verify bash path and dependencies
- Check log files for error messages

#### Tasks Not Processing
- Verify task assignment matches agent name
- Check agent status in `agent_status.json`
- Review agent logs for processing errors

#### Performance Issues
- Monitor CPU/memory usage with performance monitor
- Adjust agent sleep intervals
- Review task queue for bottlenecks

#### Integration Problems
- Verify MCP server is running on port 5005
- Check JSON file syntax and permissions
- Review agent communication logs

## Future Enhancements

### Planned Features
- **Web Dashboard**: Real-time agent monitoring interface
- **Advanced Analytics**: Detailed performance analytics and reporting
- **Agent Auto-scaling**: Dynamic agent spawning based on workload
- **Plugin System**: Extensible plugin architecture for custom agents
- **Alert System**: Email/Slack notifications for critical events
- **Historical Analysis**: Long-term trend analysis and forecasting

### Agent Extensions
- **Documentation Agent**: Automated documentation generation
- **Deployment Agent**: CI/CD pipeline integration
- **Code Review Agent**: Automated code review and suggestions
- **Database Agent**: Database migration and optimization
- **API Testing Agent**: REST API testing and validation

## Support and Maintenance

### Log Files
- `security_agent.log`: Security analysis activities
- `testing_agent.log`: Test generation and execution
- `performance_monitor.log`: System performance data
- `agent_supervisor.log`: Agent lifecycle management

### Backup and Recovery
- Automatic backups before file modifications
- Recovery procedures documented in backup logs
- Configuration snapshots for system restoration

### Monitoring and Alerts
- Performance thresholds with automatic alerts
- Agent health checks with restart capabilities
- Task failure notifications and retry mechanisms

---

*Documentation generated: September 15, 2025*
*Agent System Version: 2.0*