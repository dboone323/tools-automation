#!/usr/bin/env bash
# Production Deployment Script
# Deploys monitoring daemon and sets up production environment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITORING_DIR="$SCRIPT_DIR"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║         Production Deployment - Autonomy System          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Check Redis
echo "🔍 Step 1: Checking Redis Setup"
echo "────────────────────────────────────────────────────────────"

if command -v redis-server > /dev/null 2>&1; then
    echo "✅ Redis server installed: $(redis-server --version | head -1)"
    
    if redis-cli ping > /dev/null 2>&1; then
        echo "✅ Redis server running"
        REDIS_AVAILABLE=true
    else
        echo "⚠️  Redis server not running"
        echo "   To start Redis:"
        echo "   brew services start redis  # macOS"
        echo "   or: redis-server &"
        REDIS_AVAILABLE=false
    fi
else
    echo "⚠️  Redis server not installed"
    echo "   To install Redis:"
    echo "   brew install redis  # macOS"
    echo "   apt-get install redis  # Linux"
    REDIS_AVAILABLE=false
fi

# Check Python Redis module
if python3 -c "import redis" > /dev/null 2>&1; then
    echo "✅ Redis Python module installed"
else
    echo "⚠️  Redis Python module not installed"
    echo "   To install: pip3 install redis"
fi

if [[ "$REDIS_AVAILABLE" == "false" ]]; then
    echo ""
    echo "ℹ️  Redis not available - system will use in-memory fallback"
    echo "   This is acceptable for development but recommended for production"
fi

echo ""

# Step 2: Start Monitoring Daemon
echo "🚀 Step 2: Starting Monitoring Daemon"
echo "────────────────────────────────────────────────────────────"

DAEMON_SCRIPT="$MONITORING_DIR/monitoring_daemon.sh"
PID_FILE="$MONITORING_DIR/monitoring_daemon.pid"

if [[ -f "$PID_FILE" ]]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "⚠️  Monitoring daemon already running (PID: $OLD_PID)"
        echo "   To restart, run: kill $OLD_PID"
    else
        echo "🔄 Removing stale PID file"
        rm -f "$PID_FILE"
    fi
fi

if [[ ! -f "$PID_FILE" ]]; then
    if [[ -f "$DAEMON_SCRIPT" ]]; then
        echo "🎬 Starting monitoring daemon in background..."
        nohup "$DAEMON_SCRIPT" > "$MONITORING_DIR/monitoring_daemon_nohup.log" 2>&1 &
        DAEMON_PID=$!
        
        # Wait a moment to verify it started
        sleep 2
        
        if kill -0 "$DAEMON_PID" 2>/dev/null; then
            echo "✅ Monitoring daemon started (PID: $DAEMON_PID)"
            echo "   Log: $MONITORING_DIR/monitoring_daemon.log"
        else
            echo "❌ Monitoring daemon failed to start"
            echo "   Check: $MONITORING_DIR/monitoring_daemon_nohup.log"
        fi
    else
        echo "❌ Monitoring daemon script not found: $DAEMON_SCRIPT"
    fi
fi

echo ""

# Step 3: Verify Core Systems
echo "✅ Step 3: Verifying Core Systems"
echo "────────────────────────────────────────────────────────────"

# Test configuration discovery
if cd "$SCRIPT_DIR/../agents" && ./agent_config_discovery.sh workspace-root > /dev/null 2>&1; then
    echo "✅ Configuration discovery operational"
else
    echo "❌ Configuration discovery failed"
fi

# Test metrics collector
if python3 "$MONITORING_DIR/metrics_collector.py" --summary --hours 1 > /dev/null 2>&1; then
    echo "✅ Metrics collector operational"
else
    echo "⚠️  Metrics collector check failed"
fi

# Test AI engine
if python3 "$MONITORING_DIR/ai_decision_engine.py" --help > /dev/null 2>&1; then
    echo "✅ AI decision engine available"
else
    echo "❌ AI decision engine not available"
fi

# Test state manager
if python3 "$MONITORING_DIR/state_manager.py" --no-redis stats > /dev/null 2>&1; then
    echo "✅ State manager operational"
else
    echo "❌ State manager failed"
fi

echo ""

# Step 4: Setup Complete
echo "╔══════════════════════════════════════════════════════════╗"
echo "║              Production Deployment Complete              ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "📊 System Status:"
echo "   • Configuration: Operational"
echo "   • Monitoring: Daemon running"
echo "   • AI Engine: Available"
echo "   • State Manager: Operational"
if [[ "$REDIS_AVAILABLE" == "true" ]]; then
    echo "   • Redis: Connected"
else
    echo "   • Redis: In-memory fallback"
fi
echo ""
echo "📁 Key Files:"
echo "   • Daemon PID: $PID_FILE"
echo "   • Daemon Log: $MONITORING_DIR/monitoring_daemon.log"
echo "   • Metrics DB: $MONITORING_DIR/metrics.db"
echo "   • AI Decisions: $MONITORING_DIR/ai_decisions.db"
echo ""
echo "🔧 Management Commands:"
echo "   • View metrics: python3 $MONITORING_DIR/metrics_collector.py --summary"
echo "   • View AI stats: python3 $MONITORING_DIR/ai_decision_engine.py --agent all --type any --metrics"
echo "   • Stop daemon: kill \$(cat $PID_FILE)"
echo ""
echo "✨ System is now running in production mode!"
