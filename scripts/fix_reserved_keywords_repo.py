#!/usr/bin/env python3
import re
from pathlib import Path

KEYWORDS = set(["class","struct","enum","protocol","import","operator","typealias","return","throw","break","continue"])

def process_file(path: Path):
    text = path.read_text(encoding='utf-8')
    lines = text.splitlines()
    out = []
    in_enum = 0
    changed = False
    for line in lines:
        # update enum context
        if re.match(r'^\s*(?:public|private|fileprivate|internal|open|@objc\s+)?enum\b', line):
            in_enum += 1
        # update braces to track leaving
        # quick scan: adjust for braces
        opens = line.count('{')
        closes = line.count('}')
        # if currently inside an enum, attempt replacement on 'case' lines
        if in_enum > 0:
            m = re.match(r"^(\s*)case\s+(`?)(\w+)(`?)(.*)$", line)
            if m:
                indent, bq1, name, bq2, rest = m.groups()
                if name in KEYWORDS and not (bq1 or bq2):
                    # avoid 'case let' pattern
                    if not re.match(r"^let\b", name):
                        line = f"{indent}case `{name}`{rest}"
                        changed = True
        out.append(line)
        # adjust in_enum based on braces after processing
        in_enum += opens - closes
        if in_enum < 0:
            in_enum = 0

    if changed:
        bak = path.with_suffix(path.suffix + '.bak')
        bak.write_text(text, encoding='utf-8')
        path.write_text('\n'.join(out) + '\n', encoding='utf-8')
    return changed

def main():
    count = 0
    for p in Path('.').rglob('*.swift'):
        if process_file(p):
            print('Updated', p)
            count += 1
    print('Files updated:', count)

if __name__ == '__main__':
    main()
