#!/usr/bin/env python3
import re
import sys
from pathlib import Path

case_eq_re = re.compile(r"^(?P<prefix>\s*case\s+[\w`\,\s]+?)\s*=\s*\"(?P<raw>.*?)\"(.*)$")


def fix_file(p: Path, apply=False):
    text = p.read_text(encoding='utf-8')
    lines = text.splitlines()
    changed = False
    new_lines = []
    for line in lines:
        m = case_eq_re.match(line)
        if m:
            prefix = m.group('prefix')
            raw = m.group('raw')
            rest = m.group(3)
            new_line = f"{prefix} = \"{raw}\"{rest}"
            if new_line != line:
                changed = True
                print(f"Fixing spacing in: '{line.strip()}' -> '{new_line.strip()}'")
            new_lines.append(new_line)
        else:
            new_lines.append(line)
    if changed and apply:
        p.write_text('\n'.join(new_lines) + '\n', encoding='utf-8')
        print(f"Applied spacing fixes to {p}")
    return changed


def main():
    if len(sys.argv) < 2:
        print("Usage: fix_case_equals_spacing.py <file> [--apply]")
        sys.exit(1)
    file = sys.argv[1]
    apply = '--apply' in sys.argv
    changed = fix_file(Path(file), apply)
    print(f"changed={changed}")

if __name__ == '__main__':
    main()
