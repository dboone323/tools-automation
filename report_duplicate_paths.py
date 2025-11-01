#!/usr/bin/env python3
import re
import sys
from pathlib import Path
from collections import defaultdict

def parse_pbxproj(pbxproj_path: Path):
    text = pbxproj_path.read_text(encoding='utf-8', errors='replace')
    lines = text.splitlines()

    # Map fileRef UUID -> dict(name, path)
    file_refs = {}
    # Map group UUID -> list of child UUIDs (order and line index)
    group_children = defaultdict(list)

    # Parse PBXFileReference blocks
    in_file_ref = False
    current_uuid = None
    block_lines = []
    for i, line in enumerate(lines):
        m = re.match(r"^\s*([A-F0-9]{24}) \/\*.*?\*\/ = \{\s*$", line)
        if m:
            current_uuid = m.group(1)
            in_file_ref = False
            block_lines = [line]
            continue
        if current_uuid:
            block_lines.append(line)
            if 'isa = PBXFileReference;' in line:
                in_file_ref = True
            if in_file_ref and '};' in line:
                # extract name/path
                name = None
                path = None
                for bl in block_lines:
                    mn = re.search(r"name = ([^;]+);", bl)
                    if mn:
                        name = mn.group(1).strip().strip('"')
                    mp = re.search(r"path = ([^;]+);", bl)
                    if mp:
                        path = mp.group(1).strip().strip('"')
                file_refs[current_uuid] = {'name': name, 'path': path}
                current_uuid = None
                block_lines = []

    # Parse PBXGroup section and children lists
    in_group_section = False
    current_group = None
    in_children = False
    for i, line in enumerate(lines):
        if '/* Begin PBXGroup section */' in line:
            in_group_section = True
            continue
        if '/* End PBXGroup section */' in line:
            in_group_section = False
            current_group = None
            in_children = False
            continue
        if not in_group_section:
            continue
        mg = re.match(r"^\s*([A-F0-9]{24}) \/\*.*?\*\/ = \{", line)
        if mg:
            current_group = mg.group(1)
            in_children = False
            continue
        if current_group and 'children = (' in line:
            in_children = True
            continue
        if in_children and ');' in line:
            in_children = False
            continue
        if in_children and current_group:
            mc = re.match(r"^\s*([A-F0-9]{24}) \/\* (.+?) \*\/\s*,\s*$", line)
            if mc:
                child_uuid = mc.group(1)
                group_children[current_group].append(child_uuid)

    # Build reverse map: child UUID -> groups
    child_to_groups = defaultdict(list)
    for g, children in group_children.items():
        for c in children:
            child_to_groups[c].append(g)

    # Identify duplicate paths: same path across multiple file refs
    path_to_uuids = defaultdict(list)
    for uid, meta in file_refs.items():
        path = meta.get('path') or meta.get('name')
        if path:
            path_to_uuids[path].append(uid)

    duplicates = {p: uids for p, uids in path_to_uuids.items() if len(uids) > 1}

    return {
        'file_refs': file_refs,
        'group_children': group_children,
        'child_to_groups': child_to_groups,
        'duplicates': duplicates,
    }


def generate_report(project_dir: Path):
    pbxproj = project_dir / f"{project_dir.name}.xcodeproj" / 'project.pbxproj'
    data = parse_pbxproj(pbxproj)

    out = []
    out.append(f"# Duplicate File Reference Paths Report - {project_dir.name}")
    out.append("")
    out.append("This report lists file paths that have multiple file references and the groups that include them.")
    out.append("")

    if not data['duplicates']:
        out.append("✅ No duplicate paths detected.")
    else:
        for path, uids in sorted(data['duplicates'].items()):
            out.append(f"## {path}")
            for uid in uids:
                groups = data['child_to_groups'].get(uid, [])
                out.append(f"- Ref {uid} in groups: {', '.join(groups) if groups else '(no group)'}")
            out.append("")

        out.append("---")
        out.append("### Suggested Cleanup Procedure (Manual, Safe)")
        out.append("- Keep ONE reference (prefer the one used by targets/build phases).")
        out.append("- Remove the other references from their PBXGroup 'children' arrays in Xcode (Remove Reference).")
        out.append("- If two different refs point to the same path and only one is in targets, remove the one not used by targets.")

    report_path = project_dir / f"{project_dir.name}_DUPLICATE_PATHS_REPORT.md"
    report_path.write_text('\n'.join(out), encoding='utf-8')
    print(f"Report written: {report_path}")


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: report_duplicate_paths.py <ProjectDir>")
        sys.exit(1)
    generate_report(Path(sys.argv[1]))
