#!/bin/bash
# Generate and store MCP auth token in Keychain

SERVICE="tools-automation-mcp"
TOKEN=$(openssl rand -hex 32)

# Store in Keychain
security add-generic-password -a "$USER" -s "$SERVICE" -w "$TOKEN" -U 2>/dev/null ||
    (security delete-generic-password -a "$USER" -s "$SERVICE" 2>/dev/null &&
        security add-generic-password -a "$USER" -s "$SERVICE" -w "$TOKEN" -U)

echo "MCP auth token generated and stored in Keychain (service: $SERVICE)"
echo "Token: $TOKEN"
echo ""
echo "To retrieve later:"
echo "  security find-generic-password -a \$USER -s '$SERVICE' -w"
echo "  Or use: ./security/keychain_secrets.sh get mcp"
