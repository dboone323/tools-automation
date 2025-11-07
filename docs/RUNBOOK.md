# Tools-Automation Runbook

## Overview

This runbook provides operational procedures for the 100% autonomous agent system running on macOS with local-first AI operations, MCP-standardized coordination, and comprehensive observability.

## System Architecture

- **Local-first AI**: Ollama models with bounded cloud fallback
- **MCP Coordination**: Versioned API endpoints with authentication
- **Git Flow**: Pre-commit, pre-push, post-merge hooks with auto-rollback
- **Dependency Graph**: Cross-project impact analysis
- **Launchd Services**: Persistent background agents

## Starting Services

### Launchd Services

All core services run via launchd for automatic restart:

```bash
# Check service status
launchctl list | grep com.tools

# Restart a service
launchctl unload ~/Library/LaunchAgents/com.tools.agent.monitoring.plist
launchctl load ~/Library/LaunchAgents/com.tools.agent.monitoring.plist

# View service logs
tail -f ~/Library/Logs/tools-automation/*.log
```

### Manual Startup

If launchd fails:

```bash
# Start MCP server
python3 mcp_server.py &

# Start Ollama
ollama serve &

# Start agents
./agents/agent_monitoring.sh --once &
./agents/task_orchestrator.sh &
./agents/dependency_graph_agent.sh &
```

## Checking Health

### System Health

```bash
# Overall dashboard
./dashboard_unified.sh

# Agent status
jq .agent_status agent_status.json

# Service health
curl http://127.0.0.1:5005/v1/health
```

### AI Health

```bash
# Ollama status
curl http://localhost:11434/api/tags

# Cloud fallback status
jq .ai_metrics dashboard_data.json
```

### Submodule Health

```bash
# Per-submodule metrics
jq .submodule_metrics dashboard_data.json

# Dependency graph
jq . dependency_graph.json
```

## Monitoring & Alerts

### Viewing Metrics

```bash
# Real-time dashboard
open http://localhost:8080

# Throughput metrics
jq .throughput_metrics dashboard_data.json

# Error budgets
jq .error_budget_status dashboard_data.json
```

### Alert Management

```bash
# View recent alerts
tail -20 logs/alerts.jsonl | jq .

# Alert configuration
cat alert_config.json
```

## Common Troubleshooting

### Services Not Starting

```bash
# Check launchd status
launchctl list | grep com.tools

# Validate plists
./scripts/validate_launchd.sh

# Check logs
tail -50 ~/Library/Logs/tools-automation/*.log
```

### AI Fallback Issues

```bash
# Check quota
jq .ai_metrics.quota_remaining dashboard_data.json

# Review escalation log
tail -20 logs/cloud_escalation_log.jsonl

# Reset circuit breaker
# Edit config/cloud_fallback_config.json
```

### Test Failures

```bash
# Run with retry
RETRY_POLICY=ci ./ci_orchestrator.sh smoke

# Check retry stats
jq . metrics/test_retry_stats.jsonl
```

### Git Flow Issues

```bash
# Check hooks
ls -la .git/hooks/

# Test merge guard
./merge_guard.sh

# Check error budget
./scripts/check_error_budget.sh post_merge_tests
```

## Emergency Procedures

### Full System Reset

```bash
# Stop all services
launchctl unload ~/Library/LaunchAgents/com.tools.*.plist

# Reset state
rm -rf logs/* metrics/* incidents/*

# Restart
./scripts/install_launchd_jobs.sh --load
```

### Rollback Deployment

```bash
# Check checkpoints
./agents/auto_rollback.sh list

# Rollback to checkpoint
./agents/auto_rollback.sh restore <checkpoint_id>
```

### Quota Management

```bash
# View current quotas
jq .ai_metrics.quota_remaining dashboard_data.json

# Reset quotas (emergency)
# Edit config/cloud_fallback_config.json
```

## Maintenance Tasks

### Daily

- Review dashboard for anomalies
- Check error budgets
- Monitor AI fallback rates

### Weekly

- Review alert trends
- Update dependencies
- Validate backups

### Monthly

- Full system test
- Security audit
- Performance optimization

## Security

- MCP endpoints require `X-Auth-Token` header
- Tokens stored in macOS Keychain
- Local-only binding (127.0.0.1)
- No external network exposure

## Performance Tuning

### Circuit Breakers

- Default: 3 failures trigger OPEN state
- Auto-reset after 10 minutes

### Retry Policies

- CI mode: 3 retries with backoff
- Local mode: No retries

### Error Budgets

- Post-merge tests: 5% error rate allowed
- Auto-rollback when budget exceeded

## Contact & Support

For issues not covered here:

1. Check logs in `~/Library/Logs/tools-automation/`
2. Review dashboard metrics
3. Check agent status in `agent_status.json`
4. File issue in repository with logs attached
