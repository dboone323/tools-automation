# Unified Todo Management System

A comprehensive, AI-powered todo management system that integrates agents, MCP (Minimal Coordination Protocol), and automated project analysis for managing todos across all aspects of development projects.

## 🎯 Overview

The Unified Todo Management System provides:

- **AI-Powered Analysis**: Automatically analyzes projects to identify tasks, issues, and improvements
- **Agent-Driven Execution**: Intelligent agents that can execute, assign, and manage todos
- **MCP Integration**: Distributed task execution using the Minimal Coordination Protocol
- **Web Dashboard**: Real-time monitoring and management interface
- **Comprehensive Coverage**: Handles security, performance, features, maintenance, and more

## 🏗️ Architecture

### Core Components

1. **TodoManager** (`unified_todo_manager.py`)

   - Core todo management logic with AI analysis
   - Thread-safe operations with queue processing
   - JSON persistence with atomic updates

2. **MCP Integration** (`mcp_todo_integration.py`)

   - JSON-based request/response system
   - Distributed task execution
   - Project analysis capabilities

3. **Unified Todo Agent** (`agents/unified_todo_agent.sh`)

   - Bash-based orchestration agent
   - Health monitoring and capability registration
   - Continuous project analysis and todo processing

4. **Dashboard API** (`todo_dashboard_api.py`)

   - RESTful API for dashboard operations
   - Real-time metrics and status updates
   - Integration with all system components

5. **Web Dashboard** (`todo_dashboard.html`)
   - Interactive web interface
   - Real-time charts and metrics
   - Todo management and monitoring

## 🚀 Quick Start

### Prerequisites

- Python 3.8+
- Bash shell
- Required Python packages: `flask`, `flask-cors`

### Installation

1. **Clone and setup the project:**

   ```bash
   cd /path/to/your/project
   # Ensure all system files are in place
   ```

2. **Install Python dependencies:**

   ```bash
   pip install flask flask-cors
   ```

3. **Make scripts executable:**
   ```bash
   chmod +x launch_todo_system.sh
   chmod +x agents/unified_todo_agent.sh
   ```

### Launch the System

Start the complete todo management system:

```bash
./launch_todo_system.sh start
```

This will launch:

- Todo Dashboard API (http://localhost:5000)
- Unified Todo Agent (background processing)

### Access the Dashboard

Open your browser and navigate to: **http://localhost:5000**

## 📊 Dashboard Features

### Real-time Metrics

- Total todos count
- Status distribution (pending, in-progress, completed)
- Category breakdown (security, performance, features, etc.)
- Priority levels (critical, high, medium, low)
- Overdue todos tracking

### Interactive Charts

- Status distribution (doughnut chart)
- Category distribution (bar chart)
- Priority distribution (pie chart)

### Todo Management

- View pending and critical todos
- Create new todos
- Update todo status and assignments
- Execute todos via MCP
- Generate comprehensive reports

### Agent Monitoring

- Real-time agent status
- Health checks
- Capability monitoring

## 🔧 System Management

### Launcher Commands

```bash
# Start all services
./launch_todo_system.sh start

# Stop all services
./launch_todo_system.sh stop

# Restart all services
./launch_todo_system.sh restart

# Check service status
./launch_todo_system.sh status

# Run health check
./launch_todo_system.sh health

# View recent logs
./launch_todo_system.sh logs
```

### Manual Operations

#### Analyze Project

Trigger comprehensive project analysis:

```bash
# Via dashboard: Click "🔍 Analyze Project"
# Or via API:
curl -X POST http://localhost:5000/api/todo/analyze
```

#### Process Todos

Execute pending todo processing:

```bash
# Via dashboard: Click "⚙️ Process Todos"
# Or via API:
curl -X POST http://localhost:5000/api/todo/process
```

#### Execute Critical Todos

Run critical priority todos:

```bash
# Via dashboard: Click "🚀 Execute Critical"
# Or via API:
curl -X POST http://localhost:5000/api/todo/execute-critical
```

## 🤖 Agent System

### Unified Todo Agent

The bash-based agent provides:

- **Health Monitoring**: Continuous system health checks
- **Project Analysis**: Automated project scanning for issues
- **Todo Processing**: Background execution of assigned todos
- **Capability Registration**: Dynamic agent capability management
- **Logging**: Comprehensive operation logging

### Agent Capabilities

- Security vulnerability scanning
- Performance optimization
- Code quality analysis
- Dependency management
- Build and deployment automation
- Documentation generation

## 🔌 MCP Integration

### Request/Response Format

The system uses JSON-based MCP communication:

```json
{
  "method": "todo.create",
  "params": {
    "title": "Fix security vulnerability",
    "description": "Update vulnerable dependency",
    "category": "security",
    "priority": "critical"
  }
}
```

### Supported MCP Methods

- `todo.create` - Create new todo
- `todo.update` - Update existing todo
- `todo.get` - Retrieve todo details
- `todo.list` - List todos with filters
- `todo.assign` - Assign todo to agent
- `todo.execute` - Execute todo via MCP
- `project.analyze` - Analyze project for todos

## 📈 Monitoring and Logging

### Log Files

- `logs/todo_dashboard_api.log` - API server logs
- `logs/unified_todo_agent.log` - Agent operation logs
- `logs/dashboard_api.pid` - API process ID
- `logs/unified_todo_agent.pid` - Agent process ID

### Health Checks

The system includes comprehensive health monitoring:

- Service availability checks
- Agent responsiveness verification
- File system integrity validation
- Dependency verification

## 🔒 Security Features

- **Dependency Scanning**: Automated vulnerability detection
- **Backup File Removal**: Sensitive data protection
- **Access Control**: Agent capability restrictions
- **Audit Logging**: Comprehensive operation tracking

## 📋 Todo Categories

The system manages todos across these categories:

- **Security**: Vulnerabilities, access control, encryption
- **Performance**: Optimization, monitoring, scalability
- **Features**: New functionality, enhancements
- **Maintenance**: Code quality, refactoring, cleanup
- **Documentation**: README updates, API docs
- **Testing**: Unit tests, integration tests, coverage
- **Dependencies**: Package updates, compatibility
- **Infrastructure**: Build, deployment, CI/CD

## 🚨 Priority Levels

- **Critical**: System-breaking issues, security vulnerabilities
- **High**: Important features, performance issues
- **Medium**: Nice-to-have improvements, maintenance
- **Low**: Minor optimizations, documentation updates

## 🔄 Integration Examples

### Create Todo via API

```bash
curl -X POST http://localhost:5000/api/todo/create \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Update README",
    "description": "Add installation instructions",
    "category": "documentation",
    "priority": "medium"
  }'
```

### Get Dashboard Data

```bash
curl http://localhost:5000/api/todo/dashboard
```

### Assign Todo to Agent

```bash
curl -X POST http://localhost:5000/api/todo/123/assign \
  -H "Content-Type: application/json" \
  -d '{"agent_name": "documentation_agent"}'
```

## 🛠️ Development

### Adding New Agents

1. Create agent script in `agents/` directory
2. Register capabilities in agent initialization
3. Update launcher script if needed
4. Add agent monitoring to dashboard

### Extending MCP Methods

1. Add method handlers in `mcp_todo_integration.py`
2. Update API endpoints in `todo_dashboard_api.py`
3. Add UI controls in dashboard HTML
4. Test integration thoroughly

### Custom Categories/Priorities

Modify enums in `unified_todo_manager.py`:

```python
class TodoCategory(Enum):
    SECURITY = "security"
    PERFORMANCE = "performance"
    YOUR_NEW_CATEGORY = "your_new_category"
```

## 📊 Reporting

### Generate Comprehensive Report

```bash
# Via dashboard: Click "📊 Generate Report"
# Or via API:
curl -X POST http://localhost:5000/api/todo/report
```

Reports include:

- Todo completion statistics
- Category and priority breakdowns
- Agent performance metrics
- Project health assessment
- Recommendations for improvement

## 🐛 Troubleshooting

### Common Issues

1. **Port already in use**

   - Check if services are already running: `./launch_todo_system.sh status`
   - Kill existing processes: `./launch_todo_system.sh stop`

2. **Missing dependencies**

   - Install required packages: `pip install flask flask-cors`
   - Run health check: `./launch_todo_system.sh health`

3. **Agent not responding**

   - Check agent logs: `./launch_todo_system.sh logs`
   - Restart services: `./launch_todo_system.sh restart`

4. **Dashboard not loading**
   - Verify API is running: `curl http://localhost:5000/api/todo/dashboard`
   - Check browser console for JavaScript errors

### Debug Mode

Enable debug logging by modifying the launcher script:

```bash
# In launch_todo_system.sh, change:
python3 todo_dashboard_api.py
# To:
python3 todo_dashboard_api.py --debug
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For issues and questions:

1. Check the troubleshooting section
2. Review logs: `./launch_todo_system.sh logs`
3. Run health check: `./launch_todo_system.sh health`
4. Create an issue with detailed information

---

**🎯 The Unified Todo Management System transforms complex project management into an automated, intelligent workflow powered by AI agents and distributed execution.**
