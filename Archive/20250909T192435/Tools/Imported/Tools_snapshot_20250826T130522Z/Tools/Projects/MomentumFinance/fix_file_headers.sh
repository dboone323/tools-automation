#!/bin/bash

# Script to add standard file headers to Swift files
# Copyright © 2025 Momentum Finance. All rights reserved.

# Find all Swift files in the project (excluding .build directory)
files=$(find . -name "*.swift" -not -path "./.build/*")

# The standard file header
header="// filepath: \${file}
// Momentum Finance - Personal Finance App
// Copyright © 2025 Momentum Finance. All rights reserved."

# Process each file
for file in $files; do
    echo "Processing $file..."
    
    # Check if the file already has a standard header
    if grep -q "Copyright © 2025 Momentum Finance" "$file"; then
        echo "  File already has header, skipping..."
        continue
    fi
    
    # Get file content
    content=$(cat "$file")
    
    # Create header for this specific file
    thisHeader=$(echo "$header" | sed "s|\\\${file}|$file|g")
    
    # Create a temporary file with header + content
    echo "$thisHeader" > "$file.tmp"
    echo "" >> "$file.tmp"  # Add a blank line after header
    echo "$content" >> "$file.tmp"
    
    # Replace the original file
    mv "$file.tmp" "$file"
    
    echo "  Header added"
done

echo "File header processing complete!"
