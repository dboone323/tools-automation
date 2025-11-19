#!/usr/bin/env python3
import re
import sys
from pathlib import Path

KEYWORDS = [
    'class','struct','enum','protocol','operator','import','typealias','return','throw','break','continue','self','internal'
]

def escape_keywords_in_file(path: Path, apply=False):
    text = path.read_text()
    orig = text
    # backtick-escape properties like: let operator: -> let `operator`:
    text = re.sub(r"(^\s*(let|var)\s+)operator(\s*[:=])", r"\1`operator`\3", text, flags=re.MULTILINE)
    # backtick-escape case lines: case protocol, case `protocol`, case protocol( or case protocol =
    for kw in KEYWORDS:
        # skip if already backticked
        text = re.sub(rf"(^\s*case\s+)`?{kw}`?(\b|\s|,|\(|=)", rf"\1`{kw}`\2", text, flags=re.MULTILINE)
        # argument labels in initializers or function calls: protocol: .v2x -> `protocol`: .v2x
        text = re.sub(rf"(\W)`?{kw}`?\s*:\s", rf"\1`{kw}`:", text, flags=re.MULTILINE)
        # function parameter names and named arguments: func f(_ protocol: Type) -> should become func f(_ `protocol`: Type)
        text = re.sub(rf"(func\s+\w+\s*\([^)]*)`?{kw}`?\s*:\s*", lambda m, kw=kw: m.group(1) + f"`{kw}`: ", text, flags=re.MULTILINE)
        # normalize accidental repeated backticks: any sequence of backticks around kw -> single backtick pair
        text = re.sub(rf"`+{kw}`+", rf"`{kw}`", text)
        text = re.sub(rf"(^\s*let\s+)`?{kw}`?(\s*:)", rf"\1`{kw}`\2", text, flags=re.MULTILINE)
        text = re.sub(rf"(^\s*var\s+)`?{kw}`?(\s*[:=])", rf"\1`{kw}`\2", text, flags=re.MULTILINE)
    if text != orig:
        print(f"Changes planned for {path}")
        if apply:
            path.write_text(text)
            print(f"Applied reserved keyword fixes to {path}")
        return True
    return False

def main():
    apply = '--apply' in sys.argv
    files = []
    if '--files' in sys.argv:
        idx = sys.argv.index('--files')
        files = sys.argv[idx+1:]
    else:
        # default: read parser-skip list
        p = Path('/tmp/parser_skipped_files.txt')
        if p.exists():
            files = [l.strip() for l in p.read_text().splitlines() if l.strip()]
        else:
            print('No files list provided and /tmp/parser_skipped_files.txt not found')
            sys.exit(1)
    changed = 0
    for f in files:
        p = Path(f)
        if p.exists() and escape_keywords_in_file(p, apply=apply):
            changed += 1
    print(f"Done. Files changed: {changed}")

if __name__ == '__main__':
    main()
