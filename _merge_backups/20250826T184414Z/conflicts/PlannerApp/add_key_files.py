#!/usr/bin/env python3
"""
Script to add the most important missing Swift files to the Xcode project.
"""

import os
import re
import subprocess
import uuid


def generate_uuid():
    """Generate a UUID in the format used by Xcode (24 characters)"""
    return uuid.uuid4().hex.upper()[:24]


def main():
    project_path = (
        "/Users/danielstevens/Desktop/PlannerApp/PlannerApp.xcodeproj/project.pbxproj"
    )

    # List of most important missing files to add
    missing_files = [
        "Accessibility/AccessibilityEnhancements.swift",
        "CloudKit/CloudKitMigrationHelper.swift",
        "CloudKit/EnhancedCloudKitManager.swift",
        "Components/EnhancedPlatformNavigation.swift",
        "Components/VisualEnhancements.swift",
        "Platform/PlatformFeatures.swift",
        "Styling/ModernThemes.swift",
        "Views/Calendar/CalendarComponents.swift",
        "Views/Calendar/CalendarGrid.swift",
        "Views/Calendar/DateSectionView.swift",
        "Views/Calendar/EventRowView.swift",
        "Views/Calendar/GoalRowView.swift",
        "Views/Calendar/TaskRowView.swift",
        "Views/Settings/ThemePreviewView.swift",
        "MainApp/DashboardView_Modern.swift",
        "MainApp/MainTabView_Enhanced.swift",
    ]

    print(f"Adding {len(missing_files)} important files to the project...")

    # First verify files exist
    for file_path in missing_files:
        full_path = os.path.join("/Users/danielstevens/Desktop/PlannerApp", file_path)
        if not os.path.exists(full_path):
            print(f"Warning: {file_path} does not exist on disk")
        else:
            print(f"Found: {file_path}")

    with open(project_path, "r") as f:
        content = f.read()

    # Generate entries for each file
    new_build_files = []
    new_file_refs = []
    new_source_entries = []

    for file_path in missing_files:
        filename = os.path.basename(file_path)

        # Generate UUIDs
        file_ref_uuid = generate_uuid()
        build_file_uuid = generate_uuid()

        # Create entries
        build_file_entry = f"\t\t{build_file_uuid} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_uuid} /* {filename} */; }};"
        file_ref_entry = f'\t\t{file_ref_uuid} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{file_path}"; sourceTree = "<group>"; }};'
        source_entry = f"\t\t\t\t{build_file_uuid} /* {filename} in Sources */,"

        new_build_files.append(build_file_entry)
        new_file_refs.append(file_ref_entry)
        new_source_entries.append(source_entry)

    # Insert new build files
    build_section = re.search(
        r"(/\* Begin PBXBuildFile section \*/.*?/\* End PBXBuildFile section \*/)",
        content,
        re.DOTALL,
    )
    if build_section:
        build_section_text = build_section.group(1)
        insertion_point = build_section_text.rfind("/* End PBXBuildFile section */")
        new_build_section = (
            build_section_text[:insertion_point]
            + "\n".join(new_build_files)
            + "\n\t\t"
            + build_section_text[insertion_point:]
        )
        content = content.replace(build_section.group(1), new_build_section)
        print("✓ Added build file entries")

    # Insert new file references
    file_ref_section = re.search(
        r"(/\* Begin PBXFileReference section \*/.*?/\* End PBXFileReference section \*/)",
        content,
        re.DOTALL,
    )
    if file_ref_section:
        file_section_text = file_ref_section.group(1)
        insertion_point = file_section_text.rfind("/* End PBXFileReference section */")
        new_file_section = (
            file_section_text[:insertion_point]
            + "\n".join(new_file_refs)
            + "\n\t\t"
            + file_section_text[insertion_point:]
        )
        content = content.replace(file_ref_section.group(1), new_file_section)
        print("✓ Added file reference entries")

    # Insert new source entries
    sources_section = re.search(
        r"(68F097112DC01EFA00092697 /\* Sources \*/ = \{[^}]+files = \([^)]+\);)",
        content,
        re.DOTALL,
    )
    if sources_section:
        sources_text = sources_section.group(1)
        insertion_point = sources_text.rfind(");")
        new_sources_section = (
            sources_text[:insertion_point]
            + "\n"
            + "\n".join(new_source_entries)
            + "\n\t\t\t"
            + sources_text[insertion_point:]
        )
        content = content.replace(sources_section.group(1), new_sources_section)
        print("✓ Added source build phase entries")

    # Write the updated content
    with open(project_path, "w") as f:
        f.write(content)

    print(f"\nSuccessfully added {len(missing_files)} files to the project!")
    print("Files added:")
    for file_path in missing_files:
        print(f"  ✓ {file_path}")


if __name__ == "__main__":
    main()
