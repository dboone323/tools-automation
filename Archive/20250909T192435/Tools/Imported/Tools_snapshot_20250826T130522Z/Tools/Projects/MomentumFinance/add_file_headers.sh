#!/bin/bash

# Script to add standardized file headers to all Swift files
# Based on SwiftLint configuration requirements

echo "Adding standardized file headers to Swift files..."

# Find all Swift files in the project
find . -name "*.swift" -not -path "./.build/*" -not -path "./build/*" | while read file; do
    echo "Processing: $file"
    
    # Get the absolute path for the filepath comment
    filepath="$PWD/$file"
    
    # Check if file already has proper header
    if head -3 "$file" | grep -q "Momentum Finance - Personal Finance App"; then
        echo "  ✓ Already has proper header"
        continue
    fi
    
    # Create temporary file with proper header
    temp_file=$(mktemp)
    
    # Add the standardized header
    cat > "$temp_file" << EOF
// filepath: $filepath
// Momentum Finance - Personal Finance App
// Copyright © 2025 Momentum Finance. All rights reserved.

EOF
    
    # Check if file already has a filepath comment and skip it
    if head -1 "$file" | grep -q "^// filepath:"; then
        # Skip the first line (existing filepath) and add the rest
        tail -n +2 "$file" >> "$temp_file"
    else
        # Add entire file content
        cat "$file" >> "$temp_file"
    fi
    
    # Replace the original file
    mv "$temp_file" "$file"
    echo "  ✓ Header added"
done

echo "File header processing complete!"
