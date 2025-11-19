#!/usr/bin/env python3
import re
import sys
import argparse
from pathlib import Path

KEYWORDS = {"class","struct","enum","protocol","operator","import","typealias","return","throw","break","continue","self"}

case_pattern = re.compile(r"^\s*case\s+([a-z0-9_`]+)(\s*\(.*\))?(\s*=\s*\".*\")?\s*$")
enum_decl_pattern = re.compile(r"^\s*(public\s+|private\s+|internal\s+|fileprivate\s+)?enum\s+\w+\s*:\s*([A-Za-z0-9_,\s]+)\s*\{?\s*$")

def to_camel_case(s):
    parts = s.split('_')
    if not parts:
        return s
    return parts[0] + ''.join(p.capitalize() for p in parts[1:])


def process_file(path: Path, apply: bool=False):
    text = path.read_text()
    lines = text.splitlines()
    new_lines = []
    in_string_enum = False
    changed = False
    for line in lines:
        stripped = line.strip()
        m_enum = enum_decl_pattern.match(line)
        if m_enum:
            raw_types = m_enum.group(2)
            if 'String' in raw_types:
                in_string_enum = True
        if in_string_enum:
            m_case = case_pattern.match(line)
            if m_case:
                case_name = m_case.group(1)
                assoc = m_case.group(2) or ''
                raw_assign = m_case.group(3) or ''
                if raw_assign:
                    new_lines.append(line)
                    continue
                camel = to_camel_case(case_name)
                if case_name in KEYWORDS or case_name.startswith('`'):
                    stripped_name = case_name.strip('`')
                    camel_name = to_camel_case(stripped_name)
                    # use backticks for identifier if it matches a Swift keyword, but preserve original raw string
                    new_case = f"case `{camel_name}` = \"{stripped_name}\"" if camel_name != stripped_name else f"case `{stripped_name}` = \"{stripped_name}\""
                else:
                    if camel != case_name:
                        # Replace only the case identifier portion to avoid touching types or other text
                        new_case = re.sub(rf"(\b)\b{case_name}\b", rf"\1{camel} = \"{case_name}\"", line)
                    else:
                        new_case = line
                if new_case != line:
                    changed = True
                    print(f"Change planned in {path}: '{line.strip()}' -> '{new_case.strip()}'")
                new_lines.append(new_case)
            else:
                new_lines.append(line)
            if stripped.startswith('}'):
                in_string_enum = False
        else:
            new_lines.append(line)
    if changed and apply:
        path.write_text('\n'.join(new_lines) + '\n')
        print(f"Applied changes to {path}")
    return changed


def main():
    parser = argparse.ArgumentParser(description='Normalize snake_case enum cases to camelCase with raw values for String enums in shared-kit')
    parser.add_argument('--apply', action='store_true', help='Apply changes')
    args = parser.parse_args()

    root = Path('shared-kit')
    if not root.exists():
        print('shared-kit directory not found, running from repository root?')
        root = Path('.')
    files = list(root.rglob('*.swift'))
    total_changed = 0
    for f in files:
        changed = process_file(f, apply=args.apply)
        if changed:
            total_changed += 1
    print(f"Done. Files with planned/actual changes: {total_changed}")

if __name__ == '__main__':
    main()
