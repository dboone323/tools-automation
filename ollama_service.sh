#!/bin/bash
# On-demand Ollama service manager

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

start_ollama() {
    if ! pgrep -f "ollama serve" >/dev/null; then
        echo "Starting Ollama service..."
        nohup ollama serve >/dev/null 2>&1 &
        sleep 3
        echo "Ollama started"
    else
        echo "Ollama already running"
    fi
}

stop_ollama() {
    if pgrep -f "ollama serve" >/dev/null; then
        echo "Stopping Ollama service..."
        pkill -f "ollama serve"
        sleep 2
        echo "Ollama stopped"
    else
        echo "Ollama not running"
    fi
}

case "${1:-status}" in
    start)
        start_ollama
        ;;
    stop)
        stop_ollama
        ;;
    restart)
        stop_ollama
        sleep 2
        start_ollama
        ;;
    status)
        if pgrep -f "ollama serve" >/dev/null; then
            echo "Ollama is running"
        else
            echo "Ollama is not running"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
