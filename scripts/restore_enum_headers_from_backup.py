#!/usr/bin/env python3
import sys
import re
from pathlib import Path

case_prefix_re = re.compile(r"^\s*case\s+(?P<name>[\w`]+)\b")
enum_decl_re = re.compile(r"^\s*(?:public|private|internal|fileprivate|open|@objc\s+)?enum\s+(?P<name>\w+).*\{\s*$")


def find_enum_header_near_backup_backup_case(backup_text, case_line_text):
    # find the first occurrence of the case in backup and return the nearest enum header above it
    idx = backup_text.find(case_line_text)
    if idx == -1:
        return None
    # find lines up to idx
    before = backup_text[:idx]
    lines = before.splitlines()
    # search up to 20 lines above
    for i in range(len(lines)-1, max(-1, len(lines)-21), -1):
        line = lines[i]
        m = enum_decl_re.match(line)
        if m:
            return line.strip()
    return None


def restore_headers(current_file, backup_file, apply=False):
    cur_text = Path(current_file).read_text('utf-8')
    backup_text = Path(backup_file).read_text('utf-8')
    cur_lines = cur_text.splitlines()
    updated = False

    # find case lines outside enum using the existing script logic
    # reuse a simple stack parser
    enum_start_re = re.compile(r"^\s*(?:public|private|internal|fileprivate|open|@objc\s+)?enum\s+\w+.*\{\s*$")
    brace_open_re = re.compile(r"\{")
    brace_close_re = re.compile(r"\}")
    case_re = re.compile(r"^\s*case\b")

    stack = []
    for idx, line in enumerate(cur_lines):
        if enum_start_re.match(line):
            stack.append('enum')
        opens = len(brace_open_re.findall(line))
        closes = len(brace_close_re.findall(line))
        if opens > 0:
            for _ in range(opens):
                stack.append('other')
        if case_re.match(line) and (not stack or stack[-1] != 'enum'):
            # attempt to find header in backup using this exact case line text
            case_line_text = line.strip()
            header = find_enum_header_near_backup_backup_case(backup_text, case_line_text)
            if header:
                # Insert header above this line if header isn't already present in file scope
                # determine indent from current 'case' line
                indent = re.match(r"^(\s*)", line).group(1)
                header_with_indent = indent + header
                # check if header already exists above within last 10 lines
                should_insert = True
                for i in range(max(0, idx-10), idx):
                    if cur_lines[i].strip().startswith('enum ' + header.split()[1]):
                        should_insert = False
                        break
                if should_insert:
                    print(f"Would insert header '{header_with_indent}' before line {idx+1}: {line.strip()}")
                    if apply:
                        cur_lines.insert(idx, header_with_indent)
                        updated = True
                        # add a closing brace after the following case group? Leave it for now - rely on existing '}'
        if closes > 0:
            for _ in range(closes):
                if stack:
                    stack.pop()
    if apply and updated:
        Path(current_file).write_text('\n'.join(cur_lines) + '\n', encoding='utf-8')
        print(f"Applied header inserts to {current_file}")
    return updated


def main():
    if len(sys.argv) < 3:
        print('Usage: restore_enum_headers_from_backup.py <current_file> <backup_file> [--apply]')
        sys.exit(1)
    apply = '--apply' in sys.argv
    current, backup = sys.argv[1], sys.argv[2]
    restore_headers(current, backup, apply)

if __name__ == '__main__':
    main()
