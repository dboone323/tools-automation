#!/bin/bash

# ngrok Management Script
set -e

SERVICE=$1
PORT=$2

if [[ -z "$SERVICE" || -z "$PORT" ]]; then
    echo "Usage: $0 <service> <port>"
    echo "Examples:"
    echo "  $0 grafana 3000"
    echo "  $0 prometheus 9090"
    exit 1
fi

echo "🌐 Starting ngrok tunnel for $SERVICE on port $PORT..."

# Start ngrok in background
ngrok http $PORT > /tmp/ngrok_$SERVICE.log 2>&1 &
NGROK_PID=$!

# Wait for ngrok to start
sleep 3

# Get the public URL
PUBLIC_URL=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url')

if [[ -n "$PUBLIC_URL" && "$PUBLIC_URL" != "null" ]]; then
    echo "✅ ngrok tunnel established!"
    echo "🌍 Public URL: $PUBLIC_URL"
    echo "🔗 Local service: http://localhost:$PORT"
    echo ""
    echo "💡 Press Ctrl+C to stop the tunnel"
    echo ""
    echo "📊 Tunnel status: http://localhost:4040"
    echo ""
    # Keep the script running to maintain the tunnel
    wait $NGROK_PID
else
    echo "❌ Failed to establish ngrok tunnel"
    kill $NGROK_PID 2>/dev/null || true
    exit 1
fi
