#!/usr/bin/env python3
# Tools/Automation/regenerate_todo_json.py
# Properly regenerate the todo-tree-output.json file by scanning for actual TODO/FIXME comments

import os
import re
import json
import subprocess
from pathlib import Path
from typing import List, Dict, Any

def should_exclude_file(file_path: str) -> bool:
    """Check if file should be excluded from TODO scanning."""
    exclude_patterns = [
        # Virtual environments
        '.venv/', 'venv/', '__pycache__/',
        # Build artifacts
        '.build/', 'Pods/', 'node_modules/', 'build/', 'dist/',
        # Git
        '.git/',
        # IDE files
        '.vscode/', '.idea/', '*.swp', '*.swo',
        # OS files
        '.DS_Store', 'Thumbs.db',
        # Archives and binaries
        '.zip', '.tar.gz', '.tgz', '.png', '.jpg', '.jpeg', '.gif', '.ico', '.pdf',
        # Cache files
        '.pytest_cache/', '__pycache__/',
        # Test coverage
        '.coverage', 'coverage.xml', 'htmlcov/',
        # Documentation (we want to scan these but filter later)
        # Agent logs (we want to scan these but filter later)
        # Imported snapshots
        'Imported_Tools_snapshot-',
        'autofix_backups/',
        # Backup files
        '.backup', '.bak', '.orig', '.tmp',
    ]

    for pattern in exclude_patterns:
        if pattern in file_path:
            return True

    return False

def find_todo_comments(root_dir: str) -> List[Dict[str, Any]]:
    """Find all TODO and FIXME comments in the codebase."""
    todos = []

    # File extensions to scan
    extensions = ['.swift', '.sh', '.md', '.py', '.js', '.ts', '.json', '.yml', '.yaml']

    for root, dirs, files in os.walk(root_dir):
        # Skip excluded directories
        dirs[:] = [d for d in dirs if not should_exclude_file(os.path.join(root, d))]

        for file in files:
            if not any(file.endswith(ext) for ext in extensions):
                continue

            file_path = os.path.join(root, file)
            if should_exclude_file(file_path):
                continue

            try:
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    lines = f.readlines()

                for line_num, line in enumerate(lines, 1):
                    # Look for TODO and FIXME comments using multiple patterns
                    line_stripped = line.strip()

                    # Pattern 1: // TODO: comment
                    swift_match = re.search(r'//\s*(TODO|FIXME|HACK)\s*:?\s*(.+)', line_stripped, re.IGNORECASE)
                    if swift_match:
                        comment_type = swift_match.group(1).upper()
                        comment_text = swift_match.group(2).strip()
                    else:
                        # Pattern 2: # TODO: comment (Python/Shell)
                        python_match = re.search(r'#\s*(TODO|FIXME|HACK)\s*:?\s*(.+)', line_stripped, re.IGNORECASE)
                        if python_match:
                            comment_type = python_match.group(1).upper()
                            comment_text = python_match.group(2).strip()
                        else:
                            # Pattern 3: /* TODO: comment */ (block comments)
                            block_match = re.search(r'/\*\s*(TODO|FIXME|HACK)\s*:?\s*(.+?)\s*\*/', line_stripped, re.IGNORECASE)
                            if block_match:
                                comment_type = block_match.group(1).upper()
                                comment_text = block_match.group(2).strip()
                            else:
                                continue  # No TODO found, skip this line

                    # Skip if it's just a placeholder or not a real TODO
                    if any(skip in comment_text.lower() for skip in [
                        'placeholder', 'template', 'example', 'stub',
                        'implement me', 'not implemented', 'coming soon'
                    ]):
                        continue

                    todos.append({
                        'file': os.path.relpath(file_path, root_dir),
                        'line': line_num,
                        'text': f"{comment_type}: {comment_text}"
                    })

            except Exception as e:
                print(f"Error reading {file_path}: {e}")
                continue

    return todos

def main():
    """Main function to regenerate TODO JSON."""
    workspace_root = Path(__file__).parent.parent.parent

    # Focus on Projects directory for actual code
    projects_dir = workspace_root / 'Projects'

    print(f"🔍 Scanning for TODO/FIXME comments in {projects_dir}...")

    todos = find_todo_comments(str(projects_dir))

    # Sort by file path for consistency
    todos.sort(key=lambda x: (x['file'], x['line']))

    # Remove duplicates (same file, line, text)
    unique_todos = []
    seen = set()
    for todo in todos:
        key = (todo['file'], todo['line'], todo['text'])
        if key not in seen:
            unique_todos.append(todo)
            seen.add(key)

    # Write to JSON file
    output_file = workspace_root / 'Projects' / 'todo-tree-output.json'
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(unique_todos, f, indent=2, ensure_ascii=False)

    print("✅ TODO JSON regenerated successfully!")
    print(f"   📊 Found {len(unique_todos)} unique TODO/FIXME comments")
    print(f"   💾 Saved to {output_file}")

    # Show summary by file type
    file_types = {}
    for todo in unique_todos:
        ext = Path(todo['file']).suffix
        file_types[ext] = file_types.get(ext, 0) + 1

    print("\n📈 Breakdown by file type:")
    for ext, count in sorted(file_types.items()):
        print(f"   {ext}: {count} TODOs")

if __name__ == '__main__':
    main()

if __name__ == '__main__':
    main()
