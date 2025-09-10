#!/bin/bash
set -e

# Advanced test to verify SwiftData models compile together properly
echo "🔍 Testing MomentumFinance App SwiftData Models..."

cd /Users/danielstevens/Desktop/MomentumFinaceApp

# Compile all model files together to resolve circular dependencies
echo "📊 Compiling all SwiftData models together..."
if ! swiftc -typecheck Shared/Models/*.swift 2>/dev/null; then
    echo "❌ Error when compiling models together"
    swiftc -typecheck Shared/Models/*.swift
    exit 1
else
    echo "✅ All SwiftData models compile successfully when built together"
fi

echo "🏁 SwiftData model test completed successfully!"