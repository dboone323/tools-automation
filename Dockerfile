# Simplified Docker build for Hybrid Autonomy System
FROM python:3.11-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    bash \
    procps \
    supervisor \
    nginx \
    git \
    && rm -rf /var/lib/apt/lists/*

# Create app user
RUN useradd -m -s /bin/bash autonomy

# Set up directories
WORKDIR /app
RUN mkdir -p /app/logs /app/config /app/agents /app/monitoring/reports

# Copy Python requirements and install
COPY requirements.txt* ./
RUN pip install --no-cache-dir -r requirements.txt 2>/dev/null || echo "No requirements.txt found"

# Copy application files
COPY *.py *.sh *.json *.md /app/
COPY agents/ /app/agents/
COPY config/ /app/config/
COPY monitoring/ /app/monitoring/

# Copy dashboard server
COPY dashboard_server.py /app/

# Copy health check script
COPY health_check.py /app/health_check.py
RUN chmod +x /app/health_check.py

# Copy web assets
COPY hybrid-desktop-app/index.html /app/

# Set up supervisor for process management
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Set up nginx for web serving
COPY nginx.conf /etc/nginx/nginx.conf

# Create log files
RUN touch /app/logs/autonomous.log /app/logs/mcp_server.log /app/logs/health_monitor.log

# Set permissions
RUN chown -R autonomy:autonomy /app

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Expose ports
EXPOSE 8000 3000

# Start supervisor to manage all services
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]