#!/usr/bin/env python3
import sys
import re
from pathlib import Path

enum_re = re.compile(r"^\s*(?P<prefix>(?:public|private|internal|fileprivate|open|@objc\s+)?)enum\s+(?P<name>\w+).*\{\s*$", re.MULTILINE)


def find_ranges(text):
    ranges = []
    for m in enum_re.finditer(text):
        start_idx = m.start()
        name = m.group('name')
        start_line = text[:start_idx].count('\n') + 1
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
        ranges.append((name, start_idx, end_idx, start_line))
    return ranges


def extract_case_entries(enum_text):
    entries = []
    lines = enum_text.splitlines()
    for idx, line in enumerate(lines, start=1):
        s = line.split('//')[0].strip()
        if not s:
            continue
        if s.startswith('case '):
            s2 = s[len('case '):].strip()
            parts = re.split(r',\s*(?![^()]*\))', s2)
            for p in parts:
                p = p.strip()
                if not p:
                    continue
                name_match = re.match(r'^(?P<name>\w+)', p)
                if name_match:
                    name = name_match.group('name')
                    entries.append((name, p, idx))
    return entries


def merge_enums(filepath, apply=False):
    p = Path(filepath)
    text = p.read_text(encoding='utf-8')
    ranges = find_ranges(text)
    enums = {}
    for name, start, end, line in ranges:
        block = text[start:end]
        cases = extract_case_entries(block)
        enums.setdefault(name, []).append((start, end, line, block, cases))
    to_modify = []
    for name, occurrences in enums.items():
        if len(occurrences) < 2:
            continue
        # Build merged map of case name to case text (pref raw value if present)
        case_map = {}  # name -> (full_text, prefer_order)
        # Keep order of first occurrence as base
        base_cases_order = [c[0] for c in occurrences[0][4]]
        for start, end, line, block, cases in occurrences:
            for c_name, c_text, c_line in cases:
                if c_name not in case_map:
                    case_map[c_name] = c_text
                else:
                    # prefer ones with '=' raw values
                    if '=' in c_text and '=' not in case_map[c_name]:
                        case_map[c_name] = c_text
        # If all cases are identical to first occurrence, we'll just remove duplicates
        base_case_texts = {c[0]: c[1] for c in occurrences[0][4]}
        # Determine merged order: start with base order, then append any new names
        merged_order = base_cases_order + [n for n in case_map.keys() if n not in base_cases_order]
        merged_cases_texts = [case_map[name] for name in merged_order]
        # Build merged enum block with same indentation as first occurrence
        first_start, first_end, first_line, first_block, first_cases = occurrences[0]
        indent = re.match(r"^(\s*)", first_block).group(1)
        header_match = re.match(r"^(?P<header>.*?)\{\s*$", first_block.splitlines()[0])
        header = first_block.splitlines()[0]
        merged_body_lines = []
        # Place each merged case as comma-separated in a single line, or grouped: keep simple single 'case' lines
        # We'll try to preserve a single 'case' line with comma-separated values if first used that
        comma_style = any(',' in p for _, p, _ in first_cases)
        if comma_style:
            # one 'case' line
            merged_case_line = 'case ' + ', '.join(merged_cases_texts)
            merged_body_lines.append(merged_case_line)
        else:
            for c in merged_cases_texts:
                merged_body_lines.append('case ' + c)
        # Reconstruct merged enum block
        body = '\n'.join([indent + '    ' + l for l in merged_body_lines]) + '\n'
        merged_block = header + '\n' + body + indent + '}'
        to_modify.append((name, occurrences, first_start, first_end, merged_block))
    if not to_modify:
        print('No enums to merge found.')
        return 0
    if not apply:
        print('Dry-run: the following enums would be merged:')
        for name, occurrences, first_start, first_end, merged_block in to_modify:
            print(f"Enum {name} occurrences: {[o[2] for o in occurrences]} -> merging into first at line {occurrences[0][2]}")
        return len(to_modify)
    # Apply modifications: replace first occurrence block with merged block, remove other occurrences
    new_text = text
    # remove occurrences in reverse order to prevent index shift
    for name, occurrences, first_start, first_end, merged_block in sorted(to_modify, key=lambda x: x[2], reverse=True):
        # replace first occurrence
        first_start, first_end, first_line, first_block, first_cases = occurrences[0]
        prefix = new_text[:first_start]
        suffix = new_text[first_end:]
        new_text = prefix + merged_block + suffix
        # Remove subsequent occurrences
        # Need to re-run find to get new index positions? We'll assume original indexes suffice because removal ordered from end
        for occ in occurrences[1:]:
            s, e, line, block, cases = occ
            # If the block hasn't been removed already (guard)
            if new_text.find(block) != -1:
                new_text = new_text.replace(block, '')
        print(f'Merged enum {name} and removed {len(occurrences)-1} duplicates.')
    backup = p.with_suffix('.merged.bak')
    p.write_text(text, encoding='utf-8')
    backup.write_text(text, encoding='utf-8')
    p.write_text(new_text, encoding='utf-8')
    print(f'Modified {filepath}, backup at {backup}')
    return len(to_modify)


def main():
    if len(sys.argv) < 2:
        print('Usage: merge_duplicate_enums.py <file> [--apply]')
        sys.exit(1)
    file = sys.argv[1]
    apply = '--apply' in sys.argv
    modified = merge_enums(file, apply)
    print(f'{modified} enums merged (dry-run = {not apply}).')

if __name__ == '__main__':
    main()
