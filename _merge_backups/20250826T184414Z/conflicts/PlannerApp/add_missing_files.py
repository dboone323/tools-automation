#!/usr/bin/env python3
"""
Script to add missing Swift files to the Xcode project
"""

import os
import re
import uuid

# Files to add to the project
missing_files = [
    (
        "Accessibility/AccessibilityEnhancements.swift",
        "AccessibilityEnhancements.swift",
    ),
    ("Views/Calendar/CalendarComponents.swift", "CalendarComponents.swift"),
    ("Views/Calendar/CalendarGrid.swift", "CalendarGrid.swift"),
    ("CloudKit/CloudKitMigrationHelper.swift", "CloudKitMigrationHelper.swift"),
    ("Views/Calendar/DateSectionView.swift", "DateSectionView.swift"),
    ("CloudKit/EnhancedCloudKitManager.swift", "EnhancedCloudKitManager.swift"),
    ("Components/EnhancedPlatformNavigation.swift", "EnhancedPlatformNavigation.swift"),
    ("Views/Calendar/EventRowView.swift", "EventRowView.swift"),
    ("Views/Calendar/GoalRowView.swift", "GoalRowView.swift"),
    ("Styling/ModernThemes.swift", "ModernThemes.swift"),
    ("Platform/PlatformFeatures.swift", "PlatformFeatures.swift"),
    ("Views/Calendar/TaskRowView.swift", "TaskRowView.swift"),
    ("Views/Settings/ThemePreviewView.swift", "ThemePreviewView.swift"),
    ("Components/VisualEnhancements.swift", "VisualEnhancements.swift"),
]


def generate_uuid():
    """Generate a UUID in the format used by Xcode"""
    return uuid.uuid4().hex[:24].upper()


def add_files_to_project():
    project_file = "PlannerApp.xcodeproj/project.pbxproj"

    if not os.path.exists(project_file):
        print(f"Error: {project_file} not found")
        return False

    # Read the project file
    with open(project_file, "r") as f:
        content = f.read()

    # Find the PBXBuildFile section
    build_file_section = re.search(
        r"(/\* Begin PBXBuildFile section \*/.*?/\* End PBXBuildFile section \*/)",
        content,
        re.DOTALL,
    )
    if not build_file_section:
        print("Error: Could not find PBXBuildFile section")
        return False

    # Find the PBXFileReference section
    file_ref_section = re.search(
        r"(/\* Begin PBXFileReference section \*/.*?/\* End PBXFileReference section \*/)",
        content,
        re.DOTALL,
    )
    if not file_ref_section:
        print("Error: Could not find PBXFileReference section")
        return False

    # Find the Sources build phase
    sources_section = re.search(
        r"(68F097112DC01EFA00092697 /\* Sources \*/ = \{.*?files = \(.*?\);)",
        content,
        re.DOTALL,
    )
    if not sources_section:
        print("Error: Could not find Sources build phase")
        return False

    new_build_files = []
    new_file_refs = []
    new_source_entries = []

    for file_path, file_name in missing_files:
        # Check if file exists
        if not os.path.exists(file_path):
            print(f"Warning: {file_path} not found, skipping")
            continue

        # Generate UUIDs
        build_file_uuid = generate_uuid()
        file_ref_uuid = generate_uuid()

        # Create build file entry
        build_file_entry = f"\t\t{build_file_uuid} /* {file_name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_uuid} /* {file_name} */; }};"
        new_build_files.append(build_file_entry)

        # Create file reference entry
        file_ref_entry = f'\t\t{file_ref_uuid} /* {file_name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {file_name}; sourceTree = "<group>"; }};'
        new_file_refs.append(file_ref_entry)

        # Create source entry
        source_entry = f"\t\t\t\t{build_file_uuid} /* {file_name} in Sources */,"
        new_source_entries.append(source_entry)

    # Insert new entries
    modified_content = content

    # Add build files
    build_file_end = build_file_section.end() - len("/* End PBXBuildFile section */")
    for entry in new_build_files:
        modified_content = (
            modified_content[:build_file_end]
            + entry
            + "\n"
            + modified_content[build_file_end:]
        )
        build_file_end += len(entry) + 1

    # Add file references
    file_ref_end = re.search(
        r"/\* End PBXFileReference section \*/", modified_content
    ).start()
    for entry in new_file_refs:
        modified_content = (
            modified_content[:file_ref_end]
            + entry
            + "\n\t\t"
            + modified_content[file_ref_end:]
        )
        file_ref_end += len(entry) + 3

    # Add to sources
    sources_files_end = re.search(
        r"68F097592DC0232400092697 /\* MainTabView\.swift in Sources \*/,",
        modified_content,
    ).end()
    for entry in new_source_entries:
        modified_content = (
            modified_content[:sources_files_end]
            + "\n"
            + entry
            + modified_content[sources_files_end:]
        )
        sources_files_end += len(entry) + 1

    # Write back to file
    with open(project_file, "w") as f:
        f.write(modified_content)

    print(f"Successfully added {len(new_build_files)} files to the project")
    return True


if __name__ == "__main__":
    add_files_to_project()
