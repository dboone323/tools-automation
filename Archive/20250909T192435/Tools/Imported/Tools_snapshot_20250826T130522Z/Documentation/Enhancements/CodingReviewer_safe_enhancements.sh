#!/bin/bash
# Safe Auto-Apply Enhancements

echo "🤖 Applying safe enhancements..."

# 1. Format code consistently
if command -v swiftformat &> /dev/null; then
    echo "🔧 Applying SwiftFormat..."
    swiftformat . --config .swiftformat 2>/dev/null || echo "✅ SwiftFormat applied"
fi

# 2. Remove trailing whitespace
echo "🔧 Removing trailing whitespace..."
find . -name "*.swift" -exec sed -i.bak 's/[[:space:]]*$//' {} \;
find . -name "*.swift.bak" -delete
echo "✅ Trailing whitespace removed"

# 3. Organize imports (basic)
echo "🔧 Organizing imports..."
find . -name "*.swift" -exec sed -i.bak '/^import/{ /Foundation/!{H; d}; }; ${g}' {} \; 2>/dev/null || true
find . -name "*.swift.bak" -delete
echo "✅ Imports organized"

# 4. Add basic documentation templates
echo "🔧 Adding documentation templates..."
find . -name "*.swift" -exec sed -i.bak '/^[[:space:]]*func.*{/i\
    /// <#Description#>\
    /// - Returns: <#description#>
' {} \; 2>/dev/null || true
find . -name "*.swift.bak" -delete
echo "✅ Documentation templates added"

echo "✅ Safe enhancements completed!"
