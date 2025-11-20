#!/usr/bin/env python3
import sys
import re
from pathlib import Path
import argparse
import time
import concurrent.futures
import multiprocessing

def find_enum_blocks(text, max_enum_size=0):
    # Use single-pass matching to avoid quadratic behavior: find 'enum' then scan forward until matching brace
    enum_re = re.compile(r"^\s*(?:public|private|internal|fileprivate|open|@objc\s+)?enum\s+(\w+).*\{", re.MULTILINE)
    pos = 0
    text_len = len(text)
    while True:
        m = enum_re.search(text, pos)
        if not m:
            break
        start_idx = m.start()
        name = m.group(1)
        brace_idx = text.find('{', m.end()-1)
        if brace_idx == -1:
            pos = m.end()
            continue
        depth = 1
        i = brace_idx + 1
        while i < text_len and depth > 0:
            ch = text[i]
            if ch == '{':
                depth += 1
            elif ch == '}':
                depth -= 1
            i += 1
        end_idx = i
        # If max_enum_size provided and block size exceeds it, skip to avoid huge scanning
        if max_enum_size and (end_idx - start_idx) > max_enum_size:
            # yield a sentinel indicating skip (name, start, end, skipped)
            yield name, start_idx, end_idx, True
            continue
        yield name, start_idx, end_idx, False
        # continue scanning from end_idx to avoid rescanning inside this enum block
        pos = end_idx


def extract_cases(enum_text):
    cases = []
    lines = enum_text.splitlines()
    for idx, line in enumerate(lines, start=1):
        # remove trailing comments
        s = line.split('//')[0].strip()
        if not s:
            continue
        # handle 'case' lines
        if re.match(r"^case\b", s):
            # ignore 'case let' switch patterns and 'case .enumValue' switch entries inside computed properties
            if re.match(r"^case\s+let\b", s) or re.match(r"^case\s+\.", s):
                continue
            # strip leading 'case'
            s2 = s[len('case'):].strip()
            # remove context like '// comment' done above
            # split by commas not inside parentheses
            parts = re.split(r',\s*(?![^()]*\))', s2)
            for p in parts:
                p = p.strip()
                if not p:
                    continue
                # case value might be like 'function_call = "function_call"' or 'something(Associated(value))'
                name_match = re.match(r"^(\w+)\b", p)
                if name_match:
                    name = name_match.group(1)
                    cases.append((name, idx, p))
    return cases


def report_duplicates(filepath, max_enum_size=0):
    text = Path(filepath).read_text(encoding='utf-8')
    report = []
    for name, start, end, skipped in find_enum_blocks(text, max_enum_size=max_enum_size):
        block_text = text[start:end]
        # Calculate starting line number
        prior_text = text[:start]
        start_line = prior_text.count('\n') + 1
        if skipped:
            # mark large skipped enum by using a special entry
            report.append((name, start_line, {"<skipped-large-enum>": [(start_line, '<skipped>')]}))
            continue
        cases = extract_cases(block_text)
        counts = {}
        for name_case, rel_line, full in cases:
            counts.setdefault(name_case, []).append((start_line + rel_line - 1, full))
        dupes = {k:v for k,v in counts.items() if len(v) > 1}
        if dupes:
            report.append((name, start_line, dupes))
    return report


def _process_file(filepath):
    return filepath, report_duplicates(filepath)


def main():
    parser = argparse.ArgumentParser(description='Find duplicate enum cases in Swift files')
    parser.add_argument('files', nargs='+', help='Swift files to scan')
    parser.add_argument('--timeout', type=float, default=10.0, help='Timeout (s) per file')
    parser.add_argument('--max-enum-size', type=int, default=0, help='Skip scanning enum blocks larger than this (chars). 0=no limit')
    parser.add_argument('--workers', type=int, default=min(4, multiprocessing.cpu_count()), help='Number of parallel workers')
    args = parser.parse_args()

    timeout = args.timeout
    files = args.files
    workers = args.workers

    print(f"Scanning {len(files)} file(s) with timeout {timeout}s using {workers} workers")
    start_all = time.time()
    timed_out_files = []
    with concurrent.futures.ProcessPoolExecutor(max_workers=workers) as executor:
        futures = {executor.submit(_process_file, f): f for f in files}
        for fut in concurrent.futures.as_completed(futures):
            file = futures[fut]
            try:
                    _, r = fut.result(timeout=timeout)
            except concurrent.futures.TimeoutError:
                print(f"Timed out scanning {file} (>{timeout}s)")
                timed_out_files.append(file)
                continue
            except Exception as e:
                print(f"Error scanning {file}: {e}")
                continue

            if not r:
                print(f"{file}: No duplicate enum cases found.")
                continue
            print(f"{file}: Found duplicates:")
            for enum_name, start_line, dupes in r:
                print(f"  Enum {enum_name} at line {start_line} has duplicate cases:")
                for case_name, occurrences in dupes.items():
                    print(f"    Case '{case_name}' appears {len(occurrences)} times:")
                    for ln, full in occurrences:
                        print(f"      Line {ln}: {full}")
    total_time = time.time() - start_all
    print(f"Scan completed in {total_time:.1f}s")
    if timed_out_files:
        print("Timed out files:")
        for t in timed_out_files:
            print(f"  {t}")

if __name__ == '__main__':
    main()
