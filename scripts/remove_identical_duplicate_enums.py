#!/usr/bin/env python3
import sys
import re
from pathlib import Path


enum_re = re.compile(r"^\s*(?:public|private|internal|fileprivate|open|@objc\s+)?enum\s+(\w+).*\{\s*$", re.MULTILINE)


def find_ranges(text):
    ranges = []
    for m in enum_re.finditer(text):
        start_idx = m.start()
        name = m.group(1)
        brace_idx = text.find('{', m.end()-1)
        depth = 1
        i = brace_idx+1
        while i < len(text) and depth > 0:
            if text[i] == '{':
                depth += 1
            elif text[i] == '}':
                depth -= 1
            i += 1
        end_idx = i
        start_line = text[:start_idx].count('\n') + 1
        ranges.append((name, start_idx, end_idx, start_line))
    return ranges


def remove_identical_duplicates(filepath):
    p = Path(filepath)
    text = p.read_text(encoding='utf-8')
    ranges = find_ranges(text)
    by_name = {}
    duplicates = []
    for name, start, end, line in ranges:
        block = text[start:end]
        if name not in by_name:
            by_name[name] = (block, start, end, line)
        else:
            orig_block = by_name[name][0]
            if block.strip() == orig_block.strip():
                duplicates.append((name, start, end, line))
            else:
                print(f"Enum {name} at line {line} differs from first occurrence; skipping.")
    if not duplicates:
        print("No identical duplicate enums found to remove.")
        return 0
    # Remove duplicates from text - delete them from the end to avoid shifting indexes
    duplicates_sorted = sorted(duplicates, key=lambda x: x[1], reverse=True)
    newtext = text
    for name, start, end, line in duplicates_sorted:
        # Remove leading whitespace and the enum block
        # Also remove any trailing empty lines
        prefix = newtext[:start]
        suffix = newtext[end:]
        newtext = prefix.rstrip() + '\n\n' + suffix.lstrip()
        print(f"Removed identical duplicate enum {name} at line {line}")
    # back up original
    backup = p.with_suffix('.swift.bak')
    p.write_text(text, encoding='utf-8')
    backup.write_text(text, encoding='utf-8')
    p.write_text(newtext, encoding='utf-8')
    print(f"Wrote cleaned file to {filepath}, backup saved as {backup}")
    return len(duplicates)


def main():
    if len(sys.argv) < 2:
        print("Usage: remove_identical_duplicate_enums.py <file>")
        sys.exit(1)
    file = sys.argv[1]
    removed = remove_identical_duplicates(file)
    print(f"Removed {removed} identical duplicate enum blocks.")

if __name__ == '__main__':
    main()
