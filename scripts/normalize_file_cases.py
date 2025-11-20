#!/usr/bin/env python3
import re
import sys
from pathlib import Path

case_pattern = re.compile(r"^(?P<prefix>\s*case\s+)(?P<cases>[^=\n]+)(?P<rest>\s*(\(.*\))?(\s*=\s\".*\")?\s*)$")

def to_camel_case(s):
    parts = s.split('_')
    if not parts:
        return s
    return parts[0] + ''.join(p.capitalize() for p in parts[1:])

def process_file(path: Path, apply: bool=False):
    text = path.read_text()
    lines = text.splitlines()
    changed = False
    new_lines = []
    for line in lines:
        m = case_pattern.match(line)
        if m:
            cases = m.group('cases')
            rest = m.group('rest') or ''
            case_names = [c.strip() for c in cases.split(',')]
            new_case_parts = []
            for name in case_names:
                if name.startswith('`') and name.endswith('`'):
                    stripped = name.strip('`')
                    camel = to_camel_case(stripped)
                    if rest.strip().startswith('='):
                        new_case_parts.append(name)
                    else:
                        new_case_parts.append(f'`{camel}` = "{stripped}"')
                else:
                    camel = to_camel_case(name)
                    if camel != name:
                        if rest.strip().startswith('='):
                            new_case_parts.append(name)
                        else:
                            new_case_parts.append(f'{camel} = "{name}"')
                    else:
                        new_case_parts.append(name)
            new_case = f"{m.group('prefix')}{', '.join(new_case_parts)}{rest}"
            if new_case != line:
                changed = True
                print(f"Change planned in {path}: '{line.strip()}' -> '{new_case.strip()}'")
            new_lines.append(new_case)
        else:
            new_lines.append(line)
    if changed and apply:
        path.write_text('\n'.join(new_lines) + '\n')
        print(f"Applied changes to {path}")
    return changed

def main():
    apply = '--apply' in sys.argv
    files = []
    if '--files' in sys.argv:
        idx = sys.argv.index('--files')
        files = sys.argv[idx+1:]
    else:
        print('No files specified')
        sys.exit(1)
    total = 0
    for f in files:
        p = Path(f)
        if p.exists() and process_file(p, apply=apply):
            total += 1
    print(f"Done. Files changed: {total}")

if __name__ == '__main__':
    main()
