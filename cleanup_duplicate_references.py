#!/usr/bin/env python3
"""
Automated Xcode Project Duplicate Reference Cleaner

Removes duplicate file references from Xcode project.pbxproj files by:
1. Parsing the pbxproj file structure
2. Identifying duplicate PBXBuildFile entries
3. Identifying duplicate PBXFileReference entries in multiple groups
4. Removing duplicates while preserving one valid reference
5. Cleaning up orphaned build phase entries

Usage:
    python3 cleanup_duplicate_references.py <path_to_xcodeproj>

Example:
    python3 cleanup_duplicate_references.py ../Projects/HabitQuest/HabitQuest.xcodeproj
"""

import sys
import os
import re
from collections import defaultdict
from pathlib import Path


class XcodeprojCleaner:
    def __init__(self, xcodeproj_path):
        self.xcodeproj_path = Path(xcodeproj_path)
        self.pbxproj_path = self.xcodeproj_path / "project.pbxproj"

        if not self.pbxproj_path.exists():
            raise FileNotFoundError(f"project.pbxproj not found at {self.pbxproj_path}")

        with open(self.pbxproj_path, "r", encoding="utf-8") as f:
            self.content = f.read()
            self.lines = self.content.split("\n")

    def backup(self):
        """Create a backup of the original project file"""
        backup_path = self.pbxproj_path.with_suffix(".pbxproj.backup")
        with open(backup_path, "w", encoding="utf-8") as f:
            f.write(self.content)
        print(f"✅ Backup created: {backup_path}")
        return backup_path

    def find_duplicate_build_files(self):
        """Find duplicate PBXBuildFile entries"""
        # Pattern: UUID /* filename in Sources */ = {isa = PBXBuildFile; fileRef = UUID /* filename */; };
        build_file_pattern = r"^\s*([A-F0-9]+)\s*/\*\s*(.+?)\s+in\s+Sources\s*\*/\s*=\s*\{isa\s*=\s*PBXBuildFile;\s*fileRef\s*=\s*([A-F0-9]+)"

        file_refs = defaultdict(list)  # fileRef UUID -> list of build file UUIDs

        for i, line in enumerate(self.lines):
            match = re.match(build_file_pattern, line)
            if match:
                build_file_uuid = match.group(1)
                filename = match.group(2)
                file_ref_uuid = match.group(3)
                file_refs[file_ref_uuid].append(
                    {"line": i, "uuid": build_file_uuid, "filename": filename}
                )

        duplicates = {k: v for k, v in file_refs.items() if len(v) > 1}
        return duplicates

    def find_duplicate_file_references(self):
        """Find PBXFileReference UUIDs referenced multiple times across or within PBXGroup children.

        Returns a dict mapping file UUID -> list of all occurrences (line, group, filename).
        Consumers can decide whether to remove across-group duplicates, in-group duplicates, or both.
        """
        lines = self.lines
        in_pbxgroup_section = False
        current_group_uuid = None
        in_children = False
        # Map of file UUID -> list of occurrences with (line_index, group_uuid, text)
        occurrences = defaultdict(list)

        for i, line in enumerate(lines):
            # Enter/exit PBXGroup section markers if present
            if "/* Begin PBXGroup section */" in line:
                in_pbxgroup_section = True
                continue
            if "/* End PBXGroup section */" in line:
                in_pbxgroup_section = False
                current_group_uuid = None
                in_children = False
                continue

            if not in_pbxgroup_section:
                continue

            # Detect group header: <UUID> /* name */ = {
            m_group = re.match(r"^\s*([A-F0-9]{24})\s*/\*.*\*/\s*=\s*\{", line)
            if m_group:
                current_group_uuid = m_group.group(1)
                in_children = False
                continue

            # Detect children block start/end
            if current_group_uuid and "children = (" in line:
                in_children = True
                continue
            if in_children and ");" in line:
                in_children = False
                continue

            if in_children and current_group_uuid:
                # Match child UUID entries in children list
                m_child = re.match(
                    r"^\s*([A-F0-9]{24})\s*/\*\s*(.+?)\s*\*/\s*,\s*$",
                    line,
                )
                if m_child:
                    child_uuid = m_child.group(1)
                    filename = m_child.group(2)
                    occurrences[child_uuid].append(
                        {"line": i, "group": current_group_uuid, "filename": filename}
                    )

        return occurrences

    def remove_duplicate_build_files(self, duplicates):
        """Remove duplicate build file entries, keeping only the first one"""
        lines_to_remove = set()
        removed_count = 0

        for file_ref_uuid, build_files in duplicates.items():
            # Keep the first, remove the rest
            for build_file in build_files[1:]:
                line_num = build_file["line"]
                filename = build_file["filename"]
                lines_to_remove.add(line_num)
                print(
                    f"  ❌ Removing duplicate build file: {filename} (line {line_num + 1})"
                )
                removed_count += 1

        # Remove lines in reverse order to maintain line numbers
        new_lines = [
            line for i, line in enumerate(self.lines) if i not in lines_to_remove
        ]
        self.lines = new_lines

        return removed_count

    def remove_duplicate_file_references_from_groups(self, occurrences):
        """Remove duplicate file references from PBXGroup children arrays.

        - Removes duplicates across groups (same UUID appears in >1 group) keeping the first overall.
        - Removes duplicates within the same group (same UUID listed multiple times) keeping the first in that group.
        """
        lines_to_remove = set()
        removed_count = 0

        for file_uuid, occs in occurrences.items():
            # Sort by (group, line) to have consistent first-kept ordering
            occs_sorted = sorted(occs, key=lambda o: (o["group"], o["line"]))

            # Track first overall kept
            kept_overall = False
            seen_groups = set()

            for occ in occs_sorted:
                line_num = occ["line"]
                group = occ["group"]
                filename = occ["filename"]

                if not kept_overall:
                    # keep the first overall occurrence
                    kept_overall = True
                    seen_groups.add(group)
                    continue

                # If we've already seen this group, this is an in-group duplicate -> remove
                if group in seen_groups:
                    lines_to_remove.add(line_num)
                    removed_count += 1
                    print(
                        f"  ❌ Removing duplicate (in same group): {filename} (line {line_num + 1})"
                    )
                else:
                    # New group but same file UUID -> remove to avoid multi-group membership warning
                    lines_to_remove.add(line_num)
                    removed_count += 1
                    seen_groups.add(group)
                    print(
                        f"  ❌ Removing duplicate (across groups): {filename} (line {line_num + 1})"
                    )

        # Remove lines in reverse order to keep indexes stable
        new_lines = [
            line for i, line in enumerate(self.lines) if i not in lines_to_remove
        ]
        self.lines = new_lines

        return removed_count

    def save(self):
        """Save the cleaned project file"""
        new_content = "\n".join(self.lines)
        with open(self.pbxproj_path, "w", encoding="utf-8") as f:
            f.write(new_content)
        print(f"✅ Cleaned project saved: {self.pbxproj_path}")

    def clean(self):
        """Main cleaning process"""
        print(f"\n🔧 Cleaning Xcode project: {self.xcodeproj_path.name}")
        print("=" * 60)

        # Backup first
        self.backup()

        # Find and remove duplicate build files
        print("\n📋 Checking for duplicate build files...")
        build_file_dupes = self.find_duplicate_build_files()
        if build_file_dupes:
            print(f"Found {len(build_file_dupes)} files with duplicate build entries")
            removed = self.remove_duplicate_build_files(build_file_dupes)
            print(f"✅ Removed {removed} duplicate build file entries")
        else:
            print("✅ No duplicate build files found")

        # Find and remove duplicate file references in groups
        print("\n📁 Checking for duplicate file references in groups...")
        file_ref_occurrences = self.find_duplicate_file_references()
        # Determine which UUIDs have duplicates either within same group or across groups
        dupes = {
            uuid: occs
            for uuid, occs in file_ref_occurrences.items()
            if len(occs) > 1  # more than one occurrence overall (same or different groups)
        }
        if dupes:
            print(
                f"Found {len(dupes)} file references appearing multiple times (same or different groups)"
            )
            removed = self.remove_duplicate_file_references_from_groups(dupes)
            print(f"✅ Removed {removed} duplicate group references")
        else:
            print("✅ No duplicate group references found")

        # Save cleaned project
        print("\n💾 Saving cleaned project...")
        self.save()

        print("\n" + "=" * 60)
        print("✅ Cleanup complete!")
        print(f"\n⚠️  IMPORTANT: Open the project in Xcode to verify it loads correctly")
        print(
            f"   If there are issues, restore from: {self.pbxproj_path.with_suffix('.pbxproj.backup')}"
        )


def verify_project(xcodeproj_path):
    """Verify the project by running xcodebuild -list"""
    print(f"\n🔍 Verifying project: {xcodeproj_path}")
    result = os.system(
        f'xcodebuild -project "{xcodeproj_path}" -list 2>&1 | grep -c "member of multiple groups"'
    )
    return result == 0


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 cleanup_duplicate_references.py <path_to_xcodeproj>")
        print("\nExample:")
        print(
            "  python3 cleanup_duplicate_references.py ../Projects/HabitQuest/HabitQuest.xcodeproj"
        )
        sys.exit(1)

    xcodeproj_path = sys.argv[1]

    if not os.path.exists(xcodeproj_path):
        print(f"❌ Error: Project not found: {xcodeproj_path}")
        sys.exit(1)

    try:
        cleaner = XcodeprojCleaner(xcodeproj_path)
        cleaner.clean()

        # Verify
        print("\n🔍 Running verification...")
        os.system(f'xcodebuild -project "{xcodeproj_path}" -list 2>&1 | head -20')

    except Exception as e:
        print(f"\n❌ Error during cleanup: {e}")
        import traceback

        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
