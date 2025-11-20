#!/usr/bin/env python3
"""
Safe wrapper to run find_duplicate_enum_cases.report_duplicates on each file with a per-file timeout.
"""
import sys
import multiprocessing
from pathlib import Path

# Ensure repo root is on sys.path so local 'scripts' module can be imported
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

# Import the existing functions
from scripts.find_duplicate_enum_cases import report_duplicates


def worker(file, q):
    try:
        r = report_duplicates(file, max_enum_size=worker.max_enum_size if hasattr(worker, 'max_enum_size') else 0)
        q.put((file, r, None))
    except Exception as e:
        q.put((file, None, str(e)))


def main():
    import argparse
    parser = argparse.ArgumentParser(description='Safely scan files for duplicate enum cases (per-file timeout).')
    parser.add_argument('files', nargs='+', help='Files to scan')
    parser.add_argument('--timeout', type=float, default=5.0, help='Per-file timeout in seconds')
    parser.add_argument('--max-enum-size', type=int, default=0, help='Skip scanning enum blocks larger than this (chars). 0=no limit')
    args = parser.parse_args()
    files = args.files
    timeout = args.timeout
    results = []
    for file in files:
        print(f"Scanning {file} with {timeout}s timeout")
        q = multiprocessing.Queue()
        # Attach max_enum_size to worker function for child process to pick up
        worker.max_enum_size = args.max_enum_size
        p = multiprocessing.Process(target=worker, args=(file, q))
        p.start()
        p.join(timeout)
        if p.is_alive():
            p.terminate()
            print(f"Timed out scanning {file}")
            results.append((file, None, 'timeout'))
            continue
        try:
            file, r, err = q.get_nowait()
        except Exception:
            print(f"No result for {file}")
            results.append((file, None, 'no result'))
            continue
        results.append((file, r, err))

    # Now print results
    found_any = False
    for file, r, err in results:
        if err:
            print(f"{file}: error: {err}")
            continue
        if not r:
            print(f"{file}: No duplicate enum cases found.")
            continue
        found_any = True
        print(f"{file}: Found duplicates:")
        for enum_name, start_line, dupes in r:
            print(f"  Enum {enum_name} at line {start_line} has duplicate cases:")
            for case_name, occurrences in dupes.items():
                print(f"    Case '{case_name}' appears {len(occurrences)} times:")
                for ln, full in occurrences:
                    print(f"      Line {ln}: {full}")

    if not found_any:
        print("No duplicates found in scanned files.")


if __name__ == '__main__':
    main()
