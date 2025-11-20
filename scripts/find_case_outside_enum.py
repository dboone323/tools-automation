#!/usr/bin/env python3
import re
import sys
from pathlib import Path

enum_start_re = re.compile(r"^\s*(?:public|private|internal|fileprivate|open|@objc\s+)?enum\s+\w+.*\{\s*$")
brace_open_re = re.compile(r"\{")
brace_close_re = re.compile(r"\}")
case_re = re.compile(r"^\s*case\b")


def find_cases_outside_enum(path: Path):
    text = path.read_text(encoding='utf-8')
    lines = text.splitlines()
    stack = []  # stack of ('enum'|'other')
    for idx, line in enumerate(lines, start=1):
        if enum_start_re.match(line):
            stack.append('enum')
            continue
        # count braces, but we must check for opening brace that isn't enum start
        opens = len(brace_open_re.findall(line))
        closes = len(brace_close_re.findall(line))
        if opens > 0:
            # all non-enum openings push 'other'
            for _ in range(opens):
                stack.append('other')
        if case_re.match(line):
            if not stack or stack[-1] != 'enum':
                print(f"Line {idx}: 'case' appears outside an enum: {line.strip()}")
        if closes > 0:
            for _ in range(closes):
                if stack:
                    stack.pop()


def main():
    if len(sys.argv) < 2:
        print('Usage: find_case_outside_enum.py <file>')
        sys.exit(1)
    file = sys.argv[1]
    find_cases_outside_enum(Path(file))

if __name__ == '__main__':
    main()
